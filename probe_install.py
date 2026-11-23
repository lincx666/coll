# -*- coding: utf-8 -*-
"""摸清 TrollStore Lite 的安装机制，找可用的命令行安装路径。"""
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


print("=== 1. TrollStore Lite 的 App 位置 ===")
print(run("grep -l 'trollstorelite' /var/containers/Bundle/Application/*/*.app/Info.plist 2>/dev/null"))

print("\n=== 2. TrollStore Lite 包内容（找可执行文件）===")
print(run("dpkg -L com.opa334.trollstorelite 2>/dev/null | head -40"))

print("\n=== 3. /var/jb/usr/bin 里所有可执行（找 installer 类）===")
print(run("ls /var/jb/usr/bin/ 2>/dev/null | tr '\\n' ' '"))

print("\n=== 4. AppSync Unified 是否装了 ===")
print(run("dpkg -l 2>/dev/null | grep -i appsync || echo '未安装 AppSync'"))

print("\n=== 5. installd / 系统安装服务 ===")
print(run("ls -la /var/jb/usr/libexec/ 2>/dev/null | grep -iE 'instal|package' | head"))

print("\n=== 6. TrollStore Lite 的偏好设置（看它用什么方式装）===")
print(run("ls -la /var/mobile/Library/Preferences/ | grep -i troll"))

c.close()
