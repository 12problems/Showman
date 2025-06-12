local lovely = require("lovely")
local nativefs = require("nativefs")
Showman.INITIALIZED = true
Showman.VER = "Showman v1.0.0-dev"

local last_status = false;
local setup = false;
local prev_pseudo = 1
local count = 1


function Showman.update(dt)

  --[[ count = count + 1
  if count > 100 and prev_pseudo ~= G.GAME.pseudorandom.seed then
    sendDebugMessage("### = Pseudoseed.seed changed!")
    prev_pseudo = G.GAME.pseudorandom.seed
  end
  if count > 100 then
    sendDebugMessage(prev_pseudo)
    sendDebugMessage(G.GAME.pseudorandom.seed)
    count = 1
  end ]]
  --[[ if not setup then
    sendDebugMessage("setup")
    last_status = Showman.config.SEEK.apply_showman
    setup = true
    return
  end

  if Showman.config.SEEK.apply_showman ~= last_status then
    sendDebugMessage("apply_showman toggled")
    last_status = Showman.config.SEEK.apply_showman
  end ]]

end
