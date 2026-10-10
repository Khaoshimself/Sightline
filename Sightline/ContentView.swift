import AVFoundation
import SwiftUI
import UIKit
import Combine

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize

    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognition = SpeechRecognitionManager()
    @StateObject private var speech = SpeechManager()

    @State private var gemini = GeminiManager()

    private var isDemo: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--demo")
        #else
        false
        #endif
    }
    private let parser = VoiceCommandParser()
    private let accent = Color(
        red: 0.12, green: 0.22, blue: 0.58
    )

    @State private var isWalking = false
    @State private var cameraRequestID: UUID?
    @State private var showCameraAlert = false
    @State private var cameraRestricted = false

    @State private var target: String?
    @State private var lastDirection: String?
    @State private var lastAnnouncement = Date.distantPast
    @State private var emptyFrames = 0
    @State private var audioInterrupted = false

    @State private var sceneID: UUID?
    @State private var sceneTask: Task<Void, Never>?
    @State private var description = ""

    private var sessionStatus: String {
        if !isWalking {
            return "Ready when you are"
        }
        if isDemo { return "Sample session. Audio is off." }
        if audioInterrupted { return "Audio interrupted. Resume Voice when ready." }
        if sceneID != nil {
            return "Describing the scene…"
        }
        if speech.isSpeaking {
            return "Speaking…"
        }
        if recognition.isListening {
            return "Listening for Sightline"
        }

        return "Voice is paused. Tap Resume Voice to retry."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Sightline", systemImage: "eye")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text(isDemo ? "Demo with sample content" : "Understand what’s around you")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }

                Label(
                    sessionStatus,
                    systemImage: isWalking
                        ? "waveform"
                        : "checkmark.circle"
                )
                .font(.headline)
                .accessibilityLabel(sessionStatus)
                .accessibilityIdentifier("sessionStatus")

                CameraPreviewView(session: cameraManager.session)
                    .frame(height: textSize.isAccessibilitySize ? 120 : 260)
                    .overlay {
                        if isWalking {
                            DetectionOverlayView(
                                detections: cameraManager.detectedObjects
                            )
                            .allowsHitTesting(false)
                        } else {
                            ZStack {
                                Color.black

                                Image(systemName: "camera")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: 24)
                    )
                    .accessibilityHidden(true)

                if !isWalking {
                    actionButton(
                        "Start Walking Mode",
                        icon: "play.fill",
                        color: accent
                    ) {
                        start()
                    }
                    .disabled(cameraRequestID != nil)
                    .accessibilityHint(
                        "Starts the camera and listens for spoken commands."
                    )
                } else {
                    actionButton(
                        "Stop",
                        icon: "stop.fill",
                        color: Color(
                            red: 0.65,
                            green: 0.08,
                            blue: 0.12
                        )
                    ) {
                        stop()
                    }
                    .accessibilitySortPriority(10)
                    .accessibilityHint(
                        "Stops the camera, listening, speech, and scene requests."
                    )

                    actionButton(
                        "Describe Scene",
                        icon: "sparkles",
                        color: accent
                    ) {
                        describeScene()
                    }
                    .disabled(sceneID != nil || audioInterrupted)
                    .accessibilityHint(
                        "Reads a description of the current camera image aloud."
                    )

                    Menu {
                        ForEach(
                            ["chair", "person", "bottle", "backpack", "car"],
                            id: \.self
                        ) { object in
                            Button("Find a \(object)") {
                                handleCommand("find \(object)")
                            }
                        }
                    } label: {
                        Label(
                            "Find an Object",
                            systemImage: "viewfinder"
                        )
                        .font(.title3.weight(.semibold))
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 60
                        )
                    }
                    .disabled(sceneID != nil)

                    if !recognition.isListening
                        && !speech.isSpeaking
                        && sceneID == nil {

                        Button("Resume Voice") {
                            audioInterrupted = false
                            resumeListening()
                        }
                        .font(.title3.bold())
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 60
                        )

                        Button("Open Permissions in Settings") {
                            openSettings()
                        }
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 48
                        )
                    }
                }

                if let target {
                    Label(
                        "Looking for a \(target)",
                        systemImage: "viewfinder"
                    )
                    .font(.title3.bold())
                }

                if !description.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scene description")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        Text(description)
                            .font(.title3)
                            .textSelection(.enabled)
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(
                        Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Try saying")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    Text("“Sightline, describe the scene”")
                    Text("“Sightline, find me a chair”")
                    Text("“Sightline, stop”")

                    Text(
                        "Voice commands work while listening. Use Stop to interrupt speech."
                    )
                    .foregroundStyle(.primary)
                }

                if let error = recognition.lastError, isWalking {
                    Text(error).font(.body)
                }

                if cameraRestricted {
                    Text(
                        "Camera access is restricted on this device."
                    )
                }

                if !recognition.transcript.isEmpty {
                    DisclosureGroup {
                        Text(recognition.transcript).padding(.top, 8)
                    } label: {
                        Text("Last heard").frame(minHeight: 48)
                    }
                }

                Text(
                    "Prototype: descriptions may be wrong. Sightline does not assess whether a path is safe."
                )
                .font(.footnote)
                .foregroundStyle(.primary)
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
        .preferredColorScheme(isDemo && ProcessInfo.processInfo.arguments.contains("--dark-demo") ? .dark : nil)
        .onAppear {
            recognition.onCommand = {
                handleCommand($0)
            }

            recognition.onRecognitionFinished = {
                resumeListening()
            }

            speech.onWillSpeak = {
                recognition.stopListening()
            }

            speech.onFinished = {
                resumeListening()
            }
        }
        .onReceive(cameraManager.$detectedObjects) {
            announceTarget($0)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: AVAudioSession.didBecomeInactiveNotification
        ).receive(on: DispatchQueue.main)) { notification in
            if isWalking { pauseAudio() }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: AVAudioSession.resumptionRecommendationNotification
        ).receive(on: DispatchQueue.main)) { notification in
            guard isWalking, audioInterrupted, scenePhase == .active,
                  let context = notification.userInfo?[AVAudioSession.resumptionContextKey]
                      as? AVAudioSession.ResumptionContext,
                  context.recommendation == .shouldResume else { return }
            audioInterrupted = false
            resumeListening()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: AVAudioSession.routeChangeNotification
        ).receive(on: DispatchQueue.main)) { notification in
            // A disconnected headset must not leave an old microphone tap running.
            if let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable,
               isWalking {
                pauseAudio()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                stop()
            }
        }
        .onDisappear {
            stop()

            recognition.onCommand = nil
            recognition.onRecognitionFinished = nil
            speech.onWillSpeak = nil
            speech.onFinished = nil
        }
        .alert(
            "Camera access is off",
            isPresented: $showCameraAlert
        ) {
            Button("Open Settings") {
                openSettings()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Enable camera access in Settings to use Sightline."
            )
        }
    }

    private func start() {
        if isDemo { isWalking = true; description = "Demo uses sample content. Camera and microphone are off."; return }
        guard !isWalking,
              cameraRequestID == nil else {
            return
        }

        let status = AVCaptureDevice.authorizationStatus(
            for: .video
        )

        cameraRestricted = status == .restricted

        switch status {
        case .authorized:
            beginSession()

        case .notDetermined:
            let id = UUID()
            cameraRequestID = id

            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard cameraRequestID == id else {
                        return
                    }

                    cameraRequestID = nil

                    if granted {
                        beginSession()
                    } else {
                        showCameraAlert = true
                    }
                }
            }

        case .denied:
            showCameraAlert = true

        default:
            break
        }
    }

    private func beginSession() {
        description = ""
        target = nil
        lastDirection = nil
        emptyFrames = 0

        isWalking = true
        audioInterrupted = false
        cameraManager.start()
        recognition.requestPermissions()
    }

    private func stop() {
        // Ignore responses from work that was canceled.
        cameraRequestID = nil
        sceneID = nil

        sceneTask?.cancel()
        sceneTask = nil

        isWalking = false
        audioInterrupted = false
        target = nil
        lastDirection = nil

        cameraManager.stop()
        speech.stop()
        recognition.stopListening()
    }

    private func resumeListening() {
        guard !isDemo else { return }
        guard isWalking,
              !audioInterrupted,
              sceneID == nil,
              !speech.isSpeaking else {
            return
        }

        recognition.requestPermissions()
    }

    private func handleCommand(_ command: String) {
        guard isWalking else { return }

        if parser.isStop(command) {
            stop()
            return
        }

        if parser.isSceneDescription(command) {
            describeScene()
            return
        }

        guard let object = parser.target(from: command),
              sceneID == nil else {
            resumeListening()
            return
        }

        if isDemo { target = object; return }
        target = object
        lastDirection = nil
        emptyFrames = 0
        lastAnnouncement = Date()

        speech.speak(text: "Looking for a \(object).")
    }

    private func announceTarget(_ objects: [DetectedObject]) {
        guard isWalking,
              !audioInterrupted,
              sceneID == nil,
              !speech.isSpeaking,
              let target else {
            return
        }

        guard let match = objects
            .filter({ $0.label == target })
            .max(by: { $0.confidence < $1.confidence }) else {

            emptyFrames += 1

            // Announce again if the object disappears and returns.
            if emptyFrames >= 3 {
                lastDirection = nil
            }

            return
        }

        emptyFrames = 0

        guard match.direction != lastDirection,
              Date().timeIntervalSince(lastAnnouncement) >= 3 else {
            return
        }

        lastDirection = match.direction
        lastAnnouncement = Date()

        let position: String

        switch match.direction {
        case "Left":
            position = "to your left"
        case "Right":
            position = "to your right"
        default:
            position = "ahead"
        }

        speech.speak(
            text: "\(target.capitalized) \(position)."
        )
    }

    private func describeScene() {
        if isDemo { description = "Sample description: A chair is ahead, and a bottle is to the left."; return }
        guard isWalking,
              !audioInterrupted,
              sceneID == nil else {
            return
        }

        target = nil

        let id = UUID()
        sceneID = id
        description = "Capturing image…"

        recognition.stopListening()
        speech.stop()
        speech.speak(text: "Describing the scene.")

        cameraManager.captureSnapshot { data in
            guard isWalking,
                  sceneID == id else {
                return
            }

            guard let data else {
                sceneID = nil
                description = "Could not capture an image."

                speech.speak(
                    text: "I couldn't capture an image. Please try again."
                )
                return
            }

            description = "Describing the scene…"

            sceneTask = Task { @MainActor in
                do {
                    let text = try await gemini.describe(
                        jpegData: data
                    )

                    guard !Task.isCancelled,
                          isWalking,
                          sceneID == id else {
                        return
                    }

                    sceneID = nil
                    sceneTask = nil
                    description = text

                    speech.speak(
                        text: text
                    )
                } catch {
                    guard !Task.isCancelled,
                          isWalking,
                          sceneID == id else {
                        return
                    }

                    sceneID = nil
                    sceneTask = nil
                    // Report the cloud failure, then give a basic local summary.
                    let summary = localDetectionSummary()
                    description = error.localizedDescription + "\n\n" + summary
                    speech.speak(text: summary)
                }
            }
        }
    }

    private func pauseAudio() {
        audioInterrupted = true
        recognition.stopListening()
        speech.stop()
        sceneID = nil
        sceneTask?.cancel()
        sceneTask = nil
        target = nil
        description = "Audio was interrupted. Tap Resume Voice when ready."
    }

    private func localDetectionSummary() -> String {
        let aliases = [
            "tvmonitor": "television",
            "diningtable": "dining table",
            "pottedplant": "potted plant",
            "motorbike": "motorcycle",
            "aeroplane": "airplane",
        ]
        let imageBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let objects = cameraManager.detectedObjects
            .filter { $0.confidence >= 0.5 && $0.boundingBox.intersects(imageBounds) }
            .sorted { $0.confidence > $1.confidence }
        var phrases: [String] = []
        var reported: Set<String> = []

        for object in objects {
            let key = object.label + ":" + object.direction
            guard reported.insert(key).inserted else { continue }
            let name = aliases[object.label] ?? object.label
            let position = object.direction == "Left" ? "to your left" :
                object.direction == "Right" ? "to your right" : "ahead"
            phrases.append("\(name) \(position)")
            if phrases.count == 3 { break }
        }

        guard !phrases.isEmpty else {
            return "I couldn't get a full scene description. No recognizable objects are currently detected."
        }
        return "I couldn't get a full scene description. The camera currently detects: " +
            phrases.joined(separator: ", ") + "."
    }

    private func actionButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 64
                )
                .foregroundStyle(.white)
                .background(
                    color,
                    in: RoundedRectangle(cornerRadius: 18)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }

    private func openSettings() {
        if let url = URL(
            string: UIApplication.openSettingsURLString
        ) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}
