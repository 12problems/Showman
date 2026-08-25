local lovely = require("lovely")
local nativefs = require("nativefs")

function Showman.key_press_update(key)
	-- Showman Key Handler
	--  Print
	--sendDebugMessage(key.." pressed a")
	if key == "p" then
		--generateWithOptions(1000, Showman.config.SEEK.search_queue)
	elseif key == "l" then
		--generateShopUntil("Ride the Bus")
	end
end
