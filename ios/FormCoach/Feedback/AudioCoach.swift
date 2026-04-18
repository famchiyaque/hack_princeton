import AVFoundation

// Change to your Mac's LAN IP when testing on a physical device.
// e.g. "http://192.168.1.42:8000"
private let backendBase = "http://localhost:8000"

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

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self, let data, error == nil else { return }

            struct Bundle: Decodable { let phrases: [String: String] }
            guard let bundle = try? JSONDecoder().decode(Bundle.self, from: data) else { return }

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
        enqueue(message, priority: priority)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        queue.removeAll()
        isSpeaking = false
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

        if let cachedData = audioCache[next.message] {
            // Instant playback from prefetched cache
            playMP3(cachedData)
        } else if cacheReady {
            // Unknown phrase (dynamic fallback text) — fetch on-demand, then local TTS while waiting
            fetchAndPlay(next.message)
        } else {
            // Cache not ready yet (e.g. session started before bundle downloaded)
            speakLocally(next.message)
        }
    }

    private func playMP3(_ data: Data) {
        guard let player = try? AVAudioPlayer(data: data) else {
            isSpeaking = false
            return
        }
        audioPlayer = player
        player.delegate = self
        player.play()
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

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let data, error == nil {
                    self.audioCache[text] = data  // cache for next time
                    self.playMP3(data)
                } else {
                    self.speakLocally(text)
                }
            }
        }.resume()
    }

    private func speakLocally(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = localVoice
        utterance.rate  = 0.48
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioCoach: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        drainQueue()
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioCoach: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.drainQueue()
        }
    }
}
