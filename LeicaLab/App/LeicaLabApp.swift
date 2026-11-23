import SwiftUI
import UIKit

@main
struct LeicaLabApp: App {
    init() {
        // iOS 15 上 CIContext 初始化会碰 OpenGL，必须在主线程完成。
        // 这里在 App 启动时预热一次，避免后台渲染线程首次访问时崩溃。
        LUTProcessor.warmUp()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
