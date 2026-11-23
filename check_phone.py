# -*- coding: utf-8 -*-
"""检查手机上装了哪些跟安装 App 相关的东西（TrollStore / TrollStore Lite / AppSync）。"""
import sys

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST, USER, PWD = "192.168.1.6", "mobile", "541880"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)


def run(cmd, timeout=60):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    o.channel.recv_exit_status()
    return (out + err).strip()


print("=== 用户安装的 App（含 TrollStore 相关）===")
out = run("ls /var/containers/Bundle/Application | head -50")
print(f"  Bundle 容器数: {len(out.splitlines())}")

print("\n=== 找 TrollStore / Lite ===")
for pat in ("trollstore", "TrollStore", "troll"):
    r = run(f"grep -ril '{pat}' /var/containers/Bundle/Application/*/*.app/Info.plist 2>/dev/null | head -5")
    if r:
        print(f"  [{pat}] {r}")

print("\n=== 越狱环境 ===")
print("  /var/jb:", run("ls -d /var/jb 2>/dev/null || echo 不存在"))
print("  越狱目录:", run("ls / 2>/dev/null | grep -iE 'jb|bootstrap|dopamine|palera1n' | head -5"))
print("  dpkg:", run("which dpkg 2>/dev/null || ls /var/jb/usr/bin/dpkg 2>/dev/null || echo 无"))

print("\n=== 已装的越狱包（前 30，找 AppSync/TrollStore）===")
r = run("dpkg -l 2>/dev/null | grep -iE 'appsync|troll|ldid' | head -20")
print(" ", r or "(无 dpkg 或没有相关包)")

r2 = run("ls /var/jb/usr/bin 2>/dev/null | grep -iE 'appinst|install' | head -10")
print("  相关二进制:", r2 or "(无)")

print("\n=== 文件共享 App 里的 ipa ===")
r3 = run("ls -lh /var/mobile/Containers/Data/Application/FB0FB990-F822-4332-9559-A39AFA371EA6/Documents/ 2>&1")
print(" ", r3.replace("\n", "\n  "))

c.close()
