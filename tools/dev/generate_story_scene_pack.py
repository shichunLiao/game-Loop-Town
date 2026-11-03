"""Render original 2D scene concepts from 《回环镇·剧情 5.0》.

The scenes intentionally use only procedural geometry and colour: no existing
mockup, sprite, or background is read as an input.  They are layout paintings
for the story locations before production art is commissioned.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


W, H = 1920, 1080
OUT = Path(__file__).resolve().parents[2] / "docs" / "story-scenes"


def gradient(top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    for y in range(H):
        t = y / (H - 1)
        color = tuple(int(a * (1 - t) + b * t) for a, b in zip(top, bottom))
        draw.line((0, y, W, y), fill=color)
    return image.convert("RGBA")


def mist(image: Image.Image, color: tuple[int, int, int], seed: int, amount: int = 36) -> None:
    rng = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(amount):
        x, y = rng.randint(-300, W), rng.randint(260, 850)
        rx, ry = rng.randint(130, 420), rng.randint(24, 100)
        d.ellipse((x - rx, y - ry, x + rx, y + ry), fill=color + (rng.randint(10, 34),))
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(34)))


def platform(d: ImageDraw.ImageDraw, x: int, y: int, width: int, depth: int = 170,
             edge: tuple[int, int, int] = (203, 202, 182)) -> None:
    d.rectangle((x, y, x + width, y + depth), fill=(27, 29, 37, 255))
    d.rectangle((x, y, x + width, y + 12), fill=edge + (255,))
    d.line((x, y + 24, x + width, y + 24), fill=(87, 91, 102, 255), width=4)
    for xx in range(x + 32, x + width, 68):
        d.line((xx, y + 12, xx, y + depth), fill=(12, 14, 20, 180), width=4)


def lantern(d: ImageDraw.ImageDraw, x: int, y: int, glow: tuple[int, int, int]) -> None:
    for r, a in ((70, 20), (42, 45), (22, 120)):
        d.ellipse((x-r, y-r, x+r, y+r), fill=glow + (a,))
    d.rectangle((x - 8, y - 13, x + 8, y + 16), fill=(242, 210, 126, 255))


def investigator(d: ImageDraw.ImageDraw, x: int, ground: int, scale: float = 1.0) -> None:
    # A silhouette with the story's oversized detective hat and notebook.
    h = int(170 * scale)
    body = (12, 13, 19, 255)
    d.polygon([(x - h // 3, ground - h + 45), (x + h // 3, ground - h + 45),
               (x + h // 5, ground - 36), (x - h // 4, ground - 18)], fill=body)
    d.ellipse((x - h // 7, ground - h + 30, x + h // 7, ground - h + 78), fill=(35, 28, 30, 255))
    d.rectangle((x - h // 2, ground - h + 21, x + h // 2, ground - h + 47), fill=body)
    d.polygon([(x - h // 3, ground - h + 25), (x, ground - h - 16),
               (x + h // 3, ground - h + 25)], fill=body)
    d.rectangle((x + h // 6, ground - 69, x + h // 3, ground - 35), fill=(224, 220, 199, 255))
    d.ellipse((x + 3, ground - h + 53, x + 9, ground - h + 59), fill=(224, 151, 57, 255))


def crooked_house(d: ImageDraw.ImageDraw, x: int, base: int, w: int, h: int,
                  wall: tuple[int, int, int], lit: bool = False) -> None:
    d.polygon([(x, base), (x + 14, base - h), (x + w - 10, base - h + 18), (x + w, base)],
              fill=wall + (255,))
    d.polygon([(x - 16, base - h + 12), (x + w // 2, base - h - 36),
               (x + w + 17, base - h + 18)], fill=(28, 28, 38, 255))
    for wx in range(x + 25, x + w - 20, 42):
        wy = base - h + 48 + (wx % 3) * 9
        d.rectangle((wx, wy, wx + 15, wy + 30), fill=((226, 166, 77, 255) if lit else (23, 24, 31, 255)))


def town_entrance() -> Image.Image:
    image = gradient((65, 51, 75), (21, 26, 37))
    d = ImageDraw.Draw(image, "RGBA")
    for x, w, h in ((0, 210, 330), (175, 250, 280), (420, 210, 350), (1220, 250, 330), (1510, 300, 400), (1780, 220, 300)):
        crooked_house(d, x, 770, w, h, (49, 47, 61), lit=True)
    # Distant clock tower: all roads in the document point here.
    d.rectangle((1450, 160, 1570, 685), fill=(24, 28, 42, 255))
    d.polygon([(1415, 170), (1510, 42), (1605, 170)], fill=(24, 28, 42, 255))
    d.ellipse((1467, 255, 1553, 341), fill=(196, 180, 132, 230), outline=(30, 30, 40, 255), width=8)
    d.line((1510, 298, 1510, 266), fill=(38, 36, 43, 255), width=6)
    d.line((1510, 298, 1537, 312), fill=(38, 36, 43, 255), width=6)
    platform(d, 0, 816, 1180, 270)
    platform(d, 1345, 816, 575, 270)
    d.rectangle((1140, 720, 1184, 1080), fill=(8, 10, 15, 255))
    d.rectangle((1286, 720, 1331, 1080), fill=(8, 10, 15, 255))
    for x in (245, 885, 1660):
        d.rectangle((x, 590, x + 12, 816), fill=(31, 28, 28, 255))
        lantern(d, x + 6, 625, (250, 167, 62))
    investigator(d, 150, 816)
    # The weathered welcome sign, a story object rather than an annotation.
    d.rectangle((325, 657, 555, 718), fill=(83, 51, 34, 255), outline=(174, 105, 55, 255), width=4)
    d.rectangle((348, 718, 362, 817), fill=(61, 40, 31, 255))
    d.rectangle((520, 718, 534, 817), fill=(61, 40, 31, 255))
    mist(image, (206, 197, 217), 8)
    return image.convert("RGB")


def wax_lane() -> Image.Image:
    image = gradient((38, 28, 38), (13, 16, 23))
    d = ImageDraw.Draw(image, "RGBA")
    # Tall wall rhythm and arches close the player in.
    for x in range(-60, W + 40, 180):
        d.rectangle((x, 130, x + 130, 760), fill=(30, 28, 39, 255))
        d.arc((x + 15, 120, x + 115, 350), 180, 360, fill=(82, 66, 84, 100), width=7)
    platform(d, 0, 846, 510, 235)
    platform(d, 620, 742, 430, 338)
    platform(d, 1165, 846, 470, 235)
    platform(d, 1750, 780, 170, 300)
    # Wax statues: near ones are lit gold, hostile ones carry a red core.
    statues = [(95, 845, 0), (270, 845, 0), (455, 843, 0), (694, 741, 0), (844, 741, 0),
               (1210, 846, 1), (1348, 846, 1), (1505, 846, 1), (1810, 779, 1)]
    for x, ground, hostile in statues:
        col = (224, 183, 97, 255) if hostile else (185, 146, 82, 255)
        d.ellipse((x - 19, ground - 152, x + 19, ground - 114), fill=col)
        d.polygon([(x - 31, ground - 112), (x + 31, ground - 112), (x + 40, ground - 12),
                   (x - 38, ground - 12)], fill=col)
        if hostile:
            d.ellipse((x - 7, ground - 108, x + 7, ground - 94), fill=(162, 37, 38, 255))
    # Mirrors foreshadow the memory room.
    for x, y in ((805, 390), (1570, 300)):
        d.rectangle((x, y, x + 80, y + 174), fill=(20, 20, 30, 255), outline=(135, 113, 145, 255), width=8)
        d.rectangle((x + 12, y + 16, x + 68, y + 155), fill=(66, 56, 83, 255))
    investigator(d, 1085, 846)
    for x in (430, 1020, 1700):
        lantern(d, x, 540, (248, 180, 72))
    mist(image, (88, 68, 105), 13, 25)
    return image.convert("RGB")


def old_theater() -> Image.Image:
    image = gradient((22, 43, 49), (10, 15, 20))
    d = ImageDraw.Draw(image, "RGBA")
    # Stage curtain and audience tiers of one-eyed dolls.
    for x in range(-20, W + 20, 130):
        d.polygon([(x, 0), (x + 110, 0), (x + 78, 428), (x + 24, 428)], fill=(91, 24, 37, 255))
    for y, shift in ((495, 0), (590, 48)):
        d.rectangle((0, y, W, y + 64), fill=(21, 25, 28, 255))
        for x in range(-20 + shift, W, 92):
            d.ellipse((x, y - 36, x + 38, y + 4), fill=(164, 155, 140, 255))
            d.ellipse((x + 9, y - 22, x + 14, y - 17), fill=(16, 16, 18, 255))
            # Missing right eye is a deliberate recurring visual.
    platform(d, 0, 840, W, 250, edge=(168, 122, 79))
    # Stained windows and cold braziers.
    for x in (120, 1760):
        d.polygon([(x, 265), (x + 62, 185), (x + 124, 265), (x + 100, 455), (x + 24, 455)],
                  fill=(67, 123, 130, 160), outline=(156, 201, 197, 180))
        lantern(d, x + 62, 790, (74, 200, 207))
    # The puppeteer is tall, pale, and controls every small figure with red thread.
    px, py = 1440, 840
    d.ellipse((px - 45, py - 415, px + 45, py - 325), fill=(214, 204, 189, 255))
    d.polygon([(px - 70, py - 320), (px + 70, py - 320), (px + 124, py - 25), (px - 104, py - 25)], fill=(195, 191, 180, 255))
    origin = (px - 8, py - 285)
    for tx in (520, 730, 960, 1170, 1610, 1780):
        d.line((origin, (tx, 782)), fill=(212, 50, 55, 245), width=4)
        d.ellipse((tx - 17, 744, tx + 17, 792), fill=(103, 93, 90, 255))
    investigator(d, 875, 840)
    mist(image, (38, 126, 130), 21, 20)
    return image.convert("RGB")


def clocktower() -> Image.Image:
    image = gradient((104, 35, 30), (25, 12, 16))
    d = ImageDraw.Draw(image, "RGBA")
    # Giant clock faces and gear teeth turn the tower into a vertical route.
    for x, y, r in ((240, 260, 210), (970, 300, 255), (1680, 255, 205), (1310, 715, 175)):
        d.ellipse((x-r, y-r, x+r, y+r), fill=(165, 92, 57, 210), outline=(58, 28, 24, 255), width=16)
        for a in range(0, 360, 30):
            xx = x + int(math.cos(math.radians(a)) * r * .79)
            yy = y + int(math.sin(math.radians(a)) * r * .79)
            d.line((x + int(math.cos(math.radians(a)) * r * .65), y + int(math.sin(math.radians(a)) * r * .65), xx, yy), fill=(65, 26, 25, 255), width=4)
        d.line((x, y, x, y-r//2), fill=(55, 25, 25, 255), width=9)
        d.line((x, y, x+r//3, y+40), fill=(55, 25, 25, 255), width=9)
    for x, y, r in ((130, 920, 290), (1750, 930, 310), (1230, 790, 145)):
        d.ellipse((x-r, y-r, x+r, y+r), outline=(112, 72, 34, 255), width=42)
        for a in range(0, 360, 20):
            xx, yy = x + int(math.cos(math.radians(a))*r), y + int(math.sin(math.radians(a))*r)
            d.rectangle((xx-15, yy-15, xx+15, yy+15), fill=(103, 65, 31, 255))
    platform(d, 0, 838, W, 250, edge=(204, 155, 74))
    platform(d, 330, 660, 360, 200, edge=(204, 155, 74))
    platform(d, 1050, 590, 360, 270, edge=(204, 155, 74))
    investigator(d, 720, 838)
    mist(image, (212, 78, 36), 34, 15)
    return image.convert("RGB")


def fire_town() -> Image.Image:
    image = gradient((83, 23, 24), (18, 12, 17))
    d = ImageDraw.Draw(image, "RGBA")
    rng = random.Random(247)
    for x in range(-40, W + 30, 185):
        h = rng.randint(250, 470)
        crooked_house(d, x, 790, rng.randint(130, 220), h, (42, 26, 32), False)
        for f in range(3):
            fx, fy = x + rng.randint(20, 145), 720 - rng.randint(0, h // 2)
            d.polygon([(fx - 18, fy + 38), (fx, fy - 42), (fx + 21, fy + 38)], fill=(250, 81 + f * 20, 35, 210))
    # The clock tower opens like a wound at the final approach.
    d.rectangle((855, 128, 1060, 790), fill=(23, 17, 23, 255))
    d.polygon([(820, 145), (957, 0), (1094, 145)], fill=(23, 17, 23, 255))
    d.ellipse((884, 274, 1030, 420), fill=(238, 114, 46, 230), outline=(50, 22, 26, 255), width=12)
    platform(d, 0, 836, W, 244, edge=(170, 90, 56))
    # Ash silhouettes flee through the town.
    for x in range(150, W, 180):
        d.ellipse((x, 700, x + 26, 730), fill=(17, 17, 22, 255))
        d.polygon([(x - 10, 732), (x + 35, 732), (x + 48, 824), (x - 20, 824)], fill=(17, 17, 22, 255))
    investigator(d, 620, 836, 1.08)
    mist(image, (244, 95, 46), 55, 30)
    return image.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    scenes = {
        "01-fog-town-entrance.png": town_entrance,
        "02-wax-statue-lane.png": wax_lane,
        "03-old-theater.png": old_theater,
        "04-clocktower-heart.png": clocktower,
        "05-burning-loop-town.png": fire_town,
    }
    for name, render in scenes.items():
        image = render()
        image.save(OUT / name, optimize=True)
        print(f"created {name}: {W}x{H}")


if __name__ == "__main__":
    main()
