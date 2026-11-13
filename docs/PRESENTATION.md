# pink_presentation inventory

What's left of Pokémon Pink after the world, species, trainer, palette,
tileset and manga-event mods. Pink's changes were measured against the pret
pokeyellow commit Pink was built on (3d300551, 2026-06-07, the closest by diff
to Pink's tree), so later pret clean-ups don't show up as Pink changes.

## Where each piece of art comes from

Checked frame by frame (allowing for shade order) against the player's own
Red, Blue, Yellow, Gold, Silver and Crystal imports.

| Art | Closest cart art | How it ships |
|---|---|---|
| Brock, Erika, Blaine, Koga overworld sprites | Gold/Silver/Crystal, 0–12 pixels changed per frame | built at runtime from the player's Gen 2 import plus Pink's changed pixels |
| Misty, Surge overworld sprites | Gold, about 35–60 pixels per frame | same, with more changed pixels |
| Sabrina overworld sprite | Yellow's Silph worker, about 25% of pixels changed | built from the player's Yellow import plus Pink's pixels |
| Busybody, manga Yellow overworld sprites | each frame over one of Yellow's sheets, 15–70 pixels per frame | built frame by frame from the player's Yellow import |
| Agatha, Bruno, Lance, Lorelei, Giovanni overworld sprites | Red/Blue/Yellow, about 15–60 pixels per frame | built from the player's Yellow import plus Pink's pixels |
| SPRITE_FAIRY (Clefairy NPC) | Red/Blue's sheet, exact | not needed: after Pink's object changes no object uses it |
| 36 back sprites, Rattata and Tauros fronts | Yellow, 25–400 pixels changed | built from the player's Yellow import plus Pink's pixels |
| Surfing Clefairy sheet, Surfing minigame sheets | Yellow's, 10–30% of pixels changed | built from the player's Yellow import plus Pink's pixels |
| Emotion portraits | composed like the importer does, from Pink's tiles; each under 50% different from Yellow's | built from the player's Yellow import plus Pink's pixels |
| Title logo, speech bubble | Yellow's, edited | built from Yellow's plus Pink's pixels |
| Title Clefairy and blink overlays | Pink's title art (new drawing) | ships as files in overrides/title/ |
| Badges, slot reels, town map tiles, bolt emote | Yellow's, edited | built from Yellow's plus Pink's pixels |
| Intro sheets | Yellow's, edited | built from Yellow's plus Pink's pixels |
| Intro animation | Pink's frame scripts, layouts, spawn spots (asm) | the intro's sprite steps are wrapped (pink_presentation/intro.lua) |
| SGB border | Pink's Clefairys and FAIRY bubbles; the rest is Yellow's | a launcher skin next to the cart; Yellow's pieces redrawn as new art (tools/gen_sgb_border.py) |
| Party icons | Pink's per-species grey icons, source unknown | the Minidex 001-251 stands in (shipped with credit, as in Facets) |

"Built at runtime" is the route the engine asks for when art is derived from a
cart (modkit MK302: ship the change, not the file): only the pixels Pink
changed are stored, and the player's own import supplies the rest.

Status: every "built" row is checked pixel for pixel against Pink's pictures or
against compositions of Pink's files made the way the importer composes
Yellow's (tools/pikapic.py, title.py and surfing.py each reproduce the
player's vanilla import exactly before composing Pink's).

## Not art

- Clefairy voice clips: Pink's 42 clips, in pink_voice.
- SET_PAL_CLEFAIRY (Oak's speech) and the partner's signature moves: in
  pink_presentation.

## Done elsewhere

- Pink's rewritten text and the small script changes (gifts, pets, dolls, the
  Dojo master, the S.S. Anne captain) went into pink_world_tweaks.
- The Pikachu/Clefairy overworld sheet swap went into pink_partner.
