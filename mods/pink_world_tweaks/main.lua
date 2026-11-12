-- Pink World Tweaks
--
-- Pokemon Pink's changes to the world.  world_data.lua is generated from
-- Pink's disassembly by tools/gen_world_data.py and lists only what differs
-- from vanilla Yellow; every edit below is applied to the player's own
-- imported data at load time, so no vanilla map or tileset ships.
-- text_data.lua (tools/gen_text_data.py) holds Pink's rewritten lines.

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

  -- Pink's rewritten lines everywhere else (text_data.lua, generated by
  -- tools/gen_text_data.py): the Clefairy-for-Pikachu wording, the Voltorb
  -- in Cerulean, the swapped Jenny/Damian gifts, new trainer lines.
  for id, line in pairs(own("text_data.lua")) do
    if mod.content.text:get(id) ~= nil then
      mod.content.text:override(id, line)
    else
      mod.content.text:register(id, line)
    end
  end

  -- Objects Pink gives a different sprite: the Celadon Mansion pets, the
  -- Copycat's dolls, the Fighting Dojo master.  Lists replace on patch.
  for mapId, sprites in pairs(W.objectSprites or {}) do
    local map = mod.content.maps:get(mapId)
    if map and map.objects then
      local objects = deepcopy(map.objects)
      for index, sprite in pairs(sprites) do
        if objects[index] then objects[index].sprite = sprite end
      end
      mod.content.maps:patch(mapId, { objects = objects })
    end
  end

  -- The Celadon Mansion pets: Pink's Bulbasaur and male Nidoran cry as
  -- themselves (the Pikachu is right already: under pink_partner the
  -- CLEFAIRY slot cries as Pikachu).
  mod.content.map_scripts:register("CELADON_MANSION_1F", {
    talk = {
      TEXT_CELADONMANSION1F_MEOWTH = {
        { "face_player" },
        { "play_cry", "BULBASAUR", true },
        { "show_text", "_CeladonMansion1FMeowthText" },
      },
      TEXT_CELADONMANSION1F_NIDORANF = {
        { "face_player" },
        { "play_cry", "NIDORAN_M", true },
        { "show_text", "_CeladonMansion1FNidoranFText" },
      },
    },
  })

  -- Officer Jenny and Damian swap gifts: Jenny's fire-starting Charmander,
  -- Damian's Squirtle.  Their scripts and flags stay the engine's; only the
  -- species changes on its way out.
  local GIFT_SWAP = {
    VERMILION_CITY = { SQUIRTLE = "CHARMANDER" },
    ROUTE_24 = { CHARMANDER = "SQUIRTLE" },
  }
  mod.events:on("pokemon.before_give", function(gift)
    local ow = gift and gift.ctx and gift.ctx.overworld
    local mapId = ow and ow.map and ow.map.id
    local swap = mapId and GIFT_SWAP[mapId]
    if swap and swap[gift.species] then gift.species = swap[gift.species] end
  end)

  -- The S.S. Anne captain has a new line for the Champion when the ship
  -- comes back.  Otherwise his usual script runs (the engine's own rows).
  local okStory, Story = pcall(require, "data.scripts.story")
  local captainRows = okStory and type(Story) == "table" and Story.SS_ANNE_CAPTAINS_ROOM
    and Story.SS_ANNE_CAPTAINS_ROOM.talk
    and Story.SS_ANNE_CAPTAINS_ROOM.talk.TEXT_SSANNECAPTAINSROOM_CAPTAIN
  if type(captainRows) == "table" then
    mod.content.map_scripts:register("SS_ANNE_CAPTAINS_ROOM", {
      talk = {
        TEXT_SSANNECAPTAINSROOM_CAPTAIN = function(game, ow, npc, done)
          local rows = captainRows
          if mod.world:getFlag("EVENT_GOT_HM01") and mod.world:getFlag(CHAMPION) then
            rows = { { "show_text", "_SSAnneCaptainsRoomCaptainReturn" } }
          end
          ow.runner:run(rows, { npc = npc, onDone = done })
        end,
      },
    })
  else
    mod.log:warn("can't find the captain's script; his Champion line is skipped")
  end

  -- Pink's fix for the Route 16 sign on the Route 17 boundary: in the cart
  -- you can't read a sign on the map you're facing into, so Pink repeats it
  -- just past Route 17's top edge (5, -1), readable from (5, 0) facing up.
  local r17 = mod.content.maps:get("ROUTE_17")
  if r17 then
    local signs = deepcopy(r17.signs or {})
    signs[#signs + 1] = { x = 5, y = -1, text = "TEXT_PINK_ROUTE17_ROUTE16_SIGN" }
    mod.content.maps:patch("ROUTE_17", { signs = signs })
    mod.content.map_scripts:register("ROUTE_17", {
      talk = { TEXT_PINK_ROUTE17_ROUTE16_SIGN = { { "show_text", "_Route16SignText" } } },
    })
  end

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
