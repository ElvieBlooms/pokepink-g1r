# Test Checklist

A tester's checklist on the second screen. Tick off a walkthrough as you play,
flag a problem right where it happens, and export a report with the game log.
Made for the Pokémon Pink beta and the AYN Thor's bottom screen, but it reads
any checklist and works on any game.

## Using it
- The checklist shows on the second screen: the Thor's bottom screen, or the
  companion window on desktop. Turn it off with **CHECKLIST** in the Mods
  manager.
- With **Kanto Gear** installed, it's an app in Gear's Silph Store instead.
  Install it there and tap its tile to open it; **CLOSE** hands the screen
  back to Gear.
- Tap a line to tick it. Tap again to flag it as a problem (red !), and once
  more to clear it. Flagging notes where you are and the last 40 log lines.
- Drag to scroll. **SECTIONS** lists every section with its progress; tap one
  to jump to it.
- Ticks are kept in your save, so each playthrough has its own. Load a save
  before ticking.
- **EXPORT** writes `test_checklist/report-001.txt` (then 002, 003...) and
  `test_checklist/latest.txt` in the game's save folder: your flagged lines
  with where they happened, progress per section, the cart, the COLORS
  setting, your mods and versions, and the log since the game started.

## Your own walkthrough
It comes with the Pokémon Pink beta walkthrough. To use another one, put a
markdown file at `test_checklist/walkthrough.md` in the save folder. `##`
headings become sections and `- [ ] ` lines become items; everything else is
left out.

Needs `engine_internals`, to keep a longer log than the engine does and to
write the reports to the save folder. It changes nothing in the game.
