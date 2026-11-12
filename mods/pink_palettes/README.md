# Pink Palettes

Pokémon Pink's colours for Gen1Recomp (Yellow). Needs **pink_partner**.

- Pink's recoloured palettes (42 Super Game Boy, 27 Game Boy Color).
- Two new palettes: a cave palette for Cerulean Cave and a grey palette for
  the Trade Center, the Colosseum and some Pokémon.
- Raticate, Geodude, Graveler, Golem, Cubone and Marowak use the new grey;
  Jynx uses palette 0F.

The Game Boy Color palettes are written into the loaded game data at startup,
which needs the `engine_internals` permission. `palette_data.lua` is generated
by `tools/gen_palette_data.py`; don't hand-edit it.
