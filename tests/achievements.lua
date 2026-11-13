-- tests/achievements.lua
-- Pokemon Pink's list on Recomp Achievements' cart lists, through Recomp
-- Achievements' own headless harness and the real Gen1Recomp mod loader.
--
--   RA=/path/to/recomp_achievements ENGINE=/path/to/gen1recomp luajit tests/achievements.lua
--
-- RA is a checkout of ElvieBlooms/recomp_achievements (2.8.0 or newer).
-- It makes a scratch project holding both mods, as the harness expects.
local RA = assert(os.getenv("RA"), "set RA to a recomp_achievements checkout")
local HERE = debug.getinfo(1, "S").source:match("^@(.*)/tests/") or "."
local PROJECT = os.tmpname() .. "_pinkach"
os.execute(("mkdir -p '%s/tests' && ln -s '%s/recomp_achievements' '%s/recomp_achievements'"
  .. " && ln -s '%s/mods/pink_achievements' '%s/pink_achievements' && ln -s '%s/tools' '%s/tools'")
  :format(PROJECT, RA, PROJECT, HERE, PROJECT, RA, PROJECT))
package.loaded.__pink_project = PROJECT
local H = (function()
  local env = setmetatable({ os = setmetatable({ getenv = function(k)
    if k == "PROJECT" then return PROJECT end return os.getenv(k) end }, { __index = os }) }, { __index = _G })
  local chunk = assert(loadfile(RA .. "/tests/harness.lua"))
  setfenv(chunk, env)
  return chunk()
end)()
local SaveData = require("src.core.SaveData")
local man = io.open(HERE .. "/mods/pink_achievements/manifest.json"):read("*a"):gsub('"experimental": true', '"experimental": false')
local FILES = { ["mods/pink_achievements/manifest.json"] = man }
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("FAIL " .. m) end end
local function eq(a, b, m) check(a == b, ("%s (expected %s, got %s)"):format(m, tostring(b), tostring(a))) end

local env = H.boot({ "recomp_achievements", "pink_achievements" }, { version = "yellow", files = FILES })
check(env.ok, "load: " .. table.concat(env.loader.errors, "; "))
local api = env:exports("recomp_achievements")
SaveData.setCart("pokepink")
env:newGame()
local list = api.cartList()
eq(list and list.board, "pokepink", "Pink's list is the cart's list")
local t = api.officialTotals()
eq(t.total, 76, "76 achievements"); eq(t.maxPoints, 564, "564 points")
-- borrowed checks
env:setFlag("EVENT_GOT_POKEDEX"); env:frame()
check(api.isUnlocked("mod:pink_achievements:pokedex"), "Starting Line via off_pokedex")
env.game.save.inventory.BOULDERBADGE = 1; env:setFlag("EVENT_BEAT_BROCK"); env:frame()
check(api.isUnlocked("mod:pink_achievements:boulder_badge"), "Rock Bottom via the badge check")
env:setFlag("EVENT_TRADED_RAICHU_FOR_ELECTRODE"); env:frame()
check(api.isUnlocked("mod:pink_achievements:trade_kangaskhan"), "Kangaskhan trade via its Yellow trader's flag")
-- Pink's own
env:setFlag("EVENT_BEAT_MANSION_CHIEF"); env:frame()
check(api.isUnlocked("mod:pink_achievements:busybody_first"), "first Busybody")
eq(api.get("mod:pink_achievements:busybody_all").progress, 1, "1 of 6 places")
for i = 0, 6 do env:setFlag("EVENT_BEAT_CERULEANTRASHEDHOUSE_TRAINER_" .. i) end
env:frame()
check(api.isUnlocked("mod:pink_achievements:busybody_house"), "Full House at 7")
env:setFlag("EVENT_BEAT_SUMMERBEACHHOUSE_TRAINER_0"); env:frame()
check(api.isUnlocked("mod:pink_achievements:imposter"), "Imposter")
env.game.save.pokedex.owned.ALAKAZAM = true; env:emit("pokemon.evolved", { toSpecies = "ALAKAZAM" })
check(api.isUnlocked("mod:pink_achievements:linking_cable"), "Strong Connection")
eq(api.get("mod:pink_achievements:linking_cable_all").progress, 1, "1 of 4 cable evolutions")
env.game.save.surfingHighScore = 5200; env:emit("screen.popped", {})
check(api.isUnlocked("mod:pink_achievements:surf_score"), "surf score")
env.game.save.party[1] = { species = "PIKACHU", level = 30, moves = { { id = "SURF", pp = 15 } } }
env:emit("pokemon.move_learned", {})
check(api.isUnlocked("mod:pink_achievements:surf"), "Wave Rider")
env.game.save.player.map = "GAME_CORNER_PRIZE_ROOM"
env:emit("pokemon.before_give", { species = "DRAGONAIR", level = 18 })
check(api.isUnlocked("mod:pink_achievements:prize_dragonair"), "Dragonair prize")
env:setFlag("EVENT_BEAT_CHAMPION_RIVAL"); env:frame()
check(api.isUnlocked("mod:pink_achievements:champion"), "Pretty in Pink via off_champion")
env:emit("map.entered", { mapId = "SS_ANNE_1F", fromMapId = "VERMILION_DOCK" })
check(api.isUnlocked("mod:pink_achievements:ss_anne_return"), "back aboard")
env:setFlag("EVENT_GOT_HM01")
env:emit("world.interacted", { mapId = "SS_ANNE_CAPTAINS_ROOM", kind = "npc" })
check(api.isUnlocked("mod:pink_achievements:captain_line"), "captain's line")
local card = api.leaderboardCard()
eq(card.game, "pokepink", "card board"); eq(card.title, "Pokémon Pink", "card title")
for _, row in ipairs(api.list()) do
  check(not (row.source == "core" and row.raId), "no RA Yellow entry shows: " .. tostring(row.key))
end
print(("card: %s %d/%d points, %d/%d earned"):format(card.game, card.points, card.maxPoints, card.earned, card.total))
-- the plain game: nothing of Pink's
SaveData.setCart(nil)
local env2 = H.boot({ "recomp_achievements", "pink_achievements" }, { version = "yellow", files = FILES })
local api2 = env2:exports("recomp_achievements")
env2:newGame()
eq(api2.officialTotals().total, 76, "Yellow's own list on plain Yellow")
eq(api2.leaderboardCard().game, "yellow", "Yellow's board")
local pinkRows = 0
for _, r in ipairs(api2.list()) do if r.provider == "pink_achievements" then pinkRows = pinkRows + 1 end end
eq(pinkRows, 0, "no Pink rows on plain Yellow")
print(pass .. " passed, " .. fail .. " failed")
os.execute(("rm -rf '%s'"):format(PROJECT))
os.exit(fail == 0 and 0 or 1)
