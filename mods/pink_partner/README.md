# Pink Partner (prototype)

First piece of the Pokémon Pink port for Gen1Recomp (Yellow only).

Yellow's engine treats anything with the internal species id `PIKACHU` as
your partner. This mod leaves that id alone and swaps what the slots hold:

| Internal id | Shows as | Evolves |
|---|---|---|
| PIKACHU  | Clefairy (#35) | Moon Stone -> RAICHU slot |
| RAICHU   | Clefable (#36) | - |
| CLEFAIRY | Pikachu (#25)  | Thunder Stone -> CLEFABLE slot |
| CLEFABLE | Raichu (#26)   | - |

Everything else is read from your own imported game at load time; the mod
ships no ROM data or ROM art.

Also: the overworld follower is an animated Clefairy, and Yellow's recorded
Pikachu voice clips are switched off so the partner uses Clefairy's normal cry.

## Other mods

Other mods mean the real species when they say `PIKACHU`, so wild Pokémon
they add are swapped back as they appear: a Pikachu swarm or a fishing spot
from another mod gives you a real Pikachu, and a Clefairy one gives you
Clefairy. This covers anything that comes through the wild encounter tables
or the encounter hooks, previews included. Pink's own Pikachu on Route 2 and
in the Power Plant are left as they are.

Scripted battles (`mod.world:startWildBattle`), gifts, trades and trainer
teams from other mods still use the slot names, so another mod's gift
Pikachu turns up as Clefairy. Text another mod writes itself, such as an
announcement that looks up the species name, does too.

## Credits

- Clefairy overworld walking sprite (`assets/clefairy_follower.png`) by
  **Anima_nel**, purchased for use in this project, recoloured pink by
  ElvieBlooms (green and blue only, so the Game Boy shades are unchanged).
  It is not covered by the MIT license and may not be reused outside this mod
  without the artist's permission.

Known gaps (later mods): emotion portraits, surfing minigame art, title
screen, text that names PIKACHU directly, Pink's Clefairy voice clips.
Trading the partner to vanilla Yellow or converting the save to Gen 2 turns
it back into a Pikachu.
