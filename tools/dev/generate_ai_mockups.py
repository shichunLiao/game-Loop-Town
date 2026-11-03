"""AI 场景插画生成 + HUD 合成管线。

为什么这样分工：
    参考图是 AI 生成的插画，而我之前用 PIL 的基本图元去拼 —— 那不是对等的比较。
    正确做法是：**插画交给图像生成，UI 由我精确绘制**。
    HUD 是几何图形，我能 100% 还原，而且游戏里本来就要用同一套绘制逻辑。

    分工的另一个好处：HUD 作为独立图层，将来直接搬到 Godot 的 Control 节点，
    不需要把 UI 烤进背景图里。

产出：
    docs/mockups/ai/raw/<name>.png   生成的原始插画（不含 HUD）
    docs/mockups/ai/<name>.png       叠好 HUD 的完整效果图
    docs/mockups/ai/prompts.json     每张图实际使用的提示词（可复现、可微调）

用法：
    python tools/dev/generate_ai_mockups.py                       # 全部场景，默认 gemini
    python tools/dev/generate_ai_mockups.py clocktower            # 只做某一张
    python tools/dev/generate_ai_mockups.py clocktower --force    # 忽略缓存重新生成
    python tools/dev/generate_ai_mockups.py --backend pollinations  # 换后端（备用）

配置：
    在项目根目录 .env 里填 GEMINI_API_KEY=AIza...
    申请地址 https://aistudio.google.com/apikey
    可选 GEMINI_IMAGE_MODEL=gemini-2.5-flash-image
"""

from __future__ import annotations

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

PROJECT = Path(r"G:\新建游戏项目")
OUT_DIR = PROJECT / "docs" / "mockups" / "ai"
ASSETS = PROJECT / "assets"

W, H = 1920, 1080
DEFAULT_GEMINI_MODEL = "gemini-2.5-flash-image"

# ---------------------------------------------------------------------------
# 统一的美术指导后缀 —— 这是让多张图风格一致的关键
# ---------------------------------------------------------------------------
STYLE = (
    "dark fairytale gothic 2D side-scrolling metroidvania game scene, "
    "hand-painted illustration, thick ink outlines, deep shadows, "
    "desaturated moody palette, strong silhouettes, dramatic single-colour "
    "atmospheric lighting, layered depth with foreground silhouettes framing "
    "the edges, painterly texture, no text, no watermark, no user interface, "
    "wide side view, platformer level layout with clearly readable flat "
    "walkable ground surfaces and platforms"
)

# ---------------------------------------------------------------------------
# 提示词表 —— 每条都对应提示词文档里的具体场景要求
# ---------------------------------------------------------------------------
SCENES: dict[str, dict] = {
    "clocktower": {
        "title": "第四章 · 钟楼的心脏",
        "chapter": "第四章 · 钟楼的心脏",
        "boss": "钟楼看守",
        "boss_en": "Chapter 4 · Clocktower Heart",
        "boss_ratio": 0.62,
        "health": 3,
        "flame": True,
        "equip": [("notebook", "发光的笔记本"), ("big_scissors", "大剪刀")],
        "prompt": (
            "Interior of a giant clock tower, enormous brass gears and cogs filling "
            "the walls, three huge glowing clock faces embedded in the background "
            "walls, brass-toothed gear-rail platforms to stand on, a tall dark "
            "silhouetted figure in a wide-brimmed hat turning a massive windlass in "
            "the centre, hanging chains and a broken pendulum, "
            "monochrome crimson and burnt-orange lighting, glowing warm clock faces, "
            "dancing puppets silhouetted in the background, torn playing cards "
            "scattered in the air"
        ),
    },
    "theater": {
        "title": "第二章 · 针线与纽扣眼",
        "chapter": "第二章 · 针线与纽扣眼",
        "boss": "人偶师 · 皮埃罗",
        "boss_en": "Chapter 2 · Old Theater Boss",
        "boss_ratio": 0.55,
        "health": 4,
        "flame": False,
        "equip": [("notebook", "发光的笔记本"), ("big_scissors", "大剪刀")],
        "prompt": (
            "Ruined old theatre interior, decayed wooden stage in the foreground, "
            "rows of porcelain dolls sitting in the audience seats each missing one "
            "eye, heavy crimson velvet curtains hanging from above, a huge pale "
            "patchwork puppeteer with a half-burned face standing on the stage "
            "holding dozens of thin glowing red control threads that stretch down "
            "to small wooden marionettes, stained glass windows glowing faintly in "
            "the background, teal mist and cold flame braziers at the stage edges, "
            "splintered floorboards"
        ),
    },
    "wax_lane": {
        "title": "第一章 · 蜡像巷",
        "chapter": "第一章 · 蜡像巷",
        "boss": "蜡像师 · 莫里斯",
        "boss_en": "Chapter 1 · Wax Lane",
        "boss_ratio": 0.4,
        "health": 6,
        "flame": False,
        "equip": [("notebook", "发光的笔记本")],
        "prompt": (
            "Narrow cobbled alley at dusk lined on both sides with rows of "
            "life-sized wax statues of townspeople, every statue facing the centre "
            "of the street, warm amber street lamps casting pools of light, "
            "some statues slightly closer to the viewer than others, "
            "a wax museum with a lit doorway at the far end of the alley, "
            "hanging glass lanterns, wet cobblestones, "
            "warm yellow and dark red palette against black shadow, "
            "a lone small silhouetted figure in a wide-brimmed hat walking in the "
            "middle of the street"
        ),
    },
    "town_entrance": {
        "title": "序幕 · 小镇入口",
        "chapter": "序幕 · 小镇入口",
        "boss": "",
        "boss_en": "Prologue · Town Entrance",
        "boss_ratio": 0.0,
        "health": 5,
        "flame": False,
        "equip": [("notebook", "发光的笔记本")],
        "prompt": (
            "Dusk town gate at the edge of a strange circular village, heavy low "
            "fog, a rusted wooden signboard on two posts, cobbled road leading to "
            "the right, a tall clock tower in the far distance clearly taller than "
            "every other building, iron railings and bare twisted dead trees in the "
            "foreground, small shops and narrow alleys in the midground, "
            "crooked houses with a few warmly lit windows, "
            "violet and amber dusk sky, a lone small silhouetted figure in a "
            "wide-brimmed hat seen from behind on the left side of the road"
        ),
    },
    "town_hub": {
        "title": "小镇 Hub · 中央广场",
        "chapter": "小镇 Hub",
        "boss": "",
        "boss_en": "Town Hub · Central Square",
        "boss_ratio": 0.0,
        "health": 5,
        "flame": False,
        "equip": [("notebook", "发光的笔记本")],
        "prompt": (
            "Central circular town square at dusk, cobbled ring road curving around "
            "a huge clock tower in the very centre, the road visibly bows upward at "
            "both sides, grey-clothed villagers scattered along the road each "
            "repeating a simple chore such as carrying a child or a water bucket, "
            "iron street lamps with warm amber light, tall crooked houses with lit "
            "windows in the midground, a second upper walkway of stone ledges, "
            "heavy fog, violet and amber dusk sky, "
            "a lone small silhouetted figure in a wide-brimmed hat on the road"
        ),
    },
}


# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------

def load_env() -> dict[str, str]:
    """读取项目根目录的 .env（不依赖 python-dotenv，保持脚本零依赖可跑）。"""
    env: dict[str, str] = {}
    path = PROJECT / ".env"
    if not path.exists():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip()
    return env


# ---------------------------------------------------------------------------
# 生成后端
# ---------------------------------------------------------------------------

class BackendError(RuntimeError):
    pass


def generate_gemini(prompt: str, api_key: str, model: str,
                    aspect_ratio: str = "16:9") -> bytes:
    """调用 Gemini 图像生成，返回图片字节。

    返回值里图像以 inlineData(base64) 出现在 candidates[].content.parts[]。
    """
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{model}:generateContent?key={urllib.parse.quote(api_key)}")
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {"aspectRatio": aspect_ratio},
        },
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json",
                 "User-Agent": "looptown-asset-pipeline"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:400]
        hint = ""
        if exc.code in (400, 403):
            hint = "（检查 API Key 是否有效、是否已为该模型开通）"
        elif exc.code == 429:
            hint = "（免费层每分钟请求数超限，等一分钟再跑）"
        raise BackendError(f"HTTP {exc.code}{hint} {detail}") from exc
    except Exception as exc:  # noqa: BLE001
        raise BackendError(f"{type(exc).__name__}: {exc}") from exc

    try:
        data = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise BackendError(f"返回不是 JSON：{raw[:200]!r}") from exc

    if "error" in data:
        raise BackendError(str(data["error"])[:400])

    texts: list[str] = []
    for candidate in data.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"])
            if part.get("text"):
                texts.append(str(part["text"]))
    detail = ("模型返回文本：" + " ".join(texts)[:300]) if texts else "没有 candidates"
    raise BackendError(f"返回里没有图像。{detail}")


def generate_pollinations(prompt: str, width: int, height: int) -> bytes:
    """备用后端。实测 2026-10 起已要求 API Key，会返回 402。"""
    full = f"{prompt}, {STYLE}"
    encoded = urllib.parse.quote(full, safe="")
    url = (f"https://image.pollinations.ai/prompt/{encoded}"
           f"?width={width}&height={height}&nologo=true&model=sana")
    request = urllib.request.Request(url, headers={"User-Agent": "looptown-asset-pipeline"})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read()


def fetch_image(name: str, prompt: str, backend: str, force: bool = False) -> Path | None:
    """生成（或复用缓存）一张原图，返回文件路径。"""
    suffix = ".jpg" if backend == "pollinations" else ".png"
    dest = OUT_DIR / "raw" / f"{name}{suffix}"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and not force and dest.stat().st_size > 4096:
        print(f"  cached  {dest.name}")
        return dest

    print(f"  generating {name} via {backend} ... ", end="", flush=True)
    started = time.time()
    try:
        if backend == "gemini":
            env = load_env()
            api_key = env.get("GEMINI_API_KEY", "") or os.environ.get("GEMINI_API_KEY", "")
            model = (env.get("GEMINI_IMAGE_MODEL", "")
                     or os.environ.get("GEMINI_IMAGE_MODEL", "")
                     or DEFAULT_GEMINI_MODEL)
            if not api_key:
                print("FAILED 缺少 GEMINI_API_KEY")
                print("       请在 G:\\新建游戏项目\\.env 里填：GEMINI_API_KEY=AIza...")
                print("       申请：https://aistudio.google.com/apikey")
                return None
            data = generate_gemini(f"{prompt}, {STYLE}", api_key, model)
        else:
            data = generate_pollinations(prompt, W, H)
    except BackendError as exc:
        print(f"FAILED {exc}")
        return None
    except Exception as exc:  # noqa: BLE001
        print(f"FAILED {type(exc).__name__}: {exc}")
        return None

    if len(data) < 4096:
        print(f"FAILED 只有 {len(data)} 字节，可能被拦或限流")
        return None
    dest.write_bytes(data)
    print(f"ok  {len(data) // 1024} KB in {time.time() - started:.1f}s")
    return dest


# ---------------------------------------------------------------------------
# HUD 绘制（与游戏内 HUD 逻辑对应，将来直接搬到 Control 节点）
# ---------------------------------------------------------------------------

def find_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = ((r"C:\Windows\Fonts\msyhbd.ttc", r"C:\Windows\Fonts\msyh.ttc")
             if bold else (r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf"))
    for path in names:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


F_CHAPTER = find_font(30, True)
F_BOSS = find_font(26, True)
F_LABEL = find_font(19)
F_SMALL = find_font(17)
F_NUM = find_font(17, True)
F_FOOT = find_font(15)

C_BONE = (232, 226, 212)
C_BRASS_HI = (216, 176, 98)
C_HP = (222, 216, 200)


def ornate_frame(d: ImageDraw.ImageDraw, box: tuple, fill: tuple,
                 accent: tuple = C_BRASS_HI, alpha: int = 220) -> None:
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0, y0, x1, y1], radius=10, fill=fill + (alpha,),
                        outline=accent + (215,), width=3)
    d.rounded_rectangle(
        [x0 + 6, y0 + 6, x1 - 6, y1 - 6], radius=7,
        outline=(max(0, accent[0] - 90), max(0, accent[1] - 80),
                 max(0, accent[2] - 60), 180), width=2)
    for cx, cy in ((x0 + 14, y0 + 14), (x1 - 14, y0 + 14),
                   (x0 + 14, y1 - 14), (x1 - 14, y1 - 14)):
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=accent + (235,))


def _prop_icon(name: str, scale: float) -> Image.Image | None:
    path = ASSETS / "props" / f"{name}.png"
    if not path.exists():
        return None
    with Image.open(path) as im:
        icon = im.convert("RGBA")
    return icon.resize((max(1, int(icon.width * scale)),
                        max(1, int(icon.height * scale))), Image.NEAREST)


def draw_hud(canvas: Image.Image, spec: dict, item_count: int = 2) -> None:
    d = ImageDraw.Draw(canvas, "RGBA")

    # --- 左上：生命容器 ---
    total, filled = 7, int(spec["health"])
    gap, r = 40.0, 15.0
    bw = total * gap + 22
    ornate_frame(d, (46, 40, 46 + bw, 104), (22, 18, 20))
    for i in range(total):
        cx, cy = 46 + 22 + i * gap, 72
        if i < filled:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C_HP + (255,),
                      outline=(58, 48, 40, 255), width=3)
            d.ellipse([cx - 6, cy - 6, cx - 1, cy + 1], fill=(30, 26, 26, 255))
            d.ellipse([cx + 1, cy - 6, cx + 6, cy + 1], fill=(30, 26, 26, 255))
            d.arc([cx - 5, cy + 2, cx + 5, cy + 10], 0, 180,
                  fill=(30, 26, 26, 255), width=2)
        else:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(34, 30, 32, 225),
                      outline=(74, 66, 62, 205), width=3)

    # --- 灵魂 / 火焰容器 ---
    vx, vr = 46 + bw + 64, 40
    d.ellipse([vx - vr - 7, 68 - vr - 7, vx + vr + 7, 68 + vr + 7],
              fill=(20, 17, 18, 240), outline=C_BRASS_HI + (220,), width=4)
    d.ellipse([vx - vr, 68 - vr, vx + vr, 68 + vr], fill=(12, 14, 18, 255),
              outline=(96, 70, 30, 225), width=3)
    inner = vr - 8
    if spec.get("flame"):
        d.ellipse([vx - inner, 68 - inner, vx + inner, 68 + inner],
                  fill=(48, 22, 10, 255))
        for i in range(6):
            rr = inner * (1.0 - i / 8.0)
            d.ellipse([vx - rr, 68 - rr, vx + rr, 68 + rr],
                      fill=(170 + int(85 * i / 5.0),
                            60 + int(120 * i / 5.0), 20, 70))
    else:
        top = 68 + inner - 2 * inner * 0.66
        d.ellipse([vx - inner, top - inner * 0.5, vx + inner, 68 + inner],
                  fill=(120, 210, 230, 225))
        d.ellipse([vx - inner * 0.6, top, vx + inner * 0.6, top + inner * 0.7],
                  fill=(200, 246, 252, 180))

    # --- 左侧道具槽 ---
    for i in range(item_count):
        cx, cy, ir = 92 + i * 92, 240, 34
        d.ellipse([cx - ir - 5, cy - ir - 5, cx + ir + 5, cy + ir + 5],
                  fill=(20, 17, 18, 235), outline=C_BRASS_HI + (205,), width=3)
        d.ellipse([cx - ir, cy - ir, cx + ir, cy + ir], fill=(30, 32, 40, 255))
        icon = _prop_icon("button" if i == 0 else "rag_doll", 1.7)
        if icon is not None:
            canvas.alpha_composite(icon, (int(cx - icon.width / 2),
                                          int(cy - icon.height / 2)))
            d = ImageDraw.Draw(canvas, "RGBA")
        d.text((cx + ir - 12, cy + ir - 22), str(2 if i == 0 else 1), font=F_NUM,
               fill=C_BONE + (255,), stroke_width=3, stroke_fill=(0, 0, 0, 235))

    # --- 右下装备槽 ---
    slots = spec.get("equip", [])
    if slots:
        size, sgap = 132, 22
        tw = len(slots) * size + (len(slots) - 1) * sgap
        x0, y0 = W - 54 - tw, H - 54 - size
        for i, (icon_name, label) in enumerate(slots):
            bx = x0 + i * (size + sgap)
            ornate_frame(d, (bx, y0, bx + size, y0 + size), (18, 16, 18), C_BRASS_HI, 240)
            icon = _prop_icon(icon_name, 3.2)
            if icon is not None:
                canvas.alpha_composite(icon, (int(bx + size / 2 - icon.width / 2),
                                              int(y0 + size / 2 - icon.height / 2 + 6)))
                d = ImageDraw.Draw(canvas, "RGBA")
            lw = d.textlength(label, font=F_LABEL)
            d.text((bx + size / 2 - lw / 2, y0 + size + 8), label, font=F_LABEL,
                   fill=C_BONE + (248,), stroke_width=3, stroke_fill=(0, 0, 0, 240))

    # --- 顶部章节 + Boss 条 ---
    cx = W / 2
    title = spec.get("chapter", "")
    if title:
        tw = d.textlength(title, font=F_CHAPTER)
        d.text((cx - tw / 2, 22), title, font=F_CHAPTER, fill=C_BONE + (252,),
               stroke_width=5, stroke_fill=(0, 0, 0, 245))
        d.line([cx - tw / 2 - 90, 42, cx - tw / 2 - 16, 42],
               fill=C_BRASS_HI + (205,), width=3)
        d.line([cx + tw / 2 + 16, 42, cx + tw / 2 + 90, 42],
               fill=C_BRASS_HI + (205,), width=3)

    boss = spec.get("boss", "")
    if boss:
        bar_w, bar_h = 760, 26
        bx, by = cx - bar_w / 2, 68
        d.rectangle([bx - 6, by - 6, bx + bar_w + 6, by + bar_h + 6],
                    fill=(16, 14, 16, 230), outline=(104, 74, 32, 225), width=3)
        d.rectangle([bx, by, bx + bar_w, by + bar_h], fill=(38, 20, 22, 255))
        ratio = float(spec.get("boss_ratio", 0.6))
        d.rectangle([bx, by, bx + bar_w * ratio, by + bar_h], fill=(178, 44, 44, 255))
        d.rectangle([bx, by, bx + bar_w * ratio, by + 7], fill=(226, 96, 84, 255))
        for i in range(1, 6):
            sx = bx + bar_w * i / 6.0
            d.line([sx, by, sx, by + bar_h], fill=(16, 14, 16, 200), width=3)
        for ex in (bx - 6, bx + bar_w + 6):
            d.polygon([(ex - 13, by + bar_h / 2), (ex, by - 13),
                       (ex + 13, by + bar_h / 2), (ex, by + bar_h + 13)],
                      fill=(88, 60, 26, 235))
        nw = d.textlength(boss, font=F_BOSS)
        d.text((cx - nw / 2, by + bar_h + 16), boss, font=F_BOSS, fill=C_BONE + (248,),
               stroke_width=5, stroke_fill=(0, 0, 0, 240))
        en = spec.get("boss_en", "")
        if en:
            ew = d.textlength(en, font=F_SMALL)
            d.text((cx - ew / 2, by + bar_h + 54), en, font=F_SMALL,
                   fill=(196, 186, 178, 245), stroke_width=3, stroke_fill=(0, 0, 0, 225))

    # --- 底部黑条 ---
    d.rectangle([0, H - 30, W, H], fill=(6, 6, 8, 215))
    foot = "Godot Engine v4.6.3 · 回环镇项目"
    fw = d.textlength(foot, font=F_FOOT)
    d.text((cx - fw / 2, H - 24), foot, font=F_FOOT, fill=(152, 150, 158, 240))


def darken_edges(canvas: Image.Image, strength: float = 0.5) -> None:
    """四角压暗 —— 让 HUD 文字在明亮插画上也能读清。"""
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([-W * 0.12, -H * 0.16, W * 1.12, H * 1.16], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(200))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    dark.putalpha(ImageChops.invert(mask).point(lambda v: int(v * strength)))
    canvas.alpha_composite(dark)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def main() -> int:
    args = [a for a in sys.argv[1:]]
    force = "--force" in args
    args = [a for a in args if not a.startswith("--")]

    backend = "gemini"
    if "--backend" in sys.argv:
        index = sys.argv.index("--backend")
        if index + 1 < len(sys.argv):
            backend = sys.argv[index + 1]
            if backend in args:
                args.remove(backend)

    only = args[0] if args and args[0] in SCENES else ""
    names = [only] if only else list(SCENES.keys())

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"后端：{backend}    场景：{', '.join(names)}")
    if backend == "gemini":
        env = load_env()
        key = env.get("GEMINI_API_KEY", "")
        if not key:
            print("")
            print("缺少 GEMINI_API_KEY。请先把 Key 填进 G:\\新建游戏项目\\.env：")
            print("    GEMINI_API_KEY=AIza...")
            print("申请地址：https://aistudio.google.com/apikey")
            return 2
        print(f"已读取 GEMINI_API_KEY（{len(key)} 字符），"
              f"模型 {env.get('GEMINI_IMAGE_MODEL') or DEFAULT_GEMINI_MODEL}")

    prompts_log: dict[str, dict] = {}
    composed: list[str] = []

    for name in names:
        spec = SCENES[name]
        prompts_log[name] = {
            "title": spec["title"],
            "backend": backend,
            "prompt": spec["prompt"],
            "style_suffix": STYLE,
        }
        raw = fetch_image(name, spec["prompt"], backend, force)
        if raw is None:
            print(f"  !! {name} 生成失败，跳过合成")
            continue

        with Image.open(raw) as im:
            base = im.convert("RGBA")
        if base.size != (W, H):
            base = base.resize((W, H), Image.LANCZOS)

        darken_edges(base, 0.5)
        draw_hud(base, spec)
        dest = OUT_DIR / f"{name}.png"
        base.convert("RGB").save(dest)
        composed.append(name)
        print(f"  composed {dest.relative_to(PROJECT)}")

    log_path = OUT_DIR / "prompts.json"
    existing: dict = {}
    if log_path.exists():
        try:
            existing = json.loads(log_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            existing = {}
    existing.update(prompts_log)
    log_path.write_text(json.dumps(existing, ensure_ascii=False, indent=1),
                        encoding="utf-8")
    print("")
    print(f"完成：成功 {len(composed)}/{len(names)} 张。提示词记录在 "
          f"{log_path.relative_to(PROJECT)}")
    return 0 if composed else 1


if __name__ == "__main__":
    sys.exit(main())
