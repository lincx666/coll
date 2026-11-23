# -*- coding: utf-8 -*-
"""尝试用 trollstorehelper（root）直接安装 ipa。"""
import sys

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST, USER, PWD = "192.168.1.6", "mobile", "541880"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)


def run(cmd, timeout=180):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    rc = o.channel.recv_exit_status()
    return rc, (out + err).strip()


HELPER = "/var/jb/Applications/TrollStoreLite.app/trollstorehelper"
IPA = "/var/mobile/Downloads/LeicaLab.ipa"

print("=== trollstorehelper 无参数（root）===")
rc, out = run(f"echo '{PWD}' | sudo -S '{HELPER}' 2>&1 | head -40")
print(f"  rc={rc}")
print("  " + out.replace("\n", "\n  "))

print("\n=== trollstorehelper + ipa 路径 ===")
rc, out = run(f"echo '{PWD}' | sudo -S '{HELPER}' '{IPA}' 2>&1 | head -40")
print(f"  rc={rc}")
print("  " + out.replace("\n", "\n  "))

c.close()
