#!/usr/bin/env python3
"""Generate pink_presentation/intro_data.lua: Pink's intro sprite animation.

Usage: gen_intro_data.py <pokepink_root> <pinkbase_root> <out.lua>
       gen_intro_data.py --dump <pokeyellow_root>      (the tables, as JSON)

Reads the intro's animated objects from the disassembly:
  data/sprite_anims/intro_frames.asm   frame scripts: (frame, duration) lists
                                       that end held (endanim) or loop
                                       (dorestart)
  data/sprite_anims/intro_oam.asm      frame -> base tile and OAM layout
                                       (dy, dx, tile, flip)
  engine/movie/intro_yellow.asm        which frame script and movement each
                                       object id has, where each scene spawns
                                       its objects, and scene 12's pasted
                                       close-up
Only scenes whose spawns or pasted picture differ from vanilla are listed,
so the mod leaves the rest of the engine's intro alone.
"""
import json, os, re, sys


def strip(line):
    return line.split(";", 1)[0].strip()


def num(tok):
    tok = tok.strip()
    if tok.startswith("$"):
        return int(tok[1:], 16)
    return int(tok)


def signed(v):
    return v - 256 if v >= 128 else v


def parse(root):
    out = {}
    # frame scripts
    fr = [strip(l) for l in open(os.path.join(root, "data/sprite_anims/intro_frames.asm"))]
    order = []
    labels, cur = {}, None
    for l in fr:
        if not l:
            continue
        m = re.match(r"dw (\w+)$", l)
        if m and cur is None:
            order.append(m.group(1))
            continue
        m = re.match(r"(\w+):$", l)
        if m:
            if m.group(1) == "YellowIntro_AnimatedObjectFramesData":
                continue
            cur = labels.setdefault(m.group(1), {"frames": [], "loop": False})
            continue
        m = re.match(r"frame (\$?\w+),\s*(\d+)$", l)
        if m and cur is not None:
            cur["frames"].append([num(m.group(1)), int(m.group(2))])
            continue
        if l == "dorestart" and cur is not None:
            cur["loop"] = True
    out["framesets"] = [labels[name] for name in order]

    # OAM
    oam = [strip(l) for l in open(os.path.join(root, "data/sprite_anims/intro_oam.asm"))]
    table, layouts, cur = [], {}, None
    for l in oam:
        if not l:
            continue
        m = re.match(r"dbw (\$?\w+),\s*(\w+)$", l)
        if m:
            table.append([num(m.group(1)), m.group(2)])
            continue
        m = re.match(r"(\w+):$", l)
        if m:
            cur = None if m.group(1) == "YellowIntro_AnimatedObjectOAMData" else layouts.setdefault(m.group(1), [])
            continue
        m = re.match(r"db (.*)$", l)
        if m and cur is not None:
            vals = [num(v) for v in m.group(1).split(",")]
            if len(vals) == 4:
                dy, dx, tile, attr = vals
                cur.append([signed(dy), signed(dx), tile, bool(attr & 0x20)])
    out["frames"] = [{"base": base, "oam": layouts[name]} for base, name in table]

    # objects, scenes
    code = [strip(l) for l in open(os.path.join(root, "engine/movie/intro_yellow.asm"))]
    text = "\n".join(code)
    m = re.search(r"YellowIntro_AnimatedObjectSpawnStateData:\n((?:db [^\n]+\n)+)", text)
    spawn = {}
    for row in re.findall(r"db ([^\n]+)", m.group(1)):
        vals = [num(v) for v in row.split(",")]
        spawn[vals[0]] = {"frameset": vals[0], "move": vals[1]}
    # rows are indexed by object id, the first byte is the frame script
    rows = re.findall(r"db ([^\n]+)", m.group(1))
    spawn = {i: {"frameset": num(r.split(",")[0]), "move": num(r.split(",")[1])} for i, r in enumerate(rows)}
    out["spawn"] = spawn
    # movement routines by jumptable index
    jt = re.search(r"YellowIntro_AnimatedObjectJumptable:\n((?:dw \w+\n)+)", text)
    out["moves"] = re.findall(r"dw (\w+)", jt.group(1))

    scenes = {}
    for sm in re.finditer(r"YellowIntroScene(\d+):\n(.*?)(?=\nYellowIntroScene\d+:|\nYellowIntro_SpawnAnimatedObjectAndSavePointer:)", text, re.S):
        n, body = int(sm.group(1)), sm.group(2)
        spawns = [[num(i), num(x), num(y)] for y, x, i in
                  re.findall(r"lb de, (\$\w+), (\$\w+)\n\s*ld a, (\$\w+)\n\s*call \w*SpawnAnimatedObject", body)]
        paste = re.search(r"ld hl, \$(\w+)\n\s*ld de, \$20\n\s*ld a, \$4\n\s*ld b, 8", body)
        pokes = [[int(a, 16), num(v)] for a, v in re.findall(r"ld hl, \$(9[89a-f]\w\w)[^\n]*\n\s*ld \[hl\], (\$\w+)", body)]
        rec = {"spawns": spawns}
        if paste:
            addr = int(paste.group(1), 16) - 0x9800
            rec["paste"] = [addr % 32, addr // 32]
            rec["pokes"] = [[(a - 0x9800) % 32, (a - 0x9800) // 32, v] for a, v in pokes]
        scenes[n] = rec
    out["scenes"] = scenes
    return out


def lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            key = "[%d]" % k if isinstance(k, int) else (k if re.match(r"^[A-Za-z_]\w*$", k) else '["%s"]' % k)
            items.append("%s  %s = %s," % (pad, key, lua(v[k], ind + 1)))
        return "{\n" + "\n".join(items) + "\n" + pad + "}" if items else "{}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(lua(x) for x in v) + " }"
        return "{\n" + "\n".join(pad + "  " + lua(x, ind + 1) + "," for x in v) + "\n" + pad + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    return str(v)


def main():
    if sys.argv[1] == "--dump":
        print(json.dumps(parse(sys.argv[2])))
        return
    pink, base, out_path = sys.argv[1:4]
    P, B = parse(pink), parse(base)
    if P["moves"] != B["moves"]:
        raise SystemExit("Pink changed the movement routines: %s" % P["moves"])
    changed = {}
    for n, rec in P["scenes"].items():
        if rec != B["scenes"].get(n):
            changed[n] = rec
    data = {
        # frame script n (1-based here: Lua list), from Pink
        "framesets": [{"frames": f["frames"], "loop": f["loop"]} for f in P["framesets"]],
        # frame id -> layout (index = frame id + 1)
        "frames": [{"base": f["base"], "oam": [[e[0], e[1], e[2], e[3]] for e in f["oam"]]} for f in P["frames"]],
        "spawn": {i: s for i, s in P["spawn"].items()},
        "moves": P["moves"],
        "scenes": changed,
    }
    with open(out_path, "w") as f:
        f.write("-- generated by gen_intro_data.py from Pokemon Pink's intro (by jcferggy); do not edit.\n")
        f.write("-- framesets[i] is frame script i-1 and frames[i] is frame id i-1 (the asm counts from 0).\n")
        f.write("return " + lua(data) + "\n")
    print("framesets %d, frames %d, objects %d, scenes Pink changes: %s"
          % (len(data["framesets"]), len(data["frames"]), len(data["spawn"]), sorted(changed)))
    for n in sorted(changed):
        print("  scene %d: %s | vanilla %s" % (n, changed[n], B["scenes"].get(n)))


if __name__ == "__main__":
    main()
