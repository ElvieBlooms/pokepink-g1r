#!/usr/bin/env python3
"""Generate pink_manga_events/challenger_data.lua from Pink's disassembly.

Usage: gen_challenger_data.py <pokepink_root> <out.lua>

Pink's six Busybody challenger scripts (scripts/<Map>.asm) share one
template.  This pulls, for each map:
  coords     the trigger cells, in order (dbmapcoord x, y)
  approach   the Busybody's path for each trigger cell (by cell index)
  exit       his path out after the battle
  party      the CHIEF party number (wTrainerNo)
  beatFlag   the EVENT_BEAT_..._CHIEF flag
  object     his object_event: x, y, facing
  text ids   Chief / WaitedHere / Defeated / Victory / GoodLuckToYou
and fails loudly if a script doesn't match the template.
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pret_text import load_labels

MAPS = {
    "PokemonMansion1F": "POKEMON_MANSION_1F",
    "SafariZoneWest": "SAFARI_ZONE_WEST",
    "CeladonMartRoof": "CELADON_MART_ROOF",
    "VictoryRoad3F": "VICTORY_ROAD_3F",
    "UndergroundPathNorthSouth": "UNDERGROUND_PATH_NORTH_SOUTH",
    "UndergroundPathWestEast": "UNDERGROUND_PATH_WEST_EAST",
}
DIRS = {"NPC_MOVEMENT_UP": "up", "NPC_MOVEMENT_DOWN": "down",
        "NPC_MOVEMENT_LEFT": "left", "NPC_MOVEMENT_RIGHT": "right"}


def strip(line):
    return line.split(";", 1)[0].strip()


def parse(root, label):
    lines = [strip(l) for l in open(os.path.join(root, "scripts", label + ".asm"))]
    text = "\n".join(lines)
    out = {"label": label}

    # trigger cells
    m = re.search(r"\.ChiefEncounterCoordinates:\n(.*?)\n\s*db -1", text, re.S)
    if not m:
        raise SystemExit(f"{label}: no .ChiefEncounterCoordinates")
    out["coords"] = [[int(a), int(b)] for a, b in re.findall(r"dbmapcoord\s+(\d+),\s*(\d+)", m.group(1))]

    # movement tables, in file order
    tables = {}
    for name, body in re.findall(r"\.(Chief\w+):\n(.*?)\n\s*db -1", text, re.S):
        tables[name] = [DIRS[d] for d in re.findall(r"db\s+(NPC_MOVEMENT_\w+)", body)]

    # approach dispatch: "cp N / jr z, .movementK" then ".movementK / ld de, .Table"
    approach_body = re.search(r"ApproachScript:\n(.*?)\n\.startmove", text, re.S)
    if not approach_body:
        raise SystemExit(f"{label}: no approach script")
    body = approach_body.group(1)
    default = re.search(r"ld de, \.(Chief\w+)\n\s*ld a, \[wCoordIndex\]", body)
    branch_of = dict(re.findall(r"cp (\d+)\n\s*jr z, \.(movement\d+)", body))
    table_of = dict(re.findall(r"\.(movement\d+)\n\s*ld de, \.(Chief\w+)", body))
    approach = {}
    for i in range(1, len(out["coords"]) + 1):
        br = next((b for c, b in branch_of.items() if int(c) == i), None)
        name = table_of[br] if br else default.group(1)
        approach[i] = tables[name]
    out["approach"] = approach

    # exit path: the table loaded in the after-battle script
    after = re.search(r"AfterBattleScript:\n(.*?)\n\w+ExitScript:", text, re.S)
    ex = re.search(r"ld de, \.(Chief\w+)", after.group(1)) if after else None
    if not ex:
        raise SystemExit(f"{label}: no exit movement")
    out["exit"] = tables[ex.group(1)]
    face = re.search(r"ld a, SPRITE_FACING_(\w+)\n\s*ldh \[hSpriteFacingDirection\]", after.group(1))
    out["faceAfter"] = face.group(1).lower() if face else None
    pdir = re.search(r"ld a, PLAYER_DIR_(\w+)\n\s*ld \[wPlayerMovingDirection\]", after.group(1))
    out["playerFaceAfter"] = pdir.group(1).lower() if pdir else None

    # the player's forced step when he appears
    step = re.search(r"ld a, PAD_(UP|DOWN|LEFT|RIGHT)\n\s*ld \[wSimulatedJoypadStatesEnd\]", text)
    out["playerStep"] = step.group(1).lower() if step else None

    # battle
    pm = re.search(r"ld a, OPP_CHIEF\n\s*ld \[wCurOpponent\], a\n\s*ld a, (\d+)", text)
    if not pm:
        raise SystemExit(f"{label}: no OPP_CHIEF party")
    out["party"] = int(pm.group(1))
    # either "CheckEvent F / jp nz, CheckFightingMapTrainers" or
    # "CheckEvent F / call z, <Map>Script_Challenger"
    bf = re.search(r"CheckEvent (EVENT_BEAT_\w*CHIEF\w*)", text)
    if not bf:
        raise SystemExit(f"{label}: no beat flag")
    out["beatFlag"] = bf.group(1)

    # the Trashed House Busybody this challenger's exit script shows
    shown = re.findall(r"ld a, TOGGLE_CERULEANTRASHEDHOUSE_CHIEF_(\d)\n\s*ld \[wToggleableObjectIndex\], a\n\s*predef ShowObject", text)
    if len(shown) != 1:
        raise SystemExit(f"{label}: expected one Trashed House Busybody shown, got {shown}")
    out["houseShows"] = int(shown[0])

    # music
    mu = re.search(r"ld a, (MUSIC_\w+)\n\s*call PlayMusic", text)
    out["music"] = mu.group(1) if mu else None

    # object
    obj_text = open(os.path.join(root, "data/maps/objects", label + ".asm")).read()
    om = re.search(r"object_event\s+(\d+),\s*(\d+),\s*SPRITE_CHIEF,\s*(\w+),\s*(\w+),\s*(TEXT_\w+)", obj_text)
    if not om:
        raise SystemExit(f"{label}: no SPRITE_CHIEF object")
    out["object"] = {"x": int(om.group(1)), "y": int(om.group(2)),
                     "movement": om.group(3), "facing": om.group(4).lower(), "text": om.group(5)}

    # text labels Pink defines for this map
    stem = label
    out["text"] = {k: f"_{stem}Chief{k}Text" for k in ("", "WaitedHere", "Defeated", "Victory", "GoodLuckToYou")}
    out["text"]["Intro"] = out["text"].pop("")
    return out


def lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            key = "[%d]" % k if isinstance(k, int) else (k if re.match(r"^[A-Za-z_]\w*$", k) else '["%s"]' % k)
            items.append("%s  %s = %s," % (pad, key, lua(v[k], ind + 1)))
        return "{\n" + "\n".join(items) + "\n" + pad + "}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(lua(x) for x in v) + " }"
        return "{ " + ", ".join(lua(x, ind + 1) for x in v) + " }"
    if isinstance(v, str):
        return '"%s"' % v
    if v is None:
        return "nil"
    return str(v)


ALL_TEXT = {}


def main():
    root, out_path = sys.argv[1], sys.argv[2]
    tdir = os.path.join(root, "text")
    for fn in os.listdir(tdir):
        if fn.endswith(".asm"):
            ALL_TEXT[fn] = open(os.path.join(tdir, fn)).read()
    data = {}
    for label, mapid in MAPS.items():
        rec = parse(root, label)
        for k in rec["text"].values():
            if not any(re.search(r"^" + re.escape(k) + r"::", t, re.M) for t in ALL_TEXT.values()):
                raise SystemExit(f"{label}: text {k} not found")
        data[mapid] = rec
        print("%-29s cells %-2d party %-2d flag %-34s exit %-24s step %-5s obj (%d,%d) %s"
              % (mapid, len(rec["coords"]), rec["party"], rec["beatFlag"], ",".join(rec["exit"]),
                 rec["playerStep"], rec["object"]["x"], rec["object"]["y"], rec["object"]["facing"]))
    # Cerulean's Trashed House: seven CHIEF trainers on one tile, one shown at a time
    obj_text = open(os.path.join(root, "data/maps/objects/CeruleanTrashedHouse.asm")).read()
    house = []
    for x, y, facing, n, party in re.findall(
            r"object_event\s+(\d+),\s*(\d+),\s*SPRITE_CHIEF,\s*STAY,\s*(\w+),\s*TEXT_CERULEANTRASHEDHOUSE_CHIEF(\d),\s*OPP_CHIEF,\s*(\d+)", obj_text):
        house.append({"n": int(n), "x": int(x), "y": int(y), "facing": facing.lower(), "party": int(party)})
    script = open(os.path.join(root, "scripts/CeruleanTrashedHouse.asm")).read()
    for h in house:
        m = re.search(r"trainer (EVENT_BEAT_CERULEANTRASHEDHOUSE_TRAINER_%d), (\d+), CeruleanTrashedHouseChief%dBattleText" % (h["n"] - 1, h["n"]), script)
        if not m:
            raise SystemExit("Trashed House Busybody %d: no trainer header" % h["n"])
        h["event"], h["range"] = m.group(1), int(m.group(2))
        h["text"] = {k: "_CeruleanTrashedHouseChief%d%sText" % (h["n"], k) for k in ("Battle", "EndBattle", "AfterBattle")}
    if len(house) != 7:
        raise SystemExit("expected seven Trashed House Busybodies, got %d" % len(house))
    for mapid, rec in data.items():
        if rec["houseShows"] != rec["party"]:
            print("note: %s shows house Busybody %d (its party is %d)" % (mapid, rec["houseShows"], rec["party"]))
    champ = open(os.path.join(root, "scripts/ChampionsRoom.asm")).read()
    champ_shows = re.findall(r"TOGGLE_CERULEANTRASHEDHOUSE_CHIEF_(\d)\n\s*ld \[wToggleableObjectIndex\], a\n\s*predef ShowObject", champ)
    if champ_shows != ["7"]:
        raise SystemExit("Champion's Room shows %s, expected house Busybody 7" % champ_shows)
    print("house:", [(h["n"], h["party"], h["event"], h["range"]) for h in house], "| Champion shows 7")

    # Pink's lines for these encounters (Pokemon Pink by jcferggy)
    labels = load_labels(root)
    strings = {}
    for h in house:
        for k in h["text"].values():
            if k not in labels:
                raise SystemExit(f"text {k} isn't plain text the converter handles")
            strings[k] = labels[k]
    for rec in data.values():
        for k in rec["text"].values():
            if k not in labels:
                raise SystemExit(f"text {k} isn't plain text the converter handles")
            strings[k] = labels[k]
    odd = {k: v for k, v in strings.items() if "{RAM:" in v}
    if odd:
        print("note: lines with RAM placeholders:", list(odd))

    def lua_str(v):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") \
                      .replace("\f", "\\f").replace("\x0b", "\\v") + '"'

    with open(out_path, "w") as f:
        f.write("-- generated by gen_challenger_data.py from Pokemon Pink's scripts; do not edit.\n")
        f.write("-- Text is Pokemon Pink's, by jcferggy.\n")
        f.write("local strings = {\n")
        for k in sorted(strings):
            f.write("  %s = %s,\n" % (k, lua_str(strings[k])))
        f.write("}\n")
        f.write("return { maps = " + lua(data) + ", house = " + lua(house) + ", championShows = 7, text = strings }\n")
    print("lines:", len(strings))


if __name__ == "__main__":
    main()
