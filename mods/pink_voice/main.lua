-- Pink Voice
--
-- Pokemon Pink's 42 Clefairy voice clips, in the slots of Yellow's Pikachu
-- clips (same numbering: clip n plays wherever Yellow plays Pikachu's n).
-- pink_partner turns Yellow's clips off; this turns the clip count back on
-- and points the engine's clip loader at this mod's files.
--
-- The engine loads clips straight from the imported audio folder (it
-- doesn't look in mods' overrides), so its clip player is wrapped to open
-- this mod's file instead (engine_internals).

return function(mod)
  local COUNT = 42

  -- clips back on: playCry("PIKACHU") -- the Clefairy slot -- uses them
  mod.content.audio:override("pikaCries", COUNT)

  local okS, Sound = pcall(require, "src.core.Sound")
  if not (okS and type(Sound) == "table" and type(Sound.playPikaCry) == "function") then
    mod.log:warn("can't reach the engine's clip player; Clefairy keeps her normal cry")
    mod.content.audio:override("pikaCries", false)
    return
  end
  if Sound.__pinkVoice then return end
  Sound.__pinkVoice = true

  local function ours(path)
    local n = type(path) == "string" and path:match("audio/pika_cries/cry_(%d%d)%.wav$")
    n = n and tonumber(n)
    if n and n >= 1 and n <= COUNT then
      return mod.assets:path(("assets/cries/cry_%02d.wav"):format(n))
    end
  end

  local play = Sound.playPikaCry
  Sound.playPikaCry = function(...)
    local audio = love and love.audio
    if not (audio and audio.newSource) then return play(...) end
    local newSource = audio.newSource
    audio.newSource = function(path, ...)
      return newSource(ours(path) or path, ...)
    end
    local ok, result = pcall(play, ...)
    audio.newSource = newSource
    if not ok then error(result, 0) end
    return result
  end
end
