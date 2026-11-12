#!/usr/bin/env python3
"""Compose the Surfing minigame's title screen and intro frames from a pret
pokeyellow tree.

    from surfing import compose
    pieces = compose("path/to/pokeyellow")  # {"title_bg.png": shades, "intro_pika_0.png": (shades, alpha), ...}

    python3 surfing.py <pokeyellow_root> <imported_generated_dir>   # selftest

Mirrors the engine's importer (RomExtractor:extractSurfingPikachuTitleArt):
the 160x144 title is the beach tilemap with the title, "use control pad"
and "to surf rad" tilemaps over it, drawn from surfing_pikachu_1c's tiles;
the four paddling frames are 12 OAM tiles each from the same sheet.
Shades are 0 black .. 3 white.
"""
import os, sys
import numpy as np
from PIL import Image

LEVELS = np.array([0, 85, 170, 255])


def shades(path):
    a = np.asarray(Image.open(path).convert("L"), dtype=np.int16)
    return np.argmin(np.abs(a[..., None] - LEVELS), axis=-1).astype(np.int8)


def tiles(img):
    h, w = img.shape
    return [img[y:y + 8, x:x + 8] for y in range(0, h, 8) for x in range(0, w, 8)]


INTRO_FRAME_BASE = [0x80, 0x84, 0x88, 0x8C]
INTRO_OAM = [(-12, -16, 0x03), (-12, -8, 0x02), (-12, 0, 0x01), (-12, 8, 0x00),
             (-4, -16, 0x13), (-4, -8, 0x12), (-4, 0, 0x11), (-4, 8, 0x10),
             (4, -16, 0x23), (4, -8, 0x22), (4, 0, 0x21), (4, 8, 0x20)]


def compose(root, sheet=None):
    """sheet: surfing_pikachu_1c as the game sees it (defaults to the png)"""
    g = lambda rel: os.path.join(root, "gfx/surfing_pikachu", rel)
    if sheet is None:
        sheet = shades(g("surfing_pikachu_1c.png"))
    t = tiles(sheet)[:144]
    tm = lambda name, n: list(open(g(name), "rb").read()[:n])
    beach, ctrl, rad, title = tm("unknown_f90bc.tilemap", 240), tm("unknown_f91ac.tilemap", 15), \
        tm("unknown_f91bb.tilemap", 13), tm("unknown_f91c8.tilemap", 72)
    screen = [0xFF] * (20 * 18)
    for i, b in enumerate(beach):
        screen[6 * 20 + i] = b
    for r in range(6):
        for c in range(12):
            screen[r * 20 + 4 + c] = title[r * 12 + c]
    for r in range(3):
        for c in range(15):
            screen[(7 + r) * 20 + 3 + c] = 0xFF
    for i, b in enumerate(ctrl):
        screen[7 * 20 + 3 + i] = b
    for i, b in enumerate(rad):
        screen[9 * 20 + 4 + i] = b
    bg = np.full((144, 160), 3, dtype=np.int8)
    for r in range(18):
        for c in range(20):
            tid = screen[r * 20 + c]
            if tid == 0xFF:
                continue
            idx = tid - 0x80 if tid >= 0x80 else 128 + tid
            if 0 <= idx < 144:
                bg[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = t[idx]
    out = {"title_bg.png": (bg, None)}
    for f, base in enumerate(INTRO_FRAME_BASE):
        img = np.full((24, 32), 3, dtype=np.int8)
        alpha = np.zeros((24, 32), dtype=bool)
        for dy, dx, rel in INTRO_OAM:
            tile = t[base - 0x80 + rel][:, ::-1]  # every intro tile is x-flipped
            for y in range(8):
                for x in range(8):
                    # the importer's opaque tiles: every pixel lands, white too
                    px, py = 16 + dx + 8 + x, 12 + dy + y
                    if 0 <= px < 32 and 0 <= py < 24:
                        img[py, px] = tile[y, x]
                        alpha[py, px] = True
        out["intro_pika_%d.png" % f] = (img, alpha)
    return out


def selftest(root, gen_dir):
    sheet = shades(os.path.join(gen_dir, "minigame/surf_1c.png"))
    bad = 0
    for name, (img, alpha) in compose(root, sheet).items():
        imp = np.asarray(Image.open(os.path.join(gen_dir, "minigame", name)).convert("RGBA"), dtype=np.int16)
        ig = np.argmin(np.abs(imp[..., 0][..., None] - LEVELS), axis=-1)
        ia = imp[..., 3] > 0
        if alpha is None:
            ds, da = int((ig != img).sum()), 0
        else:
            ds, da = int(((ig != img) & alpha & ia).sum()), int((ia != alpha).sum())
        print("%-18s shade %d alpha %d" % (name, ds, da))
        bad += ds + da
    return bad == 0


if __name__ == "__main__":
    sys.exit(0 if selftest(sys.argv[1], sys.argv[2]) else 1)
