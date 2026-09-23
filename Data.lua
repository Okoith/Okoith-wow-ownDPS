local ADDON_NAME, ns = ...

-- Zugriff auf C_DamageMeter. Jeder API-Aufruf und jeder Feldzugriff steht in pcall.
-- Werte, die geheim sein können (amountPerSecond), werden nur gespeichert und
-- weitergereicht: kein Rechnen, kein Vergleichen, keine Verkettung, kein tostring.

local Data = {}
ns.Data = Data

local issecret = issecretvalue or function() return false end

-- Ergebnis des letzten Lesevorgangs. Wird wiederverwendet.
local state = {}
Data.state = state

function Data:GetMeterType()
  local MT = Enum and Enum.DamageMeterType
  if not MT then return nil end
  if ns.db.profile.mode == "hps" then return MT.Hps end
  return MT.Dps
end

function Data:GetSessionType(inCombat)
  local ST = Enum and Enum.DamageMeterSessionType
  if not ST then return nil end
  local source = ns.db.profile.dataSource
  if source == "current" then return ST.Current end
  if source == "overall" then return ST.Overall end
  -- Automatisch: im Kampf aktueller Kampf, sonst Gesamt
  if inCombat then return ST.Current end
  return ST.Overall
end

-- Liest die Session und sucht den eigenen Eintrag.
-- Schreibt in state: rank, count (nie geheim), value (evtl. geheim), hasValue, apiOk, err
local function readSession(s)
  local DM = C_DamageMeter
  if not DM or not DM.GetCombatSessionFromType then
    s.err = "C_DamageMeter.GetCombatSessionFromType missing"
    return
  end
  if s.sessionType == nil or s.meterType == nil then
    s.err = "Enum missing"
    return
  end

  local ok, session = pcall(DM.GetCombatSessionFromType, s.sessionType, s.meterType)
  if not ok then s.err = session; return end
  if issecret(session) then s.err = "session secret"; return end
  if type(session) ~= "table" then s.err = "session not a table"; return end

  local okS, sources = pcall(function() return session.combatSources end)
  if not okS then s.err = sources; return end
  if issecret(sources) then s.err = "combatSources secret"; return end
  if type(sources) ~= "table" then s.err = "combatSources not a table"; return end

  local okN, n = pcall(function() return #sources end)
  if not okN then s.err = n; return end
  if issecret(n) then s.err = "count secret"; return end

  s.apiOk = true
  s.count = n

  for i = 1, n do
    local okI, src = pcall(function() return sources[i] end)
    if okI and not issecret(src) and type(src) == "table" then
      local okL, isMe = pcall(function() return src.isLocalPlayer end)
      if okL and not issecret(isMe) and isMe == true then
        s.rank = i
        local okV, value = pcall(function() return src.amountPerSecond end)
        if okV then
          s.value = value       -- evtl. geheim: nur speichern
          s.hasValue = true
        else
          s.err = value
        end
        return
      end
    end
  end
end

function Data:Read()
  local s = state
  s.inCombat = InCombatLockdown() and true or false
  s.sessionType = self:GetSessionType(s.inCombat)
  s.meterType = self:GetMeterType()
  s.apiOk = false
  s.count = nil
  s.rank = nil
  s.value = nil
  s.hasValue = false
  s.err = nil

  local ok, err = pcall(readSession, s)
  if not ok then s.err = err end
  return s
end
