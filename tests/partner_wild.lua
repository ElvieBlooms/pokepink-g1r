-- Pink Partner: wild Pokémon from other mods come out under their real names.
--
-- Loads pink_partner against a stub mod object and the engine's own hook
-- chain (src/mods/Hooks.lua), then runs the encounter hooks with and without
-- another mod's wrapper in the chain, the way OverworldController and
-- WorldAPI call them.
--
--   ENGINE=~/dev/gen1recomp-dev luajit tests/partner_wild.lua
-- ------------------

local here = arg[0]:match("^(.*)/tests/") or "."
local engine = os.getenv("ENGINE") or (os.getenv("HOME") .. "/dev/gen1recomp-dev")
package.path = engine .. "/?.lua;" .. package.path
package.loaded["src.core.Logger"] = setmetatable({}, { __index = function() return function() end end })
local Hooks = require("src.mods.Hooks")

local H = Hooks.new()
local function stubRegistry()
  return setmetatable({}, { __index = function() return function() end end })
end
local mod = {
  content = setmetatable({}, { __index = function(t, k) t[k] = stubRegistry() return t[k] end }),
  hooks = { wrap = function(_, name, fn, prio) H:wrap(name, fn, prio, "pink_partner") end },
  events = { on = function() end },
  options = { define = function() end, get = function() return false end },
  assets = { path = function(_, p) return p end },
  log = { warn = function() end, info = function() end },
  save = { get = function() end, set = function() end },
}
local f = assert(io.open(here .. "/mods/pink_partner/main.lua"))
local entry = assert(load(f:read("*a"), "@pink_partner/main.lua"))()
f:close()
entry(mod)

local checks, failed = 0, 0
local function check(cond, what)
  checks = checks + 1
  if not cond then failed = failed + 1 print("FAIL " .. what) end
end

-- the overworld's roll: encounter.roll, then encounter.species on a non-nil roll
local function roll(mapId, tableSpecies)
  local ctx = { mapId = mapId, terrain = "grass" }
  local enc = H:call("encounter.roll", function()
    return { species = tableSpecies, level = 5 }
  end, {}, ctx)
  if enc then enc = H:call("encounter.species", function(e) return e end, enc, ctx) end
  return enc
end

-- Pink's own tables
check(roll("ROUTE_2", "CLEFAIRY").species == "CLEFAIRY", "Route 2 Pikachu stays the real Pikachu")
check(roll("POWER_PLANT", "CLEFAIRY").species == "CLEFAIRY", "Power Plant Pikachu stays")
check(roll("ROUTE_2", "PIDGEY").species == "PIDGEY", "other species untouched")

-- another mod's table patch, read through the same roll
check(roll("MT_MOON_1F", "CLEFAIRY").species == "PIKACHU", "a table Clefairy elsewhere shows as Clefairy")
check(roll("ROUTE_2", "PIKACHU").species == "CLEFAIRY", "a table Pikachu is the real Pikachu")
check(roll("ROUTE_10", "RAICHU").species == "CLEFABLE", "a table Raichu is the real Raichu")
check(roll("MT_MOON_1F", "CLEFABLE").species == "RAICHU", "a table Clefable is the real Clefable")

-- the vanilla roll's own table is never changed
local slot = { species = "PIKACHU", level = 9 }
local out = H:call("encounter.species", function(e) return e end, slot, { mapId = "ROUTE_1" })
check(out ~= slot and slot.species == "PIKACHU" and out.level == 9, "swaps a copy, keeps the level")

-- another mod in the chain (a swarm), wrapping at the default priority
local H2 = H
H2:wrap("encounter.roll", function(next, encDef, ctx)
  local enc = next(encDef, ctx)
  if ctx.mapId == "ROUTE_2" or ctx.mapId == "MT_MOON_1F" then
    return { species = ctx.swarm, level = 7 }
  end
  return enc
end, 0, "catch_of_the_day")
local function swarm(mapId, species)
  local ctx = { mapId = mapId, terrain = "grass", swarm = species }
  local enc = H:call("encounter.roll", function() return { species = "PIDGEY", level = 3 } end, {}, ctx)
  return H:call("encounter.species", function(e) return e end, enc, ctx)
end
check(swarm("ROUTE_2", "PIKACHU").species == "CLEFAIRY", "a Pikachu swarm on Route 2 is real Pikachu")
check(swarm("ROUTE_2", "CLEFAIRY").species == "PIKACHU", "a Clefairy swarm on Route 2 is Clefairy")
check(swarm("MT_MOON_1F", "CLEFAIRY").species == "PIKACHU", "a Clefairy swarm in Mt. Moon is Clefairy")

-- another mod rewriting the species in place after the roll
H:wrap("encounter.species", function(next, enc, ctx)
  local e = next(enc, ctx)
  if ctx.mapId == "POWER_PLANT" and ctx.contest then e.species = "RAICHU" end
  return e
end, 0, "catch_of_the_day")
do
  local ctx = { mapId = "POWER_PLANT", terrain = "indoor", contest = true }
  local enc = H:call("encounter.roll", function() return { species = "CLEFAIRY", level = 33 } end, {}, ctx)
  enc = H:call("encounter.species", function(e) return e end, enc, ctx)
  check(enc.species == "CLEFABLE", "a species rewritten in place is still swapped")
end

-- fishing
local fished = H:call("encounter.fishing", function() return { species = "PIKACHU", level = 15 } end,
  "SUPER_ROD", "ROUTE_2", {})
check(fished.species == "CLEFAIRY", "a fished Pikachu is the real Pikachu")
check(H:call("encounter.fishing", function() return nil end, "OLD_ROD", "ROUTE_2", {}) == nil,
  "no bite stays no bite")

-- previews
local d = H:call("encounter.table", function(x) return x end,
  { PIDGEY = 100, CLEFAIRY = 13, PIKACHU = 50 }, { mapId = "ROUTE_2", preview = true })
check(d.CLEFAIRY == 63 and d.PIKACHU == nil and d.PIDGEY == 100, "Route 2 preview merges into real Pikachu")
d = H:call("encounter.table", function(x) return x end,
  { ZUBAT = 200, CLEFAIRY = 56 }, { mapId = "MT_MOON_1F", preview = true })
check(d.PIKACHU == 56 and d.CLEFAIRY == nil, "Mt. Moon preview shows Clefairy")

print(("%d checks, %d failed"):format(checks, failed))
os.exit(failed == 0 and 0 or 1)
