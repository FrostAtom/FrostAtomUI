local _, ns = ...

local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats

local UPDATE_INTERVAL = 1
local UNIT_GAP, UNIT_LIFT = 3, 1

local Misc = ns:GetModule("Misc")

local frame = CreateFrame("Frame", nil, UIParent)
Misc:AnchorToConfig(frame, "performance.point")
frame:SetFrameStrata("LOW")

local function createReadout(unit)
	local value = frame:CreateFontString(nil, "OVERLAY")

	local label = frame:CreateFontString(nil, "OVERLAY")
	label:SetTextColor(0.62, 0.62, 0.62)
	label.unit = unit
	label:SetPoint("BOTTOMLEFT", value, "BOTTOMRIGHT", UNIT_GAP, UNIT_LIFT)

	return value, label
end

local fpsValue, fpsLabel = createReadout("fps")
local latencyValue, latencyLabel = createReadout("ms")

local RED = { 1, 0.3, 0.3 }
local ORANGE = { 1, 0.6, 0.2 }
local YELLOW = { 1, 0.9, 0.3 }
local GREEN = { 0.4, 1, 0.4 }

local function tierColor(value, red, orange, yellow, higherIsBetter)
	local color
	if higherIsBetter then
		color = value < red and RED or value < orange and ORANGE or value < yellow and YELLOW or GREEN
	else
		color = value >= red and RED or value >= orange and ORANGE or value >= yellow and YELLOW or GREEN
	end
	return color[1], color[2], color[3]
end

local untilNextTick = 0
local function onUpdate(_, elapsed)
	untilNextTick = untilNextTick - elapsed
	if untilNextTick > 0 then
		return
	end
	untilNextTick = UPDATE_INTERVAL

	local config = ns.Config.performance
	local fps = GetFramerate()
	fpsValue:SetFormattedText("%d", fps + 0.5)
	fpsValue:SetTextColor(tierColor(fps + 0.5, config.fpsRed, config.fpsOrange, config.fpsYellow, true))

	local _, _, latency = GetNetStats()
	latencyValue:SetFormattedText("%d", latency)
	latencyValue:SetTextColor(tierColor(latency, config.latencyRed, config.latencyOrange, config.latencyYellow))
end

local function applyConfig()
	local config = ns.Config.performance
	local valueFont, unitFont = config.valueFont, config.unitFont
	fpsValue:SetFont(ns.Media.fontBold, valueFont.size, valueFont.outline)
	latencyValue:SetFont(ns.Media.fontBold, valueFont.size, valueFont.outline)
	fpsLabel:SetFont(ns.Media.fontBold, unitFont.size, unitFont.outline)
	latencyLabel:SetFont(ns.Media.fontBold, unitFont.size, unitFont.outline)
	fpsLabel:SetText(fpsLabel.unit)
	latencyLabel:SetText(latencyLabel.unit)

	local lineHeight = valueFont.size + 2
	fpsValue:SetText("888")
	local columnWidth = fpsValue:GetStringWidth()
	fpsValue:ClearAllPoints()
	fpsValue:SetPoint("TOPRIGHT", frame, "TOPLEFT", columnWidth, 0)
	latencyValue:ClearAllPoints()
	latencyValue:SetPoint("TOPRIGHT", fpsValue, "TOPRIGHT", 0, -lineHeight)
	frame:SetSize(columnWidth + UNIT_GAP + fpsLabel:GetStringWidth(), lineHeight * 2)

	if config.enabled then
		untilNextTick = 0
		frame:SetScript("OnUpdate", onUpdate)
		frame:Show()
	else
		frame:SetScript("OnUpdate", nil)
		frame:Hide()
	end
end

applyConfig()
Misc:WatchConfig("performance", applyConfig)
