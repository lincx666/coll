import SwiftUI

/// 相框选择：横向卡片，每张卡片是 **用当前照片真的渲染一遍** 的结果。
struct FrameSheet: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var previews: [String: UIImage] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    // 无相框
                    card(id: "__none__", name: "无相框",
                         isSelected: model.selectedFrame == nil) {
                        model.pick(frame: nil)
                    }

                    ForEach(model.library.catalog.frames) { frame in
                        card(id: frame.id, name: frame.displayName,
                             isSelected: model.selectedFrame?.id == frame.id) {
                            model.pick(frame: frame)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("选相框")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { buildPreviews() }
        }
    }

    private func card(id: String, name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))
                    if let img = previews[id] {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    } else {
                        ProgressView().scaleEffect(0.6)
                    }
                }
                .frame(height: 130)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                }

                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    /// 每张卡片都带上当前已选的 LUT + 滤镜名，所见即所得。
    private func buildPreviews() {
        guard let source = model.originalImage else { return }
        let tiny = RenderPipeline.downscale(source, maxDimension: 320)

        let lut = model.selectedLUT?.id
        let hald = model.selectedHALD?.file
        let filterName = model.currentFilterName
        let intensity = model.intensity

        var jobs: [(key: String, frameFile: String?)] = [("__none__", nil)]
        for frame in model.library.catalog.frames {
            jobs.append((frame.id, frame.file))
        }

        let pipeline = RenderPipeline()
        Task.detached(priority: .userInitiated) {
            var result: [String: UIImage] = [:]
            for job in jobs {
                let settings = RenderPipeline.Settings(
                    lutFile: lut, haldFile: hald, intensity: intensity,
                    frameFile: job.frameFile, filterDisplayName: filterName
                )
                result[job.key] = pipeline.export(tiny, settings: settings)
            }
            let snapshot = result
            await MainActor.run { self.previews = snapshot }
        }
    }
}
