-- Pink Look Picker
--
-- A cart extra, not part of Pokemon Pink: at NEW GAME, just before Oak asks
-- your name, he offers to let you pick your look.  YES opens PRISM, the
-- menu item that Facets, Emerald Lens and Crystal Lens share (or the one
-- mod's own screen when only one is loaded).  When you back out of it, Oak
-- carries on and shows you in your new look.
--
-- PRISM is built by those mods in the START menu's item hook, so the item
-- is asked for the same way the START menu asks (engine_internals: the
-- mods runtime).  With none of them loaded, Oak asks nothing.

return function(mod)
  mod.options:define({
    { key = "ask", type = "toggle", label = "ASK AT NEW GAME", default = true },
  })

  local okR, Runtime = pcall(require, "src.mods.Runtime")
  if not (okR and type(Runtime) == "table" and type(Runtime.call) == "function") then
    mod.log:warn("can't reach the mods runtime; Oak won't offer the look picker")
    return
  end

  -- the PRISM item (or the single visuals mod's own) as the START menu
  -- would get it, or nil
  local function prismItem(game)
    local ok, items = pcall(Runtime.call, "ui.start_menu.items",
      function(_, list) return list end, game, {})
    if not (ok and type(items) == "table") then return nil end
    for _, item in ipairs(items) do
      if type(item) == "table" and item.id == "prism" and type(item.onSelect) == "function" then
        return item
      end
    end
    return nil
  end

  local KEY = "pink_look_picker"

  mod.hooks:wrap("intro.oak_speech.build", function(nextFn, steps, speech)
    steps = nextFn(steps, speech)
    if type(steps) ~= "table" or mod.options:get("ask") == false then return steps end
    local game = type(speech) == "table" and speech.game or nil
    if not prismItem(game) then return steps end
    mod.ui.insertStepBefore(steps, "ask_player_name", {
      id = "pink_pick_look_ask",
      kind = "yesno",
      pic = "player",
      saveKey = KEY,
      text = "Before we go on,\nwould you like to\fpick your look?",
    })
    mod.ui.insertStepBefore(steps, "ask_player_name", {
      id = "pink_pick_look_open",
      kind = "fn",
      run = function(sp, done)
        local answers = type(sp) == "table" and sp.answers or nil
        local g = type(sp) == "table" and sp.game or game
        local item = answers and answers[KEY] == true and g and g.stack and prismItem(g)
        if not item then return done() end
        -- a screen that waits under PRISM: it's on top again once the
        -- player has backed out of PRISM and every page it opened
        local waiter = { isOpaque = false }
        function waiter.update(self)
          if g.stack:top() ~= self then return end
          g.stack:pop()
          done()
        end
        g.stack:push(waiter)
        local ok, err = pcall(item.onSelect)
        if not ok then
          mod.log:warn("PRISM didn't open: %s", tostring(err))
        end
      end,
    })
    return steps
  end)
end
