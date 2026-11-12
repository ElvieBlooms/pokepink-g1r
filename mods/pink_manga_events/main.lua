-- Pink Manga Events
--
-- Pokemon Pink's manga events.  So far: the BUSYBODY (Yellow's unused CHIEF
-- class) who waits for you on six maps, walks up, battles and moves on, then
-- waits in Cerulean's Trashed House for a rematch.
-- challenger_data.lua is generated from Pink's scripts by
-- tools/gen_challenger_data.py; text, sprites and the trainer picture are
-- Pokemon Pink's, by jcferggy.

return function(mod)
  local function own(path)
    local src = mod:read(path)
    if type(src) ~= "string" then error("can't read " .. path) end
    local chunk, err = load(src, "@pink_manga_events/" .. path)
    if not chunk then error(err) end
    return chunk()
  end

  local C = own("challenger_data.lua")

  -- the class: Yellow's unused CHIEF becomes Pink's BUSYBODY
  mod.content.trainers:patch("OPP_CHIEF", {
    name = "BUSYBODY",
    pic = mod.assets:path("assets/trainers/busybody.png"),
  })

  -- his overworld sprite (six walking frames, like the vanilla walkers)
  mod.content.sprites:override("SPRITE_PINK_BUSYBODY", {
    id = "SPRITE_PINK_BUSYBODY",
    image = mod.assets:path("assets/sprites/busybody.png"),
    frames = 6,
    walker = true,
  })

  for id, text in pairs(C.text) do
    mod.content.text:register(id, text)
  end

  -- Pink plays Yellow's unused song here; the engine doesn't import it, so
  -- the rival's encounter theme stands in.
  local MUSIC = "Music_MeetRival"

  local HOUSE_MAP, houseName

  local function scene(mapId, rec, objIndex, objName, cell)
    local t = rec.text
    local rows = {
      { "play_music", MUSIC },
      { "show_object", mapId, objName },
      { "show_text", t.Intro },
    }
    if rec.playerStep then
      rows[#rows + 1] = { "walk_npc", "player", { rec.playerStep } }
    end
    rows[#rows + 1] = { "walk_npc", objIndex, rec.approach[cell] }
    rows[#rows + 1] = { "show_text", t.WaitedHere }
    rows[#rows + 1] = { "save_end_battle_text", t.Defeated }
    rows[#rows + 1] = { "start_battle", "trainer", "OPP_CHIEF", rec.party }
    rows[#rows + 1] = { "jump_if_false", "leave" }
    rows[#rows + 1] = { "set_flag", rec.beatFlag }
    -- he heads to Cerulean's Trashed House for a rematch: his own house
    -- Busybody shows, the others hide
    for _, h in ipairs(C.house) do
      rows[#rows + 1] = { h.n == rec.houseShows and "show_object" or "hide_object",
                          HOUSE_MAP, houseName(h.n) }
    end
    if rec.playerFaceAfter then
      rows[#rows + 1] = { "face_player_dir", rec.playerFaceAfter }
    end
    if rec.faceAfter then
      rows[#rows + 1] = { "face_object", objIndex, rec.faceAfter }
    end
    rows[#rows + 1] = { "show_text", t.GoodLuckToYou }
    rows[#rows + 1] = { "play_music", MUSIC }
    rows[#rows + 1] = { "walk_npc", objIndex, rec.exit }
    rows[#rows + 1] = { "play_default_music" }
    rows[#rows + 1] = { "label", "leave" }
    rows[#rows + 1] = { "hide_object", mapId, objName }
    return rows
  end

  -- Cerulean's Trashed House: seven Busybodies on one tile, at most one
  -- shown at a time.  Each challenger you beat sends his own one there for
  -- a rematch; beating the Champion leaves the seventh, with his last team.
  HOUSE_MAP = "CERULEAN_TRASHED_HOUSE"
  houseName = function(n) return "PINK_TRASHED_HOUSE_BUSYBODY_" .. n end

  local houseLabel, houseIndex = nil, {}
  local house = mod.content.maps:get(HOUSE_MAP)
  if house then
    houseLabel = house.label
    local objects = {}
    for i, o in ipairs(house.objects or {}) do objects[i] = o end
    for _, h in ipairs(C.house) do
      local index = #objects + 1
      houseIndex[h.n] = index
      objects[index] = {
        index = index, name = houseName(h.n), sprite = "SPRITE_PINK_BUSYBODY",
        x = h.x, y = h.y, movement = "STAY", range = h.facing:upper(),
        text = "TEXT_PINK_TRASHED_HOUSE_BUSYBODY_" .. h.n, hidden = true,
        trainerClass = "OPP_CHIEF", trainerParty = h.party,
      }
    end
    mod.content.maps:patch(HOUSE_MAP, { objects = objects })
  else
    mod.log:warn("no %s; the rematches are skipped", HOUSE_MAP)
  end

  -- Trainer headers (sight range, beaten flag, Pink's lines) have no
  -- registry; the engine reads them fresh at each encounter, so add them to
  -- the loaded data once the game is up (engine_internals).
  mod.events:on("game.ready", function(ev)
    local data = ev and ev.game and ev.game.data
    if not (data and data.trainer_headers and houseLabel) then return end
    local perMap = data.trainer_headers[houseLabel] or {}
    data.trainer_headers[houseLabel] = perMap
    for _, h in ipairs(C.house) do
      if houseIndex[h.n] then
        perMap[houseIndex[h.n]] = {
          battle = h.text.Battle, won = h.text.EndBattle, after = h.text.AfterBattle,
          event = h.event, range = h.range,
        }
      end
    end
  end)

  -- Beating the Champion: the last Busybody waits in Cerulean.  This runs
  -- before the engine's own Hall of Fame handler clears pendingHallOfFame.
  mod.content.map_scripts:register("HALL_OF_FAME", {
    onEnter = function(game)
      if not (game and game.save and game.save.pendingHallOfFame) then return end
      local rows = {}
      for _, h in ipairs(C.house) do
        rows[#rows + 1] = { h.n == C.championShows and "show_object" or "hide_object",
                            HOUSE_MAP, houseName(h.n) }
      end
      mod.world:queueScript(rows)
    end,
  })

  for mapId, rec in pairs(C.maps) do
    local map = mod.content.maps:get(mapId)
    if not map then
      mod.log:warn("no map %s; its Busybody is skipped", mapId)
    else
      -- a hidden Busybody at Pink's spot; the scene shows and hides him
      local objects = {}
      for i, o in ipairs(map.objects or {}) do objects[i] = o end
      local objIndex = #objects + 1
      local objName = "PINK_" .. mapId .. "_BUSYBODY"
      objects[objIndex] = {
        index = objIndex, name = objName, sprite = "SPRITE_PINK_BUSYBODY",
        x = rec.object.x, y = rec.object.y, movement = "STAY",
        range = rec.object.facing:upper(), -- for STAY objects, range is the facing
        text = "TEXT_PINK_BUSYBODY", hidden = true,
      }
      mod.content.maps:patch(mapId, { objects = objects })

      -- the encounter: any of Pink's trigger cells, until he's beaten
      local cells = {}
      for i, c in ipairs(rec.coords) do cells[c[1] .. "," .. c[2]] = i end
      mod.content.map_scripts:register(mapId, {
        onStep = function(game, ow, x, y)
          local cell = cells[x .. "," .. y]
          if not cell or mod.world:getFlag(rec.beatFlag) then return false end
          mod.world:queueScript(scene(mapId, rec, objIndex, objName, cell))
          return true
        end,
      })
    end
  end
end
