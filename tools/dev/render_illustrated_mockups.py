"""关卡效果图渲染器 —— 以《空洞骑士》式插画与 HUD 为目标。

参考图里我原先缺失的三样结构性东西（这一版补齐）：
  1. **完整 HUD 系统**：不只在角落放三个小图标，而是
     生命容器（带装饰外框）+ 能量/火焰容器 + 灵魂球 + 道具槽（带数量）
     + 底部装饰装备槽（带名称）+ 顶部章节名与 Boss 名条 + 底部黑条
  2. **插画级三层纵深**：前景实物压边（齿轮/藤蔓/木梁）+ 中景玩法平台
     + 背景巨大透光图案（钟面/彩窗），并且每层有独立的明度与饱和
  3. **主角识别度**：高尖帽 + 发光核心（参考图里最亮的是角色身上的球体）

配色参考：钟楼＝赤红/火橙；剧院＝青绿/暗红；都是「环境色单一但极饱和」，
主角用冷色高光对比。

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

C_INK = (8, 7, 10)
C_BONE = (232, 226, 212)
C_DARK = (26, 22, 26)

# 钟楼配色：赤红 / 火橙（参考图一）—— 压暗、加深，把亮度留给钟面与主角
TOWER_DEEP = (38, 10, 16)
TOWER_MID = (78, 20, 22)
TOWER_HOT = (150, 52, 24)
TOWER_GLOW = (236, 148, 62)
C_BRASS = (150, 108, 46)
C_BRASS_HI = (216, 176, 98)

# 剧院配色：青绿 / 暗红（参考图二）
TH_DRAPE = (86, 20, 32)
TH_WALL = (46, 52, 56)
TH_MIST = (96, 138, 142)
TH_FLAME = (78, 206, 196)
TH_BLOOD = (150, 38, 44)
C_RED_THREAD = (196, 40, 44)

C_SOUL = (150, 224, 236)
C_HP = (222, 216, 200)


def find_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = (r"C:\Windows\Fonts\msyhbd.ttc", r"C:\Windows\Fonts\msyh.ttc",
             r"C:\Windows\Fonts\simhei.ttf") if bold else (
        r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf")
    for path in names:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


F_CHAPTER = find_font(28, True)
F_BOSS = find_font(26, True)
F_LABEL = find_font(19)
F_SMALL = find_font(17)
F_TINY = find_font(15)
F_NUM = find_font(17, True)
F_FOOT = find_font(15)


# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------

def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1: tuple, c2: tuple, t: float) -> tuple:
    return (int(lerp(c1[0], c2[0], t)), int(lerp(c1[1], c2[1], t)),
            int(lerp(c1[2], c2[2], t)))


def glow(canvas: Image.Image, x: float, y: float, radius: float, color: tuple,
         strength: float = 0.55, steps: int = 10) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(255 * strength * (1.0 - i / (steps + 1.6)))
        d.ellipse([x - r, y - r, x + r, y + r], fill=color + (a,))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.2)))


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
                   alpha: int = 150) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        [x - width / 2, feet_y - 9, x + width / 2, feet_y + 9], fill=(0, 0, 0, alpha))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(8)))


def rim_light(canvas: Image.Image, sprite: Image.Image | None, x: float, feet_y: float,
              color: tuple = (255, 240, 200), width: int = 3, alpha: int = 165) -> None:
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


def vignette(canvas: Image.Image, strength: float = 0.6) -> None:
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([-W * 0.18, -H * 0.24, W * 1.18, H * 1.24], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(210))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    dark.putalpha(ImageChops.invert(mask).point(lambda v: int(v * strength)))
    canvas.alpha_composite(dark)


def grain(canvas: Image.Image, amount: int = 9, seed: int = 3) -> None:
    """极轻的颗粒，制造手绘质感（参考图都有这个）。"""
    rng = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = layer.load()
    for _ in range(W * H // 26):
        x, y = rng.randrange(W), rng.randrange(H)
        v = rng.randint(0, 255)
        px[x, y] = (v, v, v, amount)
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.6)))


# ---------------------------------------------------------------------------
# 插画级背景：巨钟 / 彩窗 / 齿轮 / 幕布
# ---------------------------------------------------------------------------

def draw_giant_clock(canvas: Image.Image, cx: float, cy: float, r: float,
                     alpha: int = 120, roman: bool = True) -> None:
    """背景巨大钟面透光 —— 参考图一的核心元素。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    # 光晕（透过钟面的强光）
    glow(canvas, cx, cy, r * 1.9, TOWER_GLOW, 0.3)
    d = ImageDraw.Draw(canvas, "RGBA")
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TOWER_GLOW + (alpha,))
    d.ellipse([cx - r * 0.94, cy - r * 0.94, cx + r * 0.94, cy + r * 0.94],
              fill=mix(TOWER_GLOW, (255, 236, 190), 0.5) + (alpha,))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=TOWER_MID + (200,), width=9)
    d.ellipse([cx - r * 1.1, cy - r * 1.1, cx + r * 1.1, cy + r * 1.1],
              outline=TOWER_MID + (140,), width=5)
    # 刻度
    for i in range(12):
        ang = math.radians(i * 30 - 90)
        x0 = cx + math.cos(ang) * r * 0.78
        y0 = cy + math.sin(ang) * r * 0.78
        x1 = cx + math.cos(ang) * r * 0.9
        y1 = cy + math.sin(ang) * r * 0.9
        w = 7 if i % 3 == 0 else 4
        d.line([x0, y0, x1, y1], fill=TOWER_DEEP + (210,), width=w)
    # 指针（指向某个「被停住的时刻」）
    d.line([cx, cy, cx + r * 0.12, cy - r * 0.62], fill=TOWER_DEEP + (225,), width=11)
    d.line([cx, cy, cx + r * 0.5, cy + r * 0.18], fill=TOWER_DEEP + (225,), width=9)
    d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=TOWER_MID + (240,))


def draw_gear(canvas: Image.Image, cx: float, cy: float, r: float, teeth: int = 18,
              body: tuple = (58, 38, 24), alpha: int = 255, tooth: float = 0.24,
              rotation: float = 0.0) -> None:
    """巨大齿轮 —— 参考图一的前景压边元素。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    col = body + (alpha,)
    # 齿
    for i in range(teeth):
        a0 = math.radians(rotation + i * 360.0 / teeth - (360.0 / teeth) * tooth / 2)
        a1 = math.radians(rotation + i * 360.0 / teeth + (360.0 / teeth) * tooth / 2)
        p = [(cx + math.cos(a0) * r * 0.96, cy + math.sin(a0) * r * 0.96),
             (cx + math.cos(a0) * r * 1.16, cy + math.sin(a0) * r * 1.16),
             (cx + math.cos(a1) * r * 1.16, cy + math.sin(a1) * r * 1.16),
             (cx + math.cos(a1) * r * 0.96, cy + math.sin(a1) * r * 0.96)]
        d.polygon(p, fill=col)
    # 轮体
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col,
              outline=mix(body, (255, 220, 170), 0.35) + (alpha,), width=6)
    d.ellipse([cx - r * 0.78, cy - r * 0.78, cx + r * 0.78, cy + r * 0.78],
              fill=mix(body, (0, 0, 0), 0.35) + (alpha,))
    # 辐条
    for i in range(8):
        ang = math.radians(rotation + i * 45)
        d.line([(cx + math.cos(ang) * r * 0.24, cy + math.sin(ang) * r * 0.24),
                (cx + math.cos(ang) * r * 0.74, cy + math.sin(ang) * r * 0.74)],
               fill=mix(body, (255, 220, 170), 0.22) + (alpha,), width=14)
    d.ellipse([cx - r * 0.22, cy - r * 0.22, cx + r * 0.22, cy + r * 0.22],
              fill=mix(body, (255, 220, 170), 0.4) + (alpha,))


def draw_stained_glass(canvas: Image.Image, cx: float, cy: float, r: float,
                       alpha: int = 130) -> None:
    """彩窗透光 —— 参考图二的背景元素。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    glow(canvas, cx, cy, r * 1.6, TH_MIST, 0.26)
    d = ImageDraw.Draw(canvas, "RGBA")
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TH_MIST + (alpha,))
    for i in range(6):
        ang = math.radians(i * 60)
        d.line([cx, cy, cx + math.cos(ang) * r * 0.92, cy + math.sin(ang) * r * 0.92],
               fill=(28, 34, 38, 210), width=8)
    d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3],
              fill=mix(TH_MIST, (255, 255, 255), 0.4) + (alpha,))


def draw_curtain(canvas: Image.Image, x0: float, width: float, color: tuple,
                 folds: int = 7) -> None:
    """剧院幕布（参考图二顶部）。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    d.rectangle([x0, 0, x0 + width, 300], fill=color + (255,))
    for i in range(folds):
        fx = x0 + width * i / folds
        d.polygon([(fx, 0), (fx + width / folds * 0.5, 0),
                   (fx + width / folds * 0.34, 300), (fx - width / folds * 0.16, 300)],
                  fill=mix(color, (255, 255, 255), 0.12) + (255,))
    d.arc([x0 - 120, 180, x0 + width + 120, 520], 0, 180,
          fill=mix(color, (0, 0, 0), 0.3) + (255,), width=26)


def draw_vines(canvas: Image.Image, seed: int = 4, color: tuple = (12, 10, 14),
               count: int = 3, alpha: int = 255) -> None:
    """前景藤蔓 / 尖刺压边（参考图两边的黑色剪影）。

    用光滑曲线 + 逐渐变细的锥形枝，而不是折线加三角刺 ——
    折线加三角会读成「锯齿」，反而分散注意、显得廉价。
    """
    d = ImageDraw.Draw(canvas, "RGBA")
    rng = random.Random(seed)
    col = color + (alpha,)
    for side in ("left", "right"):
        base_x = -30 if side == "left" else W + 30
        direction = 1 if side == "left" else -1
        for k in range(count):
            px, py = base_x, rng.uniform(320, H - 60) + k * 70
            pts = [(px, py)]
            for _ in range(8):
                px += direction * rng.uniform(34, 86)
                py += rng.uniform(-42, 42)
                pts.append((px, py))
            # 主干：由粗到细（画多段不同宽度，形成锥形）
            for i in range(len(pts) - 1):
                t = i / float(len(pts) - 1)
                w = int(26 * (1.0 - t) + 5)
                d.line([pts[i], pts[i + 1]], fill=col, width=w)
            # 叶片：小椭圆而不是三角尖刺
            for i in range(1, len(pts) - 1):
                if rng.random() < 0.65:
                    sx, sy = pts[i]
                    lw = rng.uniform(20, 40)
                    lh = rng.uniform(10, 18)
                    d.ellipse([sx - lw / 2, sy - lh / 2, sx + lw / 2, sy + lh / 2], fill=col)


# ---------------------------------------------------------------------------
# 完整的 HUD —— 这是本次补齐的重点
# ---------------------------------------------------------------------------

def draw_ornate_frame(d: ImageDraw.ImageDraw, box: tuple, fill: tuple, alpha: int = 210,
                      accent: tuple = C_BRASS_HI) -> None:
    """装饰外框：双层描边 + 四角铆钉，模仿参考图的金属框。"""
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0, y0, x1, y1], radius=10, fill=fill + (alpha,),
                        outline=accent + (200,), width=3)
    d.rounded_rectangle([x0 + 5, y0 + 5, x1 - 5, y1 - 5], radius=7,
                        outline=mix(accent, (0, 0, 0), 0.55) + (170,), width=2)
    for cx, cy in ((x0 + 13, y0 + 13), (x1 - 13, y0 + 13),
                   (x0 + 13, y1 - 13), (x1 - 13, y1 - 13)):
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=accent + (230,))


def draw_health_bar(canvas: Image.Image, x: float, y: float, filled: int = 6,
                    total: int = 7, height: float = 56.0) -> float:
    """生命：一排面具容器，装在一个装饰金属框里（参考图左上）。

    返回右边界 x，便于调用方把下一个元件接在它旁边而不是叠上去。
    """
    d = ImageDraw.Draw(canvas, "RGBA")
    gap = 40.0
    r = 15.0
    bw = total * gap + 22
    draw_ornate_frame(d, (x, y, x + bw, y + height), (22, 18, 20))

    for i in range(total):
        cx = x + 22 + i * gap
        cy = y + height / 2
        if i < filled:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C_HP + (255,),
                      outline=(58, 48, 40, 255), width=3)
            d.ellipse([cx - 6, cy - 6, cx - 1, cy + 1], fill=(30, 26, 26, 255))
            d.ellipse([cx + 1, cy - 6, cx + 6, cy + 1], fill=(30, 26, 26, 255))
            d.arc([cx - 5, cy + 2, cx + 5, cy + 10], 0, 180, fill=(30, 26, 26, 255), width=2)
        else:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(34, 30, 32, 220),
                      outline=(74, 66, 62, 200), width=3)
    return x + bw


def draw_soul_vessel(canvas: Image.Image, cx: float, cy: float, radius: float = 42.0,
                     soul_ratio: float = 0.72, flame: bool = False) -> None:
    """灵魂/火焰容器：圆形金属框 + 内部液体（参考图左上大圆）。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    r = radius
    d.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=(20, 17, 18, 235),
              outline=C_BRASS_HI + (215,), width=4)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(12, 14, 18, 255),
              outline=mix(C_BRASS, (0, 0, 0), 0.4) + (220,), width=3)

    lr = r - 8
    if flame:
        d.ellipse([cx - lr, cy - lr, cx + lr, cy + lr], fill=(48, 22, 10, 255))
        glow(canvas, cx, cy, lr * 1.4, (255, 148, 58), 0.65)
        d = ImageDraw.Draw(canvas, "RGBA")
        for i in range(6):
            rr = lr * (1.0 - i / 8.0)
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                      fill=mix((170, 56, 18), (255, 228, 156), i / 5.0) + (65,))
    else:
        # 液体从底部往上涨
        mask = Image.new("L", (W, H), 0)
        md = ImageDraw.Draw(mask)
        md.ellipse([cx - lr, cy - lr, cx + lr, cy + lr], fill=255)
        liquid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(liquid)
        top = cy + lr - 2 * lr * soul_ratio
        ld.ellipse([cx - lr, top - lr * 0.4, cx + lr, cy + lr * 1.4],
                   fill=(132, 220, 238, 235))
        ld.ellipse([cx - lr * 0.6, top, cx + lr * 0.6, top + lr * 0.7],
                   fill=(196, 244, 252, 190))
        liquid.putalpha(ImageChops.multiply(liquid.split()[3], mask))
        canvas.alpha_composite(liquid)


def draw_item_slots(canvas: Image.Image, x: float, y: float,
                    items: list[tuple[str, int]] | None = None) -> None:
    """左侧道具槽（参考图左中的两个圆形槽，带数量）。"""
    if items is None:
        items = [("button", 2), ("rag_doll", 1)]
    d = ImageDraw.Draw(canvas, "RGBA")
    for i, (icon_name, count) in enumerate(items):
        cx, cy = x + i * 92, y
        r = 34
        d.ellipse([cx - r - 5, cy - r - 5, cx + r + 5, cy + r + 5],
                  fill=(20, 17, 18, 230), outline=C_BRASS_HI + (200,), width=3)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(30, 32, 40, 255))
        icon = load_sprite(ASSETS / f"props/{icon_name}.png", scale=1.7)
        if icon is not None:
            canvas.alpha_composite(icon, (int(cx - icon.width / 2), int(cy - icon.height / 2)))
        d = ImageDraw.Draw(canvas, "RGBA")
        # 数量
        d.text((cx + r - 12, cy + r - 22), str(count), font=F_NUM,
               fill=C_BONE + (255,), stroke_width=3, stroke_fill=(0, 0, 0, 230))


def draw_equip_slots(canvas: Image.Image,
                     slots: list[tuple[str, str]] | None = None) -> None:
    """右下角装饰装备槽 + 名称（参考图右下两格）。"""
    if slots is None:
        slots = [("notebook", "发光的笔记本"), ("big_scissors", "大剪刀")]
    d = ImageDraw.Draw(canvas, "RGBA")
    size = 132
    gap = 22
    total_w = len(slots) * size + (len(slots) - 1) * gap
    x0 = W - 54 - total_w
    y0 = H - 54 - size

    for i, (icon_name, label) in enumerate(slots):
        bx = x0 + i * (size + gap)
        draw_ornate_frame(d, (bx, y0, bx + size, y0 + size), (18, 16, 18), 235)
        icon = load_sprite(ASSETS / f"props/{icon_name}.png", scale=3.2)
        if icon is not None:
            canvas.alpha_composite(
                icon, (int(bx + size / 2 - icon.width / 2),
                       int(y0 + size / 2 - icon.height / 2 + 6)))
            d = ImageDraw.Draw(canvas, "RGBA")
        tw = d.textlength(label, font=F_LABEL)
        d.text((bx + size / 2 - tw / 2, y0 + size + 8), label, font=F_LABEL,
               fill=C_BONE + (245,), stroke_width=3, stroke_fill=(0, 0, 0, 235))


def draw_boss_banner(canvas: Image.Image, chapter: str, boss: str,
                     ratio: float = 0.6, sub: str = "") -> None:
    """顶部：章节名 + Boss 名 + 分段血条（参考图两版的顶部）。"""
    d = ImageDraw.Draw(canvas, "RGBA")

    # 章节名（居中，两侧短线）
    tw = d.textlength(chapter, font=F_CHAPTER)
    cx = W / 2
    d.text((cx - tw / 2, 22), chapter, font=F_CHAPTER, fill=C_BONE + (250,),
           stroke_width=4, stroke_fill=(0, 0, 0, 240))
    d.line([cx - tw / 2 - 90, 40, cx - tw / 2 - 16, 40], fill=C_BRASS_HI + (200,), width=3)
    d.line([cx + tw / 2 + 16, 40, cx + tw / 2 + 90, 40], fill=C_BRASS_HI + (200,), width=3)

    # Boss 血条（带装饰端头 + 分段刻线）
    bw, bh = 760, 26
    bx, by = cx - bw / 2, 68
    d.rectangle([bx - 6, by - 6, bx + bw + 6, by + bh + 6], fill=(16, 14, 16, 225),
                outline=mix(C_BRASS, (0, 0, 0), 0.3) + (220,), width=3)
    d.rectangle([bx, by, bx + bw, by + bh], fill=(38, 20, 22, 255))
    d.rectangle([bx, by, bx + bw * ratio, by + bh], fill=(178, 44, 44, 255))
    d.rectangle([bx, by, bx + bw * ratio, by + 7], fill=(226, 96, 84, 255))
    # 分段刻线
    for i in range(1, 6):
        sx = bx + bw * i / 6.0
        d.line([sx, by, sx, by + bh], fill=(16, 14, 16, 190), width=3)
    # 两端装饰
    for ex in (bx - 6, bx + bw + 6):
        d.polygon([(ex - 12, by + bh / 2), (ex, by - 12), (ex + 12, by + bh / 2),
                   (ex, by + bh + 12)], fill=mix(C_BRASS, (0, 0, 0), 0.45) + (230,))

    # Boss 名
    nw = d.textlength(boss, font=F_BOSS)
    d.text((cx - nw / 2, by + bh + 14), boss, font=F_BOSS, fill=C_BONE + (245,),
           stroke_width=4, stroke_fill=(0, 0, 0, 235))
    if sub:
        sw = d.textlength(sub, font=F_SMALL)
        d.text((cx - sw / 2, by + bh + 50), sub, font=F_SMALL, fill=(190, 180, 172, 240),
               stroke_width=3, stroke_fill=(0, 0, 0, 220))


def draw_footer(canvas: Image.Image, text: str = "Godot Engine v4.6.3 · 回环镇项目") -> None:
    d = ImageDraw.Draw(canvas, "RGBA")
    d.rectangle([0, H - 30, W, H], fill=(6, 6, 8, 210))
    tw = d.textlength(text, font=F_FOOT)
    d.text((W / 2 - tw / 2, H - 24), text, font=F_FOOT, fill=(150, 148, 156, 235))


def draw_damage_number(canvas: Image.Image, x: float, y: float, value: int) -> None:
    """浮动伤害数字（参考图二里的 145）。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    text = str(value)
    f = find_font(52, True)
    tw = d.textlength(text, font=f)
    d.text((x - tw / 2, y), text, font=f, fill=C_BONE + (250,),
           stroke_width=5, stroke_fill=(20, 8, 8, 240))


def draw_interact_hint(canvas: Image.Image, x: float, y: float) -> None:
    """可交互物上方的按键提示（参考图的做法）。"""
    d = ImageDraw.Draw(canvas, "RGBA")
    r = 20
    d.ellipse([x - r, y - r, x + r, y + r], fill=(18, 16, 18, 225),
              outline=C_BRASS_HI + (220,), width=3)
    f = find_font(19, True)
    tw = d.textlength("E", font=f)
    d.text((x - tw / 2, y - 13), "E", font=f, fill=C_BONE + (250,))


# ---------------------------------------------------------------------------
# 场景一：第四章 钟楼心脏（对应参考图一）
# ---------------------------------------------------------------------------

def scene_clocktower() -> Image.Image:
    canvas = Image.new("RGBA", (W, H), C_INK + (255,))
    rng = random.Random(71)

    # --- 背景：赤红渐层 + 三个巨大钟面透光 ---
    d = ImageDraw.Draw(canvas, "RGBA")
    for y in range(H):
        t = min(y / float(H), 1.0)
        col = mix(TOWER_DEEP, TOWER_MID, t ** 0.7)
        d.line([0, y, W, y], fill=col + (255,))
    for cx, cy, r in ((230, 250, 190), (1210, 200, 240), (760, 420, 165),
                      (1720, 460, 150)):
        draw_giant_clock(canvas, cx, cy, r, alpha=62)
    # 让背景整体退后：一层暗红薄雾
    atmospheric = Image.new("RGBA", (W, H), (56, 12, 18, 78))
    canvas.alpha_composite(atmospheric)

    # 背景齿轮（大、暗、慢 —— 靠对比制造纵深）
    for cx, cy, r, rot in ((250, 880, 330, 12), (1680, 900, 300, 30), (980, 1010, 250, 6)):
        draw_gear(canvas, cx, cy, r, teeth=20, body=(52, 30, 20), alpha=210,
                  rotation=rot)

    # --- 钟楼内部结构：木梁 + 竖柱 ---
    d = ImageDraw.Draw(canvas, "RGBA")
    for bx in (0, 470, 940, 1410, 1880):
        d.rectangle([bx, 0, bx + 56, H], fill=(38, 22, 18, 230))
        d.rectangle([bx, 0, bx + 14, H], fill=(64, 38, 26, 220))
    for by in (150, 640):
        d.rectangle([0, by, W, by + 34], fill=(34, 20, 16, 200))

    # --- 玩法平面：木制平台 + 黄铜齿条（参考图的齿条地板）---
    surface = 812.0
    d.rectangle([0, surface, W, H], fill=(44, 26, 20, 255))
    d.rectangle([0, surface, W, surface + 13], fill=C_BRASS + (240,))
    d.rectangle([0, surface, W, surface + 5], fill=C_BRASS_HI + (250,))
    # 齿条
    for i in range(0, W, 56):
        d.polygon([(i + 10, surface + 13), (i + 46, surface + 13),
                   (i + 40, surface + 44), (i + 16, surface + 44)],
                  fill=(96, 66, 30, 235))
    d.rectangle([0, surface + 44, W, H], fill=(28, 17, 13, 255))
    for i in range(0, W, 96):
        d.line([i, surface + 44, i, H], fill=(22, 13, 10, 225), width=4)

    # 台阶式上层平台（垂直关卡的读法）
    for x0, x1, y in ((330, 700, 640), (1080, 1450, 604), (1560, 1880, 660)):
        d.rectangle([x0, y, x1, y + 40], fill=(48, 28, 20, 255))
        d.rectangle([x0, y, x1, y + 9], fill=C_BRASS_HI + (235,))
        for i in range(int(x0) + 16, int(x1), 48):
            d.polygon([(i, y + 40), (i + 30, y + 40), (i + 24, y + 62), (i + 6, y + 62)],
                      fill=(90, 60, 28, 230))

    # --- 巨大传动齿轮（中景偏右，不占画面正中）---
    draw_gear(canvas, 1230, 720, 168, teeth=16, body=(78, 50, 24), alpha=245, rotation=9)

    # --- 角色 ---
    keeper = load_sprite(ASSETS / "enemies/morris_idle.png", 0, 4, 2.4)
    contact_shadow(canvas, 1390, surface - 44, 110)
    if keeper is not None:
        tint = Image.new("RGBA", keeper.size, (30, 24, 32, 255))
        tint.putalpha(keeper.split()[3])
        dark_keeper = Image.blend(keeper, tint, 0.58)
        paste_feet(canvas, dark_keeper, 1390, surface - 44)
        glow(canvas, 1390 - 24, surface - 248, 22, (216, 58, 48), 0.8)
        d = ImageDraw.Draw(canvas, "RGBA")

    # 跳舞的木偶（背景两个小人，明显更小更暗，形成大小对比）
    for x, y, sc in ((1610, surface - 62, 1.7), (1760, surface - 62, 1.9)):
        pup = load_sprite(ASSETS / "enemies/townsman_idle.png", 0, 4, sc)
        if pup is not None:
            dim = Image.new("RGBA", pup.size, (26, 22, 30, 255))
            dim.putalpha(pup.split()[3])
            paste_feet(canvas, Image.blend(pup, dim, 0.5), x, y)

    # 主角：尖帽剪影 + 发光核心
    player = load_sprite(ASSETS / "characters/player/player_idle.png", 0, 6, 3.4)
    contact_shadow(canvas, 720, surface, 86)
    rim_light(canvas, player, 720, surface, (255, 232, 190), 3, 150)
    paste_feet(canvas, player, 720, surface)
    if player is not None:
        # 发光核心（参考图里角色身上最亮的球体）
        core_x, core_y = 720 - 10, surface - 152
        glow(canvas, core_x, core_y, 92, C_SOUL, 0.95)
        d = ImageDraw.Draw(canvas, "RGBA")
        d.ellipse([core_x - 22, core_y - 22, core_x + 22, core_y + 22],
                  fill=(232, 250, 255, 255))
        d.ellipse([core_x - 12, core_y - 12, core_x + 12, core_y + 12],
                  fill=(255, 255, 255, 255))

    # 飞舞的牌（参考图里的纸牌细节）
    d = ImageDraw.Draw(canvas, "RGBA")
    for _ in range(10):
        px, py = rng.uniform(200, 1700), rng.uniform(400, 900)
        d.rectangle([px, py, px + 22, py + 32], fill=(216, 205, 188, 200))
        d.line([px + 11, py + 6, px + 11, py + 26], fill=(160, 40, 44, 200), width=2)

    # --- 前景：齿轮齿 + 藤蔓压边 ---
    draw_gear(canvas, 120, 1030, 300, teeth=22, body=(34, 20, 14), alpha=255)
    draw_gear(canvas, 1820, 1010, 280, teeth=20, body=(34, 20, 14), alpha=255)
    draw_vines(canvas, seed=8, count=3)

    vignette(canvas, 0.62)
    grain(canvas, 10, 5)

    # --- HUD ---
    hb_right = draw_health_bar(canvas, 46, 40, filled=3, total=7)
    draw_soul_vessel(canvas, hb_right + 62, 68, radius=40, flame=True)
    draw_item_slots(canvas, 92, 240)
    draw_equip_slots(canvas)
    draw_boss_banner(canvas, "第四章 · 钟楼的心脏", "钟楼看守", 0.62,
                     "Chapter 4 · Clocktower Heart")
    draw_footer(canvas)
    return canvas.convert("RGB")


# ---------------------------------------------------------------------------
# 场景二：第二章 旧剧院（对应参考图二）
# ---------------------------------------------------------------------------

def scene_theater() -> Image.Image:
    canvas = Image.new("RGBA", (W, H), C_INK + (255,))
    rng = random.Random(19)

    d = ImageDraw.Draw(canvas, "RGBA")
    for y in range(H):
        t = min(y / float(H), 1.0)
        d.line([0, y, W, y], fill=mix((24, 30, 34), TH_WALL, t ** 0.8) + (255,))

    # 背景彩窗 + 冷色火光
    for cx, cy, r in ((180, 300, 150), (1740, 330, 140), (960, 210, 120)):
        draw_stained_glass(canvas, cx, cy, r, alpha=110)

    # 观众席上成排的玩偶（文档：座位上都是玩偶，缺一只右眼）
    d = ImageDraw.Draw(canvas, "RGBA")
    for tier, ty in ((0, 560), (1, 470)):
        d.rectangle([0, ty - 70, W, ty + 60], fill=mix(TH_WALL, (0, 0, 0), 0.45) + (235,))
        for i in range(0, W, 132):
            x = i + 40 + tier * 26
            d.ellipse([x, ty - 60, x + 42, ty - 18], fill=(52, 50, 52, 255))
            d.ellipse([x + 9, ty - 48, x + 17, ty - 40], fill=(20, 18, 20, 255))
            # 右眼缺失（只画左眼）
            d.ellipse([x + 25, ty - 48, x + 33, ty - 40], fill=(12, 10, 12, 255))

    # 幕布
    draw_curtain(canvas, 0, W, TH_DRAPE, folds=9)

    # --- 玩法平面：木舞台（参考图的木板地面）---
    surface = 840.0
    d.rectangle([0, surface, W, H], fill=(58, 40, 30, 255))
    for i in range(0, W, 128):
        d.line([i, surface, i + 22, H], fill=(44, 30, 22, 235), width=4)
    d.line([0, surface + 3, W, surface + 3], fill=(118, 84, 54, 245), width=6)
    for y in range(int(surface) + 40, H, 44):
        d.line([0, y, W, y], fill=(44, 30, 22, 200), width=3)

    # 断裂的木板 / 尖刺残骸（前景细节）
    for _ in range(9):
        px, py = rng.uniform(0, W), rng.uniform(surface + 40, H)
        d.line([px, py, px + rng.uniform(70, 190), py + rng.uniform(-16, 16)],
               fill=(40, 26, 20, 255), width=rng.randint(7, 15))

    # --- 皮埃罗（巨大、苍白、红线）---
    pierrot = load_sprite(ASSETS / "enemies/morris_idle.png", 0, 4, 4.6)
    contact_shadow(canvas, 1420, surface, 170)
    if pierrot is not None:
        tint = Image.new("RGBA", pierrot.size, (222, 216, 206, 255))
        tint.putalpha(pierrot.split()[3])
        pale = Image.blend(pierrot, tint, 0.55)
        paste_feet(canvas, pale, 1420, surface)
        # 烧焦的半边脸
        d = ImageDraw.Draw(canvas, "RGBA")
        glow(canvas, 1420 + 34, surface - 400, 34, (220, 90, 40), 0.7)
        d = ImageDraw.Draw(canvas, "RGBA")

    # --- 红线（核心机制：剪断控制木偶的红线）---
    thread_origin = (1420, surface - 430)
    targets = [(560, surface - 60), (760, surface - 20), (980, surface - 90),
               (1180, surface - 40), (1620, surface - 80), (1780, surface - 30)]
    for tx, ty in targets:
        d.line([thread_origin, (tx, ty)], fill=C_RED_THREAD + (210,), width=4)
        d.line([thread_origin, (tx, ty)], fill=(255, 110, 100, 90), width=2)

    # --- 木偶们 ---
    for i, (tx, ty) in enumerate(targets):
        pup = load_sprite(ASSETS / "enemies/townsman_idle.png", 0, 4, 2.6)
        paste_feet(canvas, pup, tx, ty + 60)
        d.ellipse([tx - 16, ty - 24, tx + 16, ty + 8], fill=(58, 50, 46, 235))

    # --- 主角：举着发光武器，冷色弧光 ---
    player = load_sprite(ASSETS / "characters/player/player_attack.png", 3, 6, 3.4)
    contact_shadow(canvas, 880, surface, 86)
    rim_light(canvas, player, 880, surface, (220, 250, 255), 3, 165)
    paste_feet(canvas, player, 880, surface)
    # 武器弧光
    glow(canvas, 962, surface - 96, 96, (200, 246, 255), 0.85)
    d = ImageDraw.Draw(canvas, "RGBA")
    d.arc([880, surface - 190, 1060, surface - 10], 300, 60,
          fill=(235, 252, 255, 245), width=15)
    d.arc([890, surface - 180, 1050, surface - 20], 300, 60,
          fill=(255, 255, 255, 255), width=7)

    # 冷色火光（前景两侧）
    for fx, fy in ((150, 980), (1800, 960)):
        glow(canvas, fx, fy, 190, TH_FLAME, 0.6)
        d = ImageDraw.Draw(canvas, "RGBA")
        for i in range(7):
            rr = 42 * (1.0 - i / 9.0)
            d.ellipse([fx - rr, fy - rr * 1.5, fx + rr, fy + rr * 0.7],
                      fill=mix(TH_FLAME, (255, 255, 255), i / 6.0) + (60,))

    draw_vines(canvas, seed=15, color=(10, 12, 12), count=3)
    vignette(canvas, 0.6)
    grain(canvas, 10, 11)

    # --- HUD ---
    hb_right = draw_health_bar(canvas, 46, 40, filled=4, total=7)
    draw_soul_vessel(canvas, hb_right + 62, 68, radius=40, soul_ratio=0.66)
    draw_item_slots(canvas, 92, 240, [("button", 4), ("rag_doll", 1)])
    draw_equip_slots(canvas)
    draw_damage_number(canvas, 1010, 500, 145)
    draw_boss_banner(canvas, "第二章 · 针线与纽扣眼", "人偶师 · 皮埃罗", 0.55,
                     "Chapter 2 · Old Theater Boss")
    draw_footer(canvas)
    return canvas.convert("RGB")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, builder in (("04_clocktower_heart", scene_clocktower),
                          ("05_old_theater_boss", scene_theater)):
        img = builder()
        img.save(OUT_DIR / f"{name}.png")
        print(f"  wrote docs/mockups/{name}.png  {img.width}x{img.height}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
