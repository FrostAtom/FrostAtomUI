local _, ns = ...
local L = ns.L

local strlower, strmatch = string.lower, string.match
local sort = table.sort
local abs = math.abs
local InCombatLockdown = InCombatLockdown
local GetActionInfo, PickupAction, PlaceAction, ClearCursor, GetCursorInfo =
	GetActionInfo, PickupAction, PlaceAction, ClearCursor, GetCursorInfo
local GetBindingAction, SetBinding = GetBindingAction, SetBinding

local Macros = ns:GetModule("Macros")

local Transfer = ns:NewModule("Transfer")
ns.Transfer = Transfer

local EXPORT_PREFIX = "FAUIT1:"
local ACTION_SLOTS = 120
local MODIFIERS = { "", "ALT-", "CTRL-", "SHIFT-", "ALT-CTRL-", "ALT-SHIFT-", "CTRL-SHIFT-", "ALT-CTRL-SHIFT-" }
local MACRO_SCOPES = { "account", "char", "gameAccount", "gameChar" }

Transfer.CATEGORIES = {
	{
		key = "macros",
		label = "Macros",
		desc = "Game and unlimited macros of the account and the character. Macros that already exist are not duplicated.",
	},
	{
		key = "actions",
		label = "Action bars",
		desc = "Spells, items, macros, mounts and equipment sets on every action bar slot. What the character does not have is left empty.",
	},
	{
		key = "bindings",
		label = "Key bindings",
		desc = "Every key binding, including keys bound to action buttons, spells and macros. Replaces all current bindings.",
	},
	{
		key = "interface",
		label = "Interface options",
		cvars = true,
		desc = "Game options: combat text, names, nameplates, status text, auto loot and the rest of the Interface options.",
	},
	{
		key = "camera",
		label = "Camera and mouse",
		cvars = true,
		desc = "Camera distance, speed and smoothing, mouse speed and inversion.",
	},
	{
		key = "graphics",
		label = "Graphics",
		cvars = true,
		desc = "Video options except resolution, window mode and graphics API. Some take effect only after a client restart.",
	},
	{
		key = "sound",
		label = "Sound",
		cvars = true,
		desc = "Volumes and sound options except the output device.",
	},
	{
		key = "chat",
		label = "Chat windows",
		desc = "Chat tabs with their message types, channels, font size and background, the joined channels and the chat colors.",
	},
	{
		key = "friends",
		label = "Friends",
		desc = "Friends with their notes. Only adds friends, nobody is removed.",
	},
	{
		key = "ignore",
		label = "Ignore list",
		desc = "Ignored players. Only adds players, nobody is removed.",
	},
}

local function exportSelection()
	local saved = ns.db.transfer or {}
	ns.db.transfer = saved
	return saved
end

function Transfer.IsExported(key)
	return exportSelection()[key] ~= false
end

function Transfer.SetExported(key, value)
	if value then
		exportSelection()[key] = nil
	else
		exportSelection()[key] = false
	end
end

local function macroRef(defs, scope, entry)
	local ref = type(entry) == "table" and "v" .. entry.id or "g" .. entry
	if not defs[ref] then
		defs[ref] = Macros.ExportItem(scope, entry)
	end
	return ref
end

local function gameMacroRef(defs, index)
	local id = Macros.StubOf(select(3, GetMacroInfo(index)))
	local macro = id and Macros.FindById(id)
	if macro then
		return macroRef(defs, Macros.ScopeOf(macro), macro)
	end
	return macroRef(defs, index > Macros.MAX_ACCOUNT and "gameChar" or "gameAccount", index)
end

local function addKeys(bindings, seen, command, ...)
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		if key and not seen[key] then
			seen[key] = true
			bindings[#bindings + 1] = { key, command }
		end
	end
end

local function currentBindings()
	local bindings, seen = {}, {}
	for i = 1, GetNumBindings() do
		addKeys(bindings, seen, GetBinding(i))
	end
	for _, modifier in ipairs(MODIFIERS) do
		for _, key in ipairs(ns.TransferBindingKeys) do
			local combo = modifier .. key
			local action = GetBindingAction(combo)
			if action and action ~= "" then
				addKeys(bindings, seen, action, combo)
			end
		end
	end
	return bindings
end

local function sameValue(a, b)
	if a == b then
		return true
	end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and y ~= nil and abs(x - y) < 0.0001
end

local function readCVar(name)
	local ok, value = pcall(GetCVar, name)
	local okDefault, default = pcall(GetCVarDefault, name)
	if ok and okDefault and value ~= nil then
		return value, default
	end
end

local function validColor(color)
	return type(color) == "table" and tonumber(color[1]) and tonumber(color[2]) and tonumber(color[3])
end

local function serverChannels()
	local channels = {}
	for _, name in ipairs({ EnumerateServerChannels() }) do
		channels[strlower(name)] = true
	end
	return channels
end

local function channelNames(...)
	local names = {}
	for i = 1, select("#", ...), 2 do
		names[#names + 1] = (select(i, ...))
	end
	return names
end

local exporters = {}

function exporters.macros(data)
	local refs = {}
	for _, scope in ipairs(MACRO_SCOPES) do
		local entries = scope:find("^game") and Macros.GameIndices(scope, {}) or Macros.GetList(scope) or {}
		for i = 1, #entries do
			refs[#refs + 1] = macroRef(data.macroDefs, scope, entries[i])
		end
	end
	return refs
end

function exporters.actions(data)
	local actions = {}
	for slot = 1, ACTION_SLOTS do
		local kind, id, subType, spellId = GetActionInfo(slot)
		if kind == "spell" then
			actions[slot] = { kind, spellId }
		elseif kind == "companion" then
			actions[slot] = { kind, spellId, subType }
		elseif kind == "item" or kind == "equipmentset" then
			actions[slot] = { kind, id }
		elseif kind == "macro" then
			actions[slot] = { kind, gameMacroRef(data.macroDefs, id) }
		end
	end
	return actions
end

function exporters.bindings(data)
	local bindings = currentBindings()
	for _, binding in ipairs(bindings) do
		local id = Macros.CommandId(binding[2])
		local macro = id and Macros.FindById(id)
		if macro then
			macroRef(data.macroDefs, Macros.ScopeOf(macro), macro)
		end
	end
	return bindings
end

local function exportCVars(_, group)
	local values = {}
	for _, name in ipairs(ns.TransferCVars[group]) do
		local value, default = readCVar(name)
		if value and not sameValue(value, default) then
			values[name] = value
		end
	end
	return values
end

function exporters.chat()
	local windows = {}
	for id = 1, NUM_CHAT_WINDOWS do
		local name, size, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(id)
		local window = {
			name = name,
			size = size,
			color = { r, g, b, alpha },
			shown = shown and true or nil,
			locked = locked and true or nil,
			docked = docked,
			uninteractable = uninteractable and true or nil,
			messages = { GetChatWindowMessages(id) },
			channels = channelNames(GetChatWindowChannels(id)),
		}
		local point, x, y = GetChatWindowSavedPosition(id)
		if point then
			window.position = { point, x, y }
		end
		local width, height = GetChatWindowSavedDimensions(id)
		if width then
			window.dimensions = { width, height }
		end
		windows[id] = window
	end

	local colors = {}
	for chatType, info in pairs(ChatTypeInfo) do
		if not strmatch(chatType, "^CHANNEL%d") then
			colors[chatType] = { info.r, info.g, info.b }
		end
	end

	local channels, channelColors = {}, {}
	for name, color in pairs(ns.db.channel_colors or {}) do
		channelColors[name] = { color.r, color.g, color.b }
	end
	local server = serverChannels()
	local list = { GetChannelList() }
	for i = 1, #list, 2 do
		local name = list[i + 1]
		local info = ChatTypeInfo["CHANNEL" .. list[i]]
		if info then
			channelColors[name] = { info.r, info.g, info.b }
		end
		if not server[strlower(name)] then
			channels[#channels + 1] = name
		end
	end

	return { windows = windows, colors = colors, channels = channels, channelColors = channelColors }
end

function exporters.friends()
	local friends = {}
	for i = 1, GetNumFriends() do
		local name, _, _, _, _, _, note = GetFriendInfo(i)
		if name then
			friends[#friends + 1] = { name, note }
		end
	end
	return friends
end

function exporters.ignore()
	local names = {}
	for i = 1, GetNumIgnores() do
		local name = GetIgnoreName(i)
		if name and name ~= UNKNOWN then
			names[#names + 1] = name
		end
	end
	return names
end

function Transfer.Export()
	local data = {
		version = 1,
		character = UnitName("player") .. " - " .. GetRealmName(),
		class = ns.PLAYER_CLASS,
		macroDefs = {},
	}
	local selected = false
	for _, category in ipairs(Transfer.CATEGORIES) do
		if Transfer.IsExported(category.key) then
			local exporter = category.cvars and exportCVars or exporters[category.key]
			data[category.key] = exporter(data, category.key)
			selected = true
		end
	end
	if not selected then
		return nil, L["nothing selected to copy"]
	end
	if not next(data.macroDefs) then
		data.macroDefs = nil
	end
	return EXPORT_PREFIX .. ns.Encode(ns.Serialize(data))
end

function Transfer.Decode(text)
	text = text and strtrim(text)
	if not text or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return nil, L["not a FrostAtom UI settings string"]
	end
	local body, err = ns.Decode(text:sub(#EXPORT_PREFIX + 1))
	if not body then
		return nil, err
	end
	local data = ns.Deserialize(body)
	if type(data) ~= "table" then
		return nil, L["malformed settings string"]
	end
	return data
end

function Transfer.Count(data, key)
	local value = data[key]
	if type(value) ~= "table" then
		return nil
	end
	local count = 0
	if key == "chat" then
		for _, window in pairs(type(value.windows) == "table" and value.windows or {}) do
			if type(window) == "table" and (window.shown or window.docked) then
				count = count + 1
			end
		end
	else
		for _ in pairs(value) do
			count = count + 1
		end
	end
	return count
end

local importers = {}

function importers.macros(refs, context)
	local items, itemRefs = {}, {}
	for _, ref in ipairs(refs) do
		local item = context.defs[ref]
		if item then
			items[#items + 1] = item
			itemRefs[#items] = ref
		end
	end
	local entries = {}
	local imported = Macros.Import(items, entries)
	for i, ref in ipairs(itemRefs) do
		if type(entries[i]) == "table" then
			context.entries[ref] = entries[i]
		end
	end
	return imported, #items - imported
end

local function resolveMacro(context, ref)
	local entry = context.entries[ref]
	if entry then
		return entry
	end
	local item = context.defs[ref]
	return item and Macros.Match(item)
end

local function spellBook()
	local byId, byName = {}, {}
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for index = offset + 1, offset + count do
			local link = GetSpellLink(index, BOOKTYPE_SPELL)
			local id = link and tonumber(strmatch(link, "spell:(%d+)"))
			if id then
				byId[id] = index
			end
			local name = GetSpellName(index, BOOKTYPE_SPELL)
			if name then
				byName[name] = index
			end
		end
	end
	return byId, byName
end

local function companions(kind)
	local indices = {}
	for index = 1, GetNumCompanions(kind) do
		local _, _, spellId = GetCompanionInfo(kind, index)
		if spellId then
			indices[spellId] = index
		end
	end
	return indices
end

function importers.actions(actions, context)
	local byId, byName = spellBook()
	local companionIndices = { MOUNT = companions("MOUNT"), CRITTER = companions("CRITTER") }
	local applied, skipped = 0, 0
	for slot = 1, ACTION_SLOTS do
		local action = actions[slot]
		ClearCursor()
		if type(action) == "table" then
			local kind, value, subType = action[1], action[2], action[3]
			if kind == "spell" and tonumber(value) then
				local index = byId[value] or byName[GetSpellInfo(value) or ""]
				if index then
					PickupSpell(index, BOOKTYPE_SPELL)
				end
			elseif kind == "companion" and companionIndices[subType] then
				local index = companionIndices[subType][value]
				if index then
					PickupCompanion(subType, index)
				end
			elseif kind == "item" and tonumber(value) then
				PickupItem(value)
			elseif kind == "equipmentset" and type(value) == "string" then
				if GetEquipmentSetInfoByName(value) then
					PickupEquipmentSetByName(value)
				end
			elseif kind == "macro" then
				local entry = resolveMacro(context, value)
				if type(entry) == "table" then
					Macros.PlaceOnBar(entry)
				elseif entry then
					PickupMacro(entry)
				end
			end
		end
		if GetCursorInfo() then
			PlaceAction(slot)
			applied = applied + 1
		else
			if action then
				skipped = skipped + 1
			end
			if GetActionInfo(slot) then
				PickupAction(slot)
			end
		end
		ClearCursor()
	end
	return applied, skipped
end

function importers.bindings(bindings, context)
	if #bindings == 0 then
		return 0, 0
	end
	for _, binding in ipairs(currentBindings()) do
		SetBinding(binding[1])
	end
	local applied, skipped = 0, 0
	for _, binding in ipairs(bindings) do
		local key, command = type(binding) == "table" and binding[1], type(binding) == "table" and binding[2]
		if type(key) == "string" and type(command) == "string" then
			local id = Macros.CommandId(command)
			if id then
				local macro = resolveMacro(context, "v" .. id)
				command = type(macro) == "table" and Macros.Command(macro) or nil
			end
			if command and SetBinding(key, command) then
				applied = applied + 1
			else
				skipped = skipped + 1
			end
		end
	end
	SaveBindings(GetCurrentBindingSet())
	return applied, skipped
end

local function importCVars(values, _, group)
	local applied = 0
	for _, name in ipairs(ns.TransferCVars[group]) do
		local value, default = readCVar(name)
		local wanted = type(values[name]) == "string" and values[name] or default
		if value and wanted and not sameValue(value, wanted) and pcall(SetCVar, name, wanted) then
			applied = applied + 1
		end
	end
	return applied, 0
end

local pendingChannels = {}

local function hasChannel(chatFrame, name)
	for _, channel in pairs(chatFrame.channelList) do
		if strlower(channel) == name then
			return true
		end
	end
end

local function onChannelNotice(_, message, _, _, _, _, _, _, _, channel)
	if message ~= "YOU_JOINED" or type(channel) ~= "string" then
		return
	end
	local key = strlower(channel)
	local ids = pendingChannels[key]
	if not ids then
		return
	end
	pendingChannels[key] = nil
	for _, id in ipairs(ids) do
		local chatFrame = _G["ChatFrame" .. id]
		if not hasChannel(chatFrame, key) then
			ChatFrame_AddChannel(chatFrame, channel)
		end
	end
	if not next(pendingChannels) then
		Transfer:UnregisterEvent("CHAT_MSG_CHANNEL_NOTICE", onChannelNotice)
	end
end

local function windowsWithChannel(windows, key)
	local ids = {}
	for id = 1, NUM_CHAT_WINDOWS do
		local window = windows[id]
		if type(window) == "table" and type(window.channels) == "table" then
			for _, channel in ipairs(window.channels) do
				if type(channel) == "string" and strlower(channel) == key then
					ids[#ids + 1] = id
					break
				end
			end
		end
	end
	return ids
end

local function joinChannels(channels, windows)
	local joined = {}
	local list = { GetChannelList() }
	for i = 2, #list, 2 do
		joined[strlower(list[i])] = true
	end
	local server = serverChannels()
	for _, name in ipairs(channels) do
		local key = type(name) == "string" and strlower(name)
		if key and not joined[key] and not server[key] then
			joined[key] = true
			local ids = windowsWithChannel(windows, key)
			JoinPermanentChannel(name, nil, ids[1] or DEFAULT_CHAT_FRAME:GetID())
			if #ids > 0 then
				pendingChannels[key] = ids
				Transfer:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", onChannelNotice)
			end
		end
	end
end

local function applyWindow(id, window)
	local chatFrame = _G["ChatFrame" .. id]
	if type(window.name) == "string" then
		SetChatWindowName(id, window.name)
	end
	local size = tonumber(window.size)
	if size and size > 0 then
		FCF_SetChatWindowFontSize(nil, chatFrame, size)
	end
	local color = window.color
	if validColor(color) then
		SetChatWindowColor(id, color[1], color[2], color[3])
		SetChatWindowAlpha(id, tonumber(color[4]) or DEFAULT_CHATFRAME_ALPHA)
	end
	SetChatWindowLocked(id, window.locked and 1 or nil)
	SetChatWindowUninteractable(id, window.uninteractable and 1 or nil)
	SetChatWindowShown(id, window.shown and 1 or nil)
	SetChatWindowDocked(id, tonumber(window.docked))
	local position, dimensions = window.position, window.dimensions
	if id ~= 1 and type(position) == "table" and type(position[1]) == "string" then
		SetChatWindowSavedPosition(id, position[1], tonumber(position[2]) or 0, tonumber(position[3]) or 0)
	end
	if id ~= 1 and type(dimensions) == "table" and tonumber(dimensions[1]) and tonumber(dimensions[2]) then
		SetChatWindowSavedDimensions(id, dimensions[1], dimensions[2])
	end

	ChatFrame_RemoveAllMessageGroups(chatFrame)
	if type(window.messages) == "table" then
		for _, group in ipairs(window.messages) do
			ChatFrame_AddMessageGroup(chatFrame, group)
		end
	end
	ChatFrame_RemoveAllChannels(chatFrame)
	if type(window.channels) == "table" then
		for _, channel in ipairs(window.channels) do
			if type(channel) == "string" then
				ChatFrame_AddChannel(chatFrame, channel)
			end
		end
	end
end

local function dockOrder(id)
	return (select(9, GetChatWindowInfo(id))) or NUM_CHAT_WINDOWS + id
end

local function applyChannelColors()
	local saved = ns.db.channel_colors or {}
	local list = { GetChannelList() }
	for i = 1, #list, 2 do
		local color = saved[list[i + 1]]
		if color then
			ChangeChatColor("CHANNEL" .. list[i], color.r, color.g, color.b)
		end
	end
end

function importers.chat(chat)
	local windows = type(chat.windows) == "table" and chat.windows or {}

	if type(chat.channelColors) == "table" then
		local saved = ns.db.channel_colors or {}
		ns.db.channel_colors = saved
		for name, color in pairs(chat.channelColors) do
			if type(name) == "string" and validColor(color) then
				saved[name] = { r = color[1], g = color[2], b = color[3] }
			end
		end
	end
	if type(chat.channels) == "table" then
		joinChannels(chat.channels, windows)
	end

	for id = 2, NUM_CHAT_WINDOWS do
		FCF_UnDockFrame(_G["ChatFrame" .. id])
	end
	local applied = 0
	for id = 1, NUM_CHAT_WINDOWS do
		if type(windows[id]) == "table" then
			applyWindow(id, windows[id])
			applied = applied + 1
		end
	end
	local order = {}
	for id = 1, NUM_CHAT_WINDOWS do
		order[id] = id
	end
	sort(order, function(a, b)
		return dockOrder(a) < dockOrder(b)
	end)
	for _, id in ipairs(order) do
		FloatingChatFrame_Update(id, 1)
	end

	if type(chat.colors) == "table" then
		for chatType, color in pairs(chat.colors) do
			if ChatTypeInfo[chatType] and validColor(color) then
				ChangeChatColor(chatType, color[1], color[2], color[3])
			end
		end
	end
	applyChannelColors()
	return applied, 0
end

local pendingNotes = {}

local function applyNotes()
	for i = 1, GetNumFriends() do
		local name = GetFriendInfo(i)
		local note = name and pendingNotes[strlower(name)]
		if note then
			pendingNotes[strlower(name)] = nil
			SetFriendNotes(i, note)
		end
	end
	if not next(pendingNotes) then
		Transfer:UnregisterEvent("FRIENDLIST_UPDATE", applyNotes)
	end
end

function importers.friends(friends)
	local known = {}
	for i = 1, GetNumFriends() do
		local name = GetFriendInfo(i)
		if name then
			known[strlower(name)] = true
		end
	end
	known[strlower(UnitName("player"))] = true
	local applied, skipped = 0, 0
	for _, friend in ipairs(friends) do
		local name, note = type(friend) == "table" and friend[1], type(friend) == "table" and friend[2]
		if type(name) == "string" and name ~= "" then
			local key = strlower(name)
			if type(note) == "string" and note ~= "" then
				pendingNotes[key] = note
			end
			if known[key] then
				skipped = skipped + 1
			else
				known[key] = true
				AddFriend(name)
				applied = applied + 1
			end
		end
	end
	pendingNotes[strlower(UnitName("player"))] = nil
	if next(pendingNotes) then
		Transfer:RegisterEvent("FRIENDLIST_UPDATE", applyNotes)
		applyNotes()
	end
	return applied, skipped
end

function importers.ignore(names)
	local known = {}
	for i = 1, GetNumIgnores() do
		local name = GetIgnoreName(i)
		if name then
			known[strlower(name)] = true
		end
	end
	known[strlower(UnitName("player"))] = true
	local applied, skipped = 0, 0
	for _, name in ipairs(names) do
		if type(name) == "string" and name ~= "" then
			if known[strlower(name)] then
				skipped = skipped + 1
			else
				known[strlower(name)] = true
				AddIgnore(name)
				applied = applied + 1
			end
		end
	end
	return applied, skipped
end

function Transfer.Import(data, selected)
	if InCombatLockdown() then
		ns.Print(L["cannot import settings in combat"])
		return false
	end
	local defs = {}
	if type(data.macroDefs) == "table" then
		for ref, item in pairs(data.macroDefs) do
			defs[ref] = Macros.Sanitize(item)
		end
	end
	local context = { defs = defs, entries = {} }
	ns.Print(L["settings imported from %s:"], type(data.character) == "string" and data.character or "?")
	for _, category in ipairs(Transfer.CATEGORIES) do
		if selected[category.key] and type(data[category.key]) == "table" then
			local importer = category.cvars and importCVars or importers[category.key]
			local ok, applied, skipped = xpcall(function()
				return importer(data[category.key], context, category.key)
			end, geterrorhandler())
			if ok and skipped > 0 then
				ns.Print(L["%s: %d, skipped %d"], L[category.label], applied, skipped)
			elseif ok then
				ns.Print(L["%s: %d"], L[category.label], applied)
			end
		end
	end
	return true
end
