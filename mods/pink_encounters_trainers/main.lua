-- Pink Encounters & Trainers
--
-- Pokemon Pink's wild tables, Super Rod tables and trainer parties.
-- data.lua is generated from Pink's disassembly by gen_pink_data.py and
-- lists only what differs from vanilla Yellow.  Species ids use the
-- pink_partner slots (internal PIKACHU is Clefairy, CLEFAIRY is Pikachu,
-- RAICHU is Clefable, CLEFABLE is Raichu), which is why pink_partner is a
-- dependency.

return function(mod)
  local function own(path)
    local src = mod:read(path)
    if type(src) ~= "string" then error("can't read " .. path) end
    local chunk, err = load(src, "@pink_encounters_trainers/" .. path)
    if not chunk then error(err) end
    return chunk()
  end

  local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x) end
    return out
  end

  local D = own("data.lua")

  -- wild grass / water tables (lists replace on patch)
  for mapId, rec in pairs(D.encounters) do
    mod.content.encounters:patch(mapId, rec)
  end

  -- Super Rod: field is a deep registry where lists append, so rebuild the
  -- whole superRod key from the merged view with Pink's maps swapped in
  local rod = deepcopy(mod.content.field:get("superRod")) or {}
  for mapId, slots in pairs(D.superRod) do rod[mapId] = slots end
  mod.content.field:override("superRod", rod)

  -- Trainer parties.  Yellow gives some trainers hand-picked moves
  -- (special_moves.asm); the engine applies vanilla's list by party number,
  -- so wherever Pink changed a class, the affected party slots get an
  -- explicit moveset instead: the default moves for that species and level
  -- (as the game builds them), then Pink's hand-picked moves on top.
  local function defaultMoves(species, level)
    local def = mod.content.pokemon:get(species)
    local moves = {}
    if not def then return moves end
    for _, m in ipairs(def.level1Moves or {}) do
      if #moves < 4 then moves[#moves + 1] = m end
    end
    for _, entry in ipairs(def.learnset or {}) do
      if entry.level > level then break end
      local known = false
      for _, m in ipairs(moves) do if m == entry.move then known = true break end end
      if not known then
        if #moves >= 4 then table.remove(moves, 1) end
        moves[#moves + 1] = entry.move
      end
    end
    return moves
  end

  local parties = {}
  local function partiesFor(opp)
    if not parties[opp] then
      if D.trainers[opp] then
        parties[opp] = deepcopy(D.trainers[opp])
      else
        local rec = mod.content.trainers:get(opp)
        local list = {}
        for i, party in ipairs(rec and rec.parties or {}) do
          list[i] = {}
          for j, mon in ipairs(party) do
            list[i][j] = { level = mon.level, species = mon.species, moves = mon.moves }
          end
        end
        parties[opp] = list
      end
    end
    return parties[opp]
  end

  for opp in pairs(D.trainers) do partiesFor(opp) end
  for opp, byParty in pairs(D.special) do
    local list = partiesFor(opp)
    for p, entry in pairs(byParty) do
      local party = list[p]
      for _, slot in ipairs(entry.slots) do
        local mon = party and party[slot]
        if mon then
          local moves = defaultMoves(mon.species, mon.level)
          for _, row in ipairs(entry.rows) do
            if row.mon == slot then
              moves[math.min(row.slot, #moves + 1)] = row.move
            end
          end
          mon.moves = moves
        end
      end
    end
  end

  for opp, list in pairs(parties) do
    mod.content.trainers:patch(opp, { parties = list })
  end
end
