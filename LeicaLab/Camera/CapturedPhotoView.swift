import SwiftUI
import Photos

/// 拍完之后的确认页：大图 + 保存 / 重拍。
struct CapturedPhotoView: View {

    let image: UIImage
    @ObservedObject var model: EditorModel
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var processed: UIImage?
    @State private var busy = false
    @State private var saved = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    if let shown = processed ?? image as UIImage? {
                        Image(uiImage: shown)
                            .resizable()
                            .scaledToFit()
                    }
                    if busy {
                        ProgressView().tint(.white)
                    }
                }

                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Label("重拍", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        save()
                    } label: {
                        Label(saved ? "已保存" : "保存", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || saved)
                }
                .padding()
            }
            .navigationTitle("这张可以吗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                        onDone()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { render() }
    }

    /// 用当前选中的滤镜 + 相框处理这张照片
    private func render() {
        busy = true
        let settings = RenderPipeline.Settings(
            lutFile: model.selectedLUT?.id,
            haldFile: model.selectedHALD?.file,
            intensity: model.intensity,
            frameFile: model.selectedFrame?.file,
            filterDisplayName: model.currentFilterName
        )
        let pipeline = RenderPipeline()
        let src = image

        Task.detached(priority: .userInitiated) {
            let out = pipeline.export(src, settings: settings)
            await MainActor.run {
                self.processed = out
                self.busy = false
            }
        }
    }

    private func save() {
        guard let img = processed ?? image as UIImage? else { return }
        busy = true
        model.saveToAlbum(img) { ok, msg in
            busy = false
            if ok { saved = true }
            if let msg { model.exportMessage = msg }
        }
    }
}
