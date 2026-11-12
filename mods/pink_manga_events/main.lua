-- Pink Manga Events
--
-- Pokemon Pink's manga events: the BUSYBODY (Yellow's unused CHIEF class)
-- who waits for you on six maps, walks up, battles and moves on, then waits
-- in Cerulean's Trashed House for a rematch; after the Champion, the
-- IMPOSTER at the Summer Beach House (manga Yellow in disguise) and a
-- visiting Pikachu; and Mew, not Mewtwo, in Cerulean Cave.
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
    baseMoney = 65, -- Pink pays 6500 x the last mon's level / 100
  })

  -- Overworld sheets for the Busybody and manga Yellow: Pink drew each frame
  -- over one of Yellow's own sprites, so pink_presentation builds them from
  -- the player's import (save/mod-derived/pink_presentation/sprites/).
  local okT, Transform = pcall(require, "src.mods.AssetTransform")
  local ROOT = okT and type(Transform) == "table" and Transform.SOURCE_ROOT
  local function sheet(rel, fallback)
    if type(ROOT) == "string" then return ROOT .. rel end
    mod.log:warn("the engine's art root is unavailable; %s stands in", fallback)
    local rec = mod.content.sprites:get(fallback)
    return rec and rec.image
  end

  mod.content.sprites:override("SPRITE_PINK_BUSYBODY", {
    id = "SPRITE_PINK_BUSYBODY",
    image = sheet("sprites/pink_busybody.png", "SPRITE_SUPER_NERD"),
    frames = 6,
    walker = true,
  })

  for id, text in pairs(C.text) do
    if mod.content.text:get(id) ~= nil then
      mod.content.text:override(id, text) -- a vanilla line Pink rewrote
    else
      mod.content.text:register(id, text)
    end
  end

  -- Pink plays Yellow's unused song here; the engine doesn't import it, so
  -- the rival's encounter theme stands in.
  local MUSIC = "Music_MeetRival"

  local HOUSE_MAP, houseName

  local function scene(mapId, rec, objIndex, objName, cell)
    local t = rec.text
    local rows = {}
    if rec.faceFirst then
      -- already standing there (the Celadon roof): he turns to look first
      rows[#rows + 1] = { "face_object", objIndex, rec.faceFirst }
    end
    for _, r in ipairs({
      { "play_music", MUSIC },
      { "show_object", mapId, objName },
      { "show_text", t.Intro },
    }) do rows[#rows + 1] = r end
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

  -- Pink's EVENT_BEAT_GREEN, under a name of this mod's own
  local ARRIVED = "EVENT_PINK_IMPOSTER_ARRIVED"

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
      -- the first time only: the Imposter and the Pikachu visit the beach
      if not mod.world:getFlag(ARRIVED) then
        for _, key in ipairs(C.beach.championShows) do
          rows[#rows + 1] = { "show_object", "SUMMER_BEACH_HOUSE", "PINK_SUMMERBEACHHOUSE_" .. key }
        end
        rows[#rows + 1] = { "set_flag", ARRIVED }
      end
      mod.world:queueScript(rows)
    end,
  })

  for mapId, rec in pairs(C.maps) do
    local map = mod.content.maps:get(mapId)
    if not map then
      mod.log:warn("no map %s; its Busybody is skipped", mapId)
    else
      -- a Busybody at Pink's spot, hidden until the scene shows him (on the
      -- Celadon roof he's there from the start, as in Pink)
      local objects = {}
      for i, o in ipairs(map.objects or {}) do objects[i] = o end
      local objIndex = #objects + 1
      local objName = "PINK_" .. mapId .. "_BUSYBODY"
      objects[objIndex] = {
        index = objIndex, name = objName, sprite = "SPRITE_PINK_BUSYBODY",
        x = rec.object.x, y = rec.object.y, movement = "STAY",
        range = rec.object.facing:upper(), -- for STAY objects, range is the facing
        text = "TEXT_PINK_BUSYBODY", hidden = not rec.startsShown,
      }
      mod.content.maps:patch(mapId, { objects = objects })

      -- the encounter: any of Pink's trigger cells, until he's beaten
      local cells = {}
      for i, c in ipairs(rec.coords) do cells[c[1] .. "," .. c[2]] = i end
      mod.content.map_scripts:register(mapId, {
        -- talking to him before he steps up: his opening line
        talk = { TEXT_PINK_BUSYBODY = { { "show_text", rec.text.Intro } } },
        onStep = function(game, ow, x, y)
          local cell = cells[x .. "," .. y]
          if not cell or mod.world:getFlag(rec.beatFlag) then return false end
          mod.world:queueScript(scene(mapId, rec, objIndex, objName, cell))
          return true
        end,
      })
    end
  end

  -- -------------------------------------------------------------------
  -- Summer Beach House: after the Champion, the IMPOSTER (dressed as you)
  -- and a visiting Pikachu turn up.  Talk to him and he's manga Yellow.
  local B = C.beach
  local BEACH = "SUMMER_BEACH_HOUSE"

  -- Yellow's unused JUGGLER becomes Pink's IMPOSTER; Pink plays the final
  -- battle theme for him and gives him smarter move choices
  mod.content.trainers:patch("OPP_UNUSED_JUGGLER", {
    name = "IMPOSTER",
    pic = mod.assets:path("assets/trainers/imposter.png"),
    baseMoney = 99,
    aiMods = { 1, 3 },
    battleTheme = "Music_FinalBattle",
  })

  mod.content.sprites:override("SPRITE_PINK_YELLOW", {
    id = "SPRITE_PINK_YELLOW",
    image = sheet("sprites/pink_yellow.png", "SPRITE_SAFARI_ZONE_WORKER"),
    frames = 6,
    walker = true,
  })

  -- the visiting Pikachu keeps Pink's SPRITE_CLEFAIRY: pink_partner swaps
  -- that sheet to Pikachu, as Pink does
  local PIKACHU_SPRITE = "SPRITE_CLEFAIRY"

  local beach = mod.content.maps:get(BEACH)
  local beachLabel, impIndex, yellowIndex, fairyIndex
  if beach then
    beachLabel = beach.label
    local objects = {}
    for i, o in ipairs(beach.objects or {}) do
      local copy = {}
      for k, v in pairs(o) do copy[k] = v end
      -- Pink moves the Surfin' Dude and the Clefairy aside
      local moved = (o.name == "SUMMERBEACHHOUSE_SURFINDUDE" and B.objects.SURFINDUDE)
                 or (o.name == "SUMMERBEACHHOUSE_PIKACHU" and B.objects.PIKACHU)
      if moved then copy.x, copy.y = moved.x, moved.y end
      objects[i] = copy
    end
    local function add(key, fields)
      local o = B.objects[key]
      local index = #objects + 1
      local rec = {
        index = index, name = "PINK_SUMMERBEACHHOUSE_" .. key,
        x = o.x, y = o.y, movement = o.movement, range = o.range,
        text = "TEXT_PINK_SUMMERBEACHHOUSE_" .. key, hidden = true,
      }
      for k, v in pairs(fields) do rec[k] = v end
      objects[index] = rec
      return index
    end
    -- he keeps Pink's trainer header, so he can spot you from one tile away
    impIndex = add("IMPOSTER", { sprite = "SPRITE_RED",
      trainerClass = "OPP_UNUSED_JUGGLER", trainerParty = B.objects.IMPOSTER.trainerParty })
    yellowIndex = add("YELLOW", { sprite = "SPRITE_PINK_YELLOW" })
    fairyIndex = add("FAIRY", { sprite = PIKACHU_SPRITE })
    mod.content.maps:patch(BEACH, { objects = objects })
  else
    mod.log:warn("no %s; the Imposter is skipped", BEACH)
  end

  local function name(key) return "PINK_SUMMERBEACHHOUSE_" .. key end

  local function battleRows()
    return {
      { "check_flag", B.event },
      { "jump_if_true", "beaten" },
      { "show_text", B.text.Battle },
      { "save_end_battle_text", B.text.EndBattle },
      { "start_battle", "trainer", "OPP_UNUSED_JUGGLER", B.objects.IMPOSTER.trainerParty },
      { "jump_if_false", "done" },
      { "set_flag", B.event },
      { "jump", "done" },
      { "label", "beaten" },
      { "show_text", B.text.AfterBattle },
      { "label", "done" },
    }
  end

  -- the way Yellow turns to you once the disguise drops
  local function faceToward(ow)
    local p = ow and ow.player
    if not p then return "left" end
    for _, f in ipairs(B.faceFrom) do
      if p.cellX == f.x and p.cellY == f.y then return f.dir end
    end
    local o = B.objects.YELLOW
    local dx, dy = (p.cellX or o.x) - o.x, (p.cellY or o.y) - o.y
    if math.abs(dx) >= math.abs(dy) then return dx > 0 and "right" or "left" end
    return dy > 0 and "down" or "up"
  end

  if beach then
    mod.content.map_scripts:register(BEACH, {
      talk = {
        TEXT_PINK_SUMMERBEACHHOUSE_IMPOSTER = function(game, ow, npc, done)
          local rows = {}
          if not (mod.world:getFlag(B.event) or mod.world:getFlag(B.revealFlag)) then
            rows = {
              { "fade", "out" },
              { "hide_object", BEACH, name("IMPOSTER") },
              { "show_object", BEACH, name("YELLOW") },
              { "set_flag", B.revealFlag },
              { "face_object", yellowIndex, faceToward(ow) },
              { "fade", "in" },
            }
          end
          for _, r in ipairs(battleRows()) do rows[#rows + 1] = r end
          ow.runner:run(rows, { npc = npc, onDone = done })
        end,
        TEXT_PINK_SUMMERBEACHHOUSE_YELLOW = battleRows(),
        TEXT_PINK_SUMMERBEACHHOUSE_FAIRY = {
          { "play_cry", B.cries.FAIRY, true },
          { "show_text", B.text.Fairy },
        },
      },
    })
  end

  -- Imposter's sight range and beaten flag, like the Trashed House headers
  mod.events:on("game.ready", function(ev)
    local data = ev and ev.game and ev.game.data
    if not (data and data.trainer_headers and beachLabel and impIndex) then return end
    local perMap = data.trainer_headers[beachLabel] or {}
    data.trainer_headers[beachLabel] = perMap
    perMap[impIndex] = {
      battle = B.text.Battle, won = B.text.EndBattle, after = B.text.AfterBattle,
      event = B.event, range = B.range,
    }
  end)

  -- -------------------------------------------------------------------
  -- Cerulean Cave: Mew waits where Mewtwo was, and comes with the OT name
  -- and ID of an official Game Freak event Mew (Pink's add_mon.asm)
  local M = C.mew
  local CAVE = "CERULEAN_CAVE_B1F"
  local cave = mod.content.maps:get(CAVE)
  if cave then
    local objects = {}
    for i, o in ipairs(cave.objects or {}) do
      local copy = {}
      for k, v in pairs(o) do copy[k] = v end
      if o.name == "CERULEANCAVEB1F_MEWTWO" then
        copy.pokemon, copy.level = M.species, M.level
      end
      objects[i] = copy
    end
    mod.content.maps:patch(CAVE, { objects = objects })
    -- Pink keeps the "Mew!" line and Mewtwo's cry, and the old beaten flag
    mod.content.map_scripts:register(CAVE, {
      talk = {
        TEXT_CERULEANCAVEB1F_MEWTWO = {
          { "check_flag", "EVENT_BEAT_MEWTWO" },
          { "jump_if_true", "beaten" },
          { "play_cry", "MEWTWO", true },
          { "engage_music", "Music_MeetMaleTrainer" },
          { "show_text", "_MewtwoBattleText" },
          { "static_battle", M.species, M.level, "EVENT_BEAT_MEWTWO" },
          { "jump", "end" },
          { "label", "beaten" },
          { "play_cry", "MEWTWO", true },
          { "show_text", "_MewtwoBattleText" },
          { "label", "end" },
        },
      },
    })
  else
    mod.log:warn("no %s; Mew is skipped", CAVE)
  end

  mod.events:on("pokemon.caught", function(ev)
    local mon = ev and ev.mon
    if mon and (ev.species or mon.species) == M.species then
      mon.ot, mon.otId = M.ot, M.otId
    end
  end)
end
