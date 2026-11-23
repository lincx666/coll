# iOS 15.8.8 + 无 Mac：从零到装上

你的情况：**iOS 15.8.8、没装 TrollStore、没有 Mac、有 Windows**。

结论先说：**能装，而且能永久装。** 15.8.8 在 TrollStore 支持范围内
（[支持到 16.6.1 / 16.7 RC / 17.0](https://raw.githubusercontent.com/opa334/TrollStore/main/README.md)），
只是安装器要选对 —— 老的 TrollInstallerX **不支持** 15.8.7/15.8.8。

分两大步：**① 装 TrollStore → ② 云编译出 IPA → ③ TrollStore 装上**。

---

## 第一步：装 TrollStore（要一台 Windows）

15.8.8 有两条路，按你的设备芯片选。

### 先确认芯片

设置 → 通用 → 关于本机 → 型号名称。对照：

| 机型 | 芯片 | 走哪条 |
|---|---|---|
| iPhone 6s / SE 一代 | A9 | 下面任一 |
| iPhone 7 | A10 | 下面任一 |
| iPhone 8 / X | A11 | 下面任一 |
| iPhone XS 及以后 | 不该停在 15.8.8，若确实如此见备注 |

### 路线 1：TrollInstallerDark（推荐，电脑只用一次）

这个工具专门补上了 15.7.2–15.8.x 的缺口，由 TrollInstallerX 二改，用 DarkSword 漏洞。

1. Windows 装 **Sideloadly**（官网 sideloadly.io）和 **iTunes**（微软商店那版不行，
   要 apple.com 下的完整版，Sideloadly 需要它的驱动）
2. 下载 `TrollInstallerDark.ipa`（GoogLe 搜这个名字，来源认准 GitHub / 作者发布页）
3. 手机连电脑，信任这台电脑
4. Sideloadly 里拖入 `TrollInstallerDark.ipa`，填 Apple ID，点 Start
   （免费 Apple ID 就行，只是用来签这一次名）
5. 手机上打开 TrollInstallerDark → 点 **Install TrollStore**
6. 弹窗让你选一个系统 App 装「持久性助手」→ 选 **提示（Tips）**
7. 提示成功后，打开系统的「提示」App → 点 **Install TrollStore**
8. 桌面出现 TrollStore → 打开 → Settings → **安装 ldid**

> 卡住的话：点安装后日志红字提示「利用内核漏洞失败」→ 重启手机再试；
> 装 TrollStore 或 ldid 一直转圈 → 换网络，有条件开特殊网络环境。

### 路线 2：TrollRestore（PC 端，官方推荐）

如果路线 1 搞不定，用这个。它对 15.8.x 是官方支持的方式。

1. 手机：设置 → 你的 Apple ID → 查找 → **关闭「查找我的 iPhone」**（必须）
2. 手机：App Store 装官方的 **「提示 / Tips」** App（必须，它会被替换）
3. Windows 装 iTunes（同样要完整版）
4. 下载 TrollRestore（[GitHub: seregonwar/TrollRestore-GuiVersion](https://raw.githubusercontent.com/seregonwar/TrollRestore-GuiVersion/refs/heads/main/README.md)
   有图形界面版，比命令行版省事）
5. 跑 TrollRestore → 提示「输入应用名称」时输 `Tips` → 回车
6. 手机会自动重启，重启后打开「提示」App → Install TrollStore
7. TrollStore 里 Settings → 安装 ldid

> 报 `Failed to find the removable system app 'Tips.app'` → 回 App Store 装「提示」
> 报 `Find My must be disabled` → 回去关「查找我的 iPhone」

### 备注：如果是 A12 及以后的设备

15.8.8 是给老设备的版本，A12+ 理论上不该停在 15.8.8。如果你确实是这样，
TrollStore 在该组合上**不可用**，只能走 Sideloadly 七天一签（见文末）。

---

## 第二步：云编译出 IPA（全程浏览器）

### 2.1 建仓库

仓库我已经在本地初始化好了（两个 commit，含全部代码和资源）。
你只需要在 GitHub 网页上建个空仓库，然后：

```bash
cd C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp

git remote add origin https://github.com/<你的用户名>/leicalab.git
git push -u origin main
```

推送大约 128 MB。慢的话等一会儿，别中断。

### 2.2 私仓还是公开仓？

这个要提前想清楚，因为影响你能不能免费用 macOS runner：

| | 免费额度 | 缺点 |
|---|---|---|
| **公开仓** | macOS 不限时 | 289 MB 徕卡素材对所有人生效可见 |
| **私仓** | 2000 分钟/月，macOS 按 **10 倍** 计 = **约 200 分钟** | 一次构建约 10 分钟 → **每月约 20 次** |

考虑到素材的版权状况，**建议用私仓**。20 次构建够你调试很久了。
真用完了，等下个月，或者临时把仓转公开跑一次再转回来。

### 2.3 跑工作流

1. 打开仓库 → **Actions** 标签
2. 左侧选 **Build unsigned IPA** → 右侧 **Run workflow** → 绿色按钮
3. 等 10–15 分钟
4. 完成后页面底部 **Artifacts** → 下载 `LeicaLab-ipa.zip`
5. 解压得到 `LeicaLab.ipa`

**第一次大概率会报错。** 我在 Windows 上只能做静态检查，
编译期的类型推断、并发检查这些抓不到。

报错时这么办：

- Actions 页面点进失败的 job，展开 **Build (Release, unsigned)** 那一步
- 日志里搜 `error:`，把那段贴给我
- 或者下载 `build-log` artifact（失败时我会自动上传 `build.log`）

我改完，你再跑一次。通常两三轮。

---

## 第三步：装上手机

1. 把 `LeicaLab.ipa` 传到 iPhone（AirDrop / 微信文件传输助手 / iCloud 云盘都行）
2. 在「文件」App 里长按 ipa → 分享 → **TrollStore**
   （或直接打开 TrollStore，点右上角 `+` → 选文件）
3. TrollStore 里点 Install

装好后打开就能用。`NSPhotoLibraryUsageDescription` 我已经在
`project.yml` 里写好了，第一次选图会正常弹权限框。

---

## 如果 TrollStore 实在装不上

那就只能走 Sideloadly 七天一签：

1. Sideloadly → 拖入 `LeicaLab.ipa` → 填 Apple ID → Start
2. 装完去 设置 → 通用 → VPN与设备管理 → 信任你的开发者证书
3. **7 天后失效**，要用 Sideloadly 重新 Start 一次（数据不丢）

免费 Apple ID 还有两个限制：最多同时装 3 个自签 App、每次签名有效期 7 天。
这个 App 有 289 MB 资源，重签一次要几分钟，比较烦 —— 所以还是值得把 TrollStore 装上的。

---

## 附：iOS 15 兼容性改动（这一轮已做）

工程部署目标从 17.0 降到了 **15.0**，代码里这几处改成了 iOS 15 的写法：

| 改前（iOS 16+） | 改后（iOS 15） |
|---|---|
| `NavigationStack` | `NavigationView` + `.navigationViewStyle(.stack)` |
| `ToolbarItem(placement: .topBarTrailing)` | `.navigationBarTrailing` |
| `.onChange(of:) { _, _ in }` | `.onChange(of:) { _ in }` |
| `.foregroundStyle(...)` | `.foregroundColor(...)` |
| `.overlay { ... }` | `.overlay(_:alignment:)` |
| `.background(.ultraThinMaterial, in: Capsule())` | `.background(Capsule().fill(...))` |

其余用到的 API 都在 iOS 15 范围内：`@Environment(\.dismiss)`（15+）、
`AsyncImage` 没用、`Task.detached`（Swift 5.5 向下兼容到 iOS 13）。

---

## 附：依赖版本速查

| 组件 | 要求 |
|---|---|
| 部署目标 | iOS 15.0+ |
| 你的系统 | iOS 15.8.8 ✅ |
| Xcode（CI 上用） | macOS-15 runner 自带 Xcode 16 |
| Swift | 5.0 语法 / 5.5 并发特性 |

如果编译报「'xxx' is only available in iOS 16.0 or newer」，
把那条错误贴给我，说明我漏了一处降级。
