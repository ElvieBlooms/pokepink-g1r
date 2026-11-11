#!/usr/bin/env python3
"""Load pink mods over the imported Yellow data headlessly and compare the
merged encounters / super rod / trainer parties with Pink's disassembly.

Usage: verify_pink.py <pokepink_root> <mod_dir> [<mod_dir> ...]
Env: POKEPORT_DATA_DIR, POKEPORT_VERSION=yellow
"""
import json, os, subprocess, sys
repo = os.path.expanduser("~/dev/gen1recomp-dev")
sys.path.insert(0, os.path.join(repo, "tools"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modkit
import gen_pink_data as g

pink_root = os.path.abspath(sys.argv[1])
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
local tr = {}
for id, r in pairs(data.trainers) do tr[id] = { parties = r.parties } end
local mons = {}
for id, r in pairs(data.pokemon) do
  mons[id] = { baseStats = r.baseStats, types = r.types, catchRate = r.catchRate, baseExp = r.baseExp,
    level1Moves = r.level1Moves, growthRate = r.growthRate, tmhm = r.tmhm,
    evolutions = r.evolutions, learnset = r.learnset, name = r.name }
end
local cable = data.items.ITEM_32
local eff = cable and cable.effect and data.item_effects and data.item_effects[cable.effect]
io.stderr:write("@@JSON@@" .. enc({ encounters = data.encounters, superRod = data.field.superRod, trainers = tr,
  pokemon = mons, cable = { name = cable and cable.name, price = cable and cable.price,
  effect = cable and cable.effect, hasUse = eff and type(eff.use) == "function" or false } }) .. "\n")
'''
open("/tmp/vpink.lua", "w").write(driver)
p = subprocess.run(["luajit", "/tmp/vpink.lua"], cwd=repo, capture_output=True, text=True)
for line in p.stdout.splitlines():
    if line.startswith(("MOD", "ERR", "WARN", "IGN", "ORPHAN")):
        print(line)
blob = [l for l in p.stderr.splitlines() if l.startswith("@@JSON@@")]
if not blob:
    print(p.stderr[-3000:]); sys.exit(1)
merged = json.loads(blob[0][8:])

# expected = Pink, swapped and remapped exactly as the generator does
wild = g.swap_species(g.parse_wild(pink_root), True)
rod = g.swap_species(g.parse_super_rod(pink_root), True)
classes = g.parse_classes(pink_root)
pointers, labels = g.parse_parties(pink_root)
bad = 0
for mapid, rec in wild.items():
    got = merged["encounters"].get(mapid, {})
    for kind in ("grass", "water"):
        if g.norm_table(rec.get(kind)) != g.norm_table(got.get(kind)):
            bad += 1; print("ENC MISMATCH", mapid, kind)
for mapid, slots in rod.items():
    got = [{"level": s["level"], "species": s["species"]} for s in merged["superRod"].get(mapid, [])]
    if got != slots:
        bad += 1; print("ROD MISMATCH", mapid)
checked = 0
for i, label in enumerate(pointers):
    cls = classes[i + 1]
    if not labels[label]:
        continue
    want = g.swap_species(labels[label], True)
    if cls in g.PARTY_REMAP:
        want = [want[k - 1] for k in g.PARTY_REMAP[cls]]
    got = [[{"level": m["level"], "species": m["species"]} for m in party]
           for party in merged["trainers"]["OPP_" + cls]["parties"]]
    checked += 1
    if got != want:
        bad += 1; print("TRAINER MISMATCH", cls)
# species: the slot carrying species S must hold Pink's data for S
pink_mons = g.parse_species(pink_root)
for species, rec in pink_mons.items():
    want = g.norm_species(rec)
    want["evolutions"] = [dict(e, species=g.SWAP.get(e["species"], e["species"])) for e in want["evolutions"]]
    slot = g.SWAP.get(species, species)
    got = merged["pokemon"].get(slot)
    if not got:
        bad += 1; print("SPECIES MISSING", slot); continue
    if got.get("name") != species.replace("_", " ").replace("NIDORAN M", "NIDORAN♂").replace("NIDORAN F", "NIDORAN♀") \
            and slot in g.SWAP:
        print("  note: slot", slot, "is named", got.get("name"))
    gotn = g.norm_species(got)
    for k in g.SPECIES_FIELDS:
        if gotn[k] != want[k]:
            bad += 1; print("SPECIES MISMATCH", slot, "(carries %s)" % species, k)
print("cable:", merged["cable"])
print("checked %d wild maps, %d super rod maps, %d trainer classes, %d species: %d mismatches"
      % (len(wild), len(rod), checked, len(pink_mons), bad))

# show the hand-picked movesets that were built, for a spot check
for opp in ["OPP_MISTY", "OPP_RIVAL3", "OPP_AGATHA"]:
    for pi, party in enumerate(merged["trainers"][opp]["parties"][:1], 1):
        print(opp, "party", pi, "; ".join("%s L%d %s" % (m["species"], m["level"], "/".join(m.get("moves") or ["(default)"]))
                                          for m in party))
sys.exit(1 if bad else 0)
