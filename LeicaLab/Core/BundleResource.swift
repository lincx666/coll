import Foundation

/// 统一的资源查找。
///
/// Xcode 里几种加法会产生不同的 bundle 结构：
/// - 蓝色文件夹引用（folder reference）→ 文件夹整体拷到 bundle 根，如 `LUTs/xxx.bin`
/// - 黄色组 + 逐个文件 → 全部摊平到根目录
/// - 手动拖进 `Resources/` 子目录 → `Resources/LUTs/xxx.bin`
///
/// 这里把所有可能的路径都试一遍，免得因为工程设置不同就找不到文件。
enum BundleResource {

    static func url(name: String, ext: String?, subdirectories: [String?] = []) -> URL? {
        var candidates: [String?] = subdirectories
        // 兜底：常见布局
        candidates.append(contentsOf: [
            "Resources", "LUTs", "Resources/LUTs", "HALD", "Resources/HALD",
            "Frames", "Resources/Frames", "Sounds", "Resources/Sounds",
            nil,
        ])

        var seen = Set<String>()
        for sub in candidates {
            let key = sub ?? "__root__"
            guard seen.insert(key).inserted else { continue }

            if let sub {
                if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: sub) {
                    return u
                }
            } else if let u = Bundle.main.url(forResource: name, withExtension: ext) {
                return u
            }
        }
        return nil
    }

    /// 专门给 LUT 用：优先 `LUTs/`
    static func lut(_ name: String) -> URL? {
        url(name: name, ext: "bin", subdirectories: ["LUTs", "Resources/LUTs"])
    }

    /// 专门给 HALD 用
    static func hald(_ fileName: String) -> URL? {
        let stem = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return url(name: stem,
                   ext: ext.isEmpty ? "png" : ext,
                   subdirectories: ["HALD", "Resources/HALD"])
    }

    /// 专门给相框模板用
    static func frame(_ fileName: String) -> URL? {
        let stem = (fileName as NSString).deletingPathExtension
        return url(name: stem, ext: "json", subdirectories: ["Frames", "Resources/Frames"])
    }
}
