import SwiftUI
import AVFoundation

/// 把 `AVCaptureSession` 的预览层包成 SwiftUI 视图。
struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.backgroundColor = .black
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let conn = v.videoPreviewLayer.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        if let conn = uiView.videoPreviewLayer.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
    }

    /// layerClass 用 `AVCaptureVideoPreviewLayer`，尺寸自动跟随视图
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
