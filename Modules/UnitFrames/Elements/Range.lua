local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitInRange = UnitInRange
local UnitIsUnit = UnitIsUnit
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local CheckInteractDistance = CheckInteractDistance

local function isInRange(unit)
	if UnitIsUnit(unit, "player") then
		return true
	elseif UnitInParty(unit) or UnitInRaid(unit) then
		return UnitInRange(unit)
	else
		return CheckInteractDistance(unit, 4)
	end
end

local UPDATE_INTERVAL = 0.25
local OUT_OF_RANGE_ALPHA = ns.Config.unitFrames.outOfRangeAlpha

local function update(frame)
	frame:SetAlpha(isInRange(frame.unit) and 1 or OUT_OF_RANGE_ALPHA)
end

local function onUpdate(range, elapsed)
	range.timer = range.timer - elapsed
	if range.timer <= 0 then
		range.timer = UPDATE_INTERVAL
		update(range:GetParent())
	end
end

local function create(frame)
	local range = CreateFrame("Frame", nil, frame)
	range.timer = 0
	range:SetScript("OnUpdate", onUpdate)

	return range
end

UF:RegisterElement("range", create, update)
