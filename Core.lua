local ADDON_NAME, ns = ...
local L = ns.L

-- Init, AceDB, Events, Ticker, Slash-Befehle

local UPDATE_INTERVAL = 0.25     -- SPEC Abschnitt 8
local STATUS_INTERVAL = 1.0      -- Debug-Statuseintrag im Kampf
local POST_COMBAT_STATUS = 5     -- Sekunden nach Kampfende weiter Status loggen

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "?"

local WHITE = { r = 1, g = 1, b = 1 }

ns.defaults = {
  profile = {
    mode = "dps",            -- "dps" | "hps"
    dataSource = "auto",     -- "auto" | "current" | "overall"
    showRank = true,
    showName = false,
    showUnit = true,
    colors = {
      rank = WHITE,
      name = WHITE,
      value = WHITE,
      unit = WHITE,
    },
    font = {
      size = 14,
      outline = "OUTLINE",   -- "" | "OUTLINE" | "THICKOUTLINE"
      shadow = true,
    },
    scale = 1,
    alpha = 1,
    position = { point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },
  },
  global = {
    debug = false,
  },
}

local function Print(msg)
  print("|cff33ff99OwnDPS|r: " .. msg)
end
ns.Print = Print

---------------------------------------------------------------------------
-- Aktualisierung
---------------------------------------------------------------------------

local lastStatus = 0
local postCombatUntil = 0

local function logStatus(s)
  local now = GetTime()
  if not (s.inCombat or now < postCombatUntil) then return end
  if now - lastStatus < STATUS_INTERVAL then return end
  lastStatus = now

  local last = ns.Display.last
  local out = {
    mode = ns.db.profile.mode,
    dataSource = ns.db.profile.dataSource,
    sessionType = s.sessionType,
    meterType = s.meterType,
    apiOk = s.apiOk,
    rank = s.rank,
    count = s.count,
    hasValue = s.hasValue,
    valueSecret = issecretvalue and issecretvalue(s.value) or false,
    value = s.value,                   -- wird bei Secret zu "<SECRET>"
    err = s.err,
    abbrevOk = last.abbrevOk,
    formattedSecret = issecretvalue and issecretvalue(last.formatted) or false,
    formatted = last.formatted,        -- wird bei Secret zu "<SECRET>"
    setTextOk = last.setTextOk,
    shown = last.shown,
  }
  local DM = C_DamageMeter
  if DM and DM.GetSessionDurationSeconds and s.sessionType ~= nil then
    local ok, dur = pcall(DM.GetSessionDurationSeconds, s.sessionType)
    out.durationOk = ok
    if ok then out.duration = dur end
  end
  ns.Display:DebugInfo(out)
  ns.Debug:Add("status", out)
end

function ns:Update()
  local s = ns.Data:Read()
  ns.Display:Render(s)
  if s.err then ns.Debug:Error("Data:Read", s.err) end
  if ns.Debug:IsEnabled() then logStatus(s) end
end

local function safeUpdate()
  local ok, err = pcall(ns.Update, ns)
  if not ok then ns.Debug:Error("Update", err) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
  if name ~= ADDON_NAME then return end
  events:UnregisterEvent("ADDON_LOADED")

  -- Ohne dritten Parameter legt AceDB ein Profil pro Charakter an ("Name - Realm")
  ns.db = LibStub("AceDB-3.0"):New("OwnDPSDB", ns.defaults)
  ns.Debug:Init()
end

function handlers.PLAYER_LOGIN()
  ns.Display:Create()
  ns.Debug:LogMeta()
  C_Timer.NewTicker(UPDATE_INTERVAL, safeUpdate)
  safeUpdate()
  Print(L["LOADED"]:format(ns.VERSION))
end

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
  ns.Debug:LogInstance({ initial = isInitialLogin, reload = isReloadingUi })
end

function handlers.PLAYER_REGEN_DISABLED()
  ns.Debug:Add("combatStart", { groupSize = GetNumGroupMembers() })
  lastStatus = 0
  safeUpdate()
end

function handlers.PLAYER_REGEN_ENABLED()
  ns.Debug:Add("combatEnd")
  postCombatUntil = GetTime() + POST_COMBAT_STATUS
  ns.Display:RegisterVisibility()   -- falls es beim Laden im Kampf fehlgeschlagen ist
  safeUpdate()
end

function handlers.DAMAGE_METER_CURRENT_SESSION_UPDATED()
  safeUpdate()
end

function handlers.DAMAGE_METER_RESET()
  ns.Debug:Add("damageMeterReset")
  safeUpdate()
end

events:SetScript("OnEvent", function(_, event, ...)
  local handler = handlers[event]
  if handler then
    local ok, err = pcall(handler, ...)
    if not ok then
      if ns.db then ns.Debug:Error(event, err) end
      if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        geterrorhandler()(err)
      end
    end
  end
end)

for event in pairs(handlers) do
  local ok = pcall(events.RegisterEvent, events, event)
  if not ok then Print("Event unknown: " .. event) end
end

---------------------------------------------------------------------------
-- Slash-Befehle (Einstellungsmenü folgt in Meilenstein 3)
---------------------------------------------------------------------------

local SOURCE_NAMES = { auto = "SOURCE_AUTO", current = "SOURCE_CURRENT", overall = "SOURCE_OVERALL" }
local TOGGLES = { rank = { "showRank", "ELEMENT_RANK" }, name = { "showName", "ELEMENT_NAME" }, unit = { "showUnit", "ELEMENT_UNIT" } }

local function modeName(mode)
  return mode == "hps" and L["UNIT_HPS"] or L["UNIT_DPS"]
end

local function printHelp()
  Print(L["HELP_HEADER"])
  for _, key in ipairs({ "HELP_MODE", "HELP_SOURCE", "HELP_TOGGLE", "HELP_MOVE", "HELP_RESET", "HELP_DEBUG", "HELP_STATUS" }) do
    print("  " .. L[key])
  end
end

local commands = {}

function commands.mode(arg)
  if arg ~= "dps" and arg ~= "hps" then printHelp(); return end
  ns.db.profile.mode = arg
  ns.Debug:Add("setting", { mode = arg })
  Print(L["MODE_SET"]:format(modeName(arg)))
  safeUpdate()
end

function commands.source(arg)
  if not SOURCE_NAMES[arg] then printHelp(); return end
  ns.db.profile.dataSource = arg
  ns.Debug:Add("setting", { dataSource = arg })
  Print(L["SOURCE_SET"]:format(L[SOURCE_NAMES[arg]]))
  safeUpdate()
end

function commands.toggle(arg)
  local t = TOGGLES[arg]
  if not t then printHelp(); return end
  local p = ns.db.profile
  p[t[1]] = not p[t[1]]
  Print((p[t[1]] and L["ELEMENT_SHOWN"] or L["ELEMENT_HIDDEN"]):format(L[t[2]]))
  safeUpdate()
end

function commands.move()
  local on = not ns.Display.moving
  ns.Display:SetMoveMode(on)
  Print(on and L["MOVE_ON"] or L["MOVE_OFF"])
end

function commands.reset()
  ns.Display:ResetPosition()
  Print(L["POSITION_RESET"])
end

function commands.status()
  local p = ns.db.profile
  Print(L["STATUS"]:format(modeName(p.mode), L[SOURCE_NAMES[p.dataSource] or "SOURCE_AUTO"], ns.db:GetCurrentProfile()))
  Print(L["DEBUG_STATUS"]:format(ns.Debug:IsEnabled() and L["ON"] or L["OFF"], ns.Debug:Count()))
end

function commands.debug(arg)
  if arg == "on" then
    ns.Debug:SetEnabled(true)
    ns.Debug:LogInstance({ reason = "debugOn" })
    Print(L["DEBUG_ON"])
  elseif arg == "off" then
    ns.Debug:Add("debugOff")
    ns.Debug:SetEnabled(false)
    Print(L["DEBUG_OFF"])
  elseif arg == "clear" then
    ns.Debug:Clear()
    Print(L["DEBUG_CLEARED"])
  else
    Print(L["DEBUG_STATUS"]:format(ns.Debug:IsEnabled() and L["ON"] or L["OFF"], ns.Debug:Count()))
  end
end

SLASH_OWNDPS1 = "/owndps"
SlashCmdList.OWNDPS = function(msg)
  if not ns.db then return end
  local cmd, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "" or cmd == "help" then
    printHelp()
  elseif commands[cmd] then
    commands[cmd](arg)
  else
    Print(L["UNKNOWN_COMMAND"])
  end
end
