local ADDON_NAME, ns = ...
local L = ns.L

-- Anzeige: eine Textzeile "[Platz] [Name] [Wert] [Einheit]".
-- Der Wert kann geheim sein. Er geht nur als Argument an SetFormattedText,
-- der Formatstring selbst besteht ausschließlich aus nicht geheimen Teilen.

local Display = {}
ns.Display = Display

local issecret = issecretvalue or function() return false end

-- 123.4k / 12.3M / 1.2B, im Spiel getestet (SPEC Abschnitt 2), auch mit Secret Values
local ABBREV_OPTS = {
  breakpointData = {
    { breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e3, abbreviation = "k", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
  },
}

local EMPTY_TEXT = "-"

local frame, text, moveBg

-- Ergebnis des letzten Zeichnens, für das Debug-Log
Display.last = {}

local function colorCode(c)
  return string.format("|cff%02x%02x%02x",
    math.floor((c.r or 1) * 255 + 0.5),
    math.floor((c.g or 1) * 255 + 0.5),
    math.floor((c.b or 1) * 255 + 0.5))
end

-- Baut den Formatstring aus nicht geheimen Teilen.
-- Rückgabe: fmt, withRank (true, wenn das erste Argument der Platz ist)
local function buildFormat(p, rank)
  local parts = {}
  local withRank = p.showRank and rank ~= nil
  if withRank then
    parts[#parts + 1] = colorCode(p.colors.rank) .. "%d.|r"
  end
  if p.showName then
    local name = UnitName("player") or ""
    parts[#parts + 1] = colorCode(p.colors.name) .. name:gsub("%%", "%%%%") .. "|r"
  end
  parts[#parts + 1] = colorCode(p.colors.value) .. "%s|r"
  if p.showUnit then
    local unit = (p.mode == "hps") and L["UNIT_HPS"] or L["UNIT_DPS"]
    parts[#parts + 1] = colorCode(p.colors.unit) .. unit:gsub("%%", "%%%%") .. "|r"
  end
  return table.concat(parts, " "), withRank
end

local function savePosition()
  local point, _, relPoint, x, y = frame:GetPoint(1)
  local pos = ns.db.profile.position
  pos.point, pos.relPoint, pos.x, pos.y = point, relPoint, x, y
end

function Display:ApplyPosition()
  local pos = ns.db.profile.position
  frame:ClearAllPoints()
  frame:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Display:ApplySettings()
  local p = ns.db.profile
  local f = p.font
  -- Schriftart über LibSharedMedia folgt in Meilenstein 3
  text:SetFont(STANDARD_TEXT_FONT, f.size, f.outline)
  if f.shadow then
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
  else
    text:SetShadowOffset(0, 0)
  end
  frame:SetHeight(f.size + 8)
  frame:SetScale(p.scale)
  frame:SetAlpha(p.alpha)
  self:ApplyPosition()
end

function Display:Create()
  if frame then return end

  frame = CreateFrame("Frame", "OwnDPSFrame", UIParent)
  frame:SetSize(160, 22)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(false)
  frame:SetScript("OnDragStart", function(self)
    if Display.moving then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    savePosition()
  end)

  moveBg = frame:CreateTexture(nil, "BACKGROUND")
  moveBg:SetAllPoints()
  moveBg:SetColorTexture(0.1, 0.4, 0.8, 0.4)
  moveBg:Hide()

  text = frame:CreateFontString(nil, "OVERLAY")
  text:SetPoint("LEFT", frame, "LEFT", 4, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)

  self:ApplySettings()
  text:SetText(EMPTY_TEXT)
  self:RegisterVisibility()
end

-- Im Haustierkampf immer ausblenden (SPEC Abschnitt 5, getestet).
-- Weitere Sichtbarkeitsregeln folgen in Meilenstein 5.
function Display:RegisterVisibility()
  if self.visibilityRegistered then return true end
  local ok, err = pcall(RegisterStateDriver, frame, "visibility", "[petbattle] hide; show")
  if ok then
    self.visibilityRegistered = true
  else
    ns.Debug:Error("RegisterStateDriver", err)
  end
  return ok
end

function Display:SetMoveMode(on)
  self.moving = on and true or false
  frame:EnableMouse(self.moving)
  if self.moving then
    frame:RegisterForDrag("LeftButton")
  else
    frame:RegisterForDrag()
  end
  moveBg:SetShown(self.moving)
end

function Display:ResetPosition()
  local pos = ns.db.profile.position
  local def = ns.defaults.profile.position
  pos.point, pos.relPoint, pos.x, pos.y = def.point, def.relPoint, def.x, def.y
  self:ApplyPosition()
end

local function showEmpty(last)
  text:SetText(EMPTY_TEXT)
  last.shown = "empty"
end

-- s: Ergebnis von Data:Read()
function Display:Render(s)
  if not frame then return end
  local last = self.last
  last.abbrevOk = nil
  last.formatted = nil
  last.setTextOk = nil

  if not s.hasValue then
    showEmpty(last)
    return
  end

  local okA, formatted = pcall(AbbreviateNumbers, s.value, ABBREV_OPTS)
  last.abbrevOk = okA
  if not okA then
    ns.Debug:Error("AbbreviateNumbers", formatted)
    showEmpty(last)
    return
  end
  last.formatted = formatted   -- evtl. geheim, das Log schreibt dann "<SECRET>"

  local p = ns.db.profile
  local fmt, withRank = buildFormat(p, s.rank)
  local okF, err
  if withRank then
    okF, err = pcall(text.SetFormattedText, text, fmt, s.rank, formatted)
  else
    okF, err = pcall(text.SetFormattedText, text, fmt, formatted)
  end
  last.setTextOk = okF
  if okF then
    last.shown = "value"
  else
    ns.Debug:Error("SetFormattedText", err)
    showEmpty(last)
  end
end

-- Für den Debugmodus: Ist die Textbreite lesbar, wenn der Text geheim ist?
-- (Antwort wird für Hintergrund/Rahmen in Meilenstein 3 gebraucht.)
function Display:DebugInfo(out)
  if not text then return end
  local ok, w = pcall(text.GetStringWidth, text)
  out.textWidthOk = ok
  if ok then
    out.textWidthSecret = issecret(w)
    out.textWidth = w
  end
  out.frameShown = frame:IsShown()
end
