#!/usr/bin/env python3
"""Compose Demo 9 share sheets under docs/ for teammate handoff."""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ACTORS = ROOT / "assets/environments/exploration/actors"
MID = ROOT / "assets/environments/exploration/midgrounds"
BG = ROOT / "assets/environments/exploration/backgrounds"
PROPS = ROOT / "assets/environments/exploration/props"
OUT = ROOT / "docs"

SETS = {
    "demo9-share-cast-may.png": [
        "may_idle.png", "may_windup.png", "may_slash.png", "may_summon.png",
        "may_statue.png", "may_brush.png", "may_brush_strike.png",
    ],
    "demo9-share-cast-void.png": [
        "void_idle.png", "void_command.png", "void_lash.png", "void_frenzy.png", "void_puppet.png",
    ],
    "demo9-share-cast-keeper.png": [
        "keeper_back.png", "keeper_hidden.png", "keeper_unmasked.png",
    ],
    "demo9-share-cast-fury.png": [
        "fury_idle.png", "fury_lunge.png", "fury_punch.png",
    ],
    "demo9-share-cast-ling.png": [
        "ling_giant.png", "ling_crouch.png", "ling_hand.png",
    ],
}


def fit(im: Image.Image, box: tuple[int, int]) -> Image.Image:
    im = im.convert("RGBA")
    # Wide attack canvases can have large empty margins after a pose revision.
    # Trim for presentation only; gameplay PNG dimensions remain unchanged.
    if im.getbbox():
        im = im.crop(im.getbbox())
    im.thumbnail(box, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", box, (0, 0, 0, 0))
    x = (box[0] - im.width) // 2
    y = box[1] - im.height
    canvas.paste(im, (x, y), im)
    return canvas


def sheet(names: list[str], cell: tuple[int, int] = (280, 420), cols: int = 4, title: str = "") -> Image.Image:
    rows = (len(names) + cols - 1) // cols
    pad, label_h = 24, 36
    w = cols * cell[0] + (cols + 1) * pad
    h = rows * (cell[1] + label_h) + (rows + 1) * pad + (48 if title else 0)
    bg = Image.new("RGBA", (w, h), (18, 22, 28, 255))
    draw = ImageDraw.Draw(bg)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 18)
        title_font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 28)
    except Exception:
        font = ImageFont.load_default()
        title_font = font
    y0 = pad
    if title:
        draw.text((pad, pad), title, fill=(233, 209, 156, 255), font=title_font)
        y0 = pad + 48
    for i, name in enumerate(names):
        path = ACTORS / name
        r, c = divmod(i, cols)
        x = pad + c * (cell[0] + pad)
        y = y0 + r * (cell[1] + label_h + pad)
        if path.exists():
            tile = fit(Image.open(path), cell)
            bg.alpha_composite(tile, (x, y))
        else:
            draw.rectangle([x, y, x + cell[0], y + cell[1]], outline=(120, 80, 80, 255), width=2)
        draw.text((x, y + cell[1] + 6), name.replace(".png", ""), fill=(200, 190, 170, 255), font=font)
    return bg.convert("RGB")


def side_by_side(paths: list[Path], labels: list[str], height: int = 720) -> Image.Image:
    imgs = []
    for p in paths:
        im = Image.open(p).convert("RGBA")
        ratio = height / im.height
        im = im.resize((max(1, int(im.width * ratio)), height), Image.Resampling.LANCZOS)
        imgs.append(im)
    gap, label_h = 16, 40
    w = sum(i.width for i in imgs) + gap * (len(imgs) + 1)
    h = height + label_h + gap * 2
    canvas = Image.new("RGB", (w, h), (18, 22, 28))
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 20)
    except Exception:
        font = ImageFont.load_default()
    x = gap
    for im, label in zip(imgs, labels):
        canvas.paste(im.convert("RGB"), (x, gap), im)
        draw.text((x, gap + height + 8), label, fill=(233, 209, 156), font=font)
        x += im.width + gap
    return canvas


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for out_name, files in SETS.items():
        title = out_name.replace("demo9-share-cast-", "").replace(".png", "").upper()
        im = sheet(files, title=f"Demo 9 · {title}")
        dest = OUT / out_name
        im.save(dest, "PNG", optimize=True)
        written.append(dest)
        print("wrote", dest.relative_to(ROOT), im.size)

    # Detective single
    det = ACTORS / "detective.png"
    if det.exists():
        im = Image.open(det).convert("RGBA")
        im.thumbnail((720, 1280), Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", (im.width + 48, im.height + 80), (18, 22, 28))
        canvas.paste(im.convert("RGB"), (24, 48), im)
        draw = ImageDraw.Draw(canvas)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 28)
        except Exception:
            font = ImageFont.load_default()
        draw.text((24, 12), "Demo 9 · 刑警 detective", fill=(233, 209, 156), font=font)
        dest = OUT / "demo9-share-detective.png"
        canvas.save(dest, "PNG", optimize=True)
        written.append(dest)
        print("wrote", dest.relative_to(ROOT), canvas.size)

    # Museum mid + depth
    mm, md = MID / "museum_mid.png", MID / "museum_depth.png"
    if mm.exists() and md.exists():
        dest = OUT / "demo9-share-museum-mid.png"
        side_by_side([mm, md], ["museum_mid", "museum_depth"], 640).save(dest, "PNG", optimize=True)
        written.append(dest)
        print("wrote", dest.relative_to(ROOT))

    # Harvest night fire bg
    fire = BG / "fire.png"
    if fire.exists():
        im = Image.open(fire).convert("RGB")
        im.thumbnail((1600, 900), Image.Resampling.LANCZOS)
        dest = OUT / "demo9-share-harvest-night.png"
        im.save(dest, "PNG", optimize=True)
        written.append(dest)
        print("wrote", dest.relative_to(ROOT), im.size)

    # Item3 props
    prop_names = ["well_mouth.png", "caution_tape.png", "vine.png", "red_thread.png", "ground_hand.png"]
    tiles = []
    for n in prop_names:
        p = PROPS / n
        if p.exists():
            tiles.append((n, Image.open(p).convert("RGBA")))
    if tiles:
        cell = (320, 240)
        cols = 3
        rows = (len(tiles) + cols - 1) // cols
        pad = 20
        w = cols * cell[0] + (cols + 1) * pad
        h = rows * (cell[1] + 36) + (rows + 1) * pad + 48
        canvas = Image.new("RGBA", (w, h), (18, 22, 28, 255))
        draw = ImageDraw.Draw(canvas)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 18)
            title_font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 26)
        except Exception:
            font = ImageFont.load_default()
            title_font = font
        draw.text((pad, pad), "Demo 9 · item3 props", fill=(233, 209, 156, 255), font=title_font)
        for i, (name, im) in enumerate(tiles):
            r, c = divmod(i, cols)
            x = pad + c * (cell[0] + pad)
            y = pad + 48 + r * (cell[1] + 36 + pad)
            tile = fit(im, cell)
            # checker so alpha reads
            for yy in range(0, cell[1], 16):
                for xx in range(0, cell[0], 16):
                    col = (40, 44, 52, 255) if (xx // 16 + yy // 16) % 2 == 0 else (28, 32, 38, 255)
                    draw.rectangle([x + xx, y + yy, x + xx + 16, y + yy + 16], fill=col)
            canvas.alpha_composite(tile, (x, y))
            draw.text((x, y + cell[1] + 6), name.replace(".png", ""), fill=(200, 190, 170, 255), font=font)
        dest = OUT / "demo9-share-item3-props.png"
        canvas.convert("RGB").save(dest, "PNG", optimize=True)
        written.append(dest)
        print("wrote", dest.relative_to(ROOT))

    # Overview cast strip
    overview_files = [
        "may_brush_strike.png", "void_lash.png", "keeper_unmasked.png",
        "fury_lunge.png", "ling_giant.png", "detective.png",
    ]
    im = sheet(overview_files, cell=(240, 360), cols=6, title="Demo 9 · cast overview")
    dest = OUT / "demo9-share-cast-overview.png"
    im.save(dest, "PNG", optimize=True)
    written.append(dest)
    print("wrote", dest.relative_to(ROOT), im.size)

    print("SHARE_EXPORT", len(written), "files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
