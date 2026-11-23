# -*- coding: utf-8 -*-
"""找到 Tools(文件共享 App) 的 Documents 目录，把 ipa 放进去，
这样「文件」App 的「我的 iPhone」下就能看到。"""
import sys, plistlib, posixpath

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
    rc = o.channel.recv_exit_status()
    return rc, out.strip(), err.strip()


print("=== 找 Tools 的 Data 容器 ===")
# 用 grep 直接扫 datacontainer metadata
rc, out, err = run(
    "grep -rl 'com.ownbook.notes' "
    "/var/mobile/Containers/Data/Application/*/.com.apple.mobile_container_manager.metadata.plist "
    "2>/dev/null | head -5"
)
print(f"rc={rc}")
print(out or "(无结果)")

targets = [l.strip() for l in out.split("\n") if l.strip()]
data_dirs = []
for t in targets:
    data_dirs.append(posixpath.dirname(t))
    print(f"  data dir: {posixpath.dirname(t)}")

if not data_dirs:
    print("\n换一种方式：遍历找 .com.apple.mobile_container_manager.metadata.plist")
    rc, out, err = run(
        "find /var/mobile/Containers/Data/Application -maxdepth 2 "
        "-name '.com.apple.mobile_container_manager.metadata.plist' 2>/dev/null | head -60"
    )
    metas = [l.strip() for l in out.split("\n") if l.strip()]
    print(f"  找到 {len(metas)} 个 metadata")
    sftp = c.open_sftp()
    for m in metas:
        try:
            with sftp.open(m, "rb") as f:
                md = plistlib.load(f)
            bid = md.get("MCMMetadataIdentifier", "")
            if "ownbook" in bid:
                d = posixpath.dirname(m)
                data_dirs.append(d)
                print(f"  命中: {d}  ({bid})")
        except Exception:
            pass
    sftp.close()

if not data_dirs:
    print("\n没找到 Tools 的容器。改用 <App 组> 方案。")
    c.close()
    sys.exit(1)

docs = posixpath.join(data_dirs[0], "Documents")
print(f"\n=== 目标 Documents: {docs} ===")

rc, out, err = run(f"ls -la '{docs}' 2>&1 | head -20")
print(out or err)

# 复制 ipa
rc, out, err = run(
    f"mkdir -p '{docs}' && "
    f"cp /var/mobile/Downloads/LeicaLab.ipa '{docs}/' && "
    f"ls -lh '{docs}/LeicaLab.ipa'",
    timeout=120,
)
print(f"\n复制结果 rc={rc}")
print(out or err)

c.close()
