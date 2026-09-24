local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local IsResting = IsResting
local UnitIsPVP = UnitIsPVP
local UnitIsPVPFreeForAll = UnitIsPVPFreeForAll
local UnitFactionGroup = UnitFactionGroup
local IsPVPTimerRunning, GetPVPTimer = IsPVPTimerRunning, GetPVPTimer
local GetPetHappiness = GetPetHappiness
local GetTime = GetTime
local random, floor = math.random, math.floor

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

local function setPvpTimer(frame, remaining)
	local timer = frame.pvp.timer
	if not timer then
		return
	end
	if remaining and remaining > 0 and config.pvpTimer and frame.pvp:IsShown() then
		ns.SetFont(timer.text, config.textFont.size, config.textFont.outline)
		timer.endTime = GetTime() + remaining
		timer.shown = nil
		timer:Show()
	else
		timer:Hide()
	end
end

local function updatePvp(frame)
	setPvp(frame.pvp, pvpVariant(frame.baseUnit))
	setPvpTimer(frame, IsPVPTimerRunning() and GetPVPTimer() / 1000)
end

local function testPvp(frame)
	setPvp(frame.pvp, PVP_VARIANTS[random(#PVP_VARIANTS)])
	setPvpTimer(frame, random(2) == 1 and random(10, 300))
end

local function onPvpTimerUpdate(timer)
	local remaining = floor(timer.endTime - GetTime())
	if remaining == timer.shown then
		return
	end
	if remaining < 0 then
		timer:Hide()
		return
	end
	timer.shown = remaining
	timer.text:SetFormattedText("%d:%02d", floor(remaining / 60), remaining % 60)
end

local function onPlayerFlagsChanged(frame, unit)
	if unit == "player" then
		updatePvp(frame)
	end
end

local function createPvpTimer(frame, pvp)
	local timer = CreateFrame("Frame", nil, frame)
	timer:SetFrameLevel(frame:GetFrameLevel() + 3)
	timer:SetAllPoints(pvp)
	timer:Hide()
	timer:SetScript("OnUpdate", onPvpTimerUpdate)

	timer.text = timer:CreateFontString(nil, "OVERLAY")
	timer.text:SetPoint("TOP", pvp, "BOTTOM", 0, 1)
	timer.text:SetTextColor(unpack(config.textColor))
	pvp.timer = timer

	frame:RegisterEvent("PLAYER_FLAGS_CHANGED", onPlayerFlagsChanged)
end

local function createPvp(frame)
	local pvp = frame:CreateTexture(nil, "OVERLAY")
	pvp:SetSize(16, 16)
	pvp:SetTexCoord(0, 0.6, 0, 0.6)
	pvp:Hide()

	frame:RegisterUnitEvent("UNIT_FACTION", updatePvp)
	if frame.baseUnit == "player" then
		createPvpTimer(frame, pvp)
	end

	return pvp
end

UF:RegisterElement("pvp", createPvp, updatePvp, testPvp)

local HAPPINESS_COORDS = {
	{ 0.375, 0.5625, 0, 0.359375 },
	{ 0.1875, 0.375, 0, 0.359375 },
	{ 0, 0.1875, 0, 0.359375 },
}

local function setHappiness(icon, happiness)
	local coords = config.petHappiness and happiness and HAPPINESS_COORDS[happiness]
	if coords then
		icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		icon:Show()
	else
		icon:Hide()
	end
end

local function updateHappiness(frame)
	setHappiness(frame.happiness, frame.unit == "pet" and GetPetHappiness())
end

local function testHappiness(frame)
	setHappiness(frame.happiness, random(2) == 1 and random(3))
end

local function createHappiness(frame)
	local icon = frame.health:CreateTexture(nil, "OVERLAY")
	icon:SetSize(14, 14)
	icon:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
	icon:Hide()

	frame:RegisterUnitEvent("UNIT_HAPPINESS", updateHappiness)

	return icon
end

UF:RegisterElement("happiness", createHappiness, updateHappiness, testHappiness)
