# -*- coding: utf-8 -*-
"""研究 trollstorehelper 能不能命令行调用。"""
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


APP = "/var/jb/Applications/TrollStoreLite.app"
HELPER = f"{APP}/trollstorehelper"

print("=== helper 文件信息 ===")
print(run(f"ls -la '{HELPER}' && file '{HELPER}' 2>/dev/null"))

print("\n=== 尝试 --help ===")
print(run(f"cd /tmp && '{HELPER}' --help 2>&1 | head -30"))

print("\n=== 尝试无参数 ===")
print(run(f"cd /tmp && '{HELPER}' 2>&1 | head -30"))

print("\n=== 提取 helper 里的字符串（找用法）===")
print(run(f"strings '{HELPER}' 2>/dev/null | grep -iE 'usage|install|argv|ipa|path' | head -30"))

print("\n=== TrollStoreLite 主程序字符串 ===")
print(run(f"strings '{APP}/TrollStoreLite' 2>/dev/null | grep -iE 'stdlib|tsinstall|appinst|lsapplicationworkspace|installApplication' | head -20"))

c.close()
