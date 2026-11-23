# -*- coding: utf-8 -*-
"""生成 App 图标（Assets.xcassets/AppIcon.appiconset）。

用一个中性的图形：深色底 + 一圈暖色光晕 + 中心小圆点，
不复制任何品牌 logo，纯粹是给桌面一个能认出来的标识。
"""
import sys, os, json
sys.stdout.reconfigure(encoding='utf-8')
from PIL import Image, ImageDraw, ImageFilter

APP = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\LeicaLab"
ASSETS = os.path.join(APP, "Assets.xcassets")
ICONSET = os.path.join(ASSETS, "AppIcon.appiconset")
os.makedirs(ICONSET, exist_ok=True)

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), (14, 14, 16))
d = ImageDraw.Draw(img)

# 顶部→底部轻微渐变
for y in range(SIZE):
    t = y / SIZE
    r = int(14 + 26 * t)
    g = int(14 + 20 * t)
    b = int(16 + 22 * t)
    d.line([(0, y), (SIZE, y)], fill=(r, g, b))

# 暖色光晕（模拟一点镜头光）
glow = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([SIZE * 0.18, SIZE * 0.10, SIZE * 0.82, SIZE * 0.74], fill=(150, 52, 48))
glow = glow.filter(ImageFilter.GaussianBlur(SIZE * 0.16))
img = Image.blend(img, Image.blend(img, glow, 0.55), 0.75)

d = ImageDraw.Draw(img)

# 中央圆环 + 圆点
cx = cy = SIZE / 2
ring_r = SIZE * 0.28
d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
          outline=(238, 236, 230), width=int(SIZE * 0.022))

dot_r = SIZE * 0.085
d.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=(238, 236, 230))

# 底部一条细细的金线
d.line([(SIZE * 0.32, SIZE * 0.80), (SIZE * 0.68, SIZE * 0.80)],
       fill=(198, 174, 122), width=int(SIZE * 0.012))

img.save(os.path.join(ICONSET, "icon-1024.png"))

contents = {
    "images": [
        {"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}
    ],
    "info": {"author": "xcode", "version": 1},
}
json.dump(contents, open(os.path.join(ICONSET, "Contents.json"), "w"), indent=2)

json.dump({"info": {"author": "xcode", "version": 1}},
          open(os.path.join(ASSETS, "Contents.json"), "w"), indent=2)

print("图标已生成:", os.path.join(ICONSET, "icon-1024.png"))
print("尺寸:", img.size)
