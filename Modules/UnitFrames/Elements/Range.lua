local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- Fades the whole frame while the unit is out of range. Polled, like
-- Blizzard's party frames do.
--
-- Options: alpha (default ns.Config.unitFrames.outOfRangeAlpha), interval
-- (seconds between checks, default 0.25).

local CreateFrame = CreateFrame
local UnitInRange = UnitInRange
local UnitIsUnit = UnitIsUnit
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local CheckInteractDistance = CheckInteractDistance

-- Group members have a proper range API; for everyone else the 28 yard
-- "follow" interaction distance is the best available guess.
local function isInRange(unit)
	if UnitIsUnit(unit, "player") then
		return true
	elseif UnitInParty(unit) or UnitInRaid(unit) then
		return UnitInRange(unit)
	else
		return CheckInteractDistance(unit, 4)
	end
end

local function update(frame)
	frame:SetAlpha(isInRange(frame.unit) and 1 or frame.range.alpha)
end

local function onUpdate(range, elapsed)
	range.timer = range.timer - elapsed
	if range.timer <= 0 then
		range.timer = range.interval
		update(range:GetParent())
	end
end

local function create(frame, options)
	options = options or {}

	local range = CreateFrame("Frame", nil, frame)
	range.alpha = options.alpha or ns.Config.unitFrames.outOfRangeAlpha
	range.interval = options.interval or 0.25
	range.timer = 0
	range:SetScript("OnUpdate", onUpdate)

	return range
end

UF:RegisterElement("range", create, update)
