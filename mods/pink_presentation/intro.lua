-- Pink's intro, on top of the engine's Yellow intro.
--
-- The engine's YellowIntro plays Yellow's scenes: their order and timers,
-- the music, the scrolling, the palette strobes, the skip and the hand-off
-- to the title.  Pink keeps all of that and changes the animated sprites:
-- new layouts for Clefairy's run cycles, slower frames that play back and
-- forth, the thunderbolt as five frames, a new object in the close-up, and
-- a few spawn spots and the close-up's position.  So this takes over just
-- the intro's sprite steps (spawn, move/animate, draw) with Pink's data
-- (intro_data.lua, from tools/gen_intro_data.py), fixes up the scenes Pink
-- changed after the engine sets them up, and points the intro at Pink's
-- sheets (built into save/mod-derived/ by main.lua).
--
-- Written from Pink's engine/movie/intro_yellow.asm and data/sprite_anims.
-- Needs engine_internals.  If the engine's intro ever changes shape, this
-- steps aside and the engine's own intro plays.

local M = {}

-- Func_fa079's bob (Unkn_fa0aa, sine_table 32), +-8px over 64 frames.  The
-- cart's table rounds the peak down to 0; like the engine, use the true peak
-- so the glide doesn't pop.
local function bob(phase)
  local a = phase % 64
  local v = math.floor(8 * math.sin(math.pi * (a % 32) / 32))
  return a < 32 and v or -v
end

-- the movement routines, by YellowIntro_AnimatedObjectJumptable name
local MOVES = {
  Func_fa007 = function() end,
  -- x down by 4 to $58 (no object uses it)
  Func_fa008 = function(o) if o.x ~= 0x58 then o.x = (o.x - 4) % 256 end end,
  -- surfing: x up by 4 to $58, and y follows x + 1 (the cart compares the
  -- register still holding x)
  Func_fa014 = function(o)
    if o.x ~= 0x58 then
      o.x = (o.x + 4) % 256
      o.y = (o.x + 1) % 256
    end
  end,
  -- flying: rise 2px a frame to y $58, then bob
  Func_fa02b = function(o)
    if o.fieldB == 0 then
      if o.y ~= 0x58 then
        o.y = (o.y - 2) % 256
      else
        o.fieldB = 1
      end
    end
    if o.fieldB == 1 then
      o.yoff = bob(o.fieldC)
      o.fieldC = o.fieldC + 1
    end
  end,
  -- speed bar: x by its speed, wrapping
  Func_fa062 = function(o) o.x = (o.x + o.fieldB) % 256 end,
}

function M.install(I, Assets, ROOT)
  local ok, YI = pcall(require, "src.ui.YellowIntro")
  if not (ok and type(YI) == "table") then return false, "no YellowIntro" end
  for _, name in ipairs({ "new", "spawn", "updateObjects", "drawObjects", "startScene",
                          "quadFor", "bgLetterbox" }) do
    if type(YI[name]) ~= "function" then return false, "YellowIntro has no " .. name end
  end
  if YI.__pink then return true end
  YI.__pink = true

  local function frameset(index) return I.framesets[index + 1] end

  -- Pink's sheets: the engine opens the imported files directly, so swap in
  -- whatever Assets resolves them to (this mod's built sheets)
  local new = YI.new
  YI.new = function(...)
    local self = new(...)
    if self and Assets and type(ROOT) == "string" and love and love.graphics then
      for field, rel in pairs({ atlas1 = "intro/yellow_intro_1.png", atlas2 = "intro/yellow_intro_2.png" }) do
        local path = Assets.resolve(ROOT .. rel)
        if path and path ~= ROOT .. rel then
          local okImg, img = pcall(love.graphics.newImage, path)
          if okImg and img then
            self[field] = img
            self.bgDirty = true
          end
        end
      end
    end
    return self
  end

  YI.spawn = function(self, id, x, y)
    local spec = I.spawn[id]
    if not spec then return nil end
    local fs = frameset(spec.frameset)
    local obj = {
      id = id, fs = spec.frameset, move = MOVES[I.moves[spec.move + 1]] or MOVES.Func_fa007,
      x = x, y = y, xoff = 0, yoff = 0, step = 1, wait = fs.frames[1][2], held = false,
      fieldB = 0, fieldC = 0,
    }
    self.objects[#self.objects + 1] = obj
    return obj
  end

  YI.updateObjects = function(self)
    for _, obj in ipairs(self.objects) do
      if obj.move then obj.move(obj) end
      -- the frame script: count the frame's time down, then the next frame;
      -- at the end loop (dorestart) or hold the last frame (endanim)
      if not obj.held then
        obj.wait = obj.wait - 1
        if obj.wait <= 0 then
          local fs = frameset(obj.fs)
          if obj.step >= #fs.frames then
            if fs.loop then
              obj.step = 1
              obj.wait = fs.frames[1][2]
            else
              obj.held = true
            end
          else
            obj.step = obj.step + 1
            obj.wait = fs.frames[obj.step][2]
          end
        end
      end
    end
  end

  YI.drawObjects = function(self)
    local atlas = self.atlas2
    if not atlas then return end
    for _, obj in ipairs(self.objects) do
      local fs = obj.fs and frameset(obj.fs)
      local frameId = fs and fs.frames[obj.step] and fs.frames[obj.step][1]
      local frame = frameId and I.frames[frameId + 1]
      if frame then
        for _, e in ipairs(frame.oam) do
          -- OAM: screen = (x + dx - 8, y + dy - 16), all 8-bit
          local px = (obj.x + obj.xoff + e[2] - 8) % 256
          local py = (obj.y + obj.yoff + e[1] - 16) % 256
          if px < 160 and py < 144 then
            local quad = self:quadFor(atlas, (frame.base + e[3]) % 256)
            if e[4] then
              love.graphics.draw(atlas, quad, px + 8, py, 0, -1, 1)
            else
              love.graphics.draw(atlas, quad, px, py)
            end
          end
        end
      end
    end
  end

  -- scenes Pink sets up differently: its own spawn spots, the new object,
  -- and the close-up pasted a tile further left without Yellow's fix-ups
  local startScene = YI.startScene
  YI.startScene = function(self, scene, ...)
    local before = #self.objects
    local result = startScene(self, scene, ...)
    local rec = I.scenes[scene]
    if rec then
      for i = #self.objects, before + 1, -1 do table.remove(self.objects, i) end
      if rec.paste then
        self:bgLetterbox()
        local col, row = rec.paste[1], rec.paste[2]
        local tile = 0x04
        for r = 0, 7 do
          for c = 0, 11 do
            self.bg[(row + r) % 32][(col + c) % 32] = tile + c
          end
          tile = tile + 16
        end
        for _, p in ipairs(rec.pokes or {}) do self.bg[p[2]][p[1]] = p[3] end
        self.bgDirty = true
      end
      for _, s in ipairs(rec.spawns) do self:spawn(s[1], s[2], s[3]) end
    end
    return result
  end
  return true
end

return M
