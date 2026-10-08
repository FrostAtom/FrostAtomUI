local _, ns = ...

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitAffectingCombat = UnitAffectingCombat
local UnitGUID, UnitIsDeadOrGhost = UnitGUID, UnitIsDeadOrGhost
local GetComboPoints = GetComboPoints
local floor, max = math.floor, math.max

local PlayerPlate = ns:NewModule("PlayerPlate")
local Prediction = ns.HealPrediction
local renderTags = ns.Tags.Render

local TEXT_INSET = 2
local MANA = 0
local ENERGY = 3
local MANA_HEIGHT_SCALE = 0.5
local MAX_COMBO_POINTS = MAX_COMBO_POINTS or 5
local COMBO_GAP = 2
local COMBO_EMPTY_COLOR = { 0.2, 0.2, 0.2 }
local IS_DRUID = ns.PLAYER_CLASS == "DRUID"
local HAS_COMBO_POINTS = IS_DRUID or ns.PLAYER_CLASS == "ROGUE"
local BORDER_INSET = ns.UIKit.BORDER_INSET
local themeConfig = ns.Config.theme

local plate = CreateFrame("Frame", "FrostAtomUIPlayerPlate", UIParent)
PlayerPlate:AnchorToConfig(plate, "playerPlate.point", "Player plate")
plate:SetBackdrop(ns.UIKit.backdrop)
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

local mana = createBar()
mana.text:Hide()
mana:Hide()

local function setBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
end

setBarColor(mana, unpack(ns.Colors.power[MANA]))

local combo = CreateFrame("Frame", nil, plate)
combo:Hide()
combo.points = 0
for i = 1, MAX_COMBO_POINTS do
	combo[i] = combo:CreateTexture(nil, "ARTWORK")
end

local function manaWanted()
	return IS_DRUID and ns.Config.playerPlate.druidMana and UnitPowerType("player") ~= MANA
end

local function comboAvailable()
	return HAS_COMBO_POINTS
		and ns.Config.playerPlate.comboPoints
		and not (IS_DRUID and UnitPowerType("player") ~= ENERGY)
end

local function comboPoints()
	return comboAvailable() and GetComboPoints("player", "target") or 0
end

local function colorCombo()
	local points = combo.points
	local color = points == MAX_COMBO_POINTS and themeConfig.comboPointColor or themeConfig.comboPointPartialColor
	for i = 1, MAX_COMBO_POINTS do
		local c = i <= points and color or COMBO_EMPTY_COLOR
		combo[i]:SetTexture(c[1], c[2], c[3])
	end
end

local function layoutCombo(width, height)
	combo:SetSize(width, height)
	local step = (width + COMBO_GAP) / MAX_COMBO_POINTS
	for i = 1, MAX_COMBO_POINTS do
		local left = floor((i - 1) * step + 0.5)
		local pip = combo[i]
		pip:ClearAllPoints()
		pip:SetPoint("TOPLEFT", left, 0)
		pip:SetSize(floor(i * step + 0.5) - COMBO_GAP - left, height)
	end
end

local function healthColor()
	local config = ns.Config.playerPlate
	if config.healthColorMode == "class" then
		return unpack(ns.Colors.classBar[ns.PLAYER_CLASS])
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
	health.text:SetText(renderTags(config.healthTag, "player"))
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
		setBarColor(power, unpack(ns.Colors.power[powerType]))
	end
end

local function updateMana()
	mana:SetMinMaxValues(0, UnitPowerMax("player", MANA))
	mana:SetValue(UnitPower("player", MANA))
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
	if mana:IsShown() then
		local currentMana = UnitPower("player", MANA)
		if currentMana ~= self.lastMana then
			self.lastMana = currentMana
			updateMana()
		end
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
	plate.lastHealth, plate.lastPower, plate.lastMana = nil, nil, nil
	health:SnapValue(UnitHealth("player"))
	power:SnapValue(UnitPower("player"))
	mana:SnapValue(UnitPower("player", MANA))
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
	text:SetTextColor(unpack(themeConfig.textColor))
	ns.SetShown(text, shown)
end

local function layout()
	local config = ns.Config.playerPlate
	local powerSpace = config.showPower and config.gap + config.powerHeight or 0
	local manaHeight = max(floor(config.powerHeight * MANA_HEIGHT_SCALE), 2)
	local showMana = manaWanted()
	local manaSpace = showMana and config.gap + manaHeight or 0
	local showCombo = comboAvailable()
	combo.available = showCombo
	local comboSpace = showCombo and config.gap + config.comboPointHeight or 0
	plate:SetSize(
		config.width + BORDER_INSET * 2,
		config.healthHeight + powerSpace + manaSpace + comboSpace + BORDER_INSET * 2
	)
	health:SetSize(config.width, config.healthHeight)
	power:SetSize(config.width, config.powerHeight)
	power:ClearAllPoints()
	power:SetPoint("TOP", health, "BOTTOM", 0, -config.gap)
	ns.SetShown(power, config.showPower)
	mana:SetSize(config.width, manaHeight)
	mana:ClearAllPoints()
	mana:SetPoint("TOP", config.showPower and power or health, "BOTTOM", 0, -config.gap)
	if showMana and not mana:IsShown() then
		plate.lastMana = nil
		mana:SnapValue(UnitPower("player", MANA))
	end
	ns.SetShown(mana, showMana)
	if showCombo then
		layoutCombo(config.width, config.comboPointHeight)
		combo:ClearAllPoints()
		combo:SetPoint("TOP", showMana and mana or config.showPower and power or health, "BOTTOM", 0, -config.gap)
	end
	ns.SetShown(combo, showCombo)
end

local function updateCombo()
	if comboAvailable() ~= combo.available then
		layout()
	end
	local points = comboPoints()
	if points ~= combo.points then
		combo.points = points
		colorCombo()
	end
end

local function onDisplayPower()
	layout()
	updateCombo()
end

local function applyConfig()
	local config = ns.Config.playerPlate
	Prediction:SetDemand("playerPlate", config.enabled and (config.healPrediction or config.absorbs))
	combo.points = comboPoints()
	colorCombo()
	layout()
	ns.UIKit.SetBackdropColors(plate)
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
	self:WatchConfig("theme", applyConfig)

	self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		if ns.Config.playerPlate.enabled then
			show()
		end
	end)
	self:RegisterEvent(ns.E.PREDICTION_CHANGED, function(_, guid)
		if plate:IsShown() and guid == UnitGUID("player") then
			updatePrediction()
		end
	end)
	self:RegisterEvent("UNIT_HEALTH", onPlayerEvent)
	self:RegisterEvent("UNIT_MAXHEALTH", onPlayerEvent)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", showIfWanted)
	if IS_DRUID then
		self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", onDisplayPower)
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", updateCombo)
	end
	if HAS_COMBO_POINTS then
		self:RegisterEvent("UNIT_COMBO_POINTS", updateCombo)
		self:RegisterEvent("PLAYER_TARGET_CHANGED", updateCombo)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", updateCombo)
	end
end
