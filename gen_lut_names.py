# -*- coding: utf-8 -*-
"""生成 LUT 中文名映射。

优先用 APK 里 assets/luts/config.json 自带的官方中文名，
其余按「品牌/型号/场景」词表翻译，确保 363 个全部有中文。
"""
import sys, os, json, zipfile

sys.stdout.reconfigure(encoding='utf-8')

APK = os.path.expanduser(r"~\Desktop\123v2.apk")
RES = r"C:\Users\lincx\Documents\deepseek-harness\default-workspace\iOSApp\LeicaLab\Resources"

# ---------- 1. 读 APK 官方中文名 ----------
z = zipfile.ZipFile(APK)
cfg = json.loads(z.read('assets/luts/config.json').decode('utf-8'))
z.close()

official = {}
for it in cfg.get('luts', []):
    zh = (it.get('name') or {}).get('zh', '').strip()
    p = (it.get('path') or '').strip()
    if not p or not zh:
        continue
    stem = os.path.splitext(p.replace('/', '_'))[0]
    official[stem] = zh

# ---------- 2. 相机/胶片品牌与型号 ----------
CAMERA_NAMES = {
    "Hasselblad": "哈苏自然",
    "Hasselblad_portrait": "哈苏人像",
    "Leica_M9_STD": "徕卡M9",
    "Pentax_Fuyuno": "宾得冬野",
    "Pentax_Harubeni": "宾得春红",
    "Pentax_Katen": "宾得夏天",
    "Pentax_Kyushu": "宾得九秋",
    "Ricoh_GR2_POSI": "理光正片GR2",
    "astia": "富士Astia",
    "cc": "富士CC",
    "nc": "富士NC",
    "fl3": "富士FL3",
    "e100": "柯达E100",
    "cn200": "柯达CN200",
    "leica": "徕卡经典",
    "monochrome": "徕卡黑白",
    "pentax": "宾得明亮",
    "ricoh_green": "理光电影绿",
    "ricoh_yellow": "理光电影黄",
    "ricoh_negative": "理光负片",
    "ricoh_positive": "理光正片",
    "standard": "标准",
    "superia1600": "富士Superia 1600",
    "nature1600": "富士Natura 1600",
    "ultramax400": "柯达Ultramax 400",
    "cinestill800t.33": "Cinestill 800T",
    "velvia50.33": "富士Velvia 50",
    "log_log_restore_apple_log2": "Apple Log 2 还原",
    "log_log_restore_flog2": "F-Log2 还原",
    "log_log_restore_llog": "L-Log 还原",
    "log_log_restore_log3g10": "Log3G10 还原",
    "log_log_restore_logc4": "LogC4 还原",
    "log_log_restore_vlog": "V-Log 还原",
}
official.update(CAMERA_NAMES)

# ---------- 3. cameralook 系列 ----------
CAMERALOOK = {
    0: "原色", 1: "清透", 2: "奶油", 3: "暮光", 4: "暖阳",
    5: "冷杉", 6: "旧梦", 7: "薄雾", 8: "浅滩", 9: "琥珀",
    10: "青瓷", 11: "晨露", 12: "夜巡", 13: "茶褐", 14: "雨林",
    15: "砂砾", 16: "信笺", 17: "白昼", 18: "蓝调", 19: "焦糖",
    20: "银盐", 21: "年轮", 22: "余晖",
}

# ---------- 4. fengwei 仿色 ----------
FENGWEI = {
    "fw203_s_770": "仿色·蒸馏", "fw203_v_770": "仿色·蒸馏",
    "fw203_s_768": "仿色·增强", "fw203_v_768": "仿色·增强",
    "fw203_s_769": "仿色·颗粒", "fw203_v_769": "仿色·颗粒",
    "fw203_s_8": "仿色·基础", "fw203_v_8": "仿色·基础",
    "fw203_s_2": "仿色·经典彩色", "fw203_v_2": "仿色·经典彩色",
    "fw203_s_1": "仿色·黑白", "fw203_v_1": "仿色·黑白",
    "fw203_s_16": "富士CC II", "fw203_v_16": "富士CC II",
    "fw203_s_17": "珠光", "fw203_v_17": "珠光",
    "fw203_s_18": "Pocket", "fw203_v_18": "Pocket",
    "fw203_s_19": "富士NN", "fw203_v_19": "富士NN",
    "fw203_s_20": "富士NC", "fw203_v_20": "富士NC",
    "fw203_s_21": "理光正片", "fw203_v_21": "理光正片",
    "fw203_s_22": "理光负片", "fw203_v_22": "理光负片",
    "fw203_s_23": "全能400", "fw203_v_23": "全能400",
    "fw203_s_24": "哈苏蓝", "fw203_v_24": "哈苏蓝",
    "fw203_s_25": "柯达5207", "fw203_v_25": "柯达5207",
    "fw203_s_26": "富士CC", "fw203_v_26": "富士CC",
    "fw203_s_27": "800T冷调", "fw203_v_27": "800T冷调",
    "fw203_s_28": "富士C200", "fw203_v_28": "富士C200",
    "fw203_s_29": "G7X II", "fw203_v_29": "G7X II",
    "fw203_s_30": "柯达5219", "fw203_v_30": "柯达5219",
    "fw203_s_31": "Classic U", "fw203_v_31": "Classic U",
    "fw203_s_32": "G12", "fw203_v_32": "G12",
    "fw203_s_33": "柯达正片64", "fw203_v_33": "柯达正片64",
    "fw203_s_34": "Portra 160", "fw203_v_34": "Portra 160",
    "fw203_s_35": "哈苏蓝II", "fw203_v_35": "哈苏蓝II",
    "fw203_s_36": "松下S9暖调", "fw203_v_36": "松下S9暖调",
    "fw203_s_37": "理光GR III", "fw203_v_37": "理光GR III",
    "fw203_s_38": "适马BF", "fw203_v_38": "适马BF",
    "fw203_s_512": "仿色·云端", "fw203_v_512": "仿色·云端",
}

# ---------- 5. 场景词表 ----------
SCENE = {
    # 自然
    "autumn": "秋景", "spring": "春景", "summer": "夏景", "winter": "冬景",
    "beach": "海滩", "sea": "海洋", "ocean": "海洋", "lake": "湖泊",
    "river": "河流", "mountain": "山川", "sky": "天空", "cloud": "云层",
    "clouds": "云层", "sunrise": "日出", "sunset": "日落", "dusk": "黄昏",
    "dawn": "黎明", "noon": "正午", "midnight": "午夜", "night": "夜景",
    "snow": "雪景", "rain": "雨天", "fog": "雾天", "forest": "森林",
    "tree": "树木", "trees": "树木", "grass": "草地", "flower": "花卉",
    "flowers": "花卉", "green": "绿植", "plants": "绿植", "leaf": "落叶",
    "desert": "沙漠", "canyon": "峡谷", "waterfall": "瀑布", "island": "海岛",
    "garden": "花园", "park": "公园", "field": "田野", "landscape": "风景",
    "nature": "自然", "water": "水面", "underwater": "水下", "diving": "潜水",
    "backlight": "逆光", "rainbow": "彩虹", "starry": "星空", "moon": "月亮",
    "sunlight": "阳光", "window": "窗边", "shadow": "阴影",

    # 城市
    "city": "城市", "street": "街拍", "building": "建筑",
    "architecture": "建筑", "temple": "寺庙", "buddha": "佛像",
    "church": "教堂", "bridge": "桥梁", "tower": "塔",
    "shop": "店面", "store": "店铺", "cafe": "咖啡馆", "restaurant": "餐厅",
    "bar": "酒吧", "hotel": "酒店", "room": "室内", "home": "居家",
    "indoor": "室内", "outdoor": "户外", "traffic": "车流", "car": "汽车",
    "train": "列车", "airplane": "飞机", "boat": "船只", "bike": "单车",
    "market": "市集", "neon": "霓虹", "sign": "招牌", "window_light": "窗光",

    # 人物
    "portrait": "人像", "people": "人物", "person": "人物",
    "selfie": "自拍", "group": "合影", "baby": "婴儿", "child": "儿童",
    "kid": "儿童", "man": "男士", "woman": "女士", "couple": "情侣",
    "family": "全家福", "wedding": "婚礼", "party": "聚会",
    "beauty": "美颜", "skin": "肤色", "face": "面部",

    # 动物
    "pet": "宠物", "cat": "猫咪", "dog": "狗狗", "cow": "牛",
    "bird": "鸟类", "fish": "鱼类", "horse": "马", "sheep": "羊",
    "panda": "熊猫", "insect": "昆虫", "butterfly": "蝴蝶", "wildlife": "野生动物",

    # 食物
    "food": "美食", "curry": "咖喱", "coffee": "咖啡", "tea": "茶",
    "cake": "蛋糕", "bread": "面包", "fruit": "水果", "drink": "饮品",
    "dessert": "甜点", "noodle": "面食", "rice": "米饭", "meat": "肉类",
    "vegetable": "蔬菜", "wine": "酒",

    # 静物 / 物体
    "document": "文档", "doc": "文档", "text": "文本", "barcode": "条码",
    "qr": "二维码", "screen": "屏幕", "book": "书籍", "toy": "玩具",
    "jewelry": "珠宝", "watch": "钟表", "shoe": "鞋", "cloth": "服饰",
    "bag": "包袋", "furniture": "家具", "art": "艺术品",

    # 色彩 / 风格修饰
    "blue": "蓝调", "pink": "粉调", "warm": "暖调", "cool": "冷调",
    "cold": "冷调", "hot": "暖调", "bright": "明亮", "dark": "暗调",
    "soft": "柔光", "hard": "硬光", "vivid": "鲜艳", "muted": "低饱和",
    "low": "低", "high": "高", "film": "胶片", "vintage": "复古",
    "retro": "复古", "modern": "现代", "classic": "经典",
    "natural": "自然", "fresh": "清新", "clean": "干净",
    "mono": "黑白", "bw": "黑白", "gray": "灰调", "gold": "金调",
    "silver": "银调", "green_tone": "绿调", "red": "红调",
    "orange": "橙调", "yellow": "黄调", "purple": "紫调",
    "candlelight": "烛光", "neon_light": "霓虹光", "lighting": "光效",

    # 场景修饰
    "lite": "轻", "pro": "专业", "plus": "加强", "mini": "迷你",
    "ii": "II", "iii": "III", "iv": "IV", "v2": "V2",
    "default": "默认", "custom": "自定义", "common": "通用",
    "normal": "标准", "standard": "标准", "debug": "调试",
    "black": "黑", "white": "白", "chroma": "彩",

    # 地域
    "india": "印度", "china": "中国", "japan": "日本",
    "korea": "韩国", "america": "美国", "europe": "欧洲",
    "paris": "巴黎", "tokyo": "东京", "hongkong": "香港",

    # 前缀
    "cg": "CG", "ai": "AI", "mode": "模式", "beauty2": "美颜",
    "distinct": "鲜明", "berry": "莓果", "flowerdream": "花梦",
    "first": "初恋", "fresh_blue": "清新蓝",

    # ── 补：AI 模式 / 场景遗漏词 ──
    "agave": "龙舌兰", "soda": "汽水", "south": "南", "france": "法",
    "southfrance": "南法", "t": "T", "o": "O", "tando": "T&O",
    "human": "人像", "maple": "枫叶", "leaves": "树叶",
    "mapleleaves": "枫叶", "motorbike": "摩托", "overcast": "阴天",
    "ppt": "课件", "silhouette": "剪影", "succulent": "多肉",
    "human2": "人像",

    # ── 光效 ──
    "dazzling": "炫光", "dreamland": "梦境", "gorgeous": "华彩",
    "lanshan": "蓝山", "nostalgia": "怀旧", "holi": "洒红节",
    "movie": "电影", "shutter": "快门", "stage": "舞台",
    "dot": "光斑", "light": "光", "lighting2": "光效",

    # ── 化妆 / 效果 ──
    "makeup": "妆容", "hardline": "硬朗", "sweet": "甜美",

    # ── 徕卡内部代号（来自 config.json 的 en 名）──
    "etn": "经典", "brs": "棕调", "chr": "铬色", "cls": "经典",
    "cnt": "对比", "ia": "自然", "tel": "长焦", "cc2": "CC",

    # ── 其他 ──
    "log": "Log", "709": "709", "c1": "C1", "c2": "C2",
    "db": "暗", "fbld": "前亮", "ltg": "光", "rh": "高光",
    "rl": "低光", "tbw": "青白", "tc": "青",

    # ── lut_normal_* 风格名 ──
    "clearness": "清透", "classical": "古典", "neutral": "中性",
    "lively": "生动", "freshness": "清新", "mysterious": "神秘",
    "blackgold": "黑金", "blackice": "黑冰", "brightshining": "闪亮",
    "entryromance": "初遇", "romance": "浪漫", "holiday": "假日",
    "japanese": "日系", "latte": "拿铁", "lilt": "轻快",
    "mint": "薄荷", "cookie": "曲奇", "fade": "褪色",
    "dolby": "杜比", "dolbybrightness": "杜比亮", "hdr2sdr": "HDR 转 SDR",
    "filene": "胶片", "bbp": "BBP",

    # ── 相机/胶片型号（数字代号）──
    "600f": "600F", "bf70": "BF70", "c50d": "C50D", "c64": "C64",
    "f50": "F50", "fe250": "FE250", "fr500": "FR500",
    "g200": "G200", "h400": "H400",

    # ── 参数类（相机内置调节）──
    "temperature": "色温", "tone": "色调", "tune": "调校",
    "vibrance": "自然饱和度", "contrast": "对比度", "saturation": "饱和度",
    "hue": "色相", "minus": "减", "plus2": "加",
    "n": "N",

    # ── 最后一批 ──
    "original": "原味", "oxygen": "氧气", "quiet": "静谧",
    "whiteandblack": "黑白", "whitening": "美白",
    "sibopenk": "西柚粉",
    "central": "中央", "fantasy": "幻想", "lost": "迷失",
    "meet": "相遇", "rome": "罗马", "wind": "风之语",

    # 型号代号
    "bf": "BF", "c": "C", "f": "F", "g": "G", "h": "H",
    "p": "P", "r": "R", "v": "V",
}


def scene_zh(stem: str) -> str:
    body = stem
    for prefix in ("lut_aiscene_", "lut_normal_", "lut_beauty_", "lut_ai_mode_",
                   "lut_cg_", "lut_lighting_", "lut_l_", "lut_", "beauty_"):
        if body.startswith(prefix):
            body = body[len(prefix):]
            break

    parts = [p for p in body.split("_") if p]
    out = []
    for p in parts:
        low = p.lower()
        if low in SCENE:
            out.append(SCENE[low])
        elif low.isdigit():
            out.append(low)
        elif len(p) <= 4 and p.isupper():
            out.append(p)
        else:
            out.append(p.capitalize())

    name = "".join(out) if out else stem
    return name if name else stem


def chinese_for(stem: str) -> str:
    if stem in official:
        return official[stem]
    if stem in FENGWEI:
        return FENGWEI[stem]
    if stem.startswith("cameralook_tone-"):
        try:
            n = int(stem.replace("cameralook_tone-", ""))
            return CAMERALOOK.get(n, f"画面{n:02d}")
        except ValueError:
            pass
    if stem.startswith(("lut_", "beauty_")):
        return scene_zh(stem)
    return stem.replace("_", " ")


# ---------- 6. 输出 ----------
lut_dir = os.path.join(RES, "LUTs")
stems = sorted(os.path.splitext(f)[0] for f in os.listdir(lut_dir) if f.endswith(".bin"))

mapping = {}
untranslated = []
for s in stems:
    zh = chinese_for(s)
    mapping[s] = zh
    # 判定是否仍是英文（没有中文字符）
    if not any('\u4e00' <= ch <= '\u9fff' for ch in zh):
        untranslated.append((s, zh))

out = os.path.join(RES, "lut_names_zh.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(mapping, f, ensure_ascii=False, indent=1)

print(f"生成 {out}")
print(f"  条目: {len(mapping)}")
print(f"  仍是纯英文的: {len(untranslated)}")
for s, zh in untranslated[:40]:
    print(f"    {s:44s} -> {zh}")
