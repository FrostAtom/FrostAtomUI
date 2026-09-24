local ADDON_NAME, ns = ...

local GetItemInfo = GetItemInfo
local UnitLevel = UnitLevel
local concat = table.concat

local BagItems = {}
ns.BagItems = BagItems

local NON_GEAR_SLOTS = {
	[""] = true,
	INVTYPE_NON_EQUIP = true,
	INVTYPE_BAG = true,
	INVTYPE_QUIVER = true,
	INVTYPE_AMMO = true,
	INVTYPE_BODY = true,
	INVTYPE_TABARD = true,
}

local LINK_QUALITY = {
	ff9d9d9d = 0,
	ffffffff = 1,
	ff1eff00 = 2,
	ff0070dd = 3,
	ffa335ee = 4,
	ffff8000 = 5,
	ffe6cc80 = 6,
	ff00ccff = 7,
}

local CLASS_ARMOR = {
	MAGE = { cloth = true },
	PRIEST = { cloth = true },
	WARLOCK = { cloth = true },
	ROGUE = { cloth = true, leather = true },
	DRUID = { cloth = true, leather = true },
	HUNTER = { cloth = true, leather = true, mail = 40 },
	SHAMAN = { cloth = true, leather = true, mail = 40 },
	WARRIOR = { cloth = true, leather = true, mail = true, plate = 40 },
	PALADIN = { cloth = true, leather = true, mail = true, plate = 40 },
	DEATHKNIGHT = { cloth = true, leather = true, mail = true, plate = true },
}

local CLASS_SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }

local CLASS_WEAPONS = {
	MAGE = { dagger = true, staff = true, sword1h = true, wand = true },
	PRIEST = { dagger = true, mace1h = true, staff = true, wand = true },
	WARLOCK = { dagger = true, staff = true, sword1h = true, wand = true },
	ROGUE = {
		bow = true,
		crossbow = true,
		dagger = true,
		fist = true,
		gun = true,
		mace1h = true,
		sword1h = true,
		thrown = true,
	},
	DRUID = { dagger = true, fist = true, mace1h = true, mace2h = true, staff = true, polearm = true },
	HUNTER = {
		bow = true,
		crossbow = true,
		gun = true,
		dagger = true,
		fist = true,
		axe1h = true,
		axe2h = true,
		sword1h = true,
		sword2h = true,
		polearm = true,
		staff = true,
		thrown = true,
	},
	SHAMAN = { axe1h = true, axe2h = true, mace1h = true, mace2h = true, staff = true, dagger = true, fist = true },
	WARRIOR = {
		axe1h = true,
		axe2h = true,
		bow = true,
		gun = true,
		mace1h = true,
		mace2h = true,
		polearm = true,
		sword1h = true,
		sword2h = true,
		staff = true,
		fist = true,
		dagger = true,
		thrown = true,
		crossbow = true,
	},
	PALADIN = {
		axe1h = true,
		axe2h = true,
		mace1h = true,
		mace2h = true,
		sword1h = true,
		sword2h = true,
		polearm = true,
	},
	DEATHKNIGHT = {
		axe1h = true,
		axe2h = true,
		mace1h = true,
		mace2h = true,
		sword1h = true,
		sword2h = true,
		polearm = true,
	},
}

local ARMOR_SLOTS = {
	INVTYPE_HEAD = true,
	INVTYPE_SHOULDER = true,
	INVTYPE_CHEST = true,
	INVTYPE_ROBE = true,
	INVTYPE_WAIST = true,
	INVTYPE_LEGS = true,
	INVTYPE_FEET = true,
	INVTYPE_WRIST = true,
	INVTYPE_HAND = true,
}

local WEAPON_SLOTS = {
	INVTYPE_WEAPON = true,
	INVTYPE_WEAPONMAINHAND = true,
	INVTYPE_WEAPONOFFHAND = true,
	INVTYPE_2HWEAPON = true,
	INVTYPE_RANGED = true,
	INVTYPE_THROWN = true,
	INVTYPE_RANGEDRIGHT = true,
}

local WEAPON_KEYS = {
	"axe1h",
	"axe2h",
	"bow",
	"gun",
	"mace1h",
	"mace2h",
	"polearm",
	"sword1h",
	"sword2h",
	"staff",
	"fist",
	false,
	"dagger",
	"thrown",
	"crossbow",
	"wand",
}

local QUALITY_NAMES = { "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact", "heirloom" }

local SEARCH_KEYS = {
	q = "quality",
	quality = "quality",
	ilvl = "level",
	lvl = "level",
	l = "level",
	t = "type",
	type = "type",
	n = "name",
	name = "name",
	tt = "tooltip",
	tip = "tooltip",
	s = "set",
	set = "set",
}

local SEARCH_KEYWORDS = { boe = "boe", bop = "bop", boa = "boa", quest = "quest" }

local BIND_TEXTS = {}
for text, keyword in pairs({
	ITEM_BIND_ON_EQUIP = "boe",
	ITEM_BIND_ON_PICKUP = "bop",
	ITEM_SOULBOUND = "bop",
	ITEM_BIND_TO_ACCOUNT = "boa",
	ITEM_BIND_QUEST = "quest",
}) do
	if _G[text] then
		BIND_TEXTS[_G[text]] = keyword
	end
end

function ns.LinkQuality(link)
	local color = link:match("|c(%x%x%x%x%x%x%x%x)")
	return color and LINK_QUALITY[color:lower()]
end

function ns.ItemButtonLevel(link)
	local name, _, quality, itemLevel, _, _, _, _, equipLoc = GetItemInfo(link)
	if not name then
		return nil, ns.LinkQuality(link), true
	end
	if NON_GEAR_SLOTS[equipLoc] or not itemLevel or itemLevel <= 1 then
		return nil, quality
	end
	return itemLevel, quality
end

local scanTip = CreateFrame("GameTooltip", ADDON_NAME .. "BagScanTooltip", nil, "GameTooltipTemplate")
local SCAN_LEFT = scanTip:GetName() .. "TextLeft"
local SCAN_RIGHT = scanTip:GetName() .. "TextRight"
local RED_CODE = RED_FONT_COLOR_CODE
local tooltipCache = {}
local unusableCache = {}
local searchCache = {}
local scanLines = {}
local uncertain = false

local function isRedLine(line)
	if not line or not line:IsShown() then
		return false
	end
	local text = line:GetText()
	if not text or text == "" then
		return false
	end
	if text:find(RED_CODE, 1, true) then
		return true
	end
	local r, g, b = line:GetTextColor()
	return r > 0.9 and g < 0.2 and b < 0.2
end

local function scanItem(itemId)
	local info = tooltipCache[itemId]
	if info then
		return info
	end
	scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	scanTip:SetHyperlink("item:" .. itemId)
	local lines = scanTip:NumLines()
	if lines < 2 then
		scanTip:Hide()
		return nil
	end

	local bind, red = nil, false
	local count = 0
	for i = 1, lines do
		local left, right = _G[SCAN_LEFT .. i], _G[SCAN_RIGHT .. i]
		local leftText = left:GetText()
		if leftText then
			if i <= 3 and not bind then
				bind = BIND_TEXTS[leftText]
			end
			count = count + 1
			scanLines[count] = leftText
		end
		if right and right:IsShown() then
			local rightText = right:GetText()
			if rightText then
				count = count + 1
				scanLines[count] = rightText
			end
		end
		if i > 1 and not red then
			red = isRedLine(left) or isRedLine(right)
		end
	end
	scanTip:Hide()

	info = { text = concat(scanLines, "\n", 1, count):lower(), bind = bind, red = red }
	wipe(scanLines)
	tooltipCache[itemId] = info
	return info
end

local weaponClass, armorClass, questClass
local armorTypes, weaponTypes = {}, {}

local function buildItemClasses()
	local classes = { GetAuctionItemClasses() }
	weaponClass, armorClass, questClass = classes[1], classes[2], classes[12]
	local _, cloth, leather, mail, plate = GetAuctionItemSubClasses(2)
	armorTypes[cloth], armorTypes[leather], armorTypes[mail], armorTypes[plate] = "cloth", "leather", "mail", "plate"
	local weapons = { GetAuctionItemSubClasses(1) }
	for i = 1, #WEAPON_KEYS do
		if WEAPON_KEYS[i] and weapons[i] then
			weaponTypes[weapons[i]] = WEAPON_KEYS[i]
		end
	end
end

local function lacksProficiency(itemType, subType, equipLoc)
	local class = ns.PLAYER_CLASS
	if equipLoc == "INVTYPE_SHIELD" then
		return not CLASS_SHIELD[class]
	end
	if itemType == armorClass and ARMOR_SLOTS[equipLoc] then
		local key = armorTypes[subType]
		if not key then
			return false
		end
		local required = CLASS_ARMOR[class] and CLASS_ARMOR[class][key]
		return not required or (required ~= true and UnitLevel("player") < required)
	elseif itemType == weaponClass and WEAPON_SLOTS[equipLoc] then
		local key = weaponTypes[subType]
		return key ~= nil and not (CLASS_WEAPONS[class] and CLASS_WEAPONS[class][key])
	end
	return false
end

function BagItems.IsUnusable(itemId)
	local cached = unusableCache[itemId]
	if cached ~= nil then
		return cached
	end
	local name, _, _, _, minLevel, itemType, subType, _, equipLoc = GetItemInfo(itemId)
	if not name then
		return false
	end
	if not armorClass then
		buildItemClasses()
	end

	local unusable
	if lacksProficiency(itemType, subType, equipLoc) or (minLevel and minLevel > UnitLevel("player")) then
		unusable = true
	else
		local info = scanItem(itemId)
		if not info then
			return false
		end
		unusable = info.red
	end
	unusableCache[itemId] = unusable
	return unusable
end

function BagItems.ResetScans()
	wipe(unusableCache)
	wipe(tooltipCache)
end

local function itemRecord(itemId)
	local record = searchCache[itemId]
	if not record then
		local name, _, quality, level, _, itemType, subType, _, equipLoc = GetItemInfo(itemId)
		if not name then
			return nil
		end
		if not armorClass then
			buildItemClasses()
		end
		name = name:lower()
		local types = (itemType .. " " .. subType .. " " .. (_G[equipLoc] or "")):lower()
		record = {
			name = name,
			types = types,
			text = name .. " " .. types,
			quality = quality,
			level = level,
			quest = itemType == questClass,
		}
		searchCache[itemId] = record
	end
	return record
end

local function qualityByName(value)
	for i = 0, #QUALITY_NAMES - 1 do
		local localized = _G["ITEM_QUALITY" .. i .. "_DESC"]
		if
			QUALITY_NAMES[i + 1]:sub(1, #value) == value or (localized and localized:lower():sub(1, #value) == value)
		then
			return i
		end
	end
end

local function equipmentSetItems(value)
	local items = {}
	for i = 1, GetNumEquipmentSets() do
		local name = GetEquipmentSetInfo(i)
		if name and name:lower():find(value, 1, true) then
			local ids = GetEquipmentSetItemIDs(name)
			if ids then
				for _, id in pairs(ids) do
					if id > 1 then
						items[id] = true
					end
				end
			end
		end
	end
	return items
end

local function parseTerm(word)
	local negate = false
	if word:sub(1, 1) == "!" then
		negate = true
		word = word:sub(2)
	end
	if word == "" then
		return nil
	end

	local term = { negate = negate }
	local key, op, value = word:match("^(%a+)([:=<>]=?)(.+)$")
	key = key and SEARCH_KEYS[key]
	if key then
		term.kind, term.op, term.value = key, op, value
		if key == "quality" or key == "level" then
			term.number = tonumber(value) or (key == "quality" and qualityByName(value)) or nil
			if not term.number then
				return nil
			end
		elseif key == "set" then
			term.items = equipmentSetItems(value)
		end
	elseif SEARCH_KEYWORDS[word] then
		term.kind, term.value = "bind", SEARCH_KEYWORDS[word]
	else
		term.kind, term.value = "text", word
	end
	return term
end

function BagItems.CompileSearch(text)
	local groups = {}
	for part in (text .. "|"):gmatch("([^|]*)|") do
		local group = {}
		for word in part:gmatch("[^%s&]+") do
			local term = parseTerm(word)
			if term then
				group[#group + 1] = term
			end
		end
		if #group > 0 then
			groups[#groups + 1] = group
		end
	end
	return #groups > 0 and groups or nil
end

local function compareNumber(value, op, number)
	if not value then
		return false
	elseif op == ">" then
		return value > number
	elseif op == "<" then
		return value < number
	elseif op == ">=" then
		return value >= number
	elseif op == "<=" then
		return value <= number
	end
	return value == number
end

local function matchTerm(term, itemId, record)
	local kind, value = term.kind, term.value
	local result
	if kind == "text" then
		result = record.text:find(value, 1, true) ~= nil
	elseif kind == "name" then
		result = record.name:find(value, 1, true) ~= nil
	elseif kind == "type" then
		result = record.types:find(value, 1, true) ~= nil
	elseif kind == "quality" then
		result = compareNumber(record.quality, term.op, term.number)
	elseif kind == "level" then
		result = compareNumber(record.level, term.op, term.number)
	elseif kind == "set" then
		result = term.items[itemId] == true
	else
		local info = scanItem(itemId)
		if not info then
			uncertain = true
			result = kind == "bind" and value == "quest" and record.quest
		elseif kind == "tooltip" then
			result = info.text:find(value, 1, true) ~= nil
		else
			result = info.bind == value or (value == "quest" and record.quest)
		end
	end
	if term.negate then
		return not result
	end
	return result and true or false
end

function BagItems.Matches(query, itemId)
	local record = itemRecord(itemId)
	if not record then
		return false, true
	end
	uncertain = false
	for i = 1, #query do
		local group = query[i]
		local matched = true
		for j = 1, #group do
			if not matchTerm(group[j], itemId, record) then
				matched = false
				break
			end
		end
		if matched then
			return true, uncertain
		end
	end
	return false, uncertain
end
