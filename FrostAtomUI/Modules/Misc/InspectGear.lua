local _, ns = ...

local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfo = GetItemInfo
local GetItemStats = GetItemStats
local GetItemGem = GetItemGem
local GetItemIcon = GetItemIcon
local tonumber, pairs, ipairs, wipe, sort = tonumber, pairs, ipairs, wipe, table.sort
local floor, min, max = math.floor, math.min, math.max
local tconcat = table.concat

local InspectGear = {}
ns.InspectGear = InspectGear

local MAX_LEVEL = 80
local STEM = 3
local SCAN_NAME = "FrostAtomUIInspectGearTooltip"

local SLOT_NAMES = {
	[1] = "HeadSlot",
	[2] = "NeckSlot",
	[3] = "ShoulderSlot",
	[4] = "ShirtSlot",
	[5] = "ChestSlot",
	[6] = "WaistSlot",
	[7] = "LegsSlot",
	[8] = "FeetSlot",
	[9] = "WristSlot",
	[10] = "HandsSlot",
	[11] = "Finger0Slot",
	[12] = "Finger1Slot",
	[13] = "Trinket0Slot",
	[14] = "Trinket1Slot",
	[15] = "BackSlot",
	[16] = "MainHandSlot",
	[17] = "SecondaryHandSlot",
	[18] = "RangedSlot",
	[19] = "TabardSlot",
}
InspectGear.SLOT_NAMES = SLOT_NAMES
InspectGear.LAYOUT = {
	left = { 1, 2, 3, 15, 5, 4, 19, 9 },
	right = { 10, 6, 7, 8, 11, 12, 13, 14 },
	bottom = { 16, 17, 18 },
}

local ENCHANT_SLOTS =
	{ [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [9] = true, [10] = true, [15] = true, [16] = true }
local OFFHAND_ENCHANTABLE =
	{ INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_2HWEAPON = true }
local RANGED_ENCHANTABLE = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local WAIST_SLOT = 6

local SOCKET_KEYS =
	{ "EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_META", "EMPTY_SOCKET_PRISMATIC" }
local SOCKET_TEXTURES = {
	EMPTY_SOCKET_RED = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red",
	EMPTY_SOCKET_YELLOW = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow",
	EMPTY_SOCKET_BLUE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue",
	EMPTY_SOCKET_META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta",
	EMPTY_SOCKET_PRISMATIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
}
local emptySocketTexture = {}
for _, key in ipairs(SOCKET_KEYS) do
	if _G[key] then
		emptySocketTexture[_G[key]] = SOCKET_TEXTURES[key]
	end
end

local STATS = {
	{ key = "ITEM_MOD_STAMINA_SHORT" },
	{ key = "ITEM_MOD_RESILIENCE_RATING_SHORT", rating = 94.271225, resilience = true },
	{ key = "ITEM_MOD_STRENGTH_SHORT" },
	{ key = "ITEM_MOD_AGILITY_SHORT" },
	{ key = "ITEM_MOD_INTELLECT_SHORT" },
	{ key = "ITEM_MOD_SPIRIT_SHORT" },
	{ key = "ITEM_MOD_ATTACK_POWER_SHORT" },
	{ key = "ITEM_MOD_SPELL_POWER_SHORT" },
	{ key = "ITEM_MOD_CRIT_RATING_SHORT", rating = 45.905987 },
	{ key = "ITEM_MOD_HASTE_RATING_SHORT", rating = 32.78999 },
	{ key = "ITEM_MOD_HIT_RATING_SHORT", rating = 32.78999, spellRating = 26.231993 },
	{ key = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", rating = 13.99575 },
	{ key = "ITEM_MOD_EXPERTISE_RATING_SHORT", rating = 8.197496, points = true },
	{ key = "ITEM_MOD_SPELL_PENETRATION_SHORT" },
	{ key = "ITEM_MOD_POWER_REGEN0_SHORT" },
	{ key = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", rating = 4.918498, points = true },
	{ key = "ITEM_MOD_DODGE_RATING_SHORT", rating = 45.250187 },
	{ key = "ITEM_MOD_PARRY_RATING_SHORT", rating = 45.250187 },
	{ key = "ITEM_MOD_BLOCK_RATING_SHORT", rating = 16.394995 },
	{ key = "ITEM_MOD_BLOCK_VALUE_SHORT" },
	{ key = "RESISTANCE0_NAME" },
}
InspectGear.STATS = STATS
InspectGear.MAX_LEVEL = MAX_LEVEL

local ALL_STATS = {
	"ITEM_MOD_STRENGTH_SHORT",
	"ITEM_MOD_AGILITY_SHORT",
	"ITEM_MOD_STAMINA_SHORT",
	"ITEM_MOD_INTELLECT_SHORT",
	"ITEM_MOD_SPIRIT_SHORT",
}
local SKIP_WORDS = { ["Ðº"] = true, ["ÐºÐ¾"] = true, your = true, ["Ð²Ð°ÑˆÐµÐ¹"] = true, ["Ð²Ð°Ñˆ"] = true }
local BY_WORD = { ruRU = "Ð½Ð°" }

local function lower(text)
	text = text:lower()
	text = text:gsub("\208([\144-\159])", function(c)
		return "\208" .. string.char(c:byte() + 32)
	end)
	text = text:gsub("\208([\160-\175])", function(c)
		return "\209" .. string.char(c:byte() - 32)
	end)
	return (text:gsub("\208\129", "\209\145"))
end

local function stem(word)
	local count, i = 0, 1
	while i <= #word do
		count = count + 1
		if count > STEM then
			return word:sub(1, i - 1)
		end
		local b = word:byte(i)
		i = i + (b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1)
	end
	return word
end

local words = {}

local function normalize(text)
	local n = 0
	for word in lower(text):gmatch("[%a\128-\255]+") do
		if not SKIP_WORDS[word] then
			n = n + 1
			words[n] = stem(word)
		end
	end
	return tconcat(words, " ", 1, n)
end

local aliases

local function buildAliases()
	aliases = {}
	local function add(text, key)
		if text and text ~= "" then
			aliases[#aliases + 1] = { normalize(text), key }
		end
	end
	for _, stat in ipairs(STATS) do
		add(_G[stat.key], stat.key)
	end
	add(SPELL_STATALL, "ALL")
	add(ITEM_MOD_SPELL_DAMAGE_DONE_SHORT, "ITEM_MOD_SPELL_POWER_SHORT")
	add(ITEM_MOD_SPELL_HEALING_DONE_SHORT, "ITEM_MOD_SPELL_POWER_SHORT")
	add(RESILIENCE, "ITEM_MOD_RESILIENCE_RATING_SHORT")
	add("mana every 5 seconds", "ITEM_MOD_POWER_REGEN0_SHORT")
	add("mana per 5", "ITEM_MOD_POWER_REGEN0_SHORT")
	sort(aliases, function(a, b)
		return #a[1] > #b[1]
	end)
end

local function matchStat(text)
	if not aliases then
		buildAliases()
	end
	local normalized = normalize(text)
	for i = 1, #aliases do
		local alias, key = aliases[i][1], aliases[i][2]
		local length = #alias
		if
			length > 0
			and normalized:sub(1, length) == alias
			and (#normalized == length or normalized:sub(length + 1, length + 1) == " ")
		then
			return key
		end
	end
end

local function addStat(into, key, value)
	if key == "ALL" then
		for i = 1, #ALL_STATS do
			into[ALL_STATS[i]] = (into[ALL_STATS[i]] or 0) + value
		end
	elseif key then
		into[key] = (into[key] or 0) + value
	end
end

local function stripColors(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function parseStats(text, into)
	text = stripColors(text)
	local found = false
	for value, percent, rest in text:gmatch("%+(%d+)(%%?)%s*([^%+\n]*)") do
		found = true
		if percent == "" then
			addStat(into, matchStat(rest), tonumber(value))
		end
	end
	if not found then
		local value, rest = text:match("^%s*(%d+)%s+([^\n]+)")
		if value then
			addStat(into, matchStat(rest), tonumber(value))
		end
	end
end

local setProbe = {}

local function parseSetBonus(text, into)
	wipe(setProbe)
	parseStats(text, setProbe)
	if next(setProbe) == nil then
		local by = BY_WORD[GetLocale()] or "by"
		local name, value = stripColors(text):match("^%S+%s+(.-)%s+" .. by .. "%s+(%d+)")
		if name then
			addStat(setProbe, matchStat(name), tonumber(value))
		end
	end
	for key, value in pairs(setProbe) do
		into[key] = (into[key] or 0) + value
	end
end

local function prefixOf(format)
	return format and format:match("^(.-)%%s") or nil
end

local SOCKET_BONUS_PREFIX = prefixOf(ITEM_SOCKET_BONUS)
local SET_BONUS_PREFIX = prefixOf(ITEM_SET_BONUS)
local SET_BONUS_GRAY_PATTERN = ITEM_SET_BONUS_GRAY
	and "^" .. ITEM_SET_BONUS_GRAY:gsub("[%(%)%.%-%+%[%]]", "%%%0"):gsub("%%d", "(%%d+)"):gsub("%%s", "(.+)") .. "$"
local SET_NAME_PATTERN = "^(.-) %((%d+)/(%d+)%)$"

local scan, scanLines

local function scanTooltip()
	if not scan then
		scan = CreateFrame("GameTooltip", SCAN_NAME, nil, "GameTooltipTemplate")
		scanLines = setmetatable({}, {
			__index = function(self, i)
				local line = _G[SCAN_NAME .. "TextLeft" .. i]
				self[i] = line
				return line
			end,
		})
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	return scan
end

local function setLink(link)
	scanTooltip():SetHyperlink(link)
	return scan:NumLines()
end

local function isGreen(r, g, b)
	return g > 0.9 and r < 0.15 and b < 0.15
end

local enchantCache = {}
local baseLines = {}

local function enchantText(link, enchantId)
	local cached = enchantCache[enchantId]
	if cached ~= nil then
		return cached
	end
	if setLink((link:gsub("(item:%-?%d+):%-?%d+", "%1:0", 1))) == 0 then
		return nil
	end
	wipe(baseLines)
	for i = 2, scan:NumLines() do
		local line = scanLines[i]
		local text = line:GetText()
		if text and isGreen(line:GetTextColor()) then
			baseLines[text] = true
		end
	end
	if setLink(link) == 0 then
		return nil
	end
	local found = false
	for i = 2, scan:NumLines() do
		local line = scanLines[i]
		local text = line:GetText()
		if text and text ~= "" and not baseLines[text] and isGreen(line:GetTextColor()) then
			found = text
			break
		end
	end
	scan:Hide()
	enchantCache[enchantId] = found
	return found
end

local function linkField(link, index)
	local fields = link:match("item:([%-%d:]+)")
	if not fields then
		return 0
	end
	local i = 0
	for value in fields:gmatch("(%-?%d+)") do
		i = i + 1
		if i == index then
			return tonumber(value) or 0
		end
	end
	return 0
end

local function gemInfo(link, index)
	local _, gemLink = GetItemGem(link, index)
	if gemLink and gemLink ~= "" then
		return gemLink, GetItemIcon(gemLink)
	end
end

local itemStats = {}
local BLACKSMITH_SLOTS = { [9] = true, [10] = true }
local HIDDEN_ENCHANT_STATS = {
	[3722] = { "ITEM_MOD_SPIRIT_SHORT", 1 }, -- Lightweave Embroidery
	[3728] = { "ITEM_MOD_SPIRIT_SHORT", 1 }, -- Darkglow Embroidery
	[3730] = { "ITEM_MOD_SPIRIT_SHORT", 1 }, -- Swordguard Embroidery
	[3605] = { "ITEM_MOD_AGILITY_SHORT", 23 }, -- Flexweave Underlay
	[3731] = { "ITEM_MOD_HIT_RATING_SHORT", 28 }, -- Titanium Weapon Chain
	[3223] = { "ITEM_MOD_PARRY_RATING_SHORT", 15 }, -- Adamantite Weapon Chain
	[3849] = { "ITEM_MOD_BLOCK_VALUE_SHORT", 81 }, -- Titanium Plating
	[3878] = { "ITEM_MOD_STAMINA_SHORT", 45 }, -- Mind Amplification Dish
}

local function hasBlacksmithSockets(unit)
	if not UnitIsUnit(unit, "player") then
		return true
	end
	local name = GetSpellInfo(2018) -- Blacksmithing
	for i = 1, GetNumSkillLines() do
		local skill, header, _, rank = GetSkillLineInfo(i)
		if not header and skill == name then
			return rank >= 400
		end
	end
	return false
end

local function scanItem(unit, slot, link, item, result, loaded, sets)
	local _, _, quality, _, _, itemType, subType, _, equipLoc, texture = GetItemInfo(link)
	item.name = link:match("%[(.-)%]")
	item.quality = quality
	item.itemType, item.subType = itemType, subType
	item.equipLoc = equipLoc
	item.icon = texture or GetItemIcon(link)
	if not quality then
		result.pending = true
	end

	wipe(itemStats)
	GetItemStats(link, itemStats)
	local native = 0
	for i = 1, #SOCKET_KEYS do
		native = native + (itemStats[SOCKET_KEYS[i]] or 0)
	end
	for key, value in pairs(itemStats) do
		if type(value) == "number" then
			result.stats[key] = (result.stats[key] or 0) + value
		end
	end
	item.dps = itemStats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
	item.attackPower = itemStats.ITEM_MOD_ATTACK_POWER_SHORT
	item.armor = itemStats.RESISTANCE0_NAME
	item.id = linkField(link, 1)

	item.enchantId = linkField(link, 2)
	if item.enchantId ~= 0 then
		local text = enchantText(link, item.enchantId)
		if text == nil then
			result.pending = true
		end
		item.enchant = text or nil
		if text then
			parseStats(text, result.stats)
		end
		local hidden = HIDDEN_ENCHANT_STATS[item.enchantId]
		if hidden then
			addStat(result.stats, hidden[1], hidden[2])
		end
	end

	local tooltip = scanTooltip()
	if loaded then
		tooltip:SetInventoryItem(unit, slot)
	end
	if tooltip:NumLines() == 0 then
		tooltip:SetHyperlink(link)
	end
	if tooltip:NumLines() == 0 then
		result.pending = true
	end

	local gems, gemIndex = item.gems, 0
	local extraSocketActive = not BLACKSMITH_SLOTS[slot] or hasBlacksmithSockets(unit)
	local set
	for i = 2, tooltip:NumLines() do
		local line = scanLines[i]
		local text = line:GetText()
		if text and text ~= "" then
			local r, g, b = line:GetTextColor()
			local empty = emptySocketTexture[text]
			if empty then
				gemIndex = gemIndex + 1
				gems[gemIndex] = { empty = empty, name = text }
				item.emptySockets = (item.emptySockets or 0) + 1
			elseif text:sub(1, 2) == "|c" and text:find("%+%d") then
				gemIndex = gemIndex + 1
				local gemLink, icon = gemInfo(link, gemIndex)
				local plain = stripColors(text)
				local gem = { link = gemLink, icon = icon, text = plain:match("^[^\n]*") }
				gem.subType = gemLink and select(7, GetItemInfo(gemLink))
				if gemLink and not gem.subType then
					result.pending = true
				end
				for requirement in plain:gmatch("\n%s*([^\n]+)") do
					gem.requirements = gem.requirements or {}
					gem.requirements[#gem.requirements + 1] = requirement
				end
				gems[gemIndex] = gem
				if gemIndex > native and not extraSocketActive then
					gem.inactive = true
				elseif gem.requirements then
					result.metas[#result.metas + 1] = { gem = gem, item = item }
				else
					parseStats(gem.text, result.stats)
				end
			elseif SOCKET_BONUS_PREFIX and text:sub(1, #SOCKET_BONUS_PREFIX) == SOCKET_BONUS_PREFIX then
				item.socketBonus = text:sub(#SOCKET_BONUS_PREFIX + 1)
				item.socketBonusActive = isGreen(r, g, b)
				if item.socketBonusActive then
					parseStats(item.socketBonus, result.stats)
				end
			else
				local setName, _, max = text:match(SET_NAME_PATTERN)
				if setName and not text:find("|c") then
					item.set = setName
					if sets[setName] then
						set = nil
					else
						set = { name = setName, count = 0, max = tonumber(max), bonuses = {} }
						sets[setName] = set
						result.sets[#result.sets + 1] = set
					end
				elseif set then
					local required, bonus = nil, nil
					if SET_BONUS_GRAY_PATTERN then
						required, bonus = text:match(SET_BONUS_GRAY_PATTERN)
					end
					if not bonus and SET_BONUS_PREFIX and text:sub(1, #SET_BONUS_PREFIX) == SET_BONUS_PREFIX then
						bonus = text:sub(#SET_BONUS_PREFIX + 1)
					end
					if bonus then
						set.bonuses[#set.bonuses + 1] = { text = bonus, required = tonumber(required) }
					end
				end
			end
		end
	end
	tooltip:Hide()

	for i = gemIndex + 1, 4 do
		local gemLink, icon = gemInfo(link, i)
		if gemLink then
			gemIndex = gemIndex + 1
			gems[gemIndex] = { link = gemLink, icon = icon, subType = select(7, GetItemInfo(gemLink)) }
		end
	end

	item.sockets = gemIndex
	item.nativeSockets = native
end

local GEM_COLORS = {
	{ "red" },
	{ "blue" },
	{ "yellow" },
	{ "red", "blue" },
	{ "blue", "yellow" },
	{ "red", "yellow" },
	{ "meta" },
	{},
	{ "red", "blue", "yellow" },
}
local GEM_CLASS = 10

local gemSubTypes, conditions

local function toPattern(format)
	format = format:gsub("|4[^;]*;", "\1"):gsub("%%d", "\2"):gsub("%%s", "\3")
	format = format:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	return "^" .. format:gsub("\1", "%%S*"):gsub("\2", "(%%d+)"):gsub("\3", "(.-)") .. "$"
end

local function buildConditions()
	gemSubTypes = {}
	local subTypes = { GetAuctionItemSubClasses(GEM_CLASS) }
	for i, colors in ipairs(GEM_COLORS) do
		if subTypes[i] then
			gemSubTypes[subTypes[i]] = colors
		end
	end
	conditions = {}
	local function compare(format, test)
		if format then
			conditions[#conditions + 1] = { pattern = toPattern(format), test = test }
		end
	end
	compare(ENCHANT_CONDITION_MORE_VALUE, function(a, n)
		return a >= n
	end)
	compare(ENCHANT_CONDITION_LESS_VALUE, function(a, n)
		return a < n
	end)
	compare(ENCHANT_CONDITION_EQUAL_VALUE, function(a, n)
		return a == n
	end)
	compare(ENCHANT_CONDITION_NOT_EQUAL_VALUE, function(a, n)
		return a ~= n
	end)
	compare(ENCHANT_CONDITION_MORE_COMPARE, function(a, b)
		return a > b
	end)
	compare(ENCHANT_CONDITION_MORE_EQUAL_COMPARE, function(a, b)
		return a >= b
	end)
	compare(ENCHANT_CONDITION_EQUAL_COMPARE, function(a, b)
		return a == b
	end)
	compare(ENCHANT_CONDITION_NOT_EQUAL_COMPARE, function(a, b)
		return a ~= b
	end)
end

local colorNames

local function colorOf(name)
	if not colorNames then
		colorNames = {}
		colorNames[lower(RED_GEM or "Red")] = "red"
		colorNames[lower(BLUE_GEM or "Blue")] = "blue"
		colorNames[lower(YELLOW_GEM or "Yellow")] = "yellow"
		colorNames[lower(META_GEM or "Meta")] = "meta"
	end
	return name and colorNames[lower(name)]
end

local function requirementMet(text, counts)
	local prefix = ENCHANT_CONDITION_REQUIRES or ""
	if text:sub(1, #prefix) == prefix then
		text = text:sub(#prefix + 1)
	end
	for _, condition in ipairs(conditions) do
		local first, second = text:match(condition.pattern)
		if first then
			local a, b
			if tonumber(first) then
				a, b = counts[colorOf(second)], tonumber(first)
			else
				a, b = counts[colorOf(first)], counts[colorOf(second)]
			end
			if a == nil or b == nil then
				return true
			end
			return condition.test(a, b)
		end
	end
	return true
end

local function evaluateMetas(result)
	if #result.metas == 0 then
		return
	end
	if not conditions then
		buildConditions()
	end
	local counts = { red = 0, blue = 0, yellow = 0, meta = 0 }
	for _, item in pairs(result.slots) do
		for _, gem in ipairs(item.gems) do
			local colors = gem.subType and gemSubTypes[gem.subType]
			if colors then
				for i = 1, #colors do
					counts[colors[i]] = counts[colors[i]] + 1
				end
			end
		end
	end
	for _, meta in ipairs(result.metas) do
		local gem, active = meta.gem, true
		for _, requirement in ipairs(gem.requirements) do
			active = active and requirementMet(requirement, counts)
		end
		gem.inactive = not active
		if active then
			parseStats(gem.text, result.stats)
		else
			meta.item.inactiveMeta = true
		end
	end
end

local function evaluateSets(result)
	for _, set in ipairs(result.sets) do
		for _, item in pairs(result.slots) do
			if item.set == set.name then
				set.count = set.count + 1
			end
		end
		for _, bonus in ipairs(set.bonuses) do
			bonus.active = not bonus.required or set.count >= bonus.required
			if bonus.active then
				parseSetBonus(bonus.text, result.stats)
			end
		end
	end
end

local function isEnchantable(slot, item, class)
	if ENCHANT_SLOTS[slot] then
		return true
	end
	if slot == 17 then
		return OFFHAND_ENCHANTABLE[item.equipLoc] or false
	end
	if slot == 18 then
		return class == "HUNTER" and RANGED_ENCHANTABLE[item.equipLoc] or false
	end
	return false
end

local function slotLabel(slot)
	return _G[SLOT_NAMES[slot]:upper()] or SLOT_NAMES[slot]
end
InspectGear.SlotLabel = slotLabel

local function addIssue(result, severity, text, slot)
	result.issues[#result.issues + 1] = { severity = severity, text = text, slot = slot }
end

local function checkItem(result, slot, item, class, capped)
	if not capped then
		return
	end
	if isEnchantable(slot, item, class) and item.enchantId == 0 then
		item.missingEnchant = true
		addIssue(result, "error", ns.L["No enchant: %s"]:format(slotLabel(slot)), slot)
	end
	if item.emptySockets then
		addIssue(result, "error", ns.L["Empty socket: %s"]:format(slotLabel(slot)), slot)
	end
	if slot == WAIST_SLOT and item.sockets <= item.nativeSockets then
		item.missingBuckle = true
		addIssue(result, "error", ns.L["No belt buckle"], slot)
	end
	if item.inactiveMeta then
		addIssue(result, "error", ns.L["Meta gem inactive"], slot)
	end
	if item.socketBonus and not item.socketBonusActive and not item.emptySockets then
		addIssue(result, "warning", ns.L["Socket bonus inactive: %s"]:format(slotLabel(slot)), slot)
	end
end

function InspectGear.Scan(unit, loaded, class, level)
	local result = { slots = {}, stats = {}, sets = {}, issues = {}, metas = {}, pending = false }
	local sets = {}
	for slot = 1, 19 do
		local link = GetInventoryItemLink(unit, slot)
		if link then
			local item = { link = link, gems = {} }
			scanItem(unit, slot, link, item, result, loaded, sets)
			result.slots[slot] = item
		elseif GetInventoryItemTexture(unit, slot) then
			result.pending = true
			result.slots[slot] = { icon = GetInventoryItemTexture(unit, slot), gems = {} }
		end
	end
	evaluateMetas(result)
	evaluateSets(result)
	local capped = level == MAX_LEVEL
	for slot = 1, 19 do
		local item = result.slots[slot]
		if item and item.link then
			checkItem(result, slot, item, class, capped)
		end
	end

	local levels = {}
	for slot in pairs(result.slots) do
		levels[slot] = {}
	end
	local average, count, missing = ns.UnitAverageItemLevel(unit, levels)
	for slot, holder in pairs(levels) do
		result.slots[slot].itemLevel = holder.itemLevel
	end
	result.average, result.count = average, count
	result.pending = result.pending or missing
	return result
end

local STAT_KEYS = {
	[0] = "ITEM_MOD_STRENGTH_SHORT",
	"ITEM_MOD_AGILITY_SHORT",
	"ITEM_MOD_STAMINA_SHORT",
	"ITEM_MOD_INTELLECT_SHORT",
	"ITEM_MOD_SPIRIT_SHORT",
}
local AP_KEY, SP_KEY = "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_SPELL_POWER_SHORT"
local ARMOR_KEY, BLOCK_VALUE_KEY = "RESISTANCE0_NAME", "ITEM_MOD_BLOCK_VALUE_SHORT"
local PERCENT_KEYS = {
	crit = "ITEM_MOD_CRIT_RATING_SHORT",
	spellCrit = "ITEM_MOD_CRIT_RATING_SHORT",
	allCrit = "ITEM_MOD_CRIT_RATING_SHORT",
	hit = "ITEM_MOD_HIT_RATING_SHORT",
	spellHit = "ITEM_MOD_HIT_RATING_SHORT",
	haste = "ITEM_MOD_HASTE_RATING_SHORT",
	spellHaste = "ITEM_MOD_HASTE_RATING_SHORT",
	expertise = "ITEM_MOD_EXPERTISE_RATING_SHORT",
	arp = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
	dodge = "ITEM_MOD_DODGE_RATING_SHORT",
	parry = "ITEM_MOD_PARRY_RATING_SHORT",
	block = "ITEM_MOD_BLOCK_RATING_SHORT",
}
local CRIT_KEY, HIT_KEY, HASTE_KEY = "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT"
local EXPERTISE_KEY, ARP_KEY = "ITEM_MOD_EXPERTISE_RATING_SHORT", "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"
local DEFENSE_KEY, DODGE_KEY = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT"
local PARRY_KEY, BLOCK_KEY = "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT"
local RATING = {
	crit = 45.905987,
	hit = 32.78999,
	spellHit = 26.231993,
	haste = 32.78999,
	expertise = 8.197496,
	arp = 13.99575,
	defense = 4.918498,
	dodge = 45.250187,
	parry = 45.250187,
	block = 16.394995,
}
local FERAL_WEAPONS = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }
local MINOR_STAT = 20
local NO_PARRY = { PRIEST = true, MAGE = true, WARLOCK = true, DRUID = true, SHAMAN = true }
local NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true }
local MP5_KEY = "ITEM_MOD_POWER_REGEN0_SHORT"
local STAT_NAMES = { [0] = "SPELL_STAT1_NAME", "SPELL_STAT2_NAME", "SPELL_STAT3_NAME", "SPELL_STAT4_NAME", "SPELL_STAT5_NAME" }
local CRIT_TAKEN = { meleeCritTaken = "melee", rangedCritTaken = "ranged", spellCritTaken = "spell" }
local WEAPON_SUBCLASSES = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 16, 18, 19, 20 }
local ARMOR_SUBCLASSES = { 0, 1, 2, 3, 4, 6, 7, 8, 9, 10 }
local WEAPON_SLOTS = { 16, 17, 18 }

local subclassBits
local function subclassBit(item)
	if not subclassBits then
		subclassBits = {}
		local classes = { GetAuctionItemClasses() }
		for index, ids in ipairs({ WEAPON_SUBCLASSES, ARMOR_SUBCLASSES }) do
			local names = { GetAuctionItemSubClasses(index) }
			local byName = {}
			for i, name in ipairs(names) do
				if ids[i] then
					byName[name] = 2 ^ ids[i]
				end
			end
			subclassBits[classes[index] or index] = byName
		end
		subclassBits.weapon, subclassBits.armor = classes[1], classes[2]
	end
	local byName = item and item.itemType and subclassBits[item.itemType]
	return byName and byName[item.subType] or 0, item and item.itemType
end

local function hasBit(mask, bit)
	return bit > 0 and mask % (bit * 2) >= bit
end

local function conditionMet(effect, slots, form)
	if effect.stances and not (form and form > 0 and hasBit(effect.stances, 2 ^ (form - 1))) then
		return false
	end
	if effect.weapon then
		local found = false
		for _, slot in ipairs(WEAPON_SLOTS) do
			local bit, itemType = subclassBit(slots[slot])
			if itemType == subclassBits.weapon and hasBit(effect.weapon, bit) then
				found = true
			end
		end
		if not found then
			return false
		end
	end
	if effect.armor then
		local bit, itemType = subclassBit(slots[17])
		if itemType ~= subclassBits.armor or not hasBit(effect.armor, bit) then
			return false
		end
	end
	if effect.dual then
		local _, itemType = subclassBit(slots[17])
		if itemType ~= subclassBits.weapon then
			return false
		end
	end
	return true
end

local BASE_ARMOR_MASK = 94

local function splitArmor(gear, total)
	local bonusArmor = ns.InspectStatData.BONUS_ARMOR
	local base, extra = 0, 0
	for _, item in pairs(gear.slots) do
		if type(item) == "table" then
			local armor, bonus = item.armor or 0, bonusArmor[item.id] or 0
			local bit, itemType = subclassBit(item)
			if armor > 0 and itemType == subclassBits.armor and hasBit(BASE_ARMOR_MASK, bit) then
				base = base + armor - floor(bonus)
				extra = extra + bonus - floor(bonus)
			else
				extra = extra + (armor > 0 and bonus - floor(bonus) or bonus)
			end
		end
	end
	return base, total - base + extra
end

local function addSource(totals, key, name, text)
	local list = totals.sources[key]
	if not list then
		list = {}
		totals.sources[key] = list
	end
	list[#list + 1] = { name = name, text = text }
end

local function feralAttackPower(item)
	if not (item and item.dps and FERAL_WEAPONS[item.equipLoc]) then
		return 0
	end
	return max(0, floor(item.dps * 14) - 767)
end

local function percentText(value)
	return ("+%.2f%%"):format(value)
end

local function collectEffects(talents, info, gear)
	local effects = {}
	local function add(effect, value, name)
		if value and conditionMet(effect, gear.slots, info.form) then
			effects[#effects + 1] = { kind = effect[1], misc = effect[2], value = value, name = name }
		end
	end
	local data = ns.InspectTalentData
	for _, talent in ipairs(talents or {}) do
		for _, effect in ipairs(data[talent.id] or {}) do
			local ranks = effect[3]
			add(effect, ranks[min(talent.rank, #ranks)], talent.name)
		end
	end
	local stats = ns.InspectStatData
	for _, effect in ipairs(stats.RACIALS[info.race] or {}) do
		add(effect, effect[3], (GetSpellInfo(effect.spell)))
	end
	local form = info.formData
	if form then
		local name = form.spell and GetSpellInfo(form.spell)
		for _, effect in ipairs(form.effects) do
			add(effect, effect[3], name)
		end
	end
	return effects
end

function InspectGear.Compute(gear, talents, info)
	local Data = ns.InspectStatData
	local L = ns.L
	local class, caster = info.class, info.caster
	local classData = Data.CLASS[class]
	local baseStats = info.level == Data.LEVEL and Data.BASE_STATS[class] and Data.BASE_STATS[class][info.race]
	local full = classData ~= nil and baseStats ~= nil
	local form = info.formData or {}
	local gearStats = gear.stats
	local totals = { values = {}, percent = {}, visible = {}, sources = {}, critTaken = {}, full = full }
	local values, percent, visible = totals.values, totals.percent, totals.visible
	local function source(key, name, text)
		addSource(totals, key, name, text)
	end
	local function prepend(key, name, text)
		addSource(totals, key, name, text)
		local list = totals.sources[key]
		table.insert(list, 1, table.remove(list))
	end
	local function gearValue(key)
		return gearStats[key] or 0
	end

	local statMult, conversions = {}, {}
	local armorMult, blockMult, apMult = 1, 1, 1
	local apFlat, apLevel, apWeapon, spFromAp, healFromAp, apSources = 0, 0, 0, 0, 0, {}
	local bonus, schoolCrit, hasteMult, spellHasteMult = {}, {}, 1, 1
	local hunter = class == "HUNTER"

	for _, effect in ipairs(collectEffects(talents, info, gear)) do
		local kind, misc, value, name = effect.kind, effect.misc, effect.value, effect.name
		if kind == "stat" then
			for stat = misc == -1 and 0 or misc, misc == -1 and 4 or misc do
				statMult[stat] = (statMult[stat] or 1) * (1 + value / 100)
				source(STAT_KEYS[stat], name, ("+%d%%"):format(value))
			end
		elseif kind == "armor" then
			armorMult = armorMult * (1 + value / 100)
			source(ARMOR_KEY, name, ("+%d%%"):format(value))
		elseif kind == "blockValue" then
			blockMult = blockMult * (1 + value / 100)
			source(BLOCK_VALUE_KEY, name, ("+%d%%"):format(value))
		elseif kind == "ap" then
			apMult = apMult * (1 + value / 100)
			source(AP_KEY, name, ("+%d%%"):format(value))
		elseif kind == "apFlat" then
			apFlat = apFlat + value
			source(AP_KEY, name, ("+%d"):format(value))
		elseif kind == "apLevel" then
			apLevel = apLevel + value
		elseif kind == "apWeapon" then
			apWeapon = apWeapon + value
		elseif kind == "spFromAp" then
			spFromAp = spFromAp + value
			apSources[#apSources + 1] = { name = name, value = value }
		elseif kind == "healFromAp" then
			healFromAp = healFromAp + value
		elseif CRIT_TAKEN[kind] then
			local school = CRIT_TAKEN[kind]
			totals.critTaken[school] = (totals.critTaken[school] or 0) - value
		elseif kind == "haste" or kind == "spellHaste" then
			if (kind == "spellHaste") == (caster == true) then
				if kind == "haste" then
					hasteMult = hasteMult * (1 + value / 100)
				else
					spellHasteMult = spellHasteMult * (1 + value / 100)
				end
				source(HASTE_KEY, name, ("+%d%%"):format(value))
				visible[HASTE_KEY] = true
			end
		elseif PERCENT_KEYS[kind] then
			local physical = kind == "crit" or kind == "hit"
			local spell = kind == "spellCrit" or kind == "spellHit"
			if kind == "spellCrit" and misc > 0 then
				if caster then
					schoolCrit[#schoolCrit + 1] = { mask = misc, value = value, name = name }
				end
			elseif not (caster and physical or not caster and spell) then
				local key = PERCENT_KEYS[kind]
				bonus[key] = (bonus[key] or 0) + value
				source(key, name, kind == "expertise" and ("+%d"):format(value) or ("+%d%%"):format(value))
				visible[key] = true
			end
		elseif not (hunter and kind == "apFromStat" or not hunter and kind == "rapFromStat") then
			conversions[#conversions + 1] = { kind = kind, stat = misc, value = value, name = name }
		end
	end

	local stat = {}
	for index = 0, 4 do
		local key = STAT_KEYS[index]
		local base = full and baseStats[index + 1] or 0
		local fromGear = gearValue(key)
		stat[index] = floor((base + fromGear) * (statMult[index] or 1) + 0.0001)
		if stat[index] > 0 then
			values[key] = stat[index]
		end
		if fromGear >= MINOR_STAT or fromGear > 0 and (caster and index >= 2 or not caster and index <= 2) then
			visible[key] = true
		end
		if full then
			prepend(key, L["Gear"], ("+%d"):format(fromGear))
			prepend(key, L["Base"], ("%d"):format(base))
		end
	end
	local str, agi, int = stat[0], stat[1], stat[3]

	local baseArmor, extraArmor = splitArmor(gear, gearValue(ARMOR_KEY))
	local armor = floor(baseArmor * armorMult + extraArmor + (full and agi * 2 or 0) + 0.0001)
	if armor > 0 then
		values[ARMOR_KEY] = armor
		visible[ARMOR_KEY] = true
		if full then
			source(ARMOR_KEY, _G[STAT_NAMES[1]], ("+%d"):format(agi * 2))
		end
	end

	local level = info.level or 0
	local baseAp = 0
	if full then
		local melee = classData.melee
		if hunter then
			baseAp = level * 2 + agi - 10
		elseif melee == "warrior" then
			baseAp = level * 3 + str * 2 - 20
		elseif melee == "agile" then
			baseAp = level * 2 + str + agi - 20
		elseif melee == "caster" then
			baseAp = str - 10
		elseif info.form == 1 then
			baseAp = str * 2 + agi - 20
		else
			baseAp = str * 2 - 20
		end
		baseAp = max(floor(baseAp), 0)
		source(AP_KEY, L["Base"], ("+%d"):format(baseAp))
	end
	if form.feral or info.form == 31 then
		local weapon = gear.slots[16]
		local feral = feralAttackPower(weapon)
		if feral > 0 then
			baseAp = baseAp + feral
			source(AP_KEY, L["Weapon"], ("+%d"):format(feral))
		end
		if form.feral then
			local fromLevel = level * apLevel / 100
			local fromWeapon = ((weapon and weapon.attackPower or 0) + feral) * apWeapon / 100
			if fromLevel + fromWeapon > 0 then
				baseAp = baseAp + fromLevel + fromWeapon
				source(AP_KEY, GetSpellInfo(16972), ("+%d"):format(fromLevel + fromWeapon))
			end
		end
	end

	local apAdd, spAdd, healAdd = 0, 0, 0
	for _, conversion in ipairs(conversions) do
		local amount
		if conversion.kind == "apFromArmor" then
			amount = floor(armor / conversion.value)
		else
			amount = (stat[conversion.stat] or 0) * conversion.value / 100
		end
		if amount > 0 then
			local spell = conversion.kind == "spFromStat" or conversion.kind == "healFromStat"
			if conversion.kind == "spFromStat" then
				spAdd = spAdd + amount
			elseif conversion.kind == "healFromStat" then
				healAdd = healAdd + amount
			else
				apAdd = apAdd + amount
			end
			source(spell and SP_KEY or AP_KEY, conversion.name, ("+%d"):format(floor(amount + 0.5)))
		end
	end

	local ap = floor((floor(baseAp) + floor(gearValue(AP_KEY) + apFlat + apAdd)) * apMult + 0.0001)
	if ap > 0 then
		values[AP_KEY] = ap
		visible[AP_KEY] = not caster or gearValue(AP_KEY) > 0
	end
	for _, entry in ipairs(apSources) do
		source(SP_KEY, entry.name, ("+%d"):format(floor(ap * entry.value / 100 + 0.5)))
	end
	local sp = gearValue(SP_KEY) + max(spAdd + ap * spFromAp / 100, healAdd + ap * healFromAp / 100)
	if sp > 0 then
		values[SP_KEY] = sp
		visible[SP_KEY] = caster or gearValue(SP_KEY) > 0 or sp > gearValue(SP_KEY)
	end

	local shield = gear.slots[17] and gear.slots[17].equipLoc == "INVTYPE_SHIELD"
	if shield then
		local blockValue = floor((gearValue(BLOCK_VALUE_KEY) + (full and str * 0.5 - 10 or 0)) * blockMult)
		if blockValue > 0 then
			values[BLOCK_VALUE_KEY] = blockValue
			visible[BLOCK_VALUE_KEY] = gearValue(BLOCK_VALUE_KEY) > 0 or blockMult > 1
		end
	end

	local function rated(key, rating)
		local value = gearValue(key)
		if value > 0 then
			values[key] = value
			visible[key] = true
		end
		return value / rating
	end

	local fromRating = rated(CRIT_KEY, RATING.crit)
	local crit = fromRating + (bonus[CRIT_KEY] or 0)
	if full then
		local critData = caster and classData.spellCrit or classData.meleeCrit
		if critData then
			local fromStat = 100 * (critData[1] + (caster and int or agi) * critData[2])
			crit = crit + fromStat
			prepend(CRIT_KEY, L["Rating"], percentText(fromRating))
			prepend(CRIT_KEY, L["Base"] .. " + " .. _G[STAT_NAMES[caster and 3 or 1]], percentText(fromStat))
		end
		visible[CRIT_KEY] = true
	end
	percent[CRIT_KEY] = crit
	if caster then
		totals.schoolCrit = {}
		for school = 2, 7 do
			local value = crit
			for _, entry in ipairs(schoolCrit) do
				if hasBit(entry.mask, 2 ^ (school - 1)) then
					value = value + entry.value
				end
			end
			totals.schoolCrit[school] = value
		end
		for _, entry in ipairs(schoolCrit) do
			local schools = {}
			for school = 2, 7 do
				if hasBit(entry.mask, 2 ^ (school - 1)) then
					schools[#schools + 1] = _G["DAMAGE_SCHOOL" .. school]
				end
			end
			source(CRIT_KEY, ("%s (%s)"):format(entry.name, table.concat(schools, ", ")), ("+%d%%"):format(entry.value))
		end
	end

	percent[HIT_KEY] = rated(HIT_KEY, caster and RATING.spellHit or RATING.hit) + (bonus[HIT_KEY] or 0)

	local hasteRating = caster and RATING.haste or RATING.haste / (classData and classData.hasteScalar or 1)
	local fromHaste = rated(HASTE_KEY, hasteRating)
	percent[HASTE_KEY] = ((1 + fromHaste / 100) * (caster and spellHasteMult or hasteMult) - 1) * 100

	percent[EXPERTISE_KEY] = floor(rated(EXPERTISE_KEY, RATING.expertise)) + (bonus[EXPERTISE_KEY] or 0)
	if not caster and (bonus[EXPERTISE_KEY] or 0) > 0 then
		visible[EXPERTISE_KEY] = true
	end
	percent[ARP_KEY] = rated(ARP_KEY, RATING.arp) + (bonus[ARP_KEY] or 0)

	local defenseRating = rated(DEFENSE_KEY, RATING.defense)
	local defense = floor(defenseRating)
	percent[DEFENSE_KEY] = full and 400 + defense or defense
	local defenseChance = defenseRating * 0.04

	local dodgeRating = rated(DODGE_KEY, RATING.dodge)
	if full then
		local dodgeData = classData.dodge
		local baseAgi = baseStats[2]
		local perAgi = classData.meleeCrit[2] * dodgeData[2]
		local nondiminishing = 100 * (dodgeData[1] + baseAgi * perAgi) + (bonus[DODGE_KEY] or 0)
		local diminishing = 100 * (agi - baseAgi) * perAgi + defenseChance + dodgeRating
		local cap = dodgeData[3]
		percent[DODGE_KEY] = cap * diminishing / (diminishing + cap * classData.k) + nondiminishing
	else
		percent[DODGE_KEY] = dodgeRating + (bonus[DODGE_KEY] or 0)
	end

	local parryRating = rated(PARRY_KEY, RATING.parry)
	if full and classData.parryCap and not NO_PARRY[class] then
		local diminishing = parryRating + defenseChance
		local cap = classData.parryCap
		percent[PARRY_KEY] = cap * diminishing / (diminishing + cap * classData.k) + 5 + (bonus[PARRY_KEY] or 0)
	else
		percent[PARRY_KEY] = parryRating + (bonus[PARRY_KEY] or 0)
	end

	local blockRating = rated(BLOCK_KEY, RATING.block)
	percent[BLOCK_KEY] = blockRating + (bonus[BLOCK_KEY] or 0) + (full and shield and 5 + defenseChance or 0)
	if not shield then
		visible[BLOCK_KEY] = nil
	end

	for key, value in pairs(gearStats) do
		if values[key] == nil and type(value) == "number" and value > 0 then
			values[key] = value
			visible[key] = true
		end
	end
	if full then
		for index = 0, 4 do
			visible[STAT_KEYS[index]] = true
		end
		visible[DODGE_KEY] = true
		visible[PARRY_KEY] = not NO_PARRY[class] or nil
		visible[BLOCK_KEY] = shield or nil
	end
	if NO_MANA[class] then
		visible[MP5_KEY] = nil
	end
	return totals
end
