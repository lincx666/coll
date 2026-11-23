import UIKit

/// 完整出图管线：LUT → 相框 → 导出。
///
/// 预览和导出走**同一条**管线，只是尺寸不同，所见即所得。
///
/// 针对小内存设备（iPhone SE 一代 2 GB、A9）做了自适应：
/// - 预览尺寸按屏幕像素算
/// - 超大图导出前先限幅，避免 2 GB 设备 OOM
/// - LUT 全程 CPU 运算（这台机器上 CoreImage 会崩，见 LUTProcessor 注释）
final class RenderPipeline: @unchecked Sendable {

    struct Settings: Equatable, Sendable {
        var lutFile: String?            // .bin 文件名（不带扩展）
        var haldFile: String?           // HALD PNG 文件名（带扩展）
        var intensity: Double = 1.0
        var frameFile: String?          // 相框模板 json
        var filterDisplayName: String = ""
    }

    private let processor = LUTProcessor.shared
    private let renderer = FrameRenderer()

    // MARK: - 设备档位

    /// 小内存设备：预览和导出都要更保守
    static var isConstrainedDevice: Bool {
        ProcessInfo.processInfo.physicalMemory < 3 * 1024 * 1024 * 1024
    }

    /// 预览最长边：按屏幕像素算
    static var previewMaxDimension: CGFloat {
        let screen = UIScreen.main
        let pixelLongest = max(screen.bounds.width, screen.bounds.height) * screen.scale
        let factor: CGFloat = isConstrainedDevice ? 1.0 : 1.25
        return min(2400, max(900, pixelLongest * factor))
    }

    /// 导出最长边上限。CPU LUT 是逐像素运算，A9 上不宜太大。
    static var exportMaxDimension: CGFloat {
        isConstrainedDevice ? 3000 : 6000
    }

    // MARK: - 入口

    func preview(_ image: UIImage, settings: Settings,
                 maxDimension: CGFloat? = nil) -> UIImage {
        let limit = maxDimension ?? Self.previewMaxDimension
        let downscaled = Self.downscale(image, maxDimension: limit)
        return render(downscaled, settings: settings)
    }

    func export(_ image: UIImage, settings: Settings) -> UIImage {
        let capped = Self.downscale(image, maxDimension: Self.exportMaxDimension)
        return render(capped, settings: settings)
    }

    // MARK: - 核心

    private func render(_ image: UIImage, settings: Settings) -> UIImage {
        var current = image

        if let withLUT = applyLUT(current, settings: settings) {
            current = withLUT
        }

        if let frameFile = settings.frameFile,
           let template = FrameTemplate.load(file: frameFile) {
            var ctx = PhotoMetadata.context(from: PhotoMetadata.read(from: image),
                                            filterName: settings.filterDisplayName)
            if ctx.deviceModel.isEmpty { ctx.deviceModel = UIDevice.current.model }
            current = renderer.render(current, template: template, context: ctx)
        }

        return current
    }

    private func applyLUT(_ image: UIImage, settings: Settings) -> UIImage? {
        var cube: LUTProcessor.Cube?
        if let bin = settings.lutFile {
            cube = processor.cube(named: bin)
        } else if let hald = settings.haldFile {
            cube = processor.cube(hald: hald)
        }
        guard let cube else { return nil }
        return processor.apply(cube, to: image, intensity: settings.intensity)
    }

    // MARK: - 工具

    /// 按最长边等比缩小；已经够小就原样返回。
    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let ratio = maxDimension / longest
        let target = CGSize(width: (size.width * ratio).rounded(),
                            height: (size.height * ratio).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
