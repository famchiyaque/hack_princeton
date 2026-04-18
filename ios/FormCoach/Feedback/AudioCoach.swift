import AVFoundation

final class AudioCoach: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    private var lastSpokenAt: TimeInterval = 0
    private let throttle: TimeInterval = 2.5
    private var queue: [(message: String, priority: Int)] = []

    private let voice: AVSpeechSynthesisVoice? = {
        // Try enhanced voice first, fall back to standard
        AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Ava")
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Public API

    func speakCorrections(_ corrections: [FormCorrection]) {
        guard !corrections.isEmpty else {
            enqueue("Good form, keep it up", priority: 0)
            return
        }
        let top = corrections[0]
        enqueue(top.message, priority: Int(top.severity * 10))
    }

    func speak(_ message: String, priority: Int = 5) {
        enqueue(message, priority: priority)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        queue.removeAll()
    }

    // MARK: - Private

    private func enqueue(_ message: String, priority: Int) {
        queue.append((message, priority))
        queue.sort { $0.priority > $1.priority }
        drainQueue()
    }

    private func drainQueue() {
        guard !synthesizer.isSpeaking,
              CACurrentMediaTime() - lastSpokenAt >= throttle,
              let next = queue.first
        else { return }

        queue.removeFirst()
        lastSpokenAt = CACurrentMediaTime()

        let utterance = AVSpeechUtterance(string: next.message)
        utterance.voice = voice
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

extension AudioCoach: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        drainQueue()
    }
}
