# -*- coding: utf-8 -*-
"""下载并解析 LeicaLab 崩溃日志。"""
import sys, json, re

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST, USER, PWD = "192.168.1.6", "mobile", "541880"
REMOTE = "/var/mobile/Library/Logs/CrashReporter/LeicaLab-2026-11-24-062710.ips"
LOCAL = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\_crash.ips"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)
sftp = c.open_sftp()
sftp.get(REMOTE, LOCAL)
sftp.close()
c.close()

print(f"已下载: {LOCAL}")
raw = open(LOCAL, encoding="utf-8", errors="replace").read()

# .ips 是两段：第一行 JSON header，后面是 JSON body
lines = raw.split("\n", 1)
header = {}
try:
    header = json.loads(lines[0])
except Exception:
    pass
print("\n=== 头部 ===")
print("  app:", header.get("app_name"), header.get("bundleID"))
print("  version:", header.get("app_version"))
print("  os:", header.get("os_version"))

body = {}
try:
    body = json.loads(lines[1]) if len(lines) > 1 else {}
except Exception as ex:
    print("body 解析失败:", ex)

if body:
    print("\n=== 异常信息 ===")
    print("  类型:", body.get("exception", {}))
    print("  终止原因:", body.get("termination", {}).get("indicator"),
          body.get("termination", {}).get("reasons"))

    print("\n=== 崩溃线程回溯 ===")
    imgs = body.get("usedImages", [])
    faulting = body.get("faultingThread", 0)
    threads = body.get("threads", [])
    if faulting < len(threads):
        th = threads[faulting]
        for fr in th.get("frames", [])[:25]:
            idx = fr.get("imageIndex", -1)
            img = imgs[idx].get("name", "?") if 0 <= idx < len(imgs) else "?"
            sym = fr.get("symbol", "")
            off = fr.get("imageOffset", 0)
            print(f"  {img:24s} {sym:50s} +{off}")

    print("\n=== 加载的镜像（找我们的） ===")
    for i, im in enumerate(imgs):
        n = im.get("name", "")
        if "Leica" in n or "leica" in n:
            print(f"  [{i}] {n}  {im.get('path','')}")

    print("\n=== Binary Images 概要 ===")
    print("  共", len(imgs), "个")

    # 找 exception 相关字符串
    print("\n=== 关键字符串 ===")
    txt = json.dumps(body, ensure_ascii=False)
    for kw in ("NSException", "EXC_BAD_ACCESS", "EXC_CRASH", "SIGABRT",
               "out of memory", "Memory", "CIColorCube", "CGImage"):
        if kw in txt:
            print("  命中:", kw)
