# -*- coding: utf-8 -*-
"""
generate_placeholder_art.py
===========================
《回环镇》/ Loop Town  —  procedural placeholder art generator.

Standalone.  Uses ONLY Pillow + the Python standard library.
No external source images, no network, no fonts required.

Design rules
------------
* Deterministic: every random value comes from ``rng(seed)`` -> ``random.Random``.
* Idempotent: every run overwrites exactly the same files with the same bytes.
* Palette locked: fills are drawn with the 10 palette colours at various
  ALPHA values (plus near-white at low alpha for light glows, and pure white
  for the hit-flash silhouette, which the spec calls for).  Edges are
  anti-aliased by 4x supersampled downsampling.
* Silhouette first: the player is a dark gothic wedge with a huge wide-brim
  detective hat + one amber eye; the wax dummies are pale dripping mannequins
  with NO eyes; Morris is the only figure with bright amber eye highlights.

Run:
    python tools/generate_placeholder_art.py
"""

from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# --------------------------------------------------------------------------
# paths / constants
# --------------------------------------------------------------------------

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
PREVIEW = os.path.join(ROOT, "tools", "_preview_contact_sheet.png")

SEED = 20240517

# --------------------------------------------------------------------------
# palette (the ONLY base colours allowed)
# --------------------------------------------------------------------------

C_BG = "#0F0E14"        # background deep
C_BLUE = "#2A2E3D"      # distant blue-grey
C_MID = "#3D4457"       # mid blue-grey
C_STONE = "#55596B"     # stone
C_WAX = "#E8C87A"       # wax yellow (wax / light)
C_AMBER = "#F0A93B"     # warm amber (eye highlight, lamps)
C_RED = "#7A2230"       # dark red (danger / wax museum)
C_PURP = "#4A3550"      # bruise purple
C_BONE = "#D8D2C4"      # bone white
C_ORANGE = "#C4561E"    # burn orange (fire)

C_WHITE = "#FFFFFF"     # only used for white_flash.png

PALETTE = [C_BG, C_BLUE, C_MID, C_STONE, C_WAX, C_AMBER, C_RED, C_PURP, C_BONE, C_ORANGE]


def hx(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def col(h, a=255):
    """Palette colour + alpha (0-255)."""
    r, g, b = hx(h)
    return (r, g, b, int(max(0, min(255, round(a)))))


# frequently used shorthands
BG, BLUE, MID, STONE = C_BG, C_BLUE, C_MID, C_STONE
WAX, AMBER, RED, PURP, BONE, ORANGE = C_WAX, C_AMBER, C_RED, C_PURP, C_BONE, C_ORANGE


def wpct(base, target, t):
    """Colour halfway (t 0..1) from ``base`` towards ``target`` (both palette)."""
    b, g = hx(base), hx(target)
    return "#%02X%02X%02X" % tuple(
        int(round(b[i] + (g[i] - b[i]) * max(0.0, min(1.0, t)))) for i in range(3)
    )


# --------------------------------------------------------------------------
# randomness
# --------------------------------------------------------------------------

def rng(tag=None):
    h = 0
    for ch in str(tag):
        h = (h * 131 + ord(ch)) % 1000003
    return random.Random(SEED * 7919 + h)


# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------

def V(x, y):
    return (float(x), float(y))


def mat(x, y, th=0.0, sx=1.0, sy=1.0):
    """Rotation+scale+translation matrix, then perspective squash.

    ``sy`` compresses after rotation -> cheap foreshortening for plunging
    viewplanes such as a rooftop seen from below.
    """
    a = math.radians(th)
    c, s = math.cos(a), math.sin(a)
    X, Y = x * sx, y * sy
    return (X * c - Y * s, X * s + Y * c)


def mrot(th=0.0, sx=1.0, sy=1.0):
    return lambda x, y: mat(x, y, th, sx, sy)


def add(p, hp):
    return (p[0] + hp[0], p[1] + hp[1])


def mid(p, q, t=0.5):
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


def lerp(a, b, t):
    return a + (b - a) * t


# --------------------------------------------------------------------------
# render / composite pipeline
# --------------------------------------------------------------------------

def nlayer(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def over(base, layer):
    """Alpha-composite ``layer`` onto ``base`` (both RGBA)."""
    return Image.alpha_composite(base.convert("RGBA"), layer)


def overlay_tinted(base, mask, colour):
    """Composite a solid ``colour`` (RGB triple) through grey ``mask``."""
    solid = Image.new("RGB", mask.size, colour)
    base.paste(solid, (0, 0), mask)


def downsample(im, size):
    return im.resize(size, Image.LANCZOS)


class ScaledDraw:
    """An ``ImageDraw``-alike that multiplies every coordinate by ``scale``.

    All art code is authored in *target* pixels (e.g. a 64x64 frame) while the
    real layer is ``scale`` times larger, so shapes are rasterised at high
    resolution and then smoothly downsampled.
    """

    __slots__ = ("_d", "scale")

    def __init__(self, image, scale):
        self._d = ImageDraw.Draw(image)
        self.scale = float(scale)

    def _pt(self, xy):
        s = self.scale
        return [(float(p[0]) * s, float(p[1]) * s) for p in xy]

    def _box(self, xy):
        s = self.scale
        return [float(xy[0]) * s, float(xy[1]) * s, float(xy[2]) * s, float(xy[3]) * s]

    def _lw(self, width):
        return max(1, int(round(width * self.scale)))

    # --- primitives used by the art code ---------------------------------
    def polygon(self, xy, fill=None, outline=None, width=1):
        self._d.polygon(self._pt(xy), fill=fill, outline=outline, width=self._lw(width))

    def rectangle(self, xy, fill=None, outline=None, width=1):
        self._d.rectangle(self._box(xy), fill=fill, outline=outline, width=self._lw(width))

    def ellipse(self, xy, fill=None, outline=None, width=1):
        self._d.ellipse(self._box(xy), fill=fill, outline=outline, width=self._lw(width))

    def line(self, xy, fill=None, width=1, joint=None):
        self._d.line(self._pt(xy), fill=fill, width=self._lw(width), joint=joint)

    def arc(self, xy, start, end, fill=None, width=1):
        self._d.arc(self._box(xy), start, end, fill=fill, width=self._lw(width))

    def point(self, xy, fill=None):
        self._d.point(self._pt(xy), fill=fill)

    def bitmap(self, xy, bitmap, fill=None):
        s = self.scale
        if s != 1.0:
            w = max(1, int(round(bitmap.width * s)))
            h = max(1, int(round(bitmap.height * s)))
            bitmap = bitmap.resize((w, h), Image.NEAREST)
        self._d.bitmap((float(xy[0]) * s, float(xy[1]) * s), bitmap, fill=fill)


# --------------------------------------------------------------------------
# draw helpers (operate on supersampled RGBA layers)
# --------------------------------------------------------------------------

def d_poly(d, pts, colour):
    d.polygon([(round(p[0], 2), round(p[1], 2)) for p in pts], fill=colour)


def d_ellipse(d, cx, cy, rx, ry, colour):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=colour)


def d_rect(d, x0, y0, x1, y1, colour):
    d.rectangle([x0, y0, x1, y1], fill=colour)


def d_arc(d, pts, colour, w, order=8):
    """Tapered 'brush' stroke through ``pts`` -- wide in the middle."""
    pts = [(float(p[0]), float(p[1])) for p in pts]
    if len(pts) < 2:
        return
    seg = []
    total = 0.0
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        ln = math.hypot(x1 - x0, y1 - y0) or 1e-3
        seg.append((x0, y0, x1, y1, ln))
        total += ln
    done = 0.0
    for (x0, y0, x1, y1, ln) in seg:
        chunks = max(1, int(ln / 2.0) + 1)
        for k in range(chunks + 1):
            t = done / total + (ln * (k / chunks)) / total
            tt = (k / chunks) if chunks else 0.0
            x = lerp(x0, x1, tt)
            y = lerp(y0, y1, tt)
            f = math.sin(math.pi * max(0.0, min(1.0, t)))
            ww = max(0.35, w * (0.35 + 0.65 * f))
            d_ellipse(d, x, y, ww, ww, colour)
        done += ln
    for p in pts:
        d_ellipse(d, p[0], p[1], w * 0.5, w * 0.5, colour)


def d_line_to(d, p0, p1, w, colour, order=8):
    d_arc(d, [p0, p1], colour, w, order)


def limb(d, root, theta, length, w0, w1, colour, order=8):
    """Tapered capsule from ``root`` at ``theta`` (0 = +x, 90 = down)."""
    a = math.radians(theta)
    tip = (root[0] + math.cos(a) * length, root[1] + math.sin(a) * length)
    nx, ny = -math.sin(a), math.cos(a)
    h0, h1 = w0 * 0.5, w1 * 0.5
    quad = [
        (root[0] + nx * h0, root[1] + ny * h0),
        (tip[0] + nx * h1, tip[1] + ny * h1),
        (tip[0] - nx * h1, tip[1] - ny * h1),
        (root[0] - nx * h0, root[1] - ny * h0),
    ]
    d_poly(d, quad, colour)
    d_ellipse(d, root[0], root[1], h0, h0, colour)
    d_ellipse(d, tip[0], tip[1], h1, h1, colour)
    return tip


def limb2(d, root, t1, l1, t2, l2, w0, w1, w2, colour, order=8):
    elbow = limb(d, root, t1, l1, w0, w1, colour, order)
    end = limb(d, elbow, t2, l2, w1, w2, colour, order)
    return elbow, end


def eye_glow(d, p, r, base=C_AMBER, hot=True, order=11):
    """Amber eye with additive-looking glow rings (alpha only)."""
    x, y = p
    d_ellipse(d, x, y, r * 2.7, r * 2.0, col(base, 30))
    d_ellipse(d, x, y, r * 1.9, r * 1.5, col(base, 55))
    d_ellipse(d, x, y, r * 1.25, r * 1.1, col(base, 100))
    d_ellipse(d, x, y, r, r * 0.9, col(base, 185))
    if hot:
        d_ellipse(d, x, y, r * 0.45, r * 0.42, col(C_WAX, 170))


def gaussian_alpha(layer, radius):
    a = layer.getchannel("A").filter(ImageFilter.GaussianBlur(radius))
    out = layer.copy()
    out.putalpha(a)
    return out


def glow_blob(size, p, r, colour, alpha, scale, blur=None):
    """Soft radial pool of light (one palette colour, varying alpha)."""
    lay = nlayer(size)
    d = ScaledDraw(lay, scale)
    d_ellipse(d, p[0] * scale, p[1] * scale, r * scale, r * scale, col(colour, alpha))
    if blur is None:
        blur = max(1.0, r * scale * 0.42)
    return gaussian_alpha(lay, blur)


def gear(d, cx, cy, radius, teeth, tooth_h, colour, spoke_w=None, rings=1, phase=0.0):
    """A cog silhouette (teeth + spokes + hub)."""
    step = 2.0 * math.pi / teeth
    for i in range(teeth):
        a = phase + i * step
        a0, a1 = a - step * 0.34, a + step * 0.34
        pts = []
        for aa in (a0, a1):
            pts.append((cx + math.cos(aa) * radius, cy + math.sin(aa) * radius))
        for aa in (a1, a0):
            pts.append((cx + math.cos(aa) * (radius + tooth_h), cy + math.sin(aa) * (radius + tooth_h)))
        d_poly(d, pts, colour)
    d_ellipse(d, cx, cy, radius, radius, colour)
    for k in range(rings):
        rr = radius * (0.34 + 0.22 * k)
        d_ellipse(d, cx, cy, rr, rr, colour)
    if spoke_w:
        for i in range(max(4, teeth // 2)):
            a = phase + i * (2.0 * math.pi / max(4, teeth // 2))
            limb(d, (cx, cy), math.degrees(a), radius * 0.94, spoke_w, spoke_w * 0.8, colour)


# --------------------------------------------------------------------------
# shared humanoid skeleton
# --------------------------------------------------------------------------

# joints, relative to the hip (0,0); +x = the character's LEFT on screen.
J = {
    "hip":      (0.0, 0.0),
    "chest":    (0.0, -13.0),
    "neck":     (0.0, -15.0),
    "head":     (-0.8, -21.2),
    "shoulderL": (6.0, -13.2),
    "shoulderR": (-6.0, -13.2),
    "earL":     (5.0, -21.2),
    "earR":     (-5.6, -21.2),
}


def frame(hp, p):
    """Resolve joints in screen space.

    ``p`` keys: phi, lean, bob, a1/a2, b1/b2, legL1/legL2, legR1/legR2,
    headTilt, hatT, splay, armStretch; optional `hipoff` (dx, dy).
    """
    M = mrot(p.get("phi", 0.0))
    proj = lambda pp: add(hp, M(*pp))
    splay = p.get("splay", 1.0)
    shw = p.get("shw", 1.0)
    af = p.get("armStretch", 1.0)
    lf = p.get("legStretch", 1.0)
    aL1 = p.get("aL1", p.get("a1", 112.0))
    aL2 = p.get("aL2", p.get("a2", 102.0))
    aR1 = p.get("aR1", p.get("b1", 68.0))
    aR2 = p.get("aR2", p.get("b2", 78.0))
    lL1 = p.get("lL1", p.get("legL1", 83.0))
    lL2 = p.get("lL2", p.get("legL2", 90.0))
    lR1 = p.get("lR1", p.get("legR1", 86.0))
    lR2 = p.get("lR2", p.get("legR2", 90.0))

    hip = proj(J["hip"])
    shL = proj(J["shoulderL"])
    shR = proj(J["shoulderR"])
    if shw != 1.0:
        shL = (hip[0] + (shL[0] - hip[0]) * shw, shL[1])
        shR = (hip[0] + (shR[0] - hip[0]) * shw, shR[1])
    elL = limb_pt(shL, aL1, 9.2 * af)
    haL = limb_pt(elL, aL2, 8.8 * af)
    elR = limb_pt(shR, aR1, 9.2 * af)
    haR = limb_pt(elR, aR2, 8.8 * af)

    kL = limb_pt(hip, lL1, 9.2 * lf)
    ftL = limb_pt(kL, lL2, 8.8 * lf)
    kR = limb_pt(hip, lR1, 9.2 * lf)
    ftR = limb_pt(kR, lR2, 8.8 * lf)

    def splay_pt(pt, sign):
        dx = (pt[0] - hip[0]) * splay * sign
        return (hip[0] + dx, pt[1])

    return {
        "M": M, "proj": proj, "hip": hip,
        "chest": proj(J["chest"]), "neck": proj(J["neck"]),
        "head": proj(J["head"]), "earL": proj(J["earL"]), "earR": proj(J["earR"]),
        "shL": shL, "shR": shR, "elL": elL, "haL": haL, "elR": elR, "haR": haR,
        "kL": splay_pt(kL, 1.0), "ftL": splay_pt(ftL, 1.0),
        "kR": splay_pt(kR, -1.0), "ftR": splay_pt(ftR, -1.0),
        "headTilt": p.get("headTilt", 0.0),
        "hatT": p.get("hatT", 0.0),
        "bob": p.get("bob", 0.0),
        "phi": p.get("phi", 0.0),
    }


def limb_pt(root, theta, length):
    a = math.radians(theta)
    return (root[0] + math.cos(a) * length, root[1] + math.sin(a) * length)


# ==========================================================================
#  PLAYER
# ==========================================================================

HAT_CLR = C_BG


def draw_player(d, f, p, scale=1.0):
    """The detective.  ``f`` = resolved joints, ``p`` = pose dict."""
    dark = col(HAT_CLR, 255)
    dark2 = col(HAT_CLR, 228)
    coat = col(BG, 255)
    coat_back = col(BG, 252)
    trous = col(BG, 246)
    burn = col(RED, 175)

    hip, chest = f["hip"], f["chest"]
    shL, shR = f["shL"], f["shR"]
    head = f["head"]
    M = f["M"]

    hem = p.get("hemSway", 0.0)
    trail = p.get("coatTrail", 0.0)
    sweep = p.get("coatSweep", 0.0)
    flare = p.get("coatFlare", 0.0)

    # ---- notebook swing trail (pale arc, active frames) -----------------
    if p.get("nbSwing"):
        cxx, cyy = shL
        for (R, a0, sweep, wid, alpha) in ((19.5, -24.0, 76.0, 2.4, 205),
                                           (22.4, -14.0, 52.0, 1.5, 120)):
            pts = []
            n = 14
            for i in range(n + 1):
                a = math.radians(a0 + (i / n) * sweep)
                pts.append((cxx + math.cos(a) * R, cyy + math.sin(a) * R))
            d_arc(d, pts, col(BONE, alpha), wid)
        a = math.radians(52.0)
        tipx, tipy = cxx + math.cos(a) * 19.5, cyy + math.sin(a) * 19.5
        d_ellipse(d, tipx, tipy, 1.8, 1.8, col(C_WAX, 240))
        d_ellipse(d, tipx, tipy, 3.4, 3.4, col(C_WAX, 60))

    # ---- coat tails (behind) --------------------------------------------
    d_poly(d, [
        (chest[0] - 7.6, chest[1] - 2),
        (hip[0] - 8.6, hip[1] + 3),
        (hip[0] - 11.6 - flare - trail, hip[1] + 17.6 + sweep),
        (hip[0] - 2.0 - trail, hip[1] + 8.0),
    ], coat_back)

    # ---- legs -----------------------------------------------------------
    for (k, ft) in ((f["kL"], f["ftL"]), (f["kR"], f["ftR"])):
        limb(d, hip, ang(hip, k), dist(hip, k), 7.0, 5.8, trous)
        limb(d, k, ang(k, ft), dist(k, ft), 5.8, 5.0, trous)
        # boot
        bx, by = ft
        d_poly(d, [(bx - 3.6, by - 1.6), (bx + 5.4, by - 1.6),
                   (bx + 6.0, by + 1.6), (bx - 4.0, by + 1.6)], dark)

    # ---- torso / coat ---------------------------------------------------
    torso = [
        (shL[0] + 1.4, shL[1] - 1.2),
        (shR[0] - 1.4, shR[1] - 1.2),
        (hip[0] - 7.4, hip[1] + 1.0),
        (hip[0] + 7.4, hip[1] + 1.0),
    ]
    d_poly(d, torso, coat)
    # flared hem (A-line)
    hem_pts = []
    steps = 10
    for i in range(steps + 1):
        t = i / steps
        d2 = 1.0 - abs(2.0 * t - 1.0)
        x = lerp(hip[0] - 11.2, hip[0] + 11.2, t)
        y = hip[1] + 8.0 + 9.0 * (t * t) + hem * d2 + sweep
        hem_pts.append((x, y))
    d_poly(d, [(hip[0] + 7.8, hip[1] + 0.5)] + hem_pts + [(hip[0] - 7.8, hip[1] + 0.5)], coat)
    # coat split line (very subtle, same family)
    d_arc(d, [(hip[0], hip[1] + 3.0), (hip[0] - 1.4, hip[1] + 16.0)], col(BG, 95), 0.9)

    # ---- collar / scarf -------------------------------------------------
    d_poly(d, [
        (shL[0] + 3.0, shL[1] - 1.8),
        (shL[0] - 1.2, shL[1] + 3.4),
        (f["neck"][0] - 0.4, f["neck"][1] + 2.6),
        (shR[0] - 2.4, shR[1] - 1.8),
    ], dark2)

    # ---- back arm -------------------------------------------------------
    ar = p.get("armR", (f["elR"], f["haR"]))
    limb(d, shR, ang(shR, ar[0]), dist(shR, ar[0]), 6.2, 5.2, dark2)
    limb(d, ar[0], ang(ar[0], ar[1]), dist(ar[0], ar[1]), 5.2, 4.6, dark2)
    d_ellipse(d, ar[1][0], ar[1][1], 2.8, 2.8, dark2)

    # ---- head -----------------------------------------------------------
    hx0, hy0 = head
    ht = math.radians(f["headTilt"])
    def rp(dx, dy):
        c, s = math.cos(ht), math.sin(ht)
        X, Y = dx * c - dy * s, dx * s + dy * c
        return add((hx0, hy0), M(X, Y))

    d_poly(d, [rp(-5.0, -4.0), rp(5.0, -4.0), rp(5.4, 2.6), rp(0.6, 6.8), rp(-4.4, 5.6)], coat)
    # jaw shadow
    d_poly(d, [rp(-3.6, 2.6), rp(4.4, 2.6), rp(0.4, 6.6)], col(BG, 255))

    # burn scar on the RIGHT half of the face (screen -x side)
    scar = [rp(-0.6, -1.8), rp(-3.8, -2.2), rp(-4.6, 1.8), rp(-2.8, 5.0), rp(-0.4, 3.4)]
    d_poly(d, scar, burn)
    d_poly(d, [rp(-2.2, -0.6), rp(-4.2, 0.4), rp(-3.6, 3.0), rp(-1.8, 2.0)], col(ORANGE, 96))

    # ---- hat ------------------------------------------------------------
    hatT = f["hatT"]
    rad = math.radians(hatT)
    ct, st = math.cos(rad), math.sin(rad)

    def hp(dx, dy):
        X, Y = dx, dy
        X, Y = X * ct - Y * st, X * st + Y * ct
        return add((hx0, hy0), M(X, Y))

    brimY = -7.0
    brim_tilt = p.get("brimTilt", 0.0)
    hat_lag = p.get("hatLag", 0.0)
    # trailing brim ghost while sprinting
    if hat_lag > 0.4:
        d_poly(d, [hp(-16.0 - hat_lag, brimY - 1.2), hp(16.0 - hat_lag, brimY - 1.2),
                   hp(15.0 - hat_lag * 1.4, brimY + 3.8), hp(-14.6 - hat_lag * 1.4, brimY + 4.4)],
              col(BG, 165))
    brim = [
        hp(-16.4 + brim_tilt, brimY - 1.6),
        hp(-6.0 + brim_tilt * 0.5, brimY - 3.2),
        hp(6.0, brimY - 2.8),
        hp(16.4, brimY + 0.2),
        hp(9.0, brimY + 3.0),
        hp(-7.4, brimY + 3.6),
        hp(-16.0, brimY + 2.4),
    ]
    d_poly(d, brim, dark)
    # brim underside lip
    d_poly(d, [hp(-15.2 + brim_tilt, brimY + 1.6), hp(15.4, brimY + 1.0),
               hp(9.0, brimY + 3.0), hp(-7.4, brimY + 3.6)], col(HAT_CLR, 205))
    # crown (tall, tapered)
    d_poly(d, [
        hp(-8.2, brimY - 0.6),
        hp(-7.2, brimY - 14.6),
        hp(-5.4, brimY - 17.6),
        hp(2.4, brimY - 18.6),
        hp(6.0, brimY - 16.0),
        hp(7.6, brimY - 0.6),
    ], dark)
    # hat band
    d_poly(d, [hp(-7.6, brimY - 3.8), hp(7.4, brimY - 4.0), hp(7.2, brimY - 6.2), hp(-7.4, brimY - 6.0)],
          col(BG, 255))

    # ---- eye highlight (the single readable feature) --------------------
    eyed = p.get("eye", (3.4, -3.4))
    eye_glow(d, hp(eyed[0], eyed[1]), 1.25, AMBER, True)

    # ---- front arm ------------------------------------------------------
    al = p.get("armL", (f["elL"], f["haL"]))
    limb(d, shL, ang(shL, al[0]), dist(shL, al[0]), 6.4, 5.4, coat)
    limb(d, al[0], ang(al[0], al[1]), dist(al[0], al[1]), 5.4, 4.7, coat)
    d_ellipse(d, al[1][0], al[1][1], 2.9, 2.9, coat)

    # ---- notebook -------------------------------------------------------
    nb = p.get("nb", 1.0)
    if nb > 0.0:
        a = al[1]
        nbA = (p.get("nbA", 0.0) + ang(al[0], a) * 0.22)
        r = math.radians(nbA)
        ca, sa = math.cos(r), math.sin(r)
        cx, cy = a[0] - 0.6, a[1] + 0.8
        pts = []
        for (ddx, ddy) in ((-5.8, -4.3), (5.8, -3.9), (6.1, 4.1), (-5.4, 4.4)):
            X, Y = ddx * nb, ddy * nb
            pts.append((cx + X * ca - Y * sa, cy + X * sa + Y * ca))
        d_poly(d, pts, col(BONE, 250))
        # page block edge
        d_poly(d, [pts[0], pts[1], mid(pts[1], pts[2], 0.16), mid(pts[0], pts[3], 0.16)], col(STONE, 165))


def ang(a, b):
    return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))


def dist(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])


def P(**kw):
    return kw


def HIP_ANCHOR():
    return (31.4, 41.0)


def draw_player_frame(size, pose, scale):
    W, H = size
    lay = nlayer((W * scale, H * scale))
    d = ScaledDraw(lay, scale)
    hx, hy = HIP_ANCHOR()
    f = frame((hx + pose.get("dx", 0.0), hy + pose.get("bob", 0.0)), pose)
    draw_player(d, f, pose, scale)
    return lay


# ---------------------------------------------------------------- poses ---

def poses_player():
    """All player poses.  Angle convention: 0 = +x (towards the hat brim's
    overhang), 90 = straight down.  Idle arms hang at ~84/58 degrees."""
    anims = {}

    # ---- idle: breathing, ~1px bob, coat sway ---------------------------
    anims["player_idle"] = [
        P(bob=0.0, aL1=84, aR1=58, aL2=96, aR2=80, hemSway=0.5, headTilt=-1.2),
        P(bob=-0.5, aL1=85, aR1=57, aL2=97, aR2=81, hemSway=0.1, headTilt=-0.6),
        P(bob=-1.0, aL1=86, aR1=56, aL2=98, aR2=82, hemSway=-0.4, headTilt=0.2, eye=(3.6, -3.6)),
        P(bob=-0.6, aL1=85, aR1=57, aL2=97, aR2=81, hemSway=-0.7, headTilt=0.8),
        P(bob=0.0, aL1=84, aR1=58, aL2=96, aR2=80, hemSway=-0.2, headTilt=0.4),
        P(bob=0.3, aL1=83.5, aR1=58.5, aL2=95.5, aR2=79.5, hemSway=0.3, headTilt=-0.4),
    ]

    # ---- run: 8-frame stride --------------------------------------------
    run = []
    legL = [(122, 100), (108, 132), (88, 134), (68, 116),
            (56, 104), (70, 134), (96, 138), (114, 112)]
    legR = [(56, 104), (70, 134), (96, 138), (114, 112),
            (122, 100), (108, 132), (88, 134), (68, 116)]
    for i in range(8):
        s = math.sin(2 * math.pi * i / 8)
        c = math.cos(2 * math.pi * i / 8)
        run.append(P(
            lean=8.0 + 2.5 * c,
            bob=-1.4 - 1.5 * abs(c),
            lL1=legL[i][0], lL2=legL[i][1], lR1=legR[i][0], lR2=legR[i][1],
            aL1=86 + 44 * s, aL2=96 + 26 * s,
            aR1=86 - 44 * s, aR2=96 - 26 * s,
            hemSway=-3.0 * s, coatTrail=2.6, hatLag=1.3, hatT=-4.0, headTilt=-2.0,
            eye=(3.6, -3.4),
        ))
    anims["player_run"] = run

    # ---- jump: crouch -> launch -> apex --------------------------------
    anims["player_jump"] = [
        P(bob=2.8, aL1=104, aR1=42, aL2=130, aR2=118, lL1=104, lL2=136, lR1=70, lR2=128,
          hemSway=0.0, headTilt=2.0),
        P(bob=-3.4, aL1=52, aR1=96, aL2=22, aR2=44, lL1=84, lL2=90, lR1=88, lR2=92,
          coatFlare=2.4, coatTrail=1.6, hatLag=1.0, headTilt=-3.0),
        P(bob=-5.0, aL1=32, aR1=126, aL2=4, aR2=24, lL1=104, lL2=148, lR1=66, lR2=112,
          coatFlare=3.2, coatSweep=-1.6, coatTrail=2.2, hatLag=1.4, hatT=-3.0),
    ]
    anims["player_fall"] = [
        P(bob=-2.4, aL1=28, aR1=132, aL2=0, aR2=30, lL1=104, lL2=132, lR1=70, lR2=108,
          coatFlare=2.0, coatSweep=-1.0, hatLag=0.7, headTilt=2.4),
        P(bob=-3.2, aL1=22, aR1=138, aL2=-8, aR2=18, lL1=110, lL2=142, lR1=64, lR2=100,
          coatFlare=3.6, coatSweep=-2.0, coatTrail=1.2, hatLag=1.2, headTilt=3.2),
        P(bob=-2.2, aL1=34, aR1=128, aL2=6, aR2=26, lL1=100, lL2=136, lR1=74, lR2=112,
          coatFlare=2.6, coatSweep=-1.4, coatTrail=1.8, hatLag=0.8, headTilt=1.6),
    ]

    # ---- attack: 6 frames (wind-up / active swing / follow-through) -----
    anims["player_attack"] = [
        P(lean=-3, bob=0.4, aL1=104, aL2=126, aR1=76, aR2=112, lL1=80, lR1=90,
          hemSway=1.6, headTilt=-4, nb=1.0, nbA=-8),
        P(lean=-7, bob=0.9, aL1=122, aL2=158, aR1=98, aR2=142, lL1=74, lR1=96,
          hemSway=2.6, headTilt=-7, nb=1.06, nbA=-24),
        P(lean=4, bob=-0.7, aL1=44, aL2=-8, aR1=48, aR2=-14, lL1=94, lR1=80,
          hemSway=-2.2, headTilt=3, nb=1.06, nbA=6, nbSwing=True),
        P(lean=9, bob=-0.5, aL1=20, aL2=-42, aR1=16, aR2=-48, lL1=100, lR1=74,
          hemSway=-3.2, headTilt=6, nb=1.0, nbA=22, nbSwing=True),
        P(lean=7, bob=0.2, aL1=36, aL2=-12, aR1=30, aR2=-20, lL1=98, lR1=80,
          hemSway=-2.4, headTilt=5, nb=1.0, nbA=30),
        P(lean=3, bob=0.7, aL1=72, aL2=62, aR1=66, aR2=56, lL1=92, lR1=86,
          hemSway=0.0, headTilt=1, nb=0.96, nbA=14),
    ]

    # ---- hit ------------------------------------------------------------
    anims["player_hit"] = [
        P(lean=-12, bob=-0.8, aL1=112, aR1=30, aL2=142, aR2=8, lL1=92, lL2=98, lR1=82, lR2=86,
          headTilt=-7, hatLag=2.6, hemSway=3.0, eye=(3.8, -3.0)),
        P(lean=-7, bob=0.2, aL1=104, aR1=40, aL2=128, aR2=22, lL1=90, lL2=96, lR1=82, lR2=86,
          headTilt=-4, hatLag=1.2, hemSway=2.0, eye=(3.6, -3.4)),
    ]

    # ---- death: stagger -> knees buckle -> crumple -> huddled ------------
    # The hip drops via `bob`, the legs fold via `legStretch`, and the torso
    # only tips to phi=-58 so the hat stays obviously on the head.
    anims["player_death"] = [
        P(bob=-0.6, dx=0.0, phi=-5, aL1=112, aR1=28, aL2=148, aR2=4, lL1=88, lL2=94, lR1=78, lR2=86,
          headTilt=-7, hatLag=2.2, hemSway=2.6, hatT=-3),
        P(bob=1.8, dx=-0.6, phi=-13, aL1=118, aR1=34, aL2=156, aR2=10, lL1=94, lL2=104, lR1=72, lR2=90,
          headTilt=-10, hatLag=1.6, hemSway=1.4, hatT=-2),
        P(bob=4.6, dx=-1.6, phi=-24, aL1=130, aR1=48, aL2=170, aR2=26, lL1=102, lL2=124, lR1=66, lR2=100,
          legStretch=0.94, headTilt=-12, hatLag=1.0, hemSway=0.6, hatT=-1),
        P(bob=7.4, dx=-2.6, phi=-36, aL1=142, aR1=66, aL2=182, aR2=46, lL1=112, lL2=150, lR1=60, lR2=112,
          legStretch=0.86, headTilt=-13, hemSway=0.0, brimTilt=1.5),
        P(bob=9.8, dx=-3.6, phi=-47, aL1=152, aR1=84, aL2=190, aR2=68, lL1=122, lL2=172, lR1=54, lR2=124,
          legStretch=0.76, headTilt=-12, brimTilt=3.0),
        P(bob=11.4, dx=-4.4, phi=-58, aL1=162, aR1=100, aL2=198, aR2=92, lL1=130, lL2=186, lR1=48, lR2=132,
          legStretch=0.68, headTilt=-10, brimTilt=4.5, eye=(3.0, -4.0)),
    ]

    # ---- interact: lean in, open the notebook --------------------------
    anims["player_interact"] = [
        P(aL1=80, aL2=90, aR1=60, aR2=80, hemSway=0.0, headTilt=0.0),
        P(lean=3, aL1=34, aL2=2, aR1=52, aR2=48, hemSway=0.8, headTilt=1.6, nbA=14),
        P(lean=5, aL1=14, aL2=-16, aR1=44, aR2=34, hemSway=1.2, headTilt=2.6, nbA=24),
        P(lean=2, aL1=54, aL2=34, aR1=62, aR2=64, hemSway=0.4, headTilt=1.0, nbA=10),
    ]

    # ---- climb ----------------------------------------------------------
    anims["player_climb"] = [
        P(lean=5, aL1=-142, aL2=-166, aR1=-44, aR2=-20, lL1=118, lL2=68, lR1=62, lR2=112,
          headTilt=-7, hatT=-7, hemSway=-2.0),
        P(lean=4, aL1=-124, aL2=-150, aR1=-66, aR2=-38, lL1=104, lL2=84, lR1=78, lR2=98,
          headTilt=-5, hatT=-6, hemSway=-1.2),
        P(lean=5, aL1=-44, aL2=-20, aR1=-142, aR2=-166, lL1=62, lL2=112, lR1=118, lR2=68,
          headTilt=-7, hatT=-7, hemSway=-2.0),
        P(lean=4, aL1=-66, aL2=-38, aR1=-124, aR2=-150, lL1=78, lL2=98, lR1=104, lR2=84,
          headTilt=-5, hatT=-6, hemSway=-1.2),
    ]

    return anims


# ==========================================================================
#  ENEMIES / NPCs
# ==========================================================================

def apply_globals(anims, **glob):
    """Stamp shared pose parameters onto every frame of every animation."""
    for poses in anims.values():
        for p in poses:
            for k, v in glob.items():
                p.setdefault(k, v)
    return anims


def draw_wax_dummy(d, f, p, scale=1.0, r=None):
    """Humanoid wax mannequin: pale wax body, drips, NO eyes."""
    r = r or rng("wax")
    body = col(WAX, 238)
    body_d = col(wpct(WAX, BONE, 0.18), 236)
    drip = col(WAX, 232)
    hip, chest, head = f["hip"], f["chest"], f["head"]
    shL, shR = f["shL"], f["shR"]

    melt = p.get("melt", 0.0)
    puddle = p.get("puddle", 1.0)

    # puddle at the feet
    if puddle > 0.05:
        d_ellipse(d, hip[0] - 0.4, hip[1] + 15.0, 9.0 * puddle, 2.1 * puddle, col(WAX, 120))

    # drips hanging behind the body
    drip_pts = [(shL[0] + 4, shL[1] + 3), (shR[0] - 4, shR[1] + 4),
                (hip[0] - 7, hip[1] + 2), (hip[0] + 7, hip[1] + 3),
                (head[0] + 4.4, head[1] + 3.0), (head[0] - 4.6, head[1] + 2.2)]
    for i, dp in enumerate(drip_pts):
        ln = 2.4 + 1.8 * r.random() + melt * 4.6
        w = 1.1 + 0.5 * r.random()
        d_arc(d, [dp, (dp[0] + r.uniform(-0.6, 0.6), dp[1] + ln)], drip, w * 2.0)
        d_ellipse(d, dp[0], dp[1] + ln, w * 0.75, w * 1.0, drip)

    # legs
    for (k, ft) in ((f["kL"], f["ftL"]), (f["kR"], f["ftR"])):
        limb(d, hip, ang(hip, k), dist(hip, k), 6.8, 5.6, body)
        limb(d, k, ang(k, ft), dist(k, ft), 5.6, 5.0, body)
        bx, by = ft
        d_ellipse(d, bx + 0.2, by + 0.9, 5.0, 2.3, body)

    # torso: soft, slightly bulging barrel
    torso = [
        (shL[0] + 1.6, shL[1] - 1.4), (shR[0] - 1.6, shR[1] - 1.4),
        (hip[0] - 7.2, hip[1] + 2.4), (hip[0] + 7.2, hip[1] + 2.4),
    ]
    d_poly(d, torso, body)
    d_ellipse(d, hip[0], hip[1] + 1.0, 7.4, 4.2, body)
    # melted shoulder lumps
    d_ellipse(d, shL[0] + 0.4, shL[1] + 0.8, 3.2, 2.4, body)
    d_ellipse(d, shR[0] - 0.4, shR[1] + 0.8, 3.2, 2.4, body)

    # back arm
    ar = p.get("armR", (f["elR"], f["haR"]))
    limb(d, shR, ang(shR, ar[0]), dist(shR, ar[0]) * p.get("armStretch", 1.0), 6.0, 5.0, body_d)
    limb(d, ar[0], ang(ar[0], ar[1]), dist(ar[0], ar[1]) * p.get("armStretch", 1.0), 5.0, 4.4, body_d)
    d_ellipse(d, ar[1][0], ar[1][1], 2.8, 2.8, body_d)

    # head: smooth, featureless
    hx0, hy0 = head
    M = f["M"]
    ht = math.radians(f["headTilt"])
    def rp(dx, dy):
        X, Y = dx, dy
        c, s = math.cos(ht), math.sin(ht)
        X, Y = X * c - Y * s, X * s + Y * c
        return add((hx0, hy0), M(X, Y))
    d_poly(d, [rp(-4.6, -4.2), rp(4.6, -4.2), rp(5.2, 1.6), rp(1.0, 6.0), rp(-4.0, 5.0)], body)
    # melted forehead/chin asymmetry -- deliberately NO eyes, NO mouth
    d_ellipse(d, *rp(3.6, 4.2), 1.5, 1.1, body)

    # front arm
    al = p.get("armL", (f["elL"], f["haL"]))
    limb(d, shL, ang(shL, al[0]), dist(shL, al[0]) * p.get("armStretch", 1.0), 6.2, 5.2, body)
    limb(d, al[0], ang(al[0], al[1]), dist(al[0], al[1]) * p.get("armStretch", 1.0), 5.2, 4.6, body)
    d_ellipse(d, al[1][0], al[1][1], 2.9, 2.9, body)
    return None


def poses_wax_dummy():
    anims = {}
    anims["wax_dummy_idle"] = [
        P(bob=0.0, aL1=104, aR1=76, aL2=98, aR2=84, melt=0.0, puddle=1.0),
        P(bob=-0.5, aL1=105, aR1=75, aL2=99, aR2=85, melt=0.2, puddle=1.02, headTilt=-1),
        P(bob=-0.9, aL1=106, aR1=74, aL2=100, aR2=86, melt=0.4, puddle=1.05, headTilt=-1.6),
        P(bob=-0.4, aL1=105, aR1=75, aL2=99, aR2=85, melt=0.2, puddle=1.02, headTilt=-0.6),
    ]
    w = []
    for i in range(6):
        s = math.sin(2 * math.pi * i / 6)
        w.append(P(bob=-0.6 - 0.6 * abs(math.cos(2 * math.pi * i / 6)),
                   lL1=90 + 22 * s, lL2=92 + 12 * s, lR1=90 - 22 * s, lR2=92 - 12 * s,
                   aL1=104 - 16 * s, aL2=98 - 10 * s, aR1=76 + 16 * s, aR2=84 + 10 * s,
                   melt=0.3, puddle=1.1, headTilt=-2 * s, hatT=6 * s))
    anims["wax_dummy_walk"] = w
    anims["wax_dummy_attack"] = [
        P(lean=-6, aL1=128, aL2=156, aR1=126, aR2=166, legL1=82, legR1=98, armStretch=1.05, melt=0.4),
        P(lean=-10, aL1=142, aL2=172, aR1=140, aR2=182, legL1=76, legR1=102, armStretch=1.1, melt=0.6),
        P(lean=6, aL1=40, aL2=-8, aR1=36, aR2=-14, legL1=96, legR1=84, armStretch=1.2, melt=0.8),
        P(lean=10, aL1=24, aL2=-34, aR1=20, aR2=-40, legL1=100, legR1=80, armStretch=1.25, melt=1.0),
        P(lean=4, aL1=70, aL2=48, aR1=66, aR2=42, legL1=94, legR1=86, armStretch=1.1, melt=0.6),
    ]
    anims["wax_dummy_hit"] = [
        P(lean=-12, bob=-0.8, aL1=132, aR1=50, aL2=158, aR2=24, headTilt=-6, meltsplash=True, melt=1.2),
        P(lean=-7, bob=0.0, aL1=124, aR1=58, aL2=144, aR2=34, headTilt=-3, melt=0.8),
    ]
    anims["wax_dummy_death"] = [
        P(bob=0.6, phi=-8, lean=-10, aL1=126, aR1=56, aL2=150, aR2=30, headTilt=-6, melt=1.0),
        P(bob=3.0, phi=-22, aL1=118, aR1=66, aL2=150, aR2=48, lL1=108, lL2=142, lR1=78, lR2=116, melt=1.6, puddle=1.3),
        P(bob=6.6, phi=-46, aL1=126, aR1=88, aL2=164, aR2=136, lL1=116, lL2=156, lR1=72, lR2=120, melt=2.4, puddle=1.6),
        P(bob=9.6, phi=-72, aL1=140, aR1=110, aL2=176, aR2=158, lL1=124, lL2=162, lR1=66, lR2=126, melt=3.2, puddle=2.0),
        P(bob=11.4, phi=-88, aL1=156, aR1=134, aL2=188, aR2=176, lL1=130, lL2=170, lR1=60, lR2=132, melt=4.0, puddle=2.6),
    ]
    return apply_globals(anims, shw=1.28, splay=0.78)


def draw_child_ghost(d, f, p, scale=1.0, r=None):
    """Small translucent child silhouette with trailing wisps."""
    r = r or rng("ghost")
    fade = p.get("fade", 1.0)
    base_a = int(150 * fade)
    body = col(BONE, base_a)
    body2 = col(PURP, int(base_a * 1.15))
    ghost = p.get("ghost", 0.0)   # upward drift of the trailing hem
    hip, chest, head = f["hip"], f["chest"], f["head"]
    shL, shR = f["shL"], f["shR"]

    # trailing wisps (behind)
    for i in range(5):
        wx = hip[0] + r.uniform(-6, 6)
        wy = hip[1] + 8 + r.uniform(0, 12) + ghost
        d_arc(d, [(wx, hip[1] + 2), (wx + r.uniform(-3, 3), wy)], col(PURP, int(base_a * 0.5)), 3.0)
        d_ellipse(d, wx, wy, r.uniform(1.2, 2.4), r.uniform(1.2, 2.4), col(PURP, int(base_a * 0.55)))

    # tattered dress
    dress = [
        (shL[0] + 1.4, shL[1] - 1.0), (shR[0] - 1.4, shR[1] - 1.0),
        (hip[0] - 8.6, hip[1] + 15.0 + ghost), (hip[0] + 8.6, hip[1] + 15.0 + ghost),
    ]
    d_poly(d, dress, body2)
    d_poly(d, [(hip[0] + 8.6, hip[1] + 15.0 + ghost), (hip[0] + 6.0, hip[1] + 4.0),
               (hip[0] - 6.0, hip[1] + 4.0), (hip[0] - 8.6, hip[1] + 15.0 + ghost),
               (hip[0] - 2.0, hip[1] + 12.0 + ghost), (hip[0] + 2.4, hip[1] + 16.5 + ghost)], body)

    # little arms
    for (sh, a1, a2, w) in ((shR, p.get("aR1", 78), p.get("aR2", 88), 3.6),
                            (shL, p.get("aL1", 102), p.get("aL2", 94), 3.8)):
        e = limb(d, sh, a1, 7.0, w, w * 0.85, body2)
        h = limb(d, e, a2, 6.4, w * 0.85, w * 0.75, body2)
        d_ellipse(d, h[0], h[1], w * 0.5, w * 0.5, body)

    # head + hair
    hx0, hy0 = head
    M = f["M"]
    d_ellipse(d, hx0, hy0, 5.2, 5.4, body)
    d_poly(d, [(hx0 - 5.4, hy0 - 1.0), (hx0 + 5.4, hy0 - 1.0),
               (hx0 + 4.4, hy0 - 6.6), (hx0 - 4.4, hy0 - 6.6)], body2)
    for i in range(3):
        sx = hx0 - 4.0 + i * 3.6
        d_arc(d, [(sx, hy0 - 4.0), (sx + r.uniform(-1.5, 1.5), hy0 + 5.0)], col(PURP, int(base_a * 0.6)), 1.4)


def poses_child_ghost():
    def mk(a):
        return [
            P(bob=a, aL1=104, aR1=76, aL2=96, aR2=84, ghost=0.0, fade=1.0),
            P(bob=a - 1.4, aL1=106, aR1=74, aL2=98, aR2=86, ghost=1.2, fade=0.92),
            P(bob=a - 2.2, aL1=108, aR1=72, aL2=100, aR2=88, ghost=2.0, fade=0.85),
            P(bob=a - 1.0, aL1=106, aR1=74, aL2=98, aR2=86, ghost=0.8, fade=0.94),
        ]
    return apply_globals({"child_ghost_idle": mk(-1.0), "child_ghost_float": mk(-4.0)}, shw=0.82, splay=1.5)


def draw_townsman(d, f, p, scale=1.0, r=None):
    """Grey-clothed villager (everyone in town wears grey)."""
    r = r or rng("townsman")
    cloth = col(MID, 255)
    cloth_d = col(BLUE, 255)
    skin = col(STONE, 255)
    hip, chest, head = f["hip"], f["chest"], f["head"]
    shL, shR = f["shL"], f["shR"]

    # legs
    for (k, ft) in ((f["kL"], f["ftL"]), (f["kR"], f["ftR"])):
        limb(d, hip, ang(hip, k), dist(hip, k), 6.6, 5.6, cloth_d)
        limb(d, k, ang(k, ft), dist(k, ft), 5.6, 5.0, cloth_d)
        bx, by = ft
        d_poly(d, [(bx - 3.8, by - 1.0), (bx + 4.4, by - 1.0), (bx + 5.0, by + 1.6), (bx - 4.0, by + 1.6)],
              col(BG, 255))

    # back arm
    ar = p.get("armR", (f["elR"], f["haR"]))
    limb(d, shR, ang(shR, ar[0]), dist(shR, ar[0]), 5.8, 4.8, cloth_d)
    limb(d, ar[0], ang(ar[0], ar[1]), dist(ar[0], ar[1]), 4.8, 4.2, cloth_d)
    d_ellipse(d, ar[1][0], ar[1][1], 2.6, 2.6, skin)

    # torso: long grey coat, boxy
    d_poly(d, [(shL[0] + 1.2, shL[1] - 1.4), (shR[0] - 1.2, shR[1] - 1.4),
               (hip[0] - 7.6, hip[1] + 6.0), (hip[0] + 7.6, hip[1] + 6.0)], cloth)
    # collar + vest
    d_poly(d, [(shL[0] + 2.2, shL[1] - 1.6), (hip[0] + 2.0, hip[1] + 2.0),
               (hip[0] - 2.4, hip[1] + 2.0), (shR[0] - 2.2, shR[1] - 1.6)], cloth_d)
    d_poly(d, [(chest[0] - 5.4, chest[1] - 3.0), (chest[0] + 5.4, chest[1] - 3.0),
               (hip[0] + 5.0, hip[1] + 1.0), (hip[0] - 5.0, hip[1] + 1.0)], col(STONE, 235))

    # head
    hx0, hy0 = head
    mouth = p.get("mouth", 0.0)
    d_poly(d, [(hx0 - 4.8, hy0 - 4.0), (hx0 + 4.8, hy0 - 4.0), (hx0 + 5.0, hy0 + 1.8),
               (hx0 + 0.6, hy0 + 6.0), (hx0 - 4.4, hy0 + 5.0)], skin)
    # flat cap
    d_poly(d, [(hx0 - 6.4, hy0 - 2.6), (hx0 + 5.0, hy0 - 3.0), (hx0 + 5.4, hy0 - 6.4),
               (hx0 - 5.6, hy0 - 6.2)], cloth_d)
    d_poly(d, [(hx0 - 8.0, hy0 - 2.4), (hx0 + 1.0, hy0 - 2.8), (hx0 + 1.0, hy0 - 0.6), (hx0 - 8.0, hy0 - 1.0)],
          col(BLUE, 250))
    # shut, weary eyes: two thin dark slits (NOT amber)
    d_ellipse(d, hx0 + 2.2, hy0 + 0.2, 1.3, 0.55, col(BG, 255))
    d_ellipse(d, hx0 - 2.2, hy0 + 0.2, 1.3, 0.55, col(BG, 255))
    if mouth > 0.5:
        d_ellipse(d, hx0 + 0.2, hy0 + 3.4, 1.2, 0.9, col(BG, 220))

    # front arm
    al = p.get("armL", (f["elL"], f["haL"]))
    limb(d, shL, ang(shL, al[0]), dist(shL, al[0]), 6.0, 5.0, cloth)
    limb(d, al[0], ang(al[0], al[1]), dist(al[0], al[1]), 5.0, 4.4, cloth)
    d_ellipse(d, al[1][0], al[1][1], 2.7, 2.7, skin)

    # tool held during work animation
    if p.get("tool"):
        h = al[1]
        d_poly(d, [(h[0] - 1.4, h[1] - 1.0), (h[0] + 8.6, h[1] - 5.4),
                   (h[0] + 9.8, h[1] - 2.6), (h[0] - 1.0, h[1] + 2.0)], col(BG, 255))
        d_poly(d, [(h[0] + 7.2, h[1] - 7.8), (h[0] + 11.6, h[1] - 6.4),
                   (h[0] + 11.2, h[1] - 3.0), (h[0] + 6.8, h[1] - 4.2)], col(STONE, 255))


def poses_townsman():
    idle = []
    for i in range(4):
        s = math.sin(2 * math.pi * i / 4)
        idle.append(P(bob=-0.3 - 0.5 * (1 + s) * 0.5, aL1=104 + 3 * s, aR1=76 - 3 * s,
                      aL2=96 + 2 * s, aR2=86 - 2 * s, headTilt=1.5 * s, mouth=0.0))
    task = []
    for i in range(6):
        s = math.sin(2 * math.pi * i / 6)
        c = math.cos(2 * math.pi * i / 6)
        task.append(P(lean=4 + 3 * c, bob=0.4 + 0.9 * (1 - c), aL1=84 + 14 * s, aL2=62 + 18 * s,
                      aR1=90 - 12 * s, aR2=70 - 14 * s, headTilt=2 + 3 * c, tool=True, mouth=0.0,
                      legL1=94, legR1=86))
    dazed = [
        P(bob=0.0, aL1=102, aR1=78, aL2=94, aR2=86, headTilt=-3.5, mouth=1.0, lL1=92, lR1=88),
        P(bob=-0.4, aL1=103, aR1=77, aL2=95, aR2=87, headTilt=0.0, mouth=1.0, lL1=92, lR1=88),
        P(bob=0.2, aL1=101, aR1=79, aL2=93, aR2=85, headTilt=3.5, mouth=1.0, lL1=92, lR1=88),
    ]
    return apply_globals({"townsman_idle": idle, "townsman_task": task, "townsman_dazed": dazed}, splay=0.85)


# ---------------------------------------------------------------- Morris ---

def draw_wax_tool(d, p0, p1, colour, colour2):
    """A wax sculptor's paddle/spatula."""
    ax, ay = p0
    bx, by = p1
    angd = math.degrees(math.atan2(by - ay, bx - ax))
    limb(d, p0, angd, dist(p0, p1) * 0.72, 2.6, 2.2, colour)
    mid_pt = limb_pt(p0, angd, dist(p0, p1) * 0.72)
    limb(d, mid_pt, angd, dist(p0, p1) * 0.28 * 0.5, 4.6, 3.8, colour2)
    # paddle head
    q = limb_pt(p0, angd, dist(p0, p1))
    a = math.radians(angd)
    nx, ny = -math.sin(a), math.cos(a)
    ux, uy = math.cos(a), math.sin(a)
    d_poly(d, [
        (q[0] + ux * 3.0 + nx * 3.4, q[1] + uy * 3.0 + ny * 3.4),
        (q[0] + ux * 4.6 + nx * 1.0, q[1] + uy * 4.6 + ny * 1.0),
        (q[0] + ux * 3.6 - nx * 3.0, q[1] + uy * 3.6 - ny * 3.0),
        (q[0] - ux * 0.8 - nx * 3.8, q[1] - uy * 0.8 - ny * 3.8),
        (q[0] - ux * 1.2 + nx * 3.8, q[1] - uy * 1.2 + ny * 3.8),
    ], colour2)


def draw_morris(d, f, p, scale=1.0, r=None):
    """Morris, the wax sculptor.  The only colourful townsman + amber eyes."""
    r = r or rng("morris")
    cloth = col(MID, 255)
    cloth_d = col(BLUE, 255)
    skin = col(STONE, 255)
    apron = col(wpct(MID, C_WAX, 0.30), 250)      # muted teal-ish panel
    apron2 = col(wpct(MID, C_STONE, 0.35), 250)
    ochre = col(wpct(WAX, ORANGE, 0.35), 245)     # ochre trim
    burn = col(BG, 255)
    burn2 = col(RED, 170)

    hip, chest, head = f["hip"], f["chest"], f["head"]
    shL, shR = f["shL"], f["shR"]
    M = f["M"]

    def rp(dx, dy):
        ht = math.radians(f["headTilt"])
        c, s = math.cos(ht), math.sin(ht)
        X, Y = dx * c - dy * s, dx * s + dy * c
        return add((head[0], head[1]), M(X, Y))

    # ---- legs ----
    for (k, ft) in ((f["kL"], f["ftL"]), (f["kR"], f["ftR"])):
        limb(d, hip, ang(hip, k), dist(hip, k), 8.8, 7.4, cloth_d)
        limb(d, k, ang(k, ft), dist(k, ft), 7.4, 6.6, cloth_d)
        bx, by = ft
        d_poly(d, [(bx - 5.0, by - 1.6), (bx + 5.8, by - 1.6), (bx + 6.8, by + 2.0), (bx - 5.4, by + 2.0)],
              col(BG, 255))

    # ---- torso: heavy, stooped ----
    d_poly(d, [(shL[0] + 2.2, shL[1] - 2.0), (shR[0] - 2.2, shR[1] - 2.0),
               (hip[0] - 9.4, hip[1] + 3.0), (hip[0] + 9.4, hip[1] + 3.0)], cloth)
    # apron panel
    d_poly(d, [(chest[0] + 6.6, chest[1] - 3.4), (chest[0] - 7.2, chest[1] - 3.0),
               (hip[0] - 8.6, hip[1] + 10.0), (hip[0] + 8.0, hip[1] + 10.4)], apron)
    # apron straps crossing the back
    d_arc(d, [(shL[0] + 1.0, shL[1] - 1.0), (chest[0] + 4.0, chest[1] - 3.0)], ochre, 1.6)
    # ochre hem band
    d_poly(d, [(hip[0] - 8.6, hip[1] + 8.4), (hip[0] + 8.0, hip[1] + 8.8),
               (hip[0] + 7.8, hip[1] + 10.6), (hip[0] - 8.4, hip[1] + 10.2)], ochre)
    # apron pocket / tool loop
    d_rect(d, chest[0] - 7.0, chest[1] + 3.0, chest[0] - 1.0, chest[1] + 7.0, apron2)

    # ---- back arm + tool in the far hand ----
    ar = p.get("armR", (f["elR"], f["haR"]))
    limb(d, shR, ang(shR, ar[0]), dist(shR, ar[0]) * p.get("armStretch", 1.0), 8.0, 6.6, cloth_d)
    limb(d, ar[0], ang(ar[0], ar[1]), dist(ar[0], ar[1]) * p.get("armStretch", 1.0), 6.6, 5.8, cloth_d)

    # ---- head: long, gaunt, black burn mark on the right face ----
    hx0, hy0 = head
    d_poly(d, [(hx0 - 6.4, hy0 - 6.0), (hx0 + 6.4, hy0 - 6.0), (hx0 + 6.8, hy0 + 2.4),
               (hx0 + 1.0, hy0 + 8.2), (hx0 - 5.8, hy0 + 6.6)], skin)
    # hair / sideburns (grey, everyone is grey)
    d_poly(d, [(hx0 - 6.8, hy0 - 3.0), (hx0 + 6.8, hy0 - 3.2), (hx0 + 6.4, hy0 - 6.6),
               (hx0 - 6.4, hy0 - 6.4)], cloth_d)
    # burn mark (RIGHT side of his face = screen -x)
    d_poly(d, [rp(-1.0, -3.0), rp(-6.2, -3.4), rp(-7.0, 2.0), rp(-4.0, 7.4), rp(-0.6, 4.0)], burn)
    d_poly(d, [rp(-3.0, -1.4), rp(-6.6, 0.0), rp(-5.4, 3.6), rp(-2.4, 2.4)], burn2)
    # nose
    d_poly(d, [rp(1.2, 0.4), rp(3.0, 1.2), rp(1.0, 3.2)], col(wpct(STONE, BG, 0.4), 255))
    # ---- amber eyes (the tell!) ----
    eL = rp(3.0, -0.4)
    eR = rp(-3.6, -0.6)
    eye_glow(d, eL, 1.5, AMBER, True)
    eye_glow(d, eR, 1.5, AMBER, True)

    # ---- front arm ----
    al = p.get("armL", (f["elL"], f["haL"]))
    limb(d, shL, ang(shL, al[0]), dist(shL, al[0]) * p.get("armStretch", 1.0), 8.4, 7.0, cloth)
    limb(d, al[0], ang(al[0], al[1]), dist(al[0], al[1]) * p.get("armStretch", 1.0), 7.0, 6.0, cloth)
    d_ellipse(d, al[1][0], al[1][1], 4.0, 4.0, skin)

    # tool in the front hand
    if p.get("tool", 1.0) > 0.0:
        h = al[1]
        off = p.get("toolTip", (-7.0, 9.0))
        tipL = (h[0] + off[0], h[1] + off[1])
        draw_wax_tool(d, h, tipL, col(wpct(MID, C_STONE, 0.35), 255), col(wpct(WAX, ORANGE, 0.35), 255))

    # ---- wax spray ----
    if p.get("spray", 0.0) > 0.0:
        sp = p["spray"]
        spdir = math.radians(p.get("sprayDir", -20))
        base = (al[1][0] + 4.0, al[1][1] + 2.0)
        for i in range(int(16 * sp) + 4):
            t = r.random()
            ln = (10 + 40 * t) * sp
            jitter = r.uniform(-16, 16) * (0.3 + t)
            px = base[0] + math.cos(spdir) * ln - math.sin(spdir) * jitter * 0.5
            py = base[1] + math.sin(spdir) * ln + math.cos(spdir) * jitter * 0.5
            rad = (2.6 - 1.9 * t) * sp + 0.4
            d_ellipse(d, px, py, rad * 1.5, rad, col(C_WAX, int(150 + 90 * (1 - t))))
            if t > 0.35:
                d_ellipse(d, px, py, rad * 0.55, rad * 0.5, col(BONE, 200))

    # ---- summoning: wax hands rising from the floor ----
    if p.get("summon", 0.0) > 0.0:
        su = p["summon"]
        for i in range(4):
            bx = hip[0] - 26 + i * 17 + r.uniform(-2, 2)
            by = hip[1] + 20
            hgt = (10 + 12 * r.random()) * su
            d_ellipse(d, bx, by + 1.5, 5.0, 2.0, col(C_WAX, 120))
            d_arc(d, [(bx, by), (bx + r.uniform(-1.5, 1.5), by - hgt)], col(C_WAX, 235), 4.4)
            fg = r.randint(2, 4)
            for k in range(fg):
                fa = math.radians(-140 + k * 40)
                f0 = (bx, by - hgt)
                f1 = (f0[0] + math.cos(fa) * 4.2, f0[1] + math.sin(fa) * 5.0)
                d_arc(d, [f0, f1], col(C_WAX, 235), 1.8)


def poses_morris():
    anims = {}
    anims["morris_idle"] = [
        P(bob=0.0, aL1=104, aR1=76, aL2=96, aR2=86, headTilt=-1.0, toolTip=(24.0, 48.0)),
        P(bob=-0.9, aL1=105, aR1=75, aL2=97, aR2=87, headTilt=-0.2, toolTip=(25.0, 46.0)),
        P(bob=-1.6, aL1=106, aR1=74, aL2=98, aR2=88, headTilt=0.6, toolTip=(26.0, 44.0)),
        P(bob=-0.8, aL1=105, aR1=75, aL2=97, aR2=87, headTilt=0.0, toolTip=(25.0, 46.0)),
    ]
    anims["morris_spray"] = [
        P(lean=-3, aL1=118, aL2=148, aR1=92, aR2=110, headTilt=-3, toolTip=(20, 46), spray=0.10, sprayDir=-24),
        P(lean=-5, aL1=140, aL2=176, aR1=104, aR2=126, headTilt=-6, toolTip=(14, 40), spray=0.35, sprayDir=-26),
        P(lean=-6, aL1=150, aL2=184, aR1=110, aR2=132, headTilt=-8, toolTip=(12, 38), spray=0.75, sprayDir=-28),
        P(lean=-6, aL1=152, aL2=186, aR1=112, aR2=134, headTilt=-8, toolTip=(11, 38), spray=1.00, sprayDir=-30),
        P(lean=-5, aL1=146, aL2=180, aR1=108, aR2=130, headTilt=-6, toolTip=(13, 39), spray=0.70, sprayDir=-28),
        P(lean=-3, aL1=126, aL2=158, aR1=96, aR2=116, headTilt=-3, toolTip=(18, 44), spray=0.28, sprayDir=-24),
    ]
    anims["morris_summon"] = [
        P(lean=3, aL1=126, aL2=156, aR1=132, aR2=168, legL1=86, legR1=94, headTilt=-4,
          summon=0.25, toolTip=(10, 44)),
        P(lean=4, aL1=120, aL2=150, aR1=126, aR2=162, legL1=84, legR1=96, headTilt=-6,
          summon=0.50, toolTip=(8, 42)),
        P(lean=5, aL1=112, aL2=142, aR1=118, aR2=154, legL1=82, legR1=98, headTilt=-8,
          summon=0.80, toolTip=(6, 40)),
        P(lean=5, aL1=106, aL2=136, aR1=112, aR2=148, legL1=82, legR1=98, headTilt=-9,
          summon=1.00, toolTip=(5, 40)),
        P(lean=2, aL1=112, aL2=142, aR1=118, aR2=154, legL1=84, legR1=96, headTilt=-5,
          summon=0.55, toolTip=(7, 42)),
    ]
    anims["morris_hit"] = [
        P(lean=-12, bob=-1.2, aL1=134, aR1=48, aL2=166, aR2=20, headTilt=-7, hatLag=2.6,
          hemSway=3.0, toolTip=(34, 60)),
        P(lean=-7, bob=0.4, aL1=124, aR1=58, aL2=146, aR2=32, headTilt=-4, hatLag=1.2,
          hemSway=2.0, toolTip=(30, 56)),
    ]
    anims["morris_death"] = [
        P(bob=0.4, phi=-6, lean=-8, aL1=126, aR1=54, aL2=152, aR2=28, headTilt=-5, hatLag=1.6),
        P(bob=2.6, phi=-16, lean=-4, aL1=120, aR1=62, aL2=146, aR2=38, lL1=104, lL2=136, lR1=80, lR2=114, headTilt=-8),
        P(bob=5.4, phi=-30, aL1=112, aR1=72, aL2=152, aR2=54, lL1=110, lL2=148, lR1=76, lR2=118, headTilt=-11),
        P(bob=8.0, phi=-48, aL1=124, aR1=88, aL2=162, aR2=132, lL1=116, lL2=156, lR1=72, lR2=122, headTilt=-13),
        P(bob=10.0, phi=-66, aL1=136, aR1=104, aL2=172, aR2=152, lL1=122, lL2=160, lR1=68, lR2=126, headTilt=-15),
        P(bob=11.6, phi=-80, aL1=146, aR1=118, aL2=182, aR2=166, lL1=126, lL2=166, lR1=62, lR2=130, headTilt=-17),
        P(bob=12.4, phi=-88, aL1=152, aR1=126, aL2=188, aR2=174, lL1=128, lL2=170, lR1=58, lR2=132, headTilt=-18,
          melt=3.0),
        P(bob=12.6, phi=-92, aL1=156, aR1=132, aL2=192, aR2=180, lL1=130, lL2=172, lR1=56, lR2=134, headTilt=-19,
          melt=4.0),
    ]
    return apply_globals(anims, shw=1.45, splay=0.85)


# ==========================================================================
#  PROPS  (all drawn in a 32x32 logical grid unless stated)
# ==========================================================================

def prop_letter(d, size, scale, r):
    """Envelope, warm paper, wax seal."""
    paper = col(wpct(BONE, WAX, 0.35), 255)
    paper_d = col(wpct(BONE, WAX, 0.18), 255)
    seal = col(RED, 255)
    d_poly(d, [(4, 11), (28, 11), (28, 24), (4, 24)], paper)
    d_poly(d, [(4, 11), (28, 11), (16, 20)], paper_d)
    d_poly(d, [(4, 24), (12, 17.5), (20, 17.5), (28, 24)], paper_d)
    d_poly(d, [(4, 11), (16, 20), (16, 24), (4, 24)], col(wpct(BONE, WAX, 0.05), 245))
    d_ellipse(d, 16, 19.4, 3.1, 3.1, seal)
    d_ellipse(d, 16, 19.4, 1.3, 1.3, col(wpct(RED, BONE, 0.35), 255))
    d_rect(d, 4, 11, 28, 11.6, col(STONE, 90))


def prop_notebook(d, size, scale, r):
    """Blank notebook, dark cover, pale page block."""
    cover = col(BG, 255)
    cover2 = col(wpct(BG, MID, 0.35), 255)
    d_poly(d, [(6, 6), (26, 8), (25, 27), (7, 26)], cover)
    d_poly(d, [(8.4, 8.4), (23.4, 10.0), (23.0, 24.6), (8.6, 24.2)], col(BONE, 250))
    d_rect(d, 9.4, 9.0, 22.6, 23.6, col(wpct(BONE, STONE, 0.10), 250))
    d_poly(d, [(6, 6), (10.5, 6.6), (9.6, 26.6), (7, 26)], cover)
    d_arc(d, [(15.6, 7.6), (15.4, 26.0)], cover2, 1.4)
    d_rect(d, 12.0, 13.0, 20.6, 14.0, col(STONE, 60))
    d_rect(d, 12.0, 16.4, 19.4, 17.4, col(STONE, 60))


def prop_wax_statue(d, size, scale, r, which="a"):
    """Three different poses.  Pale wax, featureless, static."""
    body = col(WAX, 246)
    body_d = col(wpct(WAX, BONE, 0.20), 244)
    hi = col(wpct(WAX, BONE, 0.45), 220)

    if which == "a":
        # standing, arms down, head slightly bowed
        d_ellipse(d, 16, 28.6, 8.0, 2.4, col(WAX, 90))
        d_rect(d, 11.4, 16.5, 15.2, 28.0, body)
        d_rect(d, 16.8, 16.5, 20.6, 28.0, body)
        d_poly(d, [(11.6, 8.0), (20.6, 8.0), (21.4, 17.6), (10.8, 17.6)], body)
        d_arc(d, [(12.0, 10.0), (10.0, 17.6)], body_d, 2.6)
        d_arc(d, [(20.2, 10.0), (22.4, 17.6)], body_d, 2.6)
        d_ellipse(d, 16.0, 5.4, 3.8, 4.2, body)
        d_poly(d, [(11.8, 4.0), (20.2, 4.0), (19.4, -0.2), (12.6, -0.2)], body_d)
        d_ellipse(d, 14.6, 6.6, 1.6, 1.0, hi)
    elif which == "b":
        # turned away, one arm raised as if sculpting
        d_ellipse(d, 16, 28.8, 7.4, 2.2, col(WAX, 90))
        d_rect(d, 12.0, 17.0, 15.6, 28.2, body)
        d_rect(d, 17.0, 17.0, 20.4, 28.2, body)
        d_poly(d, [(12.4, 9.0), (20.4, 8.4), (21.3, 18.0), (11.4, 18.4)], body)
        # raised arm
        d_arc(d, [(12.6, 11.0), (7.6, 5.2)], body_d, 2.6)
        d_arc(d, [(20.2, 11.4), (23.4, 19.0)], body_d, 2.6)
        # head turned (offset)
        d_ellipse(d, 14.6, 5.6, 3.6, 4.0, body)
        d_poly(d, [(11.2, 4.4), (18.2, 3.6), (17.6, -0.4), (11.6, 0.4)], body_d)
    else:
        # kneeling / crouched, hands on the ground, dripping
        d_ellipse(d, 17, 28.6, 8.6, 2.6, col(WAX, 100))
        d_poly(d, [(11.0, 21.0), (21.0, 19.6), (23.0, 27.6), (10.0, 27.6)], body)
        d_arc(d, [(11.6, 22.0), (9.6, 28.0)], body_d, 3.0)
        d_arc(d, [(22.4, 20.4), (24.4, 27.0)], body_d, 3.0)
        d_ellipse(d, 15.2, 16.4, 3.8, 4.0, body)
        d_poly(d, [(11.4, 15.0), (18.8, 14.2), (18.2, 10.6), (12.0, 11.4)], body_d)
        for i in range(4):
            sx = 11.0 + i * 3.4
            d_arc(d, [(sx, 26.0), (sx + r.uniform(-0.8, 0.8), 29.2 + r.uniform(0, 1.6))], body_d, 1.4)


def prop_mirror(d, size, scale, r):
    """Standing cheval mirror."""
    frame = col(wpct(BG, MID, 0.30), 255)
    frame2 = col(wpct(BG, MID, 0.55), 255)
    glass = col(PURP, 240)
    glass2 = col(BLUE, 210)
    # stand
    d_poly(d, [(14.6, 22), (17.4, 22), (18.4, 30.4), (13.6, 30.4)], frame2)
    d_poly(d, [(9.0, 29.4), (23.0, 29.4), (24.4, 31.4), (7.6, 31.4)], frame)
    # frame
    d_poly(d, [(7.0, 3.0), (25.0, 3.0), (25.0, 23.0), (7.0, 23.0)], frame)
    d_poly(d, [(9.0, 5.0), (23.0, 5.0), (23.0, 21.2), (9.0, 21.2)], glass)
    # reflection streaks
    d_poly(d, [(10.0, 5.4), (13.2, 5.4), (11.6, 20.8), (9.4, 20.8)], col(MID, 150))
    d_poly(d, [(16.4, 5.4), (18.0, 5.4), (16.4, 20.8), (15.4, 20.8)], col(BLUE, 130))
    d_rect(d, 7.0, 3.0, 25.0, 4.2, frame2)
    d_rect(d, 7.0, 21.8, 25.0, 23.0, frame2)


def prop_checkpoint_lamp(d, size, scale, r, glow_layer=None):
    """Street lamp save point (64x64 grid).  Warm amber lantern."""
    iron = col(wpct(BG, MID, 0.22), 255)
    iron2 = col(wpct(BG, MID, 0.42), 255)
    # base + post
    d_poly(d, [(22.0, 56.0), (42.0, 56.0), (46.0, 61.0), (18.0, 61.0)], iron)
    d_poly(d, [(29.0, 24.0), (35.0, 24.0), (37.2, 57.0), (26.8, 57.0)], iron)
    d_poly(d, [(26.8, 52.0), (37.2, 52.0), (37.6, 55.0), (26.4, 55.0)], iron2)
    # lamp head
    d_arc(d, [(32.0, 30.0), (32.0, 20.0)], iron2, 3.2)
    d_poly(d, [(24.0, 16.0), (40.0, 16.0), (43.2, 22.0), (20.8, 22.0)], iron2)
    d_poly(d, [(25.2, 22.4), (38.8, 22.4), (37.2, 34.0), (26.8, 34.0)], col(WAX, 250))
    d_poly(d, [(27.2, 23.4), (36.8, 23.4), (35.6, 33.0), (28.4, 33.0)], col(BONE, 252))
    d_ellipse(d, 32.0, 28.4, 2.2, 2.6, col(AMBER, 250))
    # crown
    d_poly(d, [(22.0, 15.4), (42.0, 15.4), (36.4, 8.0), (27.6, 8.0)], iron)
    d_ellipse(d, 32.0, 7.2, 2.0, 2.0, iron2)
    # glow disc around the lantern (amber, low alpha)
    for (rr, aa) in ((20.0, 22), (14.0, 30), (9.6, 44)):
        d_ellipse(d, 32.0, 27.0, rr, rr * 1.05, col(AMBER, aa))
    # cross arm holding a second small lantern
    d_rect(d, 36.0, 25.0, 46.0, 27.4, iron2)
    d_poly(d, [(42.0, 27.4), (48.0, 27.4), (47.4, 36.0), (42.6, 36.0)], iron)
    d_poly(d, [(43.2, 28.6), (46.8, 28.6), (46.4, 34.8), (43.6, 34.8)], col(WAX, 245))
    return None


def prop_signboard(d, size, scale, r):
    """Rusted wooden town sign."""
    wood = col(wpct(BG, STONE, 0.30), 255)
    wood_d = col(wpct(BG, STONE, 0.18), 255)
    rust = col(ORANGE, 235)
    rust_d = col(RED, 220)
    post = col(wpct(BG, MID, 0.26), 255)
    d_poly(d, [(28.8, 26), (35.2, 26), (34.8, 62), (29.2, 62)], post)
    d_arc(d, [(14.0, 34.0), (50.0, 32.0)], wood, 4.0)
    d_poly(d, [(4.0, 6.0), (60.0, 6.0), (60.0, 30.0), (4.0, 30.0)], wood)
    d_poly(d, [(4.0, 6.0), (60.0, 6.0), (60.0, 10.4), (4.0, 10.4)], wood_d)
    d_poly(d, [(4.0, 26.0), (60.0, 26.0), (60.0, 30.0), (4.0, 30.0)], wood_d)
    # plank joins
    d_rect(d, 4.0, 17.6, 60.0, 18.6, col(BG, 120))
    # rust streaks
    for i in range(7):
        x = 8.0 + i * 7.4 + r.uniform(-1.2, 1.2)
        ln = r.uniform(3.0, 10.0)
        d_arc(d, [(x, 11.4), (x + r.uniform(-0.7, 0.7), 11.4 + ln)], rust, 1.6)
    d_ellipse(d, 11.0, 13.0, 2.6, 2.0, rust_d)
    d_ellipse(d, 48.0, 22.0, 2.2, 1.7, rust_d)
    # carved lettering (faded)
    for i in range(3):
        y = 13.4 + i * 4.2
        w = 34.0 - i * 9.0
        d_rect(d, 13.0, y, 13.0 + w, y + 1.7, col(BG, 135))
    # nail heads
    d_ellipse(d, 8.0, 8.6, 1.3, 1.3, col(BONE, 190))
    d_ellipse(d, 56.0, 8.6, 1.3, 1.3, col(BONE, 190))


def prop_big_scissors(d, size, scale, r):
    """Large scissors (chapter 2 item) -- drawn in a 64x64 grid."""
    steel = col(wpct(STONE, BONE, 0.32), 255)
    steel2 = col(wpct(STONE, BONE, 0.58), 252)
    grip = col(wpct(BG, MID, 0.30), 255)
    grip2 = col(wpct(BG, MID, 0.48), 255)
    ax, ay = 32.0, 41.0

    # ---- handles (below the pivot) ----
    for (hx, hy, rr, rot) in ((24.0, 51.0, 7.2, -14.0), (40.0, 53.0, 7.6, 12.0)):
        a = math.radians(rot)
        c, s = math.cos(a), math.sin(a)
        d_ellipse(d, hx, hy, rr, rr * 0.84, grip)
        d_ellipse(d, hx + c * 1.2, hy + s * 1.2, rr * 0.60, rr * 0.48, (0, 0, 0, 0))
        d_ellipse(d, hx - 0.6, hy - 0.8, rr * 1.04, rr * 0.90, grip2)
        d_ellipse(d, hx - 0.6, hy - 0.8, rr * 0.72, rr * 0.60, (0, 0, 0, 0))

    # ---- blades (crossing above the pivot) ----
    d_poly(d, [(26.4, 40.0), (32.6, 38.6), (39.0, 6.0), (34.6, 5.0)], steel)
    d_poly(d, [(37.6, 42.0), (31.4, 40.6), (25.0, 8.0), (29.4, 7.0)], steel2)
    # cutting edge highlights
    d_arc(d, [(36.2, 6.6), (31.0, 38.4)], col(BONE, 120), 1.0)
    # pivot screw
    d_ellipse(d, ax, ay, 3.4, 3.4, grip)
    d_ellipse(d, ax, ay, 1.7, 1.7, steel2)


def prop_button(d, size, scale, r):
    """One small pale button."""
    pale = col(wpct(BONE, WAX, 0.15), 255)
    pale2 = col(wpct(BONE, STONE, 0.30), 250)
    d_ellipse(d, 16.0, 16.0, 10.0, 10.0, pale2)
    d_ellipse(d, 16.0, 15.4, 9.0, 9.0, pale)
    d_ellipse(d, 16.0, 15.4, 6.4, 6.4, col(wpct(BONE, WAX, 0.28), 255))
    for (dx, dy) in ((-2.2, -2.2), (2.2, -2.2), (-2.2, 2.2), (2.2, 2.2)):
        d_ellipse(d, 16.0 + dx, 15.4 + dy, 1.15, 1.15, col(wpct(BG, MID, 0.30), 245))
    d_ellipse(d, 13.4, 12.4, 1.8, 1.2, (0, 0, 0, 0))


def prop_rag_doll(d, size, scale, r):
    """Clean, intact twin-tail girl rag doll.  The ONLY undamaged doll."""
    cloth = col(wpct(BONE, WAX, 0.42), 255)
    cloth2 = col(wpct(BONE, WAX, 0.62), 252)
    thread = col(wpct(BONE, STONE, 0.35), 255)
    hair = col(wpct(BG, MID, 0.42), 255)
    hair2 = col(wpct(BG, MID, 0.62), 255)
    eye = col(BG, 255)
    cheek = col(wpct(RED, BONE, 0.45), 190)

    # dress (clean A-line)
    d_poly(d, [(11.6, 18.0), (20.4, 18.0), (23.4, 29.0), (8.6, 29.0)], cloth)
    d_poly(d, [(11.6, 18.0), (20.4, 18.0), (21.0, 21.0), (11.0, 21.0)], cloth2)
    d_rect(d, 8.6, 27.4, 23.4, 29.0, cloth2)
    # legs + shoes
    d_rect(d, 13.6, 28.6, 15.6, 31.6, col(wpct(BONE, WAX, 0.30), 255))
    d_rect(d, 16.4, 28.6, 18.4, 31.6, col(wpct(BONE, WAX, 0.30), 255))
    d_ellipse(d, 14.4, 31.8, 2.0, 1.2, col(wpct(BG, MID, 0.30), 255))
    d_ellipse(d, 17.6, 31.8, 2.0, 1.2, col(wpct(BG, MID, 0.30), 255))
    # arms
    d_arc(d, [(11.4, 19.4), (7.6, 26.0)], cloth, 2.6)
    d_arc(d, [(20.6, 19.4), (24.6, 26.0)], cloth, 2.6)
    d_ellipse(d, 7.4, 26.6, 1.5, 1.5, cloth2)
    d_ellipse(d, 24.8, 26.6, 1.5, 1.5, cloth2)
    # head + twin tails
    d_ellipse(d, 20.6, 12.4, 3.4, 3.2, hair)
    d_ellipse(d, 11.4, 12.4, 3.4, 3.2, hair)
    d_arc(d, [(22.4, 14.4), (24.8, 20.2)], hair2, 2.6)
    d_arc(d, [(9.6, 14.4), (7.2, 20.2)], hair2, 2.6)
    d_ellipse(d, 16.0, 12.6, 5.0, 5.2, cloth)
    d_poly(d, [(11.2, 9.4), (20.8, 9.4), (20.0, 6.2), (16.0, 4.6), (12.0, 6.2)], hair)
    # face: tiny, tidy
    d_ellipse(d, 14.2, 12.8, 0.85, 0.95, eye)
    d_ellipse(d, 17.8, 12.8, 0.85, 0.95, eye)
    d_ellipse(d, 12.9, 14.6, 1.1, 0.7, cheek)
    d_ellipse(d, 19.1, 14.6, 1.1, 0.7, cheek)
    d_arc(d, [(15.2, 15.4), (16.8, 15.4)], col(wpct(RED, BONE, 0.2), 210), 0.7)
    # collar ribbon
    d_poly(d, [(13.0, 17.4), (19.0, 17.4), (16.0, 19.4)], cloth2)


# ==========================================================================
#  VFX
# ==========================================================================

def vfx_marker_interact(d, size, scale, r):
    """Soft amber chevron prompt ("interact")."""
    cx, cy = 16.0, 15.2
    d_ellipse(d, cx, cy, 13.6, 13.6, col(AMBER, 22))
    d_ellipse(d, cx, cy, 10.4, 10.4, col(AMBER, 28))
    for (dy, alpha, wdt) in ((-7.2, 110, 1.9), (-1.8, 175, 2.1), (3.6, 248, 2.2)):
        pts = []
        n = 10
        for i in range(n + 1):
            t = -1.0 + 2.0 * (i / n)
            pts.append((cx + t * 7.8, cy + dy + 3.8 * abs(t) - 1.7))
        d_arc(d, pts, col(AMBER, alpha), wdt)
    d_ellipse(d, cx, cy + 9.4, 1.7, 1.7, col(AMBER, 225))


def vfx_marker_danger(d, size, scale, r):
    """Dark red warning diamond."""
    cx, cy = 16.0, 16.0
    pts_o = [(cx, cy - 13.0), (cx + 11.0, cy), (cx, cy + 13.0), (cx - 11.0, cy)]
    pts_m = [(cx, cy - 8.6), (cx + 7.2, cy), (cx, cy + 8.6), (cx - 7.2, cy)]
    d_poly(d, pts_o, col(RED, 120))
    d_poly(d, pts_m, col(RED, 245))
    d_ellipse(d, cx, cy, 4.0, 4.0, col(C_BG, 235))
    d_ellipse(d, cx, cy, 2.6, 2.6, col(RED, 255))
    d_ellipse(d, cx, cy - 0.3, 1.1, 1.1, col(wpct(RED, BONE, 0.55), 240))


def vfx_hit_spark(d, size, scale, r, i=0):
    """4-frame pale impact flash."""
    cx, cy = 16.0, 16.0
    k = i / 3.0
    spread = 0.35 + k * 1.0
    alpha = int(255 - 70 * k)
    # core
    d_ellipse(d, cx, cy, (7.6 - 4.6 * k) * 1.0, (7.6 - 4.6 * k) * 1.0, col(C_WAX, min(255, alpha + 90)))
    n = 7 + i
    for j in range(n):
        a = (j / n) * 2 * math.pi + i * 0.5
        ln = (7.0 + 5.6 * k) * (0.7 + 0.6 * r.random())
        w = 1.7 * (1.0 - 0.6 * k) + 0.4
        d_arc(d, [(cx + math.cos(a) * 2.4, cy + math.sin(a) * 2.4),
                  (cx + math.cos(a) * (2.4 + ln * spread), cy + math.sin(a) * (2.4 + ln * spread))],
              col(BONE, alpha), w)
    d_ellipse(d, cx, cy, 2.0 - 1.0 * k, 2.0 - 1.0 * k, col(BONE, 250))


def white_flash_full(size):
    """64x64 pure WHITE player silhouette (hit-flash mask).

    Drawn 1:1 (no supersampling) so the alpha matte is crisp: everywhere the
    silhouette covers, the pixel is exactly #FFFFFF opaque.
    """
    pose = P(bob=0.0, aL1=84, aR1=58, aL2=96, aR2=80, hemSway=0.4, headTilt=-1.0)
    hx, hy = HIP_ANCHOR()
    f = frame((hx, hy), pose)
    lay = nlayer(size)
    d = ScaledDraw(lay, 1.0)
    ctx = _WhiteCtx()
    ctx.__enter__()
    try:
        draw_player(d, f, pose, 1.0)
    finally:
        ctx.__exit__(None, None, None)
    alpha = lay.getchannel("A")
    out = Image.new("RGBA", size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


class _WhiteCtx:
    """Temporarily force every palette lookup to pure opaque white."""

    def __enter__(self):
        self._orig = globals()["col"]
        globals()["col"] = lambda h, a=255: (255, 255, 255, int(a))
        return self

    def __exit__(self, *exc):
        globals()["col"] = self._orig
        return False


# ==========================================================================
#  UI
# ==========================================================================

def ui_panel_dark(d, size, scale, r):
    """64x64 nine-patch dark parchment panel, 16px border, ~0.92 alpha."""
    W = size[0]
    body = col(wpct(BG, MID, 0.35), 235)
    body2 = col(wpct(BG, MID, 0.22), 235)
    edge = col(wpct(BG, STONE, 0.35), 250)
    edge_hi = col(wpct(BG, BONE, 0.25), 200)
    corner = col(wpct(BG, STONE, 0.5), 250)
    d.rectangle([0, 0, W - 1, W - 1], fill=body)
    # inner wash so the nine-patch centre is not flat
    d.rectangle([6, 6, W - 7, W - 7], fill=body2)
    d.rectangle([10, 10, W - 11, W - 11], fill=body)
    # border band
    d.rectangle([1, 1, W - 2, 3], fill=edge)
    d.rectangle([1, W - 4, W - 2, W - 2], fill=edge)
    d.rectangle([1, 1, 3, W - 2], fill=edge)
    d.rectangle([W - 4, 1, W - 2, W - 2], fill=edge)
    # subtle border highlight (inside top/left)
    d.rectangle([3, 3, W - 4, 4], fill=edge_hi)
    d.rectangle([3, 3, 4, W - 4], fill=edge_hi)
    # dark inner line
    d.rectangle([5, 5, W - 6, 6], fill=col(BG, 170))
    d.rectangle([5, 5, 6, W - 6], fill=col(BG, 170))
    d.rectangle([5, W - 7, W - 6, W - 6], fill=col(BG, 110))
    d.rectangle([W - 7, 5, W - 6, W - 6], fill=col(BG, 110))
    # corner studs
    for (cx, cy) in ((6, 6), (W - 7, 6), (6, W - 7), (W - 7, W - 7)):
        d_ellipse(d, cx, cy, 2.4, 2.4, corner)
        d_ellipse(d, cx, cy, 1.2, 1.2, edge_hi)
    # parchment grain
    for i in range(30):
        x = r.uniform(8, W - 9)
        y = r.uniform(8, W - 9)
        d_ellipse(d, x, y, r.uniform(0.7, 2.0), r.uniform(0.7, 1.6), col(BG, r.randint(14, 30)))


def ui_pip(d, size, scale, r, full=True):
    W = size[0]
    if full:
        outer = col(wpct(BG, STONE, 0.55), 255)
        inner = col(AMBER, 255)
        hot = col(C_WAX, 255)
    else:
        outer = col(wpct(BG, MID, 0.35), 235)
        inner = col(wpct(BG, MID, 0.18), 225)
        hot = col(wpct(BG, MID, 0.28), 220)
    d_ellipse(d, W / 2, W / 2, W * 0.46, W * 0.46, outer)
    d_ellipse(d, W / 2, W / 2, W * 0.40, W * 0.40, col(BG, 255))
    d_ellipse(d, W / 2, W / 2, W * 0.34, W * 0.34, inner)
    if full:
        eye_glow(d, (W / 2, W / 2), W * 0.055, AMBER, True)
        d_ellipse(d, W * 0.36, W * 0.34, W * 0.07, W * 0.05, col(BONE, 200))
    else:
        d_ellipse(d, W / 2, W / 2, W * 0.20, W * 0.20, hot)
        d_ellipse(d, W / 2, W / 2, W * 0.10, W * 0.10, col(BG, 240))


def ui_hat_icon(d, size, scale, r):
    """Detective hat HUD icon (24x24)."""
    W = size[0]
    dark = col(BG, 255)
    lip = col(wpct(BG, MID, 0.30), 255)
    # crown
    d_poly(d, [(7.4, 12.6), (7.0, 5.0), (8.4, 3.4), (14.4, 3.2), (16.4, 4.6), (16.8, 12.6)], dark)
    # band
    d_poly(d, [(7.2, 8.6), (16.7, 8.6), (16.8, 10.6), (7.1, 10.6)], lip)
    # brim
    d_poly(d, [(2.0, 13.0), (8.0, 11.6), (16.0, 11.8), (22.0, 13.6), (20.0, 16.4), (5.0, 16.6)], dark)
    d_poly(d, [(3.4, 13.6), (20.6, 13.8), (19.4, 15.2), (5.0, 15.4)], lip)
    d_ellipse(d, 13.0, 14.2, 1.3, 1.0, col(AMBER, 210))


# ==========================================================================
#  BACKGROUNDS  (1920x1080)
# ==========================================================================

def _roof_poly(x, w, base_y, h, ov, mx=0.0, my=0.0):
    """trapezoid roof: base_y = the ridge, h = the eave drop."""
    return [
        (x - ov, base_y + h),
        (x + w * 0.5 + mx, base_y),
        (x + w + ov, base_y + h),
    ]


def bg_town_far(d, size, scale, r):
    """Distant rooflines + one tall clock tower.  Lowest contrast."""
    W, H = size
    far = col(wpct(BG, BLUE, 0.60), 255)
    far2 = col(wpct(BG, BLUE, 0.48), 255)
    horizon = 782.0
    # moon disc (bone white, very low alpha)
    d_ellipse(d, 1420, 232, 96, 96, col(BONE, 20))
    d_ellipse(d, 1420, 232, 74, 74, col(BONE, 26))
    # ground band
    d.rectangle([0, horizon, W, H], fill=col(wpct(BG, BLUE, 0.34), 255))
    # distant building strip
    x = -60.0
    while x < W + 60:
        bw = r.uniform(90, 200)
        bh = r.uniform(90, 210)
        d.rectangle([x, horizon - bh, x + bw, horizon + 20], fill=far2)
        mx = r.uniform(-14, 14)
        d_poly(d, _roof_poly(x, bw, horizon - bh, r.uniform(26, 56), r.uniform(4, 14), mx), far2)
        x += bw * r.uniform(0.72, 0.98)
    # chimneys
    for i in range(22):
        cx = r.uniform(0, W)
        cy = horizon - r.uniform(120, 240)
        d.rectangle([cx, cy, cx + 14, cy + 40], fill=far)
    # clock tower (offset right of centre so the mid layer can frame it)
    tx = 1150.0
    tw = 176.0
    ty = 190.0
    d.rectangle([tx, ty, tx + tw, horizon + 30], fill=far)
    d_poly(d, _roof_poly(tx, tw, ty, 96, 16), far)
    d_poly(d, [(tx + 30, ty - 96), (tx + tw - 30, ty - 96), (tx + tw * 0.5, ty - 300)], far)
    for i in range(4):
        sx = tx + 26 + i * 40
        d.rectangle([sx, ty + 210, sx + 20, ty + 246], fill=col(BG, 90))
    # clock face
    ccx, ccy = tx + tw * 0.5, ty + 120
    d_ellipse(d, ccx, ccy, 60, 60, far2)
    d_ellipse(d, ccx, ccy, 50, 50, col(wpct(BG, BLUE, 0.75), 255))
    d_ellipse(d, ccx, ccy, 44, 44, col(wpct(BG, BLUE, 0.45), 255))
    d_arc(d, [(ccx, ccy), (ccx + 30, ccy - 22)], col(BONE, 40), 5.0)
    d_arc(d, [(ccx, ccy), (ccx - 12, ccy - 34)], col(BONE, 34), 4.0)
    # thin far balconies / wires
    for i in range(4):
        y = horizon - r.uniform(60, 320)
        d.rectangle([0, y, W, y + 6], fill=col(wpct(BG, BLUE, 0.80), 150))


def bg_town_mid(d, size, scale, r):
    """Mid rooflines with tiny warm lit windows."""
    W, H = size
    LW, LH = W / scale, H / scale          # logical (final pixel) coordinates
    mid_c = col(wpct(BG, MID, 0.62), 255)
    mid_d = col(wpct(BG, MID, 0.44), 255)
    win_glow = nlayer((W, H))
    wd = ScaledDraw(win_glow, scale)
    horizon = 878.0
    x = -70.0
    while x < LW + 70:
        bw = r.uniform(110, 236)
        bh = r.uniform(130, 300)
        top = horizon - bh
        d.rectangle([x, top, x + bw, LH + 40], fill=mid_d)
        d.rectangle([x, top, x + bw, LH + 40], fill=mid_c if r.random() < 0.4 else (0, 0, 0, 0))
        ox = r.uniform(6, 16)
        d_poly(d, _roof_poly(x, bw, top, r.uniform(30, 62), ox, r.uniform(-16, 16)), mid_d)
        # windows
        cols = max(2, int(bw // 34))
        rows = max(2, int(bh // 44))
        for ci in range(cols):
            for ri in range(rows):
                if r.random() < 0.32:
                    continue
                wx = x + 14 + ci * (bw - 24) / cols
                wy = top + 30 + ri * (bh - 46) / rows
                ww = 9.0
                wh = 13.0
                lit = r.random() < 0.30
                if lit:
                    wd.rectangle([wx - 2, wy - 2, wx + ww + 2, wy + wh + 2], fill=col(AMBER, 26))
                    wd.rectangle([wx, wy, wx + ww, wy + wh], fill=col(AMBER, 130))
                    wd.rectangle([wx + 2, wy + 2, wx + ww - 2, wy + wh - 2], fill=col(C_WAX, 190))
                else:
                    d.rectangle([wx, wy, wx + ww, wy + wh], fill=col(BG, 120))
        # chimney
        if r.random() < 0.5:
            cx = x + bw * r.uniform(0.2, 0.8)
            d.rectangle([cx, top - r.uniform(24, 54), cx + 20, top + 10], fill=mid_d)
        x += bw * r.uniform(0.8, 1.0)
    # horizon smoke / haze
    for i in range(5):
        d.rectangle([0, horizon - 40 - i * 26, LW, horizon - 24 - i * 26], fill=col(BG, 20 + i * 5))
    return win_glow, mid_c


def bg_town_near(d, size, scale, r):
    """Near dark building edges + railings; centre left clear."""
    W, H = size
    LW, LH = W / scale, H / scale
    near = col(wpct(BG, MID, 0.24), 255)
    near2 = col(wpct(BG, MID, 0.14), 255)
    keep = nlayer((W, H))
    kd = ImageDraw.Draw(keep)
    kd.rectangle([0, 0, W, H], fill=(255, 255, 255, 255))
    # left building mass
    d_poly(d, [(0, 0), (330, 0), (352, 300), (300, 470), (336, LH), (0, LH)], near)
    d_poly(d, [(0, 0), (232, 0), (250, 320), (214, 520), (238, LH), (0, LH)], near2)
    # right building mass
    d_poly(d, [(LW, 0), (LW - 300, 0), (LW - 330, 330), (LW - 268, 560),
               (LW - 320, LH), (LW, LH)], near)
    d_poly(d, [(LW, 0), (LW - 190, 0), (LW - 214, 360), (LW - 168, LH), (LW, LH)], near2)
    # hung shutters / window frames on both sides (no lit windows here)
    for (bx, side) in ((0.0, 1.0), (W - 120.0, -1.0)):
        for i in range(5):
            wy = 120 + i * 190 + r.uniform(-20, 20)
            wx = bx + (60 if side > 0 else 40)
            d.rectangle([wx, wy, wx + 62, wy + 104], fill=col(BG, 200))
            d.rectangle([wx + 4, wy + 4, wx + 58, wy + 100], fill=col(BG, 255))
            d.rectangle([wx - 6, wy + 46, wx + 68, wy + 54], fill=near2)
    # centre railing (frame bottom)
    ry = 1012.0
    d.rectangle([0, ry, LW, ry + 10], fill=near)
    d.rectangle([0, ry - 34, LW, ry - 26], fill=near)
    for i in range(int(LW // 46) + 2):
        x = i * 46.0
        d.rectangle([x, ry - 40, x + 9, ry + 34], fill=near)
    # hanging lamp silhouettes at the edges
    for (lx, ls) in ((196.0, 1.0), (LW - 208.0, -1.0)):
        d.rectangle([lx, 0, lx + 7, 96], fill=near2)
        d_poly(d, [(lx - 22, 96), (lx + 29, 96), (lx + 20, 140), (lx - 13, 140)], near)
    # keep-mask: punch out the centre so gameplay reads
    s = scale
    kd.rectangle([392 * s, 0, (LW - 392) * s, H], fill=(0, 0, 0, 255))
    for i in range(9):
        kd.ellipse([(300 - i * 8) * s, (120 + i * 96) * s,
                    (LW - 300 + i * 8) * s, (320 + i * 96) * s], fill=(0, 0, 0, 255))
    kd.ellipse([262 * s, 0, (LW - 262) * s, H], fill=(0, 0, 0, 255))
    return keep


def bg_wax_lane(d, size, scale, r):
    """Wax lane: rows of statue silhouettes along both edges + amber lamp pools."""
    W, H = size
    LW, LH = W / scale, H / scale
    lane = col(PURP, 205)
    stat = col(wpct(BG, BLUE, 0.30), 255)
    stat2 = col(wpct(BG, BLUE, 0.48), 255)
    floor = col(wpct(BG, PURP, 0.62), 255)
    glow = nlayer((W, H))
    gd = ScaledDraw(glow, scale)

    # floor
    d.rectangle([0, 900, LW, LH], fill=floor)
    for i in range(10):
        y = 906 + i * 18
        d.rectangle([0, y, LW, y + 1], fill=col(BG, 40))
    # far wall
    d.rectangle([0, 320, LW, 902], fill=lane)
    for i in range(int(LW // 150) + 2):
        x = i * 150.0
        d.rectangle([x, 320, x + 8, 902], fill=col(BG, 45))

    def statue_row(base_y, side, hgt, colour, count):
        for i in range(count):
            if side > 0:
                x = 40 + i * 118 + r.uniform(-8, 8)
            else:
                x = LW - 48 - i * 118 + r.uniform(-8, 8)
            s = hgt * r.uniform(0.75, 1.18)
            top = base_y - s
            # legs
            d.rectangle([x - 8, base_y - s * 0.48, x - 1, base_y], fill=colour)
            d.rectangle([x + 2, base_y - s * 0.48, x + 9, base_y], fill=colour)
            # torso
            d_poly(d, [(x - 11, top + s * 0.20), (x + 11, top + s * 0.20),
                       (x + 9, base_y - s * 0.46), (x - 9, base_y - s * 0.46)], colour)
            # arms
            d.rectangle([x - 17, top + s * 0.24, x - 11, top + s * 0.62], fill=colour)
            d.rectangle([x + 11, top + s * 0.24, x + 17, top + s * 0.62], fill=colour)
            # head
            d.ellipse([x - 8, top + s * 0.02, x + 8, top + s * 0.22], fill=colour)
            # drip lip on the plinth
            d.ellipse([x - 18, base_y - 5, x + 18, base_y + 7], fill=colour)
        return None

    statue_row(902, +1, 330, stat, 8)
    statue_row(902, -1, 340, stat2, 8)
    # plinths
    for i in range(8):
        for side in (+1, -1):
            x = (40 + i * 118) if side > 0 else (LW - 48 - i * 118)
            d.rectangle([x - 20, 886, x + 20, 906], fill=col(wpct(BG, MID, 0.30), 255))

    # amber lamp pools
    for i in range(4):
        lx = 260 + i * 470
        # lamp post
        d.rectangle([lx - 5, 470, lx + 5, 902], fill=col(BG, 255))
        d.polygon([(lx - 26, 440), (lx + 26, 440), (lx + 18, 500), (lx - 18, 500)],
                  fill=col(wpct(BG, MID, 0.40), 255))
        gd.ellipse([lx - 46, 448, lx + 46, 512], fill=col(AMBER, 200))
        gd.ellipse([lx - 150, 402, lx + 150, 560], fill=col(AMBER, 62))
    # lamp pools on the floor
    for i in range(4):
        lx = 260 + i * 470
        gd.ellipse([lx - 300, 780, lx + 300, LH], fill=col(AMBER, 96))
        gd.ellipse([lx - 150, 850, lx + 150, LH], fill=col(AMBER, 78))
    return glow


def bg_clocktower(d, size, scale, r):
    """Vertical clock tower interior: gears + dim red glow."""
    W, H = size
    LW, LH = W / scale, H / scale
    wall = col(PURP, 255)
    wall2 = col(wpct(BG, PURP, 0.70), 255)
    metal = col(wpct(BG, MID, 0.44), 255)
    metal2 = col(wpct(BG, MID, 0.60), 255)
    glow = nlayer((W, H))
    gd = ScaledDraw(glow, scale)

    d.rectangle([0, 0, LW, LH], fill=wall)
    # vertical panelling
    for i in range(int(LW // 128) + 2):
        x = i * 128.0
        d.rectangle([x, 0, x + 10, LH], fill=wall2)
    # dim red glow floor
    gd.ellipse([LW * 0.5 - 620, LH - 420, LW * 0.5 + 620, LH + 240], fill=col(RED, 46))
    gd.ellipse([LW * 0.5 - 330, LH - 320, LW * 0.5 + 330, LH + 120], fill=col(RED, 40))
    # red lamp housings
    for (lx, ly, rr) in ((300, 300, 74), (1620, 380, 62), (960, 190, 88)):
        d.ellipse([lx - rr, ly - rr, lx + rr, ly + rr], fill=col(RED, 150))
        d.ellipse([lx - rr * 0.62, ly - rr * 0.62, lx + rr * 0.62, ly + rr * 0.62], fill=col(RED, 210))
        d.ellipse([lx - rr * 0.26, ly - rr * 0.26, lx + rr * 0.26, ly + rr * 0.26], fill=col(ORANGE, 160))
        gd.ellipse([lx - rr * 3.0, ly - rr * 3.0, lx + rr * 3.0, ly + rr * 3.0], fill=col(ORANGE, 22))
    # big gears
    gear(d, 470, 620, 236, 18, 42, metal, 16, 2, 0.0)
    gear(d, 500, 620, 120, 14, 26, wall2, 12, 1, 0.2)
    gear(d, 1560, 700, 280, 20, 48, metal, 18, 2, 0.1)
    gear(d, 1520, 700, 150, 16, 30, wall2, 14, 1, 0.3)
    # top gear cluster
    gear(d, 960, 90, 170, 16, 34, metal2, 12, 2, 0.05)
    # pendulum
    d.rectangle([956, 120, 968, 660], fill=metal2)
    d.ellipse([900, 640, 1024, 780], fill=metal)
    d.ellipse([940, 678, 984, 742], fill=wall2)
    # ladders / beams
    for i in range(2):
        y = 460 + i * 330
        d.rectangle([0, y, LW, y + 14], fill=metal)
        for k in range(int(LW // 60) + 2):
            x = k * 60.0
            d.rectangle([x, y - 26, x + 8, y + 40], fill=metal2)
    # chains
    for cxi in (150, 240, 1780, 1690):
        for k in range(int(LH // 26)):
            d.ellipse([cxi - 7, k * 26, cxi + 7, k * 26 + 20], fill=metal)
    # floating dust (bone white, tiny alpha)
    for i in range(90):
        x = r.uniform(0, LW)
        y = r.uniform(0, LH)
        rr = r.uniform(0.8, 2.4)
        d_ellipse(d, x, y, rr, rr, col(BONE, r.randint(10, 34)))
    return glow


# ==========================================================================
#  SPEC TABLE
# ==========================================================================

def build_specs():
    """(relpath, frame_w, frame_h, frames, draw_fn, scale)"""
    S = []

    def add(path, anims, size, draw_fn, scale=4, tag=None):
        for name, poses in anims.items():
            S.append(dict(rel=path + "/" + name + ".png",
                          fw=size[0], fh=size[1], n=len(poses),
                          kind="poses", poses=poses, draw=draw_fn, scale=scale,
                          tag=tag or name))

    add("characters/player", poses_player(), (64, 64), draw_player_frame, 4)

    # ---- enemies: wax dummy (64) ----
    def wax_frame(size, pose, scale):
        lay = nlayer((size[0] * scale, size[1] * scale))
        d = ScaledDraw(lay, scale)
        f = frame((31.6, 41.4 + pose.get("bob", 0.0)), pose)
        draw_wax_dummy(d, f, pose, scale, rng("waxframe"))
        return lay
    add("enemies", poses_wax_dummy(), (64, 64), wax_frame, 4)

    # ---- child ghost ----
    def ghost_frame(size, pose, scale):
        lay = nlayer((size[0] * scale, size[1] * scale))
        d = ScaledDraw(lay, scale)
        f = frame((31.6, 44.4 + pose.get("bob", 0.0)), pose)
        draw_child_ghost(d, f, pose, scale, rng("ghostframe"))
        return lay
    add("enemies", poses_child_ghost(), (64, 64), ghost_frame, 4)

    # ---- townsman ----
    def town_frame(size, pose, scale):
        lay = nlayer((size[0] * scale, size[1] * scale))
        d = ScaledDraw(lay, scale)
        f = frame((30.4, 41.4 + pose.get("bob", 0.0)), pose)
        draw_townsman(d, f, pose, scale, rng("townframe"))
        return lay
    add("enemies", poses_townsman(), (64, 64), town_frame, 4)

    # ---- morris (128) ----
    def morris_frame(size, pose, scale):
        lay = nlayer((size[0] * scale, size[1] * scale))
        d = ScaledDraw(lay, scale)
        f = frame((64.0, 77.0 + pose.get("bob", 0.0)), pose)
        draw_morris(d, f, pose, scale, rng("morrisframe"))
        return lay
    add("enemies", poses_morris(), (128, 128), morris_frame, 4)

    # ---- props (single frame) ----
    def single(draw_fn, w, h, scale, tag):
        def f(size, pose, sc):
            lay = nlayer((w * scale, h * scale))
            d = ScaledDraw(lay, scale)
            draw_fn(d, (w, h), scale, rng(tag))
            return lay
        return f

    S.append(dict(rel="props/letter.png", fw=32, fh=32, n=1, kind="single",
                  draw=single(prop_letter, 32, 32, 4, "letter"), scale=4))
    S.append(dict(rel="props/notebook.png", fw=32, fh=32, n=1, kind="single",
                  draw=single(prop_notebook, 32, 32, 4, "notebook"), scale=4))
    for w, tag in (("a", "statuea"), ("b", "statueb"), ("c", "statuec")):
        S.append(dict(rel="props/wax_statue_%s.png" % w, fw=32, fh=32, n=1, kind="single",
                      draw=single(lambda d, s, sc, r, w=w: prop_wax_statue(d, s, sc, r, w),
                                  32, 32, 4, tag), scale=4))
    S.append(dict(rel="props/mirror.png", fw=32, fh=32, n=1, kind="single",
                  draw=single(prop_mirror, 32, 32, 4, "mirror"), scale=4))
    S.append(dict(rel="props/checkpoint_lamp.png", fw=64, fh=64, n=1, kind="single",
                  draw=single(prop_checkpoint_lamp, 64, 64, 4, "lamp"), scale=4))
    S.append(dict(rel="props/signboard.png", fw=64, fh=64, n=1, kind="single",
                  draw=single(prop_signboard, 64, 64, 4, "sign"), scale=4))
    S.append(dict(rel="props/big_scissors.png", fw=64, fh=64, n=1, kind="single",
                  draw=single(prop_big_scissors, 64, 64, 4, "scissors"), scale=4))
    S.append(dict(rel="props/button.png", fw=32, fh=32, n=1, kind="single",
                  draw=single(prop_button, 32, 32, 4, "button"), scale=4))
    S.append(dict(rel="props/rag_doll.png", fw=32, fh=32, n=1, kind="single",
                  draw=single(prop_rag_doll, 32, 32, 4, "doll"), scale=4))

    # ---- vfx ----
    S.append(dict(rel="vfx/marker_interact.png", fw=32, fh=32, n=1, kind="single",
                  draw=single(vfx_marker_interact, 32, 32, 4, "mk1"), scale=4))
    S.append(dict(rel="vfx/marker_danger.png", fw=32, fh=32, n=1, kind="single",
                  draw=single(vfx_marker_danger, 32, 32, 4, "mk2"), scale=4))
    def indexed_factory(draw_fn, w, h, scale):
        def f(size, i, sc):
            lay = nlayer((w * scale, h * scale))
            d = ScaledDraw(lay, scale)
            draw_fn(d, (w, h), scale, rng("idx%d" % i), i)
            return lay
        return f

    S.append(dict(rel="vfx/hit_spark.png", fw=32, fh=32, n=4, kind="indexed",
                  draw=indexed_factory(vfx_hit_spark, 32, 32, 4), scale=4))
    S.append(dict(rel="vfx/white_flash.png", fw=64, fh=64, n=1, kind="white",
                  scale=1))

    # ---- ui ----
    S.append(dict(rel="ui/panel_dark.png", fw=64, fh=64, n=1, kind="single",
                  draw=single(ui_panel_dark, 64, 64, 1, "panel"), scale=1))
    S.append(dict(rel="ui/hp_pip_full.png", fw=24, fh=24, n=1, kind="single",
                  draw=single(lambda d, s, sc, r: ui_pip(d, s, sc, r, True), 24, 24, 8, "pipf"), scale=8))
    S.append(dict(rel="ui/hp_pip_empty.png", fw=24, fh=24, n=1, kind="single",
                  draw=single(lambda d, s, sc, r: ui_pip(d, s, sc, r, False), 24, 24, 8, "pipe"), scale=8))
    S.append(dict(rel="ui/hat_icon.png", fw=24, fh=24, n=1, kind="single",
                  draw=single(ui_hat_icon, 24, 24, 8, "hat"), scale=8))

    # ---- backgrounds (single wide images) ----
    S.append(dict(rel="environments/bg_town_far.png", fw=1920, fh=1080, n=1, kind="bg",
                  draw=bg_town_far, scale=2, extra="none"))
    S.append(dict(rel="environments/bg_town_mid.png", fw=1920, fh=1080, n=1, kind="bg",
                  draw=bg_town_mid, scale=2))
    S.append(dict(rel="environments/bg_town_near.png", fw=1920, fh=1080, n=1, kind="bg",
                  draw=bg_town_near, scale=2))
    S.append(dict(rel="environments/bg_wax_lane.png", fw=1920, fh=1080, n=1, kind="bg",
                  draw=bg_wax_lane, scale=2))
    S.append(dict(rel="environments/bg_clocktower.png", fw=1920, fh=1080, n=1, kind="bg",
                  draw=bg_clocktower, scale=2))
    return S


# ==========================================================================
#  MAIN
# ==========================================================================

def generate_one(spec, out_dir):
    fw, fh, n, scale = spec["fw"], spec["fh"], spec["n"], spec["scale"]
    kind = spec["kind"]
    W, H = fw * n, fh
    out = nlayer((W, H))

    if kind == "bg":
        W2, H2 = W * scale, H * scale
        lay = nlayer((W2, H2))
        d = ScaledDraw(lay, scale)
        # backgrounds may return a keep/glow plate
        res = spec["draw"](d, (W2, H2), scale, rng(spec["rel"]))
        if isinstance(res, tuple):
            keep = None
            glow = None
            for item in res:
                if not isinstance(item, Image.Image):
                    continue
                (glow := item) if item.size == (W2, H2) else (keep := item)
            if glow is not None:
                lay = Image.alpha_composite(lay, glow)
            if keep is not None:
                a = ImageChops.multiply(lay.getchannel("A"), keep.getchannel("A"))
                lay.putalpha(a)
        out = downsample(lay, (W, H))

    elif kind == "poses":
        for i, pose in enumerate(spec["poses"]):
            cell = spec["draw"]((fw, fh), pose, scale)
            cell = downsample(cell, (fw, fh))
            out.alpha_composite(cell, (i * fw, 0))

    elif kind == "indexed":
        for i in range(n):
            cell = spec["draw"]((fw, fh), i, scale)
            cell = downsample(cell, (fw, fh))
            out.alpha_composite(cell, (i * fw, 0))

    elif kind == "single":
        cell = spec["draw"]((fw, fh), None, scale)
        out = downsample(cell, (fw, fh))

    elif kind == "white":
        out = white_flash_full((fw, fh))

    path = os.path.join(out_dir, *spec["rel"].split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, "PNG", optimize=True)
    return path, out


def write_manifest(entries, out_dir):
    import json
    data = {"root": "assets", "seed": SEED,
            "files": [{"path": e["rel"].replace(os.sep, "/"), "frame_w": e["fw"],
                       "frame_h": e["fh"], "frames": e["n"],
                       "width": e["fw"] * e["n"], "height": e["fh"]} for e in entries]}
    p = os.path.join(ASSETS, "_placeholder_art_manifest.json")
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    return p


def contact_sheet(cache):
    """Quick QA sheet drawn over a light checkerboard so dark silhouettes read."""
    picks = [
        ("characters/player/player_idle.png", 0, 3),
        ("characters/player/player_run.png", 3, 3),
        ("characters/player/player_attack.png", 3, 3),
        ("characters/player/player_death.png", 2, 3),
        ("enemies/wax_dummy_idle.png", 0, 3),
        ("enemies/wax_dummy_walk.png", 2, 3),
        ("enemies/wax_dummy_attack.png", 3, 3),
        ("enemies/child_ghost_float.png", 1, 3),
        ("enemies/townsman_task.png", 2, 3),
        ("enemies/townsman_dazed.png", 1, 3),
        ("enemies/morris_idle.png", 2, 1),
        ("enemies/morris_spray.png", 3, 1),
        ("props/checkpoint_lamp.png", 0, 2),
        ("props/signboard.png", 0, 2),
        ("props/rag_doll.png", 0, 3),
        ("props/big_scissors.png", 0, 2),
        ("props/mirror.png", 0, 3),
        ("props/notebook.png", 0, 3),
        ("props/letter.png", 0, 3),
        ("props/button.png", 0, 3),
        ("vfx/marker_interact.png", 0, 3),
        ("vfx/marker_danger.png", 0, 3),
        ("vfx/hit_spark.png", 1, 3),
        ("ui/panel_dark.png", 0, 2),
        ("ui/hp_pip_full.png", 0, 4),
    ]
    cell = 150
    cols = 5
    rows = (len(picks) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (150, 148, 156, 255))
    sd = ImageDraw.Draw(sheet)
    sq = 10
    for yy in range(0, sheet.height, sq):
        for xx in range(0, sheet.width, sq):
            if ((xx // sq) + (yy // sq)) % 2:
                sd.rectangle([xx, yy, xx + sq - 1, yy + sq - 1], fill=(126, 124, 134, 255))
    draw = ImageDraw.Draw(sheet)
    for idx, (rel, fi, zoom) in enumerate(picks):
        key = rel
        if key not in cache:
            continue
        img = cache[key]
        src = cache_meta[key]
        w, h = src["fw"], src["fh"]
        f = img.crop((fi * w, 0, fi * w + w, h)).resize((w * zoom, h * zoom), Image.NEAREST)
        cx = (idx % cols) * cell
        cy = (idx // cols) * cell
        sheet.alpha_composite(f, (cx + max(2, (cell - f.width) // 2),
                                  cy + max(2, (cell - f.height) // 2)))
        draw.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], outline=(60, 58, 70, 255))
    sheet.convert("RGB").save(PREVIEW, "PNG")
    return PREVIEW


cache_meta = {}


def main():
    specs = build_specs()
    os.makedirs(ASSETS, exist_ok=True)
    os.makedirs(os.path.join(ROOT, "tools"), exist_ok=True)
    cache = {}
    rows = []
    for spec in specs:
        path, img = generate_one(spec, ASSETS)
        cache[spec["rel"]] = img
        cache_meta[spec["rel"]] = spec
        rows.append((spec, path, img))
        print("  written  %-46s %4dx%-5d  frames=%d" % (
            spec["rel"], img.width, img.height, spec["n"]))

    man = write_manifest([r[0] for r in rows], ASSETS)
    print("\n" + "=" * 78)
    print("PLACEHOLDER ART SUMMARY  (seed=%d)" % SEED)
    print("=" * 78)
    total = 0
    cur = None
    for spec, path, img in sorted(rows, key=lambda r: r[0]["rel"]):
        folder = spec["rel"].rsplit("/", 1)[0]
        if folder != cur:
            print("\n[%s]" % folder)
            cur = folder
        print("  %-30s %5dx%-5d  %d frame(s) of %dx%d" % (
            spec["rel"].rsplit("/", 1)[-1], img.width, img.height,
            spec["n"], spec["fw"], spec["fh"]))
        total += 1
    print("\n  files written : %d" % total)
    print("  manifest      : %s" % man)
    print("  output root   : %s" % ASSETS)
    if os.environ.get("LOOP_TOWN_QA_SHEET") == "1":
        try:
            p = contact_sheet(cache)
            print("  QA preview    : %s" % p)
        except Exception as exc:                              # pragma: no cover
            print("  QA preview    : skipped (%s)" % exc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
