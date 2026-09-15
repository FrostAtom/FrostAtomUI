local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- "resting" (player only) and "pvp" indicators.
--
-- Options: size (default 16 for pvp, 18 for resting).

local IsResting = IsResting
local UnitIsPVP = UnitIsPVP
local UnitIsPVPFreeForAll = UnitIsPVPFreeForAll
local UnitFactionGroup = UnitFactionGroup

--------------------------------------------------
-- Resting

local function updateResting(frame)
	if IsResting() then
		frame.resting:Show()
	else
		frame.resting:Hide()
	end
end

local function createResting(frame, options)
	local size = options and options.size or 18

	local resting = frame:CreateTexture(nil, "OVERLAY")
	resting:SetSize(size, size)
	resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	resting:SetTexCoord(0, 0.5, 0, 0.421875)
	resting:Hide()

	frame:RegisterEvent("PLAYER_UPDATE_RESTING", updateResting)

	return resting
end

UF:RegisterElement("resting", createResting, updateResting)

--------------------------------------------------
-- PvP

local PVP_TEXTURE = "Interface\\TargetingFrame\\UI-PVP-%s"

local function updatePvp(frame)
	local unit = frame.unit
	local pvp = frame.pvp

	if UnitIsPVPFreeForAll(unit) then
		pvp:SetTexture(PVP_TEXTURE:format("FFA"))
		pvp:Show()
	elseif UnitIsPVP(unit) then
		local faction = UnitFactionGroup(unit)
		if faction and faction ~= "Neutral" then
			pvp:SetTexture(PVP_TEXTURE:format(faction))
			pvp:Show()
			return
		end
		pvp:Hide()
	else
		pvp:Hide()
	end
end

local function createPvp(frame, options)
	local size = options and options.size or 16

	local pvp = frame:CreateTexture(nil, "OVERLAY")
	pvp:SetSize(size, size)
	-- The icon sits in the top left of a 64x64 texture.
	pvp:SetTexCoord(0, 0.6, 0, 0.6)
	pvp:Hide()

	frame:RegisterUnitEvent("UNIT_FACTION", updatePvp)

	return pvp
end

UF:RegisterElement("pvp", createPvp, updatePvp)
