local _, ns = ...
local L = ns.L

local strbyte, strsub, strfind, strmatch, strlower, strupper, strgsub =
	string.byte, string.sub, string.find, string.match, string.lower, string.upper, string.gsub
local tconcat, pairs, tonumber, type, loadstring = table.concat, pairs, tonumber, type, loadstring
local GetSpellInfo, GetSpellName, GetItemInfo, GetItemCount, IsEquippedItem =
	GetSpellInfo, GetSpellName, GetItemInfo, GetItemCount, IsEquippedItem
local GetContainerItemLink, GetInventoryItemLink = GetContainerItemLink, GetInventoryItemLink
local GetNumCompanions, GetCompanionInfo, GetModifiedClick = GetNumCompanions, GetCompanionInfo, GetModifiedClick
local GetEquipmentSetInfoByName, GetClickFrame, GetTime = GetEquipmentSetInfoByName, GetClickFrame, GetTime

local Parser = {}
ns.MacroParser = Parser

local BYTE_SPACE, BYTE_TAB = strbyte(" "), strbyte("\t")
local BYTE_SLASH, BYTE_HASH, BYTE_DASH = strbyte("/"), strbyte("#"), strbyte("-")
local BYTE_OPEN, BYTE_SEMICOLON = strbyte("["), strbyte(";")
local BYTE_PIPE, BYTE_C, BYTE_R = strbyte("|"), strbyte("c"), strbyte("r")

Parser.RUN_LIMIT = 1023
Parser.MACRO_LIMIT = 255

Parser.ERROR, Parser.WARNING, Parser.INFO = 1, 2, 3

local COLORS = {
	secure = "ffd200",
	slash = "7fc4ff",
	chat = "9a9a9a",
	emote = "e0a870",
	meta = "c792ea",
	comment = "6a9955",
	punct = "8c8c8c",
	condition = "4fc1ff",
	arg = "ce9178",
	unit = "f48fb1",
	item = "a6e3a1",
	missing = "ff9f40",
	error = "ff4d4d",
	lua = "dcdcaa",
}
Parser.COLORS = COLORS

-- stylua: ignore
local SECURE_COMMANDS = {
	STARTATTACK = "unit", STOPATTACK = "none", CAST = "action", USE = "action",
	CASTRANDOM = "actions", USERANDOM = "actions", CASTSEQUENCE = "sequence",
	STOPCASTING = "none", CANCELAURA = "text", CANCELFORM = "none", EQUIP = "item",
	EQUIP_TO_SLOT = "slotitem", CHANGEACTIONBAR = "page", SWAPACTIONBAR = "pages",
	TARGET = "unit", TARGET_EXACT = "unit", TARGET_NEAREST_ENEMY = "none",
	TARGET_NEAREST_ENEMY_PLAYER = "none", TARGET_NEAREST_FRIEND = "none",
	TARGET_NEAREST_FRIEND_PLAYER = "none", TARGET_NEAREST_PARTY = "none",
	TARGET_NEAREST_RAID = "none", CLEARTARGET = "none", TARGET_LAST_TARGET = "none",
	TARGET_LAST_ENEMY = "none", TARGET_LAST_FRIEND = "none", ASSIST = "unit", FOCUS = "unit",
	CLEARFOCUS = "none", CLEARMAINTANK = "none", MAINTANKON = "unit", MAINTANKOFF = "unit",
	CLEARMAINASSIST = "none", MAINASSISTON = "unit", MAINASSISTOFF = "unit", DUEL = "unit",
	DUEL_CANCEL = "none", PET_ATTACK = "unit", PET_FOLLOW = "none", PET_STAY = "none",
	PET_PASSIVE = "none", PET_DEFENSIVE = "none", PET_AGGRESSIVE = "none",
	PET_AUTOCASTON = "text", PET_AUTOCASTOFF = "text", PET_AUTOCASTTOGGLE = "text",
	STOPMACRO = "none", CLICK = "click",
}

-- stylua: ignore
local OPTION_COMMANDS = {
	DISMOUNT = "none", LEAVEVEHICLE = "none", EQUIP_SET = "equipset",
	SET_TITLE = "text", USE_TALENT_SPEC = "spec",
}

local NO_ARGS = "noargs"

-- stylua: ignore
local CONDITIONS = {
	[""] = NO_ARGS, combat = NO_ARGS, exists = NO_ARGS, help = NO_ARGS, harm = NO_ARGS,
	party = NO_ARGS, raid = NO_ARGS, dead = NO_ARGS, flyable = NO_ARGS, indoors = NO_ARGS,
	outdoors = NO_ARGS, swimming = NO_ARGS, flying = NO_ARGS, mounted = NO_ARGS,
	stealth = NO_ARGS, vehicleui = NO_ARGS, unithasvehicleui = NO_ARGS,
	group = "group", stance = "number", form = "number", pet = "any",
	modifier = "modifier", mod = "modifier", button = "any", btn = "any",
	actionbar = "page", bar = "page", bonusbar = "number", equipped = "equip", worn = "equip",
	channeling = "any", spec = "spec", cursor = "cursor",
}

local CURSOR_TYPES = {
	item = true,
	money = true,
	spell = true,
	merchant = true,
	macro = true,
	guildbankmoney = true,
	equipmentset = true,
}

local MODIFIER_KEYS = {
	SHIFT = true,
	LSHIFT = true,
	RSHIFT = true,
	CTRL = true,
	LCTRL = true,
	RCTRL = true,
	ALT = true,
	LALT = true,
	RALT = true,
}

-- stylua: ignore
local INVENTORY_TYPES = {
	"INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_BODY", "INVTYPE_CHEST",
	"INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND",
	"INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPON", "INVTYPE_SHIELD", "INVTYPE_RANGED",
	"INVTYPE_CLOAK", "INVTYPE_2HWEAPON", "INVTYPE_BAG", "INVTYPE_TABARD", "INVTYPE_ROBE",
	"INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_AMMO",
	"INVTYPE_THROWN", "INVTYPE_RANGEDRIGHT", "INVTYPE_QUIVER", "INVTYPE_RELIC",
}

-- stylua: ignore
local UNIT_BASES = {
	player = true, target = true, focus = true, mouseover = true, pet = true, vehicle = true,
	none = true, npc = true,
}

local UNIT_INDEXED = { party = 4, partypet = 4, raid = 40, raidpet = 40, arena = 5, arenapet = 5, boss = 4 }

local RESET_WORDS = { target = true, combat = true, shift = true, ctrl = true, alt = true }

local COMMAND_REBUILD_INTERVAL = 2

local commands
local commandsBuiltAt = 0
local knownSpells
local equipNames

local function addSlashes(map, key, kind)
	local i = 1
	local slash = _G["SLASH_" .. key .. i]
	while slash do
		local upper = strupper(slash)
		if not map[upper] then
			map[upper] = { kind = kind, key = key }
		end
		i = i + 1
		slash = _G["SLASH_" .. key .. i]
	end
end

local function buildCommands()
	local map = {}
	for key in pairs(SECURE_COMMANDS) do
		addSlashes(map, key, "secure")
	end
	for key in pairs(ChatTypeInfo) do
		addSlashes(map, key, "chat")
	end
	for key in pairs(SlashCmdList) do
		addSlashes(map, key, "slash")
	end
	local i, j = 1, 1
	local cmd = _G["EMOTE1_CMD1"]
	while i <= (MAXEMOTEINDEX or 0) do
		if cmd then
			local upper = strupper(cmd)
			if not map[upper] then
				map[upper] = { kind = "emote", key = _G["EMOTE" .. i .. "_TOKEN"] }
			end
		end
		j = j + 1
		cmd = _G["EMOTE" .. i .. "_CMD" .. j]
		if not cmd then
			i, j = i + 1, 1
			cmd = _G["EMOTE" .. i .. "_CMD" .. j]
		end
	end
	commands = map
	commandsBuiltAt = GetTime()
end

local function lookupCommand(command)
	local upper = strupper(command)
	if not commands then
		buildCommands()
	end
	local entry = commands[upper]
	if not entry and GetTime() - commandsBuiltAt > COMMAND_REBUILD_INTERVAL then
		buildCommands()
		entry = commands[upper]
	end
	return entry
end

local function addSpell(set, name, rank)
	if not name then
		return
	end
	local lower = strlower(name)
	set[lower] = true
	set[lower .. "()"] = true
	if rank and rank ~= "" then
		set[lower .. "(" .. strlower(rank) .. ")"] = true
	end
end

local function buildSpells()
	local set = {}
	for _, book in pairs({ "spell", "pet" }) do
		local i = 1
		while true do
			local name, rank = GetSpellName(i, book)
			if not name then
				break
			end
			addSpell(set, name, rank)
			i = i + 1
		end
	end
	for _, kind in pairs({ "MOUNT", "CRITTER" }) do
		for i = 1, GetNumCompanions(kind) do
			local _, _, spellId = GetCompanionInfo(kind, i)
			addSpell(set, spellId and GetSpellInfo(spellId))
		end
	end
	knownSpells = set
end

local function buildEquipNames()
	local set = {}
	for i = 1, #INVENTORY_TYPES do
		local token = INVENTORY_TYPES[i]
		set[strlower(token)] = true
		local text = _G[token]
		if type(text) == "string" then
			set[strlower(text)] = true
		end
	end
	local classes = { GetAuctionItemClasses() }
	for i = 1, #classes do
		set[strlower(classes[i])] = true
		local subclasses = { GetAuctionItemSubClasses(i) }
		for j = 1, #subclasses do
			set[strlower(subclasses[j])] = true
		end
	end
	equipNames = set
end

function Parser.InvalidateSpells()
	knownSpells = nil
end

local function isKnownSpell(name)
	if not knownSpells then
		buildSpells()
	end
	local plain = strgsub(name, "^!+", "")
	local lower = strlower(strgsub(plain, "%s*%(", "("))
	if knownSpells[lower] then
		return true
	end
	return GetSpellInfo(plain) ~= nil
end

local function isUnitToken(unit)
	local lower = strlower(unit)
	local prefix, digits, rest = strmatch(lower, "^(%a+)(%d+)(%a*)$")
	if prefix then
		local max = UNIT_INDEXED[prefix]
		local index = tonumber(digits)
		if not max or index < 1 or index > max then
			return false
		end
	else
		prefix, rest = lower, ""
		while not UNIT_BASES[prefix] do
			local stripped = strmatch(prefix, "^(%a+)target$")
			if not stripped then
				return false
			end
			prefix = stripped
		end
	end
	return (strgsub(rest, "target", "")) == ""
end

local result
local spans, issues

local function span(from, to, color)
	local count = #spans
	local last = spans[count]
	if last and from <= last[2] then
		from = last[2] + 1
	end
	if from > to then
		return
	end
	if last and last[2] == from - 1 and last[3] == color then
		last[2] = to
		return
	end
	spans[count + 1] = { from, to, color }
end

local lineNumber

local function issue(level, text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	issues[#issues + 1] = { line = lineNumber, level = level, text = text }
end

local function trimRange(text, from, to)
	while from <= to do
		local byte = strbyte(text, from)
		if byte ~= BYTE_SPACE and byte ~= BYTE_TAB then
			break
		end
		from = from + 1
	end
	while to >= from do
		local byte = strbyte(text, to)
		if byte ~= BYTE_SPACE and byte ~= BYTE_TAB then
			break
		end
		to = to - 1
	end
	return from, to
end

local function trimSpaces(text, from, to)
	while from <= to and strbyte(text, from) == BYTE_SPACE do
		from = from + 1
	end
	while to >= from and strbyte(text, to) == BYTE_SPACE do
		to = to - 1
	end
	return from, to
end

local function splitRanges(text, from, to, separator, handler)
	local start = from
	while start <= to + 1 do
		local stop = strfind(text, separator, start, true)
		if not stop or stop > to then
			stop = to + 1
		end
		handler(start, stop - 1)
		if stop <= to then
			span(stop, stop, COLORS.punct)
		end
		start = stop + 1
	end
end

local function checkModifier(value)
	local rest = strupper(value)
	local matched = false
	while rest ~= "" do
		local token = strmatch(rest, "^(%a+)")
		if not token or not MODIFIER_KEYS[token] then
			break
		end
		matched = true
		rest = strgsub(strsub(rest, #token + 1), "^%-", "")
	end
	if matched then
		return rest == ""
	end
	return GetModifiedClick(value) ~= nil
end

local function checkArgument(kind, name, value)
	if kind == "number" or kind == "page" then
		if not strfind(value, "^%d+$") then
			return L["[%s] expects a number, got %q"]:format(name, value)
		end
		if kind == "page" and (tonumber(value) < 1 or tonumber(value) > NUM_ACTIONBAR_PAGES) then
			return L["[%s] expects an action bar page 1-%d"]:format(name, NUM_ACTIONBAR_PAGES)
		end
	elseif kind == "spec" then
		if value ~= "1" and value ~= "2" then
			return L["[%s] expects talent group 1 or 2"]:format(name)
		end
	elseif kind == "group" then
		if value ~= "party" and value ~= "raid" then
			return L["[group] expects party or raid (lowercase)"]
		end
	elseif kind == "cursor" then
		if not CURSOR_TYPES[strlower(value)] then
			return L["unknown cursor type %q"]:format(value)
		end
	elseif kind == "modifier" then
		if not checkModifier(value) then
			return L["unknown modifier %q: use shift, ctrl, alt or a modified click action like SELFCAST"]:format(value)
		end
	elseif kind == "equip" then
		if not equipNames then
			buildEquipNames()
		end
		if not equipNames[strlower(value)] then
			return L["unknown item type %q"]:format(value)
		end
	end
end

local function parseCondition(text, from, to)
	from, to = trimSpaces(text, from, to)
	if from > to then
		return
	end
	if to - from + 1 >= 7 and strsub(text, from, from + 6) == "target=" then
		span(from, from + 6, COLORS.condition)
		local unitFrom, unitTo = trimSpaces(text, from + 7, to)
		span(unitFrom, unitTo, COLORS.unit)
		return strsub(text, unitFrom, unitTo)
	elseif strbyte(text, from) == strbyte("@") then
		span(from, from, COLORS.unit)
		local unitFrom, unitTo = trimSpaces(text, from + 1, to)
		span(unitFrom, unitTo, COLORS.unit)
		return strsub(text, unitFrom, unitTo)
	end

	local nameFrom = from
	if to - from + 1 > 2 and strsub(text, from, from + 1) == "no" then
		nameFrom = from + 2
	end
	local colon = strfind(text, ":", nameFrom, true)
	if colon and colon > to then
		colon = nil
	end
	local nameStart, nameEnd = trimSpaces(text, nameFrom, (colon or to + 1) - 1)
	local name = strsub(text, nameStart, nameEnd)
	local kind = CONDITIONS[name]
	if not kind then
		span(from, colon and colon - 1 or to, COLORS.error)
		local lower = strlower(name)
		if CONDITIONS[lower] then
			issue(
				Parser.ERROR,
				L["unknown condition [%s]: condition names are case-sensitive, write [%s]"],
				name,
				lower
			)
		else
			issue(
				Parser.ERROR,
				L["unknown condition [%s]: the game counts it as true and shows an error when the macro runs"],
				name
			)
		end
		if colon then
			span(colon, to, COLORS.error)
		end
		return
	end
	span(from, colon and colon - 1 or to, COLORS.condition)
	if not colon then
		return
	end
	span(colon, colon, COLORS.punct)
	if kind == NO_ARGS then
		span(colon + 1, to, COLORS.error)
		issue(Parser.WARNING, L["[%s] takes no arguments, they are ignored"], name)
		return
	end
	splitRanges(text, colon + 1, to, "/", function(argFrom, argTo)
		argFrom, argTo = trimSpaces(text, argFrom, argTo)
		if argFrom > argTo then
			return
		end
		local message = checkArgument(kind, name, strsub(text, argFrom, argTo))
		if message then
			span(argFrom, argTo, COLORS.error)
			issue(Parser.WARNING, message)
		else
			span(argFrom, argTo, COLORS.arg)
		end
	end)
end

local function parseGroup(text, from, to)
	local unit
	splitRanges(text, from, to, ",", function(condFrom, condTo)
		local target = parseCondition(text, condFrom, condTo)
		if target then
			unit = target
		end
	end)
	if unit and unit ~= "" then
		if #unit > 31 then
			issue(Parser.ERROR, L["unit %q is longer than 31 characters"], unit)
		elseif not isUnitToken(unit) then
			issue(Parser.INFO, L["%q is not a unit token, the game looks it up as a player name"], unit)
		end
	end
end

local function itemSlotAction(action)
	local bag, slot = strmatch(action, "^(%d+)%s+(%d+)$")
	if bag then
		return true, GetContainerItemLink(tonumber(bag), tonumber(slot)) ~= nil, bag
	end
	slot = strmatch(action, "^(%d+)$")
	if slot then
		return true, GetInventoryItemLink("player", tonumber(slot)) ~= nil
	end
	return false
end

local function checkItem(action, from, to, required)
	local isSlot, filled, bag = itemSlotAction(action)
	if isSlot then
		if filled then
			span(from, to, COLORS.item)
		else
			span(from, to, COLORS.missing)
			if bag then
				issue(Parser.WARNING, L["bag slot %s is empty"], action)
			else
				issue(Parser.WARNING, L["equipment slot %s is empty"], action)
			end
		end
		return true
	end
	if GetItemInfo(action) then
		if GetItemCount(action) > 0 or IsEquippedItem(action) then
			span(from, to, COLORS.item)
		else
			span(from, to, COLORS.missing)
			issue(Parser.WARNING, L["item %q is not in your bags"], action)
		end
		return true
	end
	if required then
		span(from, to, COLORS.error)
		issue(Parser.WARNING, L["unknown item %q (or it is not cached yet)"], action)
	end
	return false
end

local function checkAction(text, from, to)
	from, to = trimRange(text, from, to)
	if from > to then
		return
	end
	local action = strsub(text, from, to)
	if checkItem(action, from, to) then
		return
	end
	if isKnownSpell(action) then
		return
	end
	span(from, to, COLORS.error)
	issue(Parser.ERROR, L["unknown spell or item %q"], action)
end

local function checkSequence(text, from, to)
	from, to = trimRange(text, from, to)
	local resetFrom, resetTo = strfind(text, "^reset=[^%s]+", from)
	if resetTo and resetTo <= to then
		span(resetFrom, resetFrom + 5, COLORS.condition)
		splitRanges(text, resetFrom + 6, resetTo, "/", function(wordFrom, wordTo)
			local word = strlower(strsub(text, wordFrom, wordTo))
			if RESET_WORDS[word] or strfind(word, "^%d+$") then
				span(wordFrom, wordTo, COLORS.arg)
			else
				span(wordFrom, wordTo, COLORS.error)
				issue(
					Parser.WARNING,
					L["unknown reset condition %q: use seconds, target, combat, shift, ctrl or alt"],
					word
				)
			end
		end)
		from = resetTo + 1
	end
	splitRanges(text, from, to, ",", function(actionFrom, actionTo)
		checkAction(text, actionFrom, actionTo)
	end)
end

local function checkArgs(kind, text, from, to)
	local trimmedFrom, trimmedTo = trimRange(text, from, to)
	local value = strsub(text, trimmedFrom, trimmedTo)
	if kind == "action" then
		checkAction(text, from, to)
	elseif kind == "actions" then
		splitRanges(text, from, to, ",", function(actionFrom, actionTo)
			checkAction(text, actionFrom, actionTo)
		end)
	elseif kind == "sequence" then
		checkSequence(text, from, to)
	elseif kind == "item" then
		if value ~= "" then
			checkItem(value, trimmedFrom, trimmedTo, true)
		end
	elseif kind == "slotitem" then
		local slot, itemFrom = strmatch(value, "^(%d+)%s+()")
		if not slot then
			if value ~= "" then
				span(trimmedFrom, trimmedTo, COLORS.error)
				issue(Parser.ERROR, L["expected an equipment slot number and an item"])
			end
			return
		end
		span(trimmedFrom, trimmedFrom + #slot - 1, COLORS.arg)
		checkItem(strsub(value, itemFrom), trimmedFrom + itemFrom - 1, trimmedTo, true)
	elseif kind == "page" or kind == "pages" then
		local ok = kind == "page" and strfind(value, "^%d+$") or kind == "pages" and strfind(value, "^%d+%s+%d+$")
		if value == "" then
			return
		end
		if ok then
			span(trimmedFrom, trimmedTo, COLORS.arg)
		else
			span(trimmedFrom, trimmedTo, COLORS.error)
			issue(Parser.ERROR, L["expected action bar page numbers 1-%d"], NUM_ACTIONBAR_PAGES)
		end
	elseif kind == "unit" then
		span(trimmedFrom, trimmedTo, COLORS.unit)
	elseif kind == "click" then
		local name = strmatch(value, "^([^%s]+)")
		if not name then
			return
		end
		local frame = GetClickFrame(name)
		if frame and frame:IsObjectType("Button") then
			span(trimmedFrom, trimmedFrom + #name - 1, COLORS.arg)
		else
			span(trimmedFrom, trimmedFrom + #name - 1, COLORS.missing)
			issue(Parser.WARNING, L["button %q does not exist right now"], name)
		end
	elseif kind == "equipset" then
		if value == "" then
			return
		end
		if GetEquipmentSetInfoByName(value) then
			span(trimmedFrom, trimmedTo, COLORS.item)
		else
			span(trimmedFrom, trimmedTo, COLORS.missing)
			issue(Parser.WARNING, L["no equipment set named %q"], value)
		end
	elseif kind == "spec" then
		if value == "1" or value == "2" then
			span(trimmedFrom, trimmedTo, COLORS.arg)
		elseif value ~= "" then
			span(trimmedFrom, trimmedTo, COLORS.error)
			issue(Parser.ERROR, L["expected talent group 1 or 2"])
		end
	end
end

local function parseOptions(text, from, to, kind)
	local position = from
	while position <= to do
		local actionFrom = position
		local cursor = position
		local sawGroup = false
		while cursor <= to do
			local byte = strbyte(text, cursor)
			if byte == BYTE_OPEN then
				local skippedFrom, skippedTo = trimRange(text, actionFrom, cursor - 1)
				if skippedFrom <= skippedTo then
					span(skippedFrom, skippedTo, COLORS.error)
					issue(Parser.WARNING, L["text before a [condition] group is ignored"])
				end
				local close = strfind(text, "]", cursor + 1, true)
				if not close or close > to then
					span(cursor, to, COLORS.error)
					issue(Parser.ERROR, L["missing ] after ["])
					return
				end
				span(cursor, cursor, COLORS.punct)
				parseGroup(text, cursor + 1, close - 1)
				span(close, close, COLORS.punct)
				sawGroup = true
				cursor = close + 1
				actionFrom = cursor
			elseif byte == BYTE_SEMICOLON then
				break
			else
				cursor = cursor + 1
			end
		end
		checkArgs(kind, text, actionFrom, cursor - 1)
		if sawGroup and (kind == "action" or kind == "actions" or kind == "sequence") then
			local actionStart, actionEnd = trimRange(text, actionFrom, cursor - 1)
			if actionStart > actionEnd then
				issue(Parser.INFO, L["empty action after a condition: the command does nothing when it matches"])
			end
		end
		if cursor <= to then
			span(cursor, cursor, COLORS.punct)
		end
		position = cursor + 1
	end
end

local function checkLua(code, from, to)
	local _, err = loadstring(code, "macro")
	span(from, to, err and COLORS.error or COLORS.lua)
	if err then
		issue(Parser.ERROR, L["Lua error: %s"], (strgsub(err, '^%[string "macro"%]:%d+: ', "")))
	end
end

local function parseCommandLine(text, from, to)
	local commandTo = strfind(text, "[%s]", from) or to + 1
	if commandTo > to + 1 then
		commandTo = to + 1
	end
	commandTo = commandTo - 1
	local command = strsub(text, from, commandTo)
	local argsFrom = commandTo + 2

	local channel = strmatch(command, "^/(%d+)$")
	if channel then
		span(from, commandTo, COLORS.chat)
		span(argsFrom, to, COLORS.chat)
		return
	end

	local entry = lookupCommand(command)
	if not entry then
		span(from, to, COLORS.error)
		issue(Parser.ERROR, L["unknown command %s"], command)
		return
	end

	local key = entry.key
	if entry.kind == "secure" then
		span(from, commandTo, COLORS.secure)
		parseOptions(text, argsFrom, to, SECURE_COMMANDS[key])
	elseif entry.kind == "chat" then
		span(from, commandTo, COLORS.chat)
		span(argsFrom, to, COLORS.chat)
	elseif entry.kind == "emote" then
		span(from, commandTo, COLORS.emote)
	elseif key == "SCRIPT" then
		span(from, commandTo, COLORS.slash)
		if argsFrom <= to then
			checkLua(strsub(text, argsFrom, to), argsFrom, to)
		end
	elseif OPTION_COMMANDS[key] then
		span(from, commandTo, COLORS.slash)
		parseOptions(text, argsFrom, to, OPTION_COMMANDS[key])
	else
		span(from, commandTo, COLORS.slash)
	end
end

local function parseLine(text, from, to)
	local first = strbyte(text, from)
	if first == BYTE_SLASH then
		parseCommandLine(text, from, to)
	elseif first == BYTE_HASH then
		if strsub(text, from, from + 4) == "#show" then
			local wordTo = strfind(text, "[%s]", from) or to + 1
			wordTo = (wordTo > to + 1 and to + 1 or wordTo) - 1
			local word = strsub(text, from, wordTo)
			if word == "#show" or word == "#showtooltip" then
				span(from, wordTo, COLORS.meta)
				parseOptions(text, wordTo + 2, to, "action")
				return
			end
		end
		span(from, to, COLORS.comment)
	elseif first == BYTE_DASH then
		span(from, to, COLORS.comment)
	else
		span(from, to, COLORS.chat)
		if first == BYTE_SPACE or first == BYTE_TAB then
			issue(Parser.WARNING, L["the line starts with a space: the game sends it to chat as text"])
		else
			issue(Parser.WARNING, L["the line does not start with /: the game says it in chat"])
		end
	end
end

function Parser.Analyze(text, limit)
	result = { spans = {}, issues = {}, bytes = #text }
	spans, issues = result.spans, result.issues
	lineNumber = 0
	local position, length = 1, #text
	while position <= length do
		local stop = strfind(text, "[\r\n]", position) or length + 1
		lineNumber = lineNumber + 1
		if stop > position then
			parseLine(text, position, stop - 1)
			if stop - position > Parser.RUN_LIMIT - 40 then
				issue(
					Parser.ERROR,
					L["the line is %d bytes long, the game runs at most %d"],
					stop - position,
					Parser.RUN_LIMIT - 40
				)
			end
		end
		position = stop + 1
	end
	if limit and length > limit then
		lineNumber = nil
		issue(Parser.ERROR, L["%d of %d characters: the game macro cannot hold more"], length, limit)
	end
	local out = result
	result, spans, issues = nil, nil, nil
	return out
end

local function escaped(text, from, to)
	return (strgsub(strsub(text, from, to), "|", "||"))
end

function Parser.Render(text, spanList, cursor)
	local parts, count = {}, 0
	local outLength = 0
	local escapedCursor
	local position = 1

	local function emit(piece)
		count = count + 1
		parts[count] = piece
		outLength = outLength + #piece
	end

	local function emitText(from, to, allowEnd)
		if cursor and not escapedCursor and cursor >= from - 1 and (cursor < to or allowEnd and cursor == to) then
			local before = escaped(text, from, cursor)
			escapedCursor = outLength + #before
		end
		if from <= to then
			emit(escaped(text, from, to))
		end
	end

	for i = 1, #spanList do
		local item = spanList[i]
		local from, to = item[1], item[2]
		emitText(position, from - 1, true)
		emit("|cff" .. item[3])
		emitText(from, to, false)
		emit("|r")
		if cursor == to and not escapedCursor then
			escapedCursor = outLength
		end
		position = to + 1
	end
	emitText(position, #text, true)
	return tconcat(parts), escapedCursor or outLength
end

function Parser.Decode(value, cursor)
	local parts, count, rawLength = {}, 0, 0
	local rawCursor
	local position, length = 1, #value
	while position <= length do
		if cursor and not rawCursor and position - 1 >= cursor then
			rawCursor = rawLength
		end
		local piece, consumed
		if strbyte(value, position) == BYTE_PIPE then
			local nextByte = strbyte(value, position + 1)
			if nextByte == BYTE_PIPE then
				piece, consumed = "|", 2
			elseif nextByte == BYTE_C and strfind(value, "^%x%x%x%x%x%x%x%x", position + 2) then
				consumed = 10
			elseif nextByte == BYTE_R then
				consumed = 2
			else
				piece, consumed = "|", 1
			end
		else
			local stop = strfind(value, "|", position, true)
			stop = stop and stop - 1 or length
			if cursor and not rawCursor and cursor < stop then
				rawCursor = rawLength + cursor - position + 1
			end
			piece, consumed = strsub(value, position, stop), stop - position + 1
		end
		if piece then
			count = count + 1
			parts[count] = piece
			rawLength = rawLength + #piece
		end
		position = position + consumed
	end
	if cursor and not rawCursor then
		rawCursor = rawLength
	end
	return tconcat(parts), rawCursor
end

local function conditionKnown(condition)
	condition = strtrim(condition)
	if condition == "" or strfind(condition, "^target=") or strfind(condition, "^@") then
		return true
	end
	if #condition > 2 and strsub(condition, 1, 2) == "no" then
		condition = strsub(condition, 3)
	end
	return CONDITIONS[strtrim((strmatch(condition, "^([^:]*)")))] ~= nil
end

function Parser.OptionsValid(text)
	local rest = strgsub(text, "%[([^%]]*)%]", function(group)
		for condition in string.gmatch(group .. ",", "([^,]*),") do
			if not conditionKnown(condition) then
				return "["
			end
		end
		return ""
	end)
	return not strfind(rest, "[", 1, true)
end

function Parser.FirstAction(text)
	local position, length = 1, #text
	while position <= length do
		local stop = strfind(text, "[\r\n]", position) or length + 1
		local line = strsub(text, position, stop - 1)
		local show = strmatch(line, "^#showtooltip%s+(.+)$") or strmatch(line, "^#show%s+(.+)$")
		if show then
			return "action", show
		end
		local command, args = strmatch(line, "^(/[^%s]+)%s+(.+)$")
		if command then
			local entry = lookupCommand(command)
			local kind = entry and entry.kind == "secure" and SECURE_COMMANDS[entry.key]
			if kind == "action" or kind == "sequence" or kind == "actions" then
				return kind, args
			end
		end
		position = stop + 1
	end
end
