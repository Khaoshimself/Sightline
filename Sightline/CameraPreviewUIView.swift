//
//  CameraPreviewUIView.swift
//  Sightline
//
//  Created by Bryan on 10/3/26.
//
import UIKit
import AVFoundation

class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
