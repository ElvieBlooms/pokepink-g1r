# Pink Manga Events

Pokémon Pink's manga events for Gen1Recomp (Yellow). Needs **pink_partner**
and **pink_encounters_trainers** (whose CHIEF parties these battles use).

## Busybody challengers

Yellow's unused CHIEF class becomes Pink's **BUSYBODY**. He waits for you on
six maps, walks up, battles you and moves on:

| Map | Team |
|---|---|
| Underground Path (north-south) | CHIEF party 1 |
| Underground Path (west-east) | CHIEF party 2 |
| Celadon Dept. Store roof | CHIEF party 3 |
| Safari Zone West | CHIEF party 4 |
| Pokémon Mansion 1F | CHIEF party 5 |
| Victory Road 3F | CHIEF party 6 |

Lose and he'll catch you again; beat him and he heads to **Cerulean's Trashed
House**, where he waits for a rematch with the same team. Only the last one
you beat is there. Beat the Champion and his final team (CHIEF party 7)
takes his place.

The rematch and Imposter trainer headers are added to the loaded game data at startup,
so this mod needs the `engine_internals` permission.

Known differences from Pink:
- Pink plays Yellow's unused song for these encounters. The engine doesn't
  import that song, so the rival's encounter theme plays instead.
- His line for when he beats you isn't shown: the engine's scripted battles
  only take the line for when he loses.

He's paid as in Pink (base money 6500).

## The Imposter

The first time you beat the Champion, two visitors turn up at the **Summer
Beach House** on Route 19: someone dressed exactly like you, and a Pikachu.
Talk to the **IMPOSTER** and the disguise drops: it's manga **Yellow**, and
she wants to see whose partner is strongest (Pikachu 88, Primeape, Arcanine,
Lapras, Snorlax, Venusaur, with the final battle theme). Walk right in front
of him and he'll challenge you without the reveal.

The Surfin' Dude and your Clefairy's stand-in move aside, the Dude now knows
it's a Clefairy that surfs, and the visiting Pikachu borrows the game's own
Pikachu overworld art from your imported data.

## Mew

Cerulean Cave's legendary is **Mew** at level 70. Catch it and it carries the
OT name **GF** and ID **22796**, like an official event Mew.

Known differences from Pink:
- Pink turns Yellow to face you from three spots and otherwise leaves her
  facing left; here she always turns to you.
- Pink gives the GF OT only to a Mew added to your party; here a Mew sent to
  the box gets it too.

## Credits

Text, the Busybody overworld sprite (`assets/sprites/busybody.png`) and
trainer picture (`assets/trainers/busybody.png`), manga Yellow's overworld
sprite (`assets/sprites/yellow.png`) and the Imposter's trainer picture
(`assets/trainers/imposter.png`) are from **Pokémon Pink** by **jcferggy**. Not covered by the MIT license.
