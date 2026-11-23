import UIKit
import ImageIO

/// 从照片里读出 EXIF，填进相框水印要用的字段。
///
/// 手机拍的照片一般只有 `FNumber` / `ExposureTime` / `ISO` / `FocalLenIn35mmFilm`，
/// 老照片或截图可能全缺 —— 缺的字段返回空串，渲染时自然就不画那一块。
enum PhotoMetadata {

    struct Info {
        var deviceModel: String = ""
        var make: String = ""
        var aperture: String = ""
        var shutterSpeed: String = ""
        var iso: String = ""
        var focalLength35mm: String = ""
        var focalLength: String = ""
        var lensModel: String = ""
        var capturedAt: Date = Date()
        var pixelSize: CGSize = .zero

        /// 相框里常用的「f/1.8  1/125  ISO 100」串
        var exposureLine: String {
            [aperture, shutterSpeed, iso].filter { !$0.isEmpty }.joined(separator: "  ")
        }
    }

    /// 从 `UIImage` 读（会重新编码一次拿 EXIF，稍有开销但兼容性最好）
    static func read(from image: UIImage) -> Info {
        var info = Info()
        info.pixelSize = image.size

        guard let data = image.jpegData(compressionQuality: 1.0),
              let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        else {
            info.deviceModel = UIDevice.current.model
            return info
        }

        return parse(props, fallbackModel: UIDevice.current.model, size: image.size)
    }

    /// 直接从 URL 读（从「文件」App 打开时 EXIF 最完整，不用重新编码）
    static func read(fromURL url: URL) -> Info {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        else { return Info(deviceModel: UIDevice.current.model) }

        var size = CGSize.zero
        if let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
           let h = props[kCGImagePropertyPixelHeight] as? CGFloat {
            size = CGSize(width: w, height: h)
        }
        return parse(props, fallbackModel: UIDevice.current.model, size: size)
    }

    // MARK: - 解析

    private static func parse(_ props: [CFString: Any],
                              fallbackModel: String,
                              size: CGSize) -> Info {
        var info = Info()
        info.pixelSize = size

        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let f = exif[kCGImagePropertyExifFNumber] as? Double, f > 0 {
                info.aperture = f == f.rounded()
                    ? String(format: "f/%.0f", f)
                    : String(format: "f/%.1f", f)
            }

            if let t = exif[kCGImagePropertyExifExposureTime] as? Double, t > 0 {
                info.shutterSpeed = t >= 1
                    ? String(format: "%.1fs", t)
                    : "1/" + String(Int((1.0 / t).rounded()))
            }

            // ISOSpeedRatings 是主键；EXIF 里也可能出现 PhotographicSensitivity。
            // 后者在部分 SDK 里没暴露常量，用 String 字面量桥接成 CFString 当键。
            let isoKeys: [CFString] = [
                kCGImagePropertyExifISOSpeedRatings,
                "PhotographicSensitivity" as CFString,
            ]
            for key in isoKeys {
                if let arr = exif[key] as? [Int], let v = arr.first {
                    info.iso = "ISO \(v)"
                    break
                }
            }

            if let f35 = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int, f35 > 0 {
                info.focalLength35mm = "\(f35)mm"
            }
            if let fl = exif[kCGImagePropertyExifFocalLength] as? Double, fl > 0 {
                info.focalLength = String(format: "%.0fmm", fl)
            }
            if let lens = exif[kCGImagePropertyExifLensModel] as? String {
                info.lensModel = lens
            }
            if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                let df = DateFormatter()
                df.dateFormat = "yyyy:MM:dd HH:mm:ss"
                info.capturedAt = df.date(from: dateStr) ?? Date()
            }
        }

        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let model = tiff[kCGImagePropertyTIFFModel] as? String {
                info.deviceModel = model.trimmingCharacters(in: .whitespaces)
            }
            if let make = tiff[kCGImagePropertyTIFFMake] as? String {
                info.make = make.trimmingCharacters(in: .whitespaces)
            }
        }

        if info.deviceModel.isEmpty { info.deviceModel = fallbackModel }
        return info
    }

    /// 转成 FrameRenderer 用的上下文
    static func context(from info: Info, filterName: String) -> FrameRenderer.Context {
        FrameRenderer.Context(
            deviceModel: info.deviceModel,
            aperture: info.aperture,
            shutterSpeed: info.shutterSpeed,
            iso: info.iso,
            focalLength35mm: info.focalLength35mm,
            capturedAt: info.capturedAt,
            customText: "",
            filterName: filterName
        )
    }
}
