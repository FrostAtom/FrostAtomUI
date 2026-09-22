local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local random = math.random

local Auras = ns.Auras
local CooldownTimer = ns:GetModule("CooldownTimer")
local config = ns.Config.unitFrames

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

local CC_SPELL_NAMES = {}
for _, spellId in ipairs(CC_SPELL_IDS) do
	local name = GetSpellInfo(spellId)
	if name then
		CC_SPELL_NAMES[name] = true
	end
end
UF.ccSpellNames = CC_SPELL_NAMES

local function show(loseControl, texture, start, duration)
	loseControl.texture:SetTexture(texture)
	if start ~= loseControl.start or duration ~= loseControl.duration then
		loseControl.start, loseControl.duration = start, duration
		loseControl:SetCooldown(start, duration)
	end
	loseControl:Show()
end

local function hide(loseControl)
	loseControl.start = nil
	loseControl:Hide()
end

local function update(frame)
	local loseControl = frame.losecontrol
	local auras, count = Auras.Get(frame.unit, "HARMFUL")

	local longest
	for i = 1, count do
		local aura = auras[i]
		if CC_SPELL_NAMES[aura.name] and (not longest or aura.expires > longest.expires) then
			longest = aura
		end
	end

	if longest and config.showLoseControl then
		show(loseControl, longest.icon, longest.expires - longest.duration, longest.duration)
	else
		hide(loseControl)
	end
end

local function test(frame)
	local loseControl = frame.losecontrol
	if not config.showLoseControl or random(3) ~= 1 then
		hide(loseControl)
		return
	end
	local _, _, texture = GetSpellInfo(CC_SPELL_IDS[random(#CC_SPELL_IDS)])
	local duration = random(4, 10)
	show(loseControl, texture, GetTime() - random(0, duration - 2), duration)
end

local function create(frame, fontSize)
	local loseControl = CreateFrame("Cooldown", nil, frame)
	loseControl:SetReverse(true)
	CooldownTimer:Attach(loseControl, fontSize or 10)

	loseControl.texture = loseControl:CreateTexture(nil, "BORDER")
	UF.SkinIcon(loseControl, loseControl.texture)

	if frame.classicon then
		loseControl:SetAllPoints(frame.classicon)
		loseControl:SetFrameLevel(frame.classicon:GetFrameLevel() + 1)
	end

	frame:RegisterUnitEvent("UNIT_AURA", update)

	return loseControl
end

UF:RegisterElement("losecontrol", create, update, test)
