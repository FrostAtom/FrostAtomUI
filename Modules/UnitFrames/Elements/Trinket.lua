local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- PvP trinket tracker for arena frames: the icon shows the trinket's
-- cooldown once the unit uses it (or a racial that shares the cooldown).
--
-- Options: size (default 30).

local CreateFrame = CreateFrame
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime

local CooldownTimer = ns:GetModule("CooldownTimer")

local TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02"

-- spell id -> cooldown it puts the trinket on
local TRINKET_SPELLS = {
	[42292] = 120, -- PvP Trinket
	[59752] = 120, -- Every Man for Himself
	[7744] = 45, -- Will of the Forsaken (shares 45s with the trinket in 3.3)
}

-- Matched by name: UNIT_SPELLCAST_SUCCEEDED reports the spell name.
local cooldownBySpellName = {}
for spellId, cooldown in pairs(TRINKET_SPELLS) do
	local name = GetSpellInfo(spellId)
	if name then
		cooldownBySpellName[name] = cooldown
	end
end

local function update(frame)
	-- Nothing can be queried: the state only changes through casts.
	frame.trinket:Show()
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

-- "cleared" means the slot is empty again (match over); "seen"/"unseen" are
-- stealth toggles and must keep the cooldown.
local function onOpponentUpdate(frame, unit, reason)
	if unit == frame.unit and reason == "cleared" then
		reset(frame)
	end
end

local function create(frame, options)
	local size = options and options.size or 30

	local trinket = CreateFrame("Frame", nil, frame)
	trinket:SetSize(size, size)

	trinket.icon = trinket:CreateTexture(nil, "BORDER")
	trinket.icon:SetAllPoints()
	trinket.icon:SetTexture(TRINKET_ICON)
	trinket.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	trinket.cooldown = CreateFrame("Cooldown", nil, trinket)
	trinket.cooldown:SetAllPoints()
	CooldownTimer:Attach(trinket.cooldown, size * 0.4)

	frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", onSpellSucceeded)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", onOpponentUpdate)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", reset)

	return trinket
end

UF:RegisterElement("trinket", create, update)
