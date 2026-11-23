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

    /// 滤镜缩略图缓存：LUT id → 用测试色块渲染出来的小图。
    ///
    /// 放在 Model 里而不是 View 的 @State，是因为生成是异步的，
    /// 放在 struct 的 @State 里容易被闭包捕获成快照，写不回去。
    @Published private(set) var thumbnails: [String: UIImage] = [:]
    private var thumbTask: Task<Void, Never>?
    private static let swatchCache = NSCache<NSString, UIImage>()

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

    // MARK: - 缩略图

    /// 96×96 彩色测试块（肤色 + 天空 + 绿叶 + 暖红 + 灰阶）
    static func swatch() -> UIImage {
        if let hit = swatchCache.object(forKey: "swatch") { return hit }

        let size = CGSize(width: 96, height: 96)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let gc = ctx.cgContext
            let cols: [UIColor] = [
                UIColor(red: 0.82, green: 0.65, blue: 0.52, alpha: 1),
                UIColor(red: 0.35, green: 0.55, blue: 0.78, alpha: 1),
                UIColor(red: 0.28, green: 0.48, blue: 0.26, alpha: 1),
                UIColor(red: 0.72, green: 0.32, blue: 0.26, alpha: 1),
            ]
            let w = size.width / CGFloat(cols.count)
            for (i, c) in cols.enumerated() {
                gc.setFillColor(c.cgColor)
                gc.fill(CGRect(x: CGFloat(i) * w, y: 0, width: w, height: size.height * 0.66))
            }
            for i in 0..<8 {
                let g = CGFloat(i) / 7.0
                gc.setFillColor(UIColor(white: g, alpha: 1).cgColor)
                gc.fill(CGRect(x: CGFloat(i) * size.width / 8,
                               y: size.height * 0.66,
                               width: size.width / 8,
                               height: size.height * 0.34))
            }
        }
        swatchCache.setObject(img, forKey: "swatch")
        return img
    }

    func thumbnail(for lut: LUTEntry) -> UIImage? {
        thumbnails[lut.id]
    }

    /// 逐个生成缩略图，算完一个就发一个，UI 能看着陆续出现。
    ///
    /// 之前的写法是「全部算完一次性赋值」，116 个 LUT 在 A9 上要十几秒，
    /// 表现就是一直转圈。
    func ensureThumbnails(for luts: [LUTEntry]) {
        thumbTask?.cancel()

        let need = luts.filter { thumbnails[$0.id] == nil }
        guard !need.isEmpty else { return }

        let base = Self.swatch()

        thumbTask = Task { [weak self] in
            for lut in need {
                if Task.isCancelled { return }

                let image: UIImage? = await Task.detached(priority: .userInitiated) {
                    RenderPipeline().export(base, settings: .init(
                        lutFile: lut.id, haldFile: nil, intensity: 1,
                        frameFile: nil, filterDisplayName: ""
                    ))
                }.value

                if Task.isCancelled { return }
                guard let self, let image else { continue }
                await MainActor.run { self.thumbnails[lut.id] = image }
            }
        }
    }

    func cancelThumbnails() {
        thumbTask?.cancel()
        thumbTask = nil
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
