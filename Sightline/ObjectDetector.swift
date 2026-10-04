//
//  ObjectDetector.swift
//  Sightline
//
//  Created by Bryan on 10/3/26.
//

import CoreML
import Vision
import CoreVideo
import ImageIO

class ObjectDetector {
    private var visionModel: VNCoreMLModel?
    
    func loadModel() {
        do {
            let detector = try YOLOv3TinyFP16(
                configuration: MLModelConfiguration()
            )
            visionModel = try VNCoreMLModel(for: detector.model)
            print("Detection model loaded")
            
        } catch {
            print("Could not load detection model: ", error)
            
        }
        
    }
    
    func detect (pixelBuffer: CVPixelBuffer,
                 orientation: CGImagePropertyOrientation) -> [DetectedObject]
        {
        guard let model = visionModel else {
            return []
        }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        
        do {
            
            try handler.perform([request])
            guard let detections =
                request.results as? [VNRecognizedObjectObservation] else {
                print("The request did not return object-detection results")
                return []
            }
            
            var objects: [DetectedObject] = []
            
            for detection in detections {
                guard let label = detection.labels.first else {
                    continue
                }
                if label.confidence >= 0.5 {
                    objects.append(
                        DetectedObject(
                            label: label.identifier,
                            confidence: label.confidence,
                            boundingBox: detection.boundingBox
                        )
                    )
                    print(
                        label.identifier,
                        "confidence:", label.confidence,
                        "box:", detection.boundingBox
                    )
                }
            }
            
            return objects
            
        } catch {
            
            print("Detection failed: ", error)
            return []
            
        }
        
    }
    
}
