-- Pink Achievements
--
-- Pokemon Pink's own achievement list for Recomp Achievements (list.lua).
-- On the Pokemon Pink cart it is the cart's own list (Recomp Achievements'
-- cart lists, API 1.6.0): it takes the RetroAchievements Yellow list's
-- place and goes on its own leaderboard, "pokepink". Anywhere else it
-- isn't shown.
--
-- Most entries borrow one of Recomp Achievements' own Yellow checks
-- (`uses` in list.lua): Pink plays like Yellow there, and with Clefairy in
-- the PIKACHU slot the partner checks follow Clefairy. The rest are Pink's
-- and are checked here, from the save and the game's events.

return function(mod)
  local found = mod.find and mod.find("recomp_achievements")
  local ach = found and found.exports
  if not (ach and type(ach.supports) == "function" and ach.supports("cart_lists")) then
    mod.log:info("Recomp Achievements 2.8.0 or newer isn't loaded; Pink's list is off")
    return
  end

  local source = mod:read("list.lua")
  local chunk = source and load(source, "@pink_achievements/list.lua")
  local LIST = chunk and chunk()
  if type(LIST) ~= "table" then
    mod.log:error("list.lua didn't load")
    return
  end

  local h = ach.connect(mod, { tab = "PINK" })
  local ok, code, message = h:declareCartList({
    cart = "pokepink", board = "pokepink", title = "Pokémon Pink",
    label = "PINK", games = { "yellow" },
  })
  if not ok then mod.log:warn("couldn't declare Pink's list: %s %s", tostring(code), tostring(message)) end
  local okCount, errors = h:registerMany(LIST)
  for i, e in pairs(errors or {}) do
    mod.log:warn("%s: %s %s", tostring(LIST[i] and LIST[i].id), tostring(e[1]), tostring(e[2]))
  end
  mod.log:info("Pink's list: %d of %d registered", okCount or 0, #LIST)

  -- ------------------ Pink's own checks
  local function onCart()
    local list = ach.cartList()
    return list ~= nil and list.provider == mod.id
  end
  local function save()
    local game = mod.game
    return type(game) == "table" and type(game.save) == "table" and game.save or nil
  end
  local function flag(s, name) return type(s.flags) == "table" and s.flags[name] == true end
  local function owned(s, species)
    local dex = type(s.pokedex) == "table" and s.pokedex.owned
    return type(dex) == "table" and dex[species] == true
  end
  local function count(s, names, test)
    local n = 0
    for _, name in ipairs(names) do if test(s, name) then n = n + 1 end end
    return n
  end

  -- pink_manga_events: the Busybody's six challenges, the Trashed House
  -- rematches and the beach house Imposter
  local CHALLENGES = {
    "EVENT_BEAT_UNDERGROUND_CHIEF", "EVENT_BEAT_UNDERGROUND2_CHIEF",
    "EVENT_BEAT_CELADONMARTROOF_CHIEF", "EVENT_BEAT_SAFARIZONEWEST_CHIEF",
    "EVENT_BEAT_MANSION_CHIEF", "EVENT_BEAT_VICTORY_ROAD_CHIEF",
  }
  local HOUSE = {}
  for i = 0, 6 do HOUSE[#HOUSE + 1] = "EVENT_BEAT_CERULEANTRASHEDHOUSE_TRAINER_" .. i end
  -- the trade evolutions; Pink has none of them in the wild, so owning one
  -- means the Linking Cable (or a link trade)
  local CABLE = { "ALAKAZAM", "MACHAMP", "GOLEM", "GENGAR" }
  local CHAMPION = "EVENT_BEAT_CHAMPION_RIVAL"
  local DEX_GOAL = 136
  local SURF_SCORE = 5000

  local function knowsSurf(mon)
    for _, mv in ipairs(type(mon.moves) == "table" and mon.moves or {}) do
      if type(mv) == "table" and mv.id == "SURF" then return true end
    end
    return false
  end

  -- Only what changed is written: a script can set several flags at once,
  -- and Recomp Achievements limits how often a mod writes.
  local last = {}
  local function unlockIf(id, cond)
    if cond and not last[id] and not h:isUnlocked(id) then
      last[id] = true
      h:unlock(id)
    end
  end
  local function progress(id, value)
    if last[id] == value then return end
    last[id] = value
    if not h:isUnlocked(id) then h:setProgress(id, value) end
  end

  -- what the save already proves; run on load and as things change
  local function evaluate()
    if not onCart() then return end
    local s = save()
    if not s then return end
    local beaten = count(s, CHALLENGES, flag)
    unlockIf("busybody_first", beaten > 0)
    progress("busybody_all", beaten)
    progress("busybody_house", count(s, HOUSE, flag))
    unlockIf("imposter", flag(s, "EVENT_BEAT_SUMMERBEACHHOUSE_TRAINER_0"))
    unlockIf("mew", owned(s, "MEW"))
    local cable = count(s, CABLE, owned)
    unlockIf("linking_cable", cable > 0)
    progress("linking_cable_all", cable)
    unlockIf("prize_porygon", owned(s, "PORYGON"))
    -- the PIKACHU slot holds Clefairy on this cart
    local surfs = false
    for _, mon in ipairs(type(s.party) == "table" and s.party or {}) do
      if type(mon) == "table" and mon.species == "PIKACHU" and knowsSurf(mon) then surfs = true break end
    end
    unlockIf("surf", surfs)
    unlockIf("surf_score", (tonumber(s.surfingHighScore) or 0) >= SURF_SCORE)
    local dex = type(s.pokedex) == "table" and s.pokedex.owned
    local n = 0
    for _, has in pairs(type(dex) == "table" and dex or {}) do if has == true then n = n + 1 end end
    progress("dex", math.min(n, DEX_GOAL))
  end

  -- Recomp Achievements says when a save is attached and its own records
  -- are in place; a new or older save starts the memo over
  if ach.events and ach.events.ready then
    mod.events:on(ach.events.ready, function()
      last = {}
      evaluate()
    end)
  end
  for _, name in ipairs({ "flag.changed", "pokemon.caught", "pokemon.evolved",
                          "pokemon.move_learned", "pokemon.received", "screen.popped" }) do
    mod.events:on(name, evaluate)
  end

  mod.events:on("map.entered", function(ev)
    if not onCart() then return end
    local s = save()
    if not s then return end
    -- the ship is back once you're Champion (pink_world_tweaks)
    if type(ev) == "table" and tostring(ev.mapId):find("^SS_ANNE") and flag(s, CHAMPION) then
      h:unlock("ss_anne_return")
    end
    evaluate()
  end)

  -- the captain's Champion line (pink_world_tweaks shows it once you have
  -- Cut and are Champion)
  mod.events:on("world.interacted", function(ev)
    if not (onCart() and type(ev) == "table") then return end
    local s = save()
    if s and ev.mapId == "SS_ANNE_CAPTAINS_ROOM" and ev.kind == "npc"
        and flag(s, CHAMPION) and flag(s, "EVENT_GOT_HM01") then
      h:unlock("captain_line")
    end
  end)

  -- Dragonair can also be fished, so the prize is the Game Corner's gift
  mod.events:on("pokemon.before_give", function(ev)
    if not (onCart() and type(ev) == "table") then return end
    local s = save()
    local map = s and type(s.player) == "table" and s.player.map
    if ev.species == "DRAGONAIR" and map == "GAME_CORNER_PRIZE_ROOM" then
      h:unlock("prize_dragonair")
    end
  end)
end
