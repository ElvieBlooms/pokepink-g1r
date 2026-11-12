# Differences from vanilla Pokémon Yellow

What each mod changes. The game's own behavior is unchanged when the mods are off.

## pink_partner
- Internal species slots swapped: `PIKACHU` holds Clefairy (#35), `RAICHU`
  holds Clefable (#36), `CLEFAIRY` holds Pikachu (#25), `CLEFABLE` holds Raichu (#26).
  Names, Pokédex numbers, stats, types, sprites, cries, palettes, learnsets and
  Pokédex entries move with them; evolutions are rewired (Moon Stone for the partner).
- The partner follower is an animated Clefairy (Anima_nel's sprite, kept in its own colours).
- Yellow's recorded Pikachu voice clips are off; the partner uses Clefairy's normal cry.
- Tester option (off by default): one Moon Stone per save.

## pink_species
- Pink's learnsets and TM/HM lists for Clefairy (learns TM39 Swift and HM03 Surf)
  and Clefable.
- Kadabra, Machoke, Graveler and Haunter can also evolve with the Linking Cable.
- `ITEM_32` (unused in Yellow) becomes the LINKINGCABLE: ¥8000, used on a party
  Pokémon like an evolution stone and consumed. It plays no heal sound on use;
  the stone's sound isn't reachable from a mod.

## pink_world_tweaks
- Block layouts on 30 maps (171 cells), applied cell by cell to the imported maps.
- 28 tileset blocks redefined (Overworld 9, Forest 10, Facility 8, Interior 1),
  walkable-tile lists for Forest and Facility, four new Cut-tree block pairs.
- Celadon Dept. Store roof and Celadon Mansion roof count as outdoor maps
  (Fly works there; so does Teleport, and an Escape Rope or Dig can return there).
- Celadon Dept. Store 4F sells the Linking Cable.
- Safari Zone Gate's unreachable hidden Nugget removed; a hidden Full Restore at
  Vermilion Dock (21, 0).
- Silph Co. 11F: the spot by the elevator warps to the 1F lobby. The Route 6
  gate and Summer Beach House exits move with their map edits.
- All ten in-game trades are Pink's (Ditto for Dodrio, Pikachu for Starmie, and so on).
- After you beat the Champion, the S.S. Anne is back at Vermilion Dock and the
  sailor lets you board without a ticket. Leaving the ship plays the departure
  again, as in Pink.
- Oak heals your party after the Hall of Fame.
- Game Corner prizes as in Pink: Abra (L12, 200 coins), Growlithe (L16, 1100),
  Slowpoke (L20, 1600); Raichu (L26, 3200), Dragonair (L28, 5000), Porygon
  (L24, 9100); TMs unchanged. Needs `engine_internals`.
- A harbor sign on Vermilion Dock (11, 1), with Pink's text.
- Dungeon battle intro also on Pokémon Mansion 1F, Victory Road 2F/3F, Power
  Plant, Diglett's Cave, Silph Co. 9F-11F, Seafoam B1F-B4F, Rocket Hideout B1F-B4F.

## pink_palettes
- Pink's colours for 42 Super Game Boy palettes and 27 Game Boy Color palettes.
- New palettes: CAVE_YELLOW (Cerulean Cave 1F, 2F, B1F) and GRAYMON_YELLOW
  (Trade Center, Colosseum).
- Raticate, Geodude, Graveler, Golem, Cubone and Marowak use GRAYMON_YELLOW;
  Jynx uses 0F.
- The Game Boy Color palettes are written into the loaded data on `game.ready`
  (no registry covers them); needs `engine_internals`.

## pink_manga_events
- Yellow's unused CHIEF class becomes BUSYBODY (Pink's trainer picture and
  overworld sprite).
- The Busybody waits on six maps (Underground Paths, Celadon Dept. Store roof,
  Safari Zone West, Pokémon Mansion 1F, Victory Road 3F): Pink's trigger cells,
  approach and exit paths, lines and CHIEF parties 1-6. Lose and he comes back;
  beat him and his EVENT_BEAT_..._CHIEF flag is set.
- Differences from Pink: the rival's encounter theme stands in for Yellow's
  unused song (not imported by the engine), and his line for beating you isn't
  shown (scripted battles only take the losing line).

## pink_tilesets
- Nine tileset sheets rebuilt at startup (Overworld, Forest, Facility, Gate,
  Gym, Lab, Mansion, Plateau, Ship Port), 93 tiles in all.
- 30 tiles come from the player's own Red (or Blue) import; without either,
  Yellow's tile stays. 63 are Pink's own and ship in `assets/pink_tiles.png`.
- Written to `save/mod-derived/pink_tilesets/tilesets/`, which the engine uses
  in place of the imported sheet while the mod is enabled. Needs `engine_internals`.

## pink_encounters_trainers
- Grass and water encounters on 36 maps, and Super Rod tables on 26 maps, as in Pink.
- Trainer parties for 17 classes (generic trainers restored to Red/Blue, manga
  Gym Leaders and rival, Agatha's Clefable), with Pink's hand-picked trainer moves.
- Rival 2 and 3: Pink's single team per fight fills every vanilla Eevee branch.
- Trainer movesets that Pink hand-picked are built from Pink's learnsets
  (loads after pink_species).
