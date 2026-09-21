local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitIsConnected = UnitIsConnected
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitGUID = UnitGUID
local unpack = unpack

local FormatValue = ns.FormatValue
local powerColors = UF.powerColors
local config = ns.Config.unitFrames

local MAX_POWER_EVENTS = {
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

	local r, g, b = unpack(powerColors[powerType])
	power:SetStatusBarColor(r, g, b)
	power.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
	if power:GetParent().hovered and max > 0 then
		power.text:SetFormattedText("%s / %s", FormatValue(current), FormatValue(max))
	else
		power.text:SetText(nil)
	end
end

local function update(frame)
	local unit = frame.unit
	local power = frame.power

	local guid = UnitGUID(unit)
	local setValue = power.SetValue
	if guid ~= power.guid then
		power.guid = guid
		setValue = power.SnapValue
	end

	if not UnitIsConnected(unit) then
		power:SetMinMaxValues(0, 1)
		setValue(power, 0)
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
	power:SetStatusBarTexture(ns.Media.blank)
	power.unit = frame.unit
	ns.SmoothBar(power)

	power.bg = power:CreateTexture(nil, "BORDER")
	power.bg:SetAllPoints()
	power.bg:SetTexture(ns.Media.blank)

	power.text = power:CreateFontString(nil, "OVERLAY")
	power.text:SetFont(ns.Media.font, config.textFont.size, config.textFont.outline)
	power.text:SetTextColor(unpack(UF.textColor))

	power:SetScript("OnUpdate", onUpdate)
	for i = 1, #MAX_POWER_EVENTS do
		frame:RegisterUnitEvent(MAX_POWER_EVENTS[i], update)
	end

	return power
end

UF:RegisterElement("power", create, update, test)
