local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local IsResting = IsResting
local UnitIsPVP = UnitIsPVP
local UnitIsPVPFreeForAll = UnitIsPVPFreeForAll
local UnitFactionGroup = UnitFactionGroup

local function updateResting(frame)
	if IsResting() then
		frame.resting:Show()
	else
		frame.resting:Hide()
	end
end

local function testResting(frame)
	if math.random(2) == 1 then
		frame.resting:Show()
	else
		frame.resting:Hide()
	end
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
	if variant then
		pvp:SetTexture(PVP_TEXTURE:format(variant))
		pvp:Show()
	else
		pvp:Hide()
	end
end

local function updatePvp(frame)
	local unit = frame.unit

	local variant
	if UnitIsPVPFreeForAll(unit) then
		variant = "FFA"
	elseif UnitIsPVP(unit) then
		local faction = UnitFactionGroup(unit)
		if faction ~= "Neutral" then
			variant = faction
		end
	end
	setPvp(frame.pvp, variant)
end

local function testPvp(frame)
	setPvp(frame.pvp, PVP_VARIANTS[math.random(#PVP_VARIANTS)])
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
