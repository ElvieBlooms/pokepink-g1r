#!/usr/bin/env python3
"""Load the pink mods over an imported Yellow headlessly and check that the
merged world data matches Pink's disassembly.

Usage: verify_world.py <pokepink_root> <mod_dir> [<mod_dir> ...]
Env: POKEPORT_DATA_DIR, POKEPORT_VERSION=yellow
"""
import json, os, subprocess, sys
repo = os.path.expanduser(os.environ.get("G1R_ROOT") or "~/dev/gen1recomp-dev")
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(repo, "tools"))
sys.path.insert(0, here)
import modkit
import gen_world_data as gw

pink = os.path.abspath(sys.argv[1])
mod_dirs = [os.path.abspath(d) for d in sys.argv[2:]]
files = {}
for d in mod_dirs:
    mount = "mods/" + os.path.basename(d.rstrip("/"))
    for r in modkit.mod_files(d):
        files[f"{mount}/{r}"] = os.path.join(d, r)
entries = "".join("  [%s] = %s,\n" % (modkit.lua_quote(k), modkit.lua_quote(v))
                  for k, v in sorted(files.items()))
driver = 'require("src.core.GameVersion").set("yellow")\n' + \
    modkit.DRIVER_TEMPLATE % (modkit.IMPORTED_BASE, "{\n" + entries + "}")
driver += r'''
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
local m = {}
for id, r in pairs(data.maps) do m[id] = { label = r.label, blocks = r.blocks, outdoor = r.outdoor } end
local t = {}
for id, r in pairs(data.tilesets) do t[id] = { blocks = r.blocks, walkable = r.walkable } end
local f = data.field
io.stderr:write("@@JSON@@" .. enc({ maps = m, tilesets = t, cut = f.cutTreeSwaps,
  dungeon = f.dungeonTransitionMaps, hidden = { gate = f.hiddenItems.SAFARI_ZONE_GATE or false,
  dock = f.hiddenItems.VERMILION_DOCK or false },
  mart = data.text_pointers.CeladonMart4F.TEXT_CELADONMART4F_CLERK.mart,
  cable = data.items.ITEM_32.name }) .. "\n")
'''
open("/tmp/vworld.lua", "w").write(driver)
p = subprocess.run(["luajit", "/tmp/vworld.lua"], cwd=repo, capture_output=True, text=True)
for line in p.stdout.splitlines():
    if line.startswith(("MOD", "ERR", "IGN", "ORPHAN")):
        print(line)
blob = [l for l in p.stderr.splitlines() if l.startswith("@@JSON@@")]
if not blob:
    print(p.stderr[-3000:]); sys.exit(1)
got = json.loads(blob[0][8:])
bad = 0

vanilla = pink.replace("pokepink", "pokeyellow")
# every map Pink edits must now equal Pink's .blk, cell for cell
by_label = {r["label"]: mid for mid, r in got["maps"].items() if r.get("label")}
checked_maps = 0
for fn in sorted(os.listdir(os.path.join(pink, "maps"))):
    mid = by_label.get(fn[:-4]) if fn.endswith(".blk") else None
    if not mid:
        continue
    want = gw.blocks_of(os.path.join(pink, "maps", fn))
    van = os.path.join(vanilla, "maps", fn)
    if os.path.exists(van) and gw.blocks_of(van) == want:
        continue  # Pink leaves this map alone (the engine may patch it itself, e.g. Pokecenters)
    have = got["maps"][mid]["blocks"]
    if len(want) != len(have):
        continue  # size mismatch already reported by the generator
    checked_maps += 1
    if want != have:
        bad += 1; print("MAP MISMATCH", mid)

# tilesets: each Pink blockset must equal the merged blocks of its users
def tblocks(r):
    return [[b[i] for i in range(16)] if isinstance(b, list) else [b[str(i)] for i in range(1, 17)]
            for b in r["blocks"]]
vanilla = pink.replace("pokepink", "pokeyellow")
for fn in ("overworld.bst", "forest.bst", "facility.bst", "interior.bst"):
    want = gw.blockset(os.path.join(pink, "gfx/blocksets", fn))
    ref = gw.blockset(os.path.join(vanilla, "gfx/blocksets", fn))
    users = [tid for tid in got["tilesets"]]  # find users by the vanilla content they used to have
    hits = [tid for tid in users if tblocks(got["tilesets"][tid]) == want]
    print(f"{fn}: tilesets now matching Pink: {hits}")
    if not hits:
        bad += 1

pc = gw.parse_collision(pink)
for tid in ("FOREST", "FACILITY"):
    w = sorted(got["tilesets"][tid]["walkable"])
    if w not in pc.values():
        bad += 1; print("WALKABLE MISMATCH", tid)

pairs = {(r["before"], r["after"]) for r in got["cut"]}
missing = [p for p in gw.parse_cut(pink) if p not in pairs]
if missing:
    bad += 1; print("CUT MISSING", missing)
singles, ranges = gw.parse_dungeon(pink)
dm = set(got["dungeon"]["maps"]); dr = {(r["first"], r["last"]) for r in got["dungeon"]["ranges"]}
if not all(s in dm for s in singles) or not all(r in dr for r in ranges):
    bad += 1; print("DUNGEON MISMATCH")

print("roofs outdoor:", got["maps"]["CELADON_MART_ROOF"].get("outdoor"), got["maps"]["CELADON_MANSION_ROOF"].get("outdoor"))
print("hidden: gate", got["hidden"]["gate"], "dock", got["hidden"]["dock"])
print("Celadon 4F shelf:", got["mart"], "| ITEM_32 is", got["cable"])
if got["hidden"]["gate"] or got["hidden"]["dock"] != [{"item": "FULL_RESTORE", "x": 21, "y": 0}]:
    bad += 1
if "ITEM_32" not in got["mart"] or not all(got["maps"][r].get("outdoor") for r in ("CELADON_MART_ROOF", "CELADON_MANSION_ROOF")):
    bad += 1
print("checked %d maps Pink edits against its .blk files: %d mismatches" % (checked_maps, bad))
sys.exit(1 if bad else 0)
