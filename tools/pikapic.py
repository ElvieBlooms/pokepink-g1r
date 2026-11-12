#!/usr/bin/env python3
"""Compose Yellow's partner emotion portraits from a pret pokeyellow tree.

    from pikapic import compose_all
    images = compose_all("path/to/pokeyellow")   # {"pikapic_1.png": PIL image, ...}

    python3 pikapic.py <pokeyellow_root> <imported_generated_dir>   # selftest

Mirrors the engine's importer (src/import/PikachuPicExtractor.lua), reading
the scripts, frame sets, tilemaps and graphics from the disassembly instead
of a ROM: each portrait is a 5x5-tile base picture with one overlay object
whose frames are drawn over it.  The selftest composes vanilla pokeyellow and
compares every file with the player's imported portraits.
"""
import os, re, sys
import numpy as np
from PIL import Image

LEVELS = np.array([0, 85, 170, 255])
PIC = 5


def strip(line):
    return line.split(";", 1)[0].strip()


def shades(img):
    a = np.asarray(img.convert("RGBA"), dtype=np.int16)
    idx = np.argmin(np.abs(a[..., 0][..., None] - LEVELS), axis=-1).astype(np.int8)
    idx[a[..., 3] == 0] = 3
    return idx


def num(tok):
    tok = tok.strip()
    if tok.startswith("$"):
        return int(tok[1:], 16)
    if tok.startswith("%"):
        return int(tok[1:], 2)
    return int(tok) & 0xff


def parse(root):
    def lines(rel):
        return [strip(l) for l in open(os.path.join(root, rel))]

    # graphics headers: index -> (size, label)
    gfx = []
    anim = lines("data/pikachu/pikachu_pic_animation.asm")
    for l in anim:
        m = re.match(r"pikapicanimgfx\s+(-?\d+),\s*(\w+)", l)
        if m:
            gfx.append((int(m.group(1)), m.group(2)))
    gfx_index = {label: i for i, (_, label) in enumerate(gfx)}

    # label -> file: Pic_e4000 / GFX_e40cc INCBIN lines in gfx/pikachu.asm
    files = {}
    pending = []
    for l in lines("gfx/pikachu.asm"):
        m = re.match(r"(\w+)::?$", l)
        if m:
            pending.append(m.group(1))
            continue
        m = re.match(r'INCBIN "(gfx/pikachu/[\w]+)\.(pic|2bpp)"', l)
        if m:
            for label in pending:
                files[label] = (m.group(1) + ".png", m.group(2))
            pending = []

    # scripts: label -> commands; labels stacked on one body share it
    body, group, cmds = {}, [], None
    for l in anim:
        m = re.match(r"(\w+):$", l)
        if m:
            if cmds is not None:
                group, cmds = [], None
            group.append(m.group(1))
            continue
        if not l or not group:
            continue
        if cmds is None:
            cmds = []
            for g in group:
                body[g] = cmds
        m = re.match(r"pikapic_loadgfx\s+(\w+)", l)
        if m:
            cmds.append(("gfx", gfx_index[m.group(1)]))
        m = re.match(r"pikapic_animation\s+(\w+),\s*([^,]+),\s*([^,]+),\s*([^,]+)", l)
        if m:
            cmds.append(("object", m.group(1), num(m.group(2)), num(m.group(3)), num(m.group(4))))
        if re.match(r"pikapic_(looptofinish|ret|jump)", l) or re.match(r"PikaPicAnimGFXHeaders|MACRO", l):
            group = []

    # script pointers: id -> label
    pointers = [m.group(1) for l in lines("engine/pikachu/pikachu_pic_animation.asm")
                for m in [re.match(r"pikapic_def\s+(\w+)", l)] if m]

    # frame sets and tilemaps
    objs = lines("data/pikachu/pikachu_pic_objects.asm")
    tm_lines = lines("data/pikachu/pikachu_pic_tilemaps.asm")
    tilemap_ids = [m.group(1) for l in tm_lines for m in [re.match(r"pikatilemap_def\s+(\w+)", l)] if m]
    tm_index = {}
    for i, label in enumerate(tilemap_ids):
        tm_index.setdefault(label, i)
    framesets, group, cur = {}, [], None
    for l in objs:
        m = re.match(r"(\w+):$", l)
        if m:
            if cur is not None:
                group, cur = [], None
            group.append(m.group(1))
            continue
        if not l or not group:
            continue
        if cur is None:
            cur = []
            for g in group:
                framesets[g] = cur
        m = re.match(r"pikaframe\s+(\w+),\s*(\w+)", l)
        if m:
            cur.append((tm_index[m.group(1)], num(m.group(2))))
        m = re.match(r"pikaframedelay\s+(\w+)", l)
        if m:
            cur.append((0, num(m.group(1))))
    tilemaps, group, cur = {}, [], None
    for l in tm_lines:
        m = re.match(r"(\w+):$", l)
        if m:
            if cur is not None:
                group, cur = [], None
            group.append(m.group(1))
            continue
        if not l.startswith("db") or not group:
            continue
        vals = [num(t) for t in l[2:].split(",")]
        if cur is None:
            if len(vals) < 2:  # PikaAnimTilemap_0: "db -1 ; unused"
                cur = {"rows": 0, "cols": 0, "cells": []}
                for g in group:
                    tilemaps.setdefault(tm_index[g], cur) if g in tm_index else None
                continue
            cur = {"rows": vals[0], "cols": vals[1], "cells": []}
            for g in group:
                tilemaps.setdefault(tm_index[g], cur) if g in tm_index else None
            vals = vals[2:]
        cur["cells"] += vals
    return gfx, files, body, pointers, framesets, tilemaps


def tiles_of(root, files, label, size):
    path, kind = files[label]
    img = shades(Image.open(os.path.join(root, path)))
    h, w = img.shape
    out = []
    if kind == "pic":
        for k in range(PIC * PIC):
            x, y = (k // PIC) * 8, (k % PIC) * 8
            out.append(img[y:y + 8, x:x + 8])
    else:
        for ty in range(h // 8):
            for tx in range(w // 8):
                out.append(img[ty * 8:ty * 8 + 8, tx * 8:tx * 8 + 8])
        out = out[:size]
    return out


def matte(canvas):
    """the importer's matteColor0: white connected to the edge goes clear"""
    h, w = canvas.shape
    alpha = np.ones((h, w), dtype=np.int8)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w and 0 <= y < h) or alpha[y, x] == 0 or canvas[y, x] != 3:
            continue
        alpha[y, x] = 0
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return alpha


def compose_all(root):
    gfx, files, body, pointers, framesets, tilemaps = parse(root)
    out = {}
    for pid in range(1, 0x1d):
        cmds = body[pointers[pid]]
        vram, nxt = {}, 0x80
        for c in cmds:
            if c[0] == "gfx":
                size, label = gfx[c[1]]
                tiles = tiles_of(root, files, label, size)
                for k, t in enumerate(tiles):
                    vram[nxt + k] = t
                nxt += len(tiles)
        objects = [c for c in cmds if c[0] == "object"]
        assert len(objects) == 2, (pid, objects)
        (_, bset, bvt, bx, by), (_, oset, ovt, ox, oy) = objects
        base_frames = framesets[bset]
        assert len(base_frames) == 1 and base_frames[0][1] == 0, (pid, base_frames)

        def paint(canvas, vt, x0, y0, tm):
            for r in range(tm["rows"]):
                for c in range(tm["cols"]):
                    cell = tm["cells"][r * tm["cols"] + c]
                    y, x = y0 + r, x0 + c
                    if cell != 0xff and y < PIC and x < PIC:
                        canvas[y * 8:y * 8 + 8, x * 8:x * 8 + 8] = vram[(cell + vt) % 0x100]

        def compose(overlay):
            canvas = np.full((PIC * 8, PIC * 8), 3, dtype=np.int8)
            paint(canvas, bvt, bx, by, tilemaps[base_frames[0][0]])
            if overlay is not None:
                paint(canvas, ovt, ox, oy, tilemaps[overlay])
            return canvas

        name = "pikapic_%d" % pid
        out[name + ".png"] = compose(None)
        for tm, _ in framesets[oset]:
            if tm != 0:
                out["%s_%d.png" % (name, tm)] = compose(tm)
    return out


def to_image(canvas):
    alpha = matte(canvas)
    rgba = np.zeros(canvas.shape + (4,), dtype=np.uint8)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = LEVELS[canvas]
    rgba[..., 3] = alpha.astype(np.uint8) * 255
    return Image.fromarray(rgba, "RGBA")


def selftest(root, gen_dir):
    images = compose_all(root)
    bad = 0
    for name, canvas in sorted(images.items()):
        path = os.path.join(gen_dir, "pikachu", name)
        if not os.path.exists(path):
            print("missing in import:", name)
            bad += 1
            continue
        imp = Image.open(path).convert("RGBA")
        got = np.asarray(imp)
        want_alpha = matte(canvas)
        # some imported portraits come out with no transparency at all (the
        # importer's PNG writer keeps a grey-3 key no pixel uses); only
        # compare the matte where the import has one
        has_alpha = bool((got[..., 3] == 0).any())
        if not (np.array_equal(shades(imp), canvas)
                and (not has_alpha or np.array_equal((got[..., 3] > 0).astype(np.int8), want_alpha))):
            print("differs:", name)
            bad += 1
    extra = set(os.listdir(os.path.join(gen_dir, "pikachu"))) - set(images)
    print("composed %d portraits, %d differ, import has %d we don't make" % (len(images), bad, len(extra)))
    return bad == 0


if __name__ == "__main__":
    sys.exit(0 if selftest(sys.argv[1], sys.argv[2]) else 1)
