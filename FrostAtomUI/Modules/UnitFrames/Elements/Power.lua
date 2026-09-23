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
