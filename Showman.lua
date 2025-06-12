Showman = {}
Showman.config = {}

Showman.config = {
  enable = true,
  debug_mode = false,
  keybinds = {
    a = "t",
    b = "lctrl",
  },
  SEEK = {
    search_depth = 100,
    search_depthID = 1,
    search_ante = 1,
    apply_showman = false,
  },
}

local lovely = require("lovely")
local nativefs = require("nativefs")

function initShowman()
	assert(load(nativefs.read(lovely.mod_dir .. "/Showman/Showman_main.lua")))()
	assert(load(nativefs.read(lovely.mod_dir .. "/Showman/Showman_keyhandler.lua")))()
	assert(load(nativefs.read(lovely.mod_dir .. "/Showman/Showman_seek.lua")))()
	Showman.PATH = findShowmanDirectory(lovely.mod_dir)
	Showman.loadConfig()
	assert(load(nativefs.read(lovely.mod_dir .. "/Showman/Showman_UI.lua")))()

end

function findShowmanDirectory(directory)
  for _, item in ipairs(nativefs.getDirectoryItems(directory)) do
    local itemPath = directory .. "/" .. item
    if
      nativefs.getInfo(itemPath, "directory")
      and string.lower(item):find("showman")
    then
      return itemPath
    end
  end
  return nil
end

function fileExists(filePath)
  return nativefs.getInfo(filePath) ~= nil
end

function Showman.loadConfig()
  local configPath = Showman.PATH .. "/config.lua"
  if not fileExists(configPath) then
    Showman.writeConfig()
  else
    local configFile, err = nativefs.read(configPath)
    if not configFile then
      error("Failed to read config file: " .. (err or "unknown error"))
    end
    Showman.config = STR_UNPACK(configFile) or Showman.config
  end
end

function Showman.writeConfig()
  local configPath = Showman.PATH .. "/config.lua"
  local success, err = nativefs.write(configPath, STR_PACK(Showman.config))
  if not success then
    error("Failed to write config file: " .. (err or "unknown error"))
  end
end

function Showman.trim(s)
   return s:match( "^%s*(.-)%s*$" )
end