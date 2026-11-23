# -*- coding: utf-8 -*-
"""用 mobile 账号把 ipa 传到越狱机 Downloads 目录，并校验大小。"""
import sys, os, time

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST = "192.168.1.6"
USER = "mobile"
PWD = "541880"
IPA = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\LeicaLab.ipa"
REMOTE = "/var/mobile/Downloads/LeicaLab.ipa"


def human(n):
    n = float(n)
    for u in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f} {u}"
        n /= 1024
    return f"{n:.1f} TB"


size = os.path.getsize(IPA)
print(f"本地: {os.path.basename(IPA)}  {human(size)}", flush=True)

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD,
          timeout=15, banner_timeout=15, auth_timeout=15,
          look_for_keys=False, allow_agent=False)
print("SSH 已连接", flush=True)

# 确保目录存在
_, o, e = c.exec_command("mkdir -p /var/mobile/Downloads && echo OK")
print("准备目录:", o.read().decode().strip(), flush=True)

sftp = c.open_sftp()

# 已存在且大小一致就跳过
try:
    st = sftp.stat(REMOTE)
    if st.st_size == size:
        print("远端已有同尺寸文件，跳过传输", flush=True)
        sftp.close()
        c.close()
        print("DONE_SKIP")
        sys.exit(0)
except IOError:
    pass

print("开始传输 ...", flush=True)
t0 = time.time()
state = {"last": 0.0}


def cb(sent, total):
    now = time.time()
    if now - state["last"] >= 2.0 or sent == total:
        state["last"] = now
        pct = sent / total * 100
        spd = sent / max(now - t0, 0.001)
        eta = (total - sent) / max(spd, 1)
        print(f"  {pct:5.1f}%  {human(sent)}/{human(total)}  "
              f"{human(spd)}/s  剩余 {eta:.0f}s", flush=True)


sftp.put(IPA, REMOTE, callback=cb)
elapsed = time.time() - t0
print(f"传输完成: {elapsed:.1f}s  平均 {human(size/elapsed)}/s", flush=True)

st = sftp.stat(REMOTE)
print(f"远端校验: {human(st.st_size)}  "
      f"{'✓ 一致' if st.st_size == size else '✗ 不一致'}", flush=True)
sftp.close()

# 顺手看看有没有安装器
print("\n检查安装工具:", flush=True)
for cmd in ("which appinst", "ls /var/jb/usr/bin/appinst",
            "ls /var/mobile/Containers/Bundle/Application | head -3"):
    _, o, e = c.exec_command(f"{cmd} 2>/dev/null || echo NOTFOUND")
    out = o.read().decode().strip()
    print(f"  $ {cmd}\n    {out}", flush=True)

c.close()
print("DONE_OK")
