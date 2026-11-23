# 没有 Mac，怎么把 `LeicaLab` 装到手机上

三条路，按「省事程度」排序。你越狱机，**第一条最省事**。

---

## 路线 A：GitHub Actions 云编译（推荐）

GitHub 有免费的 macOS 14/15 runner，公开仓库不限时。整个流程全在浏览器里完成。

### A1. 建仓库并推送

```bash
cd iOSApp
git init
git add .
git commit -m "Leica Lab: iOS port of 123v2 assets"

# 在 GitHub 上建个空仓库，然后
git remote add origin https://github.com/<你的用户名>/leicalab.git
git push -u origin main
```

**资源体积**：LUTs 199 MB + HALD 75 MB，单个文件都小于 1 MB，总量 289 MB
在 GitHub 允许范围内（单文件上限 100 MB，仓库上限按软限制 $5/GB）。
直接推能成，但很慢；用 LFS 会舒服很多：

```bash
git lfs install
git lfs track "LeicaLab/Resources/LUTs/*.bin"
git lfs track "LeicaLab/Resources/HALD/*.png"
git add .gitattributes
git commit -m "Track binary resources with LFS"
git push
```

> 注意：LFS 免费额度只有 1 GB 存储 + 1 GB/月流量。首次拉取用掉 274 MB，
> 之后每次 CI 运行再算一次。够用十几次。

### A2. 触发构建

仓库建好后，`.github/workflows/build-ipa.yml` 会自动生效：

1. 打开仓库页面 → **Actions** 标签
2. 左边选 **Build unsigned IPA** → 右侧 **Run workflow**
3. 等 8–15 分钟（第一次要装 XcodeGen + 编译 289 MB 资源）
4. 构建完，页面底部 **Artifacts** 里下载 `LeicaLab-ipa.zip`
5. 解压得到 `LeicaLab.ipa` 和 `LeicaLab.tipa`

如果编译失败，Actions 日志里会打红，`build.log` 也会作为 artifact 上传。
把 `error:` 那几行贴给我，我改。

### A3. 装到手机

越狱机用 **TrollStore**：

1. TrollStore 已装好 → 把 `.tipa` 传到 iPhone（AirDrop / 微信文件传输助手）
2. 在「文件」App 里长按 `.tipa` → 分享 → **Open in TrollStore**
3. TrollStore 里点 Install

没越狱但想要永久签名，也是 TrollStore 这条路（需要它的漏洞支持你的 iOS 版本）。
纯侧载的话用 **Sideloadly**（Windows 版，需要 Apple ID，7 天掉签）。

---

## 路线 B：租一台云 Mac（想调试时用）

GitHub Actions 只能看到「编译成功/失败」，改代码时没法实时看效果。
想边改边看，租按小时计费的 Mac 更合适。

| 服务 | 价格 | 特点 |
|---|---|---|
| **MacStadium** | ~$0.15/小时起 | 老牌，按小时 |
| **MacinCloud** | ~$1/小时 | 有图形界面，浏览器操作 |
| **Scaleway Apple Silicon** | ~€0.10/小时 | 欧洲，M1 裸金属 |
| **腾讯云 Mac 实例** | 国内可用 | 按小时，延迟低 |

大致流程：开机器 → 装 Xcode（可用 `xcodes` 命令行工具）→ 把工程拷过去 →
改完直接连真机调试（越狱机可以走 `iproxy` + `lldb` 远程 attach）。

**成本估算**：改代码那几天，每天用 2 小时，一周大约 $10–20。

---

## 路线 C：Windows 上「半自动」（只能改代码，不能编译）

如果暂时不想碰云机器，我可以在 Windows 侧做这些事：

1. **语法检查**：用 `swift-format` / SourceKit-LSP 的 Windows 版做静态解析
   （能做类型检查，但没法链接 UIKit）
2. **逻辑单测**：把不依赖 UIKit 的部分（LUT 解析、HALD 重排、相框模板计算）
   抽成纯 Swift 模块，在 Windows 上跑测试
3. **预览图**：用 Python 模拟 Swift 的渲染逻辑，先生成「应该长什么样」的图，
   你看着判断效果对不对

第 3 条其实**已经在做了** —— `ios-port/_preview/` 里那两张对照图就是这么来的
（`relens_sheet.png` 是 293 个滤镜套到测试图上的效果）。

---

## 我的建议

**先走 A**，把工程推到 GitHub，跑一次云编译。

理由：
- 不需要装任何东西，也不用付费
- 第一次编译大概率有报错，Actions 的日志比本地 Xcode 还清楚
- 我在 Windows 上没法编译，只能靠你跑一次把错误贴回来

等你把第一批报错给我，我改完，再跑一次。通常两三轮就能出可用的 `.ipa`。

---

## 需要你回答的问题

1. **GitHub 账号有吗？** 有的话我可以直接把仓库初始化好（`git init` + 首次
   commit），你只需要在网页上建仓库、然后 `git push`。
2. **iOS 版本？** 已确认是 15.8.8，部署目标已降到 15.0 —— 见
   [INSTALL_IOS15.md](INSTALL_IOS15.md)
3. **TrollStore 装了吗？** 还没有。15.8.8 要选对安装器（TrollInstallerX 不支持
   这个版本），具体流程也在 [INSTALL_IOS15.md](INSTALL_IOS15.md)。
