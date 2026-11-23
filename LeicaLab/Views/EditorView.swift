import SwiftUI

struct EditorView: View {
    @ObservedObject var model: EditorModel
    @Binding var showPicker: Bool
    @State private var sheet: SheetKind?

    enum SheetKind: String, Identifiable {
        case filters, frames
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            canvas
            controls
        }
    }

    // MARK: - 画布

    private var canvas: some View {
        ZStack {
            Color.black
            if let img = model.previewImage ?? model.originalImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            }

            if model.isRendering {
                VStack {
                    Spacer()
                    ProgressView()
                        .padding(10)
                        .background(
                            Capsule().fill(Color.black.opacity(0.35))
                        )
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { showPicker = true }
    }

    // MARK: - 控制区

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                pill(title: model.currentFilterName.isEmpty ? "原色" : model.currentFilterName,
                     icon: "camera.filters", filled: !model.currentFilterName.isEmpty)
                pill(title: model.selectedFrame?.displayName ?? "无相框",
                     icon: "rectangle.on.rectangle", filled: model.selectedFrame != nil)
                Spacer(minLength: 0)
            }

            if model.selectedLUT != nil || model.selectedHALD != nil {
                HStack(spacing: 12) {
                    Text("强度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $model.intensity, in: 0...1) { editing in
                        if !editing { model.refreshPreview() }
                    }
                    Text("\(Int(model.intensity * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                // iOS 15 的 onChange 是单参数版本
                .onChange(of: model.intensity) { _ in
                    model.refreshPreview()
                }
            }

            HStack(spacing: 12) {
                Button {
                    sheet = .filters
                } label: {
                    Label("滤镜", systemImage: "camera.filters")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    sheet = .frames
                } label: {
                    Label("相框", systemImage: "rectangle.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    model.pick(lut: nil)
                    model.pick(hald: nil)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .sheet(item: $sheet) { kind in
            switch kind {
            case .filters:
                FilterSheet(model: model)
            case .frames:
                FrameSheet(model: model)
            }
        }
    }

    private func pill(title: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2)
            Text(title).font(.caption).lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(filled
                           ? Color.accentColor.opacity(0.2)
                           : Color.secondary.opacity(0.12))
        )
        .foregroundColor(filled ? Color.accentColor : Color.secondary)
    }
}
