local _, ns = ...

local L = ns.L

local GetFramerate = GetFramerate
local GetNetStats = GetNetStats
local max = math.max

local UPDATE_INTERVAL = 1
local UNIT_GAP, UNIT_LIFT = 3, 1
local GROUP_GAP = 8

local Misc = ns:GetModule("Misc")

local frame = CreateFrame("Frame", nil, UIParent)
Misc:AnchorToConfig(frame, "performance.point", "Performance")
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
	if config.showFps then
		local fps = GetFramerate()
		fpsValue:SetFormattedText("%d", fps + 0.5)
		fpsValue:SetTextColor(tierColor(fps + 0.5, config.fpsRed, config.fpsOrange, config.fpsYellow, true))
	end

	if config.showLatency then
		local _, _, latency = GetNetStats()
		latencyValue:SetFormattedText("%d", latency)
		latencyValue:SetTextColor(tierColor(latency, config.latencyRed, config.latencyOrange, config.latencyYellow))
	end
end

local function setShown(region, shown)
	if shown then
		region:Show()
	else
		region:Hide()
	end
end

local function applyConfig()
	local config = ns.Config.performance
	local valueFont, unitFont = config.valueFont, config.unitFont
	ns.SetFont(fpsValue, valueFont.size, valueFont.outline, true)
	ns.SetFont(latencyValue, valueFont.size, valueFont.outline, true)
	ns.SetFont(fpsLabel, unitFont.size, unitFont.outline, true)
	ns.SetFont(latencyLabel, unitFont.size, unitFont.outline, true)
	fpsLabel:SetText(fpsLabel.unit)
	latencyLabel:SetText(latencyLabel.unit)
	setShown(fpsValue, config.showFps)
	setShown(fpsLabel, config.showFps)
	setShown(latencyValue, config.showLatency)
	setShown(latencyLabel, config.showLatency)

	local lineHeight = valueFont.size + 2
	fpsValue:SetText("888")
	local fpsColumn = fpsValue:GetStringWidth()
	latencyValue:SetText("8888")
	local latencyColumn = latencyValue:GetStringWidth()
	local fpsWidth = config.showFps and fpsColumn + UNIT_GAP + fpsLabel:GetStringWidth() or 0
	local latencyWidth = config.showLatency and latencyColumn + UNIT_GAP + latencyLabel:GetStringWidth() or 0
	if fpsWidth > 0 and latencyWidth > 0 then
		fpsWidth = fpsWidth + GROUP_GAP
	end
	fpsValue:ClearAllPoints()
	fpsValue:SetPoint("TOPRIGHT", frame, "TOPLEFT", fpsColumn, 0)
	latencyValue:ClearAllPoints()
	latencyValue:SetPoint("TOPRIGHT", frame, "TOPLEFT", fpsWidth + latencyColumn, 0)
	frame:SetSize(max(fpsWidth + latencyWidth, 1), lineHeight)

	if config.enabled and (config.showFps or config.showLatency) then
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

ns.OnLocaleReady(function()
	fpsLabel.unit = L["fps"]
	latencyLabel.unit = L["ms"]
	applyConfig()
end)
