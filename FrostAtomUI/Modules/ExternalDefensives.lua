local _, ns = ...

local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local huge, random = math.huge, math.random

local Auras = ns.Auras
local Scheduler = ns.Scheduler
local ExternalDefensives = ns:NewModule("ExternalDefensives")
local CooldownTimer = ns:GetModule("CooldownTimer")
local UF = ns:GetModule("UnitFrames")

local MAX_ICONS = 6
local TEST_INTERVAL = 1
local TIMER_FONT_RATIO = 0.4

local SPELLS = {
	[33206] = true, -- Pain Suppression
	[47788] = true, -- Guardian Spirit
	[6940] = true, -- Hand of Sacrifice
	[64205] = true, -- Divine Sacrifice
	[1022] = true, -- Hand of Protection
	[5599] = true, -- Hand of Protection
	[10278] = true, -- Hand of Protection
	[1044] = true, -- Hand of Freedom
	[1038] = true, -- Hand of Salvation
	[70940] = true, -- Divine Guardian
	[19752] = true, -- Divine Intervention
	[31821] = true, -- Aura Mastery
	[50720] = true, -- Vigilance
	[3411] = true, -- Intervene
	[46946] = true, -- Safeguard
	[46947] = true, -- Safeguard
	[29166] = true, -- Innervate
	[10060] = true, -- Power Infusion
	[50461] = true, -- Anti-Magic Zone
	[8178] = true, -- Grounding Totem Effect
	[62305] = true, -- Master's Call
}

local TEST_SPELLS = {
	33206, -- Pain Suppression
	1044, -- Hand of Freedom
	10060, -- Power Infusion
	29166, -- Innervate
	6940, -- Hand of Sacrifice
}

local holder
local icons = {}
local list, listCount = {}, 0
local testAuras = {}
local testing
local layoutCount, layoutSize, layoutGap

local function sortKey(aura)
	local expires = aura.expires
	return expires == 0 and huge or expires
end

local function sortLongestFirst(count)
	for i = 2, count do
		local aura = list[i]
		local key = sortKey(aura)
		local j = i - 1
		while j >= 1 and sortKey(list[j]) < key do
			list[j + 1] = list[j]
			j = j - 1
		end
		list[j + 1] = aura
	end
end

local function collectShown()
	local count = 0
	if testing then
		for i = 1, #testAuras do
			count = count + 1
			list[count] = testAuras[i]
		end
	else
		local auras, n = Auras.Get("player", "HELPFUL")
		for i = 1, n do
			local aura = auras[i]
			if SPELLS[aura.spellId] and aura.caster ~= "player" then
				count = count + 1
				list[count] = aura
			end
		end
	end

	sortLongestFirst(count)

	for i = count + 1, listCount do
		list[i] = nil
	end
	listCount = count
	local limit = ns.Config.externalDefensives.maxIcons
	return count > limit and limit or count
end

local function layout(shown)
	local config = ns.Config.externalDefensives
	local size, gap = config.size, config.gap
	if shown == layoutCount and size == layoutSize and gap == layoutGap then
		return
	end
	layoutCount, layoutSize, layoutGap = shown, size, gap
	local left = -(shown * (size + gap) - gap) / 2
	for i = 1, shown do
		local icon = icons[i]
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", holder, "CENTER", left + (i - 1) * (size + gap), 0)
	end
end

local function update()
	local shown = 0
	if ns.Config.externalDefensives.enabled then
		shown = collectShown()
	end

	layout(shown)
	for i = 1, shown do
		local icon, aura = icons[i], list[i]
		icon.texture:SetTexture(aura.icon)
		local duration = aura.duration
		if duration > 0 then
			local start = aura.expires - duration
			if start ~= icon.start or duration ~= icon.duration then
				icon.start, icon.duration = start, duration
				icon.cooldown:SetCooldown(start, duration)
			end
			icon.cooldown:Show()
		else
			icon.start = nil
			icon.cooldown:Hide()
		end
		icon:Show()
	end
	for i = shown + 1, MAX_ICONS do
		icons[i].start = nil
		icons[i]:Hide()
	end
end

local function createIcon()
	local icon = CreateFrame("Frame", nil, holder)
	icon:Hide()

	icon.texture = icon:CreateTexture(nil, "BORDER")
	UF.SkinIcon(icon, icon.texture)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetReverse(true)
	icon.cooldown:SetAllPoints()
	CooldownTimer:Attach(icon.cooldown)

	return icon
end

local function refreshTest(_, now)
	local changed
	for i = 1, #testAuras do
		local aura = testAuras[i]
		if aura.expires <= now then
			local duration = random(6, 20)
			aura.duration, aura.expires = duration, now + duration
			changed = true
		end
	end
	if changed then
		update()
	end
end

function ExternalDefensives:SetTestMode(enabled)
	enabled = enabled and true or nil
	if enabled == testing then
		return
	end
	testing = enabled
	if enabled then
		wipe(testAuras)
		local count = random(2, #TEST_SPELLS)
		for i = 1, count do
			local _, _, texture = GetSpellInfo(TEST_SPELLS[i])
			testAuras[i] = { icon = texture, duration = 0, expires = 0 }
		end
		Scheduler.AddTicker(testAuras, refreshTest, TEST_INTERVAL)
		refreshTest(nil, GetTime())
	else
		Scheduler.RemoveTicker(testAuras)
	end
	if holder then
		update()
	end
end

function ExternalDefensives:IsTesting()
	return testing or false
end

local function applyConfig()
	local config = ns.Config.externalDefensives
	local size, gap = config.size, config.gap
	holder:SetSize(config.maxIcons * (size + gap) - gap, size)
	for i = 1, MAX_ICONS do
		local icon = icons[i]
		icon:SetSize(size, size)
		ns.SetFont(icon.cooldown.timer, size * TIMER_FONT_RATIO, "OUTLINE")
	end
	if config.enabled then
		ExternalDefensives:RegisterUnitEvent("UNIT_AURA", "player", update)
		ExternalDefensives:RegisterEvent("PLAYER_ENTERING_WORLD", update)
	else
		ExternalDefensives:UnregisterUnitEvent("UNIT_AURA", "player", update)
		ExternalDefensives:UnregisterEvent("PLAYER_ENTERING_WORLD", update)
	end
	layoutCount = nil
	update()
end

function ExternalDefensives:Initialize()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetFrameStrata("HIGH")
	self:AnchorToConfig(holder, "externalDefensives.point", "External defensives")
	for i = 1, MAX_ICONS do
		icons[i] = createIcon()
	end

	applyConfig()
	self:WatchConfig("externalDefensives", applyConfig)
	hooksecurefunc(UF, "SetTestMode", function()
		ExternalDefensives:SetTestMode(UF.testing)
	end)
end
