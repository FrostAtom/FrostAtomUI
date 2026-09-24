local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CancelUnitBuff = CancelUnitBuff
local CancelItemTempEnchantment = CancelItemTempEnchantment
local InCombatLockdown = InCombatLockdown
local GameTooltip = GameTooltip
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local UIParent = UIParent
local min, max, floor, ceil, huge, random = math.min, math.max, math.floor, math.ceil, math.huge, math.random
local sort = table.sort

local Auras = ns.Auras
local CooldownTimer = ns:GetModule("CooldownTimer")
local config = ns.Config.unitFrames

local MAX_AURAS = 40
local COUNT_FONT_SCALE = 0.45
local TIMER_FONT_SCALE = 0.42
local SPARE_CANCEL_SLOTS = 4
local CATCHER_LEVEL = 3
local ENCHANT_BUTTON_LEVEL = CATCHER_LEVEL + 1
local NO_AURA_INDEX = MAX_AURAS + 1
local OWN_CASTERS = { player = true, pet = true, vehicle = true }

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

local containers = {}
local cancelContainers = {}
local hoveredIcon

local function timerLimit()
	if not config.auraTimers then
		return 0
	end
	local limit = config.auraTimerMaxDuration
	return limit and limit > 0 and limit or nil
end

local timerMaxDuration = timerLimit()

local function ownScale(container)
	local scale = container.enlargeOwn and config.ownAuraScale
	return scale and scale > 1 and scale or nil
end

local function rowSize(container)
	local scale = ownScale(container)
	return scale and floor(container.size * scale + 0.5) or container.size
end

local function refreshTooltip(icon)
	if icon.enchantSlot then
		GameTooltip:SetInventoryItem("player", icon.enchantSlot)
	else
		GameTooltip:SetUnitAura(icon.unit, icon.index, icon.filter)
	end
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
	if UF.testing then
		return
	end
	if InCombatLockdown() then
		UIErrorsFrame:AddMessage(_G.ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
		return
	end
	CancelUnitBuff("player", icon.index, icon.filter)
end

local function refreshEnchantTooltip(button)
	refreshTooltip(button:GetParent())
end

local function onEnchantEnter(button)
	onIconEnter(button:GetParent())
	button:SetScript("OnUpdate", refreshEnchantTooltip)
end

local function onEnchantLeave(button)
	button:SetScript("OnUpdate", nil)
	onIconLeave(button:GetParent())
end

local function onEnchantClick(button)
	if not UF.testing then
		CancelItemTempEnchantment(button:GetParent().weaponIndex)
	end
end

local function setEnchant(icon, enchant)
	local button = icon.enchantButton
	if not enchant then
		icon.enchantSlot = nil
		if button then
			button:Hide()
		end
		return
	end
	if not button then
		button = CreateFrame("Button", nil, icon)
		button:SetAllPoints()
		button:RegisterForClicks("RightButtonUp")
		button:SetScript("OnClick", onEnchantClick)
		button:SetScript("OnEnter", onEnchantEnter)
		button:SetScript("OnLeave", onEnchantLeave)
		icon.enchantButton = button
	end
	button:SetFrameLevel(icon:GetParent():GetFrameLevel() + ENCHANT_BUTTON_LEVEL)
	icon.enchantSlot = enchant.slot
	icon.weaponIndex = enchant.weaponIndex
	button:Show()
end

local function onIconResize(icon, size)
	icon.size = size
	ns.SetFont(icon.count, size * COUNT_FONT_SCALE, "OUTLINE")
	ns.SetFont(icon.cooldown.timer, size * TIMER_FONT_SCALE, "OUTLINE")
end

local function setIconSize(icon, size)
	if icon.size ~= size then
		icon:SetSize(size, size)
		onIconResize(icon, size)
	end
end

local function createOverlay(icon)
	local overlay = icon:CreateTexture(nil, "OVERLAY")
	overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
	overlay:SetAllPoints()
	overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
	icon.overlay = overlay
	return overlay
end

local function createIcon(container, index)
	local icon = CreateFrame("Button", nil, container)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:SetSize(container.size, container.size)
	icon:SetPoint(UF.GridIconPoint(container, index))
	icon.unit = container.unit
	icon.filter = container.filter
	icon.index = index
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	local cooldown = CreateFrame("Cooldown", nil, icon)
	cooldown:SetAllPoints()
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(true)
	cooldown:SetFrameLevel(icon:GetFrameLevel())
	icon.cooldown = cooldown

	local text = CreateFrame("Frame", nil, icon)
	text:SetAllPoints()
	text:SetFrameLevel(icon:GetFrameLevel() + 1)
	CooldownTimer:Attach(cooldown, container.size * TIMER_FONT_SCALE, text)
	cooldown.timerMinDuration = 0
	cooldown.timerMaxDuration = timerMaxDuration

	icon.texture = icon:CreateTexture(nil, "BACKGROUND")
	icon.texture:SetNonBlocking(true)
	UF.SkinIcon(icon, icon.texture)

	icon.count = text:CreateFontString(nil, "OVERLAY")
	icon.count:SetPoint("BOTTOMRIGHT", icon, -1, 0)
	icon.OnResize = onIconResize
	onIconResize(icon, container.size)

	if container.cancellable then
		icon:RegisterForClicks("RightButtonUp")
		icon:SetScript("OnClick", onIconClick)
	else
		icon:RegisterForClicks()
	end

	if container.isDebuff or canPurge then
		createOverlay(icon)
		icon.isDebuff = container.isDebuff
	end

	return icon
end

local function acquireIcon(container, index)
	local icon = container[index]
	if not icon then
		icon = createIcon(container, index)
		container[index] = icon
	end
	return icon
end

local function clearCooldown(icon)
	icon.start = nil
	local cooldown = icon.cooldown
	cooldown:SetCooldown(0, 0)
	cooldown:Hide()
end

local function clearHidden(container, shown)
	for i = shown + 1, #container do
		local icon = container[i]
		if icon.start then
			clearCooldown(icon)
		end
	end
end

local function setIcon(icon, texture, count, debuffType, duration, endTime, stealable)
	icon.texture:SetTexture(texture)

	local overlay = icon.overlay
	if overlay then
		if icon.isDebuff then
			local color = debuffType and debuffColors[debuffType] or NO_TYPE_COLOR
			overlay:SetVertexColor(color[1], color[2], color[3])
		elseif stealable and canPurge then
			overlay:SetVertexColor(STEALABLE_COLOR[1], STEALABLE_COLOR[2], STEALABLE_COLOR[3])
			overlay:Show()
		else
			overlay:Hide()
		end
	end

	local cooldown = icon.cooldown
	if duration and duration > 0 then
		local start = endTime - duration
		if start ~= icon.start or duration ~= icon.duration then
			icon.start, icon.duration = start, duration
			cooldown:SetCooldown(start, duration)
		end
	elseif icon.start then
		clearCooldown(icon)
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

local function flowLayout(container, shown, scale)
	container.flowed = true
	local size, gap, anchor = container.size, container.gap, container.anchor
	local bigSize = floor(size * scale + 0.5)
	local width = container.perRow * (size + gap) - gap + 0.5
	local maxRows = max(ceil(container.limit / container.perRow), 1)
	local xSign = anchor:find("RIGHT") and -1 or 1
	local ySign = anchor:find("BOTTOM") and 1 or -1

	local x, y, rowHeight, rows, placed = 0, 0, 0, 0, 0
	for i = 1, shown do
		local icon = container[i]
		local iconSize = icon.big and bigSize or size
		if rows == 0 then
			rows = 1
		elseif x + iconSize > width then
			if rows == maxRows then
				break
			end
			rows = rows + 1
			y = y + rowHeight + gap
			x, rowHeight = 0, 0
		end
		setIconSize(icon, iconSize)
		icon:SetPoint(anchor, xSign * x, ySign * y)
		x = x + iconSize + gap
		rowHeight = max(rowHeight, iconSize)
		placed = i
	end

	for i = placed + 1, #container do
		container[i]:Hide()
	end

	local height = rows > 0 and y + rowHeight or 0
	if rows < container.minRows then
		height = max(height, container.minRows * (size + gap) - gap)
	end
	container:SetHeight(max(height, 1))
	if container.rows ~= rows or container.flowHeight ~= height then
		container.rows, container.flowHeight = rows, height
		if container.OnRowsChanged then
			container:OnRowsChanged(rows)
		end
	end
end

local function resetGrid(container)
	container.flowed = nil
	container.flowHeight = nil
	local size = container.size
	container.size = nil
	container:SetIconSize(size)
	container.rows = -1
end

local function onCatcherEnter(catcher)
	local icon = catcher.container[catcher:GetID()]
	if icon and icon:IsShown() then
		onIconEnter(icon)
	end
end

local function onCatcherLeave()
	hoveredIcon = nil
	GameTooltip:Hide()
end

local function createCatcher(container, index)
	local catcher = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	catcher:SetID(index)
	catcher:RegisterForClicks("RightButtonUp")
	catcher:SetAttribute("unit", "player")
	catcher:SetAttribute("*type2", "cancelaura")
	catcher:SetScript("OnEnter", onCatcherEnter)
	catcher:SetScript("OnLeave", onCatcherLeave)
	catcher.container = container
	container.catchers[index] = catcher
	return catcher
end

local function setCatcherAura(catcher, index, spell)
	if catcher.auraIndex ~= index then
		catcher.auraIndex = index
		catcher:SetAttribute("index", index)
	end
	if catcher.auraSpell ~= spell then
		catcher.auraSpell = spell
		catcher:SetAttribute("spell", spell)
	end
end

local sorters = {}

local function syncCatchers(container)
	if InCombatLockdown() then
		container.catchersPending = true
		return
	end
	container.catchersPending = nil

	local catchers = container.catchers
	local byName = sorters[config.playerBuffSort] ~= nil
	local lead = container.enchantLead or 0
	local active = 0
	if not UF.testing and container:IsVisible() and container:GetLeft() then
		active = min(container.limit, container.shown + (byName and 0 or SPARE_CANCEL_SLOTS))
	end

	if active > 0 then
		local anchor = container.anchor
		local scale = container:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local originX = anchor:find("RIGHT") and container:GetRight() or container:GetLeft()
		local originY = anchor:find("BOTTOM") and container:GetBottom() or container:GetTop()
		local size = container.size * scale
		local strata, level = container:GetFrameStrata(), container:GetFrameLevel() + CATCHER_LEVEL
		for i = 1, active do
			local catcher = catchers[i] or createCatcher(container, i)
			local point, x, y = UF.GridIconPoint(container, i)
			if catcher.point ~= point then
				catcher.point = point
				catcher:ClearAllPoints()
			end
			catcher:SetPoint(point, UIParent, "BOTTOMLEFT", (originX + x) * scale, (originY + y) * scale)
			if catcher.size ~= size then
				catcher.size = size
				catcher:SetSize(size, size)
			end
			if catcher.strata ~= strata or catcher.level ~= level then
				catcher.strata, catcher.level = strata, level
				catcher:SetFrameStrata(strata)
				catcher:SetFrameLevel(level)
			end
			if byName then
				local spell = container[i].spellName
				if spell then
					setCatcherAura(catcher, nil, spell)
				else
					setCatcherAura(catcher, NO_AURA_INDEX, nil)
				end
			elseif i > lead then
				setCatcherAura(catcher, i - lead, nil)
			else
				setCatcherAura(catcher, NO_AURA_INDEX, nil)
			end
			catcher:Show()
		end
	end

	for i = active + 1, #catchers do
		catchers[i]:Hide()
	end
end

local function queueCatchers(container)
	if InCombatLockdown() then
		container.catchersPending = true
	else
		ns.Defer(container, syncCatchers)
	end
end

local function layoutContainer(container, shown)
	container.shown = shown
	local scale = ownScale(container)
	if scale then
		flowLayout(container, shown, scale)
	else
		if container.flowed then
			resetGrid(container)
		end
		container:Layout(shown)
	end
	clearHidden(container, shown)
	if container.cancellable then
		queueCatchers(container)
	end
end

local sortSet

function sorters.own(a, b)
	local ownA, ownB = OWN_CASTERS[sortSet[a].caster] or false, OWN_CASTERS[sortSet[b].caster] or false
	if ownA ~= ownB then
		return ownA
	end
	return a < b
end

local function expiresOf(aura)
	local duration = aura.duration
	return duration and duration > 0 and aura.expires or huge
end

function sorters.time(a, b)
	local expiresA, expiresB = expiresOf(sortSet[a]), expiresOf(sortSet[b])
	if expiresA ~= expiresB then
		return expiresA < expiresB
	end
	return a < b
end

local function sortedOrder(container, auras, count)
	local sorter = container.sortable and sorters[config.playerBuffSort]
	if not sorter then
		return nil
	end
	local order = container.order
	for i = 1, count do
		order[i] = i
	end
	for i = count + 1, container.orderCount do
		order[i] = nil
	end
	container.orderCount = count
	sortSet = auras
	sort(order, sorter)
	sortSet = nil
	return order
end

local enchantContainer
local weaponEnchants, weaponEnchantCount = nil, 0

local function enchantLead(container, enchantCount)
	if not InCombatLockdown() or not container.enchantLead then
		container.enchantLead = enchantCount
	end
	return container.enchantLead
end

local function showEnchant(icon, enchant)
	icon.index = nil
	icon.spellName = nil
	icon.big = false
	setEnchant(icon, enchant)
	if enchant then
		setIcon(icon, enchant.icon, nil, nil, enchant.duration, enchant.expires)
		local color = enchant.quality and ITEM_QUALITY_COLORS[enchant.quality]
		if color then
			local overlay = icon.overlay or createOverlay(icon)
			overlay:SetVertexColor(color.r, color.g, color.b)
			overlay:Show()
		end
	else
		if icon.start then
			clearCooldown(icon)
		end
		if icon == hoveredIcon then
			onIconLeave(icon)
		end
		icon:Hide()
	end
end

local function updateContainer(container)
	local auras, count = Auras.Get(container.unit, container.filter)
	local enchants, enchantCount, lead = nil, 0, 0
	if container == enchantContainer then
		if weaponEnchants then
			enchants, enchantCount = weaponEnchants, weaponEnchantCount
		end
		lead = enchantLead(container, enchantCount)
	end
	local order = sortedOrder(container, auras, count)
	local enlarge = ownScale(container) ~= nil
	local limit = container.limit

	local shown = min(lead, limit)
	for i = 1, shown do
		showEnchant(acquireIcon(container, i), i <= enchantCount and enchants[i] or nil)
	end

	for i = 1, min(count, limit - shown) do
		local index = order and order[i] or i
		local aura = auras[index]
		local icon = acquireIcon(container, shown + i)
		icon.index = index
		icon.spellName = aura.name
		icon.big = enlarge and OWN_CASTERS[aura.caster] or false
		setEnchant(icon, nil)
		setIcon(icon, aura.icon, aura.count, aura.debuffType, aura.duration, aura.expires, aura.stealable)
	end
	shown = min(shown + count, limit)

	for i = lead + 1, enchantCount do
		if shown == limit then
			break
		end
		shown = shown + 1
		showEnchant(acquireIcon(container, shown), enchants[i])
	end

	layoutContainer(container, shown)
end

function UF.HasWeaponEnchantAuras()
	return enchantContainer ~= nil
end

function UF.SetWeaponEnchants(enchants, count)
	if weaponEnchants == enchants and count == 0 and weaponEnchantCount == 0 then
		return
	end
	weaponEnchants, weaponEnchantCount = enchants, count
	if enchantContainer and not UF.testing and enchantContainer:IsVisible() then
		updateContainer(enchantContainer)
	end
end

local function testContainer(container, spells)
	local now = GetTime()
	local most = min(container.limit, container.perRow * 2)
	local shown = random(container.unit == "player" and min(container.perRow, most) or 0, most)
	local enlarge = ownScale(container) ~= nil
	for i = 1, shown do
		local icon = acquireIcon(container, i)
		icon.index = i
		icon.spellName = nil
		icon.big = enlarge and random(3) == 1
		setEnchant(icon, nil)
		local _, _, texture = GetSpellInfo(spells[random(#spells)])
		local duration = random(3) == 1 and 0 or random(8, 60)
		local count = random(3) == 1 and random(2, 5) or 1
		local debuffType = TEST_DEBUFF_TYPES[random(#TEST_DEBUFF_TYPES)] or nil
		setIcon(icon, texture, count, debuffType, duration, now + duration, random(4) == 1)
	end
	layoutContainer(container, shown)
end

local function setLimit(container, limit)
	container.limit = min(limit or MAX_AURAS, MAX_AURAS)
	if container.cancellable then
		queueCatchers(container)
	end
end

local function createContainer(frame, options, filter, isDebuff)
	local container = UF:CreateIconGrid(frame, options)
	local unit = frame.unit
	container.unit = unit
	container.filter = filter
	container.isDebuff = isDebuff
	container.enlargeOwn = unit == "target" or unit == "focus"
	container.shown = 0
	container.SetLimit = setLimit
	container.RowSize = rowSize
	if unit == "player" and not isDebuff then
		container.sortable = true
		container.order = {}
		container.orderCount = 0
		container.cancellable = true
		container.catchers = {}
		cancelContainers[#cancelContainers + 1] = container
		enchantContainer = container
	end
	containers[#containers + 1] = container
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

local function queueAllCatchers()
	for i = 1, #cancelContainers do
		queueCatchers(cancelContainers[i])
	end
end

UF:WatchConfig("unitFrames", function()
	timerMaxDuration = timerLimit()
	for i = 1, #containers do
		local container = containers[i]
		for j = 1, #container do
			local icon = container[j]
			icon.cooldown.timerMaxDuration = timerMaxDuration
			icon.start = nil
		end
		if not UF.testing and container:IsVisible() then
			updateContainer(container)
		end
	end
	queueAllCatchers()
end)

UF:WatchConfig("general", queueAllCatchers)

local combatEvents = ns.Mixin({}, ns.EventMixin)

combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	local container = enchantContainer
	if container and container.enchantLead ~= weaponEnchantCount and not UF.testing and container:IsVisible() then
		updateContainer(container)
	end
	for i = 1, #cancelContainers do
		local container = cancelContainers[i]
		if container.catchersPending then
			syncCatchers(container)
		end
	end
end)

combatEvents:RegisterEvent("UI_SCALE_CHANGED", queueAllCatchers)
