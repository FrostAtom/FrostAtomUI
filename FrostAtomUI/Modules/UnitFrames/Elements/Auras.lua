local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CancelUnitBuff = CancelUnitBuff
local GameTooltip = GameTooltip
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local min, random = math.min, math.random

local Auras = ns.Auras

local MAX_AURAS = 40
local COUNT_FONT_SCALE = 0.45

local debuffColors = UF.debuffColors
local NO_TYPE_COLOR = debuffColors[""]
local STEALABLE_COLOR = debuffColors.Magic

local PURGE_CLASSES = { PRIEST = true, SHAMAN = true, MAGE = true, HUNTER = true, WARLOCK = true }
local canPurge = PURGE_CLASSES[ns.PLAYER_CLASS]

local TEST_BUFFS = {
	48161, -- Power Word: Fortitude
	48469, -- Mark of the Wild
	42995, -- Arcane Intellect
	48066, -- Power Word: Shield
	48068, -- Renew
	48441, -- Rejuvenation
	1044, -- Hand of Freedom
	10060, -- Power Infusion
	12472, -- Icy Veins
	31884, -- Avenging Wrath
	33206, -- Pain Suppression
	47788, -- Guardian Spirit
	6940, -- Hand of Sacrifice
	53563, -- Beacon of Light
	2825, -- Bloodlust
	12042, -- Arcane Power
	48792, -- Icebound Fortitude
	871, -- Shield Wall
	18499, -- Berserker Rage
	2983, -- Sprint
}
local TEST_DEBUFFS = {
	48125, -- Shadow Word: Pain
	48160, -- Vampiric Touch
	47843, -- Unstable Affliction
	47813, -- Corruption
	47864, -- Curse of Agony
	12826, -- Polymorph
	51514, -- Hex
	10308, -- Hammer of Justice
	33786, -- Cyclone
	10890, -- Psychic Scream
	6215, -- Fear
	47476, -- Strangulate
	44572, -- Deep Freeze
	42917, -- Frost Nova
	8643, -- Kidney Shot
	57975, -- Wound Poison
	49001, -- Serpent Sting
	47486, -- Mortal Strike
	3409, -- Crippling Poison
	55095, -- Frost Fever
	55078, -- Blood Plague
	12579, -- Winter's Chill
}
local TEST_DEBUFF_TYPES = { "Magic", "Curse", "Poison", "Disease", false }

local hoveredIcon

local function refreshTooltip(icon)
	GameTooltip:SetUnitAura(icon.unit, icon:GetID(), icon.filter)
end

local function onIconEnter(icon)
	hoveredIcon = icon
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	refreshTooltip(icon)
end

local function onIconLeave(icon)
	if hoveredIcon == icon then
		hoveredIcon = nil
	end
	GameTooltip:Hide()
end

local function onIconClick(icon)
	CancelUnitBuff("player", icon:GetID(), icon.filter)
end

local function onIconResize(icon, size)
	ns.SetFont(icon.count, size * COUNT_FONT_SCALE, "OUTLINE")
end

local function createIcon(container, index)
	local icon = CreateFrame("Button", nil, container)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:SetSize(container.size, container.size)
	icon:SetPoint(UF.GridIconPoint(container, index))
	icon:SetID(index)
	icon.unit = container.unit
	icon.filter = container.filter
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)
	icon.cooldown:SetDrawEdge(true)
	icon.cooldown:SetFrameLevel(icon:GetFrameLevel())

	icon.texture = icon:CreateTexture(nil, "BACKGROUND")
	UF.SkinIcon(icon, icon.texture)

	icon.count = icon:CreateFontString(nil, "OVERLAY")
	icon.count:SetPoint("BOTTOMRIGHT", icon, -1, 0)
	icon.OnResize = onIconResize
	onIconResize(icon, container.size)

	if container.unit == "player" then
		icon:RegisterForClicks("RightButtonDown")
		icon:SetScript("OnClick", onIconClick)
	else
		icon:RegisterForClicks()
	end

	if container.isDebuff or canPurge then
		icon.overlay = icon:CreateTexture(nil, "OVERLAY")
		icon.overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		icon.overlay:SetAllPoints()
		icon.overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		icon.isDebuff = container.isDebuff
	end

	return icon
end

local function setIcon(icon, texture, count, debuffType, duration, endTime, stealable)
	icon.texture:SetTexture(texture)

	local overlay = icon.overlay
	if overlay then
		if icon.isDebuff then
			local color = debuffType and debuffColors[debuffType] or NO_TYPE_COLOR
			overlay:SetVertexColor(color[1], color[2], color[3])
		elseif stealable then
			overlay:SetVertexColor(STEALABLE_COLOR[1], STEALABLE_COLOR[2], STEALABLE_COLOR[3])
			overlay:Show()
		else
			overlay:Hide()
		end
	end

	if duration and duration > 0 then
		local start = endTime - duration
		if start ~= icon.start or duration ~= icon.duration then
			icon.start, icon.duration = start, duration
			icon.cooldown:SetCooldown(start, duration)
		end
	else
		icon.start = nil
		icon.cooldown:Hide()
	end

	if count and count > 1 then
		icon.count:SetFormattedText("%d", count)
		icon.count:Show()
	else
		icon.count:Hide()
	end

	icon:Show()
	if icon == hoveredIcon then
		refreshTooltip(icon)
	end
end

local function updateContainer(container)
	local auras, count = Auras.Get(container.unit, container.filter)

	local shown = min(count, container.limit)
	for i = 1, shown do
		local aura = auras[i]
		local icon = container[i]
		if not icon then
			icon = createIcon(container, i)
			container[i] = icon
		end
		setIcon(icon, aura.icon, aura.count, aura.debuffType, aura.duration, aura.expires, aura.stealable)
	end

	container:Layout(shown)
end

local function testContainer(container, spells)
	local now = GetTime()
	local shown = random(0, min(container.limit, container.perRow * 2))
	for i = 1, shown do
		local icon = container[i]
		if not icon then
			icon = createIcon(container, i)
			container[i] = icon
		end
		local _, _, texture = GetSpellInfo(spells[random(#spells)])
		local duration = random(3) == 1 and 0 or random(8, 60)
		local count = random(3) == 1 and random(2, 5) or 1
		local debuffType = TEST_DEBUFF_TYPES[random(#TEST_DEBUFF_TYPES)] or nil
		setIcon(icon, texture, count, debuffType, duration, now + duration, random(4) == 1)
	end
	container:Layout(shown)
end

local function setLimit(container, limit)
	container.limit = min(limit or MAX_AURAS, MAX_AURAS)
end

local function createContainer(frame, options, filter, isDebuff)
	local container = UF:CreateIconGrid(frame, options)
	container.unit = frame.unit
	container.filter = filter
	container.isDebuff = isDebuff
	container.SetLimit = setLimit
	setLimit(container, container.max)
	return container
end

local function updateBuffs(frame)
	updateContainer(frame.buffs)
end

local function createBuffs(frame, options)
	frame:RegisterUnitEvent("UNIT_AURA", updateBuffs)
	return createContainer(frame, options, "HELPFUL", false)
end

local function testBuffs(frame)
	testContainer(frame.buffs, TEST_BUFFS)
end

UF:RegisterElement("buffs", createBuffs, updateBuffs, testBuffs)

local function updateDebuffs(frame)
	updateContainer(frame.debuffs)
end

local function createDebuffs(frame, options)
	frame:RegisterUnitEvent("UNIT_AURA", updateDebuffs)
	return createContainer(frame, options, "HARMFUL", true)
end

local function testDebuffs(frame)
	testContainer(frame.debuffs, TEST_DEBUFFS)
end

UF:RegisterElement("debuffs", createDebuffs, updateDebuffs, testDebuffs)
