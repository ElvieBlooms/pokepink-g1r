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
| Surfing Clefairy sheet | Yellow's Surfing Pikachu, about 50–80 pixels per frame | to check: probably Pink's redraw |
| Emotion portraits | Pink's (Artsy-Theo's portraits, adapted) | Pink's own art |
| Title logo, title Clefairy, intro, SGB border, slot reels, town map, badges, emote bolt, party icons | to check one by one | per item |

"Built at runtime" is the route the engine asks for when art is derived from a
cart (modkit MK302: ship the change, not the file): only the pixels Pink
changed are stored, and the player's own import supplies the rest.

Status: everything above the surfing row is built and checked pixel for pixel
against Pink's pictures (tools/gen_art_data.py, pink_presentation).

## Not art

- Clefairy voice clips: Pink's `audio/pikachu_cries/*.wav` (42 clips).
- Title screen and intro scripting (Pink shows Clefairy, not Pikachu).
- SET_PAL_CLEFAIRY and the title/intro colours.

## Done elsewhere

- Pink's rewritten text and the small script changes (gifts, pets, dolls, the
  Dojo master, the S.S. Anne captain) went into pink_world_tweaks.
- The Pikachu/Clefairy overworld sheet swap went into pink_partner.
