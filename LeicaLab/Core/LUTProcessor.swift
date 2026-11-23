import CoreImage
import UIKit

/// 把 APK 里扒出来的 LUT 应用成图像。
///
/// 两种来源：
/// - **33³ `.bin`**：直接喂 `CIColorCubeWithColorSpace`，一条 GPU 滤镜搞定。
/// - **64³ HALD PNG**：先在 CPU 侧解成 float 立方体，再走同一个滤镜。
///   （iOS 的 `CIColorCube` 只吃 data 不吃图，所以 HALD 必须解一次；结果会缓存。）
///
/// 用 `CIColorCubeWithColorSpace` 而不是 `CIColorCube`，因为前者能显式指定
/// 输入色彩空间，否则暗部和高光会偏。
final class LUTProcessor: @unchecked Sendable {

    static let shared = LUTProcessor()

    private let context: CIContext
    private let cache = NSCache<NSString, CIFilter>()

    private init() {
        let working = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        context = CIContext(options: [.workingColorSpace: working])
        cache.countLimit = 24      // 33³ ≈ 575 KB/个，24 个约 14 MB
    }

    // MARK: - 滤镜构造

    /// 33³ `.bin` → CIFilter
    func colorCube(named name: String, dimension: Int = 33) -> CIFilter? {
        let key = ("bin:" + name) as NSString
        if let hit = cache.object(forKey: key) { return hit }

        guard let url = BundleResource.lut(name),
              let data = try? Data(contentsOf: url) else { return nil }

        let expected = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
        guard data.count == expected else {
            assertionFailure("LUT \(name) 尺寸不符：\(data.count) != \(expected)")
            return nil
        }

        guard let filter = Self.makeCubeFilter(dimension: dimension, data: data) else { return nil }
        cache.setObject(filter, forKey: key)
        return filter
    }

    /// 64³ HALD PNG → CIFilter（解一次后缓存）
    func colorCube(hald fileName: String) -> CIFilter? {
        let key = ("hald:" + fileName) as NSString
        if let hit = cache.object(forKey: key) { return hit }

        guard let url = BundleResource.hald(fileName),
              let image = UIImage(contentsOfFile: url.path),
              let cg = image.cgImage,
              let data = Self.haldToCubeData(cg, level: 64),
              let filter = Self.makeCubeFilter(dimension: 64, data: data)
        else { return nil }

        cache.setObject(filter, forKey: key)
        return filter
    }

    private static func makeCubeFilter(dimension: Int, data: Data) -> CIFilter? {
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return nil }
        filter.setValue(NSNumber(value: dimension), forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(CGColorSpace(name: CGColorSpace.sRGB)!, forKey: "inputColorSpace")
        return filter
    }

    // MARK: - HALD 解码

    /// 512×512 HALD（8×8 个 64×64 slice）→ 64³ float RGBA 立方体
    ///
    /// APK 里的排布：slice 内 (x = r, y = g)，slice 序号 = b，
    /// slice 按 `b % 8` 决定列、`b / 8` 决定行。
    static func haldToCubeData(_ image: CGImage, level: Int) -> Data? {
        let w = image.width, h = image.height
        guard w == level * 8, h == level * 8 else { return nil }

        var raw = [UInt8](repeating: 0, count: w * h * 4)
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: &raw, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w * 4, space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var cube = [Float](repeating: 0, count: level * level * level * 4)
        let inv = Float(1.0 / 255.0)

        for b in 0..<level {
            let sliceX = (b % 8) * level
            let sliceY = (b / 8) * level
            for g in 0..<level {
                let row = (sliceY + g) * w * 4
                for r in 0..<level {
                    let o = row + (sliceX + r) * 4
                    let dst = ((b * level + g) * level + r) * 4
                    cube[dst + 0] = Float(raw[o + 0]) * inv
                    cube[dst + 1] = Float(raw[o + 1]) * inv
                    cube[dst + 2] = Float(raw[o + 2]) * inv
                    cube[dst + 3] = 1.0
                }
            }
        }

        return cube.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // MARK: - 应用

    /// `intensity` 0…1，用 `CIMix` 在原图和滤镜结果之间插值。
    func apply(_ filter: CIFilter, to image: CIImage, intensity: Double = 1.0) -> CIImage {
        guard let output = filter.outputImage?.cropped(to: image.extent) else { return image }
        guard intensity < 0.999 else { return output }

        guard let mix = CIFilter(name: "CIMix") else { return output }
        mix.setValue(image, forKey: kCIInputBackgroundImageKey)
        mix.setValue(output, forKey: kCIInputImageKey)
        mix.setValue(intensity, forKey: "inputAmount")
        return mix.outputImage?.cropped(to: image.extent) ?? output
    }

    func cgImage(from image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }
}
