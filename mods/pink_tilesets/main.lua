-- Pink Tilesets
--
-- Pokemon Pink's tile art, built on the player's machine at startup:
--   * every tile starts from the player's own imported Yellow sheet;
--   * tiles Pink took from Red/Blue are copied from the player's own Red
--     (or Blue) import, the way Facets borrows Crystal's art.  With neither
--     imported, Yellow's tile stays;
--   * tiles that exist in no cart are Pink's own, by jcferggy, and come from
--     assets/pink_tiles.png.
-- The result is written to save/mod-derived/pink_tilesets/tilesets/, where
-- the engine uses a loaded mod's derived art in place of the imported
-- image.  No vanilla tile ships with this mod.
--
-- Needs engine_internals: src.import.CacheFs reads the other games' imports
-- and writes the result.  (A mod's own love.filesystem is a stand-in whose
-- writes go to the mod's private storage, where the asset resolver never
-- looks.)

return function(mod)
  if not (love and love.image) then
    return -- headless tools (modkit) have no image access: nothing to build
  end

  local function own(path)
    local src = mod:read(path)
    if type(src) ~= "string" then error("can't read " .. path) end
    local chunk, err = load(src, "@pink_tilesets/" .. path)
    if not chunk then error(err) end
    return chunk()
  end

  local okFs, CacheFs = pcall(require, "src.import.CacheFs")
  if not okFs or type(CacheFs) ~= "table" or type(CacheFs.readAt) ~= "function"
      or type(CacheFs.write) ~= "function" then
    mod.log:warn("CacheFs is unavailable; Pink's tiles are not built")
    return
  end

  -- Where the imports keep their art, from the engine itself (the root its
  -- asset transforms read), so this follows the engine if it ever moves.
  local okT, Transform = pcall(require, "src.mods.AssetTransform")
  local ROOT = okT and type(Transform) == "table" and Transform.SOURCE_ROOT
  if type(ROOT) ~= "string" then
    mod.log:warn("the engine's art root is unavailable; Pink's tiles are not built")
    return
  end

  local function decode(bytes, name)
    if type(bytes) ~= "string" then return nil end
    local ok, img = pcall(function()
      return love.image.newImageData(love.filesystem.newFileData(bytes, name))
    end)
    return ok and img or nil
  end

  -- the player's imported sheet for one game, or nil when not imported
  local sheets = {}
  local function sheet(game, name)
    local key = game .. "/" .. name
    if sheets[key] == nil then
      local ok, bytes = pcall(CacheFs.readAt, game .. "/" .. ROOT .. "tilesets/" .. name .. ".png")
      sheets[key] = (ok and decode(bytes, key .. ".png")) or false
    end
    return sheets[key] or nil
  end

  local pinkTiles = decode(mod:read("assets/pink_tiles.png"), "pink_tiles.png")
  if not pinkTiles then
    mod.log:warn("assets/pink_tiles.png is missing; Pink's own tiles are skipped")
  end

  local TILE = 8
  local function copyTile(dst, dstIndex, src, srcIndex)
    local perRow = math.floor(src:getWidth() / TILE)
    local dstPerRow = math.floor(dst:getWidth() / TILE)
    local sx, sy = (srcIndex % perRow) * TILE, math.floor(srcIndex / perRow) * TILE
    local dx, dy = (dstIndex % dstPerRow) * TILE, math.floor(dstIndex / dstPerRow) * TILE
    if sy + TILE > src:getHeight() or dy + TILE > dst:getHeight() then return false end
    dst:paste(src, dx, dy, sx, sy, TILE, TILE)
    return true
  end

  -- CacheFs.prefix is the active game's folder for some callers; the
  -- derived folder sits at the cache root, so it's cleared around each call
  local function atRoot(fn, ...)
    local saved = CacheFs.prefix
    CacheFs.prefix = ""
    local ok, a, b = pcall(fn, ...)
    CacheFs.prefix = saved
    if not ok then return false, a end
    return a, b
  end

  local outDir = "save/mod-derived/" .. mod.id .. "/tilesets"
  if CacheFs.createDirectory then atRoot(CacheFs.createDirectory, outDir) end

  local built, fallbacks = 0, 0
  for name, changes in pairs(own("tile_data.lua")) do
    local base = sheet("yellow", name)
    if not base then
      mod.log:warn("no imported Yellow %s sheet; skipped", name)
    else
      local out = love.image.newImageData(base:getWidth(), base:getHeight())
      out:paste(base, 0, 0, 0, 0, base:getWidth(), base:getHeight())
      for index, from in pairs(changes) do
        local done = false
        if from.pink then
          done = pinkTiles and copyTile(out, index, pinkTiles, from.pink) or false
        else
          -- prefer the recorded game, then the other one
          local other = from.game == "red" and "blue" or "red"
          for _, game in ipairs({ from.game, other }) do
            local src = sheet(game, from.sheet)
            if src and copyTile(out, index, src, from.tile) then done = true break end
          end
        end
        if not done then fallbacks = fallbacks + 1 end -- Yellow's tile stays
      end
      local png = out:encode("png"):getString()
      local path = outDir .. "/" .. name .. ".png"
      local okWrite, writeErr = true, nil
      if atRoot(CacheFs.readAt, path) ~= png then okWrite, writeErr = atRoot(CacheFs.write, path, png) end
      if okWrite then
        built = built + 1
      else
        mod.log:warn("can't write %s (%s); Yellow's sheet stays", path, tostring(writeErr))
      end
    end
  end
  mod.log:info("built %d tilesets (%d tiles kept Yellow's art)", built, fallbacks)
end
