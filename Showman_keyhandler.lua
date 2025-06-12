local lovely = require("lovely")
local nativefs = require("nativefs")

function Showman.key_press_update(key)
	-- Showman Key Handler
	--  Print
	--sendDebugMessage(key.." pressed a")
	if key == "p" then
		generateShop(1000)
	elseif key == "l" then
		generateShopUntil("Ride the Bus")
	end
end
