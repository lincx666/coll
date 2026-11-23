import SwiftUI

/// 滤镜选择：三个大 tab（相机 / AI 场景 / 网红），relens 再按分类横滑切换。
/// 每个格子给一张用当前照片实时套好的缩略预览。
struct FilterSheet: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .camera
    @State private var category: String = ""
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var building = false

    enum Tab: String, CaseIterable, Identifiable {
        case camera = "相机色彩"
        case scene = "AI 场景"
        case relens = "网红滤镜"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if tab == .relens { categoryBar }

                scrollContent
            }
            .navigationTitle("选滤镜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                if category.isEmpty {
                    category = model.library.categories.first ?? ""
                }
                buildThumbnails()
            }
            .onChange(of: tab) { _ in buildThumbnails() }
            .onChange(of: category) { _ in buildThumbnails() }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 分类横条

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.library.haldByCategory) { c in
                    Button {
                        category = c.name
                    } label: {
                        Text("\(c.name) \(c.items.count)")
                            .font(.caption.weight(category == c.name ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(category == c.name
                                               ? Color.accentColor.opacity(0.25)
                                               : Color.secondary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(category == c.name ? Color.accentColor : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - 网格

    /// SE 一代只有 320pt 宽，96pt 一列会挤成 3 列且字被截断。
    /// 用紧凑档位把格子压到 84pt，留出边距。
    private var isCompactScreen: Bool {
        UIScreen.main.bounds.width < 360
    }

    private var scrollContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompactScreen ? 78 : 96), spacing: 8)],
                      spacing: 8) {
                if tab == .camera {
                    cell(name: "原色", key: "identity",
                         isSelected: model.selectedLUT == nil && model.selectedHALD == nil) {
                        model.pick(lut: nil)
                        model.pick(hald: nil)
                    }
                }

                switch tab {
                case .camera:
                    ForEach(model.library.cameraLUTs) { lut in
                        cell(name: lut.displayName, key: "lut:\(lut.id)",
                             isSelected: model.selectedLUT?.id == lut.id) {
                            model.pick(lut: lut)
                        }
                    }
                case .scene:
                    ForEach(model.library.sceneLUTs) { lut in
                        cell(name: lut.displayName, key: "lut:\(lut.id)",
                             isSelected: model.selectedLUT?.id == lut.id) {
                            model.pick(lut: lut)
                        }
                    }
                case .relens:
                    ForEach(currentHALDs) { hald in
                        cell(name: hald.displayName, key: "hald:\(hald.id)",
                             isSelected: model.selectedHALD?.id == hald.id) {
                            model.pick(hald: hald)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var currentHALDs: [HALDEntry] {
        model.library.items(in: category)
    }

    // MARK: - 单元格

    private func cell(name: String, key: String, isSelected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                    if let thumb = thumbnails[key] {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ProgressView().scaleEffect(0.6)
                    }
                }
                .frame(height: isCompactScreen ? 62 : 74)
                // iOS 15 用 overlay(_:alignment:) 而不是 overlay { }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                )

                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 缩略图

    /// 用当前照片的极小副本批量套 LUT，打开面板时一次算完。
    ///
    /// 小内存设备（SE 一代）上，一次算 116 张缩略图会爆内存 ——
    /// 所以按设备分两批，算完一批再算下一批，中间 GC 一次。
    private func buildThumbnails() {
        guard !building, let source = model.originalImage else { return }
        building = true

        let tiny = RenderPipeline.downscale(source, maxDimension: 160)
        var jobs: [(key: String, settings: RenderPipeline.Settings)] = []

        switch tab {
        case .camera:
            for lut in model.library.cameraLUTs {
                jobs.append(("lut:\(lut.id)", .init(lutFile: lut.id, haldFile: nil,
                                                    intensity: 1, frameFile: nil,
                                                    filterDisplayName: lut.displayName)))
            }
        case .scene:
            for lut in model.library.sceneLUTs {
                jobs.append(("lut:\(lut.id)", .init(lutFile: lut.id, haldFile: nil,
                                                    intensity: 1, frameFile: nil,
                                                    filterDisplayName: lut.displayName)))
            }
        case .relens:
            for hald in currentHALDs {
                jobs.append(("hald:\(hald.id)", .init(lutFile: nil, haldFile: hald.file,
                                                      intensity: 1, frameFile: nil,
                                                      filterDisplayName: hald.displayName)))
            }
        }

        let pipeline = RenderPipeline()
        let constrained = RenderPipeline.isConstrainedDevice
        let batchSize = constrained ? 8 : 32

        Task.detached(priority: .userInitiated) {
            var index = 0
            while index < jobs.count {
                let end = min(index + batchSize, jobs.count)
                var result: [String: UIImage] = [:]
                for job in jobs[index..<end] {
                    result[job.key] = pipeline.export(tiny, settings: job.settings)
                }
                let snapshot = result
                await MainActor.run {
                    self.thumbnails.merge(snapshot) { _, new in new }
                }
                index = end
                // 小内存设备给系统一点回收时间
                if constrained { try? await Task.sleep(nanoseconds: 30_000_000) }
            }
            await MainActor.run { self.building = false }
        }
    }
}
