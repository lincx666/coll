import AVFoundation
import UIKit

/// 相机封装。只做一件事：开预览、拍一张、把 `UIImage` 交出去。
///
/// 不用 CoreImage —— 这台机器（A9 / iOS 15.8.8）上 `CIContext` 构造就段错误。
/// 滤镜在拍照之后用 CPU 处理。
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

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = .failed("找不到后置摄像头") }
            return false
        }

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = .failed("无法添加摄像头输入") }
            return false
        }

        if session.canAddOutput(output) {
            session.addOutput(output)
            output.isHighResolutionCaptureEnabled = true
        } else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = .failed("无法添加照片输出") }
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

        // 方向要在 sessionQueue 上设，主线程改 connection 属性会阻塞
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let conn = self.output.connection(with: .video) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }

            self.photoContinuation = completion

            let settings = AVCapturePhotoSettings()
            if self.output.supportedFlashModes.contains(.on) {
                settings.flashMode = self.flashOn ? .on : .off
            }
            settings.isHighResolutionPhotoEnabled = true

            self.output.capturePhoto(with: settings, delegate: self)
        }
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
        // 先把回调取出来再置空。
        // 这里不能用 defer —— 下面的 completion 是异步派发到主线程的，
        // 用 defer 会在函数返回时就把 continuation 清掉，
        // 主线程执行时已经是 nil，表现就是「按了快门没反应」。
        let completion = photoContinuation
        photoContinuation = nil

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { completion?(nil) }
            return
        }

        let fixed = Self.normalized(image)
        DispatchQueue.main.async { completion?(fixed) }
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
