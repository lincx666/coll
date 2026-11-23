import SwiftUI

/// 拍照界面：预览 + 底部滤镜选择条 + 快门。
///
/// 交互仿 Dazz：选好滤镜直接按快门，出来就是套好滤镜的照片。
struct CameraView: View {

    @StateObject private var camera = CameraController()
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    @State private var captured: PhotoBox?
    @State private var showFilterStrip = true
    @State private var filterTab: FilterTab = .brand

    enum FilterTab: String, CaseIterable, Identifiable {
        case brand = "品牌"
        case film = "胶片"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.status {
            case .ready:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            case .unauthorized:
                permissionHint
            case .failed(let msg):
                failureHint(msg)
            default:
                ProgressView().tint(.white)
            }

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            camera.requestAndStart()
            model.ensureThumbnails(for: currentLUTs)
        }
        .onDisappear {
            camera.stop()
            model.cancelThumbnails()
        }
        .statusBar(hidden: true)
        .sheet(item: $captured) { box in
            CapturedPhotoView(image: box.image, model: model) { dismiss() }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }

            Spacer()

            if model.selectedLUT != nil || model.selectedHALD != nil {
                Text(model.currentFilterName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
            }

            Spacer()

            Button {
                camera.flashOn.toggle()
            } label: {
                Image(systemName: camera.flashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 底部

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if showFilterStrip {
                filterStrip
            }

            HStack {
                Button {
                    withAnimation { showFilterStrip.toggle() }
                } label: {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }

                Spacer()

                Button {
                    shoot()
                } label: {
                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 4)
                            .frame(width: 76, height: 76)
                        Circle().fill(Color.white)
                            .frame(width: 62, height: 62)
                    }
                }
                .disabled(!camera.status.isReadyForCapture)

                Spacer()

                Color.clear.frame(width: 52, height: 52)
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 24)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var filterStrip: some View {
        VStack(spacing: 8) {
            Picker("", selection: $filterTab) {
                ForEach(FilterTab.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: filterTab) { _ in
                model.ensureThumbnails(for: currentLUTs)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterCell(name: "原色", key: nil,
                               selected: model.selectedLUT == nil && model.selectedHALD == nil) {
                        model.pick(lut: nil)
                        model.pick(hald: nil)
                    }

                    ForEach(currentLUTs) { lut in
                        filterCell(name: model.displayName(for: lut),
                                   key: lut.id,
                                   selected: model.selectedLUT?.id == lut.id) {
                            model.pick(lut: lut)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func filterCell(name: String, key: String?, selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.15))

                    if let key, let t = model.thumbnails[key] {
                        Image(uiImage: t)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if key == nil {
                        // 「原色」：直接用测试块
                        Image(uiImage: EditorModel.swatch())
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ProgressView().scaleEffect(0.5).tint(.white)
                    }
                }
                .frame(width: 58, height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.yellow : Color.clear, lineWidth: 2)
                )

                Text(name)
                    .font(.system(size: 9))
                    .foregroundColor(selected ? .yellow : .white)
                    .lineLimit(1)
                    .frame(width: 58)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据

    /// 品牌 tab：机内 LUT（哈苏/徕卡/宾得/理光/富士/柯达…），排除 log 还原和视频仿色
    /// 胶片 tab：cameralook 那 23 个风格 tone
    private var currentLUTs: [LUTEntry] {
        let all = model.library.cameraLUTs.filter { $0.group == "camera" }
        switch filterTab {
        case .brand:
            return all.filter {
                !$0.id.hasPrefix("log_") && !$0.id.hasPrefix("fengwei_")
                    && !$0.id.hasPrefix("cameralook_")
            }
        case .film:
            return all.filter { $0.id.hasPrefix("cameralook_") }
        }
    }

    // MARK: - 拍照

    private func shoot() {
        camera.capture { image in
            guard let image else {
                model.exportMessage = "拍照失败，请重试"
                return
            }
            captured = PhotoBox(image: image)
        }
    }

    // MARK: - 提示

    private var permissionHint: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.white)
            Text("没有相机权限").foregroundColor(.white)
            Text("去 设置 → 隐私 → 相机，允许 Leica Lab")
                .font(.caption).foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func failureHint(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(.orange)
            Text(msg).foregroundColor(.white)
            Button("返回") { dismiss() }
        }
    }
}

/// 用来把 UIImage 塞进 sheet(item:)
struct PhotoBox: Identifiable {
    let image: UIImage
    var id: Int { image.hashValue }
}
