local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local unpack = unpack

local FormatValue = ns.FormatValue
local ColorGradient = ns.ColorGradient

-- red -> yellow -> green
local GRADIENT = { 0.8, 0.2, 0.2, 0.65, 0.63, 0.35, 0.33, 0.59, 0.33 }

local function update(frame)
	local unit = frame.unit
	local health = frame.health

	if not UnitIsConnected(unit) then
		health:SetMinMaxValues(0, 1)
		health:SetValue(0)
		health.bg:SetVertexColor(frame:GetBackdropColor())
		health.text:SetText("offline")
	elseif UnitIsDeadOrGhost(unit) then
		health:SetMinMaxValues(0, 1)
		health:SetValue(0)

		local r, g, b = ColorGradient(0, unpack(GRADIENT))
		health.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
		health.text:SetText("RIP")
	else
		local current, max = UnitHealth(unit), UnitHealthMax(unit)
		health:SetMinMaxValues(0, max)
		health:SetValue(current)

		local r, g, b = ColorGradient(current / max, unpack(GRADIENT))
		health:SetStatusBarColor(r, g, b)
		health.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3)
		health.text:SetText(FormatValue(current))
	end
end

-- Polled every frame: UNIT_HEALTH is throttled server-side and lags behind.
local function onUpdate(health)
	local current = UnitHealth(health.unit)
	if current ~= health.lastValue then
		health.lastValue = current
		update(health:GetParent())
	end
end

local function create(frame)
	local health = CreateFrame("StatusBar", nil, frame)
	health:SetFrameLevel(frame:GetFrameLevel())
	health:SetStatusBarTexture(ns.Media.blank)
	health.unit = frame.unit

	health.bg = health:CreateTexture(nil, "BORDER")
	health.bg:SetAllPoints()
	health.bg:SetTexture(ns.Media.blank)

	health.text = health:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
	health.text:SetTextColor(unpack(UF.textColor))

	health:SetScript("OnUpdate", onUpdate)
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", update)

	return health
end

UF:RegisterElement("health", create, update)
