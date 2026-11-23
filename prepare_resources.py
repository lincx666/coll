# -*- coding: utf-8 -*-
"""把 ios-port 的资产整理成 iOS App bundle 的形状。

产物：iOSApp/LeicaLab/Resources/
    LUTs/         flat 33³ .bin（文件名即滤镜 id）
    HALD/         relens 的 HALD PNG
    Icons/        SVG 图标
    Lottie/       动画 json
    Sounds/       音效
    Frames/       相框模板
    Watermarks/   水印素材
    catalog.json  合并后的滤镜总目录
"""
import sys, os, json, shutil
sys.stdout.reconfigure(encoding='utf-8')

SRC = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\ios-port"
APP = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp"
RES = os.path.join(APP, "LeicaLab", "Resources")

for sub in ("LUTs", "HALD", "Icons", "Lottie", "Sounds", "Frames", "Watermarks"):
    d = os.path.join(RES, sub)
    os.makedirs(d, exist_ok=True)


def copy(src, dst):
    if os.path.exists(src):
        shutil.copy2(src, dst)
        return True
    return False


catalog = {"version": 1, "luts": [], "hald": [], "frames": [], "sounds": []}

# ---------- 1. 33³ .bin（luts + cameralook + aiscene 统一命名） ----------
n = 0
for folder, prefix, group in (
    (os.path.join(SRC, "luts_bin"), "", "camera"),
    (os.path.join(SRC, "aiscene_lut"), "", "aiscene"),
):
    if not os.path.isdir(folder):
        continue
    for f in sorted(os.listdir(folder)):
        if not f.endswith('.bin'):
            continue
        name = os.path.splitext(f)[0]
        dst = os.path.join(RES, "LUTs", name + ".bin")
        copy(os.path.join(folder, f), dst)
        n += 1
        catalog["luts"].append({"id": name, "group": group, "file": name + ".bin", "dim": 33})

# ---------- 2. relens HALD ----------
idx = json.load(open(os.path.join(SRC, "relens_index.json"), encoding="utf-8"))
by_hald = {}
for item in idx:
    by_hald.setdefault(item["hald_file"], []).append(item)

n_hald = 0
for hald, items in by_hald.items():
    if copy(os.path.join(SRC, "relens_hald", hald), os.path.join(RES, "HALD", hald)):
        n_hald += 1
    first = items[0]
    catalog["hald"].append({
        "id": os.path.splitext(hald)[0],
        "file": hald,
        "dim": 64,
        "names": [i["name"] for i in items],
        "category": first["category"],
        "groups": first["groups"].split('/') if first["groups"] else [],
        "scene": first.get("scene", ""),
        "count": len(items),
    })

# ---------- 3. 图标 ----------
icons_src = os.path.join(SRC, "icons_svg")
n_icon = 0
for f in os.listdir(icons_src):
    if f.endswith('.svg') and f != '_manifest.json':
        if copy(os.path.join(icons_src, f), os.path.join(RES, "Icons", f)):
            n_icon += 1

# ---------- 4. Lottie ----------
lot_src = os.path.join(SRC, "lottie")
n_lot = 0
for f in os.listdir(lot_src):
    if f.endswith('.json') and f != '_manifest.json':
        if copy(os.path.join(lot_src, f), os.path.join(RES, "Lottie", f)):
            n_lot += 1

# ---------- 5. 音效（两套合并，扁平） ----------
n_snd = 0
for folder in ("sounds", "sounds_cv"):
    p = os.path.join(SRC, folder)
    if not os.path.isdir(p):
        continue
    for f in os.listdir(p):
        if f.endswith('.wav'):
            if copy(os.path.join(p, f), os.path.join(RES, "Sounds", f)):
                n_snd += 1
                catalog["sounds"].append({"id": os.path.splitext(f)[0], "file": f})

# ---------- 6. 相框模板 ----------
fr_src = os.path.join(SRC, "frames")
n_fr = 0
for f in os.listdir(fr_src):
    if f.endswith('.json'):
        if copy(os.path.join(fr_src, f), os.path.join(RES, "Frames", f)):
            n_fr += 1
            j = json.load(open(os.path.join(fr_src, f), encoding='utf-8'))
            catalog["frames"].append({
                "id": j.get("id"),
                "file": f,
                "name": j.get("name", {}),
                "position": j.get("layout", {}).get("position", "BORDER"),
            })

# ---------- 7. 水印：只挑代表性子集（3 组） ----------
wm_src = os.path.join(SRC, "watermarks")
n_wm = 0
for group in ("leica", "classic", "film", "standard"):
    gdir = os.path.join(wm_src, group)
    if not os.path.isdir(gdir):
        continue
    for cfg_dir in sorted(os.listdir(gdir))[:8]:     # 每组前 8 个模板
        src_dir = os.path.join(gdir, cfg_dir)
        if not os.path.isdir(src_dir):
            continue
        dst_dir = os.path.join(RES, "Watermarks", group, cfg_dir)
        os.makedirs(dst_dir, exist_ok=True)
        for f in os.listdir(src_dir):
            if f.endswith(('.png', '.otf', '.json')):
                if copy(os.path.join(src_dir, f), os.path.join(dst_dir, f)):
                    n_wm += 1

json.dump(catalog, open(os.path.join(RES, "catalog.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)

print(json.dumps({
    "luts": n, "hald": n_hald, "icons": n_icon, "lottie": n_lot,
    "sounds": n_snd, "frames": n_fr, "watermarks": n_wm,
}, ensure_ascii=False))

total = sum(os.path.getsize(os.path.join(dp, f))
            for dp, _, fs in os.walk(RES) for f in fs)
print("Resources 体积: %.1f MB" % (total / 1024 / 1024))
