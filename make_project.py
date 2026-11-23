# -*- coding: utf-8 -*-
"""鐢熸垚 Xcode 宸ョ▼鏂囦欢锛坧roject.pbxproj锛夈€?
鎵嬪啓 pbxproj 寰堝鏄撻敊锛岃繖閲岀敤涓€涓瀬绠€鐢熸垚鍣細鍙敮鎸併€屽崟 target銆佹枃浠跺す寮曠敤骞惰繘璧勬簮銆嶏紝
澶熸湰宸ョ▼鐢ㄣ€傜敓鎴愬悗鐢?`open LeicaLab.xcodeproj` 鍗冲彲銆?"""
import sys, os, hashlib, json

sys.stdout.reconfigure(encoding='utf-8')

ROOT = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp"
APP = os.path.join(ROOT, "LeicaLab")
PROJ = os.path.join(ROOT, "LeicaLab.xcodeproj")

# ---------- 鏀堕泦婧愭枃浠?----------

def rel(p):
    return os.path.relpath(p, ROOT).replace('\\', '/')


swift_files = []
for dp, _, fs in os.walk(APP):
    if 'Resources' in dp.split(os.sep):
        continue
    for f in fs:
        if f.endswith('.swift'):
            swift_files.append(rel(os.path.join(dp, f)))
swift_files.sort()

resources = []
for sub in ("LUTs", "HALD", "Icons", "Lottie", "Sounds", "Frames", "Watermarks"):
    d = os.path.join(APP, "Resources", sub)
    if os.path.isdir(d) and os.listdir(d):
        resources.append(f"LeicaLab/Resources/{sub}")
if os.path.exists(os.path.join(APP, "Resources", "catalog.json")):
    resources.append("LeicaLab/Resources/catalog.json")

# ---------- 绋冲畾 ID ----------

def oid(seed):
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()

FILE_REF = {p: oid("fileref:" + p) for p in swift_files}
BUILD_FILE = {p: oid("buildfile:" + p) for p in swift_files}
GROUP_ID = {os.path.dirname(p) or ".": oid("group:" + (os.path.dirname(p) or ".")) for p in swift_files}

RES_REF = {p: oid("resref:" + p) for p in resources}
RES_BUILD = {p: oid("resbuild:" + p) for p in resources}

MAIN_GROUP = oid("maingroup")
APP_GROUP = oid("appgroup")
PRODUCTS_GROUP = oid("productsgroup")
TARGET = oid("target")
PROJECT = oid("project")
SOURCES_PHASE = oid("sources")
RESOURCES_PHASE = oid("resources")
FRAMEWORKS_PHASE = oid("frameworks")
CONFIG_LIST_PROJ = oid("configlistproj")
CONFIG_LIST_TARGET = oid("configlisttarget")
CONFIG_DEBUG_PROJ = oid("configdebugproj")
CONFIG_RELEASE_PROJ = oid("configreleaseproj")
CONFIG_DEBUG_TARGET = oid("configdebugtarget")
CONFIG_RELEASE_TARGET = oid("configreleasetarget")
PRODUCT_REF = oid("productref")

# ---------- pbxproj 鐗囨 ----------

def file_ref_lines():
    out = []
    for p in swift_files:
        name = os.path.basename(p)
        out.append(f'\t\t{FILE_REF[p]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};')
    for p in resources:
        name = os.path.basename(p)
        kind = "folder" if name in ("LUTs", "HALD", "Icons", "Lottie", "Sounds", "Frames", "Watermarks") else "text.json"
        if kind == "folder":
            out.append(f'\t\t{RES_REF[p]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = {name}; sourceTree = "<group>"; }};')
        else:
            out.append(f'\t\t{RES_REF[p]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = {name}; sourceTree = "<group>"; }};')
    out.append(f'\t\t{PRODUCT_REF} /* LeicaLab.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = LeicaLab.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    return "\n".join(out)

def build_file_lines():
    out = []
    for p in swift_files:
        out.append(f'\t\t{BUILD_FILE[p]} /* {os.path.basename(p)} in Sources */ = {{isa = PBXBuildFile; fileRef = {FILE_REF[p]} /* {os.path.basename(p)} */; }};')
    for p in resources:
        name = os.path.basename(p)
        out.append(f'\t\t{RES_BUILD[p]} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {RES_REF[p]} /* {name} */; }};')
    return "\n".join(out)

def app_group_children():
    """LeicaLab 缁勪笅鐨勫瓙缁勪笌鏂囦欢"""
    lines = []
    # 瀛愮洰褰曟寜璺緞娣卞害鎺掑簭
    dirs = sorted({os.path.dirname(p) for p in swift_files})
    top_dirs = sorted({d.split('/')[1] for d in dirs if len(d.split('/')) > 1})

    for d in top_dirs:
        gid = oid("subgroup:" + f"LeicaLab/{d}")
        lines.append(f'\t\t\t\t{gid} /* {d} */,')

    for p in swift_files:
        if os.path.dirname(p) == "LeicaLab":
            lines.append(f'\t\t\t\t{FILE_REF[p]} /* {os.path.basename(p)} */,')

    res_group = oid("resgroup")
    lines.append(f'\t\t\t\t{res_group} /* Resources */,')
    return "\n".join(lines)

def subgroup_lines():
    parts = []
    dirs = sorted({os.path.dirname(p) for p in swift_files if p.startswith('LeicaLab/')})
    by_top = {}
    for d in dirs:
        seg = d.split('/')
        if len(seg) < 2:
            continue
        top = seg[1]
        by_top.setdefault(top, []).append(d)

    for top, ds in sorted(by_top.items()):
        gid = oid("subgroup:" + f"LeicaLab/{top}")
        members = [p for p in swift_files if os.path.dirname(p) in ds]
        children = "\n".join(f'\t\t\t\t{FILE_REF[p]} /* {os.path.basename(p)} */,' for p in members)
        parts.append(
            f'\t\t{gid} /* {top} */ = {{\n'
            f'\t\t\tisa = PBXGroup;\n'
            f'\t\t\tchildren = (\n{children}\n\t\t\t);\n'
            f'\t\t\tpath = {top};\n'
            f'\t\t\tsourceTree = "<group>";\n'
            f'\t\t}};'
        )
    return "\n".join(parts)

def resources_group_lines():
    res_group = oid("resgroup")
    children = "\n".join(f'\t\t\t\t{RES_REF[p]} /* {os.path.basename(p)} */,' for p in resources)
    return (
        f'\t\t{res_group} /* Resources */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n{children}\n\t\t\t);\n'
        f'\t\t\tpath = Resources;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};'
    )

def sources_build_lines():
    return "\n".join(f'\t\t\t\t{BUILD_FILE[p]} /* {os.path.basename(p)} in Sources */,' for p in swift_files)

def resources_build_lines():
    return "\n".join(f'\t\t\t\t{RES_BUILD[p]} /* {os.path.basename(p)} in Resources */,' for p in resources)

pbxproj = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_file_lines()}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_ref_lines()}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{FRAMEWORKS_PHASE} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{MAIN_GROUP} = {{
			isa = PBXGroup;
			children = (
				{APP_GROUP} /* LeicaLab */,
				{PRODUCTS_GROUP} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{APP_GROUP} /* LeicaLab */ = {{
			isa = PBXGroup;
			children = (
{app_group_children()}
			);
			path = LeicaLab;
			sourceTree = "<group>";
		}};
		{PRODUCTS_GROUP} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{PRODUCT_REF} /* LeicaLab.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
{subgroup_lines()}
{resources_group_lines()}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{TARGET} /* LeicaLab */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "LeicaLab" */;
			buildPhases = (
				{SOURCES_PHASE} /* Sources */,
				{FRAMEWORKS_PHASE} /* Frameworks */,
				{RESOURCES_PHASE} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = LeicaLab;
			productName = LeicaLab;
			productReference = {PRODUCT_REF} /* LeicaLab.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{PROJECT} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{TARGET} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {CONFIG_LIST_PROJ} /* Build configuration list for PBXProject "LeicaLab" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = (
				"zh-Hans",
				en,
				Base,
			);
			mainGroup = {MAIN_GROUP};
			productRefGroup = {PRODUCTS_GROUP} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{TARGET} /* LeicaLab */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{RESOURCES_PHASE} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{resources_build_lines()}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{SOURCES_PHASE} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_build_lines()}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{CONFIG_DEBUG_PROJ} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{CONFIG_RELEASE_PROJ} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{CONFIG_DEBUG_TARGET} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = "";
				CODE_SIGN_STYLE = Manual;
				CODE_SIGN_IDENTITY = "";
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGNING_ALLOWED = NO;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Leica Lab";
				INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "淇濆瓨澶勭悊鍚庣殑鐓х墖鍒扮浉鍐?;
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "璇诲彇鐓х墖鐢ㄤ簬娣诲姞婊ら暅涓庢按鍗?;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.local.leicalab;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Debug;
		}};
		{CONFIG_RELEASE_TARGET} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = "";
				CODE_SIGN_STYLE = Manual;
				CODE_SIGN_IDENTITY = "";
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGNING_ALLOWED = NO;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Leica Lab";
				INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "淇濆瓨澶勭悊鍚庣殑鐓х墖鍒扮浉鍐?;
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "璇诲彇鐓х墖鐢ㄤ簬娣诲姞婊ら暅涓庢按鍗?;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.local.leicalab;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{CONFIG_LIST_PROJ} /* Build configuration list for PBXProject "LeicaLab" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{CONFIG_DEBUG_PROJ} /* Debug */,
				{CONFIG_RELEASE_PROJ} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "LeicaLab" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{CONFIG_DEBUG_TARGET} /* Debug */,
				{CONFIG_RELEASE_TARGET} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {PROJECT} /* Project object */;
}}
'''

os.makedirs(PROJ, exist_ok=True)
with open(os.path.join(PROJ, "project.pbxproj"), "w", encoding="utf-8") as f:
    f.write(pbxproj)

print(json.dumps({
    "swift_files": len(swift_files),
    "resources": len(resources),
    "pbxproj_bytes": len(pbxproj),
    "path": os.path.join(PROJ, "project.pbxproj"),
}, ensure_ascii=False, indent=1))

