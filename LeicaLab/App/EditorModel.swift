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

    /// 拖动强度滑块会连发很多次渲染请求，用递增 token 丢弃过期结果
    private var renderToken = 0

    init() {
        self.library = FilterLibrary(catalog: AppCatalog.load())
    }

    // MARK: - 中文名

    /// LUT 的中文显示名（来自 lut_names_zh.json）
    func displayName(for lut: LUTEntry) -> String {
        Self.chineseNames[lut.id] ?? lut.displayName
    }

    /// HALD 滤镜的中文名就是原包里的名字（本来就是中文）
    func displayName(for hald: HALDEntry) -> String {
        hald.displayName
    }

    /// 当前选中滤镜的显示名
    var currentFilterName: String {
        if let hald = selectedHALD { return displayName(for: hald) }
        if let lut = selectedLUT { return displayName(for: lut) }
        return ""
    }

    private static let chineseNames: [String: String] = {
        guard let url = BundleResource.url(name: "lut_names_zh", ext: "json", subdirectories: ["Resources", nil]),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }()

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
                RenderPipeline().preview(original, settings: settings)
            }.value

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
            let out = await Task.detached(priority: .userInitiated) {
                RenderPipeline().export(original, settings: settings)
            }.value

            self.isRendering = false
            self.saveToAlbum(out) { ok, msg in
                if let msg { self.exportMessage = msg }
                _ = ok
            }
        }
    }

    /// 存相册。回调在主线程。
    func saveToAlbum(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.96) else {
            completion(false, "编码失败")
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(false, "没有相册写入权限") }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { ok, err in
                DispatchQueue.main.async {
                    completion(ok, ok ? "已保存到相册 ♪" : (err?.localizedDescription ?? "保存失败"))
                }
            }
        }
    }
}
