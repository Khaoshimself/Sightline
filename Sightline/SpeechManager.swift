import AVFoundation

@MainActor
class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtteranceID: ObjectIdentifier?

    var onWillSpeak: (() -> Void)?
    var onFinished: (() -> Void)?

    var isSpeaking: Bool {
        activeUtteranceID != nil
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String) {
        guard !text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return
        }

        stop()

        let utterance = AVSpeechUtterance(string: text)
        activeUtteranceID = ObjectIdentifier(utterance)

        // Pause recognition before any sound starts.
        onWillSpeak?()
        synthesizer.speak(utterance)
    }

    func stop() {
        // Ignore any later callback from this canceled reply.
        activeUtteranceID = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)

        Task { @MainActor [weak self] in
            self?.finishSpeech(id: id)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)

        Task { @MainActor [weak self] in
            self?.finishSpeech(id: id)
        }
    }

    private func finishSpeech(id: ObjectIdentifier) {
        // An older reply must not interrupt a newer one.
        guard activeUtteranceID == id else { return }

        activeUtteranceID = nil
        onFinished?()
    }
}
