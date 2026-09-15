local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- Shows the icon and remaining duration of the longest crowd-control debuff.

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local GetSpellInfo = GetSpellInfo

local CooldownTimer = ns:GetModule("CooldownTimer")

local MAX_AURAS = 40

-- Stuns, fears, silences, roots, disarms and a few raid boss debuffs.
-- stylua: ignore
local CC_SPELL_IDS = {
	47481, 51209, 47476, 5211, 33786, 2637, 22570, 9005,
	339, 19675, 60210, 3355, 24394, 1513, 19503, 19386,
	34490, 53359, 19306, 19185, 50519, 50541, 50245, 50518,
	54706, 4167, 44572, 31661, 12355, 118, 18469, 64346,
	33395, 122, 11071, 55080, 853, 2812, 20066, 20170,
	10326, 63529, 605, 64044, 8122, 9484, 15487, 2094,
	1833, 1776, 408, 6770, 1330, 18425, 51722, 39796,
	51514, 64695, 63685, 710, 6789, 5782, 5484, 6358,
	30283, 24259, 7922, 12809, 20253, 5246, 12798, 46968,
	18498, 676, 58373, 23694, 30217, 67769, 30216, 20549,
	25046, 39965, 55536, 13099, 28169, 28059, 28084, 27819,
	63024, 63018, 62589, 63276, 66770, 48792,
}

-- Auras are matched by name: ranks and duplicates share one entry.
local CC_SPELL_NAMES = {}
for _, spellId in ipairs(CC_SPELL_IDS) do
	local name = GetSpellInfo(spellId)
	if name then
		CC_SPELL_NAMES[name] = true
	end
end

local function update(frame)
	local unit = frame.unit
	local loseControl = frame.losecontrol

	local longestEnd, longestDuration, longestTexture = 0
	for i = 1, MAX_AURAS do
		local name, _, texture, _, _, duration, endTime = UnitAura(unit, i, "HARMFUL")
		if not name then
			break
		end

		if CC_SPELL_NAMES[name] and endTime > longestEnd then
			longestEnd, longestDuration, longestTexture = endTime, duration, texture
		end
	end

	if longestEnd == 0 then
		loseControl:Hide()
	else
		loseControl.texture:SetTexture(longestTexture)
		loseControl:SetCooldown(longestEnd - longestDuration, longestDuration)
	end
end

local function create(frame, fontSize)
	local loseControl = CreateFrame("Cooldown", nil, frame)
	loseControl:SetReverse(true)
	CooldownTimer:Attach(loseControl, fontSize or 10)

	loseControl.texture = loseControl:CreateTexture(nil, "BORDER")
	loseControl.texture:SetAllPoints()

	frame:RegisterUnitEvent("UNIT_AURA", update)

	return loseControl
end

UF:RegisterElement("losecontrol", create, update)
