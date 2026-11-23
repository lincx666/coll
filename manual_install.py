# -*- coding: utf-8 -*-
"""手动安装（修正版）：用 sudo sh -c 包住整条命令。"""
import sys

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST, USER, PWD = "192.168.1.6", "mobile", "541880"
IPA = "/var/mobile/Downloads/LeicaLab.ipa"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)


def root_sh(script, timeout=600):
    """用 sudo sh -c 执行整段脚本。"""
    escaped = script.replace("'", "'\\''")
    cmd = f"echo '{PWD}' | sudo -S sh -c '{escaped}' 2>&1"
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    rc = o.channel.recv_exit_status()
    return rc, (out + err).strip()


def step(title, script, timeout=600):
    print(f"\n=== {title} ===", flush=True)
    rc, out = root_sh(script, timeout)
    print(f"  rc={rc}", flush=True)
    # 去掉 sudo 密码提示
    out = out.replace(f"[sudo] password for mobile: ", "")
    if out.strip():
        print("  " + out.replace("\n", "\n  ")[:2500], flush=True)
    return rc, out


# 1) 清理
step("清理", "rm -rf /tmp/leicalab_x && mkdir -p /tmp/leicalab_x")

# 2) 解压
step("解压 ipa", f"unzip -q -o '{IPA}' -d /tmp/leicalab_x && ls /tmp/leicalab_x")

# 3) 找 .app（用 shell 通配，在 sh 里能展开）
rc, out = step("定位 app", "ls -d /tmp/leicalab_x/Payload/*.app")

# 解析路径
app_path = None
for line in out.split("\n"):
    line = line.strip()
    if line.endswith(".app") and line.startswith("/tmp/"):
        app_path = line
        break

print(f"\n>>> app 路径: {app_path!r}", flush=True)

if not app_path:
    print("解压后没找到 .app，退出")
    c.close()
    sys.exit(1)

# 4) ldid 伪签名
step("ldid 签名", f"ldid -S '{app_path}/LeicaLab' && echo SIGNED")

# 5) 拷到 /var/jb/Applications
step("拷贝安装",
     f"rm -rf /var/jb/Applications/LeicaLab.app && "
     f"cp -R '{app_path}' /var/jb/Applications/ && "
     f"chown -R root:wheel /var/jb/Applications/LeicaLab.app && echo COPIED")

# 6) 权限
step("修权限",
     "chmod -R 755 /var/jb/Applications/LeicaLab.app && "
     "chmod 644 /var/jb/Applications/LeicaLab.app/Info.plist && echo PERMED")

# 7) uicache 注册
step("uicache 注册",
     "uicache -p /var/jb/Applications/LeicaLab.app; echo RC=$?")

# 8) 确认
step("确认", "uicache -l 2>/dev/null | grep -i leica || echo NOTFOUND")

# 9) respring
step("respring", "sbreload 2>&1 || killall -9 SpringBoard 2>&1 || true", timeout=60)

c.close()
print("\n完成")
