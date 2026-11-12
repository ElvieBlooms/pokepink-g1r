#!/usr/bin/env python3
"""Generate pink_palettes/palette_data.lua from a pret-style disassembly.

Usage: gen_palette_data.py <disasm_root> <imported_generated_dir> <out.lua> [--selftest]

Reads data/sgb/sgb_palettes.asm (SuperPalettes and CGBBasePalettes),
constants/palette_constants.asm and data/pokemon/palettes.asm, compares them
with the player's imported palettes and writes only what differs:
  sgb, cgb   palette name -> { {r,g,b} x4 }   (changed or new palettes)
  order      names appended after the import's order (new palettes)
  species    species slot -> palette name     (changed assignments)
--selftest runs on vanilla pokeyellow and must report no differences.
"""
import json, os, re, subprocess, sys

SWAP = {"PIKACHU": "CLEFAIRY", "CLEFAIRY": "PIKACHU", "RAICHU": "CLEFABLE", "CLEFABLE": "RAICHU"}


def load_import(gen_dir):
    script = r'''
local p = dofile(DIR .. "/palettes.lua")
local function enc(v)
  if type(v) == "table" then
    local n, isList = #v, true
    for k in pairs(v) do if type(k) ~= "number" then isList = false break end end
    local parts = {}
    if isList and (n > 0 or next(v) == nil) then
      for i = 1, n do parts[#parts+1] = enc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, x in pairs(v) do parts[#parts+1] = string.format("%q", tostring(k)) .. ":" .. enc(x) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif type(v) == "string" then return string.format("%q", v)
  else return tostring(v) end
end
io.write(enc({ palettes = p.palettes, cgbBase = p.cgbBase, order = p.order, pokemon = p.pokemon }))
'''.replace("DIR", repr(gen_dir))
    p = subprocess.run(["luajit", "-e", script], capture_output=True, text=True)
    if p.returncode:
        raise SystemExit(p.stderr)
    return json.loads(p.stdout)


def palette_names(root):
    names = []
    for line in open(os.path.join(root, "constants/palette_constants.asm")):
        m = re.match(r"\s*const\s+PAL_(\w+)", line)
        if m:
            names.append(m.group(1))
    return names


def to255(v):
    return int(v * 255 / 31 + 0.5)  # the importer's 5-bit -> 8-bit rounding (checked by --selftest)


def parse_tables(root):
    tables, cur = {}, None
    for raw in open(os.path.join(root, "data/sgb/sgb_palettes.asm")):
        line = raw.split(";", 1)[0].strip()
        m = re.match(r"(\w+):", line)
        if m:
            cur = m.group(1)
            tables[cur] = []
            continue
        m = re.match(r"RGB\s+(.*)$", line)
        if m and cur:
            vals = [int(x) for x in m.group(1).split(",")]
            tables[cur].append([[to255(vals[i]), to255(vals[i + 1]), to255(vals[i + 2])]
                                for i in range(0, 12, 3)])
    return tables


def parse_species(root):
    out = []
    # data/pokemon/palettes.asm is in dex order after a MissingNo entry
    for raw in open(os.path.join(root, "data/pokemon/palettes.asm")):
        line = raw.split(";", 1)[0].strip()
        m = re.match(r"db\s+PAL_(\w+)", line)
        if m:
            out.append(m.group(1))
    return out  # index 0 = MissingNo, then dex 1..151


def main():
    root, gen_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    selftest = "--selftest" in sys.argv
    imp = load_import(gen_dir)
    names = palette_names(root)
    tables = parse_tables(root)
    sgb_rows, cgb_rows = tables["SuperPalettes"], tables["CGBBasePalettes"]
    notes = []

    def norm(c):  # import colours: list of 4 {r,g,b} (lists after JSON)
        return [[x[0], x[1], x[2]] if isinstance(x, list) else [x["1"], x["2"], x["3"]] for x in c]

    sgb, cgb = {}, {}
    for i, name in enumerate(names):
        if i < len(sgb_rows):
            have = imp["palettes"].get(name)
            if have is None or norm(have) != sgb_rows[i]:
                sgb[name] = sgb_rows[i]
        if i < len(cgb_rows):
            have = imp["cgbBase"].get(name)
            if have is None or norm(have) != cgb_rows[i]:
                cgb[name] = cgb_rows[i]
    order = [n for n in names if n not in imp["order"]]

    # species palettes, by dex number -> the import's species ids
    dex_to_species = {}
    pk = imp["pokemon"]
    p = subprocess.run(["luajit", "-e",
        'local t=dofile(%r) for id,r in pairs(t) do if r.dex then print(r.dex, id) end end' % (gen_dir + "/pokemon.lua")],
        capture_output=True, text=True)
    for line in p.stdout.split("\n"):
        if line.strip():
            d, sid = line.split()
            dex_to_species[int(d)] = sid
    species = {}
    pals = parse_species(root)
    for dex in range(1, len(pals)):
        sid = dex_to_species.get(dex)
        if not sid:
            continue
        slot = sid if selftest else SWAP.get(sid, sid)
        if pals[dex] != pk.get(slot if selftest else sid):
            species[slot] = pals[dex]

    if selftest:
        print("selftest: %d sgb, %d cgb palettes, %d new names, %d species differ"
              % (len(sgb), len(cgb), len(order), len(species)))
        for k in list(sgb)[:4]: print("  sgb", k, sgb[k], imp["palettes"].get(k))
        for k in list(cgb)[:4]: print("  cgb", k, cgb[k], imp["cgbBase"].get(k))
        for k in list(species)[:6]: print("  species", k, species[k], pk.get(k))
        return

    def lua_pal(rows):
        return "{ " + ", ".join("{ %d, %d, %d }" % tuple(c) for c in rows) + " }"

    with open(out_path, "w") as f:
        f.write("-- generated by gen_palette_data.py from Pokemon Pink's disassembly; do not edit.\n")
        f.write("-- Only palettes and assignments that differ from vanilla Yellow are listed.\n")
        f.write("return {\n  sgb = {\n")
        for k in sorted(sgb):
            f.write("    %s = %s,\n" % (k if re.match(r"^[A-Za-z_]\w*$", k) else '["%s"]' % k, lua_pal(sgb[k])))
        f.write("  },\n  cgb = {\n")
        for k in sorted(cgb):
            f.write("    %s = %s,\n" % (k if re.match(r"^[A-Za-z_]\w*$", k) else '["%s"]' % k, lua_pal(cgb[k])))
        f.write("  },\n  order = { %s },\n" % ", ".join('"%s"' % n for n in order))
        f.write("  species = {\n")
        for k in sorted(species):
            f.write('    %s = "%s",\n' % (k, species[k]))
        f.write("  },\n}\n")
    print("wrote %s: %d sgb palettes %s, %d cgb, new %s, species %s"
          % (out_path, len(sgb), sorted(sgb), len(cgb), order, species))


if __name__ == "__main__":
    main()
