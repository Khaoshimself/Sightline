import AVFoundation
import Combine

@MainActor
final class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published private var activeUtteranceID: ObjectIdentifier?

    var onWillSpeak: (() -> Void)?
    var onFinished: (() -> Void)?
    var isSpeaking: Bool { activeUtteranceID != nil }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // All spoken output is generated on the device, without a speech API request.
    func speak(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        stop()
        let utterance = AVSpeechUtterance(string: text)
        activeUtteranceID = ObjectIdentifier(utterance)
        onWillSpeak?()
        synthesizer.speak(utterance)
    }

    func stop() {
        // Ignore cancellation callbacks from speech stopped by the user.
        activeUtteranceID = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        finish(utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        finish(utterance)
    }

    nonisolated private func finish(_ utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.activeUtteranceID == id else { return }
            self.activeUtteranceID = nil
            self.onFinished?()
        }
    }
}
