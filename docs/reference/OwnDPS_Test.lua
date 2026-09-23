-- OwnDPS_Test v0.3.0 (Test 3: Trend-Varianten A/B/C)
-- Test 2 fuer OwnDPS:
--   * DPS-Anzeige im Format 123.4k (AbbreviateNumbers mit breakpointData)
--   * Trend-Balken ueber StatusBars (den Vergleich rechnet WoW, nicht Lua)
--   * Platzierung mit mehreren Quellen (Gruppe / Follower-Dungeon)
--   * IsDamageMeterAvailable zu verschiedenen Zeitpunkten
--   * Reset-Verhalten beim Betreten einer Instanz
--   * Ausblenden im Haustierkampf
--
-- Log: WTF\Account\<ACCOUNT>\SavedVariables\OwnDPS_Test.lua (bei /reload oder Logout)
-- Slash-Befehle: /odt

local ADDON_NAME = ...
local VERSION = "0.3.1"
local MAX_ENTRIES = 10000
local DISPLAY_TICK = 0.25      -- Anzeige-Aktualisierung in Sekunden
local LOG_EVERY = 1.0          -- Log-Intervall im Kampf
local TREND_WINDOW = 3.0       -- Vergleichszeitraum fuer den Trend (Sekunden), per /odt window N aenderbar
local POST_COMBAT_LOG = 10

local issecret = issecretvalue or function() return false end
local DM = C_DamageMeter
local ST = Enum and Enum.DamageMeterSessionType
local MT = Enum and Enum.DamageMeterType

local loginNo = 0
local postCombatUntil = 0
local lastLog = 0
local evCounts = {}
local history = {}             -- { t = GetTime(), v = <evtl. secret> }
local lastRank
local ui = {}

---------------------------------------------------------------------------
-- Zahlenformat 123.4k / 12.3M / 1.2B (eine Nachkommastelle)
---------------------------------------------------------------------------
local ABBREV_OPTS = {
  breakpointData = {
    { breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e3, abbreviation = "k", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
  },
}

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------

local function Print(msg) print("|cff33ff99OwnDPS_Test|r: " .. msg) end

-- Nur speicherbare Werte ins Log. Secret Values werden nie gespeichert.
local function S(v)
  if issecret(v) then return "<SECRET>" end
  if v == nil then return "nil" end
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" then return v end
  return "<" .. t .. ">"
end

local function now() return math.floor(GetTime() * 100 + 0.5) / 100 end

local function add(kind, data)
  local db = OwnDPS_TestLog
  if not db or not db.enabled then return end
  data = data or {}
  data.kind = kind
  data.t = now()
  data.login = loginNo
  data.combat = InCombatLockdown() and true or false
  local e = db.entries
  e[#e + 1] = data
  if #e > MAX_ENTRIES then
    local keep = {}
    for i = #e - (MAX_ENTRIES - 1000) + 1, #e do keep[#keep + 1] = e[i] end
    db.entries = keep
  end
end

local function logAvailability(out, key)
  if DM and DM.IsDamageMeterAvailable then
    local ok, avail, reason = pcall(DM.IsDamageMeterAvailable)
    out[key .. "Ok"] = ok; out[key] = S(avail); out[key .. "Reason"] = S(reason)
  end
end

---------------------------------------------------------------------------
-- Daten holen
---------------------------------------------------------------------------

-- Liefert: eigene Quelle, Rang, Anzahl Quellen. Schreibt Details in out (falls gegeben).
local function readSession(sessionType, meterType, out, p)
  if not DM or sessionType == nil or meterType == nil then return end
  local ok, session = pcall(DM.GetCombatSessionFromType, sessionType, meterType)
  if not ok then if out then out[p .. "Err"] = tostring(session) end; return end
  if session == nil or issecret(session) then if out then out[p] = S(session) end; return end
  local okS, sources = pcall(function() return session.combatSources end)
  if not okS or issecret(sources) or type(sources) ~= "table" then
    if out then out[p .. "Sources"] = okS and S(sources) or "err" end
    return
  end
  local okN, n = pcall(function() return #sources end)
  if not okN or issecret(n) then if out then out[p .. "Count"] = "<SECRET>" end; return end
  if out then out[p .. "Count"] = n end

  local mySrc, myRank
  for i = 1, n do
    local okI, src = pcall(function() return sources[i] end)
    if okI and src and not issecret(src) then
      local okL, isMe = pcall(function() return src.isLocalPlayer end)
      local me = okL and not issecret(isMe) and isMe == true
      if me then mySrc, myRank = src, i end
      if out and i <= 8 then
        -- NeverSecret-Felder: zeigen, wer in der Liste steht (Follower, Pets, ...)
        local okC, cls = pcall(function() return src.classFilename end)
        local okK, clf = pcall(function() return src.classification end)
        local okD, sdt = pcall(function() return src.sourceDisplayType end)
        out[p .. "Src" .. i] = (me and "ME " or "") .. tostring(okC and S(cls) or "err")
          .. "/" .. tostring(okK and S(clf) or "err") .. "/" .. tostring(okD and S(sdt) or "err")
      end
    end
  end
  if out then out[p .. "Rank"] = myRank or "notFound" end
  return mySrc, myRank, n
end

local function getAPS(src)
  if not src then return nil end
  local ok, v = pcall(function() return src.amountPerSecond end)
  if ok then return v end
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------

local ARROW_UP = "Interface\\AddOns\\" .. ADDON_NAME .. "\\arrow_up"
local ARROW_DOWN = "Interface\\AddOns\\" .. ADDON_NAME .. "\\arrow_down"
local IND = 18                 -- sichtbare Groesse der Indikatoren B und C (Pixel)
local tolerance = 0.01         -- 1 %: Balkenhoehe = IND / tolerance
local trendPairs = {}          -- { name = "A"/"B"/"C", up = StatusBar, down = StatusBar }
local clipBars = {}

local function styleBar(bar, r, g, b)
  bar:SetOrientation("VERTICAL")
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  bar:SetStatusBarColor(r, g, b, 1)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
end

-- Variante A: normaler Balken (wie Test 2)
local function makeBar(parent, r, g, b)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(14, 40)
  styleBar(bar, r, g, b)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
  return bar
end

-- Varianten B und C: sehr langer Balken in einem kleinen Fenster.
-- Sichtbar ist nur das oberste Stueck. Das ist nur gefuellt, wenn
-- Wert >= (1 - Toleranz) * Maximum. WoW entscheidet das beim Zeichnen.
local function makeClipIndicator(parent, r, g, b, maskPath, withBg)
  local clip = CreateFrame("Frame", nil, parent)
  clip:SetSize(IND, IND)
  clip:SetClipsChildren(true)
  if withBg then
    local bg = clip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  end
  local bar = CreateFrame("StatusBar", nil, clip)
  bar:SetPoint("TOP", clip, "TOP", 0, 0)
  bar:SetSize(IND, IND / tolerance)
  styleBar(bar, r, g, b)
  if maskPath then
    local ok, err = pcall(function()
      local mask = bar:CreateMaskTexture()
      mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(clip)
      bar:GetStatusBarTexture():AddMaskTexture(mask)
    end)
    if not ok then add("maskErr", { err = tostring(err) }) end
  end
  clipBars[#clipBars + 1] = bar
  return clip, bar
end

local function applyTolerance()
  for _, bar in ipairs(clipBars) do bar:SetHeight(IND / tolerance) end
end

local function label(parent, anchor, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
  fs:SetText(text)
  return fs
end

local function createDisplay()
  local f = CreateFrame("Frame", "OwnDPS_TestDisplay", UIParent, "BackdropTemplate")
  f:SetSize(300, 100)
  f:SetPoint("CENTER", 0, 200)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  f:SetBackdropColor(0, 0, 0, 0.5)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  ui.frame = f
  ui.l1 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  ui.l1:SetPoint("TOPLEFT", 8, -8)
  ui.l2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ui.l2:SetPoint("TOPLEFT", 8, -34)
  ui.l3 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ui.l3:SetPoint("TOPLEFT", 8, -54)
  ui.l4 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.l4:SetPoint("TOPLEFT", 8, -76)

  -- A: zwei normale Balken (rechts aussen)
  local aUp = makeBar(f, 0.1, 0.9, 0.1); aUp:SetPoint("TOPRIGHT", -40, -10)
  local aDown = makeBar(f, 0.9, 0.1, 0.1); aDown:SetPoint("TOPRIGHT", -14, -10)
  local aHolder = CreateFrame("Frame", nil, f); aHolder:SetSize(40, 1); aHolder:SetPoint("TOPRIGHT", -8, -52)
  label(f, aHolder, "A")
  trendPairs[#trendPairs + 1] = { name = "A", up = aUp, down = aDown }

  -- B: Abschneide-Trick mit Kaestchen (oben = hoch, unten = runter)
  local bUpClip, bUp = makeClipIndicator(f, 0.1, 0.9, 0.1, nil, true)
  bUpClip:SetPoint("TOPRIGHT", -80, -10)
  local bDownClip, bDown = makeClipIndicator(f, 0.9, 0.1, 0.1, nil, true)
  bDownClip:SetPoint("TOP", bUpClip, "BOTTOM", 0, -4)
  label(f, bDownClip, "B")
  trendPairs[#trendPairs + 1] = { name = "B", up = bUp, down = bDown }

  -- C: Abschneide-Trick mit Pfeilform, beide Pfeile an derselben Stelle
  local cUpClip, cUp = makeClipIndicator(f, 0.1, 0.9, 0.1, ARROW_UP, false)
  cUpClip:SetPoint("TOPRIGHT", -120, -20)
  local cDownClip, cDown = makeClipIndicator(f, 0.9, 0.1, 0.1, ARROW_DOWN, false)
  cDownClip:SetPoint("CENTER", cUpClip, "CENTER", 0, 0)
  local cHolder = CreateFrame("Frame", nil, f); cHolder:SetSize(IND, 1); cHolder:SetPoint("TOP", cUpClip, "BOTTOM", 0, -12)
  label(f, cHolder, "C")
  trendPairs[#trendPairs + 1] = { name = "C", up = cUp, down = cDown }
  ui.cClips = { cUpClip, cDownClip }

  local ok, err = pcall(RegisterStateDriver, f, "visibility", "[petbattle] hide; show")
  if not ok then add("stateDriverErr", { err = tostring(err) }) end
end

-- Wert von vor TREND_WINDOW Sekunden aus der Historie holen
local function getPrev(t)
  local target = t - TREND_WINDOW
  local best
  for i = #history, 1, -1 do
    if history[i].t <= target then best = history[i]; break end
  end
  while #history > 0 and history[1].t < target - 2 do table.remove(history, 1) end
  return best and best.v
end

local function updateTrend(cur, prev, out)
  if cur == nil or prev == nil then
    for _, p in ipairs(trendPairs) do
      p.up:SetMinMaxValues(0, 1); p.up:SetValue(0)
      p.down:SetMinMaxValues(0, 1); p.down:SetValue(0)
    end
    if out then out.trend = "noData" end
    return
  end
  for _, p in ipairs(trendPairs) do
    -- Hoch: Max = alter Wert, Fuellung = aktueller Wert -> voll, wenn gestiegen
    local ok1 = pcall(p.up.SetMinMaxValues, p.up, 0, prev)
    local ok2 = pcall(p.up.SetValue, p.up, cur)
    -- Runter: Max = aktueller Wert, Fuellung = alter Wert -> voll, wenn gesunken
    local ok3 = pcall(p.down.SetMinMaxValues, p.down, 0, cur)
    local ok4 = pcall(p.down.SetValue, p.down, prev)
    if out then out["trend" .. p.name .. "Ok"] = ok1 and ok2 and ok3 and ok4 end
  end
  if out then
    out.trendCurSecret = issecret(cur); out.trendPrevSecret = issecret(prev)
    out.tolerance = tolerance
    -- Ausserhalb des Kampfs koennen wir die Wahrheit pruefen
    if not issecret(cur) and not issecret(prev) then
      out.trendTruth = (cur > prev) and "up" or ((cur < prev) and "down" or "equal")
      out.trendCur = cur; out.trendPrev = prev
    end
  end
end

local function updateTexts(src, rank, n, out)
  local aps = getAPS(src)
  if aps == nil then
    ui.l1:SetText("-"); ui.l2:SetText("-"); ui.l3:SetText("-")
    return nil
  end
  -- Zeile 1: gewuenschtes Format 123.4k
  local okA, txt = pcall(AbbreviateNumbers, aps, ABBREV_OPTS)
  local okS1 = okA and pcall(ui.l1.SetFormattedText, ui.l1, "%s", txt)
  if not okS1 then ui.l1:SetText("Format-Fehler") end
  -- Zeile 2: Blizzard-Standardformat zum Vergleich
  local okB, txtB = pcall(AbbreviateNumbers, aps)
  local okS2 = okB and pcall(ui.l2.SetFormattedText, ui.l2, "Standard: %s", txtB)
  if not okS2 then ui.l2:SetText("Standard: Fehler") end
  -- Zeile 3: Platzierung
  ui.l3:SetText(string.format("Platz: %s von %s", rank and (rank .. ".") or "-", tostring(n or "-")))
  if out then
    out.fmtCustomOk = okA; out.fmtCustomSetOk = okS1 and true or false
    if okA then out.fmtCustomSecret = issecret(txt) end
    if okA and not issecret(txt) then out.fmtCustom = txt end
    if not okA then out.fmtCustomErr = tostring(txt) end
    out.fmtStdOk = okB
    if okB and not issecret(txtB) then out.fmtStd = txtB end
  end
  return aps
end

---------------------------------------------------------------------------
-- Takt
---------------------------------------------------------------------------

local function tick()
  local t = GetTime()
  local inCombat = InCombatLockdown()
  local doLog = (inCombat or t < postCombatUntil) and (t - lastLog >= LOG_EVERY)
  local out = doLog and {} or nil

  local src, rank, n = readSession(ST and ST.Current, MT and MT.Dps, out, "cur")
  local aps = updateTexts(src, rank, n, out)

  if aps ~= nil then history[#history + 1] = { t = t, v = aps } end
  updateTrend(aps, getPrev(t), out)

  -- Platzierungs-Wechsel mitschreiben (fuer Trend-Variante A)
  if rank and lastRank and rank ~= lastRank then
    add("rankChange", { from = lastRank, to = rank, count = n })
  end
  if rank then lastRank = rank end

  ui.l4:SetText(inCombat and "im Kampf" or "ausser Kampf")
  -- Pfeile (C) nur im Kampf zeigen
  for _, c in ipairs(ui.cClips) do c:SetShown(inCombat) end

  if doLog then
    lastLog = t
    local okD, dur = pcall(DM.GetSessionDurationSeconds, ST.Current)
    out.sessDur = okD and S(dur) or "err"
    out.window = TREND_WINDOW
    for e, c in pairs(evCounts) do out["ev_" .. e] = c end
    wipe(evCounts)
    add("tick", out)
  end
end

local function logOverall(kind)
  local out = {}
  local src = readSession(ST and ST.Overall, MT and MT.Dps, out, "ov")
  out.ovAPS = S(getAPS(src))
  if DM and ST then
    local okD, dur = pcall(DM.GetSessionDurationSeconds, ST.Overall)
    out.ovDur = okD and S(dur) or "err"
  end
  logAvailability(out, "dmAvail")
  add(kind, out)
end

local function logInstance(extra)
  local out = extra or {}
  local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
  out.instName = S(name); out.instType = S(instanceType); out.diffID = S(difficultyID)
  out.diffName = S(difficultyName); out.maxPlayers = S(maxPlayers); out.instID = S(instanceID)
  out.groupSize = GetNumGroupMembers(); out.inRaid = IsInRaid()
  logAvailability(out, "dmAvail")
  add("instance", out)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")

ev:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON_NAME then return end
    OwnDPS_TestLog = OwnDPS_TestLog or {}
    local db = OwnDPS_TestLog
    -- neues Testaddon = frisches Log
    if db.version ~= VERSION then
      db.entries = {}; db.logins = 0; db.version = VERSION
    end
    if db.enabled == nil then db.enabled = true end
    if type(db.window) == "number" then TREND_WINDOW = db.window end
    if type(db.tolerance) == "number" then tolerance = db.tolerance end
    db.entries = db.entries or {}
    db.logins = (db.logins or 0) + 1
    loginNo = db.logins
    local version, build, _, toc = GetBuildInfo()
    local meta = { addonVersion = VERSION, gameVersion = S(version), build = S(build), toc = S(toc),
      locale = GetLocale(), class = select(2, UnitClass("player")) }
    logAvailability(meta, "dmAvailAtLoad")
    add("meta", meta)
    createDisplay()
    C_Timer.NewTicker(DISPLAY_TICK, function()
      local ok, err = pcall(tick)
      if not ok then add("tickErr", { err = tostring(err) }) end
    end)
    Print("v" .. VERSION .. " geladen, " .. #db.entries .. " Eintraege im Log. /odt fuer Hilfe")

  elseif event == "PLAYER_LOGIN" then
    local out = {}; logAvailability(out, "dmAvail"); add("login", out)

  elseif event == "PLAYER_ENTERING_WORLD" then
    local isInitial, isReload = ...
    logInstance({ initial = isInitial, reload = isReload })
    logOverall("overallAtEnterWorld")

  elseif event == "PLAYER_REGEN_DISABLED" then
    wipe(history)
    local out = { groupSize = GetNumGroupMembers() }
    logAvailability(out, "dmAvail")
    add("combatStart", out)

  elseif event == "PLAYER_REGEN_ENABLED" then
    postCombatUntil = GetTime() + POST_COMBAT_LOG
    add("combatEnd")
    C_Timer.After(1, function() logOverall("overallAfterCombat") end)

  elseif event == "DAMAGE_METER_RESET" then
    logOverall("dmReset")

  elseif event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE" then
    C_Timer.After(0.5, function()
      add(event, { displayShown = ui.frame and ui.frame:IsShown() or false })
    end)

  else
    evCounts[event] = (evCounts[event] or 0) + 1
  end
end)

for _, e in ipairs({
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
  "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "GROUP_ROSTER_UPDATE",
}) do
  if not pcall(ev.RegisterEvent, ev, e) then Print("Event unbekannt: " .. e) end
end

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------

SLASH_OWNDPSTEST1 = "/odt"
SlashCmdList.OWNDPSTEST = function(msg)
  msg = strlower(strtrim(msg or ""))
  local db = OwnDPS_TestLog
  if msg == "on" then db.enabled = true; Print("Log AN")
  elseif msg == "off" then db.enabled = false; Print("Log AUS")
  elseif msg == "clear" then wipe(db.entries); Print("Log geleert")
  elseif msg == "snap" then lastLog = 0; postCombatUntil = GetTime() + 0.5; Print("Momentaufnahme im naechsten Takt")
  elseif msg:match("^window") then
    local n = tonumber(msg:match("^window%s+([%d%.]+)"))
    if n and n >= 0.5 and n <= 30 then
      TREND_WINDOW = n; OwnDPS_TestLog.window = n; wipe(history)
      add("windowChange", { window = n }); Print("Trend-Zeitfenster: " .. n .. " s")
    else
      Print("Trend-Zeitfenster aktuell " .. TREND_WINDOW .. " s. Aendern mit /odt window 3")
    end
  elseif msg:match("^tol") then
    local n = tonumber(msg:match("^tol%s+([%d%.]+)"))
    if n and n >= 0.1 and n <= 20 then
      tolerance = n / 100; OwnDPS_TestLog.tolerance = tolerance; applyTolerance()
      add("toleranceChange", { tolerance = tolerance }); Print("Toleranz: " .. n .. " %")
    else
      Print("Toleranz aktuell " .. (tolerance * 100) .. " %. Aendern mit /odt tol 1")
    end
  elseif msg == "status" then Print("Log " .. (db.enabled and "AN" or "AUS") .. ", " .. #db.entries .. " Eintraege")
  else
    Print("/odt on | off | clear | snap | status | window N | tol N")
    Print("Log wird bei /reload oder Logout gespeichert.")
  end
end
