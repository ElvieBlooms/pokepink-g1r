# Roadmap and decisions

## Order
1. ~~pink_partner~~ (prototype, tested in-game)
2. ~~pink_encounters_trainers~~ (built, verified headlessly, needs playtest)
3. ~~pink_species~~ (built, verified headlessly, needs playtest)
4. pink_world_tweaks
5. pink_palettes
6. pink_manga_events
7. pink_presentation (art permissions first)
8. Cart release

## Decisions

**Partner by species-slot swap, not engine changes.** The engine identifies
Yellow's partner by the internal species ID `PIKACHU` in ~20 places. Instead
of changing that, `pink_partner` moves Clefairy's data into the `PIKACHU` slot
and Pikachu's into `CLEFAIRY` (same for Raichu/Clefable). Every other mod must
write Clefairy as `PIKACHU`, Clefable as `RAICHU`, Pikachu as `CLEFAIRY` and
Raichu as `CLEFABLE`. `tools/gen_pink_data.py` does this automatically.
Trade-off: trading or converting a save outside the cart turns the partner
back into a Pikachu.

**Rival party numbers.** Pink calls its rivals with fixed party numbers
(Rival 2: 1 SS Anne, 2 Tower, 3 Silph, 4 Route 22; Rival 3: 1). Vanilla
Yellow's scripts pick by the rival's Eevee (Rival 2: 1 | 2-4 | 5-7 | 8-10;
Rival 3: 1-3). The trainer data fills vanilla's numbering with Pink's teams,
so **pink_manga_events must keep vanilla's rival party-number logic** rather
than porting Pink's fixed numbers.

**Species data** is compared field by field against the import and written
to the slot that carries each species, so Pink's Clefairy data patches the
`PIKACHU` slot. `pink_species` loads after `pink_partner` (so the swap is in
place) and before `pink_encounters_trainers` (whose trainer movesets are
built from the merged learnsets, as the ROM builds them from Pink's).

**Moved out of pink_species:** the split Geodude/Jynx palette lines (Pink's
`data/pokemon/palettes.asm`) need new palettes, so they go with
`pink_palettes`; the VC Mew replacing Mewtwo is an event, so it goes with
`pink_manga_events`; the Linking Cable's place in the Celadon mart goes with
`pink_world_tweaks`.

**Super Rod** lives in the `field` registry, where lists append, so the mod
rebuilds the whole `superRod` key from the merged view.

**Trainer special moves.** Where Pink changed a class, the affected party
slots get explicit movesets (default moves for that species and level, then
Pink's picks), because the engine would otherwise apply vanilla's list by
party number.

## Known issues / questions
- Using the Linking Cable plays no sound (the stone's heal sound isn't
  available to mods).
- Pink's `data/trainers/special_moves.asm` has a `PSYCHIC:` label with no
  `db CLASS, id` header (Abra: Psywave, Kinesis, Thunder Wave, Tri Attack).
  The ROM reads it as noise, so no trainer gets those moves; the port matches.
  Ask jcferggy which trainer it was meant for.
- Emotion portraits, surfing minigame and title screen still show Pikachu.
- Text that names PIKACHU directly is not yet replaced.
- The partner swap uses the deprecated `audio` registry to turn off the
  Pikachu voice clips (one load warning); move it when Pink's Clefairy clips go in.
