import SwiftUI
import Photos

/// 全局状态：当前照片、滤镜、相框、导出。
@MainActor
final class EditorModel: ObservableObject {

    // 资源
    let library: FilterLibrary

    // 原图
    @Published var originalImage: UIImage?
    @Published var metadata: PhotoMetadata.Info?

    // 选择
    @Published var selectedLUT: LUTEntry?
    @Published var selectedHALD: HALDEntry?
    @Published var selectedFrame: FrameEntry?
    @Published var intensity: Double = 1.0

    // 结果
    @Published var previewImage: UIImage?
    @Published var isRendering = false
    @Published var exportMessage: String?

    /// 拖动强度滑块会连发很多次渲染请求，用递增 token 丢弃过期结果，
    /// 保证总是最后一次请求的图落到界面上。
    private var renderToken = 0

    init() {
        self.library = FilterLibrary(catalog: AppCatalog.load())
    }

    // MARK: - 加载

    func load(_ image: UIImage) {
        originalImage = image
        metadata = PhotoMetadata.read(from: image)
        refreshPreview()
    }

    func clear() {
        originalImage = nil
        metadata = nil
        selectedLUT = nil
        selectedHALD = nil
        selectedFrame = nil
        previewImage = nil
    }

    // MARK: - 选择

    func pick(lut: LUTEntry?) {
        selectedLUT = lut
        if lut != nil { selectedHALD = nil }
        refreshPreview()
    }

    func pick(hald: HALDEntry?) {
        selectedHALD = hald
        if hald != nil { selectedLUT = nil }
        refreshPreview()
    }

    func pick(frame: FrameEntry?) {
        selectedFrame = frame
        refreshPreview()
    }

    var currentFilterName: String {
        if let hald = selectedHALD { return hald.displayName }
        if let lut = selectedLUT { return lut.displayName }
        return ""
    }

    // MARK: - 渲染

    private var settings: RenderPipeline.Settings {
        RenderPipeline.Settings(
            lutFile: selectedLUT?.id,
            haldFile: selectedHALD?.file,
            intensity: intensity,
            frameFile: selectedFrame?.file,
            filterDisplayName: currentFilterName
        )
    }

    /// 预览：降采样到 1400px 以内，够看又不卡。
    func refreshPreview() {
        guard let original = originalImage else {
            previewImage = nil
            return
        }

        renderToken += 1
        let token = renderToken
        let settings = self.settings
        isRendering = true

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                // 尺寸交给 RenderPipeline 按设备内存自适应
                RenderPipeline().preview(original, settings: settings)
            }.value

            // 期间又发了新请求 → 这次结果作废
            guard token == self.renderToken else { return }
            self.previewImage = result
            self.isRendering = false
        }
    }

    // MARK: - 导出

    func export() {
        guard let original = originalImage else { return }
        let settings = self.settings
        isRendering = true

        Task {
            let data = await Task.detached(priority: .userInitiated) { () -> Data? in
                let full = RenderPipeline().export(original, settings: settings)
                return full.jpegData(compressionQuality: 0.96)
            }.value

            self.isRendering = false
            if let data {
                self.saveToPhotos(data)
            } else {
                self.exportMessage = "编码失败"
            }
        }
    }

    private func saveToPhotos(_ data: Data) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in self.exportMessage = "没有相册写入权限" }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { ok, err in
                Task { @MainActor in
                    self.exportMessage = ok ? "已保存到相册 ♪" : (err?.localizedDescription ?? "保存失败")
                }
            }
        }
    }
}
