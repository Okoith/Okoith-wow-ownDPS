local _, ns = ...

-- Basistabelle (enUS). Fehlende Schlüssel liefern den Schlüssel selbst,
-- damit nie ein Lua-Fehler durch einen fehlenden Text entsteht.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

L["UNIT_DPS"] = "DPS"
L["UNIT_HPS"] = "HPS"

L["LOADED"] = "Version %s loaded. Type /owndps for help."
L["UNKNOWN_COMMAND"] = "Unknown command. Type /owndps for help."
L["NOT_IN_COMBAT"] = "Not possible during combat."

L["HELP_HEADER"] = "Commands (the settings panel will follow in a later version):"
L["HELP_MODE"] = "/owndps mode dps|hps - show damage or healing"
L["HELP_SOURCE"] = "/owndps source auto|current|overall - data source"
L["HELP_TOGGLE"] = "/owndps toggle rank|name|unit - show or hide an element"
L["HELP_MOVE"] = "/owndps move - unlock or lock the frame for dragging"
L["HELP_RESET"] = "/owndps reset - reset the position"
L["HELP_DEBUG"] = "/owndps debug on|off|clear|status - debug log"
L["HELP_STATUS"] = "/owndps status - show the current settings"

L["MODE_SET"] = "Mode: %s"
L["SOURCE_SET"] = "Data source: %s"
L["SOURCE_AUTO"] = "Automatic (current fight in combat, overall otherwise)"
L["SOURCE_CURRENT"] = "Always current fight"
L["SOURCE_OVERALL"] = "Always overall"
L["ELEMENT_RANK"] = "Rank"
L["ELEMENT_NAME"] = "Name"
L["ELEMENT_UNIT"] = "Unit"
L["ELEMENT_SHOWN"] = "%s: shown"
L["ELEMENT_HIDDEN"] = "%s: hidden"

L["MOVE_ON"] = "Frame unlocked. Drag it with the left mouse button, then type /owndps move again."
L["MOVE_OFF"] = "Frame locked."
L["POSITION_RESET"] = "Position reset."

L["DEBUG_ON"] = "Debug mode on. The log is saved on /reload or logout."
L["DEBUG_OFF"] = "Debug mode off."
L["DEBUG_CLEARED"] = "Debug log cleared."
L["DEBUG_STATUS"] = "Debug mode: %s, %d entries in the log."
L["ON"] = "on"
L["OFF"] = "off"

L["STATUS"] = "Mode: %s | Data source: %s | Profile: %s"
