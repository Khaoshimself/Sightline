import AVFoundation
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isWalking = false
    @State private var status: AVAuthorizationStatus =
        AVCaptureDevice.authorizationStatus(for: .video)

    @State private var showCameraDeniedAlert = false
    @State private var cameraPermissionRequestID: UUID?
    @State private var lastCommand = ""
    @State private var targetObject: String?
    @State private var lastSpokenDirection: String?
    @State private var lastGuidanceTime = Date.distantPast
    
    @StateObject private var cameraManager = CameraManager()
    @State private var speechManager = SpeechManager()
    @StateObject private var speechRecognitionManager =
        SpeechRecognitionManager()

    // MARK: - Starting

    private func checkCameraPermission() {
        // Avoid opening multiple startup requests.
        guard cameraPermissionRequestID == nil else {
            return
        }

        let current = AVCaptureDevice.authorizationStatus(for: .video)
        status = current

        switch current {
        case .authorized:
            beginSession()

        case .notDetermined:
            let requestID = UUID()
            cameraPermissionRequestID = requestID

            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    // Ignore permission responses after Stop or leaving.
                    guard cameraPermissionRequestID == requestID else {
                        return
                    }

                    cameraPermissionRequestID = nil
                    status = AVCaptureDevice.authorizationStatus(for: .video)

                    if granted {
                        beginSession()
                    } else {
                        stopSession()
                        showCameraDeniedAlert = status == .denied
                    }
                }
            }

        case .denied:
            stopSession()
            showCameraDeniedAlert = true

        case .restricted:
            stopSession()

        @unknown default:
            stopSession()
        }
    }

    private func beginSession() {
        targetObject = nil
        lastSpokenDirection = nil
        lastGuidanceTime = .distantPast
        
        // Don't start recognition while test speech is playing.
        speechManager.stop()
        lastCommand = ""

        isWalking = true
        cameraManager.start()

        // Request speech permissions after camera permission succeeds.
        // The manager starts listening when both speech permissions pass.
        speechRecognitionManager.requestPermissions()
    }

    // MARK: - Stopping

    private func stopSession() {
        targetObject = nil
        lastSpokenDirection = nil
        lastGuidanceTime = .distantPast
        
        // Cancel any pending camera startup.
        cameraPermissionRequestID = nil
        isWalking = false

        cameraManager.stop()
        speechManager.stop()
        speechRecognitionManager.stopListening()
    }
    
    private func handleCommand(_ command: String) {
        guard isWalking else { return }
        lastCommand = command

        // The recognition manager already checks complete find commands.
        let supportedObjects: Set<String> = [
            "chair", "person", "bottle", "backpack", "car"
        ]

        guard let word = command.split(separator: " ").last else {
            return
        }

        let target = String(word)
        guard supportedObjects.contains(target) else { return }

        targetObject = target
        lastSpokenDirection = nil
        lastGuidanceTime = Date()

        speechManager.stop()
        speechManager.speak(text: "Looking for \(target).")
    }

    private func announceTarget(in objects: [DetectedObject]) {
        guard isWalking,
              !speechManager.isSpeaking,
              let target = targetObject else {
            return
        }

        // If several objects match, use the most confident detection.
        // This does not tell us which one is nearest.
        guard let match = objects
            .filter({ $0.label == target })
            .max(by: { $0.confidence < $1.confidence }) else {
            return
        }

        let direction = match.direction

        // Avoid repeating the same direction or speaking too frequently.
        guard direction != lastSpokenDirection,
              Date().timeIntervalSince(lastGuidanceTime) >= 3 else {
            return
        }

        let location: String
        switch direction {
        case "Left":
            location = "to your left"
        case "Right":
            location = "to your right"
        default:
            location = "ahead"
        }

        lastSpokenDirection = direction
        lastGuidanceTime = Date()

        speechManager.stop()
        speechManager.speak(text: "\(target.capitalized) \(location).")
    }
    
    private func resumeListening() {
        guard isWalking, !speechManager.isSpeaking else {
            return
        }

        speechRecognitionManager.requestPermissions()
    }

    // MARK: - Interface

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Sightline")
                    .font(.largeTitle.bold())

                CameraPreviewView(session: cameraManager.session)
                    .frame(height: 400)
                    .overlay {
                        if isWalking {
                            DetectionOverlayView(
                                detections: cameraManager.detectedObjects
                            )
                            .allowsHitTesting(false)
                        }
                    }
                    .clipped()

                Button("Start Walking Mode") {
                    checkCameraPermission()
                }
                .disabled(cameraPermissionRequestID != nil)

                Button("Stop") {
                    stopSession()
                }

                // Temporary development control.
                // Disabled while listening to avoid transcribing test speech.
                Button("Test Speech") {
                    speechManager.speak(text: "Sightline is ready.")
                }
                .disabled(isWalking || cameraPermissionRequestID != nil)

                Button("Test Snapshot") {
                    cameraManager.captureSnapshot { data in
                        guard isWalking else { return }

                        if let data = data {
                            print("Snapshot ready:", data.count, "bytes")
                        } else {
                            print("Could not capture a snapshot")
                        }
                    }
                }
                .disabled(!isWalking)

                Text(
                    speechRecognitionManager.isListening
                        ? "Listening"
                        : "Not listening"
                )

                if !speechRecognitionManager.transcript.isEmpty {
                    Text("Heard: \(speechRecognitionManager.transcript)")
                }

                if !lastCommand.isEmpty {
                    Text("Command: \(lastCommand)")
                        .fontWeight(.semibold)
                }

                if isWalking {
                    Text("Walking Mode activated")
                    Text(
                        "Objects detected: \(cameraManager.detectedObjects.count)"
                    )
                } else {
                    Text("Idle")
                }

                if status == .restricted {
                    Text("Camera access is restricted on this device.")
                }
            }
            .padding()
        }
        .onAppear {
            speechRecognitionManager.onCommand = { command in
                handleCommand(command)
            }

            speechManager.onWillSpeak = {
                speechRecognitionManager.stopListening()
            }

            speechManager.onFinished = {
                resumeListening()
            }

            speechRecognitionManager.onRecognitionFinished = {
                resumeListening()
            }
        }
        .onReceive(cameraManager.$detectedObjects) { objects in
            announceTarget(in: objects)
        }
        
        .onDisappear {
            stopSession()

            speechRecognitionManager.onCommand = nil
            speechRecognitionManager.onRecognitionFinished = nil
            speechManager.onWillSpeak = nil
            speechManager.onFinished = nil
        }
        
        .alert(
            "Camera access is off",
            isPresented: $showCameraDeniedAlert
        ) {
            Button("OK", role: .cancel) {}

            Button("Open Settings") {
                if let url = URL(
                    string: UIApplication.openSettingsURLString
                ) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Enable camera access in Settings to use Sightline.")
        }
    }
}

#Preview {
    ContentView()
}
