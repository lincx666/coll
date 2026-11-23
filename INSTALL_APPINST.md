# appinst 路线：越狱机直接装，不签名不折腾

你的情况：iPhone SE 一代（A9）、iOS 15.8.8、**palera1n 已越狱**。

越狱之后，装 IPA 这件事本来就不需要签名了 —— AppSync Unified 会替你把签名校验关掉。
一共四条命令的事。

---

## 前提检查

先确认你的 palera1n 是 **rootless** 还是 **rootful**。在手机上用 SSH 或终端跑：

```bash
ls -d /var/jb 2>/dev/null && echo "rootless" || echo "rootful"
```

- 有 `/var/jb` → **rootless**（palera1n `-l` 参数，现在的主流）
- 没有 → **rootful**（palera1n `-f` 参数）

这个区别只影响**从哪里装包**，`appinst` 用法一样。

> 不确定的话：打开 Sileo，看首页顶部有没有写 `Rootless` 或 `Rootful`。
> 或者看你的越狱脚本，`palera1n -l` 就是 rootless。

---

## 第一步：加源

Sileo 里加这两个源：

| 源 | 用途 |
|---|---|
| `https://repo.hackyouriphone.org` | AppSync Unified（也可用 `https://cydia.akemi.ai`） |
| `https://lukezgd.github.io/repo` | appinst（LukeZGD 的镜像，含 rootless 版） |

添加方式：Sileo → 底部 **Sources**（源）→ 右上角 **+** → 粘贴 URL → 添加。

> `cydia.akemi.ai` 是 Karen/あけみ 的官方源，AppSync Unified 从这里装最正。
> appinst 依赖它，所以两个都要装。

---

## 第二步：装包

Sileo 里搜这两个，依次安装：

1. **AppSync Unified**（作者 Karen/あけみ）
   - rootless 装 `ai.akemi.appsyncunified` 的 **arm64** 版本
   - 如果 Sileo 自动给你选了版本，直接装就行

2. **appinst (App Installer)**（同一个作者）
   - 会自动带上 AppSync Unified 依赖

装完重启一下 SpringBoard（Sileo 会提示，或者 `killall SpringBoard`）。

---

## 第三步：把 IPA 传到手机

三种都行：

- **微信文件传输助手** → 手机保存到「文件」App
- **iCloud 云盘** → 手机上「文件」App 里能看到
- **SSH / scp**（你越狱了应该有 OpenSSH）：
  ```bash
  scp LeicaLab.ipa root@<手机IP>:/var/mobile/Downloads/
  ```
  默认密码 `alpine`，装完记得改

记一下路径，下面要用。常见路径：

```
/var/mobile/Downloads/LeicaLab.ipa
/var/mobile/Documents/LeicaLab.ipa
```

---

## 第四步：装

SSH 进手机（或者用 **NewTerm** / **Termius** 这类终端 App），执行：

```bash
appinst /var/mobile/Downloads/LeicaLab.ipa
```

等几秒到几十秒（289 MB 资源，SE 上会慢一些），看到类似这样的输出就成了：

```
Installing: /var/mobile/Downloads/LeicaLab.ipa
Success
```

桌面上就会出现 **Leica Lab** 图标。

> **如果提示 `appinst: command not found`**
> 说明 PATH 里没有 `/usr/bin`（很少见），用绝对路径：
> ```bash
> /usr/bin/appinst /var/mobile/Downloads/LeicaLab.ipa
> ```
> rootless 环境下可能在 `/var/jb/usr/bin/appinst`。

> **如果提示签名相关错误**
> AppSync Unified 没装好或没生效。重启一下 SpringBoard 再试。

---

## 备选：Filza 点一下

装了 AppSync Unified 之后，Filza 也能直接装：

1. Filza 里找到 ipa
2. 点它
3. 弹出菜单选 **Install**

底层走的是同一套，适合不想开终端的时候。

---

## 备选：还是想用 TrollStore

你越狱了，TrollStore 反而是最简单的装法：

1. Sileo 加源 `https://havoc.app`
2. 搜 **TrollStore Helper**，装
3. 打开它 → **Install TrollStore**

不用折腾 DarkSword 漏洞，不用挂「提示」App，不用电脑。

**好处**：重启后不用重新装（但你是半绑定越狱，重启本来就要重新越狱，所以优势不大）。

---

## 三步总览

```
① Sileo 加源（hackyouriphone / akemi.ai + lukezgd）
   ↓
② 装 AppSync Unified + appinst
   ↓
③ 把 ipa 传进手机，SSH 里 appinst 一下
```

就完了。

---

## 可能踩的坑

| 现象 | 原因 | 解决 |
|---|---|---|
| `appinst: command not found` | PATH 问题 | 用绝对路径 `/usr/bin/appinst` |
| `Failed to install` + 签名错误 | AppSync 没生效 | `killall SpringBoard` 或重启 |
| 装上但闪退 | 资源没打进去 / 架构不对 | 见下面「怎么确认包是好的」 |
| 图标出现但打不开 | 同上 | 同上 |

### 怎么确认包是好的

在 SSH 里看一眼：

```bash
ls /var/containers/Bundle/Application/*/LeicaLab.app/Resources/LUTs | head
```

应该能看到 `leica.bin`、`standard.bin` 这些。如果没有，说明 CI 打包时资源没进去，
回来告诉我，我改 workflow。

也可以用 `otool -L` 看架构，但 SE 是 arm64，CI 产的包本来就是 arm64，一般不用查。
