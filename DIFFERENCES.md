# Differences from vanilla Pokémon Yellow

What each mod changes. The game's own behavior is unchanged when the mods are off.

## pink_partner
- Internal species slots swapped: `PIKACHU` holds Clefairy (#35), `RAICHU`
  holds Clefable (#36), `CLEFAIRY` holds Pikachu (#25), `CLEFABLE` holds Raichu (#26).
  Names, Pokédex numbers, stats, types, sprites, cries, palettes, learnsets and
  Pokédex entries move with them; evolutions are rewired (Moon Stone for the partner).
- The partner follower is an animated Clefairy: Anima_nel's sprite, recoloured pink in full-colour mode (only green and blue changed, so the Game Boy shades are the same).
- Yellow's recorded Pikachu voice clips are off; the partner uses Clefairy's normal cry.
- Tester option (off by default): one Moon Stone per save.
- As in Pink, the two overworld sheets swap: SPRITE_CLEFAIRY (the Fan Club pet,
  Celadon Mansion's and the beach house's Pikachu) shows Pikachu, using the
  player's imported Pikachu sheet.

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
- Pink's rewritten lines (53, from `text_data.lua`): Clefairy named where
  Yellow names Pikachu (Oak's lab, Pewter Gym guide, Museum, Celadon Mansion),
  Cerulean's Voltorb, the Fan Club's Pikachu, new lines for trainers on Routes
  6, 8 and 9, Viridian Forest, Mt. Moon and the Fuchsia Gym, and others.
- Objects with Pink's sprites: Celadon Mansion's Bulbasaur and Pikachu, the
  Copycat's Oddish, Sandshrew and Jigglypuff dolls, Koga as the Fighting Dojo's
  Karate Master. The Bulbasaur and the male Nidoran cry as themselves.
- Officer Jenny gives Charmander and Damian (Route 24) gives Squirtle.
- After the Champion, the S.S. Anne captain has a new line.
- Pink's repeat of the Route 16 sign just past Route 17's top edge (5, -1),
  so it can be read from Route 17.
- Pink's other three bug fixes aren't needed: the engine already behaves
  correctly there (Mt. Moon B2F's no-battle zone is checked each step, so an
  Escape Rope can't carry it out of the cave; the Pewter youngster is placed by
  map cell, not screen pixel; Pokémon Tower 2F's rival trigger is just its two
  cells).
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
- Cerulean's Trashed House gets seven hidden Busybody trainers on one tile
  (5, 1), with Pink's sight range (5), beaten flags and lines. Beating a
  challenger shows his house Busybody (same team) for a rematch and hides the
  others; beating the Champion leaves the seventh (CHIEF party 7). Their trainer
  headers are written into the loaded data on `game.ready` (no registry), so the
  mod needs `engine_internals`.
- The Busybody is paid as in Pink (base money 6500, was 3000).
- On the Celadon Dept. Store roof he's standing there from the start and turns
  to you before walking up, as in Pink; talking to any Busybody before he steps
  up shows his opening line.
- Differences from Pink: the rival's encounter theme stands in for Yellow's
  unused song (not imported by the engine), and his line for beating you isn't
  shown (scripted battles only take the losing line).
- Summer Beach House: the Surfin' Dude moves to (3, 3) and the Clefairy to
  (6, 2), with Pink's "Clefairy knows how to SURF" and "CLEFAIRY: Fairii"
  lines (Clefairy's cry). Three hidden objects are added: the IMPOSTER (dressed
  as the player, SPRITE_RED) and manga Yellow on (8, 4), and a Pikachu on
  (8, 5) ("PIKACHU: Pikaa", Pikachu's cry), on SPRITE_CLEFAIRY as in Pink
  (pink_partner shows Pikachu on that sheet).
- The first time you beat the Champion, the Imposter and the Pikachu turn up
  (Pink's EVENT_BEAT_GREEN; here EVENT_PINK_IMPOSTER_ARRIVED). Talking to the
  Imposter fades the screen, reveals Yellow (EVENT_REVEAL_SUMMERBEACHHOUSE_TRAINER)
  and starts the battle; walking in front of him (sight range 1) starts it
  without the reveal, as in Pink.
- Yellow's unused JUGGLER class becomes IMPOSTER: Pink's trainer picture,
  base money 9900, move choices 1 and 3, and the final battle theme. Its party
  (Pikachu 88 and five others) comes from pink_encounters_trainers.
- Small difference: Pink turns Yellow toward the player from three cells and
  leaves her facing left otherwise; here she faces the player from any side.
- Cerulean Cave B1F: Mew L70 replaces Mewtwo (same "Mew!" line, Mewtwo's cry
  and EVENT_BEAT_MEWTWO, as in Pink). Any Mew you catch gets OT "GF" and ID
  22796, like Pink's add_mon.asm (Pink does this for Mew added to the party;
  here a Mew sent to the box gets it too).

## pink_presentation
- Gym leaders use their own overworld sprites (Pink's SPRITE_BROCK and the
  rest, here SPRITE_PINK_*). Brock, Misty, Surge, Erika, Koga and Blaine are
  built from the player's Gold, Silver or Crystal import plus Pink's changed
  pixels; without one they keep Yellow's sprites. Sabrina is built from
  Yellow's Silph worker sheet.
- Pink's edited sheets for Agatha, Bruno, Lance, Lorelei and Giovanni, 36 back
  sprites and the Rattata and Tauros fronts, built from the player's Yellow
  import plus Pink's changed pixels. Checked pixel for pixel against Pink's
  pictures.
- The Busybody and manga Yellow overworld sheets, built frame by frame from
  Yellow's sheets plus Pink's pixels.
- Pink's partner emotion portraits (62 pictures, composed the way the importer
  composes Yellow's, from Pink's tiles), badges, town map tiles and the 22 town
  map cells Pink redraws, slot reels, the surfing overworld sprite, the
  Surfing minigame's sheets, title ("Clefairy's Beach") and paddling frames,
  and the bolt emote. All checked pixel for pixel against compositions of
  Pink's own files.
- Title screen: Pink's logo ("PINK VERSION", "Clefa!") and Clefairy with its
  blink. Pink's Clefairy sits one tile left of Yellow's Pikachu, and the
  engine has no setting for that spot, so the title's draw is wrapped to move
  the picture and blink overlays 8 pixels left.
- Oak's speech: the partner preview uses the PINKMON palette (Pink's
  SET_PAL_CLEFAIRY).
- The partner's happy mood on learning a move comes from Metronome and
  Psychic instead of Thunderbolt and Thunder, and the "thunderbolt" portrait
  plays Psychic's sound, as in Pink.
- Written to `save/mod-derived/pink_presentation/`; needs `engine_internals`.
- Party icons: one per Pokémon, as in Pink, but from the Minidex 001-251
  (colour Game Boy icons, the set Facets uses) rather than Pink's own grey
  icons, whose source isn't known. A PARTY ICONS option switches back to the
  game's shared icons, and an icon chosen by another mod (Facets) wins.
- The intro: Pink's sheets and its animated sprites over the engine's Yellow
  intro. The engine keeps the scenes, timers, music, scrolling, strobes,
  skip and title hand-off; the mod takes over the sprite steps (spawn,
  movement and frame scripts, drawing) with Pink's frame scripts, layouts and
  spawn spots, and sets up the three scenes Pink changed (the second and
  third runs' spots, and the close-up a tile left with its new object). Data
  from Pink's asm (`intro_data.lua`, tools/gen_intro_data.py); with Yellow's
  data the same code replays the engine's intro frame for frame.
- The Super Game Boy border isn't part of this mod: it ships as a skin,
  `skins/pink_sgb_border`, installed from the launcher's SKINS tab.

## pink_voice
- Pink's 42 Clefairy voice clips play wherever Yellow plays its recorded
  Pikachu clips (same numbering). The engine's clip loader is wrapped to open
  the mod's files; needs `engine_internals`.

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

## pink_look_picker (cart extra, not in Pink)
- At NEW GAME, just before "First, what is your name?", Oak asks whether you'd
  like to pick your look (over your current look). YES opens PRISM, the menu
  Facets, Emerald Lens and Crystal Lens share (or the one mod's own screen);
  backing out of it lets Oak carry on, showing your new look.
- Oak asks nothing when none of those mods is loaded, or when ASK AT NEW GAME
  is off. Needs `engine_internals` (it asks for the START menu's PRISM item
  through the mods runtime).

## pink_achievements (cart extra, not in Pink)
- Pink's own achievement list (76 achievements, 564 points), written for this
  port in the style of a RetroAchievements set: Yellow's set adapted to
  Clefairy, plus Pink's own events (the Busybody, the Imposter, Mew, the S.S.
  Anne's return, the Linking Cable, the Game Corner's Dragonair and Porygon,
  Surf and the surfing minigame).
- With Recomp Achievements 2.8.0 or newer it is the Pokemon Pink cart's own
  list (cart lists): on the cart it takes the RA Yellow list's place and the
  leaderboard card goes on the `pokepink` board. Off the cart it isn't shown.
- 66 of its checks borrow Recomp Achievements' own Yellow checks (`uses` in
  `list.lua`); the rest are in `main.lua`. Each Pink trade sets the flag of
  the Yellow trader whose place it takes, and the gifts keep Yellow's flags.
- "Gotta Catch 'em All - Pink" is 136: every species one save can get (no
  Mewtwo, Venonat, Venomoth, Drowzee, Hypno, Sandshrew, Sandslash, Grimer,
  Muk or Tangela in Pink, one fossil, one Dojo prize, one Eevee evolution).
