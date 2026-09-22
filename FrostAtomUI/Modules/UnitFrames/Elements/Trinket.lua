local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local random = math.random

local CooldownTimer = ns:GetModule("CooldownTimer")

local TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02"

local TRINKET_SPELLS = {
	[42292] = 120, -- PvP Trinket
	[59752] = 120, -- Every Man for Himself
	[7744] = 45, -- Will of the Forsaken
}

local cooldownBySpellName = {}
for spellId, cooldown in pairs(TRINKET_SPELLS) do
	local name = GetSpellInfo(spellId)
	if name then
		cooldownBySpellName[name] = cooldown
	end
end

local function update(frame)
	frame.trinket:Show()
end

local function test(frame)
	frame.trinket:Show()
	if random(3) == 1 then
		frame.trinket.cooldown:SetCooldown(0, 0)
	else
		frame.trinket.cooldown:SetCooldown(GetTime() - random(0, 100), 120)
	end
end

local function onSpellSucceeded(frame, spellName)
	local cooldown = cooldownBySpellName[spellName]
	if cooldown then
		frame.trinket.cooldown:SetCooldown(GetTime(), cooldown)
	end
end

local function reset(frame)
	frame.trinket.cooldown:SetCooldown(0, 0)
end

local function onOpponentUpdate(frame, unit, reason)
	if unit == frame.unit and reason == "cleared" then
		reset(frame)
	end
end

local function setIconSize(trinket, size)
	trinket:SetSize(size, size)
	ns.SetFont(trinket.cooldown.timer, size * 0.4, "OUTLINE")
end

local function create(frame, options)
	local size = options and options.size or 30

	local trinket = CreateFrame("Frame", nil, frame)
	trinket:SetSize(size, size)
	trinket.SetIconSize = setIconSize

	trinket.icon = trinket:CreateTexture(nil, "BORDER")
	trinket.icon:SetTexture(TRINKET_ICON)
	UF.SkinIcon(trinket, trinket.icon)

	trinket.cooldown = CreateFrame("Cooldown", nil, trinket)
	trinket.cooldown:SetAllPoints()
	CooldownTimer:Attach(trinket.cooldown, size * 0.4)

	frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", onSpellSucceeded)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", onOpponentUpdate)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", reset)

	return trinket
end

UF:RegisterElement("trinket", create, update, test)
