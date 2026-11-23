# -*- coding: utf-8 -*-
"""拉取指定 run 的 job 日志，提取编译错误。"""
import sys, os, json, urllib.request, re
sys.stdout.reconfigure(encoding='utf-8')

TOKEN = os.environ.get("GH_TOKEN", "")
REPO = "lincx666/coll"
RUN_ID = sys.argv[1] if len(sys.argv) > 1 else ""

def api(path):
    req = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}{path}",
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "dsh-agent",
        })
    with urllib.request.urlopen(req) as r:
        return r.read()

def get_json(path):
    return json.loads(api(path).decode('utf-8'))

# 1) 找 job
jobs = get_json(f"/actions/runs/{RUN_ID}/jobs")["jobs"]
job = jobs[0]
print(f"job: {job['name']} -> {job['conclusion']}")

# 2) 拉日志（返回可能是 zip 也可能是纯文本）
raw = api(f"/actions/jobs/{job['id']}/logs")
if raw[:2] == b'PK':
    import zipfile, io
    z = zipfile.ZipFile(io.BytesIO(raw))
    txt = "\n".join(z.read(n).decode('utf-8', 'replace') for n in z.namelist())
else:
    txt = raw.decode('utf-8', 'replace')

# 3) 提取关键行
clean = re.sub(r'\x1b\[[0-9;]*m', '', txt)
lines = clean.split('\n')

print("\n=== 编译错误（.swift:line:col: error）===")
errs = [l for l in lines if re.search(r'\.swift:\d+:\d+: error:', l)]
seen = set()
for l in errs:
    m = re.sub(r'^\S+Z\s+', '', l).strip()
    if m not in seen:
        seen.add(m)
        print("  " + m)

if not errs:
    print("  (无)")

print("\n=== 其他 error: ===")
others = [l for l in lines if 'error:' in l and '.swift:' not in l]
for l in others[:20]:
    m = re.sub(r'^\S+Z\s+', '', l).strip()
    if m and not m.startswith('echo') and '::error::' not in m:
        print("  " + m[:200])
