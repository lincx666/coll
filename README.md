# Leica Lab — iOS 后期 App

把 `123v2.apk` 里扒出来的资产做成一个能跑在 iPhone 上的「选图 → 套 LUT → 加相框 → 导出」应用。

> 个人自用 / 越狱侧载。不依赖任何私有 API，普通 Xcode 构建即可。

---

## 一、目录结构

```
iOSApp/                          ← 已 git init + 首次 commit（128 MB 打包后）
├── project.yml                  XcodeGen 规格（CI 用它生成工程）
├── .github/workflows/           build-ipa.yml：云编译出 .ipa
├── BUILD_WITHOUT_MAC.md         没有 Mac 怎么装到手机
├── LeicaLab.xcodeproj/          离线备份（make_project.py 生成）
├── LeicaLab/
│   ├── App/
│   │   ├── LeicaLabApp.swift    入口
│   │   └── EditorModel.swift    全局状态 + 渲染调度 + 存相册
│   ├── Core/
│   │   ├── FilterCatalog.swift  目录模型 + 分组索引
│   │   ├── BundleResource.swift 资源查找（兼容多种 bundle 布局）
│   │   ├── LUTProcessor.swift   CIColorCube + HALD 解码 + 强度混合
│   │   ├── FrameRenderer.swift  相框模板 DSL → Core Graphics
│   │   ├── PhotoMetadata.swift  EXIF 读取
│   │   └── RenderPipeline.swift 完整出图管线
│   ├── Views/
│   │   ├── RootView.swift       根视图 + 空态
│   │   ├── EditorView.swift     画布 + 控制条
│   │   ├── FilterSheet.swift    滤镜选择（三 tab + 实时缩略图）
│   │   ├── FrameSheet.swift     相框选择（实时预览）
│   │   └── PhotoPicker.swift    相册选图
│   ├── Assets.xcassets/         图标
│   └── Resources/               ← 655 个 LUT + 图标 + 动画 + 音效 + 相框
├── prepare_resources.py         从 ios-port 整理资源
├── make_project.py              生成 pbxproj（离线备份用）
├── make_icon.py                 生成图标
├── validate_project.py          校验工程完整性
├── lint_swift.py                Swift 静态粗筛
└── check_repo_size.py           仓库体积体检
```

---

## 二、怎么构建

**没有 Mac？看 [BUILD_WITHOUT_MAC.md](BUILD_WITHOUT_MAC.md)，
iOS 15.8.8 装 TrollStore 看 [INSTALL_IOS15.md](INSTALL_IOS15.md)** ——
走 GitHub Actions 云编译，全程浏览器操作，产出免签名 `.ipa`，TrollStore 直接装。

有 Mac 的话：

```bash
# 1. 确保 Resources 已就位（只用跑一次；改过 ios-port 后可重跑）
python prepare_resources.py

# 2. 用 XcodeGen 生成工程（推荐，比 make_project.py 手写的可靠）
brew install xcodegen
xcodegen generate --spec project.yml

# 3. 打开
open LeicaLab.xcodeproj
```

**签名设置**（`make_project.py` 里已写死成免签名，方便越狱机）：

```python
CODE_SIGN_STYLE = Manual
CODE_SIGNING_REQUIRED = NO
CODE_SIGNING_ALLOWED = NO
```

- 想用 **TrollStore**：这套设置直接打包 `.app`，用 ldid 自签后丢进 TrollStore 即可
- 想用 **Xcode 直接装**：把 `CODE_SIGNING_ALLOWED` 改回 `YES`，填上你的开发者证书
- 模拟器：无需任何签名，直接跑

部署目标 **iOS 15.0**，仅 iPhone 竖屏。（最初写的是 17.0，为了 15.8.8 的机器已经降下来了。）

---

## 三、三个核心实现

### 3.1 LUT：33³ `.bin` 直接吃，64³ HALD 现解

```swift
// 33³：575 KB 的 float32 RGBA 立方体，一条 GPU 滤镜
let filter = CIFilter(name: "CIColorCubeWithColorSpace")
filter.setValue(33, forKey: "inputCubeDimension")
filter.setValue(data, forKey: "inputCubeData")
filter.setValue(CGColorSpace(name: CGColorSpace.sRGB)!, forKey: "inputColorSpace")
```

用 `CIColorCubeWithColorSpace` 而不是 `CIColorCube`：前者能显式指定输入色彩空间，
否则暗部和高光会偏。

**HALD 为什么要在 CPU 侧解一次？** iOS 的 `CIColorCube` 只接受 Float32 立方体数据，
不吃图片。所以 512×512 的 HALD PNG 要先按「8×8 个 64×64 slice，slice 内 x=r / y=g，
slice 序号 = b」的规律重排成 64³ float 数组。解一次后缓存在 `NSCache` 里
（64³ × 16 字节 ≈ 1 MB / 个，`countLimit = 24`）。

**强度混合** 用 `CIMix` 而不是自己插值矩阵，色相不会漂：

```swift
mix.setValue(original, forKey: kCIInputBackgroundImageKey)
mix.setValue(filtered, forKey: kCIInputImageKey)
mix.setValue(intensity, forKey: "inputAmount")
```

### 3.2 相框：直接复用 APK 那套 JSON DSL

APK 里的 `assets/frames/*.json` 是个相当好用的声明式布局：

```json
{
  "layout": {
    "position": "BORDER",        // BORDER | OVERLAY | BOTH | IMAGE
    "height": 192,               // 底带高度
    "backgroundColor": "#FFFFFF",
    "padding": 24,
    "borderWidth": 12,
    "designSize": { "width": 4096, "height": 3072 }
  },
  "elements": [
    { "type": "logo", "overrideSource": "leica", "alignment": "START", "line": -1, "width": 96 },
    { "type": "text", "textType": "APERTURE", "alignment": "END", "fontSize": 42, "line": 0 },
    { "type": "text", "textType": "FILTER_NAME", "alignment": "END", "fontSize": 48, "line": 1 }
  ]
}
```

`FrameRenderer` 把它翻译成 Core Graphics：

- **`designSize.width` 是唯一基准**：所有尺寸 × `实际图像宽 / 4096`，所以同一套模板
  在 1200px 预览和 8000px 导出上视觉一致
- `line` = 同一基线上的分组，一行里按 `START / CENTER / END` 三段式排布
- `line = -1` 是「贴边 logo」，不参与文字行流
- 支持 `GAUSSIAN_BLUR` 背景（柔焦边框用）和 `IMAGE` 位图相框

### 3.3 元数据：缺什么就不画什么

```swift
if let f = exif[kCGImagePropertyExifFNumber] as? Double, f > 0 {
    info.aperture = f == f.rounded() ? "f/\(Int(f))" : String(format: "f/%.1f", f)
}
```

截图、微信转存图、修过的图，EXIF 往往全空。缺字段返回空串，渲染时那一块自然消失，
不会出现「f/  1/  ISO 」这种断片。

---

## 四、素材清单（`LeicaLab/Resources/`）

| 目录 | 内容 | 体积 |
|---|---|---:|
| `LUTs/` | 363 个 33³ `.bin`（93 徕卡系 + 23 相机 Look + 247 AI 场景） | 199 MB |
| `HALD/` | 288 张 64³ HALD PNG（relens 网红滤镜，292 条索引） | 75 MB |
| `Icons/` | 1266 个 SVG（AXML 还原） | 3.7 MB |
| `Lottie/` | 282 个动画 json | 6.4 MB |
| `Sounds/` | 35 段音效（四套快门风格 + 可换肤 `_cv`） | 0.9 MB |
| `Frames/` | 9 个相框模板 | 0.03 MB |
| `Watermarks/` | 328 个徕卡水印素材（PNG + 配置 + 字体） | 3.5 MB |
| **合计** | | **~289 MB** |

`catalog.json` 是给 App 读的总索引。

**体积说明**：289 MB 里 274 MB 是 LUT。越狱机不在乎体积；但如果哪天想瘦身，
优先砍 `HALD/` 里不常用的分类（每个滤镜约 260 KB）。

---

## 五、已验证 / 未验证

### 已验证（在 Windows 上能做的部分）

- 资源完整性：`validate_project.py` 全部 10 个 pbxproj 节 + 引用完整性通过
- Swift 结构：`lint_swift.py` 13 个文件括号平衡、自定义类型全部有定义、关键 API 成对
- LUT 数据：`.bin` 每个 574992 字节 = `33³ × 4 × Float32`，与 `CIColorCube` 要求一致
- HALD 规律：在 Python 里用同一套「8×8 slice」逻辑解过 288 张，中性灰映射正确

### 没验证（需要 Mac + Xcode）

- **Swift 编译**：Windows 上没有 Swift 工具链，代码是按 Xcode 16 / Swift 5.9 的语法写的，
  但不能保证零编译错误。第一次 `⌘R` 大概率要修几处类型推断。
- **实际观感**：288 个 relens 滤镜套到真实照片上好不好看，得你自己看
- **性能**：33³ 滤镜在 A 系芯片上单张 4000×3000 应该是秒级，但没实测

### 已知的坑

1. **首次启动慢**：`FilterSheet` 打开时要为当前 tab 的所有滤镜生成缩略图
   （相机色彩 116 个 → 约 2-3 秒）。缩略图有缓存，同一 session 内不会重算。
2. **`CIMix` 需要 iOS 13+**，本项目最低 17，没问题。
3. **相框字体**：`05_time.json` 用了 `DS-DIGIB.TTF`，但那个字体是 All Rights Reserved，
   没有打进资源，会 fallback 到系统字体。想要原味得自己处理授权。
4. **`06_kodak_portra_400.json` 是 `IMAGE` 类型**，需要一张位图相框素材
   （`frame_portra_400`），素材在 APK 的 `res/drawable` 里没扒出来，目前会退化成 OVERLAY。

---

## 六、下一步可以做的

- [ ] 把 `res/raw/` 里的 Lottie 接到 UI（快门动画、模式切换）
- [ ] 水印体系：`Watermarks/` 里那 328 个素材对应的 `config.json` 布局 DSL 还没接
- [ ] 批量处理（一组照片套同一个 LUT）
- [ ] LUT 收藏夹 / 最近使用
- [ ] 把 `relens` 的 `adjusts` / `defaults` 参数（每个滤镜附带的亮度/对比微调）也应用上
