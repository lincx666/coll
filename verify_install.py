# -*- coding: utf-8 -*-
"""确认 LeicaLab 是否真的装上了。"""
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
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    rc = o.channel.recv_exit_status()
    return rc, (out + err).strip()


print("=== 1. uicache 里找 leicalab ===")
rc, out = run(f"echo '{PWD}' | sudo -S uicache -l 2>/dev/null | grep -i leica")
print(f"  rc={rc}  {out or '(没找到)'}")

print("\n=== 2. Bundle 目录里找 ===")
rc, out = run("ls -d /var/containers/Bundle/Application/*/LeicaLab.app 2>/dev/null")
print(f"  {out or '(没找到)'}")

rc, out = run("grep -l 'com.local.leicalab' /var/containers/Bundle/Application/*/*.app/Info.plist 2>/dev/null")
print(f"  按 bundle id 搜: {out or '(没找到)'}")

print("\n=== 3. /var/jb/Applications ===")
rc, out = run("ls -la /var/jb/Applications/")
print("  " + out.replace("\n", "\n  "))

print("\n=== 4. 所有新出现的 App（按时间）===")
rc, out = run("ls -lt /var/containers/Bundle/Application/ | head -5")
print("  " + out.replace("\n", "\n  "))

c.close()
