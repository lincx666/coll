# -*- coding: utf-8 -*-
"""通过 SSH 把 ipa 推到越狱 iPhone，并可选地直接 appinst 安装。

用法:
    python push_ipa.py <手机IP> <密码> [--install]

越狱机默认 root 密码是 alpine。
"""
import sys, os, time, hashlib

sys.stdout.reconfigure(encoding='utf-8')
import paramiko

IPA = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\LeicaLab.ipa"
REMOTE_DIRS = ["/var/mobile/Downloads", "/var/mobile/Documents", "/tmp"]


def human(n):
    for u in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f} {u}"
        n /= 1024
    return f"{n:.1f} TB"


def main():
    if len(sys.argv) < 3:
        print("用法: python push_ipa.py <IP> <密码> [--install]")
        return 1

    host, password = sys.argv[1], sys.argv[2]
    do_install = "--install" in sys.argv

    if not os.path.exists(IPA):
        print(f"找不到 {IPA}")
        return 1

    size = os.path.getsize(IPA)
    print(f"本地文件: {os.path.basename(IPA)}  {human(size)}")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    print(f"连接 root@{host} ...")
    client.connect(host, port=22, username="root", password=password,
                   timeout=15, banner_timeout=15, auth_timeout=15,
                   look_for_keys=False, allow_agent=False)
    print("  连接成功")

    # 找一个可写目录
    remote_dir = None
    for d in REMOTE_DIRS:
        stdin, stdout, stderr = client.exec_command(f"mkdir -p {d} && test -w {d} && echo OK")
        if "OK" in stdout.read().decode():
            remote_dir = d
            break
    if not remote_dir:
        print("找不到可写目录")
        client.close()
        return 1

    remote_path = f"{remote_dir}/LeicaLab.ipa"
    print(f"目标: {remote_path}")

    sftp = client.open_sftp()
    stat = None
    try:
        stat = sftp.stat(remote_path)
    except IOError:
        pass

    if stat and stat.st_size == size:
        print("  远端已存在同尺寸文件，跳过传输")
    else:
        print("  开始传输 ...")
        t0 = time.time()
        last = [0.0]

        def cb(sent, total):
            now = time.time()
            if now - last[0] > 0.5 or sent == total:
                last[0] = now
                pct = sent / total * 100
                speed = sent / max(now - t0, 0.001)
                print(f"\r    {pct:5.1f}%  {human(sent)}/{human(total)}  {human(speed)}/s",
                      end="", flush=True)

        sftp.put(IPA, remote_path, callback=cb)
        print()
        elapsed = time.time() - t0
        print(f"  传输完成，用时 {elapsed:.1f}s  平均 {human(size/elapsed)}/s")

    sftp.close()

    # 校验大小
    stdin, stdout, stderr = client.exec_command(f"stat -c %s {remote_path}")
    remote_size = int(stdout.read().decode().strip() or 0)
    print(f"  远端大小校验: {human(remote_size)}  {'✓' if remote_size == size else '✗ 不一致'}")

    # 找安装工具
    print("\n检查安装工具 ...")
    tools = {}
    for name in ("appinst", "tsinstall", "trollstore-cli"):
        cmd = f"which {name} 2>/dev/null || ls /var/jb/usr/bin/{name} 2>/dev/null || echo NOTFOUND"
        stdin, stdout, stderr = client.exec_command(cmd)
        out = stdout.read().decode().strip()
        path = None if "NOTFOUND" in out else out.split("\n")[0]
        tools[name] = path
        print(f"  {name:16s} {'→ ' + path if path else '未安装'}")

    if do_install:
        if tools.get("appinst"):
            cmd = f"{tools['appinst']} {remote_path}"
        elif tools.get("tsinstall"):
            cmd = f"{tools['tsinstall']} {remote_path}"
        else:
            print("\n没有可用的命令行安装器。")
            print("请在手机上用 TrollStore Lite 打开这个文件：")
            print(f"  {remote_path}")
            client.close()
            return 0

        print(f"\n执行安装: {cmd}")
        stdin, stdout, stderr = client.exec_command(cmd, timeout=300)
        out = stdout.read().decode(errors="replace")
        err = stderr.read().decode(errors="replace")
        rc = stdout.channel.recv_exit_status()
        print(f"  退出码: {rc}")
        if out.strip():
            print("  输出:", out.strip()[:800])
        if err.strip():
            print("  错误:", err.strip()[:800])
    else:
        print(f"\n文件已就位，在手机上用 TrollStore Lite 打开：")
        print(f"  {remote_path}")

    client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
