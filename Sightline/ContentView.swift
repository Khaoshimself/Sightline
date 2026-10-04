import AVFoundation
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isWalking = false
    @State private var status: AVAuthorizationStatus =
        AVCaptureDevice.authorizationStatus(for: .video)
    @State private var showCameraDeniedAlert = false
    @StateObject private var cameraManager = CameraManager()

    // Check permission and update state.
    func checkCameraPermission() {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        status = current

        switch current {
        case .authorized:
            isWalking = true
            cameraManager.start()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        status = .authorized
                        isWalking = true
                        cameraManager.start()
                    } else {
                        status = .denied
                        isWalking = false
                        cameraManager.stop()
                        showCameraDeniedAlert = true
                    }
                }
            }

        case .denied:
            isWalking = false
            showCameraDeniedAlert = true

        case .restricted:
            isWalking = false

        @unknown default:
            isWalking = false
        }
    }

    // Display views based on the current state.
    var body: some View {
        VStack {
            Text("Sightline")

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

            Button("Stop") {
                isWalking = false
                cameraManager.stop()
            }

            if isWalking {
                Text("Walking Mode activated")
                Text("Objects detected: \(cameraManager.detectedObjects.count)")
            } else {
                Text("Idle")
            }

            if status == .restricted {
                Text("Camera access is restricted on this device.")
            }
        }
        .padding()
        
        .onDisappear {
            isWalking = false
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

