# iOS 15.8.8 + iPhone SE 一代：从零到装上

你的设备：**iPhone SE（2016，A9，2 GB 内存）、iOS 15.8.8、没装 TrollStore、没有 Mac、有 Windows**。

结论先说：**能装，而且能永久装。**

而且你这个组合有个**很大的优势**：A9 是 checkm8 漏洞设备（BootROM 级、苹果修不了），
意味着你还有一条别人没有的兜底路线 —— **palera1n 越狱**。
走那条路的话，TrollStore 甚至不用折腾漏洞，在越狱环境里一条命令就装上。

分两种走法，你选一个：

| | 路线 A：TrollInstallerDark | 路线 B：palera1n 越狱 |
|---|---|---|
| 要电脑吗 | 要（签一次名） | 要（每次重启都要插线） |
| 难度 | 中 | 中高 |
| 稳定性 | 好 | 极好 |
| 额外好处 | 无 | 可装插件、可改系统 |
| 重启后 | 正常用 | 需重新跑 palera1n |

**如果只想要这个 App，走 A。想顺便玩越狱，走 B。**

---

## 路线 A：TrollInstallerDark（推荐）

15.8.7/15.8.8 是 2024 年后才发的补丁版本，**老的 TrollInstallerX 不支持**。
TrollInstallerDark 是基于 Alfie 的 TrollInstallerX 二改，用 DarkSword 漏洞补上了这段。

### 准备工作（都在手机上，先做完）

1. **关掉「查找我的 iPhone」**：设置 → 顶部你的名字 → 查找 → 查找我的 iPhone → 关
   （要输 Apple ID 密码）
2. **装官方「提示」App**：App Store 搜「提示」或 Tips，装上
   （它会被替换成持久性助手，所以必须是官方从 App Store 装的）

### Windows 侧

1. 装 **iTunes** —— 注意要用 [apple.com 下载的完整版](https://www.apple.com/itunes/)，
   **微软商店那版不行**（Sideloadly 靠它的驱动通信）
2. 装 **Sideloadly**：sideloadly.io
3. 下载 **TrollInstallerDark.ipa**（搜这个名字，认 GitHub / 作者发布页，
   别下那些来路不明的网盘包）
4. 手机用 **USB-A 转 Lightning 线**连电脑（USB-C 线通过这些工具时容易识别不了）
5. 手机上点「信任」

### 签名安装

1. Sideloadly 里拖入 `TrollInstallerDark.ipa`
2. Apple ID 填你的（**免费账号就行**，只是签这一次名）
3. 点 Start → 输密码
4. 装完去 **设置 → 通用 → VPN与设备管理** → 信任你的开发者证书

### 装 TrollStore

1. 打开 TrollInstallerDark → 点 **Install TrollStore**
2. 弹窗让你选一个系统 App 装持久性助手 → **选「提示」**
3. 提示成功后，**打开系统的「提示」App** → 点 **Install TrollStore**
4. 桌面出现 TrollStore → 打开 → Settings → **安装 ldid**

> **卡住怎么办**
> - 日志红字「利用内核漏洞失败」→ 重启手机再试，通常第二次就过
> - 装 TrollStore 或 ldid 一直转圈 → 换网络，有条件开特殊网络
> - 选「提示」时报找不到 App → 回 App Store 重装一次「提示」

---

## 路线 B：palera1n（A9 专属兜底）

palera1n 是用 checkm8 漏洞的越狱，**只支持 A8–A11**，你的 SE 正好在范围内。
因为它打的是 BootROM，苹果永远修不了。

坏处：**半绑定**，每次重启后要插电脑重新跑一遍（数据不丢，但要电脑在旁边）。

### 流程概览

1. Windows 上装 palera1n（Windows 支持有限，**强烈建议用 Linux Live USB**
   或 WSL，不过 WSL 的 USB 穿透不太可靠，原生 Linux 最稳）
2. `sudo palera1n -l`（rootless 模式）→ 手机进 DFU → 自动越狱
3. 桌面上出现 Sileo（包管理器）
4. Sileo 里加 TrollStore 源，装 **TrollStore Helper**
5. 打开 TrollStore Helper → Install TrollStore
6. 之后装 App 就跟路线 A 一样了

> 细节看 [palera1n 官方文档](https://docs.palera.in/)。这条路信息量大，
> 如果你决定走，我再帮你把具体步骤写细。

---

## 第二步：云编译出 IPA（两条路线都一样）

### 2.1 建仓库

仓库我已经在本地初始化好了（4 个 commit，含全部代码和资源）。
你只需要在 GitHub 网页上建个空仓库，然后：

```bash
cd C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp

git remote add origin https://github.com/<你的用户名>/leicalab.git
git push -u origin main
```

推送大约 128 MB。慢的话等一会儿，别中断。

**推送时可能弹窗要登录**：用户名填 GitHub 账号，密码位置要填 **Personal Access Token**
（GitHub 早就不支持账号密码了）。生成：GitHub → Settings → Developer settings →
Personal access tokens → Fine-grained tokens → 勾 `repo` 权限。
如果你装了 Git Credential Manager，会直接弹浏览器授权，不用手动生成。

**token 别发给我**，这个不需要。

### 2.2 私仓还是公开仓？

这个要提前定，因为影响免费额度：

| | macOS 分钟数 | 缺点 |
|---|---|---|
| **公开仓** | 不限 | 289 MB 徕卡/哈苏素材对所有人可见 |
| **私仓** | 2000 分钟/月，macOS 按 **10 倍**计 ≈ **200 分钟** | 一次约 10 分钟 → **每月约 20 次** |

考虑到素材版权，**建议私仓**。20 次够调试很久。用完了等下月，
或临时转公开跑一次再转回来。

### 2.3 跑工作流

1. 仓库 → **Actions** → 左侧选 **Build unsigned IPA** → 右侧 **Run workflow**
2. 等 10–15 分钟
3. 完成后底部 **Artifacts** → 下载 `LeicaLab-ipa.zip` → 解压出 `LeicaLab.ipa`

**第一次大概率会报错。** 我在 Windows 上只能做静态检查，编译期的类型推断、
并发检查抓不到。报错时：

- 点进失败的 job → 展开 **Build (Release, unsigned)** → 搜 `error:` 贴给我
- 或者下载 `build-log` artifact（失败时自动上传 `build.log`）

---

## 第三步：装上手机

1. 把 `LeicaLab.ipa` 传到 iPhone（AirDrop / 微信文件传输助手 / iCloud 都行）
2. 「文件」App 里长按 ipa → 分享 → **TrollStore**
   （或 TrollStore 右上角 `+` → 选文件）
3. 点 Install

第一次选图会弹相册权限，正常授权即可。

---

## 关于 SE 一代的性能，我做了这些适配

SE 只有 **2 GB 内存 + A9**，289 MB 的资源和 33³ LUT 是好几个 G 的运算，
所以我这轮改了这些：

| 改动 | 原因 |
|---|---|
| 预览尺寸按屏幕算（约 1136px），不写死 1400 | SE 屏幕只有 1136px 长边，多渲染纯浪费 |
| 导出限幅 4000px | 2 GB 设备上 8000px + CIColorCube 中间缓冲会 OOM |
| LUT 缓存从 24 个降到 6 个 | 33³ 每个 575 KB，64³ 每个 1 MB |
| LUT 用 memory-mapped 读取 | 不整个复制进堆，省峰值内存 |
| 收到内存警告时清空缓存 | 系统压力大时主动让路 |
| 滤镜缩略图分批算（每批 8 张） | 一次算 116 张会爆内存 |
| 网格列宽收紧到 78/130pt | SE 屏幕 320pt 宽，96pt 会挤成 3 列且字被截断 |

**预期表现**：

- 打开滤镜面板 → 缩略图**一张一张出现**（不是一次性全出来），这是故意的
- 套滤镜预览 → 每张 1–3 秒（A9 上的正常速度）
- 导出 1200 万像素 → 5–10 秒
- 内存峰值应该能压在 600 MB 以内

如果实测还是卡或者闪退，告诉我具体哪一步，我再往下压。

---

## 附：iOS 15 兼容性（已做的降级）

| 改前（iOS 16+） | 改后（iOS 15） |
|---|---|
| `NavigationStack` | `NavigationView` + `.navigationViewStyle(.stack)` |
| `.topBarTrailing` / `.topBarLeading` | `.navigationBarTrailing` / `.navigationBarLeading` |
| `.onChange(of:) { _, _ in }` | `.onChange(of:) { _ in }` |
| `.foregroundStyle(...)` | `.foregroundColor(...)` |
| `.overlay { ... }` | `.overlay(_:alignment:)` |
| `.background(.ultraThinMaterial, in: Capsule())` | `Capsule().fill(...)` |

其余 API 都在 iOS 15 范围内。

如果编译报 `is only available in iOS 16.0 or newer`，把那条贴给我，说明我漏了一处。

