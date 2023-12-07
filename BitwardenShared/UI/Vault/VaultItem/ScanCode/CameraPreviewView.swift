import AVFoundation
import SwiftUI
import UIKit

// MARK: - CameraPreviewView

/// A SwiftUI wrapper around `AVCaptureVideoPreviewLayer` and an `AVCaptureSession`.
///
public struct CameraPreviewView {
    // MARK: VideoPreviewView

    /// The UIView holding the `AVCaptureVideoPreviewLayer`.
    public class VideoPreviewView: UIView {
        /// The `UIView.layer` cast as `AVCaptureVideoPreviewLayer`.
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer // swiftlint:disable:this force_cast
        }

        /// The layerClass, overrided to be an `AVCaptureVideoPreviewLayer`.
        override public class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
    }

    /// The `AVCaptureSession` backing the view.
    public let session: AVCaptureSession

    /// Create a new VideoPreviewView.
    ///
    /// - Parameter session: The `AVCaptureSession` allowing for camera access.
    ///
    public init(session: AVCaptureSession) {
        self.session = session
    }
}

// MARK: UIViewRepresentable

extension CameraPreviewView: UIViewRepresentable {
    public func makeUIView(context: Context) -> VideoPreviewView {
        let viewFinder = VideoPreviewView()
        viewFinder.backgroundColor = .black
        viewFinder.videoPreviewLayer.cornerRadius = 0
        viewFinder.videoPreviewLayer.session = session
        viewFinder.videoPreviewLayer.videoGravity = .resizeAspectFill
        viewFinder.contentMode = .scaleAspectFill
        return viewFinder
    }

    public func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}
