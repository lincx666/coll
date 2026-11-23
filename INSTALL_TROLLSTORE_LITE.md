# TrollStore Lite：越狱机最省事的装法

你把源加错了 —— 而且**你搜到的 `TrollStore Lite` 才是正解**。

先说两件事：那两个源为什么报错、TrollStore Lite 到底是不是真的。

---

## 一、那两个源为什么加不上

| 源 | 情况 |
|---|---|
| `https://cydia.akemi.ai` | **经常宕机**。作者 Karen/あけみ 的源多年来一直不稳定，社区里长期有「暂时无法访问」的记录。不是你网络的问题。 |
| `https://lukezgd.github.io/repo` | 第三方镜像，不一定还有这个包。 |

AppSync Unified 的官方备用分发方式是 **GitHub Releases 里的 .deb 文件**：

- <https://github.com/akemin-dayo/AppSync/releases>
- 最新 **116.0**，支持到 iOS 18.2
- `iphoneos-arm64` = **rootless 用**（你大概率是这个）
- `iphoneos-arm` = rootful / fakefs 用

下载对应的 .deb，然后：

```bash
# rootless
dpkg -i ai.akemi.appsyncunified_116.0_iphoneos-arm64.deb

# rootful
dpkg -i ai.akemi.appsyncunified_116.0_iphoneos-arm.deb
```

或者用 Filza 点 .deb 直接装。

装完 `killall SpringBoard`。

---

## 二、TrollStore Lite 是真的，而且是官方出的

这条要专门说清楚，因为网上假巨魔太多了：

**TrollStore Lite 是 opa334（原版 TrollStore 作者）本人做的**，2024 年 9 月随 TrollStore 2.1 一起发布，托管在 **Havoc 源**（Sileo 自带，不用加源）。

它和原版 TrollStore 的区别：

| | 原版 TrollStore（蓝图标） | **TrollStore Lite（白图标）** |
|---|---|---|
| 依赖 | CoreTrust 漏洞 | **依赖越狱环境** |
| 支持范围 | iOS 14.0–16.6.1、16.7 RC、17.0 | 不受 CoreTrust 限制，越狱就能用 |
| 重启后 | 照常工作 | **丢失越狱 → 打开闪退** |
| 安装方式 | 系统 App 注入持久性助手 | 普通 deb 包 |

对你来说：**palera1n 是半绑定越狱，重启本来就要重新越狱**，所以 Lite 版「依赖越狱」这个限制对你几乎没影响。

而且它比 `appinst` 友好得多 —— 有图形界面，Safari 里点 ipa 直接分享给它就能装。

---

## 三、走 TrollStore Lite（推荐）

### 3.1 装它

Sileo 里直接搜 **TrollStore Lite**（Havoc 源自带，**不用加任何新源**）：

- 包名：`com.opa334.trollstorelite`
- 版本：2.1.1
- 依赖：`ldid`（会让你一起装）

装上之后桌面出现**白色图标**的 TrollStore Lite。

> **注意辨别**：真正的 TrollStore Lite 图标是白色的、作者写 opa334、
> 来源是 Havoc。任何要你输 Apple ID、装描述文件、或者从网盘下 ipa 的「巨魔」都是假的。

### 3.2 装 AppSync Unified

TrollStore Lite 有个关键行为：

- **没装 AppSync** → 装进去的 App 注册成「系统应用」
- **装了 AppSync** → 注册成「用户应用」，**注册会自动保持**

所以强烈建议先把 AppSync 装上。搞不定源就用上面第一部分的 .deb 手动装。

### 3.3 装 App

1. Safari 里下载 `LeicaLab.ipa`
2. 「文件」App 里找到它 → 长按 → **分享**
3. 分享菜单里选 **TrollStore Lite**
4. 弹出提示 → **Install**
5. 等它装完，桌面出现 Leica Lab

或者：打开 TrollStore Lite → 右上角 **+** → 从「文件」里挑 ipa。

---

## 四、三条路对比

| | TrollStore Lite | appinst 命令行 | Sideloadly |
|---|---|---|---|
| 要电脑吗 | 不要 | 不要 | 要（且 7 天一次） |
| 要签名吗 | 不要 | 不要 | 要 |
| 有界面吗 | **有** | 无（终端） | 有 |
| 依赖 | 越狱 | AppSync | Apple ID |
| 你的情况 | ✅ **推荐** | ✅ 也行 | ❌ 没必要 |

---

## 五、装完怎么验证资源进包了

装好后如果打开是白屏 / 闪退，八成是资源没打进 `.app`。用 SSH 查：

```bash
ls /var/containers/Bundle/Application/*/LeicaLab.app/ | head
```

应该能看到 `LUTs`、`HALD`、`Frames` 这些目录。如果没有，回来告诉我。

再确认一下 LUT 文件：

```bash
ls /var/containers/Bundle/Application/*/LeicaLab.app/LUTs | head
# 应该看到 leica.bin  standard.bin  ...
```

---

## 附：AppSync Unified 116.0 的兼容性

官方 changelog 写的：**支持到 iOS 18.2**。你的 15.8.8 完全没问题。

如果 Sileo 里看到的版本比 116.0 老（比如 90.0），那是别的源里的旧版，
建议用 GitHub Releases 的 .deb 手动装，别装旧版 —— 旧版对 iOS 15 后期版本支持不全。
