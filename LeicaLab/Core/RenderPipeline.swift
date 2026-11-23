import CoreImage
import UIKit

/// 完整出图管线：LUT → 相框 → 导出。
///
/// 预览和导出走**同一条**管线，只是 `maxDimension` 不同，所见即所得。
///
/// 标记 `@unchecked Sendable`：内部只持有两个无状态的渲染器 + 一个线程安全的
/// 缓存，`render` 本身不写任何实例状态，可以安全地在后台线程跑。
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

    // MARK: - 入口

    func preview(_ image: UIImage, settings: Settings, maxDimension: CGFloat = 1400) -> UIImage {
        let downscaled = Self.downscale(image, maxDimension: maxDimension)
        return render(downscaled, settings: settings)
    }

    func export(_ image: UIImage, settings: Settings) -> UIImage {
        render(image, settings: settings)
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
