import UIKit
import CoreImage
import CoreGraphics

// MARK: - 模板模型

/// 相框模板，对应 APK 里 `assets/frames/*.json` 的 schema。
struct FrameTemplate: Decodable, Identifiable, Sendable {
    struct LocalizedName: Decodable, Sendable {
        let en: String?
        let zh: String?
    }

    struct DesignSize: Decodable, Sendable {
        let width: CGFloat
        let height: CGFloat
    }

    struct Layout: Decodable, Sendable {
        let position: String                // BORDER | OVERLAY | BOTH | IMAGE
        let height: CGFloat?
        let backgroundColor: String?
        let backgroundType: String?         // GAUSSIAN_BLUR
        let backgroundBlurRadius: CGFloat?
        let padding: CGFloat?
        let borderWidth: CGFloat?
        let borderHeight: CGFloat?
        let verticalPadding: CGFloat?
        let elementSpacing: CGFloat?
        let lineSpacing: CGFloat?
        let designSize: DesignSize?
        let imageResName: String?
    }

    struct Element: Decodable, Sendable {
        let type: String                    // logo | text
        let textType: String?               // CUSTOM | DEVICE_MODEL | APERTURE | …
        let logoType: String?
        let overrideSource: String?
        let alignment: String?              // START | END | CENTER
        let fontSize: CGFloat?
        let color: String?
        let fontWeight: String?
        let line: Int?
        let margin: CGFloat?
        let width: CGFloat?
        let size: CGFloat?
        let maxWidth: CGFloat?
        let format: String?
        let fontFamily: String?
        let light: Bool?
    }

    let id: String
    let name: LocalizedName?
    let layout: Layout
    let elements: [Element]
    let elementsTop: [Element]?

    var displayName: String { name?.zh ?? name?.en ?? id }

    static func load(file: String) -> FrameTemplate? {
        guard let url = BundleResource.frame(file),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FrameTemplate.self, from: data)
    }
}

// MARK: - 渲染

/// 按模板把相框画到图像上。
///
/// 关键约定：模板里的所有尺寸（height / padding / fontSize …）都是
/// **相对 `designSize.width`（通常 4096）的设计单位**，渲染时统一乘一个
/// `scale = 实际图像宽 / designSize.width`，这样同一套模板能适配任意分辨率。
///
/// 无实例状态，可跨线程复用。
final class FrameRenderer: @unchecked Sendable {

    /// 一次渲染所需的上下文：EXIF + 用户可改的字段。
    struct Context: Sendable {
        var deviceModel: String = "iPhone"
        var aperture: String = ""           // "f/1.8"
        var shutterSpeed: String = ""       // "1/125"
        var iso: String = ""                // "ISO 100"
        var focalLength35mm: String = ""    // "24mm"
        var capturedAt: Date = Date()
        var customText: String = ""         // CUSTOM 类型用
        var filterName: String = ""         // FILTER_NAME 用
    }

    // MARK: 入口

    func render(_ image: UIImage, template: FrameTemplate, context: Context) -> UIImage {
        guard let cg = image.cgImage else { return image }

        let design = template.layout.designSize ?? .init(width: 4096, height: 3072)
        let scale = CGFloat(cg.width) / design.width

        switch template.layout.position.uppercased() {
        case "OVERLAY":
            return overlay(cg, template: template, ctx: context, scale: scale)
        case "BOTH":
            return bordered(cg, template: template, ctx: context, scale: scale, both: true)
        case "IMAGE":
            if let named = template.layout.imageResName, let frame = UIImage(named: named) {
                return compositeBitmapFrame(cg, frame: frame)
            }
            return overlay(cg, template: template, ctx: context, scale: scale)
        default:  // BORDER
            return bordered(cg, template: template, ctx: context, scale: scale, both: false)
        }
    }

    // MARK: - BORDER

    private func bordered(_ cg: CGImage, template: FrameTemplate,
                          ctx: Context, scale: CGFloat, both: Bool) -> UIImage {
        let l = template.layout
        let w = CGFloat(cg.width), h = CGFloat(cg.height)

        let borderSide = (l.borderWidth ?? 0) * scale
        let borderH = (l.borderHeight ?? l.borderWidth ?? 0) * scale
        let bandHeight = (l.height ?? 0) * scale
        let pad = (l.padding ?? 0) * scale

        // BOTH（XPAN）上下各一条带；BORDER 只底部一条
        let topBand = both ? bandHeight : 0
        let bottomBand = bandHeight

        let outW = w + borderSide * 2
        let outH = h + borderH + topBand + bottomBand

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: format)

        return renderer.image { rc in
            let gc = rc.cgContext
            let bg = UIColor(hex: l.backgroundColor ?? "#FFFFFF") ?? .white
            gc.setFillColor(bg.cgColor)
            gc.fill(CGRect(x: 0, y: 0, width: outW, height: outH))

            if l.backgroundType == "GAUSSIAN_BLUR" {
                drawBlurredBackdrop(cg, in: gc,
                                    rect: CGRect(x: 0, y: 0, width: outW, height: outH),
                                    radius: (l.backgroundBlurRadius ?? 60) * scale)
            }

            let imageRect = CGRect(x: borderSide,
                                   y: borderH + topBand,
                                   width: w, height: h)
            gc.draw(cg, in: imageRect)

            if both, let top = template.elementsTop {
                drawElements(top, in: gc,
                             bandRect: CGRect(x: 0, y: 0, width: outW, height: topBand),
                             ctx: ctx, scale: scale, padding: pad)
            }

            let bandRect = CGRect(x: 0, y: outH - bottomBand, width: outW, height: bottomBand)
            drawElements(template.elements, in: gc,
                         bandRect: bandRect, ctx: ctx, scale: scale, padding: pad)
        }
    }

    // MARK: - OVERLAY

    private func overlay(_ cg: CGImage, template: FrameTemplate,
                         ctx: Context, scale: CGFloat) -> UIImage {
        let l = template.layout
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let pad = (l.padding ?? 0) * scale
        let bandHeight = (l.height ?? 0) * scale

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format)

        return renderer.image { rc in
            let gc = rc.cgContext
            gc.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

            if let bg = UIColor(hex: l.backgroundColor ?? "#00000000"),
               bg.cgColor.alpha > 0.01 {
                gc.setFillColor(bg.cgColor)
                gc.fill(CGRect(x: 0, y: h - bandHeight, width: w, height: bandHeight))
            }

            let bandRect = CGRect(x: 0, y: h - bandHeight, width: w, height: bandHeight)
            drawElements(template.elements, in: gc,
                         bandRect: bandRect, ctx: ctx, scale: scale, padding: pad)
        }
    }

    // MARK: - 元素绘制

    private func drawElements(_ elements: [FrameTemplate.Element], in gc: CGContext,
                              bandRect: CGRect, ctx: Context, scale: CGFloat, padding: CGFloat) {
        guard bandRect.height > 1 else { return }

        // 按 line 分桶：line < 0 是贴边 logo，不参与文字行流
        var textLines: [Int: [FrameTemplate.Element]] = [:]
        var pinned: [FrameTemplate.Element] = []

        for e in elements {
            if e.type == "text" {
                textLines[e.line ?? 0, default: []].append(e)
            } else {
                pinned.append(e)
            }
        }

        // 贴边 logo 优先画
        for e in pinned where (e.line ?? 0) < 0 {
            drawPinnedElement(e, in: gc, bandRect: bandRect, scale: scale, padding: padding)
        }

        let sortedLines = textLines.keys.sorted()
        guard !sortedLines.isEmpty else {
            // 没有文字，只有居中的 logo
            for e in pinned where (e.line ?? 0) >= 0 {
                drawPinnedElement(e, in: gc, bandRect: bandRect, scale: scale, padding: padding)
            }
            return
        }

        // 先量出每行高度，再整体垂直居中
        var lineHeights: [Int: CGFloat] = [:]
        for key in sortedLines {
            let maxFont = textLines[key]!.compactMap(\.fontSize).max() ?? 36
            lineHeights[key] = maxFont * scale * 1.35
        }
        let totalHeight = lineHeights.values.reduce(0, +)
        let spacing = max(0, (bandRect.height - totalHeight) / 2)

        var y = bandRect.minY + spacing
        for key in sortedLines {
            let height = lineHeights[key]!
            drawTextLine(textLines[key]!, in: gc, y: y, height: height,
                         bandRect: bandRect, ctx: ctx, scale: scale, padding: padding)
            y += height
        }
    }

    /// 一行里按 alignment 分三段：START 左、CENTER 中、END 右
    private func drawTextLine(_ elements: [FrameTemplate.Element], in gc: CGContext,
                              y: CGFloat, height: CGFloat, bandRect: CGRect,
                              ctx: Context, scale: CGFloat, padding: CGFloat) {
        var groups: [String: [FrameTemplate.Element]] = [:]
        for e in elements {
            groups[(e.alignment ?? "START").uppercased(), default: []].append(e)
        }

        let inner = bandRect.insetBy(dx: padding, dy: 0)

        if let center = groups["CENTER"], !center.isEmpty {
            drawAligned(center, in: gc, alignment: .center, y: y, height: height,
                        rect: inner, ctx: ctx, scale: scale)
            return
        }
        if let start = groups["START"], !start.isEmpty {
            drawAligned(start, in: gc, alignment: .left, y: y, height: height,
                        rect: inner, ctx: ctx, scale: scale)
        }
        if let end = groups["END"], !end.isEmpty {
            drawAligned(end, in: gc, alignment: .right, y: y, height: height,
                        rect: inner, ctx: ctx, scale: scale)
        }
    }

    private enum Align { case left, center, right }

    private func drawAligned(_ elements: [FrameTemplate.Element], in gc: CGContext,
                             alignment: Align, y: CGFloat, height: CGFloat,
                             rect: CGRect, ctx: Context, scale: CGFloat) {
        // 同一侧多个元素横向串联（例如 f/1.8 · 1/125 · ISO 100）
        let items: [(text: String, attrs: [NSAttributedString.Key: Any])] = elements
            .map { (resolvedText($0, ctx: ctx), makeAttributes($0, scale: scale)) }
            .filter { !$0.0.isEmpty }
        guard !items.isEmpty else { return }

        let gap = 24 * scale
        let widths = items.map { ($0.text as NSString).size(withAttributes: $0.attrs).width }
        let total = widths.reduce(0, +) + gap * CGFloat(max(0, items.count - 1))

        var x: CGFloat
        switch alignment {
        case .left:   x = rect.minX
        case .right:  x = rect.maxX - total
        case .center: x = rect.midX - total / 2
        }

        for (i, item) in items.enumerated() {
            let size = (item.text as NSString).size(withAttributes: item.attrs)
            let ty = y + (height - size.height) / 2
            (item.text as NSString).draw(at: CGPoint(x: x, y: ty), withAttributes: item.attrs)
            x += widths[i] + gap
        }
    }

    /// line < 0 的 logo：贴左 / 居中 / 贴右，垂直居中于整条带
    private func drawPinnedElement(_ element: FrameTemplate.Element, in gc: CGContext,
                                   bandRect: CGRect, scale: CGFloat, padding: CGFloat) {
        guard element.type == "logo" else { return }
        guard let name = element.overrideSource ?? element.logoType,
              let logo = UIImage(named: name) else { return }

        let targetW = (element.width ?? element.size ?? 96) * scale
        guard targetW > 0 else { return }
        let ratio = logo.size.height / max(logo.size.width, 1)
        let targetH = targetW * ratio
        let y = bandRect.midY - targetH / 2
        var x: CGFloat

        switch (element.alignment ?? "START").uppercased() {
        case "END":    x = bandRect.maxX - padding - targetW
        case "CENTER": x = bandRect.midX - targetW / 2
        default:       x = bandRect.minX + padding
        }

        let rect = CGRect(x: x, y: y, width: targetW, height: targetH)
        if element.light == true, let tint = UIColor(hex: element.color ?? "#FFFFFF") {
            logo.withRenderingMode(.alwaysTemplate).withTintColor(tint).draw(in: rect)
        } else {
            logo.draw(in: rect)
        }
    }

    // MARK: - 文案

    private func resolvedText(_ e: FrameTemplate.Element, ctx: Context) -> String {
        switch (e.textType ?? "CUSTOM").uppercased() {
        case "CUSTOM":            return e.format ?? ctx.customText
        case "DEVICE_MODEL":      return ctx.deviceModel
        case "APERTURE":          return ctx.aperture
        case "SHUTTER_SPEED":     return ctx.shutterSpeed
        case "ISO":               return ctx.iso
        case "FOCAL_LENGTH_35MM": return ctx.focalLength35mm
        case "FILTER_NAME":       return ctx.filterName
        case "DATETIME", "DATE":
            let df = DateFormatter()
            df.dateFormat = e.format ?? "yyyy.MM.dd HH:mm"
            df.locale = Locale(identifier: "zh_CN")
            return df.string(from: ctx.capturedAt)
        default:
            return e.format ?? ""
        }
    }

    private func makeAttributes(_ e: FrameTemplate.Element,
                                scale: CGFloat) -> [NSAttributedString.Key: Any] {
        let size = (e.fontSize ?? 36) * scale
        var font: UIFont
        if let family = e.fontFamily {
            let name = (family as NSString).deletingPathExtension
            font = UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        } else if (e.fontWeight ?? "").uppercased().contains("BOLD") {
            font = UIFont.systemFont(ofSize: size, weight: .bold)
        } else {
            font = UIFont.systemFont(ofSize: size, weight: .regular)
        }
        let color = UIColor(hex: e.color ?? "#000000") ?? .black
        return [.font: font, .foregroundColor: color]
    }

    // MARK: - 辅助

    /// 柔焦边框：把原图放大铺满 + 高斯模糊当底色
    private func drawBlurredBackdrop(_ cg: CGImage, in gc: CGContext,
                                     rect: CGRect, radius: CGFloat) {
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return }
        let src = CIImage(cgImage: cg)
        blur.setValue(src, forKey: kCIInputImageKey)
        blur.setValue(radius, forKey: kCIInputRadiusKey)

        guard let out = blur.outputImage,
              let blurred = CIContext().createCGImage(out, from: src.extent) else { return }

        gc.saveGState()
        gc.clip(to: rect)
        let s = max(rect.width / CGFloat(blurred.width), rect.height / CGFloat(blurred.height))
        let w = CGFloat(blurred.width) * s
        let h = CGFloat(blurred.height) * s
        gc.draw(blurred, in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
        gc.restoreGState()
    }

    /// 位图相框（Portra 400）：原图缩进框内
    private func compositeBitmapFrame(_ cg: CGImage, frame: UIImage) -> UIImage {
        let outSize = frame.size
        let inset = outSize.width * 0.06
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outSize, format: format)
        return renderer.image { _ in
            let inner = CGRect(x: inset, y: inset,
                               width: outSize.width - inset * 2,
                               height: outSize.height - inset * 2)
            let s = max(inner.width / CGFloat(cg.width), inner.height / CGFloat(cg.height))
            let w = CGFloat(cg.width) * s
            let h = CGFloat(cg.height) * s
            UIImage(cgImage: cg).draw(in: CGRect(x: inner.midX - w / 2,
                                                y: inner.midY - h / 2,
                                                width: w, height: h))
            frame.draw(in: CGRect(origin: .zero, size: outSize))
        }
    }
}

// MARK: - 十六进制颜色

extension UIColor {
    /// 支持 `#RGB` / `#RRGGBB` / `#AARRGGBB`（APK 里的写法是 ARGB）
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()

        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }

        switch s.count {
        case 3:
            self.init(red: CGFloat((value >> 8) & 0xF) / 15,
                      green: CGFloat((value >> 4) & 0xF) / 15,
                      blue: CGFloat(value & 0xF) / 15,
                      alpha: 1)
        case 6:
            self.init(red: CGFloat((value >> 16) & 0xFF) / 255,
                      green: CGFloat((value >> 8) & 0xFF) / 255,
                      blue: CGFloat(value & 0xFF) / 255,
                      alpha: 1)
        case 8:
            // APK 用 ARGB 顺序
            self.init(red: CGFloat((value >> 16) & 0xFF) / 255,
                      green: CGFloat((value >> 8) & 0xFF) / 255,
                      blue: CGFloat(value & 0xFF) / 255,
                      alpha: CGFloat((value >> 24) & 0xFF) / 255)
        default:
            return nil
        }
    }
}
