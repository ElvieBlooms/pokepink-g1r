#!/usr/bin/env python3
"""Generate skins/pink_sgb_border/img/border.png, Pink's Super Game Boy border as a skin.

Usage: gen_sgb_border.py <pokepink_root> <pokeyellow_root> <skin_dir>

Pink's border (gfx/sgb/border.png, border.tilemap, the palettes in
data/sgb/sgb_border.asm) is drawn out at 256x224. Pink's own tiles, the
Clefairys and the FAIRY bubbles, are kept. Every tile that is also in Yellow's
border is dropped, so no Yellow pixels ship: the frame, the lettering, the
Poke Balls, the sparkles and the bubble tails are redrawn here as new art.
Flat fills are kept, since a solid colour is not art.

The picture is saved at 8x so the engine's smooth scaling stays sharp.
"""
import os, re, struct, sys
from PIL import Image

pink, yellow, skin_dir = sys.argv[1:4]
SCALE = 8
SCREEN = (48, 40, 208, 184)  # the Game Boy screen inside the 256x224 border


def tiles(path):
    im = Image.open(path).convert("L")
    w, h = im.size
    q = lambda v: 0 if v > 212 else 1 if v > 127 else 2 if v > 42 else 3
    px = im.load()
    return [tuple(q(px[tx + x, ty + y]) for y in range(8) for x in range(8))
            for ty in range(0, h, 8) for tx in range(0, w, 8)]


def rgb(r, g, b):
    return (r * 255 // 31, g * 255 // 31, b * 255 // 31, 255)


asm = open(os.path.join(pink, "data/sgb/sgb_border.asm")).read().split("ds $100")[1]
cols = [rgb(*map(int, m)) for m in re.findall(r"RGB\s+(\d+),\s*(\d+),\s*(\d+)", asm)]
pals = [cols[i * 16:i * 16 + 4] for i in range(4)]  # SGB border palettes 4-7

# Pink's border colours, named for the new pieces.
WHITE, LPINK, MAGENTA = pals[0][0], pals[0][1], pals[3][1]
RED, BLUE, BLACK = pals[1][1], pals[1][2], pals[0][3]

ptiles = tiles(os.path.join(pink, "gfx/sgb/border.png"))
ytiles = set(tiles(os.path.join(yellow, "gfx/sgb/border.png")))
tmap = open(os.path.join(pink, "gfx/sgb/border.tilemap"), "rb").read()

out = Image.new("RGBA", (256, 224), pals[0][0])
o = out.load()
dropped = 0
for i in range(32 * 28):
    e = struct.unpack_from("<H", tmap, i * 2)[0]
    t, pal, hf, vf = e & 0x3FF, (e >> 10) & 7, e >> 14 & 1, e >> 15 & 1
    tile = ptiles[t]
    bx, by = i % 32 * 8, i // 32 * 8
    if tile in ytiles and len(set(tile)) > 1:
        # Also in Yellow's border: leave sky here and redraw below.
        dropped += 1
        for y in range(8):
            for x in range(8):
                o[bx + x, by + y] = BLUE
        continue
    for y in range(8):
        for x in range(8):
            c = tile[(7 - y if vf else y) * 8 + (7 - x if hf else x)]
            if c:
                o[bx + x, by + y] = pals[pal - 4][c]


def put(x, y, c):
    if 0 <= x < 256 and 0 <= y < 224:
        o[x, y] = c


def stamp(x0, y0, rows, colours, flip=False):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row[::-1] if flip else row):
            if ch in colours:
                put(x0 + x, y0 + y, colours[ch])


# Frame: black edge, a light pink line, a magenta band, black inner edge.
# Rounded outer corners and a heart in each corner square.
L, T, R, B = 40, 32, 215, 191
for y in range(T, B + 1):
    for x in range(L, R + 1):
        if SCREEN[0] <= x < SCREEN[2] and SCREEN[1] <= y < SCREEN[3]:
            continue
        d = min(x - L, y - T, R - x, B - y)
        o[x, y] = BLACK if d in (0, 7) else LPINK if d == 1 else MAGENTA
for cx, cy, sx, sy in ((L, T, 1, 1), (R, T, -1, 1), (L, B, 1, -1), (R, B, -1, -1)):
    put(cx, cy, BLUE)
    put(cx + sx, cy + sy, BLACK)
    heart = ["11.11", "11111", "11111", ".111.", "..1.."]
    hx = cx + 2 * sx if sx > 0 else cx - 6
    hy = cy + 2 * sy if sy > 0 else cy - 6
    stamp(hx, hy, heart, {"1": WHITE})

# Lettering in a new 5x5 face: POKéMON along the top, PINK along the bottom.
FONT = {
    "P": ["1111.", "1...1", "1111.", "1....", "1...."],
    "O": [".111.", "1...1", "1...1", "1...1", ".111."],
    "K": ["1...1", "1..1.", "111..", "1..1.", "1...1"],
    "E": ["11111", "1....", "1111.", "1....", "11111"],
    "M": ["1...1", "11.11", "1.1.1", "1...1", "1...1"],
    "N": ["1...1", "11..1", "1.1.1", "1..11", "1...1"],
    "I": [".111.", "..1..", "..1..", "..1..", ".111."],
    "e": ["...1.", ".111.", "11111", "1....", ".111."],
}


def word(text, y):
    pitch = 14
    x = 128 - (len(text) * pitch - (pitch - 5)) // 2
    for ch in text:
        stamp(x, y, FONT[ch], {"1": WHITE})
        x += pitch


word("POKeMON", T + 2)
word("PINK", B - 6)


# Poke Balls, drawn fresh: 14 pixels across, lit from the top left.
def ball(x0, y0):
    cx, cy, r = x0 + 8.0, y0 + 8.0, 7.0
    for y in range(y0, y0 + 16):
        for x in range(x0, x0 + 16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = (dx * dx + dy * dy) ** 0.5
            if d > r:
                continue
            if d > r - 1.0 or abs(dy) < 1.0:
                c = BLACK
            else:
                c = RED if dy < 0 else WHITE
            if d < 3.2:
                c = BLACK if d > 1.9 else WHITE
            put(x, y, c)
    stamp(x0 + 3, y0 + 3, ["11", "1."], {"1": WHITE})


# Twinkles beside the middle ball, in place of Yellow's dashes.
def twinkle(x0, y0):
    stamp(x0, y0, ["..1..", "..1..", "11211", "..1..", "..1.."], {"1": WHITE, "2": LPINK})


for top in (8, 200):
    for x in (56, 120, 184):
        ball(x, top)
    twinkle(111, top + 2)
    twinkle(140, top + 2)
    stamp(113, top + 10, [".1.", "111", ".1."], {"1": WHITE})
    stamp(140, top + 10, [".1.", "111", ".1."], {"1": WHITE})

# Speech bubble tails under FAIRY, pointing straight down.
TAIL = ["33111113", "23111132", "22311322", "22311322", "22233222"]
for i in range(32 * 28):
    e = struct.unpack_from("<H", tmap, i * 2)[0]
    t = e & 0x3FF
    if ptiles[t] in ytiles and len(set(ptiles[t])) > 1 and i // 32 == 10 \
            and not 5 <= i % 32 <= 26:
        stamp(i % 32 * 8, 80, TAIL, {"3": BLACK, "1": RED}, flip=bool(e >> 14 & 1))

# The screen itself stays clear.
for y in range(SCREEN[1], SCREEN[3]):
    for x in range(SCREEN[0], SCREEN[2]):
        o[x, y] = (0, 0, 0, 0)

os.makedirs(os.path.join(skin_dir, "img"), exist_ok=True)
dest = os.path.join(skin_dir, "img/border.png")
out.resize((256 * SCALE, 224 * SCALE), Image.NEAREST).save(dest, optimize=True)
print(f"{dropped} tiles shared with Yellow redrawn; wrote {dest}")
