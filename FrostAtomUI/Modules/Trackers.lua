local _, ns = ...

local GetTime = GetTime
local GetSpellInfo, GetSpellTexture, GetSpellCooldown = GetSpellInfo, GetSpellTexture, GetSpellCooldown
local IsUsableSpell, IsSpellInRange = IsUsableSpell, IsSpellInRange
local GetItemInfo, GetItemIcon, GetItemCount, GetItemCooldown = GetItemInfo, GetItemIcon, GetItemCount, GetItemCooldown
local GetInventoryItemTexture, GetInventoryItemCooldown = GetInventoryItemTexture, GetInventoryItemCooldown
local GetTotemInfo = GetTotemInfo
local UnitExists, UnitGUID, UnitAffectingCombat = UnitExists, UnitGUID, UnitAffectingCombat
local IsInInstance, GetActiveTalentGroup = IsInInstance, GetActiveTalentGroup
local pairs, ipairs, wipe, tonumber, type = pairs, ipairs, wipe, tonumber, type
local floor, max, min = math.floor, math.max, math.min
local strtrim = strtrim

local Auras = ns.Auras
local DRData = ns.DRData
local PROC_DATA = ns.ProcData
local CooldownTimer = ns:GetModule("CooldownTimer")
local DR = ns:GetModule("DiminishingReturns")
local CooldownTracker = ns:GetModule("CooldownTracker")

local Trackers = ns:NewModule("Trackers")
ns.Trackers = Trackers

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local GCD_DURATION = 1.5
local RUNE_COOLDOWN = 10
local TICK_INTERVAL = 0.1
local FONT_SCALE = 0.36
local COUNT_SCALE = 0.34
local MAX_INVENTORY_SLOT = 19
local OUT_OF_RANGE_COLOR = { 0.9, 0.2, 0.2 }
local NO_MANA_COLOR = { 0.35, 0.45, 1 }
local DR_TEXT = { "½", "¼", "×" }
local DR_COLOR_KEYS = { "halfColor", "quarterColor", "immuneColor" }
local DEFAULT_ICD = 45

local icdBySpell, icdByName = {}, {}
for id, proc in pairs(PROC_DATA) do
	local cooldown = proc.cd or 0
	if proc.items then
		for _, itemCooldown in pairs(proc.items) do
			cooldown = max(cooldown, itemCooldown)
		end
	end
	local name = cooldown > 0 and GetSpellInfo(id)
	if name then
		icdBySpell[id] = cooldown
		name = name:lower()
		icdByName[name] = max(icdByName[name] or 0, cooldown)
	end
end

Trackers.TYPES = { "aura", "cooldown", "item", "totem", "icd", "unitcd", "dr" }
Trackers.UNITS = {
	"player",
	"target",
	"focus",
	"pet",
	"arena1",
	"arena2",
	"arena3",
	"arena4",
	"arena5",
	"party1",
	"party2",
	"party3",
	"party4",
}

Trackers.SHOW = {
	aura = { "present", "absent", "always" },
	cooldown = { "ready", "cooldown", "usable", "always" },
	item = { "ready", "cooldown", "always" },
	totem = { "present", "absent", "always" },
	icd = { "ready", "cooldown", "always" },
	unitcd = { "ready", "cooldown", "always" },
	dr = { "present", "absent", "always" },
}

local ICON_DEFAULTS = {
	type = "aura",
	spells = "",
	unit = "player",
	debuff = false,
	mine = false,
	show = "present",
	minStacks = 0,
	range = false,
	usable = true,
	duration = 0,
	category = "stun",
}

local GROUP_DEFAULTS = {
	enabled = true,
	name = "Group",
	class = "",
	point = { "CENTER", 0, -120 },
	size = 36,
	spacing = 2,
	columns = 8,
	collapse = false,
	combat = "any",
	zone = "any",
	talentGroup = 0,
	inactiveAlpha = 0.35,
	timer = true,
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

function Trackers.NewIcon(kind)
	local icon = copy(ICON_DEFAULTS)
	icon.type = kind or icon.type
	icon.show = Trackers.SHOW[icon.type][1]
	return icon
end

function Trackers.NewGroup(name)
	local group = copy(GROUP_DEFAULTS)
	group.name = name or group.name
	group.class = ns.PLAYER_CLASS
	group.icons = {}
	return group
end

local function field(data, key, defaults)
	local value = data[key]
	if value == nil then
		return defaults[key]
	end
	return value
end

local EQUIVALENCIES = {
	slowed = {
		-116, -- Frostbolt
		-120, -- Cone of Cold
		-1715, -- Hamstring
		-2974, -- Wing Clip
		3409, -- Crippling Poison
		-3600, -- Earthbind
		-5116, -- Concussive Shot
		-6136, -- Chilled
		-8056, -- Frost Shock
		-12323, -- Piercing Howl
		-15407, -- Mind Flay
		-18223, -- Curse of Exhaustion
		-31589, -- Slow
		-44614, -- Frostfire Bolt
		-45524, -- Chains of Ice
		-58180, -- Infected Wounds
	},
	healingreduced = {
		-12294, -- Mortal Strike
		-13219, -- Wound Poison
		-19434, -- Aimed Shot
		-46910, -- Furious Attacks
	},
	immune = {
		-642, -- Divine Shield
		-45438, -- Ice Block
		-1022, -- Hand of Protection
		-19263, -- Deterrence
	},
	immunemagic = {
		-31224, -- Cloak of Shadows
		-48707, -- Anti-Magic Shell
		-23920, -- Spell Reflection
		8178, -- Grounding Totem Effect
		-46924, -- Bladestorm
		-49039, -- Lichborne
	},
	defensive = {
		-33206, -- Pain Suppression
		-47788, -- Guardian Spirit
		-871, -- Shield Wall
		-5277, -- Evasion
		-22812, -- Barkskin
		-61336, -- Survival Instincts
		-48792, -- Icebound Fortitude
		-498, -- Divine Protection
		-6940, -- Hand of Sacrifice
		-64205, -- Divine Sacrifice
		-47585, -- Dispersion
	},
	burst = {
		-2825, -- Bloodlust
		-32182, -- Heroism
		-12042, -- Arcane Power
		-12472, -- Icy Veins
		-28682, -- Combustion
		-31884, -- Avenging Wrath
		-50334, -- Berserk
		-19574, -- Bestial Wrath
		-1719, -- Recklessness
		-12292, -- Death Wish
		-51713, -- Shadow Dance
		-13750, -- Adrenaline Rush
		-47241, -- Metamorphosis
		-10060, -- Power Infusion
		-49016, -- Hysteria
	},
}

local parsedCache = {}

local function addSpellName(list, id)
	local name = GetSpellInfo(id)
	if name then
		list.names[name:lower()] = true
	end
	list.first = list.first or { id = id, name = name }
end

local function addSpellId(list, id)
	list.ids[id] = true
	addSpellName(list, id)
end

local function parseList(text)
	text = text or ""
	local cached = parsedCache[text]
	if cached then
		return cached
	end
	local list = { ids = {}, names = {}, entries = {} }
	for token in text:gmatch("[^;,\n]+") do
		token = strtrim(token)
		if token ~= "" then
			local category = token:match("^#(%w+)$")
			local id = tonumber(token)
			if category then
				category = category:lower()
				local equivalency = EQUIVALENCIES[category]
				if equivalency then
					for _, spellId in ipairs(equivalency) do
						if spellId < 0 then
							addSpellName(list, -spellId)
						else
							addSpellId(list, spellId)
						end
					end
				end
				for spellId, spellCategory in pairs(DRData.SPELLS) do
					if spellCategory == category then
						addSpellId(list, spellId)
					end
				end
			elseif id then
				addSpellId(list, id)
				list.entries[#list.entries + 1] = { id = id, name = GetSpellInfo(id) }
			else
				list.names[token:lower()] = true
				list.entries[#list.entries + 1] = { name = token }
				list.first = list.first or { name = token }
			end
		end
	end
	parsedCache[text] = list
	return list
end
Trackers.ParseList = parseList

local function spellTexture(entry)
	if not entry then
		return QUESTION_MARK
	end
	if entry.id then
		local _, _, texture = GetSpellInfo(entry.id)
		return texture or QUESTION_MARK
	end
	return GetSpellTexture(entry.name) or QUESTION_MARK
end

local function itemTexture(entry)
	if not entry then
		return QUESTION_MARK
	end
	if entry.slot then
		return GetInventoryItemTexture("player", entry.slot) or QUESTION_MARK
	end
	if entry.id then
		return GetItemIcon(entry.id) or QUESTION_MARK
	end
	local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entry.name)
	return texture or QUESTION_MARK
end

local function itemEntries(text)
	local list = parseList(text)
	if not list.items then
		local items = {}
		for _, entry in ipairs(list.entries) do
			if entry.id and entry.id <= MAX_INVENTORY_SLOT then
				items[#items + 1] = { slot = entry.id }
			else
				items[#items + 1] = { id = entry.id, name = entry.id and nil or entry.name }
			end
		end
		list.items = items
	end
	return list.items
end

local evaluators = {}

function evaluators.aura(icon, data)
	local list = parseList(data.spells)
	local unit = field(data, "unit", ICON_DEFAULTS)
	local texture = spellTexture(list.first)
	if not UnitExists(unit) then
		return false, texture
	end
	local filter = field(data, "debuff", ICON_DEFAULTS) and "HARMFUL" or "HELPFUL"
	local mine = field(data, "mine", ICON_DEFAULTS)
	local minStacks = field(data, "minStacks", ICON_DEFAULTS)
	local set, n = Auras.Get(unit, filter)
	for i = 1, n do
		local aura = set[i]
		if
			(list.ids[aura.spellId] or list.names[aura.name:lower()])
			and (not mine or aura.caster == "player" or aura.caster == "pet" or aura.caster == "vehicle")
			and aura.count >= minStacks
		then
			local duration = aura.duration or 0
			return true, aura.icon, duration > 0 and aura.expires - duration or nil, duration, aura.count
		end
	end
	return false, texture
end

local function cooldownActive(start, duration, enable)
	return enable == 1 and start and start > 0 and duration > GCD_DURATION
end

local function activeForShowMode(data, onCooldown)
	if field(data, "show", ICON_DEFAULTS) == "cooldown" then
		return onCooldown
	end
	return not onCooldown
end

local function spellCooldownActive(start, duration, enable)
	if not cooldownActive(start, duration, enable) then
		return false
	end
	return not (ns.PLAYER_CLASS == "DEATHKNIGHT" and duration == RUNE_COOLDOWN)
end

function evaluators.cooldown(icon, data)
	local entry = parseList(data.spells).entries[1]
	local texture = spellTexture(entry)
	local spell = entry and entry.name
	if not spell then
		return false, texture
	end
	local start, duration, enable = GetSpellCooldown(spell)
	if not start then
		return false, texture
	end
	texture = GetSpellTexture(spell) or texture
	local onCooldown = spellCooldownActive(start, duration, enable)
	local tint
	local usable, noMana = IsUsableSpell(spell)
	if field(data, "range", ICON_DEFAULTS) and UnitExists("target") and IsSpellInRange(spell, "target") == 0 then
		tint = OUT_OF_RANGE_COLOR
	elseif noMana and field(data, "usable", ICON_DEFAULTS) then
		tint = NO_MANA_COLOR
	end
	icon.polling = field(data, "range", ICON_DEFAULTS)
	local active
	if field(data, "show", ICON_DEFAULTS) == "usable" then
		active = not onCooldown and usable
	else
		active = activeForShowMode(data, onCooldown)
	end
	if not onCooldown then
		start, duration = nil, nil
	end
	return active, texture, start, duration, nil, tint
end

function evaluators.item(icon, data)
	local items = itemEntries(data.spells)
	local texture = itemTexture(items[1])
	for i = 1, #items do
		local item = items[i]
		local start, duration, enable, count
		if item.slot then
			if GetInventoryItemTexture("player", item.slot) then
				start, duration, enable = GetInventoryItemCooldown("player", item.slot)
			end
		else
			local id = item.id
			if not id then
				local _, link = GetItemInfo(item.name)
				id = link and tonumber(link:match("item:(%d+)"))
			end
			count = id and GetItemCount(id, nil, true) or 0
			if count > 0 then
				start, duration, enable = GetItemCooldown(id)
			end
		end
		if start then
			local onCooldown = cooldownActive(start, duration, enable)
			if not onCooldown then
				start, duration = nil, nil
			end
			count = count and count > 1 and count or nil
			return activeForShowMode(data, onCooldown), itemTexture(item), start, duration, count
		end
	end
	return false, texture
end

function evaluators.totem(icon, data)
	local list = parseList(data.spells)
	local texture = spellTexture(list.first)
	for slot = 1, 4 do
		local haveTotem, name, start, duration, totemIcon = GetTotemInfo(slot)
		if haveTotem and name and name ~= "" then
			local lower = name:lower()
			local matched = list.names[lower]
			if not matched then
				for wanted in pairs(list.names) do
					if lower:find(wanted, 1, true) then
						matched = true
						break
					end
				end
			end
			if matched then
				return true, totemIcon, start, duration
			end
		end
	end
	return false, texture
end

local icdStarts = {}

local function icdDuration(data)
	local duration = field(data, "duration", ICON_DEFAULTS)
	if duration > 0 then
		return duration
	end
	local list = parseList(data.spells)
	if not list.icd then
		local known = 0
		for id in pairs(list.ids) do
			known = max(known, icdBySpell[id] or 0)
		end
		for name in pairs(list.names) do
			known = max(known, icdByName[name] or 0)
		end
		list.icd = known > 0 and known or DEFAULT_ICD
	end
	return list.icd
end

function evaluators.icd(icon, data)
	local list = parseList(data.spells)
	local texture = spellTexture(list.first)
	local duration = icdDuration(data)
	local start = icdStarts[data.spells]
	local onCooldown = start and GetTime() < start + duration
	if onCooldown then
		return activeForShowMode(data, onCooldown), texture, start, duration
	end
	return activeForShowMode(data, onCooldown), texture
end

local function trackedId(unit, entry)
	if entry.id then
		return entry.id
	end
	local wanted = entry.name:lower()
	local tracked = CooldownTracker:GetTracked(unit)
	if tracked then
		for i = 1, #tracked do
			local id = tracked[i]
			local name = GetSpellInfo(id)
			if name and name:lower() == wanted then
				return id
			end
		end
	end
end

function evaluators.unitcd(icon, data)
	local list = parseList(data.spells)
	local unit = field(data, "unit", ICON_DEFAULTS)
	local texture = spellTexture(list.first)
	local guid = UnitExists(unit) and UnitGUID(unit)
	if not guid then
		return false, texture
	end
	local show = field(data, "show", ICON_DEFAULTS)
	local readyTexture, cooldownStart, cooldownDuration, cooldownTexture
	local entries = list.entries
	for i = 1, #entries do
		local id = trackedId(unit, entries[i])
		if id then
			local start, duration = CooldownTracker:GetCooldown(guid, id)
			local entryTexture = ns.SpellTexture(id) or texture
			if start then
				if not cooldownStart or start + duration < cooldownStart + cooldownDuration then
					cooldownStart, cooldownDuration, cooldownTexture = start, duration, entryTexture
				end
			elseif not readyTexture then
				readyTexture = entryTexture
			end
		end
	end
	if show == "cooldown" then
		if cooldownStart then
			return true, cooldownTexture, cooldownStart, cooldownDuration
		end
		return false, readyTexture or texture
	end
	if readyTexture then
		return true, readyTexture
	end
	if cooldownStart then
		return false, cooldownTexture, cooldownStart, cooldownDuration
	end
	return false, texture
end

function evaluators.dr(icon, data)
	local category = field(data, "category", ICON_DEFAULTS)
	local unit = field(data, "unit", ICON_DEFAULTS)
	local texture = QUESTION_MARK
	local testSpells = DRData.TEST_SPELLS
	for i = 1, #testSpells do
		local spellId = testSpells[i]
		if DRData.SPELLS[spellId] == category then
			texture = ns.SpellTexture(spellId)
			break
		end
	end
	local state = DR:Get(UnitGUID(unit))
	local entry = state and state[category]
	if not entry or entry.stacks == 0 then
		return false, texture
	end
	local tint = ns.Config.diminishingReturns[DR_COLOR_KEYS[entry.stacks]]
	texture = ns.SpellTexture(entry.spellId) or texture
	if DR:IsAuraActive(entry, GetTime()) then
		return true, texture, nil, nil, DR_TEXT[entry.stacks], nil, tint
	end
	local reset = DRData.RESET_TIME
	return true, texture, entry.expires - reset, reset, DR_TEXT[entry.stacks], nil, tint
end

local groups = {}
local allIcons = {}
local preview = false
local inCombat = false

local ticker = CreateFrame("Frame")
ticker:Hide()
ticker.untilTick = 0

local function createIcon(group)
	local icon = CreateFrame("Frame", nil, group)
	icon:Hide()

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetPoint("TOPLEFT", 1, -1)
	icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
	icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints(icon.texture)

	local overlay = CreateFrame("Frame", nil, icon)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 1)

	icon.border = overlay:CreateTexture(nil, "ARTWORK")
	icon.border:SetTexture(ns.Media.buttonNormal)
	icon.border:SetAllPoints()

	icon.count = overlay:CreateFontString(nil, "OVERLAY")
	icon.count:SetPoint("BOTTOMRIGHT", -1, 2)
	icon.count:SetJustifyH("RIGHT")

	CooldownTimer:Attach(icon.cooldown, 12, overlay)
	return icon
end

local function setCooldown(icon, start, duration, reverse)
	if start and duration and duration > 0 then
		if icon.start ~= start or icon.duration ~= duration then
			icon.start, icon.duration = start, duration
			icon.cooldown:SetReverse(reverse)
			icon.cooldown:SetCooldown(start, duration)
		end
		icon.cooldown:Show()
		return start + duration
	end
	if icon.start then
		icon.start, icon.duration = nil, nil
		icon.cooldown:SetCooldown(0, 0)
	end
	icon.cooldown:Hide()
end

local function groupVisible(data)
	if not ns.Config.trackers.enabled or not field(data, "enabled", GROUP_DEFAULTS) then
		return false
	end
	local class = field(data, "class", GROUP_DEFAULTS)
	if class ~= "" and class ~= ns.PLAYER_CLASS then
		return false
	end
	if preview then
		return true
	end
	local combat = field(data, "combat", GROUP_DEFAULTS)
	if combat == "combat" and not inCombat or combat == "nocombat" and inCombat then
		return false
	end
	local zone = field(data, "zone", GROUP_DEFAULTS)
	if zone ~= "any" then
		local _, instanceType = IsInInstance()
		if
			zone == "arena" and instanceType ~= "arena"
			or zone == "pvp" and instanceType ~= "arena" and instanceType ~= "pvp"
			or zone == "world" and instanceType ~= "none"
		then
			return false
		end
	end
	local talentGroup = field(data, "talentGroup", GROUP_DEFAULTS)
	return talentGroup == 0 or talentGroup == GetActiveTalentGroup()
end

local function layoutGroup(group)
	local data = group.data
	local size = field(data, "size", GROUP_DEFAULTS)
	local spacing = field(data, "spacing", GROUP_DEFAULTS)
	local columns = max(1, field(data, "columns", GROUP_DEFAULTS))
	local collapse = field(data, "collapse", GROUP_DEFAULTS) and not preview
	local slot = 0
	for i = 1, #group.icons do
		local icon = group.icons[i]
		if icon.data and (icon:IsShown() or not collapse) then
			local column = slot % columns
			local row = floor(slot / columns)
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", column * (size + spacing), -row * (size + spacing))
			slot = slot + 1
		end
	end
	local count = max(1, data.icons and #data.icons or 0)
	local width = min(count, columns)
	local height = floor((count - 1) / columns) + 1
	group:SetSize(width * size + (width - 1) * spacing, height * size + (height - 1) * spacing)
end

local function updateIcon(icon)
	local data, group = icon.data, icon:GetParent()
	local kind = field(data, "type", ICON_DEFAULTS)
	local evaluate = evaluators[kind]
	if not evaluate then
		icon:Hide()
		return
	end
	icon.polling = nil
	local active, texture, start, duration, count, tint, border = evaluate(icon, data)
	local show = field(data, "show", ICON_DEFAULTS)
	local visible, inactive
	if preview or show == "always" then
		visible, inactive = true, not active
	elseif show == "absent" then
		visible = not active
		start, duration, count = nil, nil, nil
	else
		visible = active
	end

	if not visible then
		if icon:IsShown() then
			icon:Hide()
			icon.wakeAt = nil
			return true
		end
		icon.wakeAt = start and duration and start + duration or nil
		return
	end

	local groupData = group.data
	icon.texture:SetTexture(texture or QUESTION_MARK)
	icon.texture:SetDesaturated(inactive and 1 or nil)
	if tint then
		icon.texture:SetVertexColor(tint[1], tint[2], tint[3])
	else
		icon.texture:SetVertexColor(1, 1, 1)
	end
	if border then
		icon.border:SetVertexColor(border[1], border[2], border[3])
	else
		icon.border:SetVertexColor(1, 1, 1)
	end
	icon:SetAlpha(inactive and not preview and field(groupData, "inactiveAlpha", GROUP_DEFAULTS) or 1)

	icon.wakeAt = setCooldown(icon, start, duration, kind == "aura" or kind == "totem")
	icon.cooldown.timer:SetAlpha(field(groupData, "timer", GROUP_DEFAULTS) and 1 or 0)
	if count and count ~= 1 then
		icon.count:SetText(count)
	else
		icon.count:SetText("")
	end

	if not icon:IsShown() then
		icon:Show()
		return true
	end
end

local function updateGroup(group)
	if not group:IsShown() then
		return
	end
	local changed = false
	for i = 1, #group.icons do
		local icon = group.icons[i]
		if icon.data and updateIcon(icon) then
			changed = true
		end
	end
	if changed and field(group.data, "collapse", GROUP_DEFAULTS) then
		layoutGroup(group)
	end
end

local function needsTicker()
	for i = 1, #allIcons do
		local icon = allIcons[i]
		if icon.polling or icon.wakeAt then
			return true
		end
	end
	return false
end

local function refreshTicker()
	if needsTicker() then
		ticker:Show()
	else
		ticker:Hide()
	end
end

local function updateAll()
	for i = 1, #groups do
		updateGroup(groups[i])
	end
	refreshTicker()
end

local changedGroups = {}

local function updateIconTrackingLayout(icon)
	if updateIcon(icon) then
		changedGroups[icon:GetParent()] = true
	end
end

local function layoutChangedGroups()
	if not next(changedGroups) then
		return
	end
	for group in pairs(changedGroups) do
		if field(group.data, "collapse", GROUP_DEFAULTS) then
			layoutGroup(group)
		end
	end
	wipe(changedGroups)
end

local function updateWhere(predicate, arg)
	for i = 1, #allIcons do
		local icon = allIcons[i]
		if icon.data and icon:GetParent():IsShown() and predicate(icon.data, arg) then
			updateIconTrackingLayout(icon)
		end
	end
	layoutChangedGroups()
	refreshTicker()
end

ticker:SetScript("OnUpdate", function(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick > 0 then
		return
	end
	self.untilTick = TICK_INTERVAL
	local now = GetTime()
	for i = 1, #allIcons do
		local icon = allIcons[i]
		if icon.data and icon:GetParent():IsShown() and (icon.polling or icon.wakeAt and icon.wakeAt <= now) then
			updateIconTrackingLayout(icon)
		end
	end
	layoutChangedGroups()
	if not needsTicker() then
		self:Hide()
	end
end)

local function createGroup(index)
	local group = CreateFrame("Frame", nil, UIParent)
	group:SetFrameStrata("MEDIUM")
	group:SetSize(1, 1)
	group.icons = {}
	group.index = index
	return group
end

local function applyGroup(group, data, index)
	group.data = data
	local path = ("trackers.groups.%d.point"):format(index)
	group.path = path
	if data.point == nil then
		data.point = copy(GROUP_DEFAULTS.point)
	end
	ns.ApplyPoint(group, path)

	local size = field(data, "size", GROUP_DEFAULTS)
	local icons = data.icons or {}
	for i = 1, #icons do
		local icon = group.icons[i] or createIcon(group)
		group.icons[i] = icon
		icon.data = icons[i]
		icon.start, icon.duration, icon.wakeAt = nil, nil, nil
		icon:SetSize(size, size)
		ns.SetFont(icon.cooldown.timer, size * FONT_SCALE, "OUTLINE")
		ns.SetFont(icon.count, max(8, size * COUNT_SCALE), "OUTLINE")
		icon:Hide()
	end
	for i = #icons + 1, #group.icons do
		local icon = group.icons[i]
		icon.data = nil
		icon.wakeAt, icon.polling = nil, nil
		icon:Hide()
	end
	layoutGroup(group)

	if groupVisible(data) then
		group:Show()
	else
		group:Hide()
	end
	local class = field(data, "class", GROUP_DEFAULTS)
	if class == "" or class == ns.PLAYER_CLASS then
		ns.Movers.Register(group, path, field(data, "name", GROUP_DEFAULTS))
	else
		ns.Movers.Unregister(group)
	end
end

local function rebuildIconIndex()
	wipe(allIcons)
	for i = 1, #groups do
		local group = groups[i]
		if group.data then
			for j = 1, #group.icons do
				local icon = group.icons[j]
				if icon.data then
					allIcons[#allIcons + 1] = icon
				end
			end
		end
	end
end

local function applyConfig()
	local list = ns.Config.trackers.groups
	for i = 1, #list do
		local group = groups[i] or createGroup(i)
		groups[i] = group
		applyGroup(group, list[i], i)
	end
	for i = #list + 1, #groups do
		local group = groups[i]
		if group.data then
			group.data = nil
			ns.Movers.Unregister(group)
			for j = 1, #group.icons do
				group.icons[j].data = nil
			end
		end
		group:Hide()
	end
	rebuildIconIndex()
	updateAll()
end

local function updateVisibility()
	local changed = false
	for i = 1, #groups do
		local group = groups[i]
		if group.data then
			local visible = groupVisible(group.data)
			if visible ~= (group:IsShown() and true or false) then
				changed = true
				if visible then
					group:Show()
				else
					group:Hide()
				end
			end
		end
	end
	if changed then
		updateAll()
	end
end

function Trackers.SetPreview(value)
	value = value and true or false
	if preview == value then
		return
	end
	preview = value
	for i = 1, #groups do
		if groups[i].data then
			layoutGroup(groups[i])
		end
	end
	updateVisibility()
	updateAll()
end

local function iconType(kind)
	return function(data)
		return field(data, "type", ICON_DEFAULTS) == kind
	end
end

local UNIT_TYPES = { aura = true, dr = true, unitcd = true }

local function iconUnit(data, unit)
	return UNIT_TYPES[field(data, "type", ICON_DEFAULTS)] and field(data, "unit", ICON_DEFAULTS) == unit
end

local function dependsOnGroupOrTarget(data)
	local kind = field(data, "type", ICON_DEFAULTS)
	return UNIT_TYPES[kind] or kind == "cooldown"
end

local function isCooldown(data)
	local kind = field(data, "type", ICON_DEFAULTS)
	return kind == "cooldown" or kind == "item"
end

local isItem, isTotem, isDR = iconType("item"), iconType("totem"), iconType("dr")
local isUnitCooldown, isICD = iconType("unitcd"), iconType("icd")

local ICD_EVENTS = {
	SPELL_AURA_APPLIED = true,
	SPELL_AURA_REFRESH = true,
	SPELL_ENERGIZE = true,
	SPELL_SUMMON = true,
	SPELL_DAMAGE = true,
	SPELL_HEAL = true,
}

local function onCombatLog(_, _, event, sourceGUID, _, _, destGUID, _, _, spellId, spellName)
	if not ICD_EVENTS[event] then
		return
	end
	local player = UnitGUID("player")
	if sourceGUID ~= player and destGUID ~= player then
		return
	end
	local now = GetTime()
	local changed = false
	for i = 1, #allIcons do
		local data = allIcons[i].data
		if field(data, "type", ICON_DEFAULTS) == "icd" then
			local list = parseList(data.spells)
			if list.ids[spellId] or spellName and list.names[spellName:lower()] then
				local start = icdStarts[data.spells]
				if not start or now >= start + icdDuration(data) then
					icdStarts[data.spells] = now
					changed = true
				end
			end
		end
	end
	if changed then
		updateWhere(isICD)
	end
end

function Trackers:Initialize()
	applyConfig()
	self:WatchConfig("trackers", applyConfig)
	self:WatchConfig("diminishingReturns", function()
		updateWhere(isDR)
	end)

	self:RegisterEvent("UNIT_AURA", function(_, unit)
		updateWhere(iconUnit, unit)
	end)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", function()
		updateWhere(dependsOnGroupOrTarget)
	end)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", function()
		updateWhere(iconUnit, "focus")
	end)
	self:RegisterEvent("UNIT_PET", function()
		updateWhere(iconUnit, "pet")
	end)
	self:RegisterEvent("ARENA_OPPONENT_UPDATE", function(_, unit)
		updateWhere(iconUnit, unit)
	end)
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", function()
		updateWhere(dependsOnGroupOrTarget)
	end)
	for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "BAG_UPDATE_COOLDOWN" }) do
		self:RegisterEvent(event, function()
			updateWhere(isCooldown)
		end)
	end
	for _, event in ipairs({ "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
		self:RegisterEvent(event, function()
			updateWhere(isItem)
		end)
	end
	self:RegisterEvent("PLAYER_TOTEM_UPDATE", function()
		updateWhere(isTotem)
	end)
	self:RegisterEvent(ns.DR_UPDATED, function()
		updateWhere(isDR)
	end)
	self:RegisterEvent(ns.COOLDOWN_UPDATED, function()
		updateWhere(isUnitCooldown)
	end)
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		inCombat = true
		updateVisibility()
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		inCombat = false
		updateVisibility()
	end)
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", updateVisibility)
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", updateVisibility)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		inCombat = UnitAffectingCombat("player") and true or false
		updateVisibility()
		updateAll()
	end)

	hooksecurefunc(ns.Movers, "Unlock", function()
		Trackers.SetPreview(ns.Movers.IsUnlocked())
	end)
	hooksecurefunc(ns.Movers, "Lock", function()
		Trackers.SetPreview(false)
	end)
end
