local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- Row of five combo point squares (rogues, cat druids, vehicles with combo
-- points). Meant for the target frame: points are read for the frame's unit.
--
-- Options: size (default 8), gap (default 2).

local CreateFrame = CreateFrame
local GetComboPoints = GetComboPoints
local UnitHasVehicleUI = UnitHasVehicleUI
local MAX_COMBO_POINTS = MAX_COMBO_POINTS or 5

local FULL_COLOR = { 1, 0.2, 0.2 }
local PARTIAL_COLOR = { 1, 0.8, 0.2 }
local EMPTY_COLOR = { 0.2, 0.2, 0.2 }

local function update(frame)
	local combo = frame.combopoints
	local source = UnitHasVehicleUI("player") and "vehicle" or "player"
	local points = GetComboPoints(source, frame.unit)

	if points == 0 then
		combo:Hide()
		return
	end

	local color = points == MAX_COMBO_POINTS and FULL_COLOR or PARTIAL_COLOR
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

-- UNIT_COMBO_POINTS reports the player (or vehicle), not the target.
local function onComboPointsChanged(frame)
	update(frame)
end

local function create(frame, options)
	options = options or {}
	local size = options.size or 8
	local gap = options.gap or 2

	local combo = CreateFrame("Frame", nil, frame)
	combo:Hide()
	combo:SetFrameLevel(frame:GetFrameLevel() + 2)
	combo:SetSize(MAX_COMBO_POINTS * size + (MAX_COMBO_POINTS - 1) * gap, size)

	for i = 1, MAX_COMBO_POINTS do
		local point = combo:CreateTexture(nil, "OVERLAY")
		point:SetSize(size, size)
		point:SetPoint("LEFT", (i - 1) * (size + gap), 0)
		combo[i] = point
	end

	frame:RegisterEvent("UNIT_COMBO_POINTS", onComboPointsChanged)

	return combo
end

UF:RegisterElement("combopoints", create, update)
