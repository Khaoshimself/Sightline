//
//  DetectedObject.swift
//  Sightline
//
//  Created by Bryan on 10/3/26.
//

import CoreGraphics

struct DetectedObject {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
    var direction: String {
        if boundingBox.midX < 0.33 {
            return "Left"
        } else if boundingBox.midX > 0.67 {
            return "Right"
        } else {
            return "Ahead"
        }
    }
}
