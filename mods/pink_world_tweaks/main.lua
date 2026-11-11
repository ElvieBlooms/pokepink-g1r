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
end
