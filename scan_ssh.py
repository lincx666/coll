# -*- coding: utf-8 -*-
"""快速扫描局域网里开着 22 端口的设备（找越狱 iPhone）。"""
import socket, concurrent.futures, sys, ipaddress
sys.stdout.reconfigure(encoding='utf-8')

PORT = 22
TIMEOUT = 0.35
subnet = "192.168.1.0/24"

def probe(ip):
    s = socket.socket()
    s.settimeout(TIMEOUT)
    try:
        r = s.connect_ex((str(ip), PORT))
        if r == 0:
            # 读一下 banner 辨别是不是 iOS
            try:
                s.settimeout(1.0)
                banner = s.recv(64).decode('utf-8', 'replace').strip()
            except Exception:
                banner = ''
            return (str(ip), banner)
    except Exception:
        pass
    finally:
        s.close()
    return None

ips = [ip for ip in ipaddress.ip_network(subnet).hosts()]
print(f"扫描 {subnet} 的 {PORT} 端口（{len(ips)} 个地址，并发）...", flush=True)

hits = []
with concurrent.futures.ThreadPoolExecutor(max_workers=128) as ex:
    for r in ex.map(probe, ips):
        if r:
            hits.append(r)
            print(f"  发现: {r[0]}  banner={r[1]!r}", flush=True)

print(f"\n共 {len(hits)} 个设备开着 22 端口")
if not hits:
    print("  → 手机可能不在这个网段，或者 OpenSSH 没启动")
