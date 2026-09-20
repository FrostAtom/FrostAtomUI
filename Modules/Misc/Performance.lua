local _, ns = ...

local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats
local ColorGradient = ns.ColorGradient
local unpack = unpack

local UPDATE_INTERVAL = 1
local VALUE_FONT_SIZE, UNIT_FONT_SIZE = 16, 11
local LINE_HEIGHT = 18
local UNIT_GAP, UNIT_LIFT = 3, 1
local FPS_WORST, FPS_BEST = 15, 45
local LATENCY_WORST, LATENCY_BEST = 300, 70

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetPoint(unpack(ns.Config.performance))
frame:SetFrameStrata("LOW")

local function createReadout(unit)
	local value = frame:CreateFontString(nil, "OVERLAY")
	value:SetFont(ns.Media.fontBold, VALUE_FONT_SIZE, "OUTLINE")

	local label = frame:CreateFontString(nil, "OVERLAY")
	label:SetFont(ns.Media.fontBold, UNIT_FONT_SIZE, "OUTLINE")
	label:SetTextColor(0.62, 0.62, 0.62)
	label:SetText(unit)
	label:SetPoint("BOTTOMLEFT", value, "BOTTOMRIGHT", UNIT_GAP, UNIT_LIFT)

	return value, label
end

local fpsValue, fpsLabel = createReadout("fps")
fpsValue:SetText("888")
local columnWidth = fpsValue:GetStringWidth()
fpsValue:SetPoint("TOPRIGHT", frame, "TOPLEFT", columnWidth, 0)

local latencyValue = createReadout("ms")
latencyValue:SetPoint("TOPRIGHT", fpsValue, "TOPRIGHT", 0, -LINE_HEIGHT)

frame:SetSize(columnWidth + UNIT_GAP + fpsLabel:GetStringWidth(), LINE_HEIGHT * 2)

local function qualityColor(value, worst, best)
	local r, g, b = ColorGradient((value - worst) / (best - worst), 1, 0.35, 0.35, 1, 0.8, 0.25, 1, 1, 1)
	return r, g, b
end

local untilNextTick = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	untilNextTick = untilNextTick - elapsed
	if untilNextTick > 0 then
		return
	end
	untilNextTick = UPDATE_INTERVAL

	local fps = GetFramerate()
	fpsValue:SetFormattedText("%d", fps + 0.5)
	fpsValue:SetTextColor(qualityColor(fps, FPS_WORST, FPS_BEST))

	local _, _, latency = GetNetStats()
	latencyValue:SetFormattedText("%d", latency)
	latencyValue:SetTextColor(qualityColor(latency, LATENCY_WORST, LATENCY_BEST))
end)
