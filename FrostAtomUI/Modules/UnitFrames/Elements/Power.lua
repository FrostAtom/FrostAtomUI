local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitIsConnected = UnitIsConnected
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitGUID = UnitGUID

local powerColors = UF.powerColors
local setBarColor = UF.SetBarColor
local config = ns.Config.unitFrames

local POWER_CHANGE_EVENTS = {
	"UNIT_MAXMANA",
	"UNIT_MAXRAGE",
	"UNIT_MAXFOCUS",
	"UNIT_MAXENERGY",
	"UNIT_MAXRUNIC_POWER",
	"UNIT_DISPLAYPOWER",
}

local function setPower(power, setValue, current, max, powerType)
	power:SetMinMaxValues(0, max)
	setValue(power, current)

	if power.colorType ~= powerType then
		power.colorType = powerType
		local color = powerColors[powerType]
		setBarColor(power, color[1], color[2], color[3])
	end
	local frame = power:GetParent()
	if max > 0 then
		UF.UpdateText(frame, power.text, "power")
	else
		power.text:SetText(nil)
	end
	if frame.name then
		UF.UpdateTextIfUses(frame, frame.name, "left", "power")
	end
	if frame.health.lastCurrent then
		UF.UpdateTextIfUses(frame, frame.health.text, "right", "power")
	end
end

local function update(frame)
	local unit = frame.unit
	local power = frame.power

	local guid = UnitGUID(unit)
	local setValue = power.SetValue
	if guid ~= power.guid then
		power.guid = guid
		power.colorType = nil
		setValue = power.SnapValue
	end

	if not UnitIsConnected(unit) then
		power:SetMinMaxValues(0, 1)
		setValue(power, 0)
		power.colorType = nil
		power.bg:SetVertexColor(frame:GetBackdropColor())
		power.text:SetText(nil)
	else
		setPower(power, setValue, UnitPower(unit), UnitPowerMax(unit), UnitPowerType(unit))
	end
end

local function test(frame)
	local power, data = frame.power, frame.test
	power.lastValue = UnitPower(frame.unit)
	setPower(power, power.SnapValue, data.dead and 0 or data.power, data.powerMax, data.powerType)
end

local function onUpdate(power)
	local current = UnitPower(power.unit)
	if current ~= power.lastValue then
		power.lastValue = current
		update(power:GetParent())
	end
end

local function create(frame)
	local power = CreateFrame("StatusBar", nil, frame)
	power:SetFrameLevel(frame:GetFrameLevel())
	ns.SkinStatusBar(power)
	power.unit = frame.unit
	ns.SmoothBar(power)

	power.bg = power:CreateTexture(nil, "BORDER")
	power.bg:SetAllPoints()
	power.bg:SetTexture(ns.Media.blank)

	power.text = power:CreateFontString(nil, "OVERLAY")
	ns.SetFont(power.text, config.textFont.size, config.textFont.outline)
	power.text:SetTextColor(unpack(UF.textColor))

	power:SetScript("OnUpdate", onUpdate)
	for i = 1, #POWER_CHANGE_EVENTS do
		frame:RegisterUnitEvent(POWER_CHANGE_EVENTS[i], update)
	end

	return power
end

UF:RegisterElement("power", create, update, test)

local MANA = 0
local MANA_TEXT_COLOR = { 0.35, 0.6, 1 }
local MANA_TEXT_INSET = 2
local TEST_MANA_MAX = 24000

local function setManaText(druidMana, current, max)
	druidMana.lastValue = current
	druidMana.text:SetFormattedText("%s (%d%%)", ns.FormatValue(current), max > 0 and current / max * 100 or 0)
end

local function updateDruidMana(frame)
	local druidMana = frame.druidmana
	local unit = frame.unit
	local max = unit == "player" and UnitPowerMax(unit, MANA) or 0
	if not config.druidMana or max <= 0 or UnitPowerType(unit) == MANA then
		druidMana:Hide()
		return
	end
	ns.SetFont(druidMana.text, config.textFont.size, config.textFont.outline)
	setManaText(druidMana, UnitPower(unit, MANA), max)
	druidMana:Show()
end

local function testDruidMana(frame)
	local druidMana, data = frame.druidmana, frame.test
	if not config.druidMana or data.class ~= "DRUID" or data.powerType == MANA then
		druidMana:Hide()
		return
	end
	ns.SetFont(druidMana.text, config.textFont.size, config.textFont.outline)
	setManaText(druidMana, math.floor(TEST_MANA_MAX * math.random(10, 100) / 100), TEST_MANA_MAX)
	druidMana:Show()
end

local function onDruidManaUpdate(druidMana)
	local current = UnitPower("player", MANA)
	if current ~= druidMana.lastValue then
		setManaText(druidMana, current, UnitPowerMax("player", MANA))
	end
end

local function createDruidMana(frame)
	local power = frame.power
	local druidMana = CreateFrame("Frame", nil, power)
	druidMana:SetAllPoints()
	druidMana:Hide()
	druidMana:SetScript("OnUpdate", onDruidManaUpdate)

	local text = druidMana:CreateFontString(nil, "OVERLAY")
	text:SetPoint("LEFT", MANA_TEXT_INSET, 0)
	text:SetTextColor(MANA_TEXT_COLOR[1], MANA_TEXT_COLOR[2], MANA_TEXT_COLOR[3])
	druidMana.text = text

	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", updateDruidMana)
	frame:RegisterUnitEvent("UNIT_MAXMANA", updateDruidMana)

	return druidMana
end

UF:RegisterElement("druidmana", createDruidMana, updateDruidMana, testDruidMana)
