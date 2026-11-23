# -*- coding: utf-8 -*-
"""拉取最新的 LeicaLab 崩溃日志并解析关键信息。"""
import sys, json, glob

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


# 找最新的几个崩溃日志
out = run("ls -t /var/mobile/Library/Logs/CrashReporter/LeicaLab-*.ips 2>/dev/null | head -3")
files = [l for l in out.split("\n") if l.strip()]
print("崩溃日志:")
for f in files:
    print("  " + f)

if not files:
    print("没有记录")
    c.close()
    sys.exit(0)

sftp = c.open_sftp()
for i, remote in enumerate(files[:2]):
    local = rf"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\_crash{i}.ips"
    try:
        sftp.get(remote, local)
        print(f"\n下载: {remote}  -> {local}")
    except Exception as ex:
        print(f"下载失败 {remote}: {ex}")
sftp.close()
c.close()
