local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local IsResting = IsResting
local UnitIsPVP = UnitIsPVP
local UnitIsPVPFreeForAll = UnitIsPVPFreeForAll
local UnitFactionGroup = UnitFactionGroup
local random = math.random

local config = ns.Config.unitFrames

local function updateResting(frame)
	ns.SetShown(frame.resting, config.showRestingIcon and IsResting())
end

local function testResting(frame)
	ns.SetShown(frame.resting, config.showRestingIcon and random(2) == 1)
end

local function createResting(frame)
	local resting = frame:CreateTexture(nil, "OVERLAY")
	resting:SetSize(18, 18)
	resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	resting:SetTexCoord(0, 0.5, 0, 0.421875)
	resting:Hide()

	frame:RegisterEvent("PLAYER_UPDATE_RESTING", updateResting)

	return resting
end

UF:RegisterElement("resting", createResting, updateResting, testResting)

local PVP_TEXTURE = "Interface\\TargetingFrame\\UI-PVP-%s"
local PVP_VARIANTS = { "Alliance", "Horde", "FFA", false }

local function setPvp(pvp, variant)
	if variant and config.showPvpIcon then
		pvp:SetTexture(PVP_TEXTURE:format(variant))
		pvp:Show()
	else
		pvp:Hide()
	end
end

local function pvpVariant(unit)
	if UnitIsPVPFreeForAll(unit) then
		return "FFA"
	elseif UnitIsPVP(unit) then
		local faction = UnitFactionGroup(unit)
		if faction ~= "Neutral" then
			return faction
		end
	end
end

local function updatePvp(frame)
	setPvp(frame.pvp, pvpVariant(frame.unit))
end

local function testPvp(frame)
	setPvp(frame.pvp, PVP_VARIANTS[random(#PVP_VARIANTS)])
end

local function createPvp(frame)
	local pvp = frame:CreateTexture(nil, "OVERLAY")
	pvp:SetSize(16, 16)
	pvp:SetTexCoord(0, 0.6, 0, 0.6)
	pvp:Hide()

	frame:RegisterUnitEvent("UNIT_FACTION", updatePvp)

	return pvp
end

UF:RegisterElement("pvp", createPvp, updatePvp, testPvp)
