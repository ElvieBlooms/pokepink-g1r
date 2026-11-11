-- Pink Species
--
-- Pokemon Pink's species changes and the Linking Cable.
-- species_data.lua is generated from Pink's disassembly by
-- tools/gen_pink_data.py and lists only fields that differ from vanilla
-- Yellow, keyed by the pink_partner slot (PIKACHU carries Clefairy).

return function(mod)
  local function own(path)
    local src = mod:read(path)
    if type(src) ~= "string" then error("can't read " .. path) end
    local chunk, err = load(src, "@pink_species/" .. path)
    if not chunk then error(err) end
    return chunk()
  end

  -- learnsets, TM/HM lists and evolutions (lists replace on patch)
  for slot, fields in pairs(own("species_data.lua")) do
    mod.content.pokemon:patch(slot, fields)
  end

  -- The Linking Cable: Pink turns Yellow's unused ITEM_32 into a consumable
  -- that works like an evolution stone, so the trade evolutions (Kadabra,
  -- Machoke, Graveler, Haunter) can happen in single-player.  Those species
  -- list it as an ITEM evolution in species_data.lua.
  mod.content.item_effects:register("PINK_LINKING_CABLE", {
    field = true, battle = false, needsTarget = true,
    use = function(ctx)
      local mon = ctx.target
      local def = mon and ctx.data.pokemon[mon.species]
      for _, evo in ipairs(def and def.evolutions or {}) do
        if evo.method == "ITEM" and evo.item == ctx.itemId then
          return "consumed", nil, { evolveTo = evo.species }
        end
      end
      return "failed", { "It won't have\nany effect." }
    end,
  })
  mod.content.items:patch("ITEM_32", {
    name = "LINKINGCABLE", price = 8000,
    effect = "PINK_LINKING_CABLE", needsTarget = true,
  })
end
