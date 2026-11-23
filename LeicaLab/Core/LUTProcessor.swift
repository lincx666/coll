import UIKit
import CoreGraphics

/// 把 LUT 应用到图像上 —— **纯 CPU 实现，不依赖 CoreImage**。
///
/// ── 为什么不用 CIContext ──
/// 在这台越狱的 iPhone SE（A9 / iOS 15.8.8）上，`CIContext` 初始化时会在
/// `CI::GLContext::GLContext` 里对空指针解引用，直接 `EXC_BAD_ACCESS`。
/// 即使指定 `mtlDevice:` 也会走 `-[CIContext initWithOptions:]`，
/// 说明 `MTLCreateSystemDefaultDevice()` 在这套环境里返回 nil，
/// 于是回落到 EAGL 路径并崩溃。
///
/// 结论：这台机器上 CoreImage 用不了。改成 CPU 三线性插值，
/// 慢一点但绝对不崩。
final class LUTProcessor: @unchecked Sendable {

    static let shared = LUTProcessor()

    /// 一个 3D LUT，数据是 `dim³ × 3` 的 8bit RGB，r 变化最快。
    struct Cube {
        let dim: Int
        let data: [UInt8]          // dim^3 * 3 字节

        var byteCount: Int { data.count }
    }

    private let cache = NSCache<NSString, Box>()

    /// NSCache 只收 class
    private final class Box {
        let cube: Cube
        init(_ c: Cube) { cube = c }
    }

    private init() {
        // 2 GB 设备（SE 一代）压到 4 个。33³×3 ≈ 108 KB，64³×3 ≈ 768 KB。
        let constrained = ProcessInfo.processInfo.physicalMemory < 3 * 1024 * 1024 * 1024
        cache.countLimit = constrained ? 4 : 12
        cache.totalCostLimit = constrained ? 4 * 1024 * 1024 : 16 * 1024 * 1024

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }

    // MARK: - 加载

    /// 33³ `.bin`（float32 RGBA 立方体）→ Cube
    func cube(named name: String, dimension: Int = 33) -> Cube? {
        let key = ("bin:" + name) as NSString
        if let hit = cache.object(forKey: key) { return hit.cube }

        guard let url = BundleResource.lut(name),
              let raw = try? Data(contentsOf: url) else { return nil }

        let expected = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
        guard raw.count == expected else {
            assertionFailure("LUT \(name) 尺寸不符：\(raw.count) != \(expected)")
            return nil
        }

        // float32 RGBA → UInt8 RGB
        var out = [UInt8](repeating: 0, count: dimension * dimension * dimension * 3)
        raw.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let floats = ptr.bindMemory(to: Float.self)
            var src = 0
            var dst = 0
            let n = dimension * dimension * dimension
            for _ in 0..<n {
                let r = max(0, min(1, floats[src]))
                let g = max(0, min(1, floats[src + 1]))
                let b = max(0, min(1, floats[src + 2]))
                out[dst]     = UInt8((r * 255).rounded())
                out[dst + 1] = UInt8((g * 255).rounded())
                out[dst + 2] = UInt8((b * 255).rounded())
                src += 4
                dst += 3
            }
        }

        let cube = Cube(dim: dimension, data: out)
        cache.setObject(Box(cube), forKey: key, cost: out.count)
        return cube
    }

    /// 64³ HALD PNG → Cube
    func cube(hald fileName: String) -> Cube? {
        let key = ("hald:" + fileName) as NSString
        if let hit = cache.object(forKey: key) { return hit.cube }

        guard let url = BundleResource.hald(fileName),
              let image = UIImage(contentsOfFile: url.path),
              let cg = image.cgImage,
              let cube = Self.haldToCube(cg, level: 64) else { return nil }

        cache.setObject(Box(cube), forKey: key, cost: cube.byteCount)
        return cube
    }

    /// 512×512 HALD（8×8 个 64×64 slice）→ 64³ RGB 立方体
    ///
    /// APK 里的排布：slice 内 (x = r, y = g)，slice 序号 = b，
    /// slice 按 `b % 8` 决定列、`b / 8` 决定行。
    static func haldToCube(_ image: CGImage, level: Int) -> Cube? {
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

        var out = [UInt8](repeating: 0, count: level * level * level * 3)
        for b in 0..<level {
            let sliceX = (b % 8) * level
            let sliceY = (b / 8) * level
            for g in 0..<level {
                let row = (sliceY + g) * w * 4
                for r in 0..<level {
                    let o = row + (sliceX + r) * 4
                    let dst = ((b * level + g) * level + r) * 3
                    out[dst]     = raw[o]
                    out[dst + 1] = raw[o + 1]
                    out[dst + 2] = raw[o + 2]
                }
            }
        }
        return Cube(dim: level, data: out)
    }

    // MARK: - 应用

    /// 对整张图做三线性插值。`intensity` 0…1 控制混合比例。
    func apply(_ cube: Cube, to image: UIImage, intensity: Double = 1.0) -> UIImage {
        guard let cg = image.cgImage else { return image }

        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return image }

        // 统一成 RGBA8 sRGB，方向信息在绘制时被烘焙进去
        let bytesPerRow = w * 4
        var src = [UInt8](repeating: 0, count: bytesPerRow * h)
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: &src, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return image }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let dim = cube.dim
        let last = dim - 1
        // 0…255 → 0…last 的定点缩放（16.16）
        let scaleFix = (last << 16) / 255
        let blend = max(0.0, min(1.0, intensity))
        let blendFix = Int(blend * 256)

        src.withUnsafeMutableBufferPointer { buf in
            guard let p = buf.baseAddress else { return }
            cube.data.withUnsafeBufferPointer { lut in
                guard let L = lut.baseAddress else { return }

                let plane = dim * dim * 3
                let rowStride = dim * 3

                for y in 0..<h {
                    var idx = y * bytesPerRow
                    for _ in 0..<w {
                        let r = Int(p[idx])
                        let g = Int(p[idx + 1])
                        let b = Int(p[idx + 2])

                        let fr = r * scaleFix
                        let fg = g * scaleFix
                        let fb = b * scaleFix

                        let r0 = fr >> 16, g0 = fg >> 16, b0 = fb >> 16
                        let r1 = r0 < last ? r0 + 1 : last
                        let g1 = g0 < last ? g0 + 1 : last
                        let b1 = b0 < last ? b0 + 1 : last
                        let tr = fr & 0xFFFF, tg = fg & 0xFFFF, tb = fb & 0xFFFF
                        let itr = 0x10000 - tr, itg = 0x10000 - tg, itb = 0x10000 - tb

                        // 8 个角
                        let o000 = (b0 * plane) + (g0 * rowStride) + (r0 * 3)
                        let o100 = (b0 * plane) + (g0 * rowStride) + (r1 * 3)
                        let o010 = (b0 * plane) + (g1 * rowStride) + (r0 * 3)
                        let o110 = (b0 * plane) + (g1 * rowStride) + (r1 * 3)
                        let o001 = (b1 * plane) + (g0 * rowStride) + (r0 * 3)
                        let o101 = (b1 * plane) + (g0 * rowStride) + (r1 * 3)
                        let o011 = (b1 * plane) + (g1 * rowStride) + (r0 * 3)
                        let o111 = (b1 * plane) + (g1 * rowStride) + (r1 * 3)

                        // 三线性插值（整数运算，最后统一右移）
                        var nr = 0, ng = 0, nb = 0
                        nr = Int(L[o000]) * itr * itg * itb
                           + Int(L[o100]) * tr  * itg * itb
                           + Int(L[o010]) * itr * tg  * itb
                           + Int(L[o110]) * tr  * tg  * itb
                           + Int(L[o001]) * itr * itg * tb
                           + Int(L[o101]) * tr  * itg * tb
                           + Int(L[o011]) * itr * tg  * tb
                           + Int(L[o111]) * tr  * tg  * tb
                        ng = Int(L[o000 + 1]) * itr * itg * itb
                           + Int(L[o100 + 1]) * tr  * itg * itb
                           + Int(L[o010 + 1]) * itr * tg  * itb
                           + Int(L[o110 + 1]) * tr  * tg  * itb
                           + Int(L[o001 + 1]) * itr * itg * tb
                           + Int(L[o101 + 1]) * tr  * itg * tb
                           + Int(L[o011 + 1]) * itr * tg  * tb
                           + Int(L[o111 + 1]) * tr  * tg  * tb
                        nb = Int(L[o000 + 2]) * itr * itg * itb
                           + Int(L[o100 + 2]) * tr  * itg * itb
                           + Int(L[o010 + 2]) * itr * tg  * itb
                           + Int(L[o110 + 2]) * tr  * tg  * itb
                           + Int(L[o001 + 2]) * itr * itg * tb
                           + Int(L[o101 + 2]) * tr  * itg * tb
                           + Int(L[o011 + 2]) * itr * tg  * tb
                           + Int(L[o111 + 2]) * tr  * tg  * tb

                        // 8 个权重乘积 × 65536³ = 2^96，除回去
                        let outR = (nr >> 48) & 0xFF
                        let outG = (ng >> 48) & 0xFF
                        let outB = (nb >> 48) & 0xFF

                        if blendFix >= 256 {
                            p[idx]     = UInt8(min(255, outR))
                            p[idx + 1] = UInt8(min(255, outG))
                            p[idx + 2] = UInt8(min(255, outB))
                        } else {
                            p[idx]     = UInt8((r * (256 - blendFix) + outR * blendFix) >> 8)
                            p[idx + 1] = UInt8((g * (256 - blendFix) + outG * blendFix) >> 8)
                            p[idx + 2] = UInt8((b * (256 - blendFix) + outB * blendFix) >> 8)
                        }

                        idx += 4
                    }
                }
            }
        }

        guard let outCtx = CGContext(
            data: &src, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outCG = outCtx.makeImage() else { return image }

        return UIImage(cgImage: outCG, scale: 1, orientation: .up)
    }
}
