#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回环镇 / Loop Town —— 程序化音频生成器。

设计基调（提示词【三十六】）：黄昏、蜡、锈、钟、火。
所有声音都必须是暗的、低饱和的、轻微失谐的，绝不欢快。

- 纯合成（numpy + 标准库 wave），无任何采样素材，无版权问题。
- 16-bit 单声道 44100 Hz WAV。
- 确定性：所有随机数都来自固定种子，重复运行结果逐字节一致（幂等）。
- 循环素材（music / ambient）在量化前把尾巴交叉淡入头部，
  使第一个样本与最后一个样本几乎重合，接缝不产生 click。

用法：
    python tools/generate_audio.py
    python tools/generate_audio.py --verify      # 只校验，不重新生成
"""

from __future__ import annotations

import argparse
import math
import os
import struct
import sys
import wave
from typing import Callable, Iterable, Sequence

import numpy as np

# ---------------------------------------------------------------------------
# 常量 / 路径
# ---------------------------------------------------------------------------

SR = 44100
ROOT_SEED = 20250917  # 固定总种子

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(HERE)
AUDIO_ROOT = os.path.join(PROJECT_ROOT, "assets", "audio")
SFX_DIR = os.path.join(AUDIO_ROOT, "sfx")
MUSIC_DIR = os.path.join(AUDIO_ROOT, "music")
AMBIENT_DIR = os.path.join(AUDIO_ROOT, "ambient")

SFX_PEAK_DB = -3.0
MUSIC_PEAK_DB = -12.0
AMBIENT_PEAK_DB = -18.0

LOOP_FADE_SEC = 0.025  # 25 ms 循环交叉淡化

# 文件清单：(目录, 基名) —— 用于校验
SFX_NAMES: list[str] = [
    "sfx_attack_swing", "sfx_attack_hit", "sfx_jump", "sfx_land",
    "sfx_hurt", "sfx_death", "sfx_interact", "sfx_pickup",
    "sfx_notebook_open", "sfx_notebook_write", "sfx_ui_click", "sfx_ui_move",
    "sfx_damage_blocked", "sfx_enemy_hit", "sfx_enemy_death",
    "sfx_wax_crack", "sfx_doll_snap", "sfx_ghost_whisper", "sfx_boss_roar",
    "sfx_wax_spray", "sfx_furnace_overheat", "sfx_mirror_turn", "sfx_light_focus",
    "sfx_clock_tick", "sfx_fire_crackle", "sfx_wind",
    "sfx_bell", "sfx_bell_distant", "sfx_nursery_rhyme",
    "sfx_nursery_rhyme_reversed",
]

MUSIC_NAMES: list[str] = [
    "mus_town", "mus_wax", "mus_theater", "mus_well", "mus_clocktower",
    "mus_fire", "mus_ending", "mus_night", "mus_deformed", "mus_morning",
]

AMBIENT_NAMES: list[str] = [
    "amb_town", "amb_wax", "amb_theater", "amb_well", "amb_clocktower",
    "amb_fire", "amb_ending", "amb_town_dusk", "amb_town_night",
    "amb_town_deformed", "amb_morning",
]

# 交叉淡化的循环文件（其余为一次性音效）
LOOPING: set[str] = set(MUSIC_NAMES) | set(AMBIENT_NAMES) | {
    "sfx_fire_crackle", "sfx_wind",
}


# ---------------------------------------------------------------------------
# 循环模式：让音高与噪声“天生周期化”
# ---------------------------------------------------------------------------
#
# 只把尾巴交叉淡入头部是**不够**的：头尾两段噪声互不相关，交叉淡化之后
# 交界处的两个样本仍然是两份不同噪声的叠加，实测接缝差可达上万 LSB（明显 click）。
# 因此循环素材必须让内容本身在文件长度上严格周期：
#   - 所有振荡器频率吸附到 44100 / N 的整数倍（一个循环里正好整数个周期）；
#   - 所有噪声用 rfft 随机相位合成（IFFT 输出天然以 N 为周期）；
#   - 事件颗粒在缓冲区上环绕摆放。
# 这样 x[N] == x[0]，配合交叉淡化（对完全周期的内容它是无损的）接缝差为 0。
# 一次性音效保持原样（用浮点频率与普通噪声，音色更自然）。

LOOP_MODE = False
LOOP_N = 0


def looping() -> bool:
    return LOOP_MODE


def snap_hz(f: float) -> float:
    """把频率吸附到“一个循环内整数个周期”。"""
    if not LOOP_MODE or LOOP_N <= 0:
        return f
    df = SR / float(LOOP_N)
    return max(df, round(f / df) * df)


def make_periodic_noise(n: int, seed: int) -> np.ndarray:
    """以 rfft 随机相位合成噪声：结果严格以 n 为周期。"""
    half = n // 2 + 1
    spec = np.zeros(half, dtype=np.complex128)
    ph = rng("pnoise:%d" % seed).uniform(0.0, 2.0 * np.pi, half)
    spec[1:] = np.exp(1j * ph[1:])
    spec[-1] = spec[-1].real
    sig = np.fft.irfft(spec, n=n)
    peak = float(np.max(np.abs(sig)))
    if peak > 1e-12:
        sig /= peak
    return sig


def noise_at(name: str, duration: float) -> np.ndarray:
    n = n_samples(duration)
    if LOOP_MODE:
        h = 2166136261
        for ch in name:
            h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
        return make_periodic_noise(n, h)
    return rng(name).standard_normal(n)


# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------

def n_samples(seconds: float) -> int:
    return int(round(seconds * SR))


def rng(name: str) -> np.random.Generator:
    """按名字派生确定性随机源（与调用顺序无关）。"""
    h = 2166136261
    for ch in f"{ROOT_SEED}:{name}":
        h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return np.random.default_rng(h)


def t_axis(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def note_hz(name: str) -> float:
    """音名 → 频率，例如 'A3' / 'C#4' / 'Bb2'。"""
    table = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4,
             "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8,
             "A": 9, "A#": 10, "Bb": 10, "B": 11}
    pitch = name[:-1]
    octave = int(name[-1])
    semis = table[pitch] + 12 * (octave + 1)
    return 440.0 * (2.0 ** ((semis - 69) / 12.0))


def cents(hz: float, c: float) -> float:
    """按音分失谐。"""
    return hz * (2.0 ** (c / 1200.0))


def to_int16(x: np.ndarray) -> np.ndarray:
    return np.clip(np.rint(x * 32767.0), -32768.0, 32767.0).astype(np.int16)


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(to_int16(x).tobytes())


def normalize_peak(x: np.ndarray, db: float) -> np.ndarray:
    peak = float(np.max(np.abs(x))) if x.size else 0.0
    if peak <= 1e-12:
        return x
    return x * ((10.0 ** (db / 20.0)) / peak)


def peak_db(x: np.ndarray) -> float:
    peak = float(np.max(np.abs(x))) if x.size else 0.0
    return -999.0 if peak <= 1e-12 else 20.0 * math.log10(peak)


# ---------------------------------------------------------------------------
# 包络 / 振荡器 / 滤波器
# ---------------------------------------------------------------------------

def env_ad(n: int, attack: float, curve: float = 2.0) -> np.ndarray:
    """攻击后按幂曲线衰减的包络。"""
    a = max(1, min(n - 1, int(attack * SR))) if n > 1 else 1
    e = np.ones(n, dtype=np.float64)
    e[:a] = np.sin(np.linspace(0.0, math.pi / 2.0, a)) ** 2
    if n > a:
        tail = np.linspace(0.0, 1.0, n - a)
        e[a:] = (1.0 - tail) ** curve
    return e


def env_points(duration: float, points: Sequence[tuple[float, float]]) -> np.ndarray:
    """按 (时间秒, 值) 控制点线性插值出包络。"""
    n = n_samples(duration)
    if n <= 1:
        return np.ones(n, dtype=np.float64)
    ts = np.array([p[0] for p in points], dtype=np.float64)
    vs = np.array([p[1] for p in points], dtype=np.float64)
    order = np.argsort(ts)
    ts, vs = ts[order], vs[order]
    idx = ts * SR
    return np.interp(np.arange(n, dtype=np.float64), idx, vs)


def env_adsr(n: int, attack: float, decay: float, sustain: float,
             release: float) -> np.ndarray:
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    if a + d + r > n:
        scale = n / float(a + d + r)
        a, d, r = max(1, int(a * scale)), max(1, int(d * scale)), max(1, int(r * scale))
    s = max(0, n - a - d - r)
    e = np.empty(n, dtype=np.float64)
    e[:a] = np.sin(np.linspace(0.0, math.pi / 2.0, a)) ** 2
    e[a:a + d] = sustain + (1.0 - sustain) * (1.0 - np.linspace(0.0, 1.0, d)) ** 2
    e[a + d:a + d + s] = sustain
    e[a + d + s:] = sustain * (1.0 - np.linspace(0.0, 1.0, n - a - d - s)) ** 2
    return e


def sine(freq: float | np.ndarray, duration: float, phase: float = 0.0) -> np.ndarray:
    ts = t_axis(n_samples(duration))
    if np.isscalar(freq):
        f: float | np.ndarray = snap_hz(float(freq))
    else:
        f = np.asarray(freq)
    ph = 2.0 * np.pi * f * ts
    return np.sin(ph + phase)


def sweep_sine(duration: float, f0: float, f1: float, t_end: float | None = None,
               phase: float = 0.0) -> np.ndarray:
    """指数扫频。直接算相位（不用 cumsum），避免长缓冲的浮点漂移。"""
    n = n_samples(duration)
    ts = t_axis(n)
    span = duration if t_end is None else min(t_end, duration)
    u = np.clip(ts / max(1e-9, span), 0.0, 1.0)
    f = f0 * (f1 / f0) ** u
    # 指数扫频的相位积分有闭式解
    k = math.log(f1 / f0)
    ph = 2.0 * np.pi * f0 * span * (np.exp(k * u) - 1.0) / k if abs(k) > 1e-9 else 2.0 * np.pi * f0 * ts
    return np.sin(ph + phase)


def add_harmonics(freq: float, duration: float, count: int = 16,
                  rolloff: float = 1.0) -> np.ndarray:
    n = n_samples(duration)
    ts = t_axis(n)
    base = snap_hz(freq)
    out = np.zeros(n, dtype=np.float64)
    for k in range(1, count + 1):
        fk = snap_hz(base * k) if LOOP_MODE else freq * k
        out += (1.0 / (k ** rolloff)) * np.sin(2.0 * np.pi * fk * ts + 0.37 * k)
    return out


def saw(freq: float, duration: float, top_hz: float = 6000.0) -> np.ndarray:
    """加性限带锯齿（暗的、失谐友好的音色）。"""
    fq = snap_hz(freq)
    top = max(1, int(top_hz / max(1.0, fq)))
    return add_harmonics(fq, duration, count=min(top, 90), rolloff=1.0)


def square(freq: float, duration: float, top_hz: float = 5000.0) -> np.ndarray:
    n = n_samples(duration)
    fq = snap_hz(freq)
    top = max(1, int(top_hz / max(1.0, fq)))
    out = np.zeros(n, dtype=np.float64)
    for k in range(1, min(top, 80) + 1, 2):
        out += (1.0 / k) * sine(fq * k, duration, phase=0.19 * k)
    return out


def noise(duration: float, name: str) -> np.ndarray:
    return noise_at(name, duration)


def biquad(x: np.ndarray, kind: str, f0: float, q: float = 0.707) -> np.ndarray:
    f = max(15.0, min(float(snap_hz(f0)), SR * 0.45))
    w0 = 2.0 * math.pi * f / SR
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * max(0.05, q))
    if kind == "lp":
        b = ((1.0 - cw) / 2.0, 1.0 - cw, (1.0 - cw) / 2.0)
    elif kind == "hp":
        b = ((1.0 + cw) / 2.0, -(1.0 + cw), (1.0 + cw) / 2.0)
    elif kind == "bp":
        b = (alpha, 0.0, -alpha)
    else:
        raise ValueError(kind)
    a = (1.0 + alpha, -2.0 * cw, 1.0 - alpha)
    b0, b1, b2 = b[0] / a[0], b[1] / a[0], b[2] / a[0]
    a1, a2 = a[1] / a[0], a[2] / a[0]
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(x.size):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, xi
        y2, y1 = y1, yi
        y[i] = yi
    return y


def lp1(x: np.ndarray, fc: float) -> np.ndarray:
    a = 1.0 - math.exp(-2.0 * math.pi * max(1.0, fc) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def hp1(x: np.ndarray, fc: float) -> np.ndarray:
    return x - lp1(x, fc)


def _circ_response(freqs: np.ndarray, fc: float, kind: str) -> np.ndarray:
    h = 1.0 / np.sqrt(1.0 + (freqs / max(1.0, fc)) ** 2)
    return h if kind == "lp" else 1.0 - h


def lp1c(x: np.ndarray, fc: float) -> np.ndarray:
    """环形（周期）一阶低通：频域实现，输出严格以 x.size 为周期。

    循环素材必须用它：普通 IIR 的启动瞬态会破坏首尾一致性。
    """
    n = x.size
    if n < 8:
        return x
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x) * _circ_response(f, fc, "lp"), n=n)


def hp1c(x: np.ndarray, fc: float) -> np.ndarray:
    n = x.size
    if n < 8:
        return x
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x) * _circ_response(f, fc, "hp"), n=n)


def bqc(x: np.ndarray, kind: str, f0: float, q: float = 0.707) -> np.ndarray:
    """环形双二阶：用模拟原型的幅频响应做频域整形（周期安全）。"""
    n = x.size
    if n < 8:
        return x
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f0 = max(15.0, float(snap_hz(f0)))
    if kind == "bp":
        h = 1.0 / np.sqrt(1.0 + ((f - f0) / max(1e-6, f0 / max(0.2, q))) ** 2)
    elif kind == "lp":
        h = _circ_response(f, f0, "lp")
    elif kind == "hp":
        h = _circ_response(f, f0, "hp")
    else:
        raise ValueError(kind)
    return np.fft.irfft(np.fft.rfft(x) * h, n=n)


def lp_fft(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    """零相位频谱低通（用于给钟声做厚重低通）。"""
    n = x.size
    if n < 64:
        return x
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    h = 1.0 / np.sqrt(1.0 + (freqs / max(1.0, fc)) ** (2.0 * order))
    return np.fft.irfft(spec * h, n=n)


def reverb_ir(seconds: float, decay: float, lp_hz: float, name: str) -> np.ndarray:
    n = max(16, n_samples(seconds))
    ir = rng("ir:" + name).standard_normal(n)
    ir *= np.exp(-np.arange(n) / (SR * decay))
    ir = lp1(ir, lp_hz)
    ir[0] += 1.0  # 保留直达声
    if LOOP_MODE:
        # 环形卷积要求 IR 自身首尾连续：否则混响尾会被绕回文件开头，等于在循环点上
        # 插入一段 ~100 ms 的混响，接缝立刻变成明显的 click。
        # 让 IR 的后 70% 平滑收零（早期反射保留，尾巴在循环点之前结束）。
        keep = int(n * 0.3)
        ramped = np.clip((np.arange(n) - keep) / max(1, n - keep), 0.0, 1.0)
        ir = ir * (1.0 - ramped) ** 1.5
    e = float(np.sum(ir ** 2))
    if e > 0:
        ir /= math.sqrt(e)
    return ir


def convolve_ir(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    n = x.size + ir.size - 1
    nfft = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), n=nfft)
    return y[:x.size]


def apply_reverb(x: np.ndarray, seconds: float, decay: float, lp_hz: float,
                 wet: float, name: str) -> np.ndarray:
    ir = reverb_ir(seconds, decay, lp_hz, name)
    tail = convolve_ir(x, ir)
    peak = float(np.max(np.abs(tail))) if tail.size else 0.0
    if peak > 1e-12:
        tail /= peak
    src = float(np.max(np.abs(x))) if x.size else 0.0
    if src > 1e-12:
        tail *= src
    return (1.0 - wet) * x + wet * tail


def formant(x: np.ndarray, pairs: Sequence[tuple[float, float, float]]) -> np.ndarray:
    """(中心频率, Q, 增益) 共振峰叠加，用来做“元音化”的嗓音。"""
    out = np.zeros_like(x)
    for f0, q, g in pairs:
        out += g * biquad(x, "bp", f0, q)
    return out


def grains(n: int, rng_: np.random.Generator, rate: float, f_lo: float,
           f_hi: float, decay_range: tuple[float, float],
           amp_range: tuple[float, float], name: str) -> np.ndarray:
    """随机颗粒（碎裂、滴落、噼啪）。"""
    out = np.zeros(n, dtype=np.float64)
    count = max(1, int(rate * n / SR))
    for i in range(count):
        dec = float(rng_.uniform(*decay_range))
        m = max(8, n_samples(dec))
        if m > n:
            m = n
        f = float(rng_.uniform(f_lo, f_hi))
        g = rng("grain:%s:%d" % (name, i)).standard_normal(m)
        g = biquad(g, "bp", f, 1.6)
        g *= env_ad(m, 0.0004, 2.4) * float(rng_.uniform(*amp_range))
        start = int(rng_.uniform(0, max(1, n - m)))
        out[start:start + m] += g
    return out


def put(dst: np.ndarray, src: np.ndarray, start: int, wrap: bool = True) -> None:
    n = dst.size
    if n <= 0 or src.size == 0:
        return
    start %= n
    if wrap and start + src.size > n:
        head = n - start
        dst[start:] += src[:head]
        rest = src[head:]
        if rest.size:
            if rest.size <= n:
                dst[:rest.size] += rest
            else:
                reps = int(math.ceil(rest.size / n))
                pad = np.tile(rest, reps)[:n]
                dst[:] += pad
    else:
        end = min(n, start + src.size)
        dst[start:end] += src[:end - start]


def add_note(dst: np.ndarray, start: float, freq: float, dur: float,
             wave_fn: Callable[[float, float], np.ndarray],
             attack: float = 0.005, decay: float = 1.4,
             amp: float = 0.2, detune_cents: float = 0.0) -> None:
    f = snap_hz(cents(freq, detune_cents))
    sig = wave_fn(f, dur)
    m = sig.size
    sig = sig * env_ad(m, attack, decay)
    put(dst, amp * sig, n_samples(start))


# ---------------------------------------------------------------------------
# 循环交叉淡化
# ---------------------------------------------------------------------------

def make_loop(x: np.ndarray, fade_sec: float = LOOP_FADE_SEC) -> np.ndarray:
    """循环素材的收尾处理。

    注意：这里**不做**头尾交叉淡化。实测证明，对基础内容本身不周期的素材，
    交叉淡化会把两份互不相关的波形直接相加（接缝差反而从 ~160 LSB 涨到 ~140000 LSB）。
    本生成器的循环素材（music / ambient / sfx_wind / sfx_fire_crackle）全部
    从构造上就是严格周期的：
        - 振荡器频率吸附到 44100/N 的整数倍
        - 噪声用 rfft 随机相位合成（天然以 N 为周期）
        - 滤波器用环形（频域）实现
        - 调制用 LFO 频率同样吸附
        - 颗粒事件在缓冲区上环绕摆放
    因此 x[N] == x[0]，直接返回即可；只保留一个极短的防爆音淡化以防数值意外。
    """
    n = x.size
    guard = min(n_samples(0.002), n // 8)
    if guard >= 2:
        y = x.copy()
        g = np.sin(np.pi * 0.5 * (np.arange(guard) + 0.5) / guard) ** 2
        y[:guard] *= g
        y[n - guard:] *= g[::-1]
        return y
    return x


# 交叉淡化窗口内的包络（仅用于校验；与 make_loop 保持一致）
def loop_gain(n: int, fade_sec: float = LOOP_FADE_SEC) -> np.ndarray:
    fade = min(n_samples(fade_sec), n // 3)
    g = np.ones(n, dtype=np.float64)
    if fade >= 2:
        idx = np.arange(fade, dtype=np.float64)
        w = np.sin(np.pi * 0.5 * (idx + 0.5) / fade) ** 2
        g[:fade] = 1.0 - w
        g[n - fade:] = w
    return g


# ---------------------------------------------------------------------------
# SFX 构造块
# ---------------------------------------------------------------------------

def drum_pickup(duration: float, f_lo: float, f_hi: float, decay: float,
                snap: float, noise_amt: float, name: str) -> np.ndarray:
    n = n_samples(duration)
    ts = t_axis(n)
    f = f_lo * (f_hi / f_lo) ** (ts / max(1e-6, duration))
    body = np.sin(2.0 * np.pi * np.cumsum(f) / SR) * np.exp(-ts / decay)
    nz = biquad(rng("drum:" + name).standard_normal(n), "bp", 1900.0, 1.1)
    nz *= np.exp(-ts / max(0.002, snap)) * noise_amt
    return body + nz


def thud(duration: float = 0.3, f0: float = 96.0, f1: float = 52.0,
         decay: float = 0.075, noise_amt: float = 0.7, noise_fc: float = 420.0,
         name: str = "thud") -> np.ndarray:
    n = n_samples(duration)
    ts = t_axis(n)
    f = f0 * (f1 / f0) ** np.clip(ts / 0.055, 0.0, 1.0)
    body = np.sin(2.0 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.0015, 2.2)
    nz = lp1(rng("thud:" + name).standard_normal(n), noise_fc)
    nz *= env_ad(n, 0.0008, 4.5) * noise_amt
    return body * np.exp(-ts / decay) + nz


def tick(duration: float = 0.09, f: float = 1220.0, q: float = 9.0,
         noise_amt: float = 0.5, name: str = "tick") -> np.ndarray:
    n = n_samples(duration)
    res = biquad(rng("tick:" + name).standard_normal(n), "bp", f, q)
    res *= env_ad(n, 0.0004, 4.0)
    clk = rng("tickc:" + name).standard_normal(n) * env_ad(n, 0.0002, 8.0) * noise_amt
    return res + clk


def crackle_grain(name: str, seed: int, f_lo: float = 900.0,
                  f_hi: float = 4200.0, dur: float = 0.02) -> np.ndarray:
    m = n_samples(dur)
    g = rng("crk:%s:%d" % (name, seed)).standard_normal(m)
    g = biquad(g, "hp", 700.0)
    g = biquad(g, "bp", float(rng("crkf:%s:%d" % (name, seed)).uniform(f_lo, f_hi)), 1.3)
    return g * env_ad(m, 0.0003, 3.2)


def moan(freq: float, duration: float, detune: float, wobble_hz: float,
         name: str) -> np.ndarray:
    """低沉的呜咽 / 呻吟。

    用直接相位（不用 cumsum）并把调制频率吸附到循环网格，因此循环素材里
    调用它是严格周期的；一次性音效（SFX）不受影响。
    """
    n = n_samples(duration)
    ts = t_axis(n)
    f0 = snap_hz(freq)
    w = snap_hz(wobble_hz)
    lfo = 1.0 + 0.004 * np.sin(2.0 * np.pi * snap_hz(0.9) * ts) + 0.002 * np.sin(
        2.0 * np.pi * w * ts + 0.7)
    ph = 2.0 * np.pi * f0 * ts * lfo
    v1 = np.sin(ph)
    v2 = np.sin(2.0 * np.pi * snap_hz(f0 * (1.0 + detune)) * ts * lfo + 1.3)
    v3 = np.sin(2.0 * np.pi * snap_hz(f0 * (1.0 - detune * 0.6)) * ts * lfo + 2.1)
    rough = 0.5 + 0.5 * np.sin(2.0 * np.pi * w * ts)
    nz = lp1c(noise_at("moan:" + name, duration), 260.0) * 0.35 * rough \
        if LOOP_MODE else lp1(rng("moan:" + name).standard_normal(n), 260.0) * 0.35 * rough
    return 0.5 * (v1 + v2 + v3) * (1.0 + 0.25 * rough) + nz


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

SFX_BUILDERS: dict[str, Callable[[], np.ndarray]] = {}


def sfx(name: str) -> Callable[[Callable[[], np.ndarray]], Callable[[], np.ndarray]]:
    def deco(fn: Callable[[], np.ndarray]) -> Callable[[], np.ndarray]:
        SFX_BUILDERS[name] = fn
        return fn
    return deco


@sfx("sfx_attack_swing")
def _b() -> np.ndarray:
    dur = 0.34
    n = n_samples(dur)
    ts = t_axis(n)
    f = 2600.0 * (420.0 / 2600.0) ** (ts / dur)
    nz = rng("swing").standard_normal(n)
    filt = biquad(nz, "bp", float(np.mean(f)), 0.9)
    # 三段近似跟踪下扫的带通
    seg = np.array_split(np.arange(n), 6)
    out = np.zeros(n)
    for k, idx in enumerate(seg):
        if idx.size:
            fc = float(f[idx[0]])
            out[idx] = biquad(nz[idx], "bp", fc, 1.4) + 0.6 * biquad(nz[idx], "bp", fc * 2.2, 1.1)
    env = env_ad(n, 0.012, 1.7)
    air = hp1(nz, 3200.0) * env_ad(n, 0.008, 3.0) * 0.35
    sub = np.sin(2.0 * np.pi * np.cumsum(180.0 * (90.0 / 180.0) ** (ts / dur)) / SR)
    sub *= env_ad(n, 0.05, 3.0) * 0.25
    return (out + air + sub) * env + filt * 0.1 * env


@sfx("sfx_attack_hit")
def _b() -> np.ndarray:
    dur = 0.3
    n = n_samples(dur)
    ts = t_axis(n)
    body = thud(dur, 118.0, 46.0, 0.085, 0.75, 380.0, "hit")
    wet = lp1(rng("hitwet").standard_normal(n), 900.0) * env_ad(n, 0.002, 5.0) * 0.4
    dull = lp_fft(body + wet, 2600.0, 2)
    return dull * env_ad(n, 0.0006, 1.2)


@sfx("sfx_jump")
def _b() -> np.ndarray:
    dur = 0.3
    n = n_samples(dur)
    ts = t_axis(n)
    f = 190.0 * (430.0 / 190.0) ** (ts / dur)
    body = np.sin(2.0 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.015, 2.2)
    nz = biquad(rng("jump").standard_normal(n), "bp", 1500.0, 0.9)
    nz *= env_ad(n, 0.02, 3.0) * 0.35
    return body * 0.7 + nz * lp_fft(np.ones(n), 5200.0, 2)


@sfx("sfx_land")
def _b() -> np.ndarray:
    dur = 0.3
    n = n_samples(dur)
    body = thud(dur, 84.0, 40.0, 0.1, 0.45, 300.0, "land")
    wood = biquad(rng("landw").standard_normal(n), "bp", 420.0, 3.5)
    wood *= env_ad(n, 0.001, 7.0) * 0.22
    return lp_fft(body + wood, 3000.0, 2)


@sfx("sfx_hurt")
def _b() -> np.ndarray:
    dur = 0.42
    n = n_samples(dur)
    ts = t_axis(n)
    sting = (0.55 * np.sin(2.0 * np.pi * 233.08 * ts)
             + 0.45 * np.sin(2.0 * np.pi * 246.94 * ts + 0.6)
             + 0.3 * np.sin(2.0 * np.pi * 116.54 * ts + 1.4))
    sting *= env_ad(n, 0.004, 2.4)
    voice = formant(rng("hurt").standard_normal(n),
                    [(620.0, 4.0, 1.0), (1180.0, 5.0, 0.6), (2400.0, 6.0, 0.25)])
    voice *= env_ad(n, 0.01, 3.2) * 0.3
    return lp_fft(sting + voice, 4200.0, 2)


@sfx("sfx_death")
def _b() -> np.ndarray:
    dur = 2.0
    n = n_samples(dur)
    ts = t_axis(n)
    glide = 220.0 * (55.0 / 220.0) ** np.clip(ts / 1.7, 0.0, 1.0)
    vib = 1.0 + 0.006 * np.sin(2.0 * np.pi * 3.1 * ts)
    a = np.sin(2.0 * np.pi * np.cumsum(glide * vib) / SR)
    b = np.sin(2.0 * np.pi * np.cumsum(glide * vib * 1.007) / SR + 0.9)
    c = np.sin(2.0 * np.pi * np.cumsum(glide * 2.0 * vib) / SR + 2.0) * 0.35
    tone = (a + 0.85 * b + c) / 2.2
    tone *= env_ad(n, 0.03, 1.35)
    breath = lp1(rng("death").standard_normal(n), 700.0) * env_ad(n, 0.09, 2.2) * 0.35
    tail = apply_reverb(tone + breath, 2.2, 0.95, 1400.0, 0.5, "death")
    return tail * np.clip(env_ad(n, 0.02, 0.5), 0.0, 1.0)


@sfx("sfx_interact")
def _b() -> np.ndarray:
    return drum_pickup(0.26, 520.0, 330.0, 0.055, 0.02, 0.25, "interact") * 0.9 \
        + drum_pickup(0.26, 780.0, 529.0, 0.04, 0.02, 0.15, "interact2") * 0.35


@sfx("sfx_pickup")
def _b() -> np.ndarray:
    dur = 0.45
    n = n_samples(dur)
    r = rng("pickup")
    out = np.zeros(n)
    pos = 0.0
    while pos < dur:
        m = n_samples(float(r.uniform(0.02, 0.06)))
        g = r.standard_normal(m)
        g = hp1(g, 1600.0)
        g = biquad(g, "bp", float(r.uniform(1800.0, 5200.0)), 1.2)
        g *= env_ad(m, 0.004, 2.0) * float(r.uniform(0.35, 1.0))
        put(out, g, n_samples(pos), wrap=False)
        pos += float(r.uniform(0.03, 0.09))
    body = lp1(noise_at("mfire", dur), 500.0) * env_ad(n, 0.01, 5.0) * 0.15
    return hp1(out, 700.0) + body


@sfx("sfx_notebook_open")
def _b() -> np.ndarray:
    dur = 0.7
    n = n_samples(dur)
    ts = t_axis(n)
    r = rng("nbopen")
    creak = biquad(noise_at("mfire", dur), "bp", 420.0, 2.2)
    creak *= (0.5 + 0.5 * np.sin(2.0 * np.pi * 17.0 * ts + np.sin(2.0 * np.pi * 3.0 * ts)))
    creak *= env_points(dur, [(0.0, 0.0), (0.12, 0.7), (0.5, 1.0), (0.68, 0.0)])
    low = lp1(noise_at("mfire", dur), 220.0) * env_ad(n, 0.02, 2.5) * 0.4
    paper = hp1(noise_at("mfire", dur), 2200.0) * env_points(
        dur, [(0.0, 0.0), (0.3, 0.25), (0.5, 0.5), (0.7, 0.0)])
    return creak * 0.9 + low + paper * 0.5


@sfx("sfx_notebook_write")
def _b() -> np.ndarray:
    dur = 0.24
    n = n_samples(dur)
    r = rng("nbwrite")
    out = np.zeros(n)
    pos = 0.0
    while pos < dur:
        m = n_samples(float(r.uniform(0.012, 0.03)))
        g = hp1(r.standard_normal(m), 1800.0)
        g = biquad(g, "bp", float(r.uniform(2400.0, 6000.0)), 1.0)
        g *= env_ad(m, 0.002, 1.6) * float(r.uniform(0.5, 1.0))
        put(out, g, n_samples(pos), wrap=False)
        pos += float(r.uniform(0.015, 0.035))
    return out * env_points(dur, [(0.0, 0.0), (0.01, 1.0), (0.2, 0.6), (0.24, 0.0)])


@sfx("sfx_ui_click")
def _b() -> np.ndarray:
    return tick(0.09, 1450.0, 7.0, 0.55, "uiclick") \
        + drum_pickup(0.09, 900.0, 620.0, 0.02, 0.006, 0.1, "uiclick2") * 0.5


@sfx("sfx_ui_move")
def _b() -> np.ndarray:
    return tick(0.06, 2150.0, 8.0, 0.4, "uimove") * 0.55


@sfx("sfx_damage_blocked")
def _b() -> np.ndarray:
    dur = 0.34
    n = n_samples(dur)
    body = thud(dur, 150.0, 90.0, 0.035, 0.4, 700.0, "block")
    metal = (biquad(rng("blk1").standard_normal(n), "bp", 2350.0, 12.0) * 0.6
             + biquad(rng("blk2").standard_normal(n), "bp", 3720.0, 14.0) * 0.4
             + biquad(rng("blk3").standard_normal(n), "bp", 5400.0, 16.0) * 0.25)
    metal *= env_ad(n, 0.0006, 6.5)
    return body * 0.8 + metal


@sfx("sfx_enemy_hit")
def _b() -> np.ndarray:
    dur = 0.28
    n = n_samples(dur)
    body = thud(dur, 165.0, 70.0, 0.05, 1.0, 900.0, "ehit")
    squelch = biquad(rng("ehits").standard_normal(n), "bp", 700.0, 1.4)
    squelch *= env_ad(n, 0.004, 5.0) * 0.5
    return lp_fft(body + squelch, 3400.0, 2)


@sfx("sfx_enemy_death")
def _b() -> np.ndarray:
    dur = 1.15
    n = n_samples(dur)
    ts = t_axis(n)
    g = moan(150.0, dur, 0.014, 15.0, "edeath")
    g *= np.clip(1.0 - ts / dur, 0.0, 1.0) ** 1.2
    g *= 1.0 + 0.4 * np.sin(2.0 * np.pi * 9.0 * ts)
    crk = grains(n, rng("edeathg"), 9.0, 500.0, 3200.0, (0.004, 0.014),
                 (0.2, 0.6), "edeath")
    crk *= np.clip(1.0 - ts / dur, 0.0, 1.0)
    th = thud(0.3, 120.0, 44.0, 0.07, 0.7, 400.0, "edeaththud")
    out = np.zeros(n)
    put(out, g, 0, wrap=False)
    put(out, crk, 0, wrap=False)
    put(out, th, 0, wrap=False)
    return lp_fft(out, 4200.0, 2)


@sfx("sfx_wax_crack")
def _b() -> np.ndarray:
    dur = 0.5
    n = n_samples(dur)
    click = rng("waxc").standard_normal(n) * env_ad(n, 0.0002, 20.0)
    click = hp1(click, 2000.0)
    body = biquad(rng("waxb").standard_normal(n), "bp", 3200.0, 2.0) * env_ad(n, 0.0005, 9.0)
    crk = grains(n, rng("waxg"), 45.0, 700.0, 3800.0, (0.002, 0.007),
                 (0.2, 0.85), "wax")
    return click * 0.9 + body * 0.6 + crk


@sfx("sfx_doll_snap")
def _b() -> np.ndarray:
    dur = 0.75
    n = n_samples(dur)
    r = rng("doll")
    crack = (noise_at("mfire", dur) * env_ad(n, 0.0002, 16.0))
    crack = hp1(crack, 2500.0)
    ring = (biquad(noise_at("mfire", dur), "bp", 2600.0, 9.0) * 0.4
            + biquad(noise_at("mfire", dur), "bp", 4300.0, 11.0) * 0.3)
    ring *= env_ad(n, 0.0004, 5.0)
    shards = np.zeros(n)
    for i in range(26):
        m = n_samples(float(r.uniform(0.006, 0.02)))
        g = hp1(r.standard_normal(m), 2200.0)
        g *= env_ad(m, 0.0003, 3.0) * float(r.uniform(0.15, 0.8))
        start = n_samples(float(r.uniform(0.0, 0.62)))
        put(shards, g, start, wrap=False)
    low = lp1(noise_at("mfire", dur), 260.0) * env_ad(n, 0.001, 8.0) * 0.3
    return crack + ring + shards * 0.8 + low


@sfx("sfx_ghost_whisper")
def _b() -> np.ndarray:
    dur = 1.5
    n = n_samples(dur)
    ts = t_axis(n)
    src = rng("ghost").standard_normal(n)
    out = np.zeros(n)
    src1 = biquad(src, "bp", 720.0, 5.0) * 0.7
    src2 = biquad(src, "bp", 1180.0, 6.0) * 0.5
    src3 = biquad(src, "bp", 2450.0, 7.0) * 0.25
    am = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2.0 * np.pi * 0.7 * ts
                                          + 2.4 * np.sin(2.0 * np.pi * 0.23 * ts)))
    breath = 0.6 + 0.4 * np.sin(2.0 * np.pi * 0.31 * ts + 1.1)
    out = (src1 * (0.6 + 0.4 * breath) + src2 * am + src3 * breath)
    out *= env_points(dur, [(0.0, 0.0), (0.35, 0.8), (0.7, 1.0), (1.2, 0.5), (1.5, 0.0)])
    out = lp_fft(out, 5200.0, 2)
    return apply_reverb(out, 1.0, 0.5, 2600.0, 0.25, "ghost")


@sfx("sfx_boss_roar")
def _b() -> np.ndarray:
    dur = 1.55
    n = n_samples(dur)
    ts = t_axis(n)
    bend = 62.0 * (48.0 / 62.0) ** np.clip(ts / 1.2, 0.0, 1.0)
    a = saw(58.0, dur, 2400.0)
    b = saw(58.0 * 1.011, dur, 2000.0)
    c = saw(58.0 * 0.988, dur, 1600.0)
    growl = (a + b + c) / 3.0
    wob = 0.6 + 0.4 * np.sin(2.0 * np.pi * 6.5 * ts)
    sub = np.sin(2.0 * np.pi * np.cumsum(bend) / SR)
    rough = lp1(rng("roar").standard_normal(n), 350.0) * 0.5
    fm = np.sin(2.0 * np.pi * np.cumsum(bend * 3.0) / SR
                + 1.2 * np.sin(2.0 * np.pi * 7.0 * ts))
    out = growl * wob * 0.8 + sub * 0.7 + rough * (0.6 + 0.4 * wob) + fm * 0.2
    out *= env_points(dur, [(0.0, 0.0), (0.06, 0.9), (0.35, 1.0),
                            (1.1, 0.7), (1.55, 0.0)])
    return lp_fft(out, 3000.0, 2)


@sfx("sfx_wax_spray")
def _b() -> np.ndarray:
    dur = 1.2
    n = n_samples(dur)
    ts = t_axis(n)
    src = rng("spray").standard_normal(n)
    hiss = hp1(src, 2600.0)
    mid = biquad(src, "bp", 1800.0, 0.8) * 0.6
    am = 0.75 + 0.25 * np.sin(2.0 * np.pi * 5.3 * ts + 0.8 * np.sin(2.0 * np.pi * 1.7 * ts))
    out = (hiss * 0.6 + mid) * am
    out *= env_points(dur, [(0.0, 0.0), (0.06, 1.0), (0.95, 0.95), (1.2, 0.0)])
    out = lp_fft(out, 7000.0, 1)
    return out


@sfx("sfx_furnace_overheat")
def _b() -> np.ndarray:
    dur = 1.45
    n = n_samples(dur)
    ts = t_axis(n)
    prog = ts / dur
    src = rng("furnace").standard_normal(n)
    rumble = lp1(src, 60.0) * (1.0 + 3.0 * prog)
    rumble = lp_fft(rumble, 180.0, 2)
    rise = np.sin(2.0 * np.pi * np.cumsum(30.0 * (90.0 / 30.0) ** prog) / SR)
    ring_f = 1860.0 * (1.0 + 0.06 * prog)
    ring = (np.sin(2.0 * np.pi * ring_f * ts) * 0.5
            + np.sin(2.0 * np.pi * ring_f * 1.5 * ts + 0.3) * 0.3
            + np.sin(2.0 * np.pi * ring_f * 2.02 * ts + 1.0) * 0.2)
    ring *= (0.5 + 0.5 * np.sin(2.0 * np.pi * 7.0 * ts)) * (prog ** 2)
    out = rumble * 0.7 + rise * 0.5 + ring * 0.35
    out *= env_points(dur, [(0.0, 0.0), (0.1, 0.35), (1.1, 0.9), (1.45, 0.0)])
    return lp_fft(out, 5200.0, 2)


@sfx("sfx_mirror_turn")
def _b() -> np.ndarray:
    dur = 0.62
    n = n_samples(dur)
    ts = t_axis(n)
    f = 900.0 * (4200.0 / 900.0) ** (ts / dur)
    src = rng("mirror").standard_normal(n)
    seg = np.array_split(np.arange(n), 8)
    out = np.zeros(n)
    for idx in seg:
        if idx.size:
            fc = float(f[idx[0]])
            out[idx] = biquad(src[idx], "bp", fc, 5.0) * 0.7 + biquad(src[idx], "bp", fc * 1.6, 6.0) * 0.4
    out *= env_points(dur, [(0.0, 0.0), (0.05, 0.8), (0.5, 1.0), (0.62, 0.0)])
    glass = hp1(rng("mirror2").standard_normal(n), 5000.0)
    glass *= env_ad(n, 0.004, 4.0) * 0.35
    return out + glass


@sfx("sfx_light_focus")
def _b() -> np.ndarray:
    dur = 1.2
    n = n_samples(dur)
    ts = t_axis(n)
    base = 1318.51
    tone = (np.sin(2.0 * np.pi * base * ts)
            + 0.6 * np.sin(2.0 * np.pi * base * 1.003 * ts + 0.4)
            + 0.4 * np.sin(2.0 * np.pi * base * 1.501 * ts + 1.2)
            + 0.25 * np.sin(2.0 * np.pi * base * 2.004 * ts + 2.0))
    shimmer = 1.0 + 0.05 * np.sin(2.0 * np.pi * 5.5 * ts + 2.0 * np.sin(2.0 * np.pi * 0.9 * ts))
    tone *= shimmer
    tone *= env_points(dur, [(0.0, 0.0), (0.25, 0.85), (0.85, 1.0), (1.2, 0.0)])
    air = hp1(rng("light").standard_normal(n), 6000.0)
    air *= env_points(dur, [(0.0, 0.0), (0.4, 0.5), (1.2, 0.1)]) * 0.3
    return lp_fft(tone, 9000.0, 2) * 0.8 + air


@sfx("sfx_clock_tick")
def _b() -> np.ndarray:
    dur = 0.12
    n = n_samples(dur)
    a = tick(0.06, 1320.0, 10.0, 0.6, "tickA")
    b = tick(0.05, 880.0, 9.0, 0.35, "tickB") * 0.45
    out = np.zeros(n)
    put(out, a, 0, wrap=False)
    put(out, b, n_samples(0.008), wrap=False)
    esc = biquad(rng("tickesc").standard_normal(n), "bp", 4200.0, 4.0)
    esc *= env_ad(n, 0.0003, 9.0) * 0.25
    return out + esc


@sfx("sfx_fire_crackle")
def _b() -> np.ndarray:
    dur = 2.0
    n = n_samples(dur)
    ts = t_axis(n)
    r = rng("firec")
    src = noise_at("firec", dur)          # 循环模式下为周期噪声
    bed = lp1c(src, 420.0) * 0.5
    bed *= 0.7 + 0.3 * np.sin(2.0 * np.pi * snap_hz(0.9) * ts
                            + 0.5 * np.sin(2.0 * np.pi * snap_hz(0.31) * ts))
    rumble = lp1c(src, 70.0) * 0.4
    out = bed + rumble
    pos = 0.0
    i = 0
    while pos < dur:
        g = crackle_grain("firec", i, 800.0, 5000.0,
                          float(r.uniform(0.004, 0.018)))
        put(out, g * float(r.uniform(0.15, 0.9)), n_samples(pos))
        pos += float(r.uniform(0.008, 0.09))
        i += 1
    return lp_fft(out, 6500.0, 1)


@sfx("sfx_wind")
def _b() -> np.ndarray:
    dur = 2.0
    n = n_samples(dur)
    ts = t_axis(n)
    src = noise_at("wind", dur)           # 循环模式下为周期噪声
    gust = (1.0
            + 0.45 * np.sin(2.0 * np.pi * snap_hz(0.23) * ts + 0.4)
            + 0.25 * np.sin(2.0 * np.pi * snap_hz(0.37) * ts + 2.0)
            + 0.12 * np.sin(2.0 * np.pi * snap_hz(0.11) * ts + 1.0))
    low = lp1c(src, 320.0) * gust
    mid = bqc(src, "bp", 700.0, 0.7) * (0.5 + 0.5 * gust) * 0.5
    whistle = bqc(src, "bp", 1450.0, 9.0) * (0.35 + 0.65 * np.sin(
        2.0 * np.pi * snap_hz(0.19) * ts) ** 2) * 0.3
    return lp_fft(low + mid + whistle, 3800.0, 1)


@sfx("sfx_wind")
def _b() -> np.ndarray:
    dur = 2.0
    n = n_samples(dur)
    ts = t_axis(n)
    src = noise_at("wind", dur)          # 循环模式下为周期噪声
    gust = (1.0
            + 0.45 * np.sin(2.0 * np.pi * snap_hz(0.23) * ts + 0.4)
            + 0.25 * np.sin(2.0 * np.pi * snap_hz(0.37) * ts + 2.0)
            + 0.12 * np.sin(2.0 * np.pi * snap_hz(0.11) * ts + 1.0))
    low = lp1c(src, 320.0) * gust
    mid = bqc(src, "bp", 700.0, 0.7) * (0.5 + 0.5 * gust) * 0.5
    whistle = bqc(src, "bp", 1450.0, 9.0) * (0.35 + 0.65 * np.sin(
        2.0 * np.pi * snap_hz(0.19) * ts) ** 2) * 0.3
    return lp_fft(low + mid + whistle, 3800.0, 1)


# ---------------------------------------------------------------------------
# 钟（全游戏最重要的声音）
# ---------------------------------------------------------------------------

# (相对基频, 相对振幅, 拍频)
BELL_PARTIALS: list[tuple[float, float, float]] = [
    (0.5, 0.35, 0.0),
    (1.0, 1.00, 0.0),
    (1.19, 0.32, 0.9),
    (1.5, 0.42, 0.0),
    (2.0, 0.62, 1.3),
    (2.51, 0.40, 1.7),
    (2.66, 0.30, 0.7),
    (3.01, 0.24, 1.1),
    (3.47, 0.20, 2.1),
    (4.17, 0.16, 1.5),
    (4.98, 0.11, 2.6),
    (5.58, 0.09, 1.9),
    (6.78, 0.07, 3.1),
    (8.21, 0.05, 2.4),
    (9.94, 0.035, 3.4),
]


def bell_body(f0: float, dur: float, name: str,
              detune_cents: float = 0.0) -> np.ndarray:
    n = n_samples(dur)
    ts = t_axis(n)
    out = np.zeros(n)
    if f0 < 60.0:
        base = 55.0  # 更低的钟用 55 Hz 做相位基准，保证循环无缝
    else:
        base = round(f0)
    r = rng("bell:" + name)
    hum = r.normal(0.0, 1.0)
    for i, (ratio, amp, beat) in enumerate(BELL_PARTIALS):
        f = snap_hz(cents(f0 * ratio, detune_cents + float(r.uniform(-2.5, 2.5))))
        d = 14.0 / (f ** 0.62)
        d = max(0.25, min(d, dur * 3.0))
        e = np.exp(-ts / d)
        phase = float(r.uniform(0.0, 2.0 * math.pi))
        if beat > 0.05:
            parts = []
            for off in (beat * 0.5, -beat * 0.5, beat * 1.7):
                parts.append(np.sin(2.0 * np.pi * snap_hz(f + off) * ts + phase))
            sig = sum(parts) / len(parts)
        else:
            sig = np.sin(2.0 * np.pi * f * ts + phase)
        out += amp * sig * e
    # 钟槌击打声（以 55 Hz 相位基准生成，保证循环可拼接）
    imp = np.zeros(n)
    m = min(n, n_samples(0.035))
    imp[:m] = r.standard_normal(m) * env_ad(m, 0.0004, 10.0)
    strike = (np.sin(2.0 * np.pi * (base * 2.0) * ts) * 0.5
              + np.sin(2.0 * np.pi * (base * 4.39) * ts + 0.8) * 0.3)
    strike *= env_ad(n, 0.0006, 22.0)
    # 起振：极短的淡入，避免爆音
    out *= np.clip(ts / 0.004, 0.0, 1.0)
    imp *= np.clip(ts / 0.001, 0.0, 1.0)
    return out * 0.9 + (imp * 0.25 + strike * 0.3)


def make_bell(f0: float, dur: float, fade_out: float,
              detune_cents: float = 0.0) -> np.ndarray:
    x = bell_body(f0, dur, "bell", detune_cents)
    x = bell_body(f0, dur, "bell2", detune_cents + 1.6) * 0.45 + x * 0.75
    n = x.size
    ts = t_axis(n)
    if fade_out > 0.0:
        start = max(0.0, dur - fade_out)
        f = np.clip((ts - start) / fade_out, 0.0, 1.0)
        x *= (1.0 - f) ** 0.9
    return x


def build_bell() -> np.ndarray:
    """sfx_bell —— 大而慢的、忧郁的教堂钟。"""
    dur = 4.2
    x = make_bell(110.0, dur, 1.2, 0.0)
    x = apply_reverb(x, 2.2, 1.2, 3200.0, 0.28, "bell")
    return x


def build_bell_distant() -> np.ndarray:
    """sfx_bell_distant —— 同一口钟，重低通 + 轻音量 + 更长混响尾。"""
    dur = 4.4
    x = make_bell(110.0, dur, 0.9, -2.0)
    x = lp_fft(x, 520.0, 3)          # 厚重的低通（远处听不见高频）
    x = lp_fft(x, 420.0, 1)
    x = apply_reverb(x, 3.4, 1.8, 700.0, 0.65, "belld")
    ts = t_axis(x.size)
    x *= np.clip(ts / 0.02, 0.0, 1.0)
    x *= np.clip(1.0 - np.clip((ts - (dur - 1.6)) / 1.6, 0.0, 1.0), 0.0, 1.0) ** 0.8
    return x * 0.55


# ---------------------------------------------------------------------------
# 童谣（会以“倒放”形式在游戏里出现）
# ---------------------------------------------------------------------------

# A 小调，刻意微微走音；最后一个音拖长后收掉（倒放会变成吸气般的起音）
RHYME_MELODY: list[tuple[float, float, str]] = [
    (0.00, 0.55, "A4"),
    (0.55, 0.55, "C5"),
    (1.10, 0.55, "B4"),
    (1.65, 0.55, "A4"),
    (2.20, 0.80, "E4"),
    (3.00, 1.10, "G4"),
    (4.10, 0.55, "F4"),
    (4.65, 0.60, "E4"),
    (5.25, 0.55, "D4"),
    (5.80, 0.75, "E4"),
]

RHYME_DETUNE_CENTS = [7.0, -5.0, 9.0, -3.0, 6.0, -8.0, 4.0, -6.0, 8.0, -2.0]


def vowel_voice(freq: float, dur: float, name: str) -> np.ndarray:
    """元音化的合成嗓音（暗的锯齿 + 共振峰）。"""
    n = n_samples(dur)
    ts = t_axis(n)
    vib = 1.0 + 0.0035 * np.sin(2.0 * np.pi * 4.7 * ts + 0.6 * np.sin(2.0 * np.pi * 0.8 * ts))
    a = saw(freq * 1.0 * 1.0, dur, 2600.0)
    b = saw(freq * 1.004, dur, 2200.0)
    c = square(freq * 0.997, dur, 1800.0) * 0.35
    src = (a * 0.5 + b * 0.4 + c) / 1.25
    src = src * vib
    voiced = formant(src, [(700.0, 6.0, 1.0), (1150.0, 7.0, 0.55),
                           (2600.0, 8.0, 0.22), (3400.0, 9.0, 0.1)])
    syll = 0.72 + 0.28 * np.sin(2.0 * np.pi * 2.3 * ts + 1.1)
    return lp_fft(voiced * syll, 4200.0, 2)


def build_nursery_rhyme() -> np.ndarray:
    dur = 6.6
    n = n_samples(dur)
    out = np.zeros(n)
    for i, (start, length, pitch) in enumerate(RHYME_MELODY):
        f = cents(note_hz(pitch), RHYME_DETUNE_CENTS[i % len(RHYME_DETUNE_CENTS)])
        sig = vowel_voice(f, length, "rhyme%d" % i)
        sig *= env_adsr(sig.size, 0.06, 0.18, 0.75, min(0.22, length * 0.4))
        put(out, sig, n_samples(start), wrap=False)
    tail = env_points(dur, [(0.0, 1.0), (5.9, 0.9), (6.6, 0.0)])
    out *= tail
    out = apply_reverb(out, 1.1, 0.5, 2600.0, 0.2, "rhyme")
    peak = float(np.max(np.abs(out))) if out.size else 0.0
    if peak > 1e-12:
        out /= peak
    return out


# ---------------------------------------------------------------------------
# 音乐
# ---------------------------------------------------------------------------

MUSIC_LEN = 24.0
AMBIENT_LEN = 20.0

MUSIC_BUILDERS: dict[str, Callable[[], np.ndarray]] = {}
AMBIENT_BUILDERS: dict[str, Callable[[], np.ndarray]] = {}


def music(name: str) -> Callable[[Callable[[], np.ndarray]], Callable[[], np.ndarray]]:
    def deco(fn: Callable[[], np.ndarray]) -> Callable[[], np.ndarray]:
        MUSIC_BUILDERS[name] = fn
        return fn
    return deco


def amb(name: str) -> Callable[[Callable[[], np.ndarray]], Callable[[], np.ndarray]]:
    def deco(fn: Callable[[], np.ndarray]) -> Callable[[], np.ndarray]:
        AMBIENT_BUILDERS[name] = fn
        return fn
    return deco


def pad_chord(freqs: Sequence[float], dur: float, detune_cents: float,
              name: str, detune_spread: float = 5.0) -> np.ndarray:
    """慢速失谐 pad（用周期化的正弦堆叠，天然可循环）。"""
    n = n_samples(dur)
    out = np.zeros(n)
    for i, f in enumerate(freqs):
        layer = np.zeros(n)
        for k, d in enumerate((-detune_spread, 0.0, detune_spread)):
            fk = snap_hz(cents(f, detune_cents + d))
            layer += saw(fk, dur, 2200.0)
            layer += 0.5 * sine(fk * 0.5, dur, phase=0.3 * k + 0.7 * i)
        out += layer / (3.0 * len(freqs))
    lfo = 0.72 + 0.28 * np.sin(2.0 * np.pi * snap_hz(0.11) * t_axis(n) + 0.6)
    return lp_fft(out * lfo, 1800.0, 2)


def drone(freqs: Sequence[float], dur: float, name: str,
          breath: float = 0.18) -> np.ndarray:
    n = n_samples(dur)
    ts = t_axis(n)
    out = np.zeros(n)
    f0 = snap_hz(freqs[0])
    for i, f in enumerate(freqs):
        mult = max(1, int(round(f / freqs[0])))
        fk = snap_hz(f0 * mult) if LOOP_MODE else f0 * mult
        out += add_harmonics(fk, dur, count=max(1, int(2000.0 / max(1.0, fk))), rolloff=1.5)
    out /= max(1, len(freqs))
    mod = 1.0 - breath * 0.5 * (1.0 - np.cos(2.0 * np.pi * snap_hz(0.0833) * ts))
    return lp_fft(out * mod, 1200.0, 2)


def put_tail(dst: np.ndarray, src: np.ndarray, start: int, room_s: float) -> None:
    """在缓冲区末尾留出 room_s 的“尾室”，让一次性长音（钟）自然衰减后再裁回。

    这样它不会在循环点上被硬切，也不会用环绕的方式接到文件开头。
    """
    total = dst.size + n_samples(room_s)
    buf = np.zeros(total, dtype=np.float64)
    buf[:dst.size] = dst
    end = min(total, start + src.size)
    if end > start:
        buf[start:end] += src[:end - start]
    dst += buf[:dst.size]


def bell_hit(f0: float, dur: float, amp: float, name: str) -> np.ndarray:
    return amp * make_bell(f0, dur, min(dur * 0.4, 1.5), 0.0)


@music("mus_town")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    out = drone([55.0, 82.5, 110.0], dur, "mtown", 0.22)
    out += pad_chord([110.0, 130.81, 164.81], dur, -6.0, "mtown2")
    put_tail(out, bell_hit(220.0, 3.2, 0.05, "mtownb1"), n_samples(5.0), 3.2)
    put_tail(out, bell_hit(220.0, 3.2, 0.04, "mtownb2"), n_samples(14.0), 3.2)
    put_tail(out, bell_hit(164.81, 3.5, 0.035, "mtownb3"), n_samples(19.5), 3.5)
    wind = lp1c(noise_at("mtownw", dur), 300.0) * 0.06
    wind *= 0.6 + 0.4 * np.sin(2.0 * np.pi * snap_hz(0.0833) * t_axis(n))
    return out * 0.8 + wind


@music("mus_wax")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    out = pad_chord([73.42, 87.31, 110.0, 146.83], dur, -9.0, "mwax")
    out *= 0.9 + 0.1 * np.sin(2.0 * np.pi * snap_hz(0.25) * t_axis(n))
    r = rng("mwaxd")
    drips = np.zeros(n)
    for start in (3.2, 7.7, 12.4, 16.9, 21.3):
        d = drum_pickup(0.4, 900.0, 300.0, 0.05, 0.01, 0.2, "mdrip%d" % int(start * 10))
        put(drips, d * float(r.uniform(0.3, 0.5)), n_samples(start))
        put(drips, d * 0.25, n_samples(start + 0.18))
    hum = lp1c(noise_at("mwaxh", dur), 260.0) * 0.08
    return out * 0.7 + drips * 0.5 + hum


@music("mus_theater")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    out = np.zeros(n)
    # 3/4 拍，速度 60 → 每小节 3 秒，8 小节正好 24 秒
    box = [("A5", 0.0), ("C6", 0.75), ("E5", 1.5), ("B5", 3.0), ("A5", 3.75),
           ("F5", 4.5), ("E5", 6.0), ("G5", 6.75), ("C6", 9.0), ("B5", 9.75),
           ("A5", 12.0), ("E5", 12.75), ("F5", 13.5), ("D5", 15.0),
           ("C6", 15.75), ("B5", 18.0), ("A5", 18.75), ("G5", 19.5), ("E5", 21.0)]
    for i, (pitch, start) in enumerate(box):
        f = note_hz(pitch)
        add_note(out, start, f, 0.9, lambda ff, dd: music_box_wave(ff, dd),
                 attack=0.002, decay=3.4, amp=0.16,
                 detune_cents=(-13.0 if i % 4 == 3 else (7.0 if i % 3 == 0 else 0.0)))
    low = drone([36.71, 55.0], dur, "mtheater", 0.3) * 0.5
    room = lp1c(noise_at("mtheaterr", dur), 260.0) * 0.05
    return out + low * 0.5 + room


def music_box_wave(freq: float, dur: float) -> np.ndarray:
    """音乐盒音色：非谐分音 + 快速衰减。"""
    ratios = (1.0, 2.01, 3.93, 5.4, 7.1, 9.2)
    amps = (1.0, 0.45, 0.28, 0.16, 0.1, 0.06)
    decs = (2.0, 1.1, 0.7, 0.45, 0.3, 0.2)
    n = n_samples(dur)
    ts = t_axis(n)
    out = np.zeros(n)
    for ratio, amp, dec in zip(ratios, amps, decs):
        fp = snap_hz(freq * ratio)
        out += amp * np.sin(2.0 * np.pi * fp * ts + ratio) * np.exp(-ts / dec)
    return out


@music("mus_well")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    ts = t_axis(n)
    out = drone([36.71, 55.0, 73.42], dur, "mwell", 0.3)
    out += pad_chord([73.42, 77.78], dur, -12.0, "mwell2") * 0.4
    # 慢心跳：每 4 秒两次（6 次循环）
    beat = np.zeros(n)
    for k in range(6):
        base = 4.0 * k
        for off, amp in ((0.15, 1.0), (0.58, 0.65)):
            th = drum_pickup(0.5, 62.0, 34.0, 0.09, 0.015, 0.15, "mhb%d%d" % (k, int(off * 10)))
            put(beat, th * amp, n_samples(base + off))
    hollow = lp1c(noise_at("mwellh", dur), 150.0) * 0.09
    hollow *= 0.5 + 0.5 * np.sin(2.0 * np.pi * snap_hz(0.125) * ts)
    return out * 0.8 + beat * 0.35 + hollow


@music("mus_clocktower")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    out = np.zeros(n)
    for k in range(48):  # 每 0.5 秒一跳
        start = 0.5 * k
        accent = (k % 4 == 0)
        g = tick(0.09, 1500.0 if accent else 1180.0, 10.0 if accent else 8.0,
                 0.6 if accent else 0.42, "mct%d" % k)
        put(out, g * (0.5 if accent else 0.3), n_samples(start))
    ts = t_axis(n)
    rise = pad_chord([110.0, 164.81, 220.0], dur, -7.0, "mctpad")
    rise *= np.linspace(0.25, 1.0, n) ** 1.5
    mech = lp1c(noise_at("mctm", dur), 190.0) * 0.07
    mech *= 0.6 + 0.4 * np.sin(2.0 * np.pi * snap_hz(0.25) * ts)
    put(out, bell_hit(330.0, 2.6, 0.04, "mctb"), n_samples(12.0))
    return out * 0.6 + rise * 0.35 + mech


@music("mus_fire")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    ts = t_axis(n)
    r = rng("mfire")
    rumble = lp1c(noise_at("mfire", dur), 45.0) * 0.9
    rumble *= 0.75 + 0.25 * np.sin(2.0 * np.pi * snap_hz(0.125) * ts + 0.4 * np.sin(2.0 * np.pi * snap_hz(0.3) * ts))
    crk = np.zeros(n)
    pos = 0.6
    i = 0
    while pos < dur - 0.3:
        g = crackle_grain("mfirec", i, 700.0, 4600.0, float(r.uniform(0.004, 0.02)))
        put(crk, g * float(r.uniform(0.12, 0.7)), n_samples(pos))
        pos += float(r.uniform(0.02, 0.22))
        i += 1
    pad = pad_chord([58.27, 82.41, 116.54], dur, -14.0, "mfirep") * 0.6
    pad += pad_chord([87.31], dur, 6.0, "mfirep2") * 0.25  # 与 F# 的高音冲突
    return rumble * 0.8 + crk * 0.6 + pad * 0.4


@music("mus_ending")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    out = pad_chord([87.31, 130.81, 174.61, 220.0], dur, 0.0, "mend") * 0.9
    for i, (pitch, start) in enumerate([("F4", 1.2), ("A4", 3.4), ("C5", 5.6),
                                        ("F5", 8.0), ("C5", 12.0), ("A4", 14.2),
                                        ("F4", 16.6), ("C5", 20.0)]):
        add_note(out, start, note_hz(pitch), 3.4, music_box_wave,
                 attack=0.004, decay=2.2, amp=0.13, detune_cents=2.0 * (i % 3 - 1))
    air = lp1c(noise_at("menda", dur), 900.0) * 0.05
    air *= 0.5 + 0.5 * np.sin(2.0 * np.pi * snap_hz(0.0833) * t_axis(n))
    out *= env_points(dur, [(0.0, 0.8), (6.0, 1.0), (18.0, 0.95), (24.0, 0.8)])
    return out * 0.7 + air


@music("mus_night")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    ts = t_axis(n)
    thin = (pad_chord([220.0, 261.63], dur, -8.0, "mnight") * 0.35
            + drone([55.0, 82.5], dur, "mnightd", 0.25) * 0.5)
    thin = lp_fft(thin, 2600.0, 2)
    out = thin
    put(out, bell_hit(261.63, 3.2, 0.03, "mnightb1"), n_samples(4.0))
    put(out, bell_hit(196.0, 3.2, 0.025, "mnightb2"), n_samples(15.0))
    air = lp1c(noise_at("mnighta", dur), 700.0) * 0.06
    air *= 0.4 + 0.6 * np.sin(2.0 * np.pi * snap_hz(0.0417) * ts) ** 2
    return out * 0.8 + air


@music("mus_deformed")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    ts = t_axis(n)
    bend = 1.0 + 0.02 * np.sin(2.0 * np.pi * snap_hz(0.0833) * ts) + 0.008 * np.sin(
        2.0 * np.pi * snap_hz(0.21) * ts + 1.3)
    src = pad_chord([58.27, 69.3, 82.41], dur, -18.0, "mdef")
    src = src * bend
    groan = moan(48.0, dur, 0.03, 3.3, "mdefg") * 0.35
    groan *= 0.6 + 0.4 * np.sin(2.0 * np.pi * snap_hz(0.125) * ts + 0.7)
    metal = (bqc(noise_at("mdefm", dur), "bp", 1860.0, 14.0) * 0.08
             + bqc(noise_at("mdefm2", dur), "bp", 2790.0, 16.0) * 0.05)
    metal *= 0.5 + 0.5 * np.sin(2.0 * np.pi * snap_hz(1.1) * ts) * np.sin(2.0 * np.pi * snap_hz(0.0833) * ts)
    return src * 0.7 + groan + metal


@music("mus_morning")
def _m() -> np.ndarray:
    dur = MUSIC_LEN
    n = n_samples(dur)
    out = pad_chord([98.0, 146.83, 196.0, 246.94], dur, 1.0, "mmorn") * 0.8
    for i, (pitch, start) in enumerate([("G4", 2.0), ("A4", 4.5), ("D5", 7.0),
                                        ("B4", 10.5), ("G4", 13.0), ("D5", 16.5),
                                        ("E5", 19.5)]):
        add_note(out, start, note_hz(pitch), 2.8, music_box_wave,
                 attack=0.006, decay=2.0, amp=0.1, detune_cents=-2.0 + 2.0 * i)
    air = lp1c(noise_at("mmorna", dur), 1400.0) * 0.06
    air *= 0.5 + 0.5 * np.sin(2.0 * np.pi * snap_hz(0.0833) * t_axis(n) + 1.0)
    out *= env_points(dur, [(0.0, 0.7), (7.0, 0.95), (20.0, 1.0), (24.0, 0.7)])
    return out * 0.7 + air


# ---------------------------------------------------------------------------
# 环境声
# ---------------------------------------------------------------------------

def amb_bed(dur: float, name: str, amount: float = 1.0,
            fc: float = 400.0, gusts: Sequence[tuple[float, float]] = (),
            bp_hz: float = 700.0, bp_amt: float = 0.4) -> np.ndarray:
    n = n_samples(dur)
    ts = t_axis(n)
    src = noise_at("amb:" + name, dur)
    gust = np.ones(n)
    for (rate, depth) in gusts:
        gust += depth * np.sin(2.0 * np.pi * snap_hz(rate) * ts + rate * 7.0)
    low = lp1c(src, fc) * np.clip(gust, 0.05, None)
    mid = bqc(src, "bp", bp_hz, 0.7) * (0.5 + 0.5 * gust) * bp_amt
    return (low + mid) * amount


def amb_events(dst: np.ndarray, dur: float, name: str, kind: str,
               times: Sequence[float], amp: float = 1.0) -> None:
    for i, start in enumerate(times):
        if kind == "creak":
            dlen = 0.55
            m = n_samples(dlen)
            ts = t_axis(m)
            d = bqc(noise_at("ambe:%s:%d" % (name, i), dlen), "bp", 380.0, 2.4)
            d *= (0.4 + 0.6 * np.abs(np.sin(2.0 * np.pi * snap_hz(13.0) * ts)))
            d *= env_points(dlen, [(0.0, 0.0), (0.1, 0.8), (0.4, 1.0), (0.55, 0.0)])
        elif kind == "drip":
            d = drum_pickup(0.35, 1000.0, 320.0, 0.05, 0.01, 0.2,
                            "ambd:%s:%d" % (name, i))
            m = d.size
        elif kind == "tick":
            d = tick(0.09, 1350.0, 10.0, 0.55, "ambt:%s:%d" % (name, i))
            m = d.size
        elif kind == "bellpart":
            d = make_bell(220.0, 3.0, 1.4, 0.0) * 0.05
            m = d.size
        elif kind == "shriek":
            d = moan(140.0, 0.9, 0.05, 11.0, "ambs:%s:%d" % (name, i))
            m = d.size
            d *= env_points(0.9, [(0.0, 0.0), (0.05, 0.8), (0.4, 0.5), (0.9, 0.0)])
        elif kind == "grain":
            d = crackle_grain("ambg:%s:%d" % (name, i), i, 900.0, 5000.0, 0.012)
            m = d.size
        else:
            continue
        put(dst, d * amp, n_samples(start))


def amb_reverb(x: np.ndarray, dur: float, name: str, wet: float,
               decay: float) -> np.ndarray:
    return apply_reverb(x, min(2.2, dur * 0.15), decay, 1600.0, wet, name)


@amb("amb_town")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    out = amb_bed(dur, "town", 1.0, 380.0, ((0.083, 0.4), (0.19, 0.2)), 620.0, 0.45)
    ev = np.zeros(n)
    amb_events(ev, dur, "town", "creak", (2.5, 7.3, 13.9, 18.2), 0.2)
    amb_events(ev, dur, "town", "bellpart", (5.5,), 0.6)
    return amb_reverb(out * 0.8 + ev, dur, "ambtown", 0.15, 0.6)


@amb("amb_wax")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    hum = add_harmonics(55.0, dur, 8, 1.4) * 0.06
    hum *= 0.7 + 0.3 * np.sin(2.0 * np.pi * snap_hz(0.15) * t_axis(n))
    bed = amb_bed(dur, "wax", 0.55, 300.0, ((0.11, 0.3),), 520.0, 0.3)
    ev = np.zeros(n)
    amb_events(ev, dur, "wax", "drip", (3.1, 6.2, 9.7, 14.4, 17.8), 0.5)
    amb_events(ev, dur, "wax", "grain", (1.4, 5.0, 8.2, 12.1, 16.0, 19.0), 0.4)
    return lp_fft(hum + bed + ev, 3000.0, 2)


@amb("amb_theater")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    room = amb_bed(dur, "theater", 0.9, 220.0, ((0.07, 0.35),), 400.0, 0.35)
    ev = np.zeros(n)
    amb_events(ev, dur, "theater", "creak", (1.8, 6.6, 11.2, 16.5), 0.35)
    box = np.zeros(n)
    for i, (pitch, start) in enumerate([("A5", 4.0), ("C6", 12.5), ("E5", 18.0)]):
        sig = music_box_wave(note_hz(pitch), 1.2)
        sig *= env_ad(sig.size, 0.002, 3.2) * 0.05
        put(box, sig, n_samples(start))
    return amb_reverb(room * 0.7 + ev + box, dur, "ambtheater", 0.3, 0.9)


@amb("amb_well")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    out = drone([36.71, 55.0], dur, "awell", 0.3) * 0.55
    out += amb_bed(dur, "well", 0.4, 150.0, ((0.05, 0.4),), 300.0, 0.35)
    ev = np.zeros(n)
    amb_events(ev, dur, "well", "drip", (2.2, 5.6, 8.1, 11.7, 15.2, 18.6), 0.45)
    return lp_fft(out + ev, 2600.0, 2)


@amb("amb_clocktower")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    tickbed = np.zeros(n)
    for k in range(40):
        accent = (k % 2 == 0)
        g = tick(0.09, 1400.0 if accent else 1120.0, 9.0,
                 0.5 if accent else 0.35, "act%d" % k)
        put(tickbed, g * (0.45 if accent else 0.28), n_samples(0.5 * k))
    mech = lp1c(noise_at("actm", dur), 220.0) * 0.12
    room = amb_bed(dur, "clocktower", 0.5, 260.0, ((0.09, 0.3),), 480.0, 0.3)
    return tickbed * 0.7 + mech + room


@amb("amb_fire")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    r = rng("afire")
    ts = t_axis(n)
    rumble = lp1c(noise_at("mfire", dur), 50.0) * 0.8
    rumble *= 0.75 + 0.25 * np.sin(2.0 * np.pi * snap_hz(0.15) * ts + 0.5 * np.sin(2.0 * np.pi * snap_hz(0.4) * ts))
    crk = np.zeros(n)
    pos = 0.4
    i = 0
    while pos < dur - 0.3:
        g = crackle_grain("afirec", i, 800.0, 5200.0, float(r.uniform(0.004, 0.018)))
        put(crk, g * float(r.uniform(0.15, 0.85)), n_samples(pos))
        pos += float(r.uniform(0.015, 0.18))
        i += 1
    air = hp1c(noise_at("mfire", dur), 3000.0) * 0.12
    return rumble * 0.8 + crk * 0.7 + air


@amb("amb_ending")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    out = drone([43.65, 65.41], dur, "aend", 0.2) * 0.4
    air = amb_bed(dur, "ending", 0.7, 500.0, ((0.067, 0.45), (0.15, 0.2)), 900.0, 0.4)
    ev = np.zeros(n)
    amb_events(ev, dur, "ending", "bellpart", (7.0,), 0.5)
    return amb_reverb(out + air + ev, dur, "ambending", 0.25, 1.1)


@amb("amb_town_dusk")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    out = amb_bed(dur, "towndusk", 1.0, 330.0, ((0.07, 0.5), (0.23, 0.22)), 560.0, 0.5)
    ev = np.zeros(n)
    amb_events(ev, dur, "towndusk", "creak", (4.2, 11.5, 17.0), 0.22)
    amb_events(ev, dur, "towndusk", "bellpart", (8.5,), 1.0)
    return amb_reverb(out * 0.85 + ev, dur, "ambtowndusk", 0.22, 0.8)


@amb("amb_town_night")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    out = lp_fft(amb_bed(dur, "townnight", 1.0, 240.0, ((0.05, 0.4),), 420.0, 0.35),
                 1200.0, 2)
    ev = np.zeros(n)
    amb_events(ev, dur, "townnight", "bellpart", (3.5, 12.0), 0.7)
    amb_events(ev, dur, "townnight", "grain", (6.0, 15.5), 0.25)
    return lp_fft(out * 0.8 + ev, 2400.0, 2)


@amb("amb_town_deformed")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    ts = t_axis(n)
    out = amb_bed(dur, "towndef", 1.0, 300.0, ((0.06, 0.5), (0.17, 0.3)), 500.0, 0.5)
    out *= 1.0 + 0.02 * np.sin(2.0 * np.pi * snap_hz(0.13) * ts) + 0.008 * np.sin(
        2.0 * np.pi * snap_hz(0.31) * ts + 1.0)
    groan = moan(52.0, dur, 0.035, 3.0, "atdfg") * 0.25
    groove = 0.6 + 0.4 * np.sin(2.0 * np.pi * snap_hz(0.1) * ts + 0.4)
    ev = np.zeros(n)
    amb_events(ev, dur, "towndef", "shriek", (5.0, 14.5), 0.3)
    amb_events(ev, dur, "towndef", "creak", (9.0,), 0.4)
    return lp_fft(out * 0.75 + groan * groove + ev, 3400.0, 2)


@amb("amb_morning")
def _a() -> np.ndarray:
    dur = AMBIENT_LEN
    n = n_samples(dur)
    out = amb_bed(dur, "morning", 0.9, 600.0, ((0.1, 0.4), (0.21, 0.18)), 1100.0, 0.5)
    ev = np.zeros(n)
    amb_events(ev, dur, "morning", "grain", (2.0, 5.5, 9.0, 13.5, 17.5), 0.22)
    air = hp1c(noise_at("amorn", dur), 4000.0) * 0.06
    return lp_fft(out * 0.8 + ev + air, 6000.0, 1)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def _build_table() -> list[tuple[str, str, str, float]]:
    """返回 (name, out_dir, group, peak_db)。group ∈ {sfx, music, ambient}"""
    rows: list[tuple[str, str, str, float]] = []
    for name in SFX_NAMES:
        rows.append((name, SFX_DIR, "sfx", SFX_PEAK_DB))
    for name in MUSIC_NAMES:
        rows.append((name, MUSIC_DIR, "music", MUSIC_PEAK_DB))
    for name in AMBIENT_NAMES:
        rows.append((name, AMBIENT_DIR, "ambient", AMBIENT_PEAK_DB))
    return rows


def known_duration(name: str, group: str) -> float:
    if group == "music":
        return MUSIC_LEN
    if group == "ambient":
        return AMBIENT_LEN
    return {
        "sfx_death": 2.0, "sfx_fire_crackle": 2.0, "sfx_wind": 2.0,
        "sfx_ghost_whisper": 1.5, "sfx_boss_roar": 1.55,
        "sfx_nursery_rhyme": 6.6, "sfx_nursery_rhyme_reversed": 6.6,
        "sfx_bell": 4.2, "sfx_bell_distant": 4.4,
    }.get(name, 1.0)


def build_one(name: str, group: str) -> np.ndarray:
    global LOOP_MODE, LOOP_N
    LOOP_MODE = name in LOOPING
    LOOP_N = n_samples(known_duration(name, group))
    if group == "sfx":
        if name == "sfx_bell":
            return build_bell()
        if name == "sfx_bell_distant":
            return build_bell_distant()
        if name == "sfx_nursery_rhyme":
            return build_nursery_rhyme()
        if name == "sfx_nursery_rhyme_reversed":
            return build_nursery_rhyme()[::-1].copy()
        if name not in SFX_BUILDERS:
            raise KeyError("未实现的音效: %s" % name)
        return SFX_BUILDERS[name]()
    if group == "music":
        if name not in MUSIC_BUILDERS:
            raise KeyError("未实现的音乐: %s" % name)
        return MUSIC_BUILDERS[name]()
    if group == "ambient":
        if name not in AMBIENT_BUILDERS:
            raise KeyError("未实现的环境声: %s" % name)
        return AMBIENT_BUILDERS[name]()
    raise ValueError(group)


def loop_metrics(data_int16: np.ndarray, fade_sec: float = LOOP_FADE_SEC) -> dict:
    """接缝指标：端点差、接缝斜率 vs 乐段内最大斜率。"""
    d = data_int16.astype(np.float64)
    n = d.size
    seam = abs(float(d[-1] - d[0]))
    interior = np.abs(np.diff(d))
    max_jump = float(np.max(interior))
    rms_jump = float(np.sqrt(np.mean(interior ** 2)))
    return {
        "seam_abs": seam,
        "max_jump": max_jump,
        "rms_jump": rms_jump,
        "seam_vs_max": seam / max(1e-9, max_jump),
    }


def generate_all() -> list[dict]:
    rows = []
    for name, out_dir, group, target_db in _build_table():
        x = np.asarray(build_one(name, group), dtype=np.float64)
        if name in LOOPING:
            x = make_loop(x)
        x = normalize_peak(x, target_db)
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, x)
        intr = to_int16(x)
        rec = {
            "name": name,
            "group": group,
            "path": path,
            "seconds": x.size / SR,
            "samples": int(x.size),
            "target_db": target_db,
            "peak_db": peak_db(x),
            "quant_peak_db": peak_db(intr.astype(np.float64) / 32767.0),
            "loop": name in LOOPING,
            "first_raw": float(x[0]),
            "last_raw": float(x[-1]),
            "first_i16": int(intr[0]),
            "last_i16": int(intr[-1]),
            "seam_diff": abs(int(intr[-1]) - int(intr[0])),
            "min_i16": int(np.min(intr)),
            "max_i16": int(np.max(intr)),
            "dc": float(np.mean(x)),
        }
        rec.update(loop_metrics(intr))
        rows.append(rec)
        print("[wav] %-30s %6.2fs peak=%6.2f dBFS  seam=%d LSB"
              % (name, x.size / SR, peak_db(x), rec["seam_diff"]))
    return rows


def verify_existing() -> list[dict]:
    rows = []
    for name, out_dir, group, target_db in _build_table():
        path = os.path.join(out_dir, name + ".wav")
        if not os.path.exists(path):
            print("[MISSING] %s" % path)
            continue
        with wave.open(path, "rb") as w:
            ch, sw, fr, nfr = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
            raw = w.readframes(nfr)
        if (ch, sw, fr) != (1, 2, SR):
            print("[BADFMT] %s ch=%d sw=%d sr=%d" % (path, ch, sw, fr))
            continue
        data = np.frombuffer(raw, dtype="<i2")
        rec = {
            "name": name,
            "group": group,
            "path": path,
            "seconds": nfr / fr,
            "samples": int(nfr),
            "target_db": target_db,
            "peak_db": peak_db(data.astype(np.float64) / 32767.0),
            "quant_peak_db": peak_db(data.astype(np.float64) / 32767.0),
            "loop": name in LOOPING,
            "first_raw": float(data[0] / 32767.0),
            "last_raw": float(data[-1] / 32767.0),
            "first_i16": int(data[0]),
            "last_i16": int(data[-1]),
            "seam_diff": abs(int(data[-1]) - int(data[0])),
            "min_i16": int(np.min(data)),
            "max_i16": int(np.max(data)),
            "dc": float(np.mean(data.astype(np.float64) / 32767.0)),
        }
        rec.update(loop_metrics(data))
        rows.append(rec)
    return rows


def report(rows: list[dict], write_csv: bool = True) -> int:
    loops = [r for r in rows if r["loop"]]
    print("\n%-30s %-8s %8s %9s %8s" % ("file", "group", "seconds", "peak_dBFS", "seam_LSB"))
    print("-" * 68)
    for r in rows:
        print("%-30s %-8s %8.2f %9.2f %8d"
              % (r["name"], r["group"], r["seconds"], r["peak_db"], r["seam_diff"]))
    print("\n--- 循环接缝校验（%d 个循环素材）---" % len(loops))
    print("%-30s %9s %9s %9s" % ("file", "seam_LSB", "max_jump", "seam/max"))
    worst = 0
    for r in loops:
        worst = max(worst, r["seam_diff"])
        print("%-30s %9d %9.0f %9.4f"
              % (r["name"], r["seam_diff"], r["max_jump"], r["seam_vs_max"]))
    print("\n最大接缝差 = %d LSB（阈值 2）" % worst)
    print("文件总数: %d (sfx=%d music=%d ambient=%d)"
          % (len(rows),
             sum(1 for r in rows if r["group"] == "sfx"),
             sum(1 for r in rows if r["group"] == "music"),
             sum(1 for r in rows if r["group"] == "ambient")))
    if write_csv:
        csv_path = os.path.join(HERE, "audio_inventory.csv")
        with open(csv_path, "w", encoding="utf-8") as fh:
            fh.write("file,group,seconds,peak_dBFS,seam_LSB,max_jump,seam_over_max\n")
            for r in rows:
                fh.write("%s,%s,%.4f,%.3f,%d,%.0f,%.5f\n"
                         % (r["name"], r["group"], r["seconds"], r["peak_db"],
                            r["seam_diff"], r["max_jump"], r["seam_vs_max"]))
        print("清单已写出: %s" % csv_path)
    expected = len(SFX_NAMES) + len(MUSIC_NAMES) + len(AMBIENT_NAMES)
    bad = 0
    if len(rows) != expected:
        print("!! 文件数量不符，期望 %d 实际 %d" % (expected, len(rows)))
        bad += 1
    if max((r["seam_diff"] for r in loops), default=0) > 2:
        print("!! 存在接缝 click 风险的循环素材")
        bad += 1
    print("RESULT: %s" % ("ALL PASS" if bad == 0 else "FAILED"))
    return 0 if bad == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="回环镇程序化音频生成器")
    ap.add_argument("--verify", action="store_true", help="只校验已存在的 WAV，不重新生成")
    args = ap.parse_args()

    for d in (SFX_DIR, MUSIC_DIR, AMBIENT_DIR):
        os.makedirs(d, exist_ok=True)

    rows = verify_existing() if args.verify else generate_all()
    return report(rows)


if __name__ == "__main__":
    sys.exit(main())
