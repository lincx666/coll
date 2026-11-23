# -*- coding: utf-8 -*-
"""抓 LeicaLab 的崩溃日志。"""
import sys

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST, USER, PWD = "192.168.1.6", "mobile", "541880"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)


def run(cmd, timeout=90):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return (o.read() + e.read()).decode(errors="replace").strip()


print("=== 找崩溃报告 ===")
paths = [
    "/var/mobile/Library/Logs/CrashReporter",
    "/private/var/mobile/Library/Logs/CrashReporter",
    "/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs",
]
for p in paths:
    r = run(f"ls -lt {p} 2>/dev/null | grep -iE 'leica|LeicaLab' | head -5")
    if r:
        print(f"  [{p}]")
        print("  " + r.replace("\n", "\n  "))

print("\n=== 全盘搜 LeicaLab 崩溃文件 ===")
r = run("find /var/mobile/Library -iname '*leicalab*' -newermt '-2 hours' 2>/dev/null | head -10")
print("  " + (r or "(无)"))

print("\n=== 最近的 崩溃/ips 文件 ===")
r = run("find /var/mobile/Library/Logs -name '*.ips' -newermt '-2 hours' 2>/dev/null | head -10")
print("  " + (r or "(无 .ips)"))

r = run("find /var/mobile/Library/Logs -name '*.crash' -newermt '-2 hours' 2>/dev/null | head -10")
print("  " + (r or "(无 .crash)"))

c.close()
