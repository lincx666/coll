import SwiftUI

struct RootView: View {
    @StateObject private var model = EditorModel()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if model.originalImage == nil {
                    EmptyStateView { showPicker = true }
                } else {
                    EditorView(model: model, showPicker: $showPicker)
                }
            }
            .navigationTitle("Leica Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.originalImage != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("换一张") { showPicker = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            model.export()
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.down")
                        }
                        .disabled(model.isRendering)
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { image in
                if let image { model.load(image) }
            }
        }
        .alert("提示", isPresented: .init(
            get: { model.exportMessage != nil },
            set: { if !$0 { model.exportMessage = nil } }
        )) {
            Button("好") { model.exportMessage = nil }
        } message: {
            Text(model.exportMessage ?? "")
        }
    }
}

// MARK: - 空态

struct EmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.filters")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("选一张照片开始")
                    .font(.title3.weight(.medium))
                Text("655 个 LUT · 9 种相框 · 徕卡水印")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: action) {
                Label("从相册选择", systemImage: "photo.on.rectangle")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
