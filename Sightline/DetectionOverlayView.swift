import SwiftUI

struct DetectionOverlayView: View {
    // Results from the latest processed camera frame.
    let detections: [DetectedObject]

    var body: some View {
        // Read the size of the camera preview we're drawing over.
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Draw one rectangle for each detection.
                ForEach(detections.indices, id: \.self) { index in
                    let detection = detections[index]

                    // Convert the model's box into screen coordinates.
                    let rect = displayRect(
                        for: detection.boundingBox,
                        in: geometry.size
                    )

                    Rectangle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(
                            width: rect.width,
                            height: rect.height
                        )
                        // Position uses the rectangle's center.
                        .position(
                            x: rect.midX,
                            y: rect.midY
                        )
                    
                    Text("\(detection.label) — \(detection.direction)")
                        .font(.caption.bold())
                        .padding(4)
                        .background(Color.black.opacity(0.75))
                        .foregroundStyle(Color.green)
                        .position(
                            x: rect.midX,
                            y: max(12, rect.minY - 12)
                        )
                    
                }
            }
        }
        .allowsHitTesting(false)
        .clipped()
    }

    private func displayRect(
        for box: CGRect,
        in previewSize: CGSize
    ) -> CGRect {
        // Temporary dimensions for our upright-phone test:
        // the 1920 × 1080 camera frame is oriented using .right.
        let imageWidth: CGFloat = 1080
        let imageHeight: CGFloat = 1920

        // Match the camera preview's aspect-fill scaling.
        let scale = max(
            previewSize.width / imageWidth,
            previewSize.height / imageHeight
        )

        let displayWidth = imageWidth * scale
        let displayHeight = imageHeight * scale

        // Aspect fill crops any extra image area equally on both sides.
        let cropX = (displayWidth - previewSize.width) / 2
        let cropY = (displayHeight - previewSize.height) / 2

        return CGRect(
            x: box.minX * displayWidth - cropX,

            // Convert Vision's bottom-left origin to a top-left origin.
            y: (1 - box.maxY) * displayHeight - cropY,

            width: box.width * displayWidth,
            height: box.height * displayHeight
        )
    }
}

#Preview {
    DetectionOverlayView(detections: [])
        .frame(height: 400)
}
