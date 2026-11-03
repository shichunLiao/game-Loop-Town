"""关卡效果图渲染器 —— 严格按《回环镇》提示词文档的场景要求绘制。

文档【十一】序幕 / 小镇入口 明确要求：
    场景：黄昏。大雾。锈迹斑斑的「欢迎来到回环镇」木牌。
          玩家从左进入。道路向右延伸。远处能够看到钟楼，钟楼始终明显高于其他建筑。
    前景：栏杆 / 枯树 / 路灯 / 碎石
    中景：居民住宅 / 小巷 / 小店 / 旧建筑
    远景：巨大钟楼
    第一次进入可拾取信件：「请找到小铃，带她回家。」

文档【十二】小镇 Hub：
    左蜡像巷 / 右剧院 / 下方枯井 / 中心钟楼；5~8 个 NPC 各有循环的重复动作
    道路必须体现完美圆环，「无论往哪里走，最后都会回到中心」

文档【十三】第一章 蜡像巷：
    结构：入口 → 蜡像街 → 小型战斗区 → 追逐区 → 蜡像馆
    视觉：蜡 / 暖黄灯 / 暗红 / 黑色阴影 / 玻璃 / 镜子 / 人形轮廓
    路边全是蜡像，部分会转头、眼睛跟随

文档【三十三】视觉规范：暗、忧郁、怪诞、手绘、童话恐怖、低饱和；
    场景主色＝蓝灰 / 灰绿 / 暗红 / 褐黄 / 蜡黄 / 火橙。

用法：
    python tools/dev/render_level_mockups.py
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

PROJECT = Path(r"G:\新建游戏项目")
ASSETS = PROJECT / "assets"
OUT_DIR = PROJECT / "docs" / "mockups"

W, H = 1920, 1080

# ---------------------------------------------------------------------------
# 调色板（文档【三十三】：蓝灰 / 灰绿 / 暗红 / 褐黄 / 蜡黄 / 火橙）
# ---------------------------------------------------------------------------
C_INK = (9, 8, 12)
C_DUSK_HI = (86, 70, 88)        # 黄昏天顶偏紫
C_DUSK_LO = (168, 112, 78)      # 黄昏地平线偏橙
C_FAR = (58, 56, 76)            # 远景：雾里压扁的蓝灰
C_FAR2 = (44, 44, 62)
C_MID = (46, 44, 58)            # 中景建筑
C_MID2 = (36, 35, 47)
C_NEAR = (20, 19, 26)           # 前景剪影
C_STONE = (62, 64, 80)
C_STONE_HI = (178, 186, 208)    # 可站平面亮边
C_STONE_MID = (108, 114, 140)
C_WAX = (236, 206, 128)
C_AMBER = (246, 176, 66)
C_RED = (156, 46, 56)
C_SOUL = (132, 214, 232)
C_BONE = (228, 222, 208)
C_BURN = (212, 100, 38)
C_MOSS = (86, 96, 82)           # 灰绿
C_GLASS = (150, 172, 190)


def find_font(size: int) -> ImageFont.FreeTypeFont:
    for path in (r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\msyhbd.ttc",
                 r"C:\Windows\Fonts\simhei.ttf", r"C:\Windows\Fonts\Deng.ttf"):
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


F_TITLE = find_font(26)
F_HUD = find_font(23)
F_SMALL = find_font(18)
F_NOTE = find_font(16)
F_NAME = find_font(19)


def load_sprite(path: Path, frame: int = 0, frames: int = 1,
                scale: float = 1.0) -> Image.Image | None:
    if not path.exists():
        return None
    with Image.open(path) as im:
        im = im.convert("RGBA")
        fw = im.width // frames
        img = im.crop((frame * fw, 0, (frame + 1) * fw, im.height))
    if scale != 1.0:
        img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))),
                         Image.NEAREST)
    return img


def paste_feet(canvas: Image.Image, sprite: Image.Image | None, x: float,
               feet_y: float, flip: bool = False) -> None:
    if sprite is None:
        return
    img = sprite.transpose(Image.FLIP_LEFT_RIGHT) if flip else sprite
    canvas.alpha_composite(img, (int(x - img.width / 2), int(feet_y - img.height)))


def contact_shadow(canvas: Image.Image, x: float, feet_y: float, width: float,
                   alpha: int = 120) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        [x - width / 2, feet_y - 7, x + width / 2, feet_y + 7], fill=(0, 0, 0, alpha))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(7)))


def rim_light(canvas: Image.Image, sprite: Image.Image | None, x: float, feet_y: float,
              color: tuple = (255, 238, 196), width: int = 3, alpha: int = 155) -> None:
    if sprite is None:
        return
    pad = 16
    layer = Image.new("RGBA", (sprite.width + pad * 2, sprite.height + pad * 2), (0, 0, 0, 0))
    layer.alpha_composite(sprite, (pad, pad))
    base = layer.split()[3]
    grown = base.filter(ImageFilter.MaxFilter(width * 2 + 1))
    outline = ImageChops.subtract(grown, base).filter(ImageFilter.GaussianBlur(2.0))
    ring = Image.new("RGBA", layer.size, color + (255,))
    ring.putalpha(outline.point(lambda v: int(v * alpha / 255.0)))
    canvas.alpha_composite(ring, (int(x - layer.width / 2), int(feet_y - layer.height + pad)))


def glow(canvas: Image.Image, x: float, y: float, radius: float, color: tuple,
         strength: float = 0.55) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 9
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(255 * strength * (1.0 - i / (steps + 1.4)))
        d.ellipse([x - r, y - r, x + r, y + r], fill=color + (a,))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.22)))


def vignette(canvas: Image.Image, strength: float = 0.5) -> None:
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([-W * 0.2, -H * 0.26, W * 1.2, H * 1.26], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(200))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    dark.putalpha(ImageChops.invert(mask).point(lambda v: int(v * strength)))
    canvas.alpha_composite(dark)


# ---------------------------------------------------------------------------
# 大雾 —— 文档【十一】明确要求「大雾」，这是序幕的核心氛围
# ---------------------------------------------------------------------------

def draw_fog(canvas: Image.Image, horizon: float, density: float = 1.0,
             color: tuple = (108, 104, 124), seed: int = 5) -> None:
    """分层雾：地平线附近最浓，向上向下淡出；再加几条横向漂移的雾带。"""
    rng = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # 浓雾核心：以地平线为中心的一整条
    for i in range(190):
        t = i / 189.0
        a = int(96 * density * (1.0 - abs(t - 0.5) * 2.0) ** 1.4)
        y = int(horizon - 240 + i * 3.0)
        if 0 <= y < H:
            d.line([0, y, W, y], fill=color + (a,))

    # 漂移雾带：高低错落，制造纵深
    for _ in range(11):
        cy = horizon + rng.uniform(-330, 140)
        cx = rng.uniform(-200, W + 200)
        cw = rng.uniform(420, 1000)
        ch = rng.uniform(56, 140)
        a = int(rng.uniform(28, 62) * density)
        d.ellipse([cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2],
                  fill=color + (a,))

    layer = layer.filter(ImageFilter.GaussianBlur(46))
    canvas.alpha_composite(layer)


# ---------------------------------------------------------------------------
# 天空 / 远景
# ---------------------------------------------------------------------------

def draw_dusk_sky(canvas: Image.Image, horizon: float) -> None:
    """黄昏天空：天顶偏紫 → 地平线偏橙（文档：场景是黄昏）。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    for y in range(int(horizon) + 80):
        t = min(y / max(horizon, 1.0), 1.0)
        t = t ** 1.7
        col = (
            int(C_DUSK_HI[0] + (C_DUSK_LO[0] - C_DUSK_HI[0]) * t),
            int(C_DUSK_HI[1] + (C_DUSK_LO[1] - C_DUSK_HI[1]) * t),
            int(C_DUSK_HI[2] + (C_DUSK_LO[2] - C_DUSK_HI[2]) * t),
        )
        d.line([0, y, W, y], fill=col + (255,))
    # 地平线暖光
    glow(canvas, W * 0.72, horizon - 30, 620, (240, 168, 108), 0.34)


def draw_clock_tower(canvas: Image.Image, x: float, spire_y: float, base_y: float,
                     width: float = 190, alpha: int = 255, lit: bool = True) -> None:
    """巨大钟楼 —— 文档反复强调「钟楼始终明显高于其他建筑」。

    做成哥特式尖顶 + 钟面 + 侧塔，是全地图的视觉锚点。
    """
    d = ImageDraw.Draw(canvas, "RGBA")
    body = (C_FAR2 if alpha == 255 else C_FAR) + (alpha,)
    x0, x1 = x, x + width
    cx = (x0 + x1) / 2

    # 塔身（收分：越往上越窄）
    d.polygon([(x0 - 16, base_y), (x1 + 16, base_y),
               (x1 - 6, spire_y + 210), (x0 + 6, spire_y + 210)], fill=body)
    # 钟面层
    band_y = spire_y + 210
    d.rectangle([x0 - 20, band_y, x1 + 20, band_y + 190], fill=body)
    # 尖顶
    d.polygon([(x0 - 26, band_y), (x1 + 26, band_y), (cx, spire_y)], fill=body)
    d.polygon([(cx - 7, spire_y + 6), (cx + 7, spire_y + 6), (cx, spire_y - 74)], fill=body)
    # 两侧小塔
    for sx in (x0 - 44, x1 + 24):
        d.rectangle([sx, band_y + 40, sx + 22, band_y + 190], fill=body)
        d.polygon([(sx - 6, band_y + 40), (sx + 28, band_y + 40), (sx + 11, band_y - 26)],
                  fill=body)

    # 钟面
    face_r = 54
    face_cy = band_y + 92
    d.ellipse([cx - face_r, face_cy - face_r, cx + face_r, face_cy + face_r],
              fill=(22, 22, 30, alpha), outline=(120, 126, 150, alpha), width=5)
    if lit:
        # 只有钟面是亮的 —— 小镇唯一「正常」的东西
        d.ellipse([cx - face_r + 8, face_cy - face_r + 8,
                   cx + face_r - 8, face_cy + face_r - 8],
                  fill=(196, 178, 132, 90))
    d.line([cx, face_cy, cx, face_cy - 34], fill=(198, 190, 170, alpha), width=4)
    d.line([cx, face_cy, cx + 26, face_cy + 12], fill=(198, 190, 170, alpha), width=4)
    # 小窗
    for wy in range(int(spire_y) + 250, int(base_y) - 60, 84):
        d.rectangle([cx - 11, wy, cx + 11, wy + 30], fill=(18, 18, 26, alpha))


def atmospheric_recede(canvas: Image.Image, depth: float = 0.55,
                       color: tuple = (96, 88, 112)) -> None:
    """给已绘制的内容盖一层「空气透视」膜，把它推到远处。

    这是让背景与玩法平面分开的关键一步：只靠画得更暗不够，
    必须整层压上一层冷调薄雾，纵深才会出来（手绘背景的通用做法）。
    """
    veil = Image.new("RGBA", (W, H), color + (int(255 * depth * 0.34),))
    canvas.alpha_composite(veil)


def draw_town_skyline(canvas: Image.Image, horizon: float, kind: str = "mid",
                      density: float = 1.0) -> None:
    """中景：居民住宅 / 小巷 / 小店 / 旧建筑（文档【十一】的中景要求）。"""
    rng = random.Random(97 if kind == "mid" else 41)
    d = ImageDraw.Draw(canvas, "RGBA")
    pal = [C_FAR, C_FAR2, (52, 50, 66)] if kind == "far" else [C_MID, C_MID2, (40, 39, 52)]
    x = -80
    while x < W + 80:
        bw = rng.randint(96, 196) * (0.7 if kind == "far" else 1.0)
        bh = rng.randint(110, 268) * (0.7 if kind == "far" else 1.0)
        top = horizon - bh
        body = pal[rng.randrange(len(pal))] + (255,)
        d.rectangle([x, top, x + bw, horizon + 30], fill=body)

        # 屋顶形态：尖顶 / 平顶 / 老虎窗（旧建筑与住宅的区别）
        roof = rng.random()
        if roof < 0.45:
            d.polygon([(x - 12, top), (x + bw + 12, top), (x + bw / 2, top - 42)],
                      fill=body)
        elif roof < 0.7:
            d.rectangle([x - 10, top - 16, x + bw + 10, top], fill=body)
            d.polygon([(x + bw * 0.3, top - 16), (x + bw * 0.5, top - 48),
                       (x + bw * 0.7, top - 16)], fill=body)
        else:
            d.rectangle([x - 10, top - 12, x + bw + 10, top], fill=body)

        # 窗与门（少数亮着暖色灯 —— 环境叙事：这里还住着人）
        rows = max(1, int(bh) // 76)
        cols = max(1, int(bw) // 60)
        for r in range(rows):
            for c in range(cols):
                wx = x + 18 + c * 60
                wy = top + 26 + r * 76
                if wx + 24 > x + bw - 6 or wy + 34 > horizon - 10:
                    continue
                lit = rng.random() < 0.24 * density
                col = (C_AMBER + (200,)) if lit else (22, 21, 29, 255)
                d.rectangle([wx, wy, wx + 24, wy + 34], fill=col)
                if lit:
                    glow(canvas, wx + 12, wy + 17, 34, C_AMBER, 0.3)
                    d = ImageDraw.Draw(canvas, "RGBA")
        # 门（一楼）
        door_x = x + bw * 0.42
        d.rectangle([door_x, horizon - 44, door_x + 30, horizon + 30], fill=(16, 15, 21, 255))
        x += bw + rng.randint(12, 40)


# ---------------------------------------------------------------------------
# 可站平面（沿用已验证的读法：厚亮带 + 向下渐暗的体块）
# ---------------------------------------------------------------------------

def draw_floor(canvas: Image.Image, x0: float, x1: float, surface_y: float,
               bottom_y: float, mossy: bool = False,
               edge_color: tuple | None = None) -> None:
    d = ImageDraw.Draw(canvas, "RGBA")
    if x1 <= x0:
        return
    x0i, x1i, sy = int(x0), int(x1), int(surface_y)
    top = edge_color or C_STONE_HI

    body_top = sy + 22
    height = max(1, int(bottom_y) - body_top)
    base = 66 if not mossy else 60
    for i in range(height):
        t = i / float(height)
        v = base - int(42 * min(t * 2.2, 1.0))
        g = v + (6 if mossy else 2)
        d.line([x0i, body_top + i, x1i, body_top + i],
               fill=(v, g, v + 12, 255))

    # 顶面亮带
    d.rectangle([x0i, sy, x1i, sy + 8], fill=top + (255,))
    d.rectangle([x0i, sy + 8, x1i, sy + 15], fill=C_STONE_MID + (255,))
    d.rectangle([x0i, sy + 15, x1i, sy + 22], fill=(74, 80, 100, 255))

    # 铺装：石板缝（小镇是铺装路面，不是天然岩层）
    y = sy + 34
    while y < bottom_y:
        d.line([x0i, y, x1i, y], fill=(22, 22, 30, 200), width=3)
        y += 46
    for i in range(x0i + 20, x1i, 96):
        d.line([i, sy + 22, i, min(sy + 34, int(bottom_y))],
               fill=(22, 22, 30, 190), width=3)

    # 苔痕（灰绿，文档允许的主色之一）
    if mossy:
        rng = random.Random(x0i + 7)
        for _ in range(int((x1i - x0i) / 60)):
            mx = rng.randint(x0i, max(x0i + 1, x1i - 40))
            mw = rng.randint(18, 52)
            d.rectangle([mx, sy + 8, mx + mw, sy + 15], fill=C_MOSS + (150,))

    d.rectangle([x0i, sy, x0i + 7, sy + 28], fill=top + (255,))
    d.rectangle([x1i - 7, sy, x1i, sy + 28], fill=top + (255,))


def draw_ledge(canvas: Image.Image, x0: float, x1: float, y: float,
               thickness: float = 34, mossy: bool = False) -> None:
    draw_floor(canvas, x0, x1, y, y + thickness + 26, mossy)
    d = ImageDraw.Draw(canvas, "RGBA")
    for i in range(int((x1 - x0) // 96)):
        px = x0 + 34 + i * 96
        d.polygon([(px, y + thickness), (px + 36, y + thickness),
                   (px + 18, y + thickness + 42)], fill=(18, 18, 26, 255))


def draw_chasm(canvas: Image.Image, left_x: float, right_x: float,
               surface_y: float, bottom_y: float) -> None:
    d = ImageDraw.Draw(canvas, "RGBA")
    d.rectangle([left_x, surface_y, right_x, bottom_y], fill=(4, 4, 7, 255))
    depth = min(int(bottom_y - surface_y), 260)
    for i in range(depth):
        a = int(150 * (1.0 - i / float(depth)))
        d.line([left_x, surface_y + i, left_x + 28, surface_y + i],
               fill=(118, 126, 152, a))
        d.line([right_x - 28, surface_y + i, right_x, surface_y + i],
               fill=(118, 126, 152, a))
    d.rectangle([left_x, surface_y, left_x + 8, surface_y + 30], fill=C_STONE_HI + (255,))
    d.rectangle([right_x - 8, surface_y, right_x, surface_y + 30], fill=C_STONE_HI + (255,))


# ---------------------------------------------------------------------------
# 环境道具（文档【十一】前景：栏杆 / 枯树 / 路灯 / 碎石）
# ---------------------------------------------------------------------------

def draw_dead_tree(d: ImageDraw.ImageDraw, x: float, base_y: float, scale: float = 1.0,
                   color: tuple = C_NEAR) -> None:
    """枯树 —— 全部枝条朝同一个方向弯（文档【十五】：那是火风的方向）。"""
    s = scale
    d.polygon([(x - 9 * s, base_y), (x + 9 * s, base_y),
               (x + 5 * s, base_y - 120 * s), (x - 5 * s, base_y - 120 * s)],
              fill=color + (255,))
    branches = [
        (base_y - 60 * s, -78, 46), (base_y - 84 * s, -62, 40),
        (base_y - 104 * s, -50, 34), (base_y - 46 * s, 58, 40),
        (base_y - 74 * s, 44, 34),
    ]
    for by, dx, dy in branches:
        # 统一向右弯（火风方向）
        end = (x + dx * s, by + dy * s)
        d.line([(x, by), end], fill=color + (255,), width=max(2, int(5 * s)))
        d.line([end, (end[0] + 26 * s, end[1] - 18 * s)],
               fill=color + (255,), width=max(1, int(3 * s)))


def draw_railing(d: ImageDraw.ImageDraw, x0: float, x1: float, y: float,
                 height: float = 96, step: float = 74,
                 color: tuple = C_NEAR) -> None:
    """铁栏杆（前景）。"""
    d.rectangle([x0, y - 12, x1, y], fill=color + (255,))
    d.rectangle([x0, y - height, x1, y - height + 12], fill=color + (255,))
    x = x0
    while x <= x1:
        d.rectangle([x, y - height, x + 7, y], fill=color + (255,))
        x += step


def draw_rubble(d: ImageDraw.ImageDraw, x: float, base_y: float, rng: random.Random,
                color: tuple = C_NEAR) -> None:
    """碎石堆（前景）。"""
    for _ in range(rng.randint(4, 9)):
        rx = x + rng.uniform(-30, 30)
        rw = rng.uniform(8, 26)
        rh = rng.uniform(5, 15)
        d.ellipse([rx, base_y - rh, rx + rw, base_y], fill=color + (255,))


def draw_street_lamp(canvas: Image.Image, x: float, base_y: float,
                     height: float = 250, lit: bool = True,
                     color: tuple = C_NEAR) -> None:
    """路灯（前景），同时是存档点。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    d.rectangle([x - 6, base_y - height, x + 6, base_y], fill=color + (255,))
    d.polygon([(x - 30, base_y - height), (x + 30, base_y - height),
               (x + 22, base_y - height - 34), (x - 22, base_y - height - 34)],
              fill=color + (255,))
    if lit:
        glow(canvas, x, base_y - height - 8, 210, C_AMBER, 0.62)
        d = ImageDraw.Draw(canvas, "RGBA")
        d.ellipse([x - 17, base_y - height - 25, x + 17, base_y - height + 9],
                  fill=C_AMBER + (255,))
        d.ellipse([x - 9, base_y - height - 17, x + 9, base_y - height + 1],
                  fill=(255, 246, 218, 255))


def draw_welcome_sign(canvas: Image.Image, x: float, base_y: float,
                      text: str = "欢迎来到回环镇") -> None:
    """锈迹斑斑的「欢迎来到回环镇」木牌（文档【十一】明确指定）。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    # 两根木柱
    for px in (x - 76, x + 62):
        d.rectangle([px, base_y - 158, px + 14, base_y], fill=(30, 26, 24, 255))
    # 牌面（倾斜，破旧）
    d.polygon([(x - 96, base_y - 190), (x + 96, base_y - 176),
               (x + 92, base_y - 84), (x - 100, base_y - 98)],
              fill=(52, 42, 34, 255))
    d.polygon([(x - 96, base_y - 190), (x + 96, base_y - 176),
               (x + 94, base_y - 168), (x - 97, base_y - 182)],
              fill=(78, 62, 48, 255))
    # 锈斑
    rng = random.Random(3)
    for _ in range(26):
        rx = x + rng.uniform(-92, 88)
        ry = base_y + rng.uniform(-184, -92)
        rr = rng.uniform(3, 11)
        d.ellipse([rx, ry, rx + rr, ry + rr], fill=(104, 58, 32, 190))
    # 字（文档要求牌上就写这句）
    try:
        f = find_font(24)
        tw = d.textlength(text, font=f)
        d.text((x - tw / 2, base_y - 160), text, font=f, fill=(196, 188, 168, 235))
    except Exception:
        pass


def draw_marker(d: ImageDraw.ImageDraw, x: float, y: float, color: tuple) -> None:
    d.polygon([(x, y - 158), (x + 13, y - 143), (x, y - 128), (x - 13, y - 143)],
              fill=color + (255,), outline=(8, 8, 12, 230))


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

def draw_hud(canvas: Image.Image, health_ratio: float = 0.8,
             memory: str = "记忆 2/7", item: str = "居民的信",
             boss: tuple[str, float] | None = None) -> None:
    d = ImageDraw.Draw(canvas, "RGBA")
    r, gap = 16, 44
    for i in range(5):
        cx, cy = 54 + i * gap, 54
        if (i + 1) <= round(health_ratio * 5):
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C_BONE + (255,),
                      outline=C_INK + (240,), width=3)
            d.ellipse([cx - 6, cy - 7, cx + 6, cy + 5], fill=C_INK + (255,))
        else:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(96, 102, 126, 165), width=3)
    tw = d.textlength(memory, font=F_HUD)
    d.text((W - 54 - tw, 40), memory, font=F_HUD, fill=C_WAX + (255,),
           stroke_width=3, stroke_fill=(0, 0, 0, 210))
    d.rectangle([50, H - 98, 306, H - 46], fill=(10, 10, 15, 190),
                outline=(100, 106, 132, 175), width=2)
    d.text((68, H - 88), item, font=F_SMALL, fill=C_BONE + (240,))
    if boss is not None:
        name, ratio = boss
        bw, bh = 780, 22
        bx, by = (W - bw) / 2, H - 112
        d.rectangle([bx - 4, by - 4, bx + bw + 4, by + bh + 4],
                    fill=(8, 8, 12, 205), outline=C_INK + (240,), width=2)
        d.rectangle([bx, by, bx + bw, by + bh], fill=(38, 20, 24, 255))
        d.rectangle([bx, by, bx + bw * ratio, by + bh], fill=C_RED + (255,))
        d.rectangle([bx, by, bx + bw * ratio, by + 6], fill=(206, 92, 100, 255))
        nw = d.textlength(name, font=F_NAME)
        d.text((W / 2 - nw / 2, by - 36), name, font=F_NAME, fill=C_BONE + (240,),
               stroke_width=3, stroke_fill=(0, 0, 0, 215))


def title_card(canvas: Image.Image, title: str, subtitle: str) -> None:
    """左上角的图名 + 文档依据（仅供评审，正式出图删掉）。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    d.rectangle([0, 0, W, 104], fill=(6, 6, 10, 175))
    d.text((54, 22), title, font=F_TITLE, fill=C_BONE + (245,))
    d.text((54, 62), subtitle, font=F_SMALL, fill=(158, 162, 182, 255))


def _note(d: ImageDraw.ImageDraw, x: float, y: float, text: str) -> None:
    tw = d.textlength(text, font=F_NOTE)
    d.line([x, y - 12, x, y - 34], fill=(150, 156, 178, 225), width=2)
    d.line([x, y - 34, x + tw + 18, y - 34], fill=(150, 156, 178, 225), width=2)
    d.rectangle([x, y - 52, x + tw + 18, y - 22], fill=(8, 8, 12, 220))
    d.text((x + 9, y - 47), text, font=F_NOTE, fill=(198, 198, 210, 255))


# ---------------------------------------------------------------------------
# 场景一：Town_Entrance 序幕（文档【十一】逐条落实）
# ---------------------------------------------------------------------------

def scene_town_entrance() -> Image.Image:
    canvas = Image.new("RGBA", (W, H), C_INK + (255,))
    horizon = 690.0
    surface = 838.0
    bottom = float(H)

    # --- 黄昏天空 ---
    draw_dusk_sky(canvas, horizon)

    # --- 远景：巨大钟楼，明显高于所有建筑 ---
    draw_town_skyline(canvas, horizon, "far", 0.8)
    draw_clock_tower(canvas, 1408, 118, horizon + 20, 200)
    # 远景推远
    atmospheric_recede(canvas, 0.7, (104, 96, 124))

    # --- 中景：居民住宅 / 小巷 / 小店 / 旧建筑 ---
    draw_town_skyline(canvas, horizon + 20, "mid", 1.0)
    # 中景推远（比远景轻，形成两层纵深）
    atmospheric_recede(canvas, 0.42, (92, 86, 108))

    # --- 大雾（文档明确要求）---
    draw_fog(canvas, horizon + 10, 1.0, (118, 112, 132), seed=5)
    draw_fog(canvas, horizon - 60, 0.5, (126, 120, 140), seed=17)

    d = ImageDraw.Draw(canvas, "RGBA")

    # --- 地面：向右延伸的道路，中段有小巷缺口 ---
    draw_floor(canvas, 0, 1180, surface, bottom, mossy=True)
    draw_floor(canvas, 1360, W, surface, bottom, mossy=True)
    draw_chasm(canvas, 1180, 1360, surface, bottom)

    # --- 上层支路（通往住宅区的小巷）---
    draw_ledge(canvas, 620, 900, 636, mossy=True)
    draw_ledge(canvas, 1010, 1270, 556, mossy=True)
    draw_ledge(canvas, 1500, 1790, 636, mossy=True)

    # --- 前景：栏杆 / 枯树 / 路灯 / 碎石 ---
    draw_railing(d, 0, 300, surface, 96, 74)
    draw_dead_tree(d, 380, surface, 1.15)
    draw_street_lamp(canvas, 240, surface, 250)
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_rubble(d, 560, surface, random.Random(2))
    draw_dead_tree(d, 1120, surface, 0.85)
    draw_rubble(d, 1620, surface, random.Random(9))
    draw_dead_tree(d, 1810, surface, 1.0)

    # --- 锈木牌（文档指定：「欢迎来到回环镇」）---
    draw_welcome_sign(canvas, 470, surface)

    # --- 信件（第一次进入可拾取）---
    glow(canvas, 880, surface - 190, 76, C_WAX, 0.72)
    paste_feet(canvas, load_sprite(ASSETS / "props/letter.png", scale=2.6), 880, surface - 172)
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_marker(d, 880, surface - 172, C_WAX)

    # --- NPC：灰色镇民，每人一个循环动作 ---
    npc = load_sprite(ASSETS / "enemies/townsman_idle.png", 0, 4, 3.4)
    for x in (760, 1000, 1560, 1760):
        contact_shadow(canvas, x, surface, 72)
        paste_feet(canvas, npc, x, surface)
        draw_marker(d, x, surface, C_SOUL)

    # --- 主角：从左进入，面朝右 ---
    player = load_sprite(ASSETS / "characters/player/player_idle.png", 1, 6, 3.4)
    contact_shadow(canvas, 170, surface, 80)
    rim_light(canvas, player, 170, surface)
    paste_feet(canvas, player, 170, surface)

    vignette(canvas, 0.46)

    d = ImageDraw.Draw(canvas, "RGBA")
    _note(d, 470, surface + 96, "锈木牌「欢迎来到回环镇」")
    _note(d, 880, surface - 96, "信件：请找到小铃，带她回家")
    _note(d, 170, surface + 130, "玩家从左进入")
    _note(d, 1180, surface - 130, "小巷缺口 = 通往住宅区")
    _note(d, 1420, 300, "钟楼：明显高于其他建筑")
    _note(d, 240, surface - 200, "路灯（前景）＝存档点")
    title_card(canvas, "序幕 · 小镇入口  Town_Entrance",
               "文档【十一】：黄昏 / 大雾 / 锈木牌 / 玩家从左进入 / 远处钟楼｜前景栏杆·枯树·路灯·碎石｜中景住宅·小巷·小店")
    return canvas.convert("RGB")


# ---------------------------------------------------------------------------
# 场景二：Town_Hub 小镇 Hub（文档【十二】：环形道路）
# ---------------------------------------------------------------------------

def scene_town_hub() -> Image.Image:
    canvas = Image.new("RGBA", (W, H), C_INK + (255,))
    horizon = 660.0
    surface = 812.0
    bottom = float(H)

    draw_dusk_sky(canvas, horizon)
    draw_town_skyline(canvas, horizon, "far", 0.75)
    atmospheric_recede(canvas, 0.7, (104, 96, 124))

    # 中心：钟楼（Hub 的正中，所有路的归宿）
    draw_clock_tower(canvas, 860, 76, horizon + 40, 230)

    draw_town_skyline(canvas, horizon + 24, "mid", 1.0)
    atmospheric_recede(canvas, 0.42, (92, 86, 108))
    draw_fog(canvas, horizon, 0.72, (108, 104, 126), seed=13)

    d = ImageDraw.Draw(canvas, "RGBA")

    # --- 环形道路：地面高度沿 x 呈拱形，视觉上「两侧翘起、中间下沉」，
    #     形成一圈可绕行的平台，而不是一条直路 ---
    segments = 26
    for i in range(segments):
        x0 = i * (W / segments)
        x1 = (i + 1) * (W / segments) + 2
        t = (i + 0.5) / segments
        # 拱形：两侧高、中间低（离钟楼越近越低）
        bow = (abs(t - 0.5) * 2.0) ** 1.5
        y = surface - bow * 172
        draw_floor(canvas, x0, x1, y, bottom, mossy=(i % 3 == 0))

    # 环路的两个「开口」：左通蜡像巷，右通剧院
    draw_floor(canvas, 0, 150, surface - 172, bottom)

    # 上层环廊
    draw_ledge(canvas, 330, 620, 470, mossy=True)
    draw_ledge(canvas, 1300, 1590, 470, mossy=True)

    # NPC：5~8 个，各自循环动作（抱孩子 / 提水桶 / 擦窗 / 看钟 / 弯腰 / 伸手）
    npc = load_sprite(ASSETS / "enemies/townsman_idle.png", 0, 4, 3.4)
    actions = ["抱孩子", "提水桶", "擦窗", "看钟", "弯腰", "伸手", "提水桶"]
    hubs = [220, 420, 640, 1080, 1300, 1520, 1740]
    for i, x in enumerate(hubs):
        y = surface - ((abs((x / W) - 0.5) * 2.0) ** 1.5) * 172
        contact_shadow(canvas, x, y, 72)
        paste_feet(canvas, npc, x, y, flip=(i % 2 == 1))
        draw_marker(d, x, y, C_SOUL)
        _note(d, x, y + 76, actions[i % len(actions)])

    # 公告栏上的 247
    glow(canvas, 1000, surface - 300, 70, C_WAX, 0.6)
    paste_feet(canvas, load_sprite(ASSETS / "props/letter.png", scale=2.4), 1000, surface - 286)
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_marker(d, 1000, surface - 286, C_WAX)

    # 主角
    player = load_sprite(ASSETS / "characters/player/player_idle.png", 0, 6, 3.4)
    contact_shadow(canvas, 780, surface - 24, 80)
    rim_light(canvas, player, 780, surface - 24)
    paste_feet(canvas, player, 780, surface - 24)

    vignette(canvas, 0.46)

    d = ImageDraw.Draw(canvas, "RGBA")
    _note(d, 250, surface + 120, "道路呈拱形：两侧翘起、中心下沉 = 环形感")
    _note(d, 960, 250, "钟楼在正中心：所有路的归宿")
    _note(d, 1600, 560, "上层环廊 = 另一圈可绕行的路")
    _note(d, 130, surface - 210, "左开口 → 蜡像巷")
    title_card(canvas, "小镇 Hub  Town_Hub",
               "文档【十二】：左蜡像巷・右剧院・下枯井・中心钟楼｜5~8 个 NPC 各有循环动作｜道路必须体现完美圆环")
    return canvas.convert("RGB")


# ---------------------------------------------------------------------------
# 场景三：蜡像巷（文档【十三】：结构 + 视觉）
# ---------------------------------------------------------------------------

def scene_wax_lane() -> Image.Image:
    canvas = Image.new("RGBA", (W, H), C_INK + (255,))
    horizon = 700.0
    surface = 840.0
    bottom = float(H)

    # 蜡像巷是室内感的街巷：天空更暗，暖黄灯为主光源
    d = ImageDraw.Draw(canvas, "RGBA")
    for y in range(int(horizon) + 60):
        t = y / max(horizon, 1.0)
        v = int(20 + 26 * t)
        d.line([0, y, W, y], fill=(v, int(v * 0.9), int(v * 1.08), 255))

    # 远景：两侧墙 + 拱（街巷是被夹着的走廊）
    for i in range(-40, W + 200, 196):
        d.rectangle([i + 30, 250, i + 96, horizon + 60], fill=(38, 36, 46, 255))
        d.arc([i - 10, 150, i + 136, 380], 180, 360, fill=(38, 36, 46, 255), width=7)
    for y in range(250, int(horizon) + 60, 52):
        d.line([0, y, W, y], fill=(32, 30, 40, 255), width=3)
    # 背景墙推远（蜡像巷是室内走廊，纵深靠这层膜拉开）
    atmospheric_recede(canvas, 0.5, (74, 66, 84))

    draw_fog(canvas, horizon - 40, 0.42, (96, 88, 104), seed=21)
    d = ImageDraw.Draw(canvas, "RGBA")

    # --- 结构（文档）：入口 → 蜡像街 → 小型战斗区 → 追逐区 → 蜡像馆 ---
    # 入口段
    draw_floor(canvas, 0, 430, surface, bottom)
    # 蜡像街（抬升的走道）
    draw_floor(canvas, 430, 880, surface - 96, bottom)
    # 战斗区（下沉的广场，给战斗留空间）
    draw_floor(canvas, 1000, 1420, surface + 24, bottom)
    # 追逐区（长而窄，中间断开 —— 需要跳）
    draw_floor(canvas, 1420, 1720, surface - 60, bottom)
    draw_chasm(canvas, 1720, 1830, surface - 60, bottom)
    draw_floor(canvas, 1830, W, surface - 60, bottom)

    # 通向蜡像馆的门（右侧）
    d.rectangle([1852, surface - 300, 1920, surface - 60], fill=(26, 24, 32, 255))
    d.arc([1796, surface - 380, 1912, surface - 236], 180, 360, fill=(44, 40, 50, 255),
          width=9)

    # 悬空平台（追逐区的路线）
    draw_ledge(canvas, 700, 950, 606, mossy=True)
    draw_ledge(canvas, 1150, 1380, 520, mossy=True)
    draw_ledge(canvas, 1520, 1760, 606, mossy=True)

    # --- 蜡像（文档：所有路边都有蜡像；部分转头、眼睛跟随）---
    statues = [load_sprite(ASSETS / f"props/wax_statue_{k}.png", scale=3.0)
               for k in ("a", "b", "c")]
    spots = [
        (110, surface, 0, False), (300, surface, 1, True),
        (500, surface - 96, 2, False), (660, surface - 96, 0, True),
        (820, surface - 96, 1, False), (1080, surface + 24, 2, True),
        (1240, surface + 24, 0, False), (1380, surface + 24, 1, True),
        (1490, surface - 60, 2, False), (1620, surface - 60, 0, True),
        (1800, surface - 60, 1, False), (1880, surface - 60, 2, True),
    ]
    for i, (x, y, pose, watching) in enumerate(spots):
        contact_shadow(canvas, x, y, 56, alpha=105)
        # 蜡像本体压暗：它们是「记忆的截面」，不该比主角更亮
        statue = statues[pose]
        if statue is not None:
            dim = Image.new("RGBA", statue.size, (150, 138, 112, 255))
            dim.putalpha(statue.split()[3])
            statue = Image.blend(statue, dim, 0.34)
        paste_feet(canvas, statue, x, y)
        # 只有被灯照到的蜡像才有一点暖光，其余融进阴影
        if i % 3 == 0:
            glow(canvas, x, y - 96, 108, C_WAX, 0.09)
        d = ImageDraw.Draw(canvas, "RGBA")
        # 眼睛：转头的蜡像眼睛朝街心（暖黄），其余暗
        eye = C_AMBER if watching else (78, 68, 52)
        d.ellipse([x - 3, y - 118, x + 3, y - 112], fill=eye + (200,))

    # 战斗单位（文档：WaxDummy，缓慢接近 / 挥拳 / 跳扑 / 假人包围）
    dummy = load_sprite(ASSETS / "enemies/wax_dummy_idle.png", 0, 4, 3.6)
    for x, y in ((1160, surface + 24), (1340, surface + 24), (1660, surface - 60)):
        contact_shadow(canvas, x, y, 78)
        paste_feet(canvas, dummy, x, y)
        draw_marker(d, x, y, C_RED)

    # 玻璃 / 镜子（文档视觉要素：玻璃、镜子）
    for mx, my in ((760, 496), (1620, 340)):
        glow(canvas, mx, my, 78, C_GLASS, 0.42)
        paste_feet(canvas, load_sprite(ASSETS / "props/mirror.png", scale=3.0), mx, my + 92)
        d = ImageDraw.Draw(canvas, "RGBA")
        draw_marker(d, mx, my + 92, C_SOUL)

    # 主角
    sprite = load_sprite(ASSETS / "characters/player/player_run.png", 3, 8, 3.4)
    contact_shadow(canvas, 950, surface + 24, 80)
    rim_light(canvas, sprite, 950, surface + 24)
    paste_feet(canvas, sprite, 950, surface + 24)

    vignette(canvas, 0.54)

    d = ImageDraw.Draw(canvas, "RGBA")
    _note(d, 200, surface + 110, "入口")
    _note(d, 620, surface - 150, "蜡像街：路边全是蜡像")
    _note(d, 1180, surface + 160, "小型战斗区：下沉广场")
    _note(d, 1560, surface - 10, "追逐区：断开，必须跳")
    _note(d, 1860, surface - 350, "→ 蜡像馆")
    _note(d, 760, 452, "镜子 / 玻璃（视觉要素）")
    title_card(canvas, "第一章 · 蜡像巷  WaxLane",
               "文档【十三】：入口→蜡像街→小型战斗区→追逐区→蜡像馆｜蜡·暖黄灯·暗红·黑阴影·玻璃·镜子·人形轮廓")
    return canvas.convert("RGB")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, builder in (("01_town_entrance", scene_town_entrance),
                          ("02_town_hub", scene_town_hub),
                          ("03_wax_lane", scene_wax_lane)):
        img = builder()
        img.save(OUT_DIR / f"{name}.png")
        print(f"  wrote docs/mockups/{name}.png  {img.width}x{img.height}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
