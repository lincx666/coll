import Foundation

// MARK: - 目录模型

/// 资源包里的总目录，由 `prepare_resources.py` 生成。
struct AppCatalog: Decodable, Sendable {
    let luts: [LUTEntry]
    let hald: [HALDEntry]
    let frames: [FrameEntry]
    let sounds: [SoundEntry]

    static let empty = AppCatalog(luts: [], hald: [], frames: [], sounds: [])

    static func load() -> AppCatalog {
        guard let url = BundleResource.url(name: "catalog", ext: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(AppCatalog.self, from: data)
        else {
            assertionFailure("catalog.json 缺失或格式不符")
            return .empty
        }
        return catalog
    }
}

/// 33³ 的 `.bin` LUT（徕卡 / 相机 Look / AI 场景）
struct LUTEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let group: String        // "camera" | "aiscene"
    let file: String
    let dim: Int

    /// 展示名：去掉 AI 场景前缀、下划线换空格
    var displayName: String {
        switch group {
        case "aiscene":
            return id
                .replacingOccurrences(of: "lut_aiscene_", with: "")
                .replacingOccurrences(of: "lut_normal_", with: "")
                .replacingOccurrences(of: "lut_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        default:
            return id
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: ".", with: " ")
        }
    }

    var categoryLabel: String { group == "aiscene" ? "AI 场景" : "相机" }
}

/// 64³ 的 HALD PNG（relens 网红滤镜）
struct HALDEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let file: String
    let dim: Int             // 源 HALD 级别，64
    let names: [String]
    let category: String
    let groups: [String]
    let scene: String
    let count: Int

    var displayName: String { names.first ?? id }

    /// 多个滤镜共用同一张 HALD 时的别名
    var aliases: [String] { Array(names.dropFirst()) }
}

struct FrameEntry: Decodable, Identifiable, Hashable, Sendable {
    struct LocalizedName: Decodable, Hashable, Sendable {
        let en: String?
        let zh: String?
    }
    let id: String
    let file: String
    let name: LocalizedName?
    let position: String

    var displayName: String { name?.zh ?? name?.en ?? id }
}

struct SoundEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let file: String
}

// MARK: - 运行时索引

/// 把 catalog 切成 UI 要用的分组，避免视图里反复算。
struct FilterLibrary: Sendable {
    let catalog: AppCatalog

    let cameraLUTs: [LUTEntry]
    let sceneLUTs: [LUTEntry]
    let haldByCategory: [HALDCategory]

    struct HALDCategory: Sendable, Identifiable {
        var id: String { name }
        let name: String
        let items: [HALDEntry]
    }

    init(catalog: AppCatalog) {
        self.catalog = catalog
        self.cameraLUTs = catalog.luts.filter { $0.group == "camera" }
        self.sceneLUTs = catalog.luts.filter { $0.group == "aiscene" }

        var buckets: [String: [HALDEntry]] = [:]
        for entry in catalog.hald {
            buckets[entry.category, default: []].append(entry)
        }
        self.haldByCategory = buckets
            .sorted { $0.value.count > $1.value.count }
            .map { HALDCategory(name: $0.key, items: $0.value) }
    }

    var categories: [String] { haldByCategory.map(\.name) }

    /// 三个大类的总条目数，首页用
    var totalFilters: Int {
        cameraLUTs.count + sceneLUTs.count + catalog.hald.count
    }

    func items(in category: String) -> [HALDEntry] {
        haldByCategory.first { $0.name == category }?.items ?? []
    }
}
