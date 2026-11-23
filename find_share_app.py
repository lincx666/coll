# -*- coding: utf-8 -*-
"""扫描手机上哪些 App 开启了「文件」App 共享（UIFileSharingEnabled），
并把 ipa 复制到它的 Documents 目录，让「我的 iPhone」里能看到。
"""
import sys, plistlib, posixpath

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

HOST, USER, PWD = "192.168.1.6", "mobile", "541880"
IPA_PATH = "/var/mobile/Downloads/LeicaLab.ipa"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, port=22, username=USER, password=PWD, timeout=15,
          allow_agent=False, look_for_keys=False)
sftp = c.open_sftp()

print("=== 查找支持文件共享的 App ===", flush=True)
bundle_root = "/var/containers/Bundle/Application"
candidates = []

for app_uuid in sftp.listdir(bundle_root):
    base = f"{bundle_root}/{app_uuid}"
    try:
        entries = sftp.listdir(base)
    except IOError:
        continue
    for e in entries:
        if not e.endswith(".app"):
            continue
        info = posixpath.join(base, e, "Info.plist")
        try:
            with sftp.open(info, "rb") as f:
                pl = plistlib.load(f)
        except Exception:
            continue
        sharing = pl.get("UIFileSharingEnabled", False)
        inplace = pl.get("LSSupportsOpeningDocumentsInPlace", False)
        if not (sharing or inplace):
            continue
        bid = pl.get("CFBundleIdentifier", "?")
        name = pl.get("CFBundleDisplayName") or pl.get("CFBundleName") or e
        candidates.append({
            "name": name, "bid": bid, "uuid": app_uuid,
            "app": e, "sharing": sharing, "inplace": inplace,
        })
        print(f"  {name:28s} {bid:44s} sharing={sharing} inplace={inplace}", flush=True)

if not candidates:
    print("  (没有任何 App 开启文件共享)")

# 找 Data 容器
print("\n=== 定位 Data 容器 ===", flush=True)
data_root = "/var/mobile/Containers/Data/Application"
for cand in candidates:
    meta = f"{data_root}/{cand['uuid']}/.com.apple.mobile_container_manager.metadata.plist"
    try:
        with sftp.open(meta, "rb") as f:
            md = plistlib.load(f)
        cand["data_uuid"] = md.get("MCMMetadataIdentifier", "")
        print(f"  {cand['name']}: data={cand['data_uuid'][:40]}", flush=True)
    except Exception as ex:
        cand["data_uuid"] = None
        print(f"  {cand['name']}: 读不到 metadata ({type(ex).__name__})", flush=True)

sftp.close()
c.close()
