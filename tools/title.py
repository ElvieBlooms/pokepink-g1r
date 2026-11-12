#!/usr/bin/env python3
"""Compose Yellow's title-screen pieces from a pret pokeyellow tree.

    from title import compose
    pieces = compose("path/to/pokeyellow")   # {"pikachu.png": RGBA array, ...}

    python3 title.py <pokeyellow_root> <imported_generated_dir>   # selftest

Mirrors the engine's importer (RomExtractor:extractYellowTitleArt), reading
the tile sheets, tilemaps, the partner's box and pokes and its eye OAM from
engine/movie/title_yellow.asm.  The engine draws pikachu.png at tile (4, 8)
and the blink overlays at pixel (56, 80) whatever the cart says, so the
composition is cut to those origins: a cart that places its partner
elsewhere (Pink's Clefairy sits at (3, 9)) is shifted into that frame, and
the blink overlays grow to cover wherever its eyes are.
"""
import os, re, sys
import numpy as np
from PIL import Image

GREY = np.array([255, 170, 85, 0])  # 2bpp colour index -> grey (importer SHADES)


def tiles_from_png(path, count=None):
    """8x8 tiles in row-major order, as colour indexes 0 (white) .. 3 (black)"""
    a = np.asarray(Image.open(path).convert("L"), dtype=np.int16)
    idx = np.argmin(np.abs(a[..., None] - GREY), axis=-1).astype(np.int8)
    h, w = idx.shape
    out = [idx[y:y + 8, x:x + 8] for y in range(0, h, 8) for x in range(0, w, 8)]
    return out[:count] if count else out


def parse_asm(root):
    src = open(os.path.join(root, "engine/movie/title_yellow.asm")).read()
    code = "\n".join(l.split(";", 1)[0].rstrip() for l in src.splitlines())
    m = re.search(r"TitleScreen_PlacePikachu:\n\s*hlcoord (\d+), (\d+)\n\s*ld de, TitleScreenPikachuTilemap\n\s*lb bc, (\d+), (\d+)", code)
    box = dict(x=int(m.group(1)), y=int(m.group(2)), rows=int(m.group(3)), cols=int(m.group(4)))
    body = code[m.end():code.index("ld hl, TitleScreenPikachuEyesOAMData", m.end())]
    pokes = [(int(x), int(y), int(v.replace("$", ""), 16))
             for x, y, v in re.findall(r"hlcoord (\d+), (\d+)\n\s*ld \[hl\], (\$\w+)", body)]
    m = re.search(r"TitleScreenPikachuEyesOAMData:\n((?:\s*db [^\n]+\n)+)", code)
    eyes = []
    for row in re.findall(r"db ([^\n]+)", m.group(1)):
        y, x, tile, attr = [int(v.strip().replace("$", ""), 16) for v in row.split(",")]
        eyes.append(dict(y=y - 16, x=x - 8, tile=tile - 0xF0, flip=bool(attr & 0x20)))
    m = re.search(r"TitleScreen_PlacePikaSpeechBubble:\n\s*hlcoord (\d+), (\d+)\n\s*ld de, TitleScreenPikaBubbleTilemap\n\s*lb bc, (\d+), (\d+)", code)
    bubble = dict(x=int(m.group(1)), y=int(m.group(2)), rows=int(m.group(3)), cols=int(m.group(4)))
    return box, pokes, eyes, bubble


def matte(img):
    """importer's matteColor0 over an index image: edge-connected white -> clear"""
    h, w = img.shape
    alpha = np.ones((h, w), dtype=bool)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w and 0 <= y < h) or not alpha[y, x] or img[y, x] != 0:
            continue
        alpha[y, x] = False
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return alpha


def compose(root):
    g = lambda rel: os.path.join(root, "gfx/title", rel)
    logo = tiles_from_png(g("pokemon_logo.png"), 115)
    corner = tiles_from_png(g("pokemon_logo_corner.png"), 3)
    bg = tiles_from_png(g("pikachu_bg.png"), 64)
    ob = tiles_from_png(g("pikachu_ob.png"), 12)

    def tile(i):
        if i < 0x80:
            return logo[i] if i < len(logo) else None
        if i < 0xF0:
            return bg[i - 0x80] if i - 0x80 < len(bg) else None
        if i < 0xFD:
            return ob[i - 0xF0]
        return corner[i - 0xFD]

    def canvas(cols, rows, cells):
        img = np.zeros((rows * 8, cols * 8), dtype=np.int8)
        alpha = np.zeros((rows * 8, cols * 8), dtype=bool)
        for i, c, r in cells:
            t = tile(i)
            if t is not None and 0 <= c < cols and 0 <= r < rows:
                img[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = t
                alpha[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = True
        return img, alpha

    def tilemap(name, cols, rows):
        data = open(g(name), "rb").read()[:cols * rows]
        return [(b, k % cols, k // cols) for k, b in enumerate(data)]

    box, pokes, eyes, bub = parse_asm(root)
    out = {}

    img, _ = canvas(16, 7, tilemap("pokemon_logo.tilemap", 16, 7))
    out["pokemon_logo.png"] = (img, np.ones(img.shape, dtype=bool))

    cells = tilemap("pika_bubble.tilemap", bub["cols"], bub["rows"])
    cells += [(0x64, 3, 4), (0x65, 4, 4)]
    img, _ = canvas(7, 5, cells)
    out["pika_bubble.png"] = (img, matte(img))

    # the partner, in the engine's frame: tile (4, 8), 13 x 9 tiles.  A
    # partner that starts further left (Pink's, at column 3) widens the
    # frame leftward; the mod moves the picture and its blink overlays left
    # by out["shift"] pixels when the title draws.
    OX, OY, COLS, ROWS = 4, 8, 13, 9
    if box["x"] < OX:
        COLS += OX - box["x"]
        OX = box["x"]
    cells = [(i, c + box["x"] - OX, r + box["y"] - OY)
             for i, c, r in tilemap("pikachu.tilemap", box["cols"], box["rows"])]
    cells += [(v, x - OX, y - OY) for x, y, v in pokes]
    for i, c, r in cells:
        if (c < 0 or c >= COLS or r < 0 or r >= ROWS) and i not in (0x00,):
            t = tile(i)
            if t is not None and (t != 0).any():
                raise SystemExit("title: tile $%02X at (%d, %d) falls outside the engine's frame" % (i, c + OX, r + OY))
    img, _ = canvas(COLS, ROWS, cells)
    pika = img.copy()

    # eyes are OAM: colour 0 is clear, OBP0 turns colour 1 white
    def eye_tile(n):
        t = ob[n].copy()
        t[t == 1] = 0
        return t

    def blit_eye(target, n, x, y, flip):
        t = ob[n]
        tt = eye_tile(n)
        if flip:
            t, tt = t[:, ::-1], tt[:, ::-1]
        for yy in range(8):
            for xx in range(8):
                if t[yy, xx] != 0 and 0 <= y + yy < target.shape[0] and 0 <= x + xx < target.shape[1]:
                    target[y + yy, x + xx] = tt[yy, xx]

    # blink overlays: drawn by the engine at screen (56, 80); a band that
    # covers every eye sprite, cut from the eyeless face
    ox, oy = OX * 8, OY * 8
    xs = [e["x"] - ox for e in eyes]
    ys = [e["y"] - oy for e in eyes]
    shift = (4 - OX) * 8
    bx0, by0 = 56 - shift - ox, 80 - oy
    bx1, by1 = max(max(xs) + 8, bx0 + 48), max(max(ys) + 8, by0 + 16)
    if min(xs) < bx0 or min(ys) < by0:
        raise SystemExit("title: the eyes sit above or left of the engine's blink band")
    overlays = {}
    for suffix, base in (("eyes_half.png", 4), ("eyes_closed.png", 8)):
        band = pika[by0:by1, bx0:bx1].copy()
        for e in eyes:
            blit_eye(band, base + e["tile"], e["x"] - ox - bx0, e["y"] - oy - by0, e["flip"])
        overlays[suffix] = band
    for e in eyes:
        blit_eye(pika, e["tile"], e["x"] - ox, e["y"] - oy, e["flip"])
    alpha = matte(pika)
    out["pikachu.png"] = (pika, alpha)
    out["shift"] = shift
    for suffix, band in overlays.items():
        h, w = band.shape
        out[suffix] = (band, alpha[by0:by0 + h, bx0:bx0 + w].copy())
    return out


def to_image(img, alpha):
    rgba = np.zeros(img.shape + (4,), dtype=np.uint8)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = GREY[img]
    rgba[..., 3] = alpha.astype(np.uint8) * 255
    return Image.fromarray(rgba, "RGBA")


def selftest(root, gen_dir):
    bad = 0
    pieces = compose(root)
    if pieces.pop("shift"):
        print("partner box is shifted")
        bad += 1
    for name, (img, alpha) in sorted(pieces.items()):
        imp = np.asarray(Image.open(os.path.join(gen_dir, "title", name)).convert("RGBA"), dtype=np.int16)
        if imp.shape[:2] != img.shape:
            print(name, "size", imp.shape[:2], img.shape)
            bad += 1
            continue
        ig = np.argmin(np.abs(imp[..., 0][..., None] - GREY), axis=-1)
        ia = imp[..., 3] > 0
        vis = ia | alpha
        ds = int(((ig != img) & ia & alpha).sum())
        da = int((ia != alpha).sum())
        print("%-16s shade %d alpha %d" % (name, ds, da))
        bad += ds + da
    return bad == 0


if __name__ == "__main__":
    sys.exit(0 if selftest(sys.argv[1], sys.argv[2]) else 1)
