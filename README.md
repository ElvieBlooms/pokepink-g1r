# Pokémon Pink for Gen1Recomp

A port of **Pokémon Pink Version: Special Clefairy Edition**, jcferggy's
Pokémon Yellow romhack, to [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp),
rebuilt as a set of mods on top of your own Pokémon Yellow.

> **Status:** early work in progress. Not for distribution until the
> original author has given permission (see [CREDITS.md](CREDITS.md)).

No ROM, patch, disassembly or ROM-derived art is included. You import your own
Pokémon Yellow in Gen1Recomp, and these mods rebuild Pink's changes on top of it.

## Playing

The easiest way is the **Pokémon Pink cart** (`pokepink-cart`), which pins
every mod at one release and plays as its own game with its own saves.

To install the mods by hand instead, get every `pink_*-X.Y.Z.zip` from the
same release, then **MODS > Import mod .zip** each one on Yellow and enable them all.

## The mods

| Mod | What it does | Status |
|---|---|---|
| `pink_partner` | Clefairy is your partner instead of Pikachu (species-slot swap, follower, cry) | prototype |
| `pink_encounters_trainers` | Pink's wild Pokémon, Super Rod tables and trainer teams | done, needs playtest |
| `pink_species` | Clefairy's and Clefable's learnsets, Surf/Swift, the Linking Cable | done, needs playtest |
| `pink_world_tweaks` | map edits, new Cut trees, Mansion ledges, rooftop Fly, Linking Cable in the Celadon mart, Vermilion Dock item | done, needs playtest |
| `pink_tilesets` | Pink's tile art: Red/Blue tiles built from the player's own Red/Blue import, Pink's own tiles shipped with credit | done, needs playtest |
| `pink_palettes` | Pink's recoloured palettes, the new cave and grey palettes, split Geodude/Cubone/Jynx palettes | done, needs playtest |
| `pink_manga_events` | Trainers Blue and Yellow, Busybody rematches, Imposter, surfing beach, VC Mew in place of Mewtwo | planned |
| `pink_presentation` | title screen, intro, SGB borders, slots, emotion portraits | planned, waiting on art permissions |

Every mod depends on `pink_partner`: the others refer to Clefairy and Pikachu
by their swapped internal IDs (see [docs/ROADMAP.md](docs/ROADMAP.md)).
Load order is `pink_partner`, `pink_species`, `pink_palettes`, `pink_world_tweaks`, then `pink_encounters_trainers`.

## Layout

```
mods/<id>/          one folder per mod, exactly what goes in its .zip
tools/release.py    builds every mod as one lockstep release (runs modkit gates)
tools/gen_pink_data.py   regenerates pink_encounters_trainers/data.lua and pink_species/species_data.lua
tools/gen_world_data.py  regenerates pink_world_tweaks/world_data.lua
tools/verify_pink.py     loads the mods over an imported Yellow and diffs against Pink
tools/verify_world.py    the same for map, tileset and field changes
tools/gen_tile_data.py   regenerates pink_tilesets/tile_data.lua and assets/pink_tiles.png
tools/gen_palette_data.py regenerates pink_palettes/palette_data.lua
docs/ROADMAP.md     plan, decisions and known issues
DIFFERENCES.md      what each mod changes from vanilla Yellow
CREDITS.md          who made what
```

## Releasing

All mods share one version number and ship in one GitHub Release, which is
what the cart pins.

```sh
python3 tools/release.py 0.3.0 --stamp   # bump every manifest and build dist/ locally
git commit -am "Release 0.3.0"
git tag v0.3.0 && git push --follow-tags  # the workflow builds and publishes the release
```

`release.py` needs a gen1recomp checkout for modkit (`--engine PATH`, or
`$G1R_ROOT`, or `~/dev/gen1recomp-dev`) and `luajit`.

## Regenerating the encounter and trainer data

```sh
# vanilla self-check: must report 0 differences
python3 tools/gen_pink_data.py path/to/pokeyellow path/to/yellow/data/generated /dev/null --selftest
# Pink (also writes mods/pink_species/species_data.lua)
python3 tools/gen_pink_data.py path/to/pokepink path/to/yellow/data/generated mods/pink_encounters_trainers/data.lua
python3 tools/gen_world_data.py path/to/pokepink path/to/yellow/data/generated mods/pink_world_tweaks/world_data.lua
# check the result in-engine
POKEPORT_DATA_DIR=path/to/yellow/data/generated POKEPORT_VERSION=yellow \
  python3 tools/verify_pink.py path/to/pokepink mods/pink_partner mods/pink_species mods/pink_encounters_trainers
```

`path/to/yellow/data/generated` is the imported-data folder in your Gen1Recomp
save directory (`yellow/data/generated`). It's read locally and never committed.

## License

The code and tools in this repo are by ElvieBlooms, under the [MIT License](LICENSE).

The MIT License covers this port's own work only. Art credited to other
artists in [CREDITS.md](CREDITS.md) (for example Anima_nel's Clefairy sprite) is
used with their permission and is not MIT-licensed. Pokémon Pink's design and
data (the encounter tables, trainer teams and events these mods recreate)
belong to jcferggy, and any art from the hack belongs to its artists. See
[CREDITS.md](CREDITS.md). Pokémon is © Nintendo / Creatures / Game Freak; this
is an unofficial fan project.
