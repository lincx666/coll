# -*- coding: utf-8 -*-
"""最终验证：确认 App 已注册、可执行文件架构正确、资源完整。"""
import sys

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST, USER, PWD = "192.168.1.6", "mobile", "541880"
APP = "/var/jb/Applications/LeicaLab.app"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)


def root_sh(script, timeout=120):
    escaped = script.replace("'", "'\\''")
    cmd = f"echo '{PWD}' | sudo -S sh -c '{escaped}' 2>&1"
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    rc = o.channel.recv_exit_status()
    return rc, (out + err).strip().replace("[sudo] password for mobile: ", "")


print("=== 1. uicache 注册状态 ===")
_, out = root_sh("uicache -l 2>/dev/null | grep -i leica")
print("  " + (out or "未注册"))

print("\n=== 2. 应用信息 ===")
_, out = root_sh("uicache -i com.local.leicalab 2>&1 | head -20")
print("  " + out.replace("\n", "\n  "))

print("\n=== 3. 可执行文件 ===")
_, out = root_sh(f"ls -lh '{APP}/LeicaLab' && file '{APP}/LeicaLab' 2>/dev/null")
print("  " + out.replace("\n", "\n  "))

print("\n=== 4. 资源完整性 ===")
_, out = root_sh(
    f"for d in LUTs HALD Icons Lottie Sounds Frames Watermarks; do "
    f"n=$(find '{APP}'/$d -type f 2>/dev/null | wc -l); echo \"  $d: $n\"; done"
)
print(out.replace("\n", "\n  "))

print("\n=== 5. Info.plist 关键字段 ===")
_, out = root_sh(f"plutil -p '{APP}/Info.plist' 2>/dev/null | grep -E 'Identifier|MinimumOS|Executable|DisplayName'")
print("  " + out.replace("\n", "\n  "))

print("\n=== 6. 签名状态 ===")
_, out = root_sh(f"ldid -e '{APP}/LeicaLab' 2>&1 | head -5")
print("  " + (out or "(无输出=未签名或签名空)").replace("\n", "\n  "))

c.close()
