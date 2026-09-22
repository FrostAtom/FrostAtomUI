local _, ns = ...

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitAffectingCombat = UnitAffectingCombat

local PlayerPlate = ns:NewModule("PlayerPlate")
local UF = ns:GetModule("UnitFrames")

local TEXT_INSET = 2
local BORDER_INSET = UF.BORDER_INSET
local frameConfig = ns.Config.unitFrames

local plate = CreateFrame("Frame", "FrostAtomUIPlayerPlate", UIParent)
PlayerPlate:AnchorToConfig(plate, "playerPlate.point")
plate:SetBackdrop(UF.backdrop)
plate:Hide()

local function createBar()
	local bar = CreateFrame("StatusBar", nil, plate)
	ns.SkinStatusBar(bar)
	ns.SmoothBar(bar)

	local bg = bar:CreateTexture(nil, "BORDER")
	bg:SetTexture(ns.Media.blank)
	bg:SetAllPoints()
	bar.bg = bg

	local text = bar:CreateFontString(nil, "OVERLAY")
	text:SetPoint("RIGHT", -TEXT_INSET, 0)
	bar.text = text

	return bar
end

local health = createBar()
health:SetPoint("TOP", 0, -BORDER_INSET)

local power = createBar()

local function setBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
end

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
		setBarColor(power, unpack(UF.powerColors[powerType]))
	end
end

local function isWanted()
	local config = ns.Config.playerPlate
	if not config.enabled then
		return false
	end
	return config.alwaysShow or UnitAffectingCombat("player") or UnitHealth("player") < UnitHealthMax("player")
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

	local fadeTime = ns.Config.playerPlate.fadeTime
	local alpha = fadeTime > 0 and self:GetAlpha() - elapsed / fadeTime or 0
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

local function applyConfig()
	local config = ns.Config.playerPlate
	plate:SetSize(
		config.width + BORDER_INSET * 2,
		config.healthHeight + config.gap + config.powerHeight + BORDER_INSET * 2
	)
	UF.SetBackdropColors(plate)
	health:SetSize(config.width, config.healthHeight)
	power:SetSize(config.width, config.powerHeight)
	power:ClearAllPoints()
	power:SetPoint("TOP", health, "BOTTOM", 0, -config.gap)

	local font = config.font
	ns.SetFont(health.text, font.size, font.outline)
	ns.SetFont(power.text, font.size, font.outline)
	health.text:SetTextColor(unpack(frameConfig.textColor))
	power.text:SetTextColor(unpack(frameConfig.textColor))
	if config.showText then
		health.text:Show()
		power.text:Show()
	else
		health.text:Hide()
		power.text:Hide()
	end

	local color = config.classColorHealth and UF.classBarColors[ns.PLAYER_CLASS] or config.healthColor
	setBarColor(health, unpack(color))

	if isWanted() then
		show()
	end
end

local function onPlayerEvent(_, unit)
	if unit == "player" and isWanted() then
		show()
	end
end

function PlayerPlate:Initialize()
	applyConfig()
	self:WatchConfig("playerPlate", applyConfig)
	self:WatchConfig("unitFrames", applyConfig)

	self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		if ns.Config.playerPlate.enabled then
			show()
		end
	end)
	self:RegisterEvent("UNIT_HEALTH", onPlayerEvent)
	self:RegisterEvent("UNIT_MAXHEALTH", onPlayerEvent)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		if isWanted() then
			show()
		end
	end)
end
