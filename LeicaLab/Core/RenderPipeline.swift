import UIKit
import CoreImage

/// 完整出图管线：LUT → 相框 → 导出。
///
/// 预览和导出走**同一条**管线，只是尺寸不同，所见即所得。
///
/// 针对小内存设备（iPhone SE 一代 2 GB、A9）做了自适应：
/// - 预览尺寸按屏幕像素算，不是写死的 1400
/// - 超大图导出前先限幅，避免 2 GB 设备 OOM
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
        ProcessInfo.processInfo.physicalMemory < 3 * 1024 * 1024 * 1024   // < 3 GB
    }

    /// 预览最长边：按屏幕像素算（再乘一点余量），不写死
    static var previewMaxDimension: CGFloat {
        let screen = UIScreen.main
        let pixelLongest = max(screen.bounds.width, screen.bounds.height) * screen.scale
        // 小屏设备给 1.0 倍，大屏给到 1.25 倍，避免过度渲染
        let factor: CGFloat = isConstrainedDevice ? 1.0 : 1.25
        return min(2400, max(900, pixelLongest * factor))
    }

    /// 导出最长边上限。2 GB 设备上 8000px 很容易 OOM。
    static var exportMaxDimension: CGFloat {
        isConstrainedDevice ? 4000 : 8000
    }

    // MARK: - 入口

    func preview(_ image: UIImage, settings: Settings,
                 maxDimension: CGFloat? = nil) -> UIImage {
        let limit = maxDimension ?? Self.previewMaxDimension
        let downscaled = Self.downscale(image, maxDimension: limit)
        return render(downscaled, settings: settings)
    }

    func export(_ image: UIImage, settings: Settings) -> UIImage {
        // 超大原图先限幅：SE 上 1200 万像素原图 + CIColorCube 中间缓冲会爆内存
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
        guard let cg = image.cgImage else { return nil }

        var filter: CIFilter?
        if let bin = settings.lutFile {
            filter = processor.colorCube(named: bin)
        } else if let hald = settings.haldFile {
            filter = processor.colorCube(hald: hald)
        }
        guard let filter else { return nil }

        // 统一到 sRGB，避免 P3 素材被二次解释
        let src = CIImage(cgImage: cg, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        let out = processor.apply(filter, to: src, intensity: settings.intensity)
        guard let result = processor.cgImage(from: out) else { return nil }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
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
