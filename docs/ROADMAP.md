# Roadmap and decisions

## Order
1. ~~pink_partner~~ (prototype, tested in-game)
2. ~~pink_encounters_trainers~~ (built, verified headlessly, needs playtest)
3. ~~pink_species~~ (built, verified headlessly, needs playtest)
4. ~~pink_world_tweaks~~ (verified headlessly; needs playtest)
4b. ~~pink_tilesets~~ (built; composition verified pixel-for-pixel against Pink; needs playtest)
5. ~~pink_palettes~~ (verified headlessly; needs playtest)
6. ~~pink_manga_events~~ (Busybody challengers, Trashed House rematches, beach house Imposter, Mew; verified headlessly, needs playtest)
7. ~~pink_presentation~~ and ~~pink_voice~~ (verified headlessly, needs playtest). SGB border: a skin next to the cart
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

**Rooftop Fly.** Pink widens only the party menu's Fly check. The engine has
no hook for it, so both Celadon roofs are marked `outdoor`. Side effects
accepted for now: Teleport works there, and the roof can become the
"last outdoor spot" an Escape Rope or Dig returns to.

**Game Corner prizes** are local tables in the engine's `data/scripts/story3.lua`,
picked by a private function, so no mod can reach them. The mod replaces the three
counters' talk handlers with its own prize vendor (`prize_vendor.lua`), written
from the original game's behaviour (pret `engine/events/prize_menu.asm`) rather
than copied from the engine, whose code is GPLv3 and couldn't go into this MIT
repo. It uses the engine's TextBox, PrizeCounter, Bag and script runner
(`engine_internals`). If upstream ever moves the prize lists into data, switch
to that and drop the vendor.

**S.S. Anne return.** Pink checks EVENT_BEAT_GREEN; the engine's equivalent is
`EVENT_BEAT_CHAMPION_RIVAL`. Entering Vermilion after the Champion clears
`EVENT_SS_ANNE_LEFT`; an `onStep` on (18,30) shows Pink's sailor line and lets
you board. Text keeps Pink's spelling ("come on abord!").

**Tile art.** Of the 93 tiles Pink changes, 30 exist in international Red/Blue
and get built at runtime from the player's own Red or Blue import (the Facets
route, `engine_internals` + `CacheFs`). The other 63 exist in no cart (checked
against Red, Blue, Yellow and Japanese Blue), so they are Pink's own tiles and
ship as a patch image credited to jcferggy, gated on his permission.
The mod gets the cache location from the engine (`AssetTransform.SOURCE_ROOT`,
as Facets does) rather than hard-coding it, which is also what keeps lint
rule MK301 clean.

**Palettes.** The `palettes` registry covers the Super Game Boy set, species
use their `palette` field, and maps use their own `palette` field, which the
engine checks before its lookup. The Game Boy Color set (`cgbBase`) has no
registry; the engine reads it fresh on each lookup, so the mod writes Pink's
colours into the loaded data on `game.ready`. Pink's new SET_PAL_CLEFAIRY
command and its title/intro colours belong to pink_presentation.

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
- Pink's intro wraps YellowIntro's new/spawn/updateObjects/drawObjects/
  startScene (engine_internals). If the engine renames them, the mod logs a
  warning and Yellow's intro plays.
- Pink's SGB border ships as a launcher skin (skins/pink_sgb_border), not
  through a mod: borders are skins in the engine, and a cart can't carry one.
- Pink's own per-species party icons (gfx/icons/party_mon_sprites.png) have an
  unknown source, so the Minidex icons stand in for them.
- pink_voice ships Pink's clips for now; the plan is to replace them with a
  Pika Remastered-style treatment of Clefairy's voice.
- pink_partner and pink_voice set the deprecated `audio` registry's
  `pikaCries` (one load warning each); move when the engine offers a
  replacement.
