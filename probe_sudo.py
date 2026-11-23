# -*- coding: utf-8 -*-
"""测试 sudo 权限 + 准备用 uicache 方式安装。"""
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


print("=== 1. sudo 是否可用 ===")
rc, out = run(f"echo '{PWD}' | sudo -S id 2>&1")
print(f"  rc={rc}\n  {out}")

print("\n=== 2. /var/jb/Applications 权限 ===")
print(run("ls -ld /var/jb/Applications")[1])

print("\n=== 3. uicache 存在? ===")
print(run("which uicache && uicache --help 2>&1 | head -15")[1])

print("\n=== 4. ldid 可用? ===")
print(run("which ldid && ldid -h 2>&1 | head -5")[1])

print("\n=== 5. unzip 可用? ===")
print(run("which unzip")[1])

c.close()
