# -*- coding: utf-8 -*-
"""下载最新构建产物 -> 推送到手机 -> ldid 签名 -> 安装 -> 注册。

token 从环境变量 GH_TOKEN 读取，不写进代码。
"""
import sys, os, time, subprocess, json, urllib.request

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

TOKEN = os.environ.get("GH_TOKEN", "")
if not TOKEN:
    print("缺少 GH_TOKEN 环境变量")
    sys.exit(1)

REPO = "lincx666/coll"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else ""

HOST = os.environ.get("PHONE_HOST", "192.168.1.6")
USER = os.environ.get("PHONE_USER", "mobile")
PWD = os.environ.get("PHONE_PWD", "")
if not PWD:
    print("缺少 PHONE_PWD 环境变量")
    sys.exit(1)

APP_DIR = "/var/jb/Applications/LeicaLab.app"
REMOTE_IPA = "/var/mobile/Downloads/LeicaLab.ipa"
LOCAL = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\LeicaLab.ipa"


def api(path):
    req = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}{path}",
        headers={"Authorization": f"Bearer {TOKEN}",
                 "Accept": "application/vnd.github+json",
                 "User-Agent": "dsh-agent"})
    with urllib.request.urlopen(req) as r:
        return r.read()


# 没给 run id 就用最新一次成功的
if not RUN_ID:
    runs = json.loads(api("/actions/runs?per_page=5"))["workflow_runs"]
    ok = [r for r in runs if r["conclusion"] == "success"]
    if not ok:
        print("没有成功的构建")
        sys.exit(1)
    RUN_ID = str(ok[0]["id"])
    print(f"使用最新成功构建: #{ok[0]['run_number']} ({RUN_ID})")

# ---------- 1. 下载 ----------
arts = json.loads(api(f"/actions/runs/{RUN_ID}/artifacts"))["artifacts"]
art = next((a for a in arts if a["name"] == "LeicaLab-ipa"), None)
if not art:
    print("没找到 artifact")
    sys.exit(1)
print(f"artifact: {art['name']}  {art['size_in_bytes']/1024/1024:.1f} MB", flush=True)

zip_path = LOCAL + ".zip"
subprocess.run([
    "curl.exe", "-sL",
    "-H", f"Authorization: Bearer {TOKEN}",
    "-H", "Accept: application/vnd.github+json",
    "-o", zip_path,
    f"https://api.github.com/repos/{REPO}/actions/artifacts/{art['id']}/zip",
], check=True)

import zipfile, shutil
with zipfile.ZipFile(zip_path) as z:
    names = [n for n in z.namelist() if n.endswith(".ipa")]
    if not names:
        print("zip 里没有 ipa")
        sys.exit(1)
    with z.open(names[0]) as src, open(LOCAL, "wb") as dst:
        shutil.copyfileobj(src, dst)
os.remove(zip_path)
print(f"本地 ipa: {os.path.getsize(LOCAL)/1024/1024:.1f} MB", flush=True)

# ---------- 2. 推送 ----------
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)


def root_sh(script, timeout=600):
    esc = script.replace("'", "'\\''")
    _, o, e = c.exec_command(f"echo '{PWD}' | sudo -S sh -c '{esc}' 2>&1", timeout=timeout)
    out = (o.read() + e.read()).decode(errors="replace")
    rc = o.channel.recv_exit_status()
    return rc, out.replace("[sudo] password for mobile: ", "").strip()


def step(title, script, timeout=600):
    print(f"\n=== {title} ===", flush=True)
    rc, out = root_sh(script, timeout)
    print(f"  rc={rc}", flush=True)
    if out.strip():
        print("  " + out.replace("\n", "\n  ")[:1500], flush=True)
    return rc, out


print("\n传输中 ...", flush=True)
sftp = c.open_sftp()
t0 = time.time()
last = [0.0]


def cb(sent, total):
    now = time.time()
    if now - last[0] > 2 or sent == total:
        last[0] = now
        print(f"  {sent/total*100:5.1f}%  {sent/1024/1024:.1f}/{total/1024/1024:.1f} MB", flush=True)


sftp.put(LOCAL, REMOTE_IPA, callback=cb)
sftp.close()
print(f"  完成 {time.time()-t0:.1f}s", flush=True)

# ---------- 3. 安装 ----------
step("清理旧版本", f"rm -rf {APP_DIR} /tmp/lc_x && mkdir -p /tmp/lc_x")
step("解压", f"unzip -q -o '{REMOTE_IPA}' -d /tmp/lc_x && ls /tmp/lc_x/Payload")
step("ldid 签名", "ldid -S /tmp/lc_x/Payload/LeicaLab.app/LeicaLab && echo SIGNED")
step("安装", f"cp -R /tmp/lc_x/Payload/LeicaLab.app /var/jb/Applications/ && "
             f"chown -R root:wheel {APP_DIR} && chmod -R 755 {APP_DIR} && echo COPIED")
step("注册", f"uicache -p {APP_DIR}; echo RC=$?")
step("确认", "uicache -l 2>/dev/null | grep -i leica || echo NOTFOUND")
step("respring", "sbreload 2>&1 || killall -9 SpringBoard 2>&1 || true", timeout=60)
step("清理临时", "rm -rf /tmp/lc_x")

c.close()
print("\n完成", flush=True)
