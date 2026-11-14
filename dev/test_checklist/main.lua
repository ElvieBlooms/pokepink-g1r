-- Test Checklist
--
-- A tester's checklist on the second screen (the AYN Thor's bottom screen, or
-- the desktop companion window).  It reads a markdown walkthrough, lets you
-- tick each line, flag a problem where it happens, and export a report with
-- the game log to the save folder.
--
-- Hooks render.compose to draw and push its own frame through ctx.secondScreen
-- and to read that screen's touches.  With Kanto Gear installed it's an app in
-- the Silph Store instead, and Gear stands down while it's open.  Logger is
-- wrapped to keep a longer log than the engine's 200 lines; CacheFs writes the
-- reports (both engine_internals).  It changes nothing in the game.
-- ------------------

return function(mod)
  local Checklist = assert(load(mod:read("checklist.lua"), "@test_checklist/checklist.lua"))()

  local W, H = 540, 620
  local LOG_KEEP = 3000

  mod.options:define({
    { key = "screen", type = "choice", label = "CHECKLIST",
      choices = { { "SECOND SCREEN", "show" }, { "OFF", "off" } }, default = "show" },
  })

  -- -------- the log, kept from load
  local logLines, started = {}, love.timer.getTime()
  local okL, Logger = pcall(require, "src.core.Logger")
  if okL and type(Logger) == "table" then
    for _, line in ipairs(Logger.history or {}) do logLines[#logLines + 1] = "[early] " .. line end
    for _, level in ipairs({ "info", "warn", "error" }) do
      local original = Logger[level]
      if type(original) == "function" then
        Logger[level] = function(fmt, ...)
          local ok, msg = pcall(string.format, tostring(fmt), ...)
          logLines[#logLines + 1] = ("%8.1f [%s] %s"):format(love.timer.getTime() - started, level,
            ok and msg or tostring(fmt))
          if #logLines > LOG_KEEP then table.remove(logLines, 1) end
          return original(fmt, ...)
        end
      end
    end
  end
  local function lastLog(n)
    local out = {}
    for i = math.max(1, #logLines - n + 1), #logLines do out[#out + 1] = logLines[i] end
    return out
  end

  -- -------- the walkthrough: a copy in the save folder wins over the bundled one
  local okFs, CacheFs = pcall(require, "src.import.CacheFs")
  local function atRoot(fn, ...)
    if not okFs then return nil end
    local saved = CacheFs.prefix
    CacheFs.prefix = ""
    local ok, a, b = pcall(fn, ...)
    CacheFs.prefix = saved
    if not ok then return nil, a end
    return a, b
  end
  local source = "bundled walkthrough.md"
  local body = atRoot(CacheFs.readAt, "test_checklist/walkthrough.md")
  if type(body) == "string" and body ~= "" then
    source = "test_checklist/walkthrough.md"
  else
    body = mod:read("walkthrough.md")
  end
  local list = Checklist.parse(body)
  mod.log:info("checklist: %d items in %d sections from %s", #list.items, #list.sections, source)

  -- -------- marks, kept in the save (per playthrough)
  local marks, notes, loaded = {}, {}, false
  local function loadMarks()
    if loaded or not mod.game then return end
    loaded = true
    local okM, saved = pcall(mod.save.get, mod.save, "marks", {})
    marks = okM and type(saved) == "table" and saved or {}
    local okN, savedNotes = pcall(mod.save.get, mod.save, "notes", {})
    notes = okN and type(savedNotes) == "table" and savedNotes or {}
  end
  -- a different save keeps its own ticks
  mod.events:on("game.ready", function() loaded, dirty = false, true end)

  local function saveMarks()
    pcall(mod.save.set, mod.save, "marks", marks)
    pcall(mod.save.set, mod.save, "notes", notes)
  end

  local function where()
    local okW, pos = pcall(function() return mod.world:current() end)
    if okW and type(pos) == "table" then
      return ("%s (%s,%s)"):format(tostring(pos.mapId), tostring(pos.x), tostring(pos.y))
    end
    return "not on a map"
  end

  -- -------- Kanto Gear or the option decides when it's up
  local gearOpen = false
  local gear = mod.find and mod.find("kanto_gear")
  local modules = gear and gear.exports and gear.exports.modules
  local viaGear = false
  local dirty = true
  if type(modules) == "table" and modules.api == 1 and type(modules.register) == "function" then
    local G, P, D = "3fa34d", "e8f5e9", "1b5e20"
    local rows = {}
    for r = 1, 24 do
      local row = {}
      for c = 1, 24 do
        local ch = "."
        if r >= 3 and r <= 22 and c >= 4 and c <= 21 then ch = "p" end
        if (r == 3 or r == 22) and c >= 4 and c <= 21 or (c == 4 or c == 21) and r >= 3 and r <= 22 then ch = "d" end
        for _, line in ipairs({ 7, 12, 17 }) do
          if r == line or r == line + 1 then
            if c >= 7 and c <= 9 then ch = "g" elseif c >= 11 and c <= 18 then ch = "d" end
          end
        end
        row[c] = ch
      end
      rows[r] = table.concat(row)
    end
    viaGear = modules.register({
      id = "test_checklist", label = "Checklist", category = "Tools", accent = "green",
      description = { "Tick off a walkthrough as you play,", "flag problems where they happen,", "and export a report with the log." },
      icon = { pal = { g = G, p = P, d = D }, rows = rows },
      open = function() gearOpen = true; dirty = true; return true end,
      shown = function() return gearOpen end,
      available = function() return true end,
    }) == true
  end
  local function active()
    if viaGear then return gearOpen end
    return mod.options:get("screen") ~= "off"
  end

  -- -------- layout
  local fonts = {}
  local function font(size)
    if not fonts[size] then
      local ok, f = pcall(love.graphics.newFont, size)
      fonts[size] = ok and f or love.graphics.getFont()
    end
    return fonts[size]
  end
  local HEADER, FOOTER, PAD = 64, 72, 14
  local C = {
    bg = { 0.09, 0.10, 0.12 }, panel = { 0.15, 0.16, 0.19 }, text = { 0.93, 0.93, 0.95 },
    dim = { 0.62, 0.64, 0.70 }, done = { 0.36, 0.78, 0.45 }, issue = { 0.95, 0.38, 0.38 },
    section = { 0.78, 0.33, 0.62 }, button = { 0.24, 0.26, 0.31 },
  }

  local view, scroll, rowsCache = "list", 0, nil
  local toast, toastUntil = nil, 0
  local function say(text) toast, toastUntil, dirty = text, love.timer.getTime() + 4, true end

  -- each row once: { kind, y, h, item index or section }
  local function layoutRows()
    if rowsCache then return rowsCache end
    local rows, y = {}, 0
    local f = font(18)
    for _, s in ipairs(list.sections) do
      rows[#rows + 1] = { kind = "section", section = s, y = y, h = 44 }
      y = y + 44
      for i = s.first, s.last do
        local _, lines = f:getWrap(list.items[i].text, W - PAD * 2 - 48)
        local h = math.max(44, #lines * f:getHeight() + 16)
        rows[#rows + 1] = { kind = "item", index = i, y = y, h = h }
        y = y + h
      end
    end
    rowsCache = { rows = rows, height = y }
    return rowsCache
  end
  local function listHeight() return H - HEADER - FOOTER end
  local function clampScroll()
    local maxScroll = math.max(0, layoutRows().height - listHeight())
    scroll = math.max(0, math.min(scroll, maxScroll))
  end

  local buttons = {}
  local function footerButtons()
    local labels = { view == "list" and "SECTIONS" or "LIST", "EXPORT", viaGear and "CLOSE" or "TOP" }
    local bw = (W - PAD * 4) / 3
    for i, label in ipairs(labels) do
      buttons[i] = { label = label, x = PAD + (i - 1) * (bw + PAD), y = H - FOOTER + 12, w = bw, h = FOOTER - 24 }
    end
    return buttons
  end

  -- -------- the report
  local function report()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local done, issues, total = Checklist.counts(list, marks)
    add("Test Checklist report")
    add("Checklist: " .. list.title .. " (" .. source .. ")")
    local okS, SaveData = pcall(require, "src.core.SaveData")
    local cart = okS and SaveData.getCart and SaveData.getCart() or nil
    add("Cart: " .. tostring(cart or "none"))
    local okP, P = pcall(require, "src.render.PaletteFX")
    if okP and P.modeLabel then add("COLORS: " .. tostring(P.modeLabel(P.mode))) end
    add("Position: " .. where())
    add(("Session time: %.0f s"):format(love.timer.getTime() - started))
    add(("Progress: %d of %d done, %d flagged"):format(done, total, issues))
    add("")
    add("== Flagged ==")
    for _, item in ipairs(list.items) do
      if marks[item.key] == "issue" then
        add("- [" .. item.section.title .. "] " .. item.text)
        local note = notes[item.key]
        if type(note) == "table" then
          add("  flagged at " .. tostring(note.where) .. (" after %.0f s"):format(tonumber(note.time) or 0))
          for _, l in ipairs(note.log or {}) do add("    " .. l) end
        end
      end
    end
    add("")
    add("== Sections ==")
    for _, s in ipairs(list.sections) do
      local d, i, t = Checklist.counts(list, marks, s.first, s.last)
      add(("%-44s %3d/%-3d %s"):format(s.title, d, t, i > 0 and (i .. " flagged") or ""))
    end
    add("")
    add("== Mods ==")
    local game = mod.game
    for _, m in ipairs(game and game.mods and game.mods.loaded or {}) do
      local man = m.manifest or {}
      add(("%s %s"):format(tostring(man.id), tostring(man.version)))
    end
    add("")
    add("== Log ==")
    for _, l in ipairs(logLines) do add(l) end
    return table.concat(lines, "\n") .. "\n"
  end

  local function export()
    if not okFs then return say("Can't write files on this build") end
    atRoot(CacheFs.createDirectory, "test_checklist")
    local n = 1
    while n < 1000 and atRoot(CacheFs.readAt, ("test_checklist/report-%03d.txt"):format(n)) do n = n + 1 end
    local path = ("test_checklist/report-%03d.txt"):format(n)
    local text = report()
    local ok, err = atRoot(CacheFs.write, path, text)
    if not ok then
      mod.log:warn("checklist: export failed: %s", tostring(err))
      return say("Export failed")
    end
    atRoot(CacheFs.write, "test_checklist/latest.txt", text)
    mod.log:info("checklist: report written to %s", path)
    say("Saved " .. path)
  end

  -- -------- input
  local touch
  local function tapList(x, y)
    if y < HEADER or y >= H - FOOTER then return end
    if not loaded then return say("Load a save first; ticks are kept in it") end
    local ly = y - HEADER + scroll
    for _, row in ipairs(layoutRows().rows) do
      if ly >= row.y and ly < row.y + row.h then
        if row.kind == "item" then
          local item = list.items[row.index]
          local mark = Checklist.nextMark(marks[item.key])
          marks[item.key] = mark
          if mark == "issue" then
            notes[item.key] = { where = where(), time = love.timer.getTime() - started, log = lastLog(40) }
            say("Flagged at " .. notes[item.key].where)
          else
            notes[item.key] = nil
          end
          saveMarks()
        end
        dirty = true
        return
      end
    end
  end
  local function tapSections(x, y)
    if y < HEADER or y >= H - FOOTER then return end
    local i = math.floor((y - HEADER + scroll) / 52) + 1
    local s = list.sections[i]
    if not s then return end
    for _, row in ipairs(layoutRows().rows) do
      if row.kind == "section" and row.section == s then scroll = row.y end
    end
    view = "list"
    clampScroll()
    dirty = true
  end
  local function tapFooter(x, y)
    for _, b in ipairs(footerButtons()) do
      if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
        if b.label == "SECTIONS" then view, scroll = "sections", 0
        elseif b.label == "LIST" then view, scroll = "list", 0
        elseif b.label == "EXPORT" then export()
        elseif b.label == "CLOSE" then gearOpen = false
        elseif b.label == "TOP" then scroll = 0 end
        dirty = true
        return true
      end
    end
    return false
  end
  local function onTouch(action, x, y)
    if action == "down" then
      touch = { x = x, y = y, lastY = y, moved = false }
    elseif action == "move" and touch then
      if math.abs(y - touch.y) > 12 then touch.moved = true end
      if touch.moved then
        scroll = scroll - (y - touch.lastY)
        if view == "list" then clampScroll() else scroll = math.max(0, scroll) end
        dirty = true
      end
      touch.lastY = y
    elseif (action == "up" or action == "tap") then
      local t = touch or { x = x, y = y, moved = false }
      touch = nil
      if t.moved then return end
      if y >= H - FOOTER then tapFooter(x, y)
      elseif view == "list" then tapList(x, y)
      else tapSections(x, y) end
    elseif action == "cancel" then
      touch = nil
    end
  end

  -- -------- drawing
  local canvas
  local function setColor(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end
  local function drawList()
    local f, top = font(18), HEADER - scroll
    for _, row in ipairs(layoutRows().rows) do
      local y = top + row.y
      if y + row.h >= HEADER and y < H - FOOTER then
        if row.kind == "section" then
          setColor(C.panel); love.graphics.rectangle("fill", 0, y, W, row.h)
          local d, i, t = Checklist.counts(list, marks, row.section.first, row.section.last)
          setColor(C.section); love.graphics.setFont(font(19))
          love.graphics.print(row.section.title, PAD, y + 11)
          setColor(i > 0 and C.issue or C.dim); love.graphics.setFont(font(16))
          love.graphics.printf(("%d/%d"):format(d, t) .. (i > 0 and ("  " .. i .. "!") or ""), 0, y + 13, W - PAD, "right")
        else
          local item = list.items[row.index]
          local mark = marks[item.key]
          local bx, by = PAD, y + 10
          setColor(C.dim); love.graphics.setLineWidth(2)
          love.graphics.rectangle("line", bx, by, 26, 26, 4)
          if mark == "done" then
            setColor(C.done); love.graphics.setLineWidth(4)
            love.graphics.line(bx + 5, by + 13, bx + 11, by + 20, bx + 22, by + 6)
          elseif mark == "issue" then
            setColor(C.issue); love.graphics.rectangle("fill", bx + 2, by + 2, 22, 22, 3)
            setColor(C.bg); love.graphics.setFont(font(18)); love.graphics.printf("!", bx, by + 2, 26, "center")
          end
          setColor(mark == "done" and C.dim or C.text); love.graphics.setFont(f)
          love.graphics.printf(item.text, PAD + 44, y + 8, W - PAD * 2 - 48, "left")
          setColor(C.panel); love.graphics.setLineWidth(1)
          love.graphics.line(PAD, y + row.h - 1, W - PAD, y + row.h - 1)
        end
      end
    end
  end
  local function drawSections()
    for i, s in ipairs(list.sections) do
      local y = HEADER + (i - 1) * 52 - scroll
      if y + 52 >= HEADER and y < H - FOOTER then
        local d, n, t = Checklist.counts(list, marks, s.first, s.last)
        setColor(C.panel); love.graphics.rectangle("fill", PAD, y + 4, W - PAD * 2, 44, 6)
        setColor(d == t and C.done or C.text); love.graphics.setFont(font(18))
        love.graphics.print(s.title, PAD * 2, y + 15)
        setColor(n > 0 and C.issue or C.dim); love.graphics.setFont(font(16))
        love.graphics.printf(("%d/%d"):format(d, t) .. (n > 0 and ("  " .. n .. "!") or ""), 0, y + 16, W - PAD * 2, "right")
      end
    end
  end
  local function draw()
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setShader()
    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3], 1)
    love.graphics.setScissor(0, HEADER, W, H - HEADER - FOOTER)
    if view == "list" then drawList() else drawSections() end
    love.graphics.setScissor()
    -- header
    setColor(C.panel); love.graphics.rectangle("fill", 0, 0, W, HEADER)
    local done, issues, total = Checklist.counts(list, marks)
    setColor(C.text); love.graphics.setFont(font(20))
    love.graphics.print(list.title, PAD, 10)
    setColor(C.dim); love.graphics.setFont(font(15))
    love.graphics.print(("%d of %d done"):format(done, total), PAD, 38)
    if issues > 0 then setColor(C.issue); love.graphics.printf(issues .. " flagged", 0, 38, W - PAD, "right") end
    setColor(C.done); love.graphics.rectangle("fill", 0, HEADER - 4, W * (total > 0 and done / total or 0), 4)
    -- footer
    setColor(C.panel); love.graphics.rectangle("fill", 0, H - FOOTER, W, FOOTER)
    love.graphics.setFont(font(17))
    for _, b in ipairs(footerButtons()) do
      setColor(C.button); love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8)
      setColor(C.text); love.graphics.printf(b.label, b.x, b.y + (b.h - font(17):getHeight()) / 2, b.w, "center")
    end
    if toast and love.timer.getTime() < toastUntil then
      love.graphics.setFont(font(16))
      setColor(C.bg, 0.92); love.graphics.rectangle("fill", PAD, H - FOOTER - 52, W - PAD * 2, 42, 8)
      setColor(C.text); love.graphics.printf(toast, PAD * 2, H - FOOTER - 41, W - PAD * 4, "center")
    end
    love.graphics.pop()
  end

  -- -------- the second screen
  local nextPush, wasActive, toastShown = 0, false, false
  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    local screen = type(ctx) == "table" and ctx.secondScreen
    local up = active()
    if up ~= wasActive then
      wasActive, dirty = up, true
      if up and not viaGear and screen and screen.setEnabled then pcall(screen.setEnabled, true) end
    end
    if not (up and screen and screen.push and screen.usable and screen.usable()) then return handled end
    loadMarks()
    for _ = 1, 64 do
      local event = screen.pollTouch and screen.pollTouch()
      if not event then break end
      local action, sx, sy = tostring(event):match("^(%a+),(%-?%d+),(%-?%d+)$")
      if not action then sx, sy = tostring(event):match("^(%d+),(%d+)$"); action = "tap" end
      if sx then onTouch(action, tonumber(sx), tonumber(sy)) end
    end
    local now = love.timer.getTime()
    local showingToast = toast ~= nil and now < toastUntil
    if showingToast ~= toastShown then toastShown, dirty = showingToast, true end
    if not dirty and now < nextPush then return handled end
    canvas = canvas or love.graphics.newCanvas(W, H, { dpiscale = 1 })
    draw()
    local okI, image = pcall(canvas.newImageData, canvas)
    if okI and image then
      pcall(screen.push, image, W, H, 0x17191f, "secondary")
    end
    dirty, nextPush = false, now + 1
    return handled
  end)

  mod.exports.report = report
end
