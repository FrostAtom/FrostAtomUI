local _, ns = ...
local L = ns.L

local strbyte, strgsub, strmatch, strlower, gmatch = string.byte, string.gsub, string.match, string.lower, string.gmatch
local tconcat, tremove, max = table.concat, table.remove, math.max
local InCombatLockdown = InCombatLockdown
local GetBindingKey, SetBinding, SetBindingClick, SaveBindings, GetCurrentBindingSet =
	GetBindingKey, SetBinding, SetBindingClick, SaveBindings, GetCurrentBindingSet
local GetMacroInfo, GetNumMacros, CreateMacro, EditMacro, DeleteMacro, PickupMacro =
	GetMacroInfo, GetNumMacros, CreateMacro, EditMacro, DeleteMacro, PickupMacro
local GetNumMacroIcons, GetMacroIconInfo = GetNumMacroIcons, GetMacroIconInfo

local Parser = ns.MacroParser

local Macros = ns:NewModule("Macros")
Macros.configKey = "macros"

local BUTTON_PREFIX = "FAMacro"
local CHAIN_RESERVE = 40
local STUB_LIMIT = 255
local STUB_NAME_LIMIT = 16
local BYTE_HASH, BYTE_DASH = strbyte("#"), strbyte("-")
local MAX_ACCOUNT = MAX_ACCOUNT_MACROS or 36
local MAX_CHARACTER = MAX_CHARACTER_MACROS or 18

Macros.MAX_ACCOUNT = MAX_ACCOUNT
Macros.MAX_CHARACTER = MAX_CHARACTER
Macros.CHANGED = "FrostAtomUI_MACROS_CHANGED"

local store, lists
local chunkCounts = {}
local pending = {}
local stubHeaders = {}
local iconIndex

local function charKey()
	return UnitName("player") .. " - " .. GetRealmName()
end

function Macros.Encode(text)
	return (strgsub(text, "|", "||"))
end

function Macros.ButtonName(macro)
	return BUTTON_PREFIX .. macro.id
end

function Macros.Command(macro)
	return "CLICK " .. Macros.ButtonName(macro) .. ":LeftButton"
end

function Macros.GetList(scope)
	return lists and lists[scope]
end

function Macros.ScopeOf(macro)
	for scope, list in pairs(lists) do
		if ns.tContains(list, macro) then
			return scope
		end
	end
end

local function chunkName(macro, index)
	local base = Macros.ButtonName(macro)
	return index == 1 and base or base .. "_" .. index
end

local function compile(body)
	local chunks, lines, size = {}, {}, 0
	local limit = Parser.RUN_LIMIT - CHAIN_RESERVE
	for line in gmatch(Macros.Encode(body), "[^\r\n]+") do
		local first = strbyte(line)
		if first ~= BYTE_HASH and first ~= BYTE_DASH then
			local need = #line + (size > 0 and 1 or 0)
			if size > 0 and size + need > limit then
				chunks[#chunks + 1] = tconcat(lines, "\n")
				wipe(lines)
				size, need = 0, #line
			end
			lines[#lines + 1] = line
			size = size + need
		end
	end
	if #lines > 0 then
		chunks[#chunks + 1] = tconcat(lines, "\n")
	end
	return chunks
end

local function getButton(name)
	local button = _G[name]
	if not button then
		button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
		button:Hide()
		button:RegisterForClicks("AnyDown")
		button:SetAttribute("type", "macro")
	end
	return button
end

function Macros.ChunkCount(macro)
	return chunkCounts[macro.id] or 0
end

local function iconIndexOf(texture)
	if not texture then
		return 1
	end
	if not iconIndex then
		iconIndex = {}
		for i = 1, GetNumMacroIcons() do
			local path = GetMacroIconInfo(i)
			if path then
				iconIndex[strlower(path)] = iconIndex[strlower(path)] or i
			end
		end
	end
	return iconIndex[strlower(texture)] or 1
end
Macros.IconIndexOf = iconIndexOf

local function stubLine(macro)
	return "/click " .. Macros.ButtonName(macro)
end

function Macros.FindStub(macro)
	local line = stubLine(macro)
	for index = 1, MAX_ACCOUNT + MAX_CHARACTER do
		local _, _, body = GetMacroInfo(index)
		if body then
			for bodyLine in gmatch(body, "[^\r\n]+") do
				if strtrim(bodyLine) == line then
					return index
				end
			end
		end
	end
end

function Macros.StubOf(body)
	for line in gmatch(body or "", "[^\r\n]+") do
		local id = strmatch(strtrim(line), "^/click " .. BUTTON_PREFIX .. "(%d+)$")
		if id then
			return tonumber(id)
		end
	end
end

function Macros.FindById(id)
	for _, list in pairs(lists) do
		for i = 1, #list do
			if list[i].id == id then
				return list[i]
			end
		end
	end
end

local function stubHeader(macro)
	local body = macro.body
	for line in gmatch(body, "[^\r\n]+") do
		if strmatch(line, "^#show") then
			if not Parser.OptionsValid(line) then
				return
			end
			return Macros.Encode(line)
		end
	end
	local kind, args = Parser.FirstAction(body)
	if kind == "action" and Parser.OptionsValid(args) then
		return "#showtooltip " .. Macros.Encode(args)
	end
end

local function stubBody(macro)
	local line = stubLine(macro)
	local header = stubHeader(macro)
	if header and #header + 1 + #line <= STUB_LIMIT then
		return header .. "\n" .. line
	end
	return line
end

local function stubName(macro)
	return ns.TruncateUTF8(macro.name ~= "" and macro.name or "?", STUB_NAME_LIMIT)
end

local function syncStub(macro)
	local body = stubBody(macro)
	if stubHeaders[macro.id] == body then
		return
	end
	stubHeaders[macro.id] = body
	local index = Macros.FindStub(macro)
	if index then
		local name, _, current = GetMacroInfo(index)
		if current ~= body or name ~= stubName(macro) then
			EditMacro(index, stubName(macro), nil, body)
		end
	end
end

local function flushPending()
	if InCombatLockdown() then
		return
	end
	Macros:UnregisterEvent("PLAYER_REGEN_ENABLED", flushPending)
	for macro in pairs(pending) do
		pending[macro] = nil
		Macros.Apply(macro)
	end
end

function Macros.Apply(macro)
	if InCombatLockdown() then
		pending[macro] = true
		Macros:RegisterEvent("PLAYER_REGEN_ENABLED", flushPending)
		return false
	end
	local chunks = compile(macro.body)
	local count = #chunks
	for index = 1, max(count, chunkCounts[macro.id] or 0) do
		local name = chunkName(macro, index)
		local text = chunks[index]
		if text then
			if index < count then
				text = text .. "\n/click " .. chunkName(macro, index + 1)
			end
			getButton(name):SetAttribute("macrotext", text)
		elseif _G[name] then
			_G[name]:SetAttribute("macrotext", nil)
		end
	end
	if count == 0 then
		getButton(chunkName(macro, 1)):SetAttribute("macrotext", nil)
	end
	chunkCounts[macro.id] = count
	syncStub(macro)
	return true
end

function Macros.SetIcon(macro)
	if InCombatLockdown() then
		return
	end
	local index = Macros.FindStub(macro)
	if index then
		EditMacro(index, nil, iconIndexOf(macro.icon))
	end
end

function Macros.IsPending(macro)
	return pending[macro] ~= nil
end

function Macros.Create(scope, name, icon, body)
	local macro = {
		id = store.nextId,
		name = name or L["Macro %d"]:format(store.nextId),
		icon = icon,
		body = body or "",
	}
	store.nextId = store.nextId + 1
	local list = lists[scope]
	list[#list + 1] = macro
	Macros.Apply(macro)
	ns:Fire(Macros.CHANGED)
	return macro
end

local function clearKeys(command)
	local changed = false
	local key = GetBindingKey(command)
	while key do
		SetBinding(key)
		changed = true
		key = GetBindingKey(command)
	end
	return changed
end

function Macros.Delete(macro)
	if InCombatLockdown() then
		return false
	end
	if clearKeys(Macros.Command(macro)) then
		SaveBindings(GetCurrentBindingSet())
	end
	local stub = Macros.FindStub(macro)
	if stub then
		DeleteMacro(stub)
	end
	macro.body = ""
	Macros.Apply(macro)
	pending[macro] = nil
	stubHeaders[macro.id] = nil
	for _, list in pairs(lists) do
		local index = ns.tContains(list, macro)
		if index then
			tremove(list, index)
		end
	end
	ns:Fire(Macros.CHANGED)
	return true
end

function Macros.PlaceOnBar(macro)
	if InCombatLockdown() then
		ns.Print(L["cannot change macros in combat"])
		return
	end
	local body = stubBody(macro)
	stubHeaders[macro.id] = body
	local index = Macros.FindStub(macro)
	if index then
		EditMacro(index, stubName(macro), iconIndexOf(macro.icon), body)
	else
		local numAccount, numCharacter = GetNumMacros()
		local perCharacter = Macros.ScopeOf(macro) == "char"
		if perCharacter and numCharacter >= MAX_CHARACTER or not perCharacter and numAccount >= MAX_ACCOUNT then
			ns.Print(L["no free game macro slot to put %s on an action bar; key bindings work without one"], macro.name)
			return
		end
		index = CreateMacro(stubName(macro), iconIndexOf(macro.icon), body, perCharacter and 1 or nil)
	end
	if index then
		PickupMacro(index)
	end
end

function Macros.ConvertGameMacro(index)
	if InCombatLockdown() then
		ns.Print(L["cannot change macros in combat"])
		return
	end
	local name, texture, body = GetMacroInfo(index)
	if not name then
		return
	end
	local icon = texture ~= ns.Media.questionMark and texture or nil
	local raw = Parser.Decode(body or "")
	local scope = index > MAX_ACCOUNT and "char" or "account"
	local macro = Macros.Create(scope, name, icon, raw)

	local command = "MACRO " .. name
	local key = GetBindingKey(command)
	local moved = false
	while key do
		SetBindingClick(key, Macros.ButtonName(macro), "LeftButton")
		moved = true
		key = GetBindingKey(command)
	end
	if moved then
		SaveBindings(GetCurrentBindingSet())
	end

	local stub = stubBody(macro)
	stubHeaders[macro.id] = stub
	EditMacro(index, nil, nil, stub)
	return macro
end

local EXPORT_PREFIX = "FAUIM1:"
local NAME_LIMIT = 64
local GAME_BODY_LIMIT = 255
local GAME_SCOPES = { gameAccount = "account", gameChar = "char" }
local SCOPES = { account = true, char = true, gameAccount = true, gameChar = true }

function Macros.Export(items)
	return EXPORT_PREFIX .. ns.Encode(ns.Serialize({ macros = items }))
end

local function sanitize(item)
	if type(item) ~= "table" or type(item.body) ~= "string" then
		return nil
	end
	local name = type(item.name) == "string" and strtrim(item.name) or ""
	return {
		scope = SCOPES[item.scope] and item.scope or "account",
		name = ns.TruncateUTF8(name, NAME_LIMIT),
		icon = type(item.icon) == "string" and item.icon ~= "" and item.icon or nil,
		body = strgsub(item.body, "\r\n?", "\n"),
	}
end

function Macros.DecodeExport(text)
	text = text and strtrim(text)
	if not text or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return nil, L["not a FrostAtom UI macro string"]
	end
	local body, err = ns.Decode(text:sub(#EXPORT_PREFIX + 1))
	if not body then
		return nil, err
	end
	local data = ns.Deserialize(body)
	if type(data) ~= "table" or type(data.macros) ~= "table" then
		return nil, L["malformed macro string"]
	end
	local items = {}
	for i = 1, #data.macros do
		items[#items + 1] = sanitize(data.macros[i])
	end
	if #items == 0 then
		return nil, L["malformed macro string"]
	end
	return items
end

local function takenNames(scope)
	local taken = {}
	if GAME_SCOPES[scope] then
		local first = scope == "gameChar" and MAX_ACCOUNT + 1 or 1
		local numAccount, numCharacter = GetNumMacros()
		local count = scope == "gameChar" and numCharacter or numAccount
		for index = first, first + count - 1 do
			local name = GetMacroInfo(index)
			if name then
				taken[strlower(name)] = true
			end
		end
	else
		for _, macro in ipairs(lists[scope]) do
			taken[strlower(macro.name)] = true
		end
	end
	return taken
end

local function uniqueName(base, taken, limit)
	local name, suffix = ns.TruncateUTF8(base, limit), 1
	while base ~= "" and taken[strlower(name)] do
		suffix = suffix + 1
		local tail = " " .. suffix
		name = ns.TruncateUTF8(base, limit - #tail) .. tail
	end
	taken[strlower(name)] = true
	return name
end

local function gameSlotFree(scope)
	local numAccount, numCharacter = GetNumMacros()
	if scope == "gameChar" then
		return numCharacter < MAX_CHARACTER
	end
	return numAccount < MAX_ACCOUNT
end

function Macros.Import(items)
	local taken = {}
	local imported, converted = 0, 0
	local lastScope, lastEntry, lastGameName
	for _, item in ipairs(items) do
		local scope = item.scope
		local gameBody = GAME_SCOPES[scope] and Macros.Encode(item.body)
		if gameBody and (InCombatLockdown() or #gameBody > GAME_BODY_LIMIT or not gameSlotFree(scope)) then
			scope = GAME_SCOPES[scope]
			gameBody = nil
			converted = converted + 1
		end
		taken[scope] = taken[scope] or takenNames(scope)
		if gameBody then
			lastGameName = uniqueName(item.name, taken[scope], STUB_NAME_LIMIT)
			CreateMacro(lastGameName, iconIndexOf(item.icon), gameBody, scope == "gameChar" and 1 or nil)
		else
			lastEntry = Macros.Create(scope, uniqueName(item.name, taken[scope], NAME_LIMIT), item.icon, item.body)
		end
		lastScope = scope
		imported = imported + 1
	end
	if GAME_SCOPES[lastScope] then
		lastEntry = GetMacroIndexByName(lastGameName)
	end
	return imported, converted, lastScope, lastEntry
end

local function onSpellsChanged()
	Parser.InvalidateSpells()
	ns:Fire(Macros.CHANGED, "knowledge")
end

local function migrate(saved)
	saved.nextId = saved.nextId or 1
	saved.account = saved.account or {}
	saved.chars = saved.chars or {}
	return saved
end

Macros:OnInitialize(function(self)
	store = migrate(ns.db.macros or {})
	ns.db.macros = store
	local key = charKey()
	store.chars[key] = store.chars[key] or {}
	lists = { account = store.account, char = store.chars[key] }

	for _, list in pairs(lists) do
		for i = 1, #list do
			self.Apply(list[i])
		end
	end

	self:RegisterEvent("SPELLS_CHANGED", onSpellsChanged)
	self:RegisterEvent("COMPANION_LEARNED", onSpellsChanged)
	self:RegisterEvent("BAG_UPDATE", function()
		ns:Fire(Macros.CHANGED, "knowledge")
	end)
	self:RegisterUnitEvent("UNIT_PET", "player", onSpellsChanged)
end)
