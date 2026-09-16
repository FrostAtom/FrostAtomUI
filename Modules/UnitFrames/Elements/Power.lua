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
		local current, max = UnitPower(unit), UnitPowerMax(unit)
		power:SetMinMaxValues(0, max)
		setValue(power, current)

		local r, g, b = unpack(powerColors[UnitPowerType(unit)])
		power:SetStatusBarColor(r, g, b)
		power.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
		power.text:SetText(FormatValue(current))
	end
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

	power.text = power:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
	power.text:SetTextColor(unpack(UF.textColor))

	power:SetScript("OnUpdate", onUpdate)
	for _, event in ipairs({
		"UNIT_MAXMANA",
		"UNIT_MAXRAGE",
		"UNIT_MAXFOCUS",
		"UNIT_MAXENERGY",
		"UNIT_MAXRUNIC_POWER",
		"UNIT_DISPLAYPOWER",
	}) do
		frame:RegisterUnitEvent(event, update)
	end

	return power
end

UF:RegisterElement("power", create, update)
