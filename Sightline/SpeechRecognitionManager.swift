import AVFoundation
import Speech
import Combine
import Foundation

// Keep manager state and UI updates on the main actor.
@MainActor
class SpeechRecognitionManager: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var lastError: String?
    private var recoveryAttempts = 0
    private var recoveryTask: Task<Void, Never>?

    private let audioEngine = AVAudioEngine()

    // Configure the audio session away from the UI thread.
    private let audioSessionQueue = DispatchQueue(
        label: "sightline.audioSession"
    )

    private var audioStartupTask: Task<Void, Never>?

    private let speechRecognizer = SFSpeechRecognizer()
    private let commandParser = VoiceCommandParser()

    var onCommand: ((String) -> Void)?
    var onRecognitionFinished: (() -> Void)?

    private var recognitionRequest:
        SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask: SFSpeechRecognitionTask?
    private var isInputTapInstalled = false

    // Cancel a pending command if its words change.
    private var pendingCommandTask: Task<Void, Never>?
    private var lastCommandText = ""

    // Identify the current listening session and permission request.
    private var activeSessionID: UUID?
    private var permissionRequestID: UUID?

    // MARK: - Permissions

    func requestPermissions() {
        // Ignore repeated starts while permission or startup is pending.
        guard !isListening,
              activeSessionID == nil,
              permissionRequestID == nil else {
            return
        }

        lastError = nil
        recoveryAttempts = 0
        let requestID = UUID()
        permissionRequestID = requestID

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self,
                      self.permissionRequestID == requestID else {
                    return
                }

                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                    self.requestMicrophonePermission(
                        requestID: requestID
                    )

                case .denied:
                    self.permissionRequestID = nil
                    self.lastError = "Speech recognition is off. Enable it in Settings."
                    print("Speech recognition permission denied")

                case .restricted:
                    self.permissionRequestID = nil
                    self.lastError = "Speech recognition is restricted on this device."
                    print("Speech recognition is restricted")

                case .notDetermined:
                    self.permissionRequestID = nil
                    print(
                        "Speech recognition permission not determined"
                    )

                @unknown default:
                    self.permissionRequestID = nil
                    print("Unknown speech recognition permission")
                }
            }
        }
    }

    private func requestMicrophonePermission(requestID: UUID) {
        AVAudioApplication.requestRecordPermission {
            [weak self] granted in

            DispatchQueue.main.async {
                // Ignore permission answers after Stop.
                guard let self = self,
                      self.permissionRequestID == requestID else {
                    return
                }

                self.permissionRequestID = nil

                if granted {
                    print("Both permissions granted")
                    self.startListening()
                } else {
                    self.lastError = "Microphone access is off. Enable it in Settings."
                    print("Microphone permission denied")
                }
            }
        }
    }

    // MARK: - Audio Setup

    private func configureAudioSession() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            audioSessionQueue.async {
                let session = AVAudioSession.sharedInstance()

                do {
                    // Avoid resetting settings that already match.
                    if session.category != .playAndRecord ||
                        session.mode != .default ||
                        session.categoryOptions != [.defaultToSpeaker] {
                        try session.setCategory(
                            .playAndRecord,
                            mode: .default,
                            options: [.defaultToSpeaker]
                        )
                    }

                    // iOS 27: activate without blocking the UI thread.
                    session.activate(options: []) { activated, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if activated {
                            continuation.resume(returning: ())
                        } else {
                            continuation.resume(
                                throwing: NSError(
                                    domain: "Sightline.AudioSession",
                                    code: 1,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "The audio session did not activate."
                                    ]
                                )
                            )
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Start Listening

    private func startListening() {
        guard !isListening, activeSessionID == nil else {
            return
        }

        guard let recognizer = speechRecognizer,
              recognizer.isAvailable else {
            lastError = "Speech recognition is unavailable. Tap Resume Voice to retry."
            print("Speech recognition is unavailable")
            return
        }

        let sessionID = UUID()
        activeSessionID = sessionID

        audioStartupTask = Task { @MainActor [weak self] in
            guard let self = self,
                  self.activeSessionID == sessionID else {
                return
            }

            do {
                try await self.configureAudioSession()

                // Stop may have been pressed while activation was pending.
                guard !Task.isCancelled,
                      self.activeSessionID == sessionID else {
                    return
                }

                self.audioStartupTask = nil
                self.startCapture(
                    using: recognizer,
                    sessionID: sessionID
                )
            } catch {
                // An old failure must not stop a newer session.
                guard self.activeSessionID == sessionID else {
                    return
                }

                print("Could not activate the audio session:", error)
                self.stopListening()
            }
        }
    }

    private func startCapture(
        using recognizer: SFSpeechRecognizer,
        sessionID: UUID
    ) {
        guard activeSessionID == sessionID else {
            return
        }

        do {
            // Create a fresh request for this listening session.
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.contextualStrings = ["Sightline"]
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0,
                  recordingFormat.channelCount > 0 else {
                print("Microphone audio format is unavailable")
                stopListening()
                return
            }

            // The older tap API still works for this prototype.
            // Its iOS 27 deprecation warning may remain.
            inputNode.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: recordingFormat
            ) { buffer, _ in
                // Skip buffers containing no audio frames.
                guard buffer.frameLength > 0 else {
                    return
                }

                request.append(buffer)
            }

            isInputTapInstalled = true

            recognitionTask = recognizer.recognitionTask(
                with: request
            ) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let errorMessage = error?.localizedDescription

                print(
                    "Recognition:",
                    text ?? "(no text)",
                    "Final:", isFinal,
                    "Error:", errorMessage ?? "(none)"
                )

                DispatchQueue.main.async {
                    // Ignore callbacks from an older session.
                    guard let self = self,
                          self.activeSessionID == sessionID else {
                        return
                    }

                    if let errorMessage = errorMessage {
                        print(
                            "Speech recognition failed:",
                            errorMessage
                        )
                        self.recoverAfterError(errorMessage)
                        return
                    }

                    if let text = text,
                       !text.trimmingCharacters(
                           in: .whitespacesAndNewlines
                       ).isEmpty {
                        self.transcript = text

                        self.scheduleCommand(
                            from: text,
                            sessionID: sessionID
                        )
                    }

                    // Let a pending complete command finish its delay.
                    if isFinal && self.pendingCommandTask == nil {
                        self.stopListening()
                        self.onRecognitionFinished?()
                    }
                }
            }

            // Start recording after the request and tap are ready.
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            lastError = nil

            print("Audio engine running:", audioEngine.isRunning)
        } catch {
            print("Could not start listening:", error)
            stopListening()
        }
    }

    // MARK: - Stop and Cleanup

    func stopListening() {
        // Invalidate startup before canceling its task.
        activeSessionID = nil
        recoveryTask?.cancel()
        recoveryTask = nil

        audioStartupTask?.cancel()
        audioStartupTask = nil

        pendingCommandTask?.cancel()
        pendingCommandTask = nil
        lastCommandText = ""

        permissionRequestID = nil
        isListening = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if isInputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isInputTapInstalled = false
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        // Preserve the transcript after stopping.
        // Leave the shared audio session active for spoken output.
    }

    private func recoverAfterError(_ message: String) {
        stopListening()
        lastError = "Voice recognition paused. " + message
        guard recoveryAttempts < 2 else { return }
        recoveryAttempts += 1
        let recoveryID = UUID()
        activeSessionID = recoveryID
        recoveryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard let self, !Task.isCancelled,
                  self.activeSessionID == recoveryID else { return }
            self.activeSessionID = nil
            self.recoveryTask = nil
            self.startListening()
        }
    }

    // MARK: - Command Delivery

    private func scheduleCommand(
        from text: String,
        sessionID: UUID
    ) {
        let normalized = text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")

        // Identical results should not restart the timer.
        guard normalized != lastCommandText else {
            return
        }

        lastCommandText = normalized

        pendingCommandTask?.cancel()
        pendingCommandTask = nil

        guard let command = commandParser.command(
            from: normalized
        ) else {
            return
        }

        // Local find requests and Gemini requests use this path.
        guard commandParser.isSupportedCommand(command) else {
            return
        }

        pendingCommandTask = Task { @MainActor [weak self] in
            do {
                // Wait one second without changes to the command.
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self = self,
                  self.activeSessionID == sessionID else {
                return
            }

            self.pendingCommandTask = nil
            self.stopListening()
            self.onCommand?(command)
        }
    }
}
