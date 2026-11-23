# -*- coding: utf-8 -*-
"""检查 Swift 源码里的跨文件符号引用是否都能找到定义。

不是编译器，只是个「有没有明显拼错 / 忘了定义」的粗筛。
"""
import sys, re, os
sys.stdout.reconfigure(encoding='utf-8')

BASE = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\LeicaLab"

files = []
for dp, _, fs in os.walk(BASE):
    for f in fs:
        if f.endswith('.swift'):
            files.append(os.path.join(dp, f))

sources = {os.path.relpath(p, BASE): open(p, encoding='utf-8').read() for p in files}
combined = "\n".join(sources.values())

# ---- 定义的顶层类型 ----
type_defs = set(re.findall(r'\b(?:struct|class|enum|protocol)\s+(\w+)', combined))

# ---- 每个文件里用到的自定义类型（排除系统类型） ----
custom_candidates = {
    'AppCatalog', 'LUTEntry', 'HALDEntry', 'FrameEntry', 'SoundEntry',
    'FilterLibrary', 'HALDCategory', 'BundleResource', 'LUTProcessor',
    'FrameTemplate', 'FrameRenderer', 'PhotoMetadata', 'RenderPipeline',
    'EditorModel', 'RootView', 'EditorView', 'EmptyStateView',
    'FilterSheet', 'FrameSheet', 'PhotoPicker', 'LeicaLabApp',
}

missing = custom_candidates - type_defs
print("自定义类型定义缺失:", sorted(missing) if missing else "无")

# ---- 检查每个文件都能"看到"它用到的类型（Swift 同 module 内不用 import） ----
print("\n各文件引用的自定义类型：")
for rel, src in sorted(sources.items()):
    used = sorted({t for t in custom_candidates if re.search(r'\b' + t + r'\b', src)})
    print(f"  {rel:28s} {', '.join(used) if used else '(无)'}")

# ---- 检查关键的 Bundle / 资源方法是否成对 ----
print("\n关键 API 调用检查：")
checks = [
    ("BundleResource.lut", "func lut("),
    ("BundleResource.hald", "func hald("),
    ("BundleResource.frame", "func frame("),
    ("BundleResource.url", "func url(name:"),
    ("LUTProcessor.colorCube(named:)", "func colorCube(named:"),
    ("LUTProcessor.colorCube(hald:)", "func colorCube(hald"),
    ("FrameTemplate.load", "static func load(file:"),
    ("RenderPipeline.preview", "func preview("),
    ("RenderPipeline.export", "func export("),
    ("RenderPipeline.downscale", "static func downscale("),
    ("FrameRenderer.render", "func render("),
    ("PhotoMetadata.context", "static func context(from"),
    ("FilterLibrary.items(in:)", "func items(in category:"),
]
for label, sig in checks:
    print(f"  {label:34s} {'OK' if sig in combined else 'MISSING'}")

# ---- 找出 TODO / FIXME / 明显错误 ----
print("\n遗留标记：")
for rel, src in sorted(sources.items()):
    for i, line in enumerate(src.split('\n'), 1):
        if any(k in line for k in ('TODO', 'FIXME', 'XXX')):
            print(f"  {rel}:{i}  {line.strip()}")
