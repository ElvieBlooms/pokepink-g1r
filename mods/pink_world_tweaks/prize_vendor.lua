-- Pink's Game Corner prize counters.
--
-- Yellow's prize lists live inside the engine's own story script, out of a
-- mod's reach, so this replaces the three counters' talk handlers with
-- Pink's lists.  The flow follows the original game's CeladonPrizeMenu
-- (pret engine/events/prize_menu.asm): it is written for this mod, not
-- copied from the engine.
--   1. No COIN CASE: say so and stop.
--   2. Otherwise offer this counter's three prizes plus NO THANKS.
--   3. Confirm the pick; then check coins.
--   4. A Pokémon goes to the party or a box and only then are coins taken;
--      an item goes to the bag, or nothing happens if the bag is full.
-- One purchase per conversation, as in the original.
--
-- Needs engine_internals: the text box, the prize window, the bag and the
-- script runner are engine modules.

local PrizeVendor = {}

-- Pink's prizes (data/events/prizes.asm, prize_mon_levels.asm).  Species use
-- the pink_partner slots: Pink's Raichu is the real Raichu, which lives in
-- the CLEFABLE slot.
PrizeVendor.WINDOWS = {
  {
    { kind = "mon", species = "ABRA", level = 12, cost = 200 },
    { kind = "mon", species = "GROWLITHE", level = 16, cost = 1100 },
    { kind = "mon", species = "SLOWPOKE", level = 20, cost = 1600 },
  },
  {
    { kind = "mon", species = "CLEFABLE", level = 26, cost = 3200 },   -- Raichu
    { kind = "mon", species = "DRAGONAIR", level = 28, cost = 5000 },
    { kind = "mon", species = "PORYGON", level = 24, cost = 9100 },
  },
  {
    { kind = "item", item = "TM_DRAGON_RAGE", cost = 3300 },
    { kind = "item", item = "TM_HYPER_BEAM", cost = 5500 },
    { kind = "item", item = "TM_SUBSTITUTE", cost = 7700 },
  },
}

-- the player's own game text, by id
local function say(game, id)
  return game.data.text[id] or ""
end

function PrizeVendor.handler(window)
  return function(game, ow, npc, done)
    local TextBox = require("src.render.TextBox")
    local PrizeCounter = require("src.ui.PrizeCounter")
    local stack = game.stack

    local function finished()
      if ow then ow.prizeWindow = nil end
      done()
    end
    local function tell(id)
      stack:push(TextBox.new(game, say(game, id), finished))
    end

    if not game.save.inventory.COIN_CASE then
      stack:push(TextBox.new(game, say(game, "_RequireCoinCaseText"), done))
      return
    end

    local rows = {}
    for _, prize in ipairs(PrizeVendor.WINDOWS[window]) do
      local name = prize.kind == "mon" and game.data.pokemon[prize.species].name
                   or game.data.items[prize.item].name
      rows[#rows + 1] = { name = name, cost = prize.cost, prize = prize }
    end

    local function purchase(prize)
      if (game.save.coins or 0) < prize.cost then
        tell("_SorryNeedMoreCoinsText")
        return
      end
      if prize.kind == "mon" then
        -- coins only change hands once the Pokémon has somewhere to go
        ow.runner:run({
          { "give_pokemon", prize.species, prize.level, false, true },
          { "jump_if_false", "full" },
          { "take_coins", prize.cost },
          { "jump", "end" },
          { "label", "full" },
          { "show_text", "_BoxIsFullText" },
          { "label", "end" },
        }, { onDone = finished })
        return
      end
      local Bag = require("src.inventory.Bag")
      if not Bag.add(game.save, prize.item, 1, game.data) then
        tell("_OopsYouDontHaveEnoughRoomText")
        return
      end
      game.save.coins = game.save.coins - prize.cost
      finished()
    end

    local prompt, menu
    local function closeMenu()
      while stack:top() == menu or stack:top() == prompt do stack:pop() end
    end

    local function openMenu()
      menu = PrizeCounter.new(game, rows, {
        onCancel = function()
          closeMenu()
          done()
        end,
        onPick = function(row, index)
          if ow then ow.prizeWindow = { prizes = rows, index = index } end
          closeMenu()
          local question = say(game, "_SoYouWantPrizeText"):gsub("{RAM:wNameBuffer}", row.name)
          stack:push(TextBox.new(game, question, nil, {
            instant = true,
            choice = function(yes)
              if yes then purchase(row.prize) else tell("_OhFineThenText") end
            end,
          }))
        end,
      })
      stack:push(menu)
    end

    stack:push(TextBox.new(game, say(game, "_ExchangeCoinsForPrizesText"), function()
      -- "Which prize do you want?" stays up under the prize window
      prompt = TextBox.new(game, say(game, "_WhichPrizeText"), nil, {
        instant = true,
        stay = { onShown = openMenu },
      })
      stack:push(prompt)
    end, { instant = true }))
  end
end

return PrizeVendor
