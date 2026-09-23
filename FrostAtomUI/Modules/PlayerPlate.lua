local _, ns = ...

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitAffectingCombat = UnitAffectingCombat
local UnitGUID, UnitIsDeadOrGhost = UnitGUID, UnitIsDeadOrGhost

local PlayerPlate = ns:NewModule("PlayerPlate")
local UF = ns:GetModule("UnitFrames")
local Prediction = ns.HealPrediction

local TEXT_INSET = 2
local BORDER_INSET = UF.BORDER_INSET
local frameConfig = ns.Config.unitFrames

local plate = CreateFrame("Frame", "FrostAtomUIPlayerPlate", UIParent)
PlayerPlate:AnchorToConfig(plate, "playerPlate.point", "Player plate")
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
Prediction.CreateBars(health)

local power = createBar()

local function setBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
end

local function healthColor()
	local config = ns.Config.playerPlate
	if config.healthColorMode == "class" then
		return unpack(UF.classBarColors[ns.PLAYER_CLASS])
	elseif config.healthColorMode == "health" then
		local max = UnitHealthMax("player")
		return ns.HealthColor(max > 0 and UnitHealth("player") / max or 0)
	end
	return unpack(config.healthColor)
end

local function updatePrediction()
	local config = ns.Config.playerPlate
	if UnitIsDeadOrGhost("player") then
		Prediction.SetValues(health, 0, 0, false)
	else
		Prediction.Refresh(health, UnitGUID("player"), "player", config.healPrediction, config.absorbs)
	end
end

local function updateHealth()
	local config = ns.Config.playerPlate
	local current, max = UnitHealth("player"), UnitHealthMax("player")
	health:SetMinMaxValues(0, max)
	health:SetValue(current)
	if config.healthText == "value" then
		health.text:SetText(ns.FormatValue(current))
	else
		health.text:SetFormattedText("%d%%", max > 0 and current / max * 100 or 0)
	end
	if config.healthColorMode == "health" then
		setBarColor(health, healthColor())
	end
	updatePrediction()
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
	Prediction.Follow(health)
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

local function showIfWanted()
	if isWanted() then
		show()
	end
end

local function styleText(text, font, shown)
	ns.SetFont(text, font.size, font.outline)
	text:SetTextColor(unpack(frameConfig.textColor))
	if shown then
		text:Show()
	else
		text:Hide()
	end
end

local function applyConfig()
	local config = ns.Config.playerPlate
	local powerSpace = config.showPower and config.gap + config.powerHeight or 0
	plate:SetSize(config.width + BORDER_INSET * 2, config.healthHeight + powerSpace + BORDER_INSET * 2)
	UF.SetBackdropColors(plate)
	health:SetSize(config.width, config.healthHeight)
	power:SetSize(config.width, config.powerHeight)
	power:ClearAllPoints()
	power:SetPoint("TOP", health, "BOTTOM", 0, -config.gap)
	if config.showPower then
		power:Show()
	else
		power:Hide()
	end
	plate.lastHealth = nil

	styleText(health.text, config.font, config.showText)
	styleText(power.text, config.font, config.showText)

	setBarColor(health, healthColor())
	updatePrediction()
	showIfWanted()
end

local function onPlayerEvent(_, unit)
	if unit == "player" then
		showIfWanted()
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
	self:RegisterEvent(Prediction.CHANGED, function(_, guid)
		if plate:IsShown() and guid == UnitGUID("player") then
			updatePrediction()
		end
	end)
	self:RegisterEvent("UNIT_HEALTH", onPlayerEvent)
	self:RegisterEvent("UNIT_MAXHEALTH", onPlayerEvent)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", showIfWanted)
end
