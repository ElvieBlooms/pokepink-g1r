#!/usr/bin/env python3
"""Generate pink_presentation/art_data.lua: Pink's sprite and picture edits,
stored as changes to the player's own imported art.

Usage: gen_art_data.py <pokepink_root> <pinkbase_root> <install_dir> <out.lua>

<install_dir> is a Gen1Recomp save folder holding the imports
(<game>/assets/generated/...).  It's read here to measure Pink's changes
and to check that every base the mod builds from gives the same picture in
each game it may come from; nothing from it is written out except the
positions and shades of the pixels Pink changed.

A job rebuilds one image of the engine's art cache:
  out    the cache-relative path written to save/mod-derived/pink_presentation/
  bases  where the starting picture comes from, first found wins
  size   width, height
  perm   base shade -> Pink shade, when the base orders its greys differently
  patch  { index, shade, ... } for each pixel Pink changed (index = y*w + x,
         shade 0 black .. 3 white)
  matte  battle pictures: the white around the picture becomes transparent
Every picture here was drawn over a cart's own art; nothing ships whole.
"""
import itertools, os, re, sys
import numpy as np
from PIL import Image

LEVELS = np.array([0, 85, 170, 255])


def shades(path):
    """4-level shade index per pixel; transparent counts as white."""
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im, dtype=np.int16)
    grey = a[..., 0]  # every cache and pret image here is grey
    idx = np.argmin(np.abs(grey[..., None] - LEVELS), axis=-1).astype(np.int8)
    idx[a[..., 3] == 0] = 3
    return idx


def best_perm(base, target):
    best = None
    for p in itertools.permutations(range(4)):
        d = int((np.array(p)[base] != target).sum())
        if best is None or d < best[0]:
            best = (d, p)
    return best


GEN2 = ("gold", "silver", "crystal")
# overworld sprites Pink added: sprite id, Pink file, the sheet it was drawn
# over (in the games that have it), gym map
NEW_SPRITES = [
    ("SPRITE_PINK_BROCK", "brock", [(g, "sprites/brock.png") for g in GEN2], "PEWTER_GYM"),
    ("SPRITE_PINK_MISTY", "misty", [(g, "sprites/misty.png") for g in GEN2], "CERULEAN_GYM"),
    ("SPRITE_PINK_SURGE", "surge", [(g, "sprites/surge.png") for g in GEN2], "VERMILION_GYM"),
    ("SPRITE_PINK_ERIKA", "erika", [(g, "sprites/erika.png") for g in GEN2], "CELADON_GYM"),
    ("SPRITE_PINK_SABRINA", "sabrina", [("yellow", "sprites/silph_worker_f.png")], "SAFFRON_GYM"),
    ("SPRITE_PINK_KOGA", "koga2", [(g, "sprites/koga.png") for g in GEN2], "FUCHSIA_GYM"),
    ("SPRITE_PINK_BLAINE", "blaine", [(g, "sprites/blaine.png") for g in GEN2], "CINNABAR_GYM"),
]
# Pink's manga characters, each walking frame drawn over a frame of one of
# Yellow's own sheets (the closest is picked per frame)
FRAME_SPRITES = [("sprites/pink_busybody.png", "manga_blue"), ("sprites/pink_yellow.png", "manga_yellow")]
# Pink's edits of sheets Yellow already has
YELLOW_SPRITES = ["agatha", "bruno", "lance", "lorelei", "giovanni"]
# a patch bigger than this share of the picture is a redraw, not an edit
REDRAW = 0.5


def lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            key = "[%d]" % k if isinstance(k, int) else (k if re.match(r"^[A-Za-z_]\w*$", k) else '["%s"]' % k)
            items.append("%s  %s = %s," % (pad, key, lua(v[k], ind + 1)))
        return "{\n" + "\n".join(items) + "\n" + pad + "}"
    if isinstance(v, (list, tuple)):
        if all(not isinstance(x, (dict, list, tuple)) for x in v):
            body = ", ".join(lua(x) for x in v)
            if len(body) > 100:
                chunks = [", ".join(lua(x) for x in v[i:i + 24]) for i in range(0, len(v), 24)]
                return "{\n" + ",\n".join(pad + "  " + c for c in chunks) + ",\n" + pad + "}"
            return "{ " + body + " }"
        return "{\n" + "\n".join(pad + "  " + lua(x, ind + 1) + "," for x in v) + "\n" + pad + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    if v is None:
        return "nil"
    return str(int(v))


def main():
    pink, base_root, install, out_path = sys.argv[1:5]
    cache = lambda game, rel: os.path.join(install, game, "assets/generated", rel)
    jobs, notes = [], []

    def frame_job(out, pink_png):
        """a 6-frame sheet built frame by frame from Yellow's sheets"""
        target = shades(pink_png)
        sheets = {}
        for fn in sorted(os.listdir(os.path.join(install, "yellow/assets/generated/sprites"))):
            a = shades(cache("yellow", "sprites/" + fn))
            if a.shape[1] == 16:
                sheets[fn] = a
        frames, ref = [], np.zeros_like(target)
        for k in range(target.shape[0] // 16):
            want = target[k * 16:k * 16 + 16]
            d, fn, j = min((int((a[j * 16:j * 16 + 16] != want).sum()), fn, j)
                           for fn, a in sheets.items() for j in range(a.shape[0] // 16))
            frames.append({"bases": [{"game": "yellow", "rel": "sprites/" + fn}], "src": j, "dst": k})
            ref[k * 16:k * 16 + 16] = sheets[fn][j * 16:j * 16 + 16]
        h, w = target.shape
        changed = np.argwhere(ref != target)
        if len(changed) > REDRAW * w * h:
            raise SystemExit("%s: %d of %d pixels changed: a redraw, not an edit" % (out, len(changed), w * h))
        patch = []
        for y, x in changed:
            patch += [int(y) * w + int(x), int(target[y, x])]
        jobs.append({"out": out, "parts": frames, "size": [w, h], "patch": patch})
        return len(changed), w * h

    def job(out, pink_png, bases, matte=False, extra=None):
        target = shades(pink_png)
        found = [(g, rel) for g, rel in bases if os.path.exists(cache(g, rel))]
        if not found:
            raise SystemExit("%s: no import has %s" % (out, bases))
        ref = None
        for g, rel in found:
            b = shades(cache(g, rel))
            if b.shape != target.shape:
                raise SystemExit("%s: %s/%s is %s, Pink's is %s" % (out, g, rel, b.shape, target.shape))
            if ref is None:
                ref = b
            elif not np.array_equal(ref, b):
                raise SystemExit("%s: %s/%s differs from %s; bases must agree" % (out, g, rel, found[0]))
        d, perm = best_perm(ref, target)
        mapped = np.array(perm)[ref]
        h, w = target.shape
        changed = np.argwhere(mapped != target)
        if len(changed) > REDRAW * w * h:
            raise SystemExit("%s: %d of %d pixels changed: a redraw, not an edit" % (out, len(changed), w * h))
        patch = []
        for y, x in changed:
            patch += [int(y) * w + int(x), int(target[y, x])]
        rec = {"out": out, "bases": [{"game": g, "rel": r} for g, r in bases],
               "size": [w, h], "patch": patch}
        if tuple(perm) != (0, 1, 2, 3):
            rec["perm"] = list(perm)
        if matte:
            rec["matte"] = True
        rec.update(extra or {})
        jobs.append(rec)
        return len(changed), w * h

    report = []
    # gym leaders: Gen 2 sheets plus Pink's touch-ups
    for sid, pink_name, bases, gym in NEW_SPRITES:
        n, total = job("sprites/pink_%s.png" % pink_name, os.path.join(pink, "gfx/sprites/%s.png" % pink_name),
                       bases,
                       extra={"sprite": sid, "frames": 6, "walker": True, "gym": gym})
        report.append("%s %d/%d" % (pink_name, n, total))
    for out, name in FRAME_SPRITES:
        n, total = frame_job(out, os.path.join(pink, "gfx/sprites/%s.png" % name))
        report.append("%s %d/%d" % (name, n, total))
    # Elite Four and Giovanni: Yellow's sheets, edited
    for name in YELLOW_SPRITES:
        n, total = job("sprites/%s.png" % name, os.path.join(pink, "gfx/sprites/%s.png" % name),
                       [("yellow", "sprites/%s.png" % name)])
        report.append("%s %d/%d" % (name, n, total))
    # battle pictures Pink edited
    for kind, sub, suffix in (("back", "battle/back", ""), ("front", "battle/front", "")):
        d_p, d_b = os.path.join(pink, "gfx/pokemon", kind), os.path.join(base_root, "gfx/pokemon", kind)
        for fn in sorted(os.listdir(d_p)):
            if not fn.endswith(".png"):
                continue
            bp = os.path.join(d_b, fn)
            if os.path.exists(bp) and open(bp, "rb").read() == open(os.path.join(d_p, fn), "rb").read():
                continue
            n, total = job("%s/%s" % (sub, fn), os.path.join(d_p, fn), [("yellow", "%s/%s" % (sub, fn))], matte=True)
            report.append("%s %d/%d" % (fn, n, total))

    # which object each leader is: the line using Pink's new sprite
    def leader_object(gym, pink_name):
        label = "".join(w.capitalize() for w in gym.split("_"))
        text = open(os.path.join(pink, "data/maps/objects/%s.asm" % label)).read()
        sprites = re.findall(r"^\s*object_event\s+\d+,\s*\d+,\s*(SPRITE_\w+)", text, re.M)
        want = "SPRITE_" + pink_name.upper()
        if want not in sprites:
            raise SystemExit("%s: no %s object" % (label, want))
        return sprites.index(want) + 1
    for j in jobs:
        if "gym" in j:
            j["object"] = leader_object(j["gym"], j["out"].split("pink_")[1][:-4])

    with open(out_path, "w") as f:
        f.write("-- generated by gen_art_data.py; do not edit.\n")
        f.write("-- Pokemon Pink's sprite and picture edits (by jcferggy), as changes to the\n")
        f.write("-- player's own imported art: only the pixels Pink changed are listed.\n")
        f.write("return {\n  jobs = " + lua(jobs, 1) + ",\n")
        f.write("}\n")
    print("jobs:", len(jobs))
    print("  " + ", ".join(report))
    for n in notes:
        print("note:", n)


if __name__ == "__main__":
    main()
