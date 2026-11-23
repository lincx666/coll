import AVFoundation
import UIKit

/// 相机封装。只做一件事：开预览、拍一张、把 `UIImage` 交出去。
///
/// 不用 CoreImage，因为这台机器（A9 / iOS 15.8.8）上 `CIContext`
/// 构造就段错误。滤镜在拍照之后用 CPU 处理。
final class CameraController: NSObject, ObservableObject {

    enum Status {
        case idle, unauthorized, ready, failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published var flashOn = false

    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "leicalab.camera.session")
    private var photoContinuation: ((UIImage?) -> Void)?
    private var configured = false

    // MARK: - 权限 + 启动

    func requestAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.start()
                    } else {
                        self?.status = .unauthorized
                    }
                }
            }
        default:
            status = .unauthorized
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                guard self.configure() else { return }
                self.configured = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.status = .ready }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - 配置

    private func configure() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // 后置摄像头
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.status = .failed("找不到后置摄像头")
            }
            return false
        }

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.status = .failed("无法添加摄像头输入")
            }
            return false
        }

        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.status = .failed("无法添加照片输出")
            }
            return false
        }

        session.commitConfiguration()
        return true
    }

    // MARK: - 拍照

    func capture(completion: @escaping (UIImage?) -> Void) {
        guard status.isReadyForCapture else {
            completion(nil)
            return
        }
        photoContinuation = completion

        let settings = AVCapturePhotoSettings()
        if output.supportedFlashModes.contains(.on) {
            settings.flashMode = flashOn ? .on : .off
        }

        // 让照片方向跟预览一致
        if let conn = output.connection(with: .video),
           conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }

        output.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Status 便捷判断

extension CameraController.Status {
    var isReadyForCapture: Bool {
        if case .ready = self { return true }
        return false
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        defer { photoContinuation = nil }

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.photoContinuationPass(nil) }
            return
        }

        // 修正方向：swiftui 里画的时候需要 .up
        let fixed = Self.normalized(image)
        DispatchQueue.main.async { self.photoContinuationPass(fixed) }
    }

    private func photoContinuationPass(_ image: UIImage?) {
        photoContinuation?(image)
    }

    /// 把 EXIF 方向烘焙进像素，方便后续处理
    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
