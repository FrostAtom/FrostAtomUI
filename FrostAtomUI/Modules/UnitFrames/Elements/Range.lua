local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitInRange = UnitInRange
local UnitIsUnit = UnitIsUnit
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local CheckInteractDistance = CheckInteractDistance
local GetTime = GetTime

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
local config = ns.Config.unitFrames

local function update(frame)
	frame.range.nextCheck = GetTime() + UPDATE_INTERVAL
	frame:SetAlpha(isInRange(frame.unit) and 1 or config.outOfRangeAlpha)
end

local function test(frame)
	frame.range.nextCheck = math.huge
	frame:SetAlpha(math.random(4) == 1 and config.outOfRangeAlpha or 1)
end

local function onUpdate(range)
	if GetTime() >= range.nextCheck then
		update(range:GetParent())
	end
end

local function create(frame)
	local range = CreateFrame("Frame", nil, frame)
	range.nextCheck = 0
	range:SetScript("OnUpdate", onUpdate)

	return range
end

UF:RegisterElement("range", create, update, test)
