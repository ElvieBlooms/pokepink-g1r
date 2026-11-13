-- Pink Partner (prototype)
--
-- Yellow's engine identifies the partner by the internal species id
-- "PIKACHU" (follower, happiness, refusing to evolve, surfing).  Instead of
-- touching the engine, this mod swaps what the PIKACHU and CLEFAIRY slots
-- (and their evolutions RAICHU and CLEFABLE) contain: the partner keeps
-- the PIKACHU id, but everything the player sees -- name, dex number,
-- stats, types, sprites, cry, icon, palette, dex entry, moves -- is
-- Clefairy's.  The real CLEFAIRY slot carries Pikachu in turn.
--
-- Nothing here is copied out of the ROM: every record is read from the
-- player's own imported data at load time and moved between slots.

return function(mod)
  -- internal id -> the species whose data it should carry
  local SWAP = {
    PIKACHU  = "CLEFAIRY",
    CLEFAIRY = "PIKACHU",
    RAICHU   = "CLEFABLE",
    CLEFABLE = "RAICHU",
  }

  local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x) end
    return out
  end

  -- snapshot every source record before writing anything, so the swap
  -- never reads a slot it has already overwritten
  local mons, cries = {}, {}
  for id in pairs(SWAP) do
    mons[id] = deepcopy(mod.content.pokemon:get(id))
    cries[id] = deepcopy(mod.content.cries:get(id))
  end

  -- battle palettes are looked up by species id, so each slot names the
  -- palette of the species it now carries.  (The party icon needs nothing:
  -- it is looked up by dex number, which moves with the record.)
  local PALETTE = {
    PIKACHU = "PINKMON", RAICHU = "PINKMON",       -- Clefairy, Clefable
    CLEFAIRY = "YELLOWMON", CLEFABLE = "YELLOWMON", -- Pikachu, Raichu
  }

  for id, from in pairs(SWAP) do
    local src = mons[from]
    if not src then
      mod.log:warn("no vanilla record for %s; slot left alone", from)
    else
      local rec = deepcopy(src)
      rec.id = id
      rec.index = mons[id] and mons[id].index or rec.index
      rec.source = nil
      -- evolution targets live in swapped slots too
      for _, evo in ipairs(rec.evolutions or {}) do
        local target = evo.species
        for slot, carried in pairs(SWAP) do
          if carried == target then evo.species = slot break end
        end
      end
      -- the cry and palette follow the species, not the slot
      rec.cry = id
      rec.palette = PALETTE[id]
      mod.content.pokemon:override(id, rec)

      if cries[from] then mod.content.cries:override(id, cries[from]) end
    end
  end

  -- Yellow voices anything with the PIKACHU id with its recorded clips.
  -- Until Pink's own Clefairy clips are wired in, turn those off so the
  -- partner uses the (swapped) Clefairy chip cry instead.
  mod.content.audio:override("pikaCries", false)

  -- overworld follower: Clefairy walking frames by Anima_nel (purchased for
  -- this project; not covered by the repo's MIT license).  Six 16x16 frames
  -- in the engine's walker order: stand down, stand up, stand left, walk
  -- down, walk up, walk left (right is drawn mirrored).  trueColor keeps the
  -- sheet's own colours in full-colour mode: pink, recoloured from the
  -- artist's tan by changing only green and blue.  In the Game Boy palette
  -- modes the engine shades sprites by the red channel (>83% is transparent),
  -- so each colour's red value was lowered just enough to land on the right
  -- shade, and the recolour leaves red alone.
  -- Pink swaps the two overworld sheets: SPRITE_CLEFAIRY (the Fan Club pet,
  -- and the Pikachu Pink puts in Celadon and the beach house) shows Pikachu.
  -- That art is the game's own, so point at the player's imported Pikachu
  -- sheet (read before the follower override below replaces the record).
  -- Yellow's SPRITE_CLEFAIRY has three standing frames; the Pikachu sheet's
  -- first three are the same three facings.
  local vanillaPikachu = mod.content.sprites:get("SPRITE_PIKACHU")
  if vanillaPikachu and vanillaPikachu.image then
    mod.content.sprites:override("SPRITE_CLEFAIRY", {
      id = "SPRITE_CLEFAIRY",
      image = vanillaPikachu.image,
      frames = 3,
      walker = false,
      paletteSource = "SPRITE_PIKACHU",
    })
  end

  mod.content.sprites:override("SPRITE_PIKACHU", {
    id = "SPRITE_PIKACHU",
    image = mod.assets:path("assets/clefairy_follower.png"),
    frames = 6,
    walker = true,
    trueColor = true,
  })

  -- Tester option, off by default: turn it on in the mod manager to get one
  -- Moon Stone per save (the first time you enter a map), for checking that
  -- the partner refuses to evolve.
  mod.options:define({
    { key = "test_moon_stone", type = "toggle",
      label = "TEST: GIVE MOON STONE", default = false },
  })

  mod.events:on("map.entered", function()
    if not mod.options:get("test_moon_stone") then return end
    if not mod.world then return end
    if mod.save:get("got_test_moon_stone", false) then return end
    mod.save:set("got_test_moon_stone", true)
    mod.world:queueScript({
      { "give_item", "MOON_STONE", 1 },
    })
  end)
end
