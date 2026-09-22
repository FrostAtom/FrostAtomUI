local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetComboPoints = GetComboPoints
local UnitHasVehicleUI = UnitHasVehicleUI
local MAX_COMBO_POINTS = MAX_COMBO_POINTS or 5

local config = ns.Config.unitFrames

local EMPTY_COLOR = { 0.2, 0.2, 0.2 }

local function setPoints(combo, points)
	if points == 0 then
		combo:Hide()
		return
	end

	local color = points == MAX_COMBO_POINTS and config.comboPointColor or config.comboPointPartialColor
	for i = 1, MAX_COMBO_POINTS do
		local point = combo[i]
		if i <= points then
			point:SetTexture(color[1], color[2], color[3])
		else
			point:SetTexture(EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3])
		end
	end
	combo:Show()
end

local function update(frame)
	local source = UnitHasVehicleUI("player") and "vehicle" or "player"
	setPoints(frame.combopoints, GetComboPoints(source, frame.unit))
end

local function test(frame)
	setPoints(frame.combopoints, math.random(0, MAX_COMBO_POINTS))
end

local function setPointSize(combo, size)
	local gap = combo.gap
	combo:SetSize(MAX_COMBO_POINTS * size + (MAX_COMBO_POINTS - 1) * gap, size)
	for i = 1, MAX_COMBO_POINTS do
		local point = combo[i]
		point:SetSize(size, size)
		point:ClearAllPoints()
		point:SetPoint("LEFT", (i - 1) * (size + gap), 0)
	end
end

local function create(frame, options)
	options = options or {}

	local combo = CreateFrame("Frame", nil, frame)
	combo:Hide()
	combo:SetFrameLevel(frame:GetFrameLevel() + 2)
	combo.gap = options.gap or 2
	combo.SetPointSize = setPointSize

	for i = 1, MAX_COMBO_POINTS do
		combo[i] = combo:CreateTexture(nil, "OVERLAY")
	end
	setPointSize(combo, config.comboPointSize)

	frame:RegisterEvent("UNIT_COMBO_POINTS", update)

	return combo
end

UF:RegisterElement("combopoints", create, update, test)
