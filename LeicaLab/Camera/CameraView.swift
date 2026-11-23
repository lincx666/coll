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
    @State private var filterTab: FilterTab = .camera
    @State private var thumbnails: [String: UIImage] = [:]

    enum FilterTab: String, CaseIterable, Identifiable {
        case camera = "相机"
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
        .onAppear { camera.requestAndStart() }
        .onDisappear { camera.stop() }
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

            if let lut = model.selectedLUT {
                Text(model.displayName(for: lut))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
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
                // 左：切换滤镜面板
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

                // 中：快门
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

                // 右：占位，保持快门居中
                Color.clear.frame(width: 52, height: 52)
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 24)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)],
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
            .frame(width: 200)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // 原色
                    filterCell(name: "原色", key: "none", selected: model.selectedLUT == nil) {
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
        .onChange(of: filterTab) { _ in buildThumbs() }
        .onAppear { buildThumbs() }
    }

    private func filterCell(name: String, key: String, selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.15))
                    if let t = thumbnails[key] {
                        Image(uiImage: t)
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

    /// 相机 tab 只放相机/胶片那批，排除 247 个 AI 场景
    private var currentLUTs: [LUTEntry] {
        let all = model.library.cameraLUTs.filter {
            $0.group == "camera" && !$0.id.hasPrefix("lut_")
        }
        switch filterTab {
        case .camera:
            return all.filter { !$0.id.hasPrefix("log_") }
        case .film:
            return all.filter { $0.id.hasPrefix("log_") || $0.id.count < 12 }
        }
    }

    /// 缩略图：拿不到相机画面就先用纯色块占位，成本低。
    private func buildThumbs() {
        let luts = currentLUTs
        let pipeline = RenderPipeline()
        // 一个 96×96 的渐变测试块，能看出色调差异
        let base = Self.swatch()
        let pwd = model

        Task.detached(priority: .userInitiated) {
            var out: [String: UIImage] = [:]
            for lut in luts {
                let s = RenderPipeline.Settings(lutFile: lut.id, haldFile: nil,
                                                intensity: 1, frameFile: nil,
                                                filterDisplayName: "")
                out[lut.id] = pipeline.export(base, settings: s)
            }
            _ = pwd
            let snap = out
            await MainActor.run { self.thumbnails.merge(snap) { _, n in n } }
        }
    }

    /// 96×96 彩色测试块（肤色 + 天空 + 绿叶 + 灰阶）
    static func swatch() -> UIImage {
        let size = CGSize(width: 96, height: 96)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let gc = ctx.cgContext
            let cols: [UIColor] = [
                UIColor(red: 0.82, green: 0.65, blue: 0.52, alpha: 1),   // 肤色
                UIColor(red: 0.35, green: 0.55, blue: 0.78, alpha: 1),   // 天空
                UIColor(red: 0.28, green: 0.48, blue: 0.26, alpha: 1),   // 绿叶
                UIColor(red: 0.72, green: 0.32, blue: 0.26, alpha: 1),   // 暖红
            ]
            let w = size.width / CGFloat(cols.count)
            for (i, c) in cols.enumerated() {
                gc.setFillColor(c.cgColor)
                gc.fill(CGRect(x: CGFloat(i) * w, y: 0, width: w, height: size.height * 0.66))
            }
            // 底部灰阶
            for i in 0..<8 {
                let g = CGFloat(i) / 7.0
                gc.setFillColor(UIColor(white: g, alpha: 1).cgColor)
                gc.fill(CGRect(x: CGFloat(i) * size.width / 8,
                               y: size.height * 0.66,
                               width: size.width / 8,
                               height: size.height * 0.34))
            }
        }
    }

    // MARK: - 拍照

    private func shoot() {
        camera.capture { image in
            if let image { captured = PhotoBox(image: image) }
        }
    }

    // MARK: - 提示

    private var permissionHint: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.white)
            Text("没有相机权限")
                .foregroundColor(.white)
            Text("去 设置 → 隐私 → 相机，允许 Leica Lab")
                .font(.caption)
                .foregroundColor(.gray)
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
