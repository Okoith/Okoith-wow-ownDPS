local ADDON_NAME, ns = ...

-- Debug-Log in der SavedVariable OwnDPSDebugLog (Ringpuffer).
-- Regel: Secret Values werden nie gespeichert, nur als "<SECRET>" markiert.

local Debug = {}
ns.Debug = Debug

local MAX_ENTRIES = 5000
local ERROR_REPEAT_SECONDS = 5

local issecret = issecretvalue or function() return false end

local loginNo = 0
local lastErrors = {}   -- Meldungstext -> Zeitpunkt, drosselt identische Fehler

-- Wandelt einen Wert in etwas Speicherbares um. Secret Values -> "<SECRET>".
local function S(v)
  if issecret(v) then return "<SECRET>" end
  if v == nil then return "nil" end
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" then return v end
  return "<" .. t .. ">"
end
Debug.S = S

function Debug:Init()
  if type(OwnDPSDebugLog) ~= "table" then OwnDPSDebugLog = {} end
  local log = OwnDPSDebugLog
  if type(log.entries) ~= "table" then log.entries = {} end
  log.logins = (tonumber(log.logins) or 0) + 1
  loginNo = log.logins
end

function Debug:IsEnabled()
  return ns.db ~= nil and ns.db.global.debug == true
end

function Debug:SetEnabled(enabled)
  ns.db.global.debug = enabled and true or false
  if enabled then self:LogMeta() end
end

function Debug:Count()
  local log = OwnDPSDebugLog
  return (log and log.entries) and #log.entries or 0
end

function Debug:Clear()
  local log = OwnDPSDebugLog
  if log and log.entries then wipe(log.entries) end
end

-- data: flache Tabelle mit festen String-Schlüsseln; jeder Wert wird mit S() bereinigt.
function Debug:Add(kind, data)
  if not self:IsEnabled() then return end
  local log = OwnDPSDebugLog
  if not log or not log.entries then return end

  local entry = {}
  if data then
    for k, v in pairs(data) do entry[k] = S(v) end
  end
  entry.kind = kind
  entry.t = math.floor(GetTime() * 100 + 0.5) / 100
  entry.time = date("%H:%M:%S")
  entry.login = loginNo
  entry.combat = InCombatLockdown() and true or false

  local e = log.entries
  e[#e + 1] = entry
  while #e > MAX_ENTRIES do table.remove(e, 1) end
end

-- Fehler aus pcall. Gleiche Meldungen höchstens alle paar Sekunden.
function Debug:Error(where, err)
  if not self:IsEnabled() then return end
  local msg = S(err)
  if type(msg) ~= "string" then msg = tostring(msg) end
  local key = where .. ":" .. msg
  local now = GetTime()
  if lastErrors[key] and now - lastErrors[key] < ERROR_REPEAT_SECONDS then return end
  lastErrors[key] = now
  self:Add("error", { where = where, err = msg })
end

local function damageMeterAvailability(out)
  local DM = C_DamageMeter
  if DM and DM.IsDamageMeterAvailable then
    local ok, avail, reason = pcall(DM.IsDamageMeterAvailable)
    out.dmAvailOk = ok
    if ok then
      out.dmAvail = avail
      out.dmAvailReason = reason
    else
      out.dmAvailErr = avail
    end
  else
    out.dmAvail = "API missing"
  end
  if C_CVar and C_CVar.GetCVar then
    local ok, v = pcall(C_CVar.GetCVar, "damageMeterEnabled")
    out.cvarDamageMeterEnabled = ok and v or "err"
  end
end

-- Version, Build, Sprache, Klasse und Einstellungen
function Debug:LogMeta()
  if not self:IsEnabled() then return end
  local gameVersion, build, buildDate, toc = GetBuildInfo()
  local out = {
    addonVersion = ns.VERSION,
    gameVersion = gameVersion, build = build, buildDate = buildDate, toc = toc,
    locale = GetLocale(),
    class = select(2, UnitClass("player")),
    profile = ns.db:GetCurrentProfile(),
    mode = ns.db.profile.mode,
    dataSource = ns.db.profile.dataSource,
    hasIsSecretValue = issecretvalue ~= nil,
  }
  damageMeterAvailability(out)
  self:Add("meta", out)
end

function Debug:LogInstance(extra)
  if not self:IsEnabled() then return end
  local out = extra or {}
  local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
  out.instName = name
  out.instType = instanceType
  out.diffID = difficultyID
  out.diffName = difficultyName
  out.maxPlayers = maxPlayers
  out.instID = instanceID
  out.groupSize = GetNumGroupMembers()
  damageMeterAvailability(out)
  self:Add("instance", out)
end
