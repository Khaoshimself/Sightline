//
//  CameraPreviewView.swift
//  Sightline
//
//  Created by Bryan on 10/3/26.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        
        // Assign session to view.previewLayer.session.
        view.previewLayer.session = session
        // Set view.previewLayer.videoGravity to .resizeAspectFill.
        view.previewLayer.videoGravity = .resizeAspectFill
        
        return view
    }
    
    func updateUIView(
        _ uiView: CameraPreviewUIView,
        context: Context
    ) {
        // Assign session to uiView.previewLayer.session.
        uiView.previewLayer.session = session
    }
}

#Preview {
    CameraPreviewView(session: AVCaptureSession())
}
