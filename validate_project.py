# -*- coding: utf-8 -*-
"""校验生成的 project.pbxproj 结构是否自洽。"""
import sys, re, os
sys.stdout.reconfigure(encoding='utf-8')

p = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\LeicaLab.xcodeproj\project.pbxproj"
t = open(p, encoding='utf-8').read()

print("字节数:", len(t.encode('utf-8')))
print("花括号: { =", t.count('{'), " } =", t.count('}'))
print("圆括号: ( =", t.count('('), " ) =", t.count(')'))

print("\n--- 节检查 ---")
for s in ('PBXBuildFile', 'PBXFileReference', 'PBXFrameworksBuildPhase', 'PBXGroup',
          'PBXNativeTarget', 'PBXProject', 'PBXResourcesBuildPhase', 'PBXSourcesBuildPhase',
          'XCBuildConfiguration', 'XCConfigurationList'):
    ok = f"Begin {s} section" in t and f"End {s} section" in t
    print(f"  {s:26s} {'OK' if ok else 'MISSING'}")

print("\n--- 引用完整性 ---")
defined = set(re.findall(r'^\t\t([0-9A-F]{24}) ', t, re.M))
referenced = set(re.findall(r'\b([0-9A-F]{24})\b', t))
print("  定义:", len(defined), " 引用:", len(referenced))
missing = referenced - defined
print("  引用但未定义:", len(missing))
for m in sorted(missing)[:5]:
    print("    ", m)

print("\n--- 文件引用 ---")
refs = re.findall(r'([0-9A-F]{24}) /\* ([^*]+) \*/ = \{isa = PBXFileReference', t)
print("  PBXFileReference 数:", len(refs))

builds = re.findall(r'([0-9A-F]{24}) /\* ([^*]+) in (Sources|Resources) \*/ = \{isa = PBXBuildFile; fileRef = ([0-9A-F]{24})', t)
print("  PBXBuildFile 数:", len(builds))
for bid, name, phase, ref in builds[:3]:
    print(f"    {phase:9s} {name}")

print("\n--- rootObject ---")
m = re.search(r'rootObject = ([0-9A-F]{24})', t)
print("  ", m.group(1) if m else "MISSING", "(defined)" if m and m.group(1) in defined else "(NOT DEFINED)")
