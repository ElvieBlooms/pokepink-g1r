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

Everything is read from your own imported game at load time; the mod ships
no ROM data or art.

Also: the overworld follower uses Clefairy's overworld sprite, and Yellow's
recorded Pikachu voice clips are switched off so the partner uses Clefairy's
normal cry.

Known gaps (later mods): emotion portraits, surfing minigame art, title
screen, text that names PIKACHU directly, Pink's Clefairy voice clips.
Trading the partner to vanilla Yellow or converting the save to Gen 2 turns
it back into a Pikachu.
