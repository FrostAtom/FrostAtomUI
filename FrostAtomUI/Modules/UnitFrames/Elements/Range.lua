local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitInRange = UnitInRange
local UnitIsUnit = UnitIsUnit
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local CheckInteractDistance = CheckInteractDistance
local IsSpellInRange = IsSpellInRange
local UnitCanAttack = UnitCanAttack
local GetTime = GetTime

local UPDATE_INTERVAL = 0.25
local config = ns.Config.unitFrames

local function spellRange(spell, unit)
	if spell and spell ~= "" then
		local result = IsSpellInRange(spell, unit)
		if result ~= nil then
			return result == 1
		end
	end
end

local function isInRange(unit)
	if UnitIsUnit(unit, "player") then
		return true
	end
	local bySpell =
		spellRange(UnitCanAttack("player", unit) and config.rangeSpellHostile or config.rangeSpellFriendly, unit)
	if bySpell ~= nil then
		return bySpell
	elseif UnitInParty(unit) or UnitInRaid(unit) then
		return UnitInRange(unit)
	else
		return CheckInteractDistance(unit, 4)
	end
end

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

UF:RegisterElement({ name = "range", Create = create, Update = update, Test = test })
