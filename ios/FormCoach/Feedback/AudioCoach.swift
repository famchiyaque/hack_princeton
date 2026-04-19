import AVFoundation
import os

// Change to your Mac's LAN IP when testing on a physical device.
// e.g. "http://192.168.1.42:8000"
private var backendBase: String {
    APIClient.defaultBaseURL.replacingOccurrences(of: "/api", with: "")
}

private let log = Logger(subsystem: "com.formcoach", category: "AudioCoach")

final class AudioCoach: NSObject, ObservableObject {

    // Prefetched ElevenLabs audio: phrase text → MP3 data
    private var audioCache: [String: Data] = [:]
    @Published private(set) var cacheReady = false

    // Active ElevenLabs player
    private var audioPlayer: AVAudioPlayer?

    // On-device fallback
    private let synthesizer = AVSpeechSynthesizer()
    private let localVoice: AVSpeechSynthesisVoice? = {
        AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Ava")
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    private var queue: [(message: String, priority: Int)] = []
    private var isSpeaking = false

    /// Hard ceiling on how long a single utterance can block the queue. If the
    /// player never reports finish (e.g. audio session was stolen by camera
    /// activation), this watchdog clears `isSpeaking` and drains the next item.
    private let utteranceWatchdog: TimeInterval = 8.0
    private var watchdogWork: DispatchWorkItem?

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Cache

    /// Download all pre-generated phrase audio from the backend in one shot.
    /// Call this when a session is about to start (e.g. from SessionView.onAppear).
    func prefetch() {
        guard let url = URL(string: "\(backendBase)/api/tts/bundle") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data, error == nil, (200...299).contains(status) else {
                log.warning("TTS bundle fetch failed (status \(status)): \(error?.localizedDescription ?? "no data")")
                return
            }

            struct Bundle: Decodable { let phrases: [String: String] }
            guard let bundle = try? JSONDecoder().decode(Bundle.self, from: data) else {
                log.warning("TTS bundle decode failed (\(data.count) bytes)")
                return
            }

            var decoded: [String: Data] = [:]
            for (phrase, b64) in bundle.phrases {
                if let mp3 = Data(base64Encoded: b64) {
                    decoded[phrase] = mp3
                }
            }

            DispatchQueue.main.async {
                self.audioCache = decoded
                self.cacheReady = true
            }
        }.resume()
    }

    // MARK: - Public API

    func speak(_ message: String, priority: Int = 5) {
        log.debug("speak(priority:\(priority, privacy: .public)) \(message, privacy: .public)")
        enqueue(message, priority: priority)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        queue.removeAll()
        isSpeaking = false
        cancelWatchdog()
    }

    // MARK: - Private

    private func enqueue(_ message: String, priority: Int) {
        queue.append((message, priority))
        queue.sort { $0.priority > $1.priority }
        drainQueue()
    }

    private func drainQueue() {
        guard !isSpeaking, let next = queue.first else { return }

        queue.removeFirst()
        isSpeaking = true
        armWatchdog()

        if let cachedData = audioCache[next.message] {
            playMP3(cachedData, fallbackText: next.message)
        } else if cacheReady {
            fetchAndPlay(next.message)
        } else {
            speakLocally(next.message)
        }
    }

    private func playMP3(_ data: Data, fallbackText: String) {
        // Re-activate the audio session right before playing — the camera
        // startup can yank it away silently on first launch.
        try? AVAudioSession.sharedInstance().setActive(true, options: [])

        guard let player = try? AVAudioPlayer(data: data) else {
            log.warning("AVAudioPlayer init failed, falling back to local TTS")
            speakLocally(fallbackText)
            return
        }
        audioPlayer = player
        player.delegate = self
        let started = player.prepareToPlay() && player.play()
        if !started {
            log.warning("AVAudioPlayer.play() returned false, falling back to local TTS")
            audioPlayer = nil
            speakLocally(fallbackText)
        }
    }

    /// On-demand fetch for phrases not in the pre-cached bundle (dynamic fallback strings).
    /// Falls back to local TTS if the request takes longer than 3 seconds.
    private func fetchAndPlay(_ text: String) {
        guard let url = URL(string: "\(backendBase)/api/tts/speak") else {
            speakLocally(text); return
        }

        var request = URLRequest(url: url, timeoutInterval: 3.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable { let text: String }
        request.httpBody = try? JSONEncoder().encode(Body(text: text))

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                if let data, error == nil, (200...299).contains(status) {
                    self.audioCache[text] = data
                    self.playMP3(data, fallbackText: text)
                } else {
                    log.warning("TTS fetch failed (status \(status)): \(error?.localizedDescription ?? "unknown")")
                    self.speakLocally(text)
                }
            }
        }.resume()
    }

    private func speakLocally(_ text: String) {
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = localVoice
        utterance.rate  = 0.48
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        // `.spokenAudio` mode is optimized for short utterances and plays
        // nicely next to AVCaptureSession. `.mixWithOthers` prevents the
        // session from being deactivated underneath us.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth]
            )
            try session.setActive(true, options: [])
        } catch {
            log.error("audio session setup failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Watchdog — recovers if a player delegate never fires.

    private func armWatchdog() {
        cancelWatchdog()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isSpeaking else { return }
            log.warning("utterance watchdog fired — forcing queue drain")
            self.audioPlayer?.stop()
            self.audioPlayer = nil
            self.isSpeaking = false
            self.drainQueue()
        }
        watchdogWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + utteranceWatchdog, execute: work)
    }

    private func cancelWatchdog() {
        watchdogWork?.cancel()
        watchdogWork = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioCoach: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        cancelWatchdog()
        drainQueue()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        cancelWatchdog()
        drainQueue()
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioCoach: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.cancelWatchdog()
            self?.drainQueue()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            log.warning("AVAudioPlayer decode error: \(String(describing: error), privacy: .public)")
            self?.isSpeaking = false
            self?.cancelWatchdog()
            self?.drainQueue()
        }
    }
}
