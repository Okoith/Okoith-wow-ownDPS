if GetLocale() ~= "deDE" then return end

local _, ns = ...
local L = ns.L

L["UNIT_DPS"] = "DPS"
L["UNIT_HPS"] = "HPS"

L["LOADED"] = "Version %s geladen. Hilfe mit /owndps."
L["UNKNOWN_COMMAND"] = "Unbekannter Befehl. Hilfe mit /owndps."
L["NOT_IN_COMBAT"] = "Im Kampf nicht möglich."

L["HELP_HEADER"] = "Befehle (das Einstellungsmenü folgt in einer späteren Version):"
L["HELP_MODE"] = "/owndps mode dps|hps - Schaden oder Heilung anzeigen"
L["HELP_SOURCE"] = "/owndps source auto|current|overall - Datenquelle"
L["HELP_TOGGLE"] = "/owndps toggle rank|name|unit - Element ein- oder ausblenden"
L["HELP_MOVE"] = "/owndps move - Fenster zum Verschieben entsperren oder sperren"
L["HELP_RESET"] = "/owndps reset - Position zurücksetzen"
L["HELP_DEBUG"] = "/owndps debug on|off|clear|status - Debug-Log"
L["HELP_STATUS"] = "/owndps status - aktuelle Einstellungen anzeigen"

L["MODE_SET"] = "Modus: %s"
L["SOURCE_SET"] = "Datenquelle: %s"
L["SOURCE_AUTO"] = "Automatisch (im Kampf aktueller Kampf, sonst Gesamt)"
L["SOURCE_CURRENT"] = "Immer aktueller Kampf"
L["SOURCE_OVERALL"] = "Immer Gesamt"
L["ELEMENT_RANK"] = "Platz"
L["ELEMENT_NAME"] = "Name"
L["ELEMENT_UNIT"] = "Einheit"
L["ELEMENT_SHOWN"] = "%s: sichtbar"
L["ELEMENT_HIDDEN"] = "%s: ausgeblendet"

L["MOVE_ON"] = "Fenster entsperrt. Mit der linken Maustaste ziehen, danach erneut /owndps move eingeben."
L["MOVE_OFF"] = "Fenster gesperrt."
L["POSITION_RESET"] = "Position zurückgesetzt."

L["DEBUG_ON"] = "Debugmodus an. Das Log wird bei /reload oder Logout gespeichert."
L["DEBUG_OFF"] = "Debugmodus aus."
L["DEBUG_CLEARED"] = "Debug-Log geleert."
L["DEBUG_STATUS"] = "Debugmodus: %s, %d Einträge im Log."
L["ON"] = "an"
L["OFF"] = "aus"

L["STATUS"] = "Modus: %s | Datenquelle: %s | Profil: %s"
