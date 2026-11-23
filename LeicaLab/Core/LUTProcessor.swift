import CoreImage
import UIKit
import Metal

/// 把 APK 里扒出来的 LUT 应用成图像。
///
/// 两种来源：
/// - **33³ `.bin`**：直接喂 `CIColorCubeWithColorSpace`，一条 GPU 滤镜搞定。
/// - **64³ HALD PNG**：先在 CPU 侧解成 float 立方体，再走同一个滤镜。
///   解一次后缓存（每个 64³ 立方体约 1 MB，不能缓存太多）。
///
/// 用 `CIColorCubeWithColorSpace` 而不是 `CIColorCube`，因为前者能显式指定
/// 输入色彩空间，否则暗部和高光会偏。
///
/// ── 关于 `CIContext` 的线程问题（踩过的坑）──
/// iOS 15 上 `CIContext(options:)` 会去建一个 OpenGL ES 上下文，
/// 而 EAGL 上下文必须在主线程创建。如果在 `Task.detached` 里第一次访问
/// 单例（懒加载），就会在后台线程建 GL 上下文，直接 `EXC_BAD_ACCESS`
/// 段错误。
///
/// 所以这里：
/// 1. 显式用 Metal 设备建 `CIContext`（不走 GL 路径）
/// 2. 提供 `warmUp()`，由 App 启动时在主线程调一次
final class LUTProcessor: @unchecked Sendable {

    static let shared = LUTProcessor()

    private let context: CIContext
    private let cache = NSCache<NSString, CIFilter>()

    private init() {
        // 优先 Metal：A9（iPhone SE 一代）也支持 Metal，
        // 且 Metal 的 CIContext 是线程安全的，可以在任意线程创建。
        let working = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
            ?? CGColorSpaceCreateDeviceRGB()

        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: [.workingColorSpace: working])
        } else {
            // 兜底：软件渲染，慢但不会崩
            context = CIContext(options: [
                .workingColorSpace: working,
                .useSoftwareRenderer: true,
            ])
        }

        // 2 GB 设备（SE 一代）把缓存压到 6 个，其余 16 个。
        // 33³ ≈ 575 KB/个，64³ ≈ 1 MB/个。
        let constrained = ProcessInfo.processInfo.physicalMemory < 3 * 1024 * 1024 * 1024
        cache.countLimit = constrained ? 6 : 16
        cache.totalCostLimit = constrained ? 8 * 1024 * 1024 : 24 * 1024 * 1024

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }

    // MARK: - 预热

    /// 在**主线程**调一次，把 `CIContext` 建好。
    ///
    /// iOS 15 上 `CIContext` 的初始化路径会碰 OpenGL，必须在主线程完成。
    /// App 启动时调用，之后后台线程才能安全访问 `shared`。
    static func warmUp() {
        _ = shared.context
    }

    // MARK: - 滤镜构造

    /// 33³ `.bin` → CIFilter
    func colorCube(named name: String, dimension: Int = 33) -> CIFilter? {
        let key = ("bin:" + name) as NSString
        if let hit = cache.object(forKey: key) { return hit }

        guard let url = BundleResource.lut(name) else { return nil }
        guard let data = Self.memoryMappedData(at: url) else { return nil }

        let expected = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
        guard data.count == expected else {
            assertionFailure("LUT \(name) 尺寸不符：\(data.count) != \(expected)")
            return nil
        }

        guard let filter = Self.makeCubeFilter(dimension: dimension, data: data) else { return nil }
        // cost 按字节算，配合 totalCostLimit
        cache.setObject(filter, forKey: key, cost: data.count)
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

        cache.setObject(filter, forKey: key, cost: data.count)
        return filter
    }

    private static func makeCubeFilter(dimension: Int, data: Data) -> CIFilter? {
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return nil }
        filter.setValue(NSNumber(value: dimension), forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(CGColorSpace(name: CGColorSpace.sRGB)!, forKey: "inputColorSpace")
        return filter
    }

    /// 用 memory-mapped 读取：575 KB 的 LUT 不必整个复制进堆，
    /// 2 GB 设备上能省不少峰值内存。
    private static func memoryMappedData(at url: URL) -> Data? {
        if let mapped = try? Data(contentsOf: url, options: .alwaysMapped),
           mapped.count > 0 {
            return mapped
        }
        return try? Data(contentsOf: url)
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

    /// 在指定范围渲染（柔焦背景用，需要比原图大一圈）
    func render(_ image: CIImage, extent: CGRect) -> CGImage? {
        context.createCGImage(image, from: extent)
    }
}
