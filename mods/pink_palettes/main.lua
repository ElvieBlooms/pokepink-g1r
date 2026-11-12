-- Pink Palettes
--
-- Pokemon Pink's colours.  palette_data.lua is generated from Pink's
-- disassembly by tools/gen_palette_data.py and lists only what differs from
-- vanilla Yellow.

return function(mod)
  local function own(path)
    local src = mod:read(path)
    if type(src) ~= "string" then error("can't read " .. path) end
    local chunk, err = load(src, "@pink_palettes/" .. path)
    if not chunk then error(err) end
    return chunk()
  end

  local P = own("palette_data.lua")

  -- Super Game Boy palettes, including Pink's two new ones
  -- (CAVE_YELLOW, GRAYMON_YELLOW).
  for name, colours in pairs(P.sgb) do
    mod.content.palettes:override(name, colours)
  end

  -- Species that get their own palette in Pink: Raticate, the Geodude line,
  -- Cubone and Marowak on the new grey; Jynx on 0F.  Keys are pink_partner
  -- slots.
  for slot, name in pairs(P.species) do
    mod.content.pokemon:patch(slot, { palette = name })
  end

  -- In the colour-pack mode the engine colours a species through Yellow's
  -- Game Boy Color palettes, but a species with its own `palette` field
  -- (Clefairy in the PIKACHU slot, and the species above) skips that and
  -- gets the Super Game Boy set, whose white is Yellow's warm 31,31,30: a
  -- cream box behind the partner's picture and the battle text.  Such a
  -- species is looked up the way every other one is (engine_internals).
  local okPF, PaletteFX = pcall(require, "src.render.PaletteFX")
  local okGV, GameVersion = pcall(require, "src.core.GameVersion")
  if okPF and type(PaletteFX) == "table" and type(PaletteFX.monPal) == "function"
      and type(PaletteFX.pal) == "function" and type(PaletteFX.usesGbcPack) == "function"
      and okGV and type(GameVersion) == "table" and type(GameVersion.isYellow) == "function" then
    if not PaletteFX.__pinkMonPal then
      PaletteFX.__pinkMonPal = true
      local monPal = PaletteFX.monPal
      PaletteFX.monPal = function(data, species, transformed, ...)
        if not transformed and GameVersion.isYellow() and PaletteFX.usesGbcPack() then
          local def = data and data.pokemon and data.pokemon[species]
          if type(def) == "table" and def.palette then
            local pal = PaletteFX.pal(data, def.palette)
            if pal then return pal end
          end
        end
        return monPal(data, species, transformed, ...)
      end
    end
  else
    mod.log:warn("can't reach the palette lookup; the partner may sit on a cream box in colour-pack mode")
  end

  -- Map palettes: a map's own palette wins over the engine's lookup.
  for _, mapId in ipairs({ "CERULEAN_CAVE_1F", "CERULEAN_CAVE_2F", "CERULEAN_CAVE_B1F" }) do
    mod.content.maps:patch(mapId, { palette = "CAVE_YELLOW" })
  end
  for _, mapId in ipairs({ "TRADE_CENTER", "COLOSSEUM" }) do
    mod.content.maps:patch(mapId, { palette = "GRAYMON_YELLOW" })
  end

  -- Game Boy Color palettes: no registry reaches them, and the engine reads
  -- them fresh from the loaded data on every lookup, so write Pink's into
  -- the loaded data once the game is up (engine_internals).
  mod.events:on("game.ready", function(ev)
    local data = ev and ev.game and ev.game.data
    local pal = data and data.palettes
    if not pal then return end
    pal.cgbBase = pal.cgbBase or {}
    for name, colours in pairs(P.cgb) do
      pal.cgbBase[name] = colours
    end
  end)
end
