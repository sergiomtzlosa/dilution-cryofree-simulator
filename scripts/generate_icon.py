#!/usr/bin/env python3
"""
generate_icon.py
Generates AppIcon.icns for the Dilution Cryofree Simulator
without using .xcassets. Draws a cryogenic-themed icon
programmatically using CoreGraphics via ctypes on macOS.
Outputs: Resources/AppIcon.icns
"""

import struct
import zlib
import math
import os
import subprocess
import tempfile
import shutil

# ── PNG helpers ─────────────────────────────────────────────────────────────

def _chunk(tag: bytes, data: bytes) -> bytes:
    length = struct.pack(">I", len(data))
    body = tag + data
    crc = struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    return length + body + crc

def make_png(width: int, height: int, rgba_rows: list[bytes]) -> bytes:
    """Encode raw RGBA rows into a minimal PNG."""
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    ihdr = _chunk(b"IHDR", ihdr_data)

    raw = b""
    for row in rgba_rows:
        raw += b"\x00" + row          # filter type None per row

    compressed = zlib.compress(raw, 9)
    idat = _chunk(b"IDAT", compressed)
    iend = _chunk(b"IEND", b"")
    return sig + ihdr + idat + iend


# ── Icon drawing ─────────────────────────────────────────────────────────────

def lerp(a, b, t):
    return a + (b - a) * t

def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))

def circle_sdf(x, y, cx, cy, r):
    dx, dy = x - cx, y - cy
    return math.sqrt(dx*dx + dy*dy) - r

def aa_alpha(sdf, aa=1.2):
    return clamp((-sdf) / aa + 0.5)

def blend(dst, src_rgb, src_a):
    """Alpha-blend src over dst (all floats 0-1)."""
    a = clamp(src_a)
    return tuple(lerp(d, s, a) for d, s in zip(dst, src_rgb))


def draw_icon(size: int) -> list[bytes]:
    """Return RGBA row bytes for an icon of `size` x `size` pixels."""
    rows = []
    cx = cy = size / 2.0
    R = size / 2.0

    # Colour palette
    BG_OUTER   = (0.04, 0.04, 0.08)          # near-black space
    BG_INNER   = (0.08, 0.10, 0.18)          # deep navy
    GOLD       = (1.00, 0.80, 0.20)          # gold accent
    CYAN       = (0.18, 0.90, 1.00)          # cryo-cyan
    VIOLET     = (0.55, 0.25, 1.00)          # quantum violet
    WHITE      = (1.00, 1.00, 1.00)

    for j in range(size):
        row = bytearray()
        y = j + 0.5
        for i in range(size):
            x = i + 0.5

            # ── Background gradient (radial, BG_OUTER → BG_INNER) ──────────
            dist_norm = math.sqrt((x-cx)**2 + (y-cy)**2) / R
            t_bg = clamp(dist_norm)
            r, g, b = tuple(lerp(BG_INNER[k], BG_OUTER[k], t_bg) for k in range(3))

            # ── Outer circle clip AA ────────────────────────────────────────
            outer_sdf = circle_sdf(x, y, cx, cy, R - 1.5)
            if outer_sdf > 1.5:
                # Fully outside the icon disc – transparent
                row += bytes([0, 0, 0, 0])
                continue
            disc_alpha = aa_alpha(outer_sdf)

            # ── Subtle concentric ring glow (4 K / 50 K shields) ───────────
            for ring_r, ring_col, ring_w in [
                (R * 0.85, (0.30, 0.55, 0.70), 1.8),   # 4K shield – blue steel
                (R * 0.65, (0.50, 0.40, 0.20), 1.6),   # 50K shield – warm gold
            ]:
                ring_sdf = abs(circle_sdf(x, y, cx, cy, ring_r)) - ring_w
                ring_a = aa_alpha(ring_sdf, 1.0) * 0.55
                r, g, b = blend((r, g, b), ring_col, ring_a)

            # ── OVC cylinder body (outer vacuum chamber silhouette) ─────────
            ovc_half_w = R * 0.38
            ovc_top    = cy - R * 0.70
            ovc_bot    = cy + R * 0.72
            in_ovc_x   = abs(x - cx) < ovc_half_w
            in_ovc_y   = ovc_top < y < ovc_bot
            if in_ovc_x and in_ovc_y:
                # Edge glow on OVC walls
                edge_dist = min(abs(x - (cx - ovc_half_w)), abs(x - (cx + ovc_half_w)))
                ovc_wall_a = clamp(1.0 - edge_dist / 3.0) * 0.35
                r, g, b = blend((r, g, b), (0.60, 0.65, 0.70), ovc_wall_a)

            # ── Mixing chamber sphere at bottom (the "heart") ───────────────
            mc_r  = R * 0.18
            mc_cy = cy + R * 0.48
            mc_sdf = circle_sdf(x, y, cx, mc_cy, mc_r)
            mc_a = aa_alpha(mc_sdf, 1.2) * 0.92
            # Gradient: violet core → cyan edge
            mc_dist_n = clamp(circle_sdf(x, y, cx, mc_cy, 0) / mc_r + 0.5)
            mc_col = tuple(lerp(VIOLET[k], CYAN[k], clamp(mc_dist_n * 1.4 - 0.2)) for k in range(3))
            r, g, b = blend((r, g, b), mc_col, mc_a)

            # Inner shine on MC
            shine_sdf = circle_sdf(x, y, cx - mc_r*0.25, mc_cy - mc_r*0.30, mc_r * 0.45)
            shine_a   = aa_alpha(shine_sdf, 1.5) * 0.30
            r, g, b   = blend((r, g, b), WHITE, shine_a)

            # ── Still flange (horizontal band) ──────────────────────────────
            still_y = cy + R * 0.15
            still_h = R * 0.055
            still_w = R * 0.50
            if abs(x - cx) < still_w and abs(y - still_y) < still_h:
                t_still = clamp(1.0 - abs(y - still_y) / still_h)
                r, g, b = blend((r, g, b), GOLD, t_still * 0.72)

            # ── Cold plate flange ────────────────────────────────────────────
            cp_y = cy + R * 0.32
            cp_h = R * 0.045
            cp_w = R * 0.42
            if abs(x - cx) < cp_w and abs(y - cp_y) < cp_h:
                t_cp = clamp(1.0 - abs(y - cp_y) / cp_h)
                r, g, b = blend((r, g, b), (0.70, 0.85, 1.00), t_cp * 0.65)

            # ── 4K top plate ─────────────────────────────────────────────────
            top4k_y = cy - R * 0.58
            top4k_h = R * 0.05
            top4k_w = R * 0.60
            if abs(x - cx) < top4k_w and abs(y - top4k_y) < top4k_h:
                t4 = clamp(1.0 - abs(y - top4k_y) / top4k_h)
                r, g, b = blend((r, g, b), (0.60, 0.75, 0.90), t4 * 0.70)

            # ── Pulse tube cold head (right side cylinder) ───────────────────
            pt_cx  = cx + R * 0.52
            pt_top = cy - R * 0.60
            pt_bot = cy - R * 0.10
            pt_w   = R * 0.095
            if abs(x - pt_cx) < pt_w and pt_top < y < pt_bot:
                edge_d = min(abs(x - (pt_cx - pt_w)), abs(x - (pt_cx + pt_w)))
                pt_a   = clamp(edge_d / 3.0) * 0.55 + 0.25
                r, g, b = blend((r, g, b), (0.70, 0.72, 0.75), pt_a * 0.80)

            # ── ³He flow particles (animated look via static gradient dots) ──
            # Vertical cyan line down the centre (pumping line)
            pump_dist = abs(x - cx)
            pump_top  = cy - R * 0.55
            pump_bot  = cy + R * 0.46
            if pump_dist < R * 0.025 and pump_top < y < pump_bot:
                # Dashed: on every ~12px segment
                seg = (y % (R * 0.09))
                if seg < R * 0.05:
                    pump_a = clamp(1.0 - pump_dist / (R * 0.025)) * 0.80
                    r, g, b = blend((r, g, b), CYAN, pump_a)

            # ── Cryogen label snowflake dot cluster (subtle) ─────────────────
            for dot_ox, dot_oy in [(-0.68, -0.22), (0.68, -0.22),
                                    (0.00, -0.80), (-0.48, 0.70), (0.48, 0.70)]:
                dot_x = cx + dot_ox * R * 0.80
                dot_y = cy + dot_oy * R * 0.80
                dot_sdf = circle_sdf(x, y, dot_x, dot_y, R * 0.030)
                dot_a = aa_alpha(dot_sdf, 0.8) * 0.50
                r, g, b = blend((r, g, b), CYAN, dot_a)

            # ── Outer golden rim ─────────────────────────────────────────────
            rim_sdf = abs(circle_sdf(x, y, cx, cy, R - 3.5)) - 2.5
            rim_a   = aa_alpha(rim_sdf, 1.0) * 0.70
            r, g, b = blend((r, g, b), GOLD, rim_a)

            # ── Apply disc clip alpha ────────────────────────────────────────
            a_out = disc_alpha

            ri = int(clamp(r) * 255)
            gi = int(clamp(g) * 255)
            bi = int(clamp(b) * 255)
            ai = int(clamp(a_out) * 255)
            row += bytes([ri, gi, bi, ai])

        rows.append(bytes(row))
    return rows


# ── ICNS builder ─────────────────────────────────────────────────────────────
# Sizes and OSType codes required for a modern macOS .icns
ICNS_ENTRIES = [
    (16,   b"icp4"),
    (32,   b"icp5"),
    (64,   b"icp6"),
    (128,  b"ic07"),
    (256,  b"ic08"),
    (512,  b"ic09"),
    (1024, b"ic10"),
    # @2x HiDPI variants (same size PNGs, labelled with 2x codes)
    (32,   b"ic11"),   # 16@2x
    (64,   b"ic12"),   # 32@2x
    (256,  b"ic13"),   # 128@2x
    (512,  b"ic14"),   # 256@2x
]

def build_icns(png_map: dict) -> bytes:
    """Assemble an ICNS file from a dict of {size: png_bytes}."""
    icons_data = b""
    for size, ostype in ICNS_ENTRIES:
        png = png_map[size]
        entry = ostype + struct.pack(">I", len(png) + 8) + png
        icons_data += entry
    header = b"icns" + struct.pack(">I", len(icons_data) + 8)
    return header + icons_data


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    script_dir  = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    out_path    = os.path.join(project_dir, "Resources", "AppIcon.icns")

    print("Generating icon PNGs...")
    unique_sizes = sorted({s for s, _ in ICNS_ENTRIES})
    png_map = {}
    for sz in unique_sizes:
        print(f"  {sz}×{sz}...")
        rows   = draw_icon(sz)
        png_map[sz] = make_png(sz, sz, rows)

    print("Assembling ICNS...")
    icns_bytes = build_icns(png_map)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(icns_bytes)

    print(f"✓  Written {len(icns_bytes):,} bytes → {out_path}")

if __name__ == "__main__":
    main()

