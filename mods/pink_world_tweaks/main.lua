-- Pink World Tweaks
--
-- Pokemon Pink's changes to the world.  world_data.lua is generated from
-- Pink's disassembly by tools/gen_world_data.py and lists only what differs
-- from vanilla Yellow; every edit below is applied to the player's own
-- imported data at load time, so no vanilla map or tileset ships.

return function(mod)
  local function own(path)
    local src = mod:read(path)
    if type(src) ~= "string" then error("can't read " .. path) end
    local chunk, err = load(src, "@pink_world_tweaks/" .. path)
    if not chunk then error(err) end
    return chunk()
  end

  local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x) end
    return out
  end

  local W = own("world_data.lua")

  -- Map layouts: only the changed cells (two new Cut trees on Route 4 and in
  -- Fuchsia City, the Mansion ledges, the Silph Co. 11F warp spot, signs and
  -- route details).  Lists replace on patch, so copy the player's blocks and
  -- change just those cells.
  for mapId, cells in pairs(W.blocks) do
    local map = mod.content.maps:get(mapId)
    if map and map.blocks then
      local blocks = deepcopy(map.blocks)
      for cell, block in pairs(cells) do blocks[cell] = block end
      mod.content.maps:patch(mapId, { blocks = blocks })
    else
      mod.log:warn("no map %s to edit", mapId)
    end
  end

  -- Block definitions (which tiles make up a block) and walkable tiles.
  for tilesetId, defs in pairs(W.blockDefs) do
    local ts = mod.content.tilesets:get(tilesetId)
    if ts and ts.blocks then
      local blocks = deepcopy(ts.blocks)
      for index, tiles in pairs(defs) do blocks[index] = tiles end
      mod.content.tilesets:patch(tilesetId, { blocks = blocks })
    end
  end
  for tilesetId, list in pairs(W.walkable) do
    mod.content.tilesets:patch(tilesetId, { walkable = list })
  end

  -- field is a deep registry: lists append, which is what these want.
  mod.content.field:patch("cutTreeSwaps", W.cutTrees)              -- new Cut trees
  mod.content.field:patch("dungeonTransitionMaps", W.dungeon)      -- cave-style battle intro

  -- Yellow's unreachable Nugget in the Safari Zone Gate becomes a reachable
  -- FULL RESTORE on Vermilion Dock.  Removing an entry needs the whole key.
  local hidden = deepcopy(mod.content.field:get("hiddenItems")) or {}
  hidden.SAFARI_ZONE_GATE = nil
  hidden.VERMILION_DOCK = { { item = "FULL_RESTORE", x = 21, y = 0 } }
  mod.content.field:override("hiddenItems", hidden)

  -- The Linking Cable (pink_species) on the Celadon Dept. Store 4F shelf;
  -- text_pointers is deep, so this appends to the clerk's list.
  mod.content.text_pointers:patch("CeladonMart4F", {
    TEXT_CELADONMART4F_CLERK = { mart = { "ITEM_32" } },
  })

  -- Fly from the Celadon Dept. Store and Celadon Mansion roofs.  Pink only
  -- widens the Fly check; here both roofs count as outdoor maps, so Teleport
  -- also works there and a later Escape Rope or Dig can return to a roof.
  mod.content.maps:patch("CELADON_MART_ROOF", { outdoor = true })
  mod.content.maps:patch("CELADON_MANSION_ROOF", { outdoor = true })

  -- Warps Pink changed: Silph Co. 11F's elevator spot leads to the 1F lobby,
  -- and the Route 6 gate and Summer Beach House exits move with their map
  -- edits.  Lists replace on patch.
  for mapId, list in pairs(W.warps) do
    mod.content.maps:patch(mapId, { warps = list })
  end

  -- In-game trades: Pink rewrites all ten (field lists append, so replace
  -- the whole key).  Its Pikachu trade asks for a real Pikachu, which lives
  -- in the CLEFAIRY slot under pink_partner.
  if #W.trades > 0 then
    mod.content.field:override("trades", W.trades)
  end

  -- Pink's own lines (Pokemon Pink by jcferggy).
  mod.content.text:register("_PinkVermilionReturningChapText",
    "Excuse me, are\nyou the POKéMON\nleague champion?\f"
    .. "No ticket needed.\nPlease sir,\ncome on abord!")
  mod.content.text:register("_PinkVermilionDockSignText",
    "WELCOME TO\nVERMILION CITY!\f"
    .. "There is some\ngraffiti painted\nin the corner.\f"
    .. "{RIVAL} was\nhere! {PLAYER}\nis a loser!")

  -- The S.S. Anne comes back after the Champion.  Clearing the departure
  -- flag on entering Vermilion puts the ship back at the dock, and the
  -- sailor's usual "do you have a ticket?" path is the same "ship parked"
  -- branch Pink jumps to.  Leaving the ship again replays the departure, as
  -- in Pink.
  local CHAMPION = "EVENT_BEAT_CHAMPION_RIVAL"
  mod.content.map_scripts:register("VERMILION_CITY", {
    onEnter = function()
      if mod.world:getFlag(CHAMPION) and mod.world:getFlag("EVENT_SS_ANNE_LEFT") then
        mod.world:setFlag("EVENT_SS_ANNE_LEFT", false)
      end
    end,
    -- Walking past the sailor onto the dock (18,30 facing down): after the
    -- Champion, Pink greets you and lets you board without a ticket.  This
    -- runs before the engine's ticket check and stops it on this step.
    onStep = function(game, ow, x, y)
      if x ~= 18 or y ~= 30 then return false end
      if not (ow and ow.player and ow.player.facing == "down") then return false end
      if not mod.world:getFlag(CHAMPION) then return false end
      mod.world:queueScript({ { "show_text", "_PinkVermilionReturningChapText" } })
      return true
    end,
  })

  -- Pink restores a harbor sign on Vermilion Dock.
  mod.content.maps:patch("VERMILION_DOCK", {
    signs = { { x = 11, y = 1, text = "TEXT_PINK_VERMILIONDOCK_SIGN" } },
  })
  mod.content.map_scripts:register("VERMILION_DOCK", {
    talk = { TEXT_PINK_VERMILIONDOCK_SIGN = { { "show_text", "_PinkVermilionDockSignText" } } },
  })

  -- Pink's Game Corner prizes (Growlithe, Slowpoke, Raichu, Dragonair and
  -- new prices).  The engine keeps Yellow's lists out of reach, so the
  -- three counters get this mod's own handler; see prize_vendor.lua.
  local PrizeVendor = own("prize_vendor.lua")
  mod.content.map_scripts:register("GAME_CORNER_PRIZE_ROOM", {
    talk = {
      TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1 = PrizeVendor.handler(1),
      TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_2 = PrizeVendor.handler(2),
      TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_3 = PrizeVendor.handler(3),
    },
  })

  -- Oak heals your party after the Hall of Fame.  This runs before the
  -- engine's own Hall of Fame handler, which clears pendingHallOfFame.
  mod.content.map_scripts:register("HALL_OF_FAME", {
    onEnter = function(game)
      if game and game.save and game.save.pendingHallOfFame then
        mod.world:queueScript({ { "heal_party" } })
      end
    end,
  })
end
