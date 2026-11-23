# -*- coding: utf-8 -*-
"""解析 .ips 崩溃日志，重点是崩溃线程和异常类型。"""
import sys, json, os

sys.stdout.reconfigure(encoding='utf-8')

for n in range(3):
    p = rf"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\_crash{n}.ips"
    if not os.path.exists(p):
        continue
    print("=" * 70)
    print(os.path.basename(p))
    print("=" * 70)

    raw = open(p, encoding="utf-8", errors="replace").read()
    lines = raw.split("\n", 1)
    try:
        header = json.loads(lines[0])
    except Exception:
        header = {}

    print(f"  时间: {header.get('timestamp')}")
    print(f"  系统: {header.get('os_version')}")

    try:
        body = json.loads(lines[1])
    except Exception as ex:
        print("  body 解析失败:", ex)
        continue

    exc = body.get("exception", {})
    print(f"  异常: {exc.get('type')} {exc.get('signal')} {exc.get('subtype')}")

    term = body.get("termination", {})
    print(f"  终止: {term.get('indicator')} {term.get('reasons')} {term.get('namespace')}")

    imgs = body.get("usedImages", [])
    faulting = body.get("faultingThread", 0)
    threads = body.get("threads", [])
    print(f"  线程数: {len(threads)}, 崩溃线程: {faulting}")

    if faulting < len(threads):
        print("\n  崩溃栈:")
        for fr in threads[faulting].get("frames", [])[:22]:
            idx = fr.get("imageIndex", -1)
            img = imgs[idx].get("name", "?") if 0 <= idx < len(imgs) else "?"
            sym = fr.get("symbol", "")
            off = fr.get("imageOffset", 0)
            print(f"    {img:26s} {sym:56s} +{off}")

    # ASI 之类的附加信息
    asi = body.get("asi")
    if asi:
        print(f"\n  附加信息: {asi}")

    # 找最后一次异常回溯
    last = body.get("lastExceptionBacktrace")
    if last:
        print("\n  Last Exception Backtrace:")
        for fr in last[:15]:
            idx = fr.get("imageIndex", -1)
            img = imgs[idx].get("name", "?") if 0 <= idx < len(imgs) else "?"
            sym = fr.get("symbol", "")
            print(f"    {img:26s} {sym}")

    print()
