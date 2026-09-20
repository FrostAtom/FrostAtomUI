local _, ns = ...

local CreateFrame = CreateFrame
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitAffectingCombat = UnitAffectingCombat
local unpack = unpack

local PlayerPlate = ns:NewModule("PlayerPlate")
local UF = ns:GetModule("UnitFrames")

local BAR_WIDTH = 150
local HEALTH_HEIGHT, POWER_HEIGHT = 11, 6
local BAR_GAP = 3
local FONT_SIZE = 12
local TEXT_OFFSET = 4
local FADE_SPEED = 2

local plate = CreateFrame("Frame", "FrostAtomUIPlayerPlate", UIParent)
plate:SetSize(BAR_WIDTH, HEALTH_HEIGHT + BAR_GAP + POWER_HEIGHT)
plate:SetPoint(unpack(ns.Config.playerPlate))
plate:Hide()

local function createBar(height)
	local bar = CreateFrame("StatusBar", nil, plate)
	bar:SetSize(BAR_WIDTH, height)
	bar:SetStatusBarTexture(ns.Media.blank)
	ns.SmoothBar(bar)

	local borderSize = ns.PixelPerfect(1)
	local border = bar:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(0, 0, 0)
	border:SetPoint("TOPRIGHT", borderSize, borderSize)
	border:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)

	local bg = bar:CreateTexture(nil, "BORDER")
	bg:SetTexture(ns.Media.blank)
	bg:SetAllPoints()
	bg:SetAlpha(0.9)
	bar.bg = bg

	local text = bar:CreateFontString(nil, "OVERLAY")
	text:SetFont(ns.Media.font, FONT_SIZE, "OUTLINE")
	text:SetPoint("LEFT", bar, "RIGHT", TEXT_OFFSET, 0)
	text:SetTextColor(1, 1, 1)
	bar.text = text

	return bar
end

local health = createBar(HEALTH_HEIGHT)
health:SetPoint("TOP")
local classColor = UF.classBarColors[ns.PLAYER_CLASS]
health:SetStatusBarColor(unpack(classColor))
health.bg:SetVertexColor(classColor[1] * 0.3, classColor[2] * 0.3, classColor[3] * 0.3)

local power = createBar(POWER_HEIGHT)
power:SetPoint("TOP", health, "BOTTOM", 0, -BAR_GAP)

local function updateHealth()
	local current, max = UnitHealth("player"), UnitHealthMax("player")
	health:SetMinMaxValues(0, max)
	health:SetValue(current)
	health.text:SetFormattedText("%d%%", max > 0 and current / max * 100 or 0)
end

local function updatePower()
	local current, max = UnitPower("player"), UnitPowerMax("player")
	power:SetMinMaxValues(0, max)
	power:SetValue(current)
	power.text:SetText(ns.FormatValue(current))

	local powerType = UnitPowerType("player")
	if powerType ~= power.powerType then
		power.powerType = powerType
		local r, g, b = unpack(UF.powerColors[powerType])
		power:SetStatusBarColor(r, g, b)
		power.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
	end
end

local function isWanted()
	return UnitAffectingCombat("player") or UnitHealth("player") < UnitHealthMax("player")
end

plate:SetScript("OnUpdate", function(self, elapsed)
	local currentHealth, currentPower = UnitHealth("player"), UnitPower("player")
	if currentHealth ~= self.lastHealth then
		self.lastHealth = currentHealth
		updateHealth()
	end
	if currentPower ~= self.lastPower then
		self.lastPower = currentPower
		updatePower()
	end

	if isWanted() then
		self:SetAlpha(1)
		return
	end

	local alpha = self:GetAlpha() - elapsed * FADE_SPEED
	if alpha > 0 then
		self:SetAlpha(alpha)
	else
		self:Hide()
	end
end)

local function show()
	if plate:IsShown() then
		return
	end
	plate.lastHealth, plate.lastPower = nil, nil
	health:SnapValue(UnitHealth("player"))
	power:SnapValue(UnitPower("player"))
	plate:SetAlpha(1)
	plate:Show()
end

local function onPlayerEvent(_, unit)
	if unit == "player" and isWanted() then
		show()
	end
end

PlayerPlate:RegisterEvent("PLAYER_REGEN_DISABLED", show)
PlayerPlate:RegisterEvent("UNIT_HEALTH", onPlayerEvent)
PlayerPlate:RegisterEvent("UNIT_MAXHEALTH", onPlayerEvent)
PlayerPlate:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if isWanted() then
		show()
	end
end)
