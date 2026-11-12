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

## How it's built

Pink drew all of these over the games' own art, so none of it ships as a
picture. The mod carries only the pixels Pink changed and, at startup, starts
each picture from your own imports and writes the result to
`save/mod-derived/pink_presentation/`, which the game uses in place of the
imported picture.

- The gym leaders other than Sabrina need a **Gold, Silver or Crystal**
  import. Without one, those leaders keep Yellow's sprites.
- Everything else comes from your Yellow import.

Needs the `engine_internals` permission (it reads the other games' imports and
uses the importer's own transparency step for battle pictures).

## Credits

The sprite and picture edits are from **Pokémon Pink** by **jcferggy**; the art
they're drawn over is Game Freak's and comes from your own games.
