import SwiftUI
import UIKit

@main
struct LeicaLabApp: App {
    init() {
        // 这台机器（A9 / iOS 15.8.8 越狱）上 CoreImage 的 CIContext 构造会段错误，
        // 所以整条渲染链已经改成 CoreGraphics + CPU，不再预热任何 CIContext。
        // 这里只做个启动标记，方便日志排查。
        NSLog("[LeicaLab] launched, uid=\(getuid())")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
