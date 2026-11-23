# -*- coding: utf-8 -*-
"""把 iOSApp 整理成一个可推送的 git 仓库。

处理两件事：
1. 排除脚本产物（__pycache__ 等）
2. 资源体积 —— 289 MB 直接推 GitHub 会被拒（单文件 >100 MB / 仓库 >1 GB）
   给出两条路：走 LFS，或走 Release 附件。
"""
import sys, os, json
sys.stdout.reconfigure(encoding='utf-8')

ROOT = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp"

# 统计各目录体积
rows = []
for dp, dns, fs in os.walk(ROOT):
    if '.git' in dp:
        continue
    total = sum(os.path.getsize(os.path.join(dp, f)) for f in fs)
    if total > 1_000_000:
        rows.append((os.path.relpath(dp, ROOT), total, len(fs)))

rows.sort(key=lambda r: -r[1])
print("超过 1 MB 的目录：")
for rel, size, n in rows:
    print(f"  {rel:46s} {size/1024/1024:8.1f} MB  ({n} 文件)")

total = sum(r[1] for r in rows)
print(f"\n合计约 {total/1024/1024:.0f} MB")

# 单个大文件
print("\n超过 10 MB 的单个文件：")
found = False
for dp, _, fs in os.walk(ROOT):
    for f in fs:
        p = os.path.join(dp, f)
        s = os.path.getsize(p)
        if s > 10 * 1024 * 1024:
            print(f"  {os.path.relpath(p, ROOT):56s} {s/1024/1024:7.1f} MB")
            found = True
if not found:
    print("  （无）")

# 资源文件数
res = os.path.join(ROOT, "LeicaLab", "Resources")
n_res = sum(len(fs) for _, _, fs in os.walk(res))
print(f"\nResources 共 {n_res} 个文件")
print("  → 走 LFS: git lfs 会把它们存成指针，仓库本体只有几 MB")
print("  → 不走 LFS: GitHub 单文件上限 100 MB（当前最大 "
      f"{max(os.path.getsize(os.path.join(dp,f)) for dp,_,fs in os.walk(res) for f in fs)/1024/1024:.1f} MB），"
      "总量 289 MB 也偏大，但勉强能推")
