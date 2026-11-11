#!/usr/bin/env python3
"""Generate pink_encounters_trainers/data.lua from a pret-style disassembly.

Usage: gen_pink_data.py <disasm_root> <imported_generated_dir> <out.lua> [--selftest]

Parses data/wild/grass_water.asm (+ map files), data/wild/super_rod.asm,
data/trainers/parties.asm and data/trainers/special_moves.asm, applies the
Pink partner species swap, and writes ONLY the tables that differ from the
player's imported vanilla data (so no unchanged ROM data is shipped).

--selftest parses the given disassembly WITHOUT the swap and reports any
table that differs from the import (run it on vanilla pokeyellow: it must
report nothing, which proves the parser reads the formats correctly).
"""
import json, os, re, subprocess, sys

SWAP = {"PIKACHU": "CLEFAIRY", "CLEFAIRY": "PIKACHU",
        "RAICHU": "CLEFABLE", "CLEFABLE": "RAICHU"}

# Pink fights its rivals with one fixed party per encounter (no Eevee-based
# variants), but vanilla Yellow's scripts still pick a party by the rival's
# Eevee outcome.  Expand Pink's parties into vanilla's index space so every
# vanilla index lands on Pink's team for that encounter.
#   RIVAL2: 1 SS Anne | 2-4 Pokemon Tower | 5-7 Silph Co. | 8-10 Route 22
#   RIVAL3: 1-3 Champion
PARTY_REMAP = {"RIVAL2": [1, 2, 2, 2, 3, 3, 3, 4, 4, 4], "RIVAL3": [1, 1, 1]}

def strip(line):
    return line.split(";", 1)[0].strip()

def db_args(line):
    m = re.match(r"db\s+(.*)$", line)
    if not m:
        return None
    return [a.strip() for a in m.group(1).split(",") if a.strip()]

def num(tok):
    tok = tok.strip()
    if tok.startswith("$"):
        return int(tok[1:], 16)
    return int(tok)

# ---------------------------------------------------------------- wild
def parse_map_consts(root):
    names = []
    for line in open(os.path.join(root, "constants/map_constants.asm")):
        m = re.match(r"\s*map_const\s+(\w+)\s*,", line)
        if m:
            names.append(m.group(1))
    return names

def parse_wild(root):
    # WildDataPointers has one dw per map id, in map-constant order
    consts = parse_map_consts(root)
    ptrs = []
    for line in open(os.path.join(root, "data/wild/grass_water.asm")):
        m = re.match(r"\s*dw\s+(\w+)", line)
        if m:
            ptrs.append(m.group(1))
    order = list(zip(ptrs, consts))
    labels = {}
    mapdir = os.path.join(root, "data/wild/maps")
    for fn in sorted(os.listdir(mapdir)):
        cur, kind, tab = None, None, None
        for raw in open(os.path.join(mapdir, fn)):
            line = strip(raw)
            if not line:
                continue
            m = re.match(r"(\w+):", line)
            if m:
                cur = m.group(1)
                labels[cur] = {}
                continue
            m = re.match(r"def_(grass|water)_wildmons\s+(\S+)", line)
            if m:
                kind = m.group(1)
                tab = {"rate": num(m.group(2)), "slots": []}
                labels[cur][kind] = tab
                continue
            if line.startswith("end_"):
                kind, tab = None, None
                continue
            a = db_args(line)
            if a and tab is not None:
                tab["slots"].append({"level": num(a[0]), "species": a[1]})
    out = {}
    for label, mapid in order:
        if label == "NothingWildMons" or mapid.startswith("UNUSED"):
            continue
        rec = labels.get(label)
        if rec is None:
            raise SystemExit("missing wild label " + label)
        out[mapid] = rec
    return out

def parse_super_rod(root):
    out = {}
    for raw in open(os.path.join(root, "data/wild/super_rod.asm")):
        a = db_args(strip(raw))
        if not a or len(a) < 3:
            continue
        mapid, rest = a[0], a[1:]
        out[mapid] = [{"species": rest[i], "level": num(rest[i + 1])}
                      for i in range(0, len(rest), 2)]
    return out

# ---------------------------------------------------------------- trainers
def parse_classes(root):
    names = []
    for line in open(os.path.join(root, "constants/trainer_constants.asm")):
        m = re.match(r"\s*trainer_const\s+(\w+)", line)
        if m:
            names.append(m.group(1))
    return names  # index 0 = NOBODY

def parse_parties(root):
    lines = open(os.path.join(root, "data/trainers/parties.asm")).read().splitlines()
    pointers, labels, cur = [], {}, None
    for raw in lines:
        line = strip(raw)
        if not line:
            continue
        m = re.match(r"dw\s+(\w+)", line)
        if m and cur is None:
            pointers.append(m.group(1))
            continue
        m = re.match(r"(\w+):$", line)
        if m:
            cur = m.group(1)
            if cur != "TrainerDataPointers":
                labels[cur] = []
            else:
                cur = None
            continue
        a = db_args(line)
        if a is None or cur is None:
            continue
        if a[-1] != "0":
            raise SystemExit("party line without terminator: " + raw)
        a = a[:-1]
        party = []
        if a[0] in ("$FF", "-1"):
            rest = a[1:]
            for i in range(0, len(rest), 2):
                party.append({"level": num(rest[i]), "species": rest[i + 1]})
        else:
            lvl = num(a[0])
            party = [{"level": lvl, "species": s} for s in a[1:]]
        labels[cur].append(party)
    return pointers, labels

def parse_special(root, warnings):
    out = {}  # class -> party -> [ {mon, slot, move} ]
    cur = None
    for n, raw in enumerate(open(os.path.join(root, "data/trainers/special_moves.asm")), 1):
        line = strip(raw)
        if not line or line.endswith(":"):
            if line.endswith(":") and line != "SpecialTrainerMoves:" :
                warnings.append("special_moves.asm:%d: label %s with no 'db CLASS, id' header; "
                                "its rows are skipped (the ROM reads them as noise)" % (n, line))
                cur = "SKIP"
            continue
        a = db_args(line)
        if a is None:
            continue
        if a == ["-1"] or a == ["$FF"]:
            break
        if cur is None:
            cur = (a[0], num(a[1]))
            out.setdefault(cur[0], {}).setdefault(cur[1], [])
            continue
        if a == ["0"]:
            cur = None
            continue
        if cur == "SKIP":
            continue
        out[cur[0]][cur[1]].append({"mon": num(a[0]), "slot": num(a[1]), "move": a[2]})
    return out

# ---------------------------------------------------------------- import
def load_import(gen_dir):
    script = r'''
local dir = arg[1]
local function enc(v)
  local t = type(v)
  if t == "table" then
    local n = #v
    local isList = n > 0 or next(v) == nil
    if isList then
      for k in pairs(v) do if type(k) ~= "number" then isList = false break end end
    end
    local parts = {}
    if isList then
      for i = 1, n do parts[#parts+1] = enc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, x in pairs(v) do
      if type(x) ~= "function" then
        parts[#parts+1] = string.format("%q", tostring(k)) .. ":" .. enc(x)
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" or t == "boolean" then return tostring(v)
  else return "null" end
end
local e = dofile(dir .. "/encounters.lua")
local f = dofile(dir .. "/field.lua")
local tr = dofile(dir .. "/trainers.lua")
local slim = {}
for id, r in pairs(tr) do slim[id] = { parties = r.parties, specialMoves = r.specialMoves } end
io.write(enc({ encounters = e, superRod = f.superRod, trainers = slim }))
'''
    p = subprocess.run(["luajit", "-e", script.replace("arg[1]", repr(gen_dir))],
                       capture_output=True, text=True)
    if p.returncode:
        raise SystemExit(p.stderr)
    return json.loads(p.stdout)

# ---------------------------------------------------------------- compare
def swap_species(obj, enabled):
    if not enabled:
        return obj
    if isinstance(obj, list):
        return [swap_species(x, True) for x in obj]
    if isinstance(obj, dict):
        return {k: (SWAP.get(v, v) if k == "species" else swap_species(v, True))
                for k, v in obj.items()}
    return obj

def norm_table(t):
    if not t:
        return None
    if t.get("rate", 0) == 0 and not t.get("slots"):
        return None
    return {"rate": t["rate"], "slots": [{"level": s["level"], "species": s["species"]}
                                         for s in t.get("slots", [])]}

def norm_special(rows_by_party):
    """import shape {party, moves:[{mon,move,slot}]} list -> {party: rows}"""
    out = {}
    for entry in rows_by_party or []:
        out[int(entry["party"])] = [{"mon": r["mon"], "slot": r["slot"], "move": r["move"]}
                                    for r in entry["moves"]]
    return out

def main():
    root, gen_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    selftest = "--selftest" in sys.argv
    do_swap = not selftest
    warnings = []
    imp = load_import(gen_dir)

    wild = swap_species(parse_wild(root), do_swap)
    rod = swap_species(parse_super_rod(root), do_swap)
    classes = parse_classes(root)
    pointers, labels = parse_parties(root)
    special = parse_special(root, warnings)

    enc_out, rod_out, tr_out, sp_out = {}, {}, {}, {}

    for mapid, rec in sorted(wild.items()):
        vanilla = imp["encounters"].get(mapid, {})
        diff = {}
        for kind in ("grass", "water"):
            a, b = norm_table(rec.get(kind)), norm_table(vanilla.get(kind))
            if a != b:
                diff[kind] = a if a else {"rate": 0, "slots": []}
        if diff:
            enc_out[mapid] = diff

    for mapid, slots in sorted(rod.items()):
        v = [{"level": s["level"], "species": s["species"]}
             for s in imp["superRod"].get(mapid, [])]
        if slots != v:
            rod_out[mapid] = slots

    for i, label in enumerate(pointers):
        cls = classes[i + 1]
        opp = "OPP_" + cls
        if opp not in imp["trainers"]:
            warnings.append("class %s not in the import; skipped" % opp)
            continue
        if not labels[label]:
            continue  # an empty class (CHIEF); the ROM has nothing to replace
        parties = swap_species(labels[label], do_swap)
        psp_raw = {int(k): v for k, v in special.get(cls, {}).items()}
        if cls in PARTY_REMAP and not selftest:
            remap = PARTY_REMAP[cls]
            parties = [parties[i - 1] for i in remap]
            psp_raw = {new: psp_raw[old] for new, old in enumerate(remap, 1) if old in psp_raw}
        vanilla = [[{"level": m["level"], "species": m["species"]} for m in p]
                   for p in imp["trainers"][opp]["parties"]]
        vsp = norm_special(imp["trainers"][opp].get("specialMoves"))
        psp = psp_raw
        if parties != vanilla:
            tr_out[opp] = parties
        if psp != vsp or parties != vanilla:
            # parties whose moves must be rebuilt at load time: any with pink
            # or vanilla special rows, when the class changed at all
            touched = sorted(set(psp) | set(vsp))
            entry = {}
            for p in touched:
                if p > len(parties):
                    warnings.append("%s party %d has special moves but no such party" % (opp, p))
                    continue
                slots = sorted({r["mon"] for r in psp.get(p, []) + vsp.get(p, [])
                                if 1 <= r["mon"] <= len(parties[p - 1])})
                bad = [r for r in psp.get(p, []) if not 1 <= r["mon"] <= len(parties[p - 1])]
                for r in bad:
                    warnings.append("%s party %d special move %s targets mon %d (party has %d)"
                                    % (opp, p, r["move"], r["mon"], len(parties[p - 1])))
                if slots:
                    entry[p] = {"slots": slots, "rows": [r for r in psp.get(p, []) if r not in bad]}
            if entry:
                sp_out[opp] = entry

    if selftest:
        print("selftest:", len(enc_out), "encounter maps,", len(rod_out), "super rod maps,",
              len(tr_out), "trainer classes,", len(sp_out), "special-move classes differ")
        for k in list(enc_out)[:10]: print("  enc", k, json.dumps(enc_out[k])[:200])
        for k in list(rod_out)[:10]: print("  rod", k, rod_out[k], imp["superRod"].get(k))
        for k in list(tr_out)[:10]: print("  tr", k)
        for k in list(sp_out)[:10]: print("  sp", k, sp_out[k])
        for w in warnings: print("  warn", w)
        return

    with open(out_path, "w") as f:
        f.write("-- generated by gen_pink_data.py from Pokemon Pink's disassembly; do not edit.\n")
        f.write("-- Only tables that differ from vanilla Yellow are listed. Species ids are\n")
        f.write("-- the pink_partner slots (internal PIKACHU = Clefairy, and so on).\n")
        f.write("return " + to_lua({"encounters": enc_out, "superRod": rod_out,
                                    "trainers": tr_out, "special": sp_out}) + "\n")
    print("wrote", out_path, ":", len(enc_out), "encounter maps,", len(rod_out),
          "super rod maps,", len(tr_out), "trainer classes,", len(sp_out), "special-move classes")
    for w in warnings:
        print("warn:", w)

def to_lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            key = "[%d]" % k if isinstance(k, int) else (k if re.match(r"^[A-Za-z_]\w*$", k) else '["%s"]' % k)
            items.append("%s  %s = %s," % (pad, key, to_lua(v[k], ind + 1)))
        return "{\n" + "\n".join(items) + "\n" + pad + "}"
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(isinstance(x, dict) and len(x) <= 3 and all(not isinstance(y, (dict, list)) for y in x.values()) for x in v):
            return "{\n" + "\n".join("%s  %s," % (pad, inline(x)) for x in v) + "\n" + pad + "}"
        return "{\n" + "\n".join("%s  %s," % (pad, to_lua(x, ind + 1)) for x in v) + "\n" + pad + "}"
    if isinstance(v, str):
        return '"%s"' % v
    return str(v)

def inline(d):
    return "{ " + ", ".join("%s = %s" % (k, to_lua(d[k])) for k in sorted(d)) + " }"

if __name__ == "__main__":
    main()
