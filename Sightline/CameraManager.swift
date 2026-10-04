// AVFoundation provides the camera and video-capture tools.
import AVFoundation
import QuartzCore
import Combine

// This object manages the camera.
//
// NSObject: the base class needed for this delegate setup.
// AVCaptureVideoDataOutputSampleBufferDelegate:
// lets this object receive video frames from AVFoundation.
class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {

    // Coordinates capture: connects the camera input to outputs.
    // Your preview also uses this session to display live video.
    let session = AVCaptureSession()
    
    private var hasPrintedFrameSize = false
    
    private let objectDetector = ObjectDetector()
    
    private var lastDetectionTime: CFTimeInterval = 0
    
    @Published private(set) var detectedObjects: [DetectedObject] = []

    // Remembers whether setup succeeded.
    // Stopping capture doesn't remove the input/output,
    // so we only need to configure this session once.
    private var isConfigured = false

    // Runs camera setup, starting, and stopping one task at a time.
    // This keeps potentially slow camera work off the UI's main thread.
    private let sessionQueue = DispatchQueue(label: "sightline.camera")

    // Delivers frames to our processing method one at a time,
    // separately from the camera start/stop work.
    private let frameQueue = DispatchQueue(label: "sightline.frames")

    // Gives our code access to individual video frames.
    // The preview alone displays video but doesn't deliver frames to us.
    private let videoOutput = AVCaptureVideoDataOutput()

    // Called after ContentView confirms camera permission.
    func start() {
        // Schedule this work on the camera queue.
        // "self" refers to this CameraManager instance.
        sessionQueue.async {
            self.configureSession()

            // Start only if setup succeeded and capture isn't running.
            // && means "and"; ! means "not".
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    // Called when the user taps Stop or the view disappears.
    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // AVFoundation calls this automatically when it delivers a frame.
    // We don't call this method ourselves.
    // It runs on frameQueue because of setSampleBufferDelegate below.
    func captureOutput(
        _ output: AVCaptureOutput,             // Which output sent the frame.
        didOutput sampleBuffer: CMSampleBuffer, // Image data plus timing/metadata.
        from connection: AVCaptureConnection   // The capture connection used.
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        if hasPrintedFrameSize == false {
            print("Width: ", width, "Height: ", height)
            hasPrintedFrameSize = true
        }
        
        let now = CACurrentMediaTime()

        guard now - lastDetectionTime >= 0.5 else {
            return
        }

        lastDetectionTime = now

        let objects = objectDetector.detect(
            pixelBuffer: pixelBuffer,
            orientation: .right
        )

        // Update UI-facing data on the main queue.
        DispatchQueue.main.async {
            self.detectedObjects = objects
        }
        
    }

    // Builds the connection between the camera and video output.
    // "private" means this is only called from inside CameraManager.
    private func configureSession() {

        // Don't add the same camera input/output again.
        if isConfigured == true {
            return
        }

        // Find the rear wide-angle camera.
        // The result is optional because a suitable camera may not exist.
        // "guard let" unwraps it or exits the function if it's missing.
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            return
        }

        // Diagnostic message shown in Xcode's console.
        print(camera.localizedName)

        // Drop late frames if processing can't keep up.
        // This helps avoid building a backlog of outdated images.
        videoOutput.alwaysDiscardsLateVideoFrames = true

        // Send frame callbacks to this CameraManager on frameQueue.
        // This connects videoOutput to captureOutput(...) above.
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)

        do {
            // Wrap the physical camera as an input the session can use.
            // "try" is required because creating the input can fail.
            let input = try AVCaptureDeviceInput(device: camera)

            // Confirm the session accepts both before adding them.
            if session.canAddInput(input) &&
                session.canAddOutput(videoOutput) {

                // Camera → session.
                session.addInput(input)

                // Session → frame-delivery output.
                session.addOutput(videoOutput)
                
                frameQueue.async {
                    self.objectDetector.loadModel()
                }

                // Setup succeeded; future starts can reuse it.
                isConfigured = true
            } else {
                print("Could not add camera input or output")
            }

        } catch {
            // Handles an error thrown while creating the camera input.
            print("Could not create a camera input:", error)
        }
    }
}
