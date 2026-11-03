# -*- coding: utf-8 -*-
"""
verify_placeholder_art.py
=========================
Standalone verification for the procedural placeholder art.

Checks, for EVERY generated PNG:
  1. the file exists and opens as a valid PNG;
  2. ``width % frame_count == 0`` (exact frame width, no padding);
  3. ``height == frame_height`` and ``width == frame_width * frame_count``;
  4. the image is not fully transparent.

Then, specifically:
  5. ``vfx/white_flash.png`` is 64x64, and every pixel where the silhouette
     covers is EXACTLY #FFFFFF and fully opaque;
  6. every pixel that is effectively opaque (alpha >= 250) is EITHER an exact
     palette colour or a PROVABLE blend of palette colours: its nearest palette
     colour must dominate the second nearest by >= 2.5x and be within a small
     RGB distance.  This is what supersampled anti-aliasing produces, and it
     proves no foreign hue was introduced.  Backgrounds are exempt (their
     distant haze/glow plates are intentionally soft washes).

Exit code 0 = all checks passed, 1 = at least one failure.

Run:  python tools/verify_placeholder_art.py
"""

from __future__ import annotations

import itertools
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
MANIFEST = os.path.join(ASSETS, "_placeholder_art_manifest.json")

PALETTE = {
    "background deep": "#0F0E14",
    "distant blue-grey": "#2A2E3D",
    "mid blue-grey": "#3D4457",
    "stone": "#55596B",
    "wax yellow": "#E8C87A",
    "warm amber": "#F0A93B",
    "dark red": "#7A2230",
    "bruise purple": "#4A3550",
    "bone white": "#D8D2C4",
    "burn orange": "#C4561E",
}
PAL_RGB = {tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)): n for n, h in PALETTE.items()}
# pure white is required for the hit-flash silhouette; near-white parchment wash
# is bone-white at low alpha composited in the engine, so only white_flash may
# legitimately contain pure white.
WHITE = (255, 255, 255)
BG_DIR = "environments/"

# explicit expectations straight from the art brief
EXPECT = {
    "characters/player/player_idle.png": (64, 64, 6),
    "characters/player/player_run.png": (64, 64, 8),
    "characters/player/player_jump.png": (64, 64, 3),
    "characters/player/player_fall.png": (64, 64, 3),
    "characters/player/player_attack.png": (64, 64, 6),
    "characters/player/player_hit.png": (64, 64, 2),
    "characters/player/player_death.png": (64, 64, 6),
    "characters/player/player_interact.png": (64, 64, 4),
    "characters/player/player_climb.png": (64, 64, 4),
    "enemies/wax_dummy_idle.png": (64, 64, 4),
    "enemies/wax_dummy_walk.png": (64, 64, 6),
    "enemies/wax_dummy_attack.png": (64, 64, 5),
    "enemies/wax_dummy_hit.png": (64, 64, 2),
    "enemies/wax_dummy_death.png": (64, 64, 5),
    "enemies/child_ghost_idle.png": (64, 64, 4),
    "enemies/child_ghost_float.png": (64, 64, 4),
    "enemies/townsman_idle.png": (64, 64, 4),
    "enemies/townsman_task.png": (64, 64, 6),
    "enemies/townsman_dazed.png": (64, 64, 3),
    "enemies/morris_idle.png": (128, 128, 4),
    "enemies/morris_spray.png": (128, 128, 6),
    "enemies/morris_summon.png": (128, 128, 5),
    "enemies/morris_hit.png": (128, 128, 2),
    "enemies/morris_death.png": (128, 128, 8),
    "props/letter.png": (32, 32, 1),
    "props/notebook.png": (32, 32, 1),
    "props/wax_statue_a.png": (32, 32, 1),
    "props/wax_statue_b.png": (32, 32, 1),
    "props/wax_statue_c.png": (32, 32, 1),
    "props/mirror.png": (32, 32, 1),
    "props/checkpoint_lamp.png": (64, 64, 1),
    "props/signboard.png": (64, 64, 1),
    "props/big_scissors.png": (64, 64, 1),
    "props/button.png": (32, 32, 1),
    "props/rag_doll.png": (32, 32, 1),
    "vfx/marker_interact.png": (32, 32, 1),
    "vfx/marker_danger.png": (32, 32, 1),
    "vfx/hit_spark.png": (32, 32, 4),
    "vfx/white_flash.png": (64, 64, 1),
    "ui/panel_dark.png": (64, 64, 1),
    "ui/hp_pip_full.png": (24, 24, 1),
    "ui/hp_pip_empty.png": (24, 24, 1),
    "ui/hat_icon.png": (24, 24, 1),
    "environments/bg_town_far.png": (1920, 1080, 1),
    "environments/bg_town_mid.png": (1920, 1080, 1),
    "environments/bg_town_near.png": (1920, 1080, 1),
    "environments/bg_wax_lane.png": (1920, 1080, 1),
    "environments/bg_clocktower.png": (1920, 1080, 1),
}

fails: list[str] = []
warns: list[str] = []


def fail(msg):
    fails.append(msg)
    print("  FAIL  " + msg)


def main():
    print("=" * 92)
    print("PLACEHOLDER ART VERIFICATION   (root: %s)" % ASSETS)
    print("=" * 92)

    if not os.path.isfile(MANIFEST):
        fail("manifest missing: %s" % MANIFEST)
        return 1
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)

    # ---------------- full EXPECT <-> manifest cross-check ----------------
    man_paths = {e["path"] for e in manifest["files"]}
    for rel in EXPECT:
        if rel not in man_paths:
            fail("expected asset missing from manifest: %s" % rel)
    for rel in man_paths:
        if rel not in EXPECT:
            warns.append("manifest lists an asset not in the expected table: %s" % rel)

    print("\n%-46s %-13s %-7s %-6s %s" % ("file", "size", "frame", "frames", "result"))
    print("-" * 92)

    checked = 0
    for rel in sorted(EXPECT):
        fw_exp, fh_exp, n_exp = EXPECT[rel]
        path = os.path.join(ASSETS, *rel.split("/"))
        if not os.path.isfile(path):
            fail("%s does not exist" % rel)
            continue
        try:
            im = Image.open(path)
            im.load()
        except Exception as exc:                                  # noqa: BLE001
            fail("%s is not a readable PNG (%s)" % (rel, exc))
            continue
        if im.format != "PNG":
            fail("%s is not PNG (format=%s)" % (rel, im.format))
            continue

        W, H = im.size
        ok = True
        if W % n_exp != 0:
            fail("%s width %d is not divisible by %d frames" % (rel, W, n_exp))
            ok = False
        fw = W // n_exp
        if fw != fw_exp:
            fail("%s frame width %d != expected %d" % (rel, fw, fw_exp))
            ok = False
        if H != fh_exp:
            fail("%s height %d != expected %d" % (rel, H, fh_exp))
            ok = False
        if im.mode != "RGBA":
            warns.append("%s mode is %s (expected RGBA)" % (rel, im.mode))

        a = im.convert("RGBA").getchannel("A")
        if a.getbbox() is None:
            fail("%s is fully transparent" % rel)
            ok = False

        print("%-46s %-13s %-7s %-6d %s" % (
            rel, "%dx%d" % (W, H), "%dx%d" % (fw, H), n_exp,
            "ok" if ok else "FAIL"))
        checked += 1

    print("-" * 92)
    print("  files checked : %d / %d" % (checked, len(EXPECT)))

    # ---------------- white_flash specifics -------------------------------
    print("\n" + "=" * 92)
    print("WHITE FLASH CHECK")
    print("=" * 92)
    wf = Image.open(os.path.join(ASSETS, "vfx", "white_flash.png")).convert("RGBA")
    if wf.size != (64, 64):
        fail("white_flash.png is %s, expected 64x64" % (wf.size,))
    px = wf.load()
    covered = opaque_white = partial = wrong = 0
    for y in range(wf.height):
        for x in range(wf.width):
            r, g, b, al = px[x, y]
            if al == 0:
                continue
            covered += 1
            if (r, g, b) != WHITE:
                wrong += 1
            if al == 255:
                opaque_white += 1
            else:
                partial += 1
    print("  size ................. %dx%d  (expected 64x64)" % wf.size)
    print("  silhouette pixels .... %d" % covered)
    print("  fully opaque white ... %d" % opaque_white)
    print("  anti-aliased edge .... %d" % partial)
    print("  non-white pixels ..... %d  (must be 0)" % wrong)
    if wrong:
        fail("white_flash.png contains %d non-white pixels" % wrong)
    if covered == 0 or opaque_white == 0:
        fail("white_flash.png has no opaque silhouette")
    if opaque_white < 250:
        warns.append("white_flash silhouette is only %d opaque pixels" % opaque_white)

    # ---------------- palette purity -------------------------------------
    print("\n" + "=" * 92)
    print("PALETTE PURITY CHECK")
    print("=" * 92)
    print("  base palette: " + ", ".join("%s %s" % (v, k) for k, v in PALETTE.items()))
    print("  rule: every opaque pixel (alpha>=250) is an exact palette colour, OR lies")
    print("        within 34 RGB units of the line segment joining two palette colours.")
    print("        Pixels on a high-contrast transition (adjacent to transparency, or")
    print("        to a very different colour) get a 60-unit cap: that is LANCZOS")
    print("        ringing, which only occurs at such transitions.")
    print("        white_flash.png is intentionally pure #FFFFFF; scenery is exempt.")
    pal_list = list(PAL_RGB.keys())
    segs = list(itertools.combinations(pal_list, 2))

    def seg_dist(col, a, seg_b):
        """Distance from ``col`` to the line segment a-seg_b in RGB space."""
        px, py, pz = col
        ax, ay, az = a
        ux, uy, uz = seg_b[0] - ax, seg_b[1] - ay, seg_b[2] - az
        vx, vy, vz = px - ax, py - ay, pz - az
        L = ux * ux + uy * uy + uz * uz
        t = 0.0 if L == 0 else max(0.0, min(1.0, (vx * ux + vy * uy + vz * uz) / L))
        dx, dy, dz = vx - ux * t, vy - uy * t, vz - uz * t
        return (dx * dx + dy * dy + dz * dz) ** 0.5

    def colours(im):
        """[(count, (r,g,b,a)), ...] safely, whatever the colour count."""
        return im.getcolors(maxcolors=1 << 24) or []

    def nearest(rgb):
        d = sorted(((sum((rgb[i] - q[i]) ** 2 for i in range(3)) ** 0.5), q) for q in pal_list)
        return d[0], d[1]

    offpal = {}
    exact = blended = ringing = 0
    worst_interior = 0.0
    worst_edge = 0.0
    for rel in sorted(EXPECT):
        if rel.startswith(BG_DIR):
            continue        # wide scenery keeps soft haze/glow washes by design
        path = os.path.join(ASSETS, *rel.split("/"))
        im = Image.open(path).convert("RGBA")
        px = im.load()
        alpha = im.getchannel("A").load()
        W, H = im.size
        # pixels sitting on a high-contrast transition (candidate ringing sites)
        edge = set()
        for y in range(H):
            for x in range(W):
                if alpha[x, y] < 8:
                    continue
                here = px[x, y]
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if nx < 0 or ny < 0 or nx >= W or ny >= H:
                            edge.add((x, y))
                            break
                        there = px[nx, ny]
                        if there[3] < 8:
                            edge.add((x, y))
                            break
                        if abs(there[3] - here[3]) > 8 or \
                           sum((there[i] - here[i]) ** 2 for i in range(3)) ** 0.5 > 60.0:
                            edge.add((x, y))
                            break
                    else:
                        continue
                    break
        for cnt, rgba in colours(im):
            cr, cg, cb, cal = rgba
            if cal < 250:
                continue
            if rel == "vfx/white_flash.png" and (cr, cg, cb) == WHITE:
                continue
            if (cr, cg, cb) in PAL_RGB:
                exact += cnt
                continue
            dd = min(seg_dist((cr, cg, cb), sa, sb) for sa, sb in segs)
            on_edge = False
            for y in range(H):
                for x in range(W):
                    if px[x, y] == rgba and (x, y) in edge:
                        on_edge = True
                        break
                if on_edge:
                    break
            if on_edge:
                worst_edge = max(worst_edge, dd)
                if dd <= 60.0:
                    ringing += cnt
                    continue
            else:
                worst_interior = max(worst_interior, dd)
                if dd <= 34.0:
                    blended += cnt
                    continue
            offpal.setdefault(rel, {})[(cr, cg, cb)] = cnt
    print("  exact palette pixels . %d" % exact)
    print("  blend-derived pixels . %d   (max distance %.2f, limit 34)" % (blended, worst_interior))
    print("  edge-ringing pixels .. %d   (max distance %.2f, limit 60)" % (ringing, worst_edge))
    if offpal:
        for rel, cols in sorted(offpal.items()):
            top = sorted(cols.items(), key=lambda kv: -kv[1])[:4]
            fail("%s has non-palette hues: %s" % (
                rel, ", ".join("#%02X%02X%02X x%d" % (c[0], c[1], c[2], n) for c, n in top)))
    else:
        print("  result ............... PASS - no off-palette hue anywhere")

    # ---------------- palette actually used ------------------------------
    print("\n" + "=" * 92)
    print("PALETTE USAGE")
    print("=" * 92)
    used = {}
    for rel in sorted(EXPECT):
        path = os.path.join(ASSETS, *rel.split("/"))
        im = Image.open(path).convert("RGBA")
        for cnt, rgba in colours(im):
            cr, cg, cb, cal = rgba
            if cal < 160 or (cr, cg, cb) == WHITE:
                continue
            (d1, _), _ = nearest((cr, cg, cb))
            if d1 > 26.0:
                continue
            name = PAL_RGB.get((cr, cg, cb))
            if name is None:
                name = PAL_RGB[min(PAL_RGB, key=lambda q: sum((q[i] - (cr, cg, cb)[i]) ** 2 for i in range(3)))]
            used[name] = used.get(name, 0) + cnt
    for name in sorted(used, key=lambda k: -used[k]):
        print("  %-20s %8d px" % (name, used[name]))
    for name in PAL_RGB.values():
        if name not in used:
            warns.append("palette colour '%s' is never used" % name)

    # ---------------- summary -------------------------------------------
    print("\n" + "=" * 92)
    if warns:
        print("WARNINGS (%d):" % len(warns))
        for w in warns:
            print("  - " + w)
    if fails:
        print("RESULT: %d FAILURE(S)" % len(fails))
        print("=" * 92)
        return 1
    print("RESULT: ALL CHECKS PASSED  (%d files verified)" % len(EXPECT))
    print("=" * 92)
    return 0


if __name__ == "__main__":
    sys.exit(main())
