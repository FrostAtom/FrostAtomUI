local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitCanAssist = UnitCanAssist
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local GameTooltip = GameTooltip
local random, min = math.random, math.min

local Auras = ns.Auras
local CooldownTimer = ns:GetModule("CooldownTimer")
local config = ns.Config.raidFrames
local debuffColors = UF.debuffColors
local ccSpellNames = UF.ccSpellNames
local drSpells = ns.DRData.SPELLS

local CC_TIMER_FONT_SIZE = 10
local COUNT_FONT_SCALE = 0.7
local BUFF_GAP = 1
local BUFF_INSET = 1
local BORDER_EDGE = 10
local DEFAULT_PRIORITY = 4

local CC_PRIORITY = {
	root = 1,
	randomroot = 1,
	disarm = 2,
	silence = 3,
}

local HOT_SPELLS = {
	139, -- Renew
	17, -- Power Word: Shield
	41635, -- Prayer of Mending
	33206, -- Pain Suppression
	47788, -- Guardian Spirit
	47753, -- Divine Aegis
	10060, -- Power Infusion
	774, -- Rejuvenation
	8936, -- Regrowth
	33763, -- Lifebloom
	48438, -- Wild Growth
	29166, -- Innervate
	61295, -- Riptide
	974, -- Earth Shield
	51945, -- Earthliving
	53563, -- Beacon of Light
	53601, -- Sacred Shield
	1044, -- Hand of Freedom
	1022, -- Hand of Protection
	6940, -- Hand of Sacrifice
	1038, -- Hand of Salvation
}

local TEST_CC = { 33786, 853, 8122, 118, 15487, 51514, 2094, 122 }
local TEST_DEBUFF_TYPES = { "Magic", "Curse", "Poison", "Disease" }

local hotNames = {}
for i = 1, #HOT_SPELLS do
	local name = GetSpellInfo(HOT_SPELLS[i])
	if name then
		hotNames[name] = true
	end
end

local function ccPriority(aura)
	local category = drSpells[aura.spellId]
	if category then
		return CC_PRIORITY[category] or DEFAULT_PRIORITY
	elseif ccSpellNames[aura.name] then
		return DEFAULT_PRIORITY
	end
end

local function setCC(cc, texture, start, duration)
	if not texture then
		if cc:IsShown() then
			cc.start = nil
			cc:Hide()
		end
		return
	end
	cc.texture:SetTexture(texture)
	if start ~= cc.start or duration ~= cc.duration then
		cc.start, cc.duration = start, duration
		cc:SetCooldown(start, duration)
	end
	cc:Show()
end

local function setDispel(dispel, debuffType)
	if dispel.debuffType == debuffType then
		return
	end
	dispel.debuffType = debuffType
	if not debuffType then
		dispel.border:Hide()
		dispel.overlay:Hide()
		return
	end
	local color = debuffColors[debuffType]
	if config.dispelStyle == "overlay" then
		dispel.border:Hide()
		dispel.overlay:SetVertexColor(color[1], color[2], color[3], ns.Config.dispelHighlightAlpha)
		dispel.overlay:Show()
	else
		dispel.overlay:Hide()
		dispel.border:SetBackdropBorderColor(color[1], color[2], color[3])
		dispel.border:Show()
	end
end

local function isDispellable(debuffType, canDispel)
	if not debuffType or not debuffColors[debuffType] or debuffType == "" then
		return false
	end
	if config.dispelMine then
		return canDispel ~= nil and canDispel[debuffType] == true
	end
	return true
end

local function refreshTooltip(icon)
	if icon.index then
		GameTooltip:SetUnitAura(icon:GetParent().unit, icon.index, icon.filter)
	end
end

local function onIconEnter(icon)
	if not icon.index then
		return
	end
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	refreshTooltip(icon)
end

local function onIconLeave()
	GameTooltip:Hide()
end

local function setIndex(icon, index)
	icon.index = index
	if index and GameTooltip:IsOwned(icon) then
		refreshTooltip(icon)
	end
end

local function setBuff(icon, texture, count, duration, expires)
	icon.texture:SetTexture(texture)
	if duration and duration > 0 then
		local start = expires - duration
		if start ~= icon.start or duration ~= icon.duration then
			icon.start, icon.duration = start, duration
			icon.cooldown:SetCooldown(start, duration)
		end
		icon.cooldown:Show()
	elseif icon.start then
		icon.start = nil
		icon.cooldown:Hide()
	end
	if count and count > 1 then
		icon.count:SetFormattedText("%d", count)
	else
		icon.count:SetText(nil)
	end
	icon:Show()
end

local function hideBuffs(buffs, from)
	for i = from, #buffs do
		local icon = buffs[i]
		if icon:IsShown() then
			icon.start = nil
			icon.index = nil
			icon:Hide()
		end
	end
end

local function acceptsBuff(aura)
	if config.buffFilter == "hots" then
		return hotNames[aura.name]
	end
	return aura.duration and aura.duration > 0
end

local function updateBuffs(buffs, unit)
	local limit = min(config.buffMax, #buffs)
	local shown = 0
	if limit > 0 then
		local auras, count = Auras.Get(unit, "HELPFUL|PLAYER")
		for i = 1, count do
			local aura = auras[i]
			if acceptsBuff(aura) then
				shown = shown + 1
				setBuff(buffs[shown], aura.icon, aura.count, aura.duration, aura.expires)
				setIndex(buffs[shown], i)
				if shown == limit then
					break
				end
			end
		end
	end
	hideBuffs(buffs, shown + 1)
end

local function update(frame)
	local widget = frame.raidauras
	local unit = frame.unit
	local canDispel = UF.canDispel
	local wantDispel = config.dispel and (not config.dispelMine or canDispel ~= nil) and UnitCanAssist("player", unit)
	local wantCC = config.ccIcon

	local best, bestPriority, bestIndex, dispelType
	if wantCC or wantDispel then
		local auras, count = Auras.Get(unit, "HARMFUL")
		for i = 1, count do
			local aura = auras[i]
			if wantCC then
				local priority = ccPriority(aura)
				if
					priority
					and (
						not best
						or priority > bestPriority
						or priority == bestPriority and aura.expires > best.expires
					)
				then
					best, bestPriority, bestIndex = aura, priority, i
				end
			end
			if wantDispel and not dispelType and isDispellable(aura.debuffType, canDispel) then
				dispelType = aura.debuffType
			end
		end
	end

	if best then
		setCC(widget.cc, best.icon, best.expires - best.duration, best.duration)
	else
		setCC(widget.cc, nil)
	end
	setIndex(widget.cc, bestIndex)
	setDispel(widget.dispel, dispelType)
	updateBuffs(widget.buffs, unit)
end

local function test(frame)
	local widget = frame.raidauras
	if config.ccIcon and random(4) == 1 then
		local duration = random(4, 10)
		setCC(widget.cc, ns.SpellTexture(TEST_CC[random(#TEST_CC)]), GetTime() - random(0, 2), duration)
	else
		setCC(widget.cc, nil)
	end
	widget.cc.index = nil
	setDispel(widget.dispel, config.dispel and random(4) == 1 and TEST_DEBUFF_TYPES[random(#TEST_DEBUFF_TYPES)] or nil)
	local buffs = widget.buffs
	local shown = min(config.buffMax, #buffs, random(0, 3))
	local now = GetTime()
	for i = 1, shown do
		local duration = random(6, 20)
		setBuff(
			buffs[i],
			ns.SpellTexture(HOT_SPELLS[random(#HOT_SPELLS)]),
			random(3) == 1 and 3 or 1,
			duration,
			now + duration
		)
		buffs[i].index = nil
	end
	hideBuffs(buffs, shown + 1)
end

local function createBuff(parent)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetFrameLevel(parent:GetFrameLevel() + 3)
	icon:Hide()
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local cooldown = CreateFrame("Cooldown", nil, icon)
	cooldown:SetAllPoints()
	cooldown:SetReverse(true)
	icon.cooldown = cooldown
	icon.count = cooldown:CreateFontString(nil, "OVERLAY")
	icon.count:SetPoint("BOTTOMRIGHT", 1, 0)
	icon.filter = "HELPFUL|PLAYER"
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)
	return icon
end

local function create(frame, maxBuffs)
	local widget = {}
	local health = frame.health

	local cc = CreateFrame("Cooldown", nil, frame)
	cc:SetReverse(true)
	cc:SetPoint("CENTER", health)
	cc:SetFrameLevel(frame:GetFrameLevel() + 4)
	cc:Hide()
	CooldownTimer:Attach(cc, CC_TIMER_FONT_SIZE)
	cc.texture = cc:CreateTexture(nil, "BORDER")
	UF.SkinIcon(cc, cc.texture)
	cc.filter = "HARMFUL"
	cc:SetScript("OnEnter", onIconEnter)
	cc:SetScript("OnLeave", onIconLeave)
	widget.cc = cc

	local border = CreateFrame("Frame", nil, frame)
	border:SetAllPoints()
	border:SetFrameLevel(frame:GetFrameLevel() + 5)
	border:SetBackdrop({ edgeFile = ns.Media.border, edgeSize = BORDER_EDGE })
	border:Hide()
	local overlay = health:CreateTexture(nil, "OVERLAY", nil, -1)
	overlay:SetAllPoints()
	overlay:SetTexture(ns.Media.blank)
	overlay:Hide()
	widget.dispel = { border = border, overlay = overlay }

	local buffs = {}
	for i = 1, maxBuffs do
		buffs[i] = createBuff(frame)
	end
	widget.buffs = buffs

	frame:RegisterUnitEvent("UNIT_AURA", update)
	return widget
end

function UF.LayoutRaidAuras(frame)
	local widget = frame.raidauras
	local size = config.ccIconSize
	local mouse = not config.auraClickThrough
	widget.cc:SetSize(size, size)
	widget.cc:EnableMouse(mouse)
	widget.dispel.debuffType = false
	local health = frame.health
	local buffSize = config.buffSize
	local buffs = widget.buffs
	for i = 1, #buffs do
		local icon = buffs[i]
		icon:SetSize(buffSize, buffSize)
		icon:EnableMouse(mouse)
		icon:ClearAllPoints()
		icon:SetPoint("BOTTOMRIGHT", health, -BUFF_INSET - (i - 1) * (buffSize + BUFF_GAP), BUFF_INSET)
		ns.SetFont(icon.count, buffSize * COUNT_FONT_SCALE, "OUTLINE")
	end
end

UF:RegisterElement("raidauras", create, update, test)

local UnitIsPartyLeader, UnitIsRaidOfficer = UnitIsPartyLeader, UnitIsRaidOfficer
local GetNumRaidMembers = GetNumRaidMembers

local LEADER_TEXTURE = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local ASSIST_TEXTURE = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local LEADER_SIZE = 12

local function setLeader(icon, texture)
	if texture and config.leaderIcon then
		icon:SetTexture(texture)
		icon:Show()
	else
		icon:Hide()
	end
end

local function updateLeader(frame)
	local unit = frame.unit
	local texture
	if UnitIsPartyLeader(unit) then
		texture = LEADER_TEXTURE
	elseif GetNumRaidMembers() > 0 and UnitIsRaidOfficer(unit) then
		texture = ASSIST_TEXTURE
	end
	setLeader(frame.raidleader, texture)
end

local function testLeader(frame)
	local roll = random(8)
	setLeader(frame.raidleader, roll == 1 and LEADER_TEXTURE or roll == 2 and ASSIST_TEXTURE or nil)
end

local function createLeader(frame)
	local icon = frame.health:CreateTexture(nil, "OVERLAY")
	icon:SetSize(LEADER_SIZE, LEADER_SIZE)
	icon:SetPoint("TOPLEFT", frame.health, -2, 3)
	icon:Hide()
	frame:RegisterEvent("PARTY_LEADER_CHANGED", updateLeader)
	frame:RegisterEvent("RAID_ROSTER_UPDATE", updateLeader)
	return icon
end

UF:RegisterElement("raidleader", createLeader, updateLeader, testLeader)
