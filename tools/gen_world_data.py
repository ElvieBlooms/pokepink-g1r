#!/usr/bin/env python3
"""Generate pink_world_tweaks/world_data.lua from a pret-style disassembly.

Usage: gen_world_data.py <disasm_root> <imported_generated_dir> <out.lua> [--selftest]

Compares the disassembly with the player's imported vanilla data and writes
only what differs:
  blocks      map id -> { [cell] = block }       (maps/*.blk, 1-based cells)
  blockDefs   tileset id -> { [block] = {16 tile ids} }   (gfx/blocksets/*.bst)
  walkable    tileset id -> walkable tile list    (data/tilesets/collision_tile_ids.asm)
  cutTrees    new { before, after } pairs         (data/tilesets/cut_tree_blocks.asm)
  dungeon     { maps = {...}, ranges = {{first, last}, ...} } additions
              (data/maps/dungeon_maps.asm)
Nothing unchanged is written, so no vanilla map, blockset or collision table
ships in full.

--selftest runs on vanilla pokeyellow and must report no differences.
"""
import json, os, re, subprocess, sys


def load_import(gen_dir):
    script = r'''
local dir = DIR
local function enc(v)
  local t = type(v)
  if t == "table" then
    local n = #v
    local isList = n > 0 or next(v) == nil
    if isList then for k in pairs(v) do if type(k) ~= "number" then isList = false break end end end
    local parts = {}
    if isList then
      for i = 1, n do parts[#parts+1] = enc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, x in pairs(v) do
      if type(x) ~= "function" then parts[#parts+1] = string.format("%q", tostring(k)) .. ":" .. enc(x) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" or t == "boolean" then return tostring(v)
  else return "null" end
end
local maps, ts, f = dofile(dir .. "/maps.lua"), dofile(dir .. "/tilesets.lua"), dofile(dir .. "/field.lua")
local m, t = {}, {}
for id, r in pairs(maps) do m[id] = { label = r.label, blocks = r.blocks, warps = r.warps } end
for id, r in pairs(ts) do t[id] = { blocks = r.blocks, walkable = r.walkable } end
io.write(enc({ maps = m, tilesets = t, cutTreeSwaps = f.cutTreeSwaps,
               dungeon = f.dungeonTransitionMaps, trades = f.trades }))
'''.replace("DIR", repr(gen_dir))
    p = subprocess.run(["luajit", "-e", script], capture_output=True, text=True)
    if p.returncode:
        raise SystemExit(p.stderr)
    return json.loads(p.stdout)


def strip(line):
    return line.split(";", 1)[0].strip()


def hexnum(tok):
    tok = tok.strip()
    return int(tok[1:], 16) if tok.startswith("$") else int(tok)


def blocks_of(path):
    return list(open(path, "rb").read())


def blockset(path):
    raw = open(path, "rb").read()
    return [list(raw[i:i + 16]) for i in range(0, len(raw), 16)]


def import_blocks(rec):
    # tileset blocks are lists of 16 tile ids (or string-keyed 1..16 after JSON)
    out = []
    for b in rec["blocks"]:
        out.append([b[i] for i in range(16)] if isinstance(b, list)
                   else [b[str(i)] for i in range(1, 17)])
    return out


def parse_collision(root):
    out, label = {}, None
    for raw in open(os.path.join(root, "data/tilesets/collision_tile_ids.asm")):
        line = strip(raw)
        m = re.match(r"(\w+)::?$", line)
        if m:
            label = m.group(1)
            continue
        m = re.match(r"coll_tiles\s*(.*)$", line)
        if m and label:
            out[label] = sorted(hexnum(x) for x in m.group(1).split(",") if x.strip())
    return out


def parse_cut(root):
    pairs = []
    for raw in open(os.path.join(root, "data/tilesets/cut_tree_blocks.asm")):
        m = re.match(r"db\s+(\S+),\s*(\S+)", strip(raw))
        if m and m.group(1) not in ("-1", "$FF"):
            pairs.append((hexnum(m.group(1)), hexnum(m.group(2))))
    return pairs


def parse_dungeon(root):
    singles, ranges = [], []
    for raw in open(os.path.join(root, "data/maps/dungeon_maps.asm")):
        line = strip(raw)
        m = re.match(r"db\s+(\w+)\s*,\s*(\w+)$", line)
        if m:
            ranges.append((m.group(1), m.group(2)))
            continue
        m = re.match(r"db\s+([A-Z_0-9]+)$", line)
        if m and m.group(1) not in ("-1",):
            singles.append(m.group(1))
    return singles, ranges


SWAP = {"PIKACHU": "CLEFAIRY", "CLEFAIRY": "PIKACHU", "RAICHU": "CLEFABLE", "CLEFABLE": "RAICHU"}
DIALOGSET = {"TRADE_DIALOGSET_CASUAL": 1, "TRADE_DIALOGSET_EVOLUTION": 2, "TRADE_DIALOGSET_HAPPY": 3}


def parse_warps(root):
    """map label -> [ {x, y, destMap, destWarp} ] from data/maps/objects/*.asm"""
    out = {}
    d = os.path.join(root, "data/maps/objects")
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".asm"):
            continue
        warps = []
        for raw in open(os.path.join(d, fn)):
            m = re.match(r"warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)", strip(raw))
            if m:
                warps.append({"x": int(m.group(1)), "y": int(m.group(2)),
                              "destMap": m.group(3), "destWarp": int(m.group(4))})
        out[fn[:-4]] = warps
    return out


def parse_trades(root):
    out = []
    for raw in open(os.path.join(root, "data/events/trades.asm")):
        m = re.match(r'npctrade\s+(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*"([^"]*)"', strip(raw))
        if m:
            out.append({"give": m.group(1), "get": m.group(2),
                        "dialogset": DIALOGSET[m.group(3)], "nickname": m.group(4)})
    return out


def parse_object_sprites(root):
    out = {}
    d = os.path.join(root, "data/maps/objects")
    for fn in os.listdir(d):
        if fn.endswith(".asm"):
            text = open(os.path.join(d, fn)).read()
            out[fn[:-4]] = re.findall(r"^\s*object_event\s+\d+,\s*-?\d+,\s*(SPRITE_\w+)", text, re.M)
    return out


def sprite_ids(root):
    text = open(os.path.join(root, "constants/sprite_constants.asm")).read()
    return set(re.findall(r"const (SPRITE_\w+)", text))


def main():
    root, gen_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    selftest = "--selftest" in sys.argv
    imp = load_import(gen_dir)
    notes = []

    # ---- map block layouts: .blk file name == the import's map label
    by_label = {r["label"]: mid for mid, r in imp["maps"].items() if r.get("label")}
    blocks = {}
    for fn in sorted(os.listdir(os.path.join(root, "maps"))):
        if not fn.endswith(".blk"):
            continue
        label = fn[:-4]
        mid = by_label.get(label)
        if not mid:
            continue  # a .blk no map uses (or a Pink-only map, handled with events)
        new = blocks_of(os.path.join(root, "maps", fn))
        old = imp["maps"][mid]["blocks"]
        if len(new) != len(old):
            notes.append(f"{mid}: size {len(old)} -> {len(new)}, skipped")
            continue
        diff = {i + 1: b for i, (a, b) in enumerate(zip(old, new)) if a != b}
        if diff:
            blocks[mid] = diff

    # ---- block definitions: match each .bst to the tilesets using it in the import
    block_defs = {}
    for fn in sorted(os.listdir(os.path.join(root, "gfx/blocksets"))):
        if not fn.endswith(".bst"):
            continue
        new = blockset(os.path.join(root, "gfx/blocksets", fn))
        vanilla_path = os.path.join(root.replace("pokepink", "pokeyellow"), "gfx/blocksets", fn)
        ref = blockset(vanilla_path) if (not selftest and os.path.exists(vanilla_path)) else new
        users = [tid for tid, r in imp["tilesets"].items() if import_blocks(r) == ref]
        if not users:
            notes.append(f"{fn}: no imported tileset matches its vanilla blocks")
            continue
        for tid in users:
            old = import_blocks(imp["tilesets"][tid])
            diff = {i + 1: new[i] for i in range(min(len(old), len(new))) if old[i] != new[i]}
            if diff:
                block_defs[tid] = diff

    # ---- walkable tiles: match each collision list to tilesets by vanilla content
    pink_coll = parse_collision(root)
    van_coll = parse_collision(root.replace("pokepink", "pokeyellow")) if not selftest else pink_coll
    walkable = {}
    for label, new in pink_coll.items():
        ref = van_coll.get(label, new)
        users = [tid for tid, r in imp["tilesets"].items() if sorted(r["walkable"] or []) == ref]
        if new != ref:
            if not users:
                notes.append(f"collision {label}: no imported tileset matches")
            for tid in users:
                walkable[tid] = new
        elif selftest and not users:
            notes.append(f"collision {label}: no imported tileset matches (selftest)")

    # ---- cut trees: new pairs only (field lists append)
    have = {(r["before"], r["after"]) for r in imp["cutTreeSwaps"]}
    cut = [{"before": a, "after": b} for a, b in parse_cut(root) if (a, b) not in have]

    # ---- dungeon transition maps: additions only (field lists append)
    singles, ranges = parse_dungeon(root)
    d = imp["dungeon"]
    have_maps = set(d.get("maps", []))
    have_ranges = {(r["first"], r["last"]) for r in d.get("ranges", [])}
    dungeon = {"maps": [m for m in singles if m not in have_maps],
               "ranges": [{"first": a, "last": b} for a, b in ranges if (a, b) not in have_ranges]}

    # ---- warps: whole warp list for any map whose list differs
    # Only maps whose warps Pink changed compared with vanilla pret (pret
    # keeps debug warps the engine's import drops, e.g. Red's house 2F).
    warps = {}
    vanilla_root = root if selftest else root.replace("pokepink", "pokeyellow")
    vanilla_warps = parse_warps(vanilla_root)
    for label, wl in parse_warps(root).items():
        mid = by_label.get(label)
        if not mid:
            continue
        have = [{k: w[k] for k in ("x", "y", "destMap", "destWarp")} for w in (imp["maps"][mid].get("warps") or [])]
        if selftest:
            if wl != have and label != "RedsHouse2F":
                warps[mid] = wl
            continue
        if wl != vanilla_warps.get(label):
            if vanilla_warps.get(label) != have:
                notes.append(f"{mid}: vanilla pret warps differ from the import; check by hand")
            warps[mid] = wl

    # ---- in-game trades: the whole list (Pink rewrites every trade)
    trades = parse_trades(root)
    if not selftest:
        trades = [dict(t, give=SWAP.get(t["give"], t["give"]), get=SWAP.get(t["get"], t["get"])) for t in trades]
    have_trades = [{k: t[k] for k in ("give", "get", "dialogset", "nickname")} for t in imp["trades"]]
    trades_out = trades if trades != have_trades else None

    # ---- object sprites Pink changed (same object, new look).  Compared with
    # the pret commit Pink was built on; sprites Pink added (the gym leaders)
    # are pink_presentation's.
    object_sprites = {}
    if not selftest:
        base_root = root.replace("pokepink", "pinkbase")
        known = sprite_ids(base_root)
        old_objs = parse_object_sprites(base_root)
        for label, new in sorted(parse_object_sprites(root).items()):
            mid, old = by_label.get(label), old_objs.get(label)
            if not mid or old is None or len(old) != len(new):
                continue
            for i, (a, b) in enumerate(zip(old, new)):
                if a != b:
                    if b in known:
                        object_sprites.setdefault(mid, {})[i + 1] = b
                    else:
                        notes.append(f"{mid} object {i + 1}: {b} is new in Pink (pink_presentation)")

    if selftest:
        print("selftest: %d warp lists, trades %s" % (len(warps), "differ" if trades_out else "match"))
        for k in list(warps)[:5]: print("  warps", k, warps[k], imp["maps"][k].get("warps"))
        print("selftest: %d maps, %d tilesets' blocks, %d walkable lists, %d cut pairs, "
              "%d dungeon maps, %d dungeon ranges differ"
              % (len(blocks), len(block_defs), len(walkable), len(cut),
                 len(dungeon["maps"]), len(dungeon["ranges"])))
        for k in list(blocks)[:5]: print("  map", k, len(blocks[k]))
        for n in notes: print("  note", n)
        return

    with open(out_path, "w") as f:
        f.write("-- generated by gen_world_data.py from Pokemon Pink's disassembly; do not edit.\n")
        f.write("-- Only cells, blocks and lists that differ from vanilla Yellow are listed.\n")
        f.write("return " + json_to_lua({"blocks": blocks, "blockDefs": block_defs,
                                         "walkable": walkable, "cutTrees": cut,
                                         "dungeon": dungeon, "warps": warps,
                                         "trades": trades_out or [],
                                         "objectSprites": object_sprites}) + "\n")
    print("warps:", {k: len(v) for k, v in warps.items()}, "| trades:", len(trades_out or []),
          "| object sprites:", object_sprites)
    print("wrote %s: %d maps (%d cells), blocks in %s, walkable %s, %d cut pairs, "
          "%d dungeon maps + %d ranges"
          % (out_path, len(blocks), sum(len(v) for v in blocks.values()),
             {k: len(v) for k, v in block_defs.items()}, list(walkable),
             len(cut), len(dungeon["maps"]), len(dungeon["ranges"])))
    for n in notes:
        print("note:", n)


def json_to_lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            key = "[%d]" % k if isinstance(k, int) else (k if re.match(r"^[A-Za-z_]\w*$", k) else '["%s"]' % k)
            items.append("%s  %s = %s," % (pad, key, json_to_lua(v[k], ind + 1)))
        return "{\n" + "\n".join(items) + "\n" + pad + "}"
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(json_to_lua(x) for x in v) + " }"
        return "{\n" + "\n".join("%s  %s," % (pad, json_to_lua(x, ind + 1)) for x in v) + "\n" + pad + "}"
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


if __name__ == "__main__":
    main()
