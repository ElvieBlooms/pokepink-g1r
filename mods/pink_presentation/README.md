# Pink Presentation

Pokémon Pink's look for Gen1Recomp (Yellow). Part of the Pokémon Pink cart.

## What it changes

- **Gym leaders** get their own overworld sprites, as in Pink: Brock, Misty,
  Lt. Surge, Erika, Koga and Blaine (Gold/Silver's sprites, touched up by Pink)
  and Sabrina (Yellow's Silph worker, redrawn).
- **Elite Four and Giovanni**: Pink's edited overworld sprites.
- **Battle pictures**: Pink's edits to 36 back sprites (redrawn to look more
  like the official designs) and to Rattata's and Tauros's fronts (shaded for
  their palettes).
- The **Busybody** and **manga Yellow** overworld sprites used by
  pink_manga_events.
- **Partner portraits**: Pink's Clefairy emotion portraits (adapted from
  Artsy-Theo's), all 62 pictures.
- **Title screen**: Pink's logo and Clefairy, with its blink.
- **Badges, slot reels, town map** (tiles and the cells Pink redraws), the
  **surfing** overworld sprite, the **Surfing minigame** ("Clefairy's Beach")
  and the **bolt emote**.
- Oak's speech shows your partner in Pink's palette, and the partner's
  signature moves are Metronome and Psychic (its happy mood on learning them,
  and Psychic's sound in its "thunderbolt" portrait).

- **Party icons**: one per Pokémon, as in Pink, from the Minidex 001-251
  (option PARTY ICONS: MINIDEX or GAME). If another mod such as Facets picks
  an icon, its choice wins.

Not yet: Pink's intro and its Super Game Boy border.

## How it's built

Pink drew nearly all of these over the games' own art, so they don't ship as
pictures. The mod carries only the pixels Pink changed and, at startup, starts
each picture from your own imports and writes the result to
`save/mod-derived/pink_presentation/`, which the game uses in place of the
imported picture.

- The gym leaders other than Sabrina need a **Gold, Silver or Crystal**
  import. Without one, those leaders keep Yellow's sprites.
- Everything else comes from your Yellow import.
- The title Clefairy and its blink frames are new drawings and ship in
  `overrides/title/`.

The title screen draws Pink's Clefairy one tile further left than Yellow's
Pikachu; the mod wraps the title screen's draw to move it there.

Needs the `engine_internals` permission (it reads the other games' imports and
uses the importer's own transparency step for battle pictures).

## Credits

The sprite and picture edits are from **Pokémon Pink** by **jcferggy**; the
portraits adapt **Artsy-Theo**'s; the title art's artist is to be confirmed.
The party icons are the **Minidex 001-251** by **Chamber, Soloo993, Blue
Emerald, Lake, Neslug and Pikachu25**, used with credit (`assets/icons/`).
The art they're drawn over is Game Freak's and comes from your own games.
