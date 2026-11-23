import SwiftUI

struct RootView: View {
    @StateObject private var model = EditorModel()
    @State private var showPicker = false
    @State private var showCamera = false

    var body: some View {
        NavigationView {
            Group {
                if model.originalImage == nil {
                    HomeView(model: model,
                             pickPhoto: { showPicker = true },
                             openCamera: { showCamera = true })
                } else {
                    EditorView(model: model, showPicker: $showPicker)
                }
            }
            .navigationTitle("Leica Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if model.originalImage != nil {
                        Button {
                            model.export()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .disabled(model.isRendering)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { image in
                if let image { model.load(image) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(model: model)
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

// MARK: - 首页

struct HomeView: View {
    @ObservedObject var model: EditorModel
    let pickPhoto: () -> Void
    let openCamera: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundColor(.accentColor)

                Text("Leica Lab")
                    .font(.title2.weight(.semibold))

                Text("\(model.library.totalFilters) 个滤镜 · 9 种相框")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: openCamera) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("拍照")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button(action: pickPhoto) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("从相册选")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}
