local _, ns = ...
local L = ns.L

local strbyte, strsub, strfind, strmatch, strlower, strtrim, strsplit =
	string.byte, string.sub, string.find, string.match, string.lower, strtrim, strsplit
local floor, min, max, ceil = math.floor, math.min, math.max, math.ceil
local InCombatLockdown, GetCursorInfo, ClearCursor = InCombatLockdown, GetCursorInfo, ClearCursor
local GetMacroInfo, GetNumMacros, CreateMacro, EditMacro, DeleteMacro, PickupMacro =
	GetMacroInfo, GetNumMacros, CreateMacro, EditMacro, DeleteMacro, PickupMacro
local GetNumMacroIcons, GetMacroIconInfo = GetNumMacroIcons, GetMacroIconInfo
local GetBindingKey, GetBindingAction, GetBindingText, SetBinding, SetBindingClick, SetBindingMacro =
	GetBindingKey, GetBindingAction, GetBindingText, SetBinding, SetBindingClick, SetBindingMacro
local SaveBindings, GetCurrentBindingSet = SaveBindings, GetCurrentBindingSet
local IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, IsMouseButtonDown =
	IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, IsMouseButtonDown
local GetSpellInfo, GetSpellName, GetItemInfo, GetItemSpell, GetSpellTexture =
	GetSpellInfo, GetSpellName, GetItemInfo, GetItemSpell, GetSpellTexture
local GetContainerItemInfo, GetInventoryItemTexture = GetContainerItemInfo, GetInventoryItemTexture
local SecureCmdOptionParse, GameTooltip = SecureCmdOptionParse, GameTooltip

local Macros = ns:GetModule("Macros")
local Parser = ns.MacroParser

local FRAME_NAME = "FrostAtomUIMacros"
local WIDTH, HEIGHT = 800, 600
local COLUMNS = 14
local LIST_ROWS = 3
local COLUMN_WIDTH = 49
local ROW_HEIGHT = 46
local BUTTON_HEIGHT = 22
local EDITOR_WIDTH, EDITOR_HEIGHT = 500, 225
local ISSUE_ROWS = 14
local ISSUE_ROW_HEIGHT = 14
local EDITOR_INSET = 2
local GUTTER_WIDTH = 32
local GUTTER_CACHE_LIMIT = 500
local PICKER_COLUMNS = 5
local PICKER_ROWS = 4
local PICKER_ROW_HEIGHT = 36
local MENU_BUTTON_HEIGHT = 16
local MENU_HIDE_DELAY = 2

local TOOLTIP_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

local MENU_BACKDROPS = {
	dark = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 9 },
	},
	menu = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 4 },
	},
}

local POPUP_ART = {
	{ "Interface\\MacroFrame\\MacroPopup-TopLeft", 256, 256, 0, 0 },
	{ "Interface\\MacroFrame\\MacroPopup-TopRight", 64, 256, 256, 0 },
	{ "Interface\\MacroFrame\\MacroPopup-BotLeft", 256, 64, 0, -256 },
	{ "Interface\\MacroFrame\\MacroPopup-BotRight", 64, 64, 256, -256 },
}

local HORIZONTAL_BAR = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar"
local FILTER_BORDER = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder"

local LEVEL_COLORS = {
	[Parser.ERROR] = RED_FONT_COLOR,
	[Parser.WARNING] = ORANGE_FONT_COLOR,
	[Parser.INFO] = GRAY_FONT_COLOR,
}

local IGNORED_KEYS = {
	LSHIFT = true,
	RSHIFT = true,
	LCTRL = true,
	RCTRL = true,
	LALT = true,
	RALT = true,
	UNKNOWN = true,
}

local TABS = {
	{ key = "account", label = "Account" },
	{ key = "char", label = "Character" },
	{ key = "gameAccount", label = "Game: account" },
	{ key = "gameChar", label = "Game: character" },
}

local frame
local tab = "account"
local selection = {}
local entries = {}
local editorEntry, editorRaw, analysis
local gameDirty = false
local rendering = false
local errorCounts = {}
local icons
local gutter = { cache = {}, cacheSize = 0 }

local function isGame(key)
	key = key or tab
	return key == "gameAccount" or key == "gameChar"
end

local function selected()
	return selection[tab]
end

local function isVirtual(entry)
	return type(entry) == "table"
end

local function entryName(entry)
	if isVirtual(entry) then
		return entry.name
	end
	return (GetMacroInfo(entry)) or ""
end

local function displayName(entry)
	local name = entryName(entry)
	if strtrim(name) == "" then
		return L["Unnamed"], true
	end
	return name, false
end

local function entryRawBody(entry)
	if isVirtual(entry) then
		return entry.body
	end
	local _, _, body = GetMacroInfo(entry)
	return (Parser.Decode(body or ""))
end

local function entryCommand(entry)
	if isVirtual(entry) then
		return Macros.Command(entry)
	end
	return "MACRO " .. entryName(entry)
end

local function entryKeys(entry)
	return { GetBindingKey(entryCommand(entry)) }
end

local function itemTexture(action)
	local name, bag, slot = SecureCmdItemParse(action)
	if bag then
		return (GetContainerItemInfo(tonumber(bag), tonumber(slot)))
	elseif slot then
		return GetInventoryItemTexture("player", tonumber(slot))
	end
	return name and select(10, GetItemInfo(name))
end

local function actionTexture(kind, args)
	if not Parser.OptionsValid(args) then
		return
	end
	local action = SecureCmdOptionParse(args)
	if not action or action == "" then
		return
	end
	if kind == "sequence" then
		local _, item, spell = QueryCastSequence(action)
		action = item or spell
	elseif kind == "actions" then
		action = strtrim((strsplit(",", action)))
	end
	if not action or action == "" then
		return
	end
	return itemTexture(action) or GetSpellTexture((action:gsub("^!+", "")))
end

local function virtualIcon(macro)
	if macro.icon then
		return macro.icon
	end
	local kind, args = Parser.FirstAction(macro.body)
	return kind and actionTexture(kind, args) or ns.Media.questionMark
end

local function entryIcon(entry)
	if isVirtual(entry) then
		return virtualIcon(entry)
	end
	local _, texture = GetMacroInfo(entry)
	return texture or ns.Media.questionMark
end

local function errorCount(body)
	local count = errorCounts[body]
	if not count then
		count = 0
		local issues = Parser.Analyze(body).issues
		for i = 1, #issues do
			if issues[i].level == Parser.ERROR then
				count = count + 1
			end
		end
		errorCounts[body] = count
	end
	return count
end

local function gameRange(key)
	local numAccount, numCharacter = GetNumMacros()
	if key == "gameAccount" then
		return 1, numAccount
	end
	return Macros.MAX_ACCOUNT + 1, Macros.MAX_ACCOUNT + numCharacter
end

local function collectEntries()
	wipe(entries)
	if isGame() then
		local first, last = gameRange(tab)
		for index = first, last do
			entries[#entries + 1] = index
		end
	else
		local list = Macros.GetList(tab)
		for i = 1, #list do
			entries[i] = list[i]
		end
	end
	local current = selected()
	if current and not ns.tContains(entries, current) then
		selection[tab] = nil
	end
	if not selected() then
		selection[tab] = entries[1]
	end
end

local function keyLabel(key, abbreviate)
	return GetBindingText(key, "KEY_", abbreviate and 1 or nil)
end

local function commandLabel(command)
	local id = strmatch(command, "^CLICK FAMacro(%d+):")
	local macro = id and Macros.FindById(tonumber(id))
	if macro then
		return macro.name
	end
	local macroName = strmatch(command, "^MACRO (.+)$")
	if macroName then
		return macroName
	end
	local buttonName = strmatch(command, "^CLICK (.+):")
	if buttonName then
		return buttonName
	end
	return GetBindingText(command, "BINDING_NAME_")
end

local refresh, refreshList, refreshDetail, loadEditor, analyzeEditor, openPicker

local function limitOf(entry)
	if entry and not isVirtual(entry) then
		return Parser.MACRO_LIMIT
	end
end

local function saveGameMacro()
	if not gameDirty or not editorEntry or isVirtual(editorEntry) then
		return
	end
	gameDirty = false
	local encoded = Macros.Encode(editorRaw)
	if #encoded > Parser.MACRO_LIMIT then
		ns.Print(
			L["%s is longer than %d characters and was not saved; make it unlimited to keep the text"],
			entryName(editorEntry),
			Parser.MACRO_LIMIT
		)
		return
	end
	local _, _, current = GetMacroInfo(editorEntry)
	if current ~= encoded then
		EditMacro(editorEntry, nil, nil, encoded)
	end
end

local function applyMacro(macro)
	Macros.Apply(macro)
	if frame and frame:IsShown() then
		refreshList()
		refreshDetail()
	end
end

local function storeRaw(raw)
	if raw == editorRaw then
		return
	end
	editorRaw = raw
	if isVirtual(editorEntry) then
		editorEntry.body = raw
		ns.Defer(editorEntry, applyMacro)
	else
		gameDirty = true
	end
end

local function renderEditor(cursorRaw)
	local edit = frame.edit
	local rendered, cursor = Parser.Render(editorRaw, analysis.spans, cursorRaw)
	rendering = true
	if edit:GetText() ~= rendered then
		edit:SetText(rendered)
	end
	if cursorRaw then
		edit:SetCursorPosition(cursor)
	end
	edit.lastCursor = edit:GetCursorPosition()
	edit.lastValue = edit:GetText()
	rendering = false
end

local function showIssues()
	local issues = analysis.issues
	local rows = frame.issueRows
	local shown = min(#issues, ISSUE_ROWS)
	if #issues > ISSUE_ROWS then
		shown = ISSUE_ROWS - 1
	end
	for i = 1, ISSUE_ROWS do
		local row = rows[i]
		local item = issues[i]
		if i <= shown then
			local color = LEVEL_COLORS[item.level]
			if item.line then
				row.text:SetFormattedText(L["Line %d: %s"], item.line, item.text)
			else
				row.text:SetText(item.text)
			end
			row.text:SetTextColor(color.r, color.g, color.b)
			row.line = item.line
			row.color = color
			row:Show()
		elseif i == shown + 1 and #issues > shown then
			row.text:SetFormattedText(L["... and %d more"], #issues - shown)
			row.text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
			row.line = nil
			row.color = nil
			row:Show()
		else
			row:Hide()
		end
	end
	ns.SetShown(frame.noIssues, #issues == 0 and editorEntry ~= nil)
end

local function showInfo()
	local info = frame.info
	if not editorEntry then
		info:SetText("")
		return
	end
	local bytes = #Macros.Encode(editorRaw)
	if isVirtual(editorEntry) then
		local text = L["%d bytes"]:format(bytes)
		local chunks = Macros.ChunkCount(editorEntry)
		if chunks > 1 then
			text = text .. " - " .. L["runs as %d chained parts"]:format(chunks)
		end
		if Macros.IsPending(editorEntry) then
			text = text .. " - " .. ORANGE_FONT_COLOR_CODE .. L["changes apply after combat"] .. FONT_COLOR_CODE_CLOSE
		end
		info:SetText(text)
	else
		local text = MACROFRAME_CHAR_LIMIT:format(bytes)
		if bytes > Parser.MACRO_LIMIT then
			text = RED_FONT_COLOR_CODE .. text .. FONT_COLOR_CODE_CLOSE
		end
		info:SetText(text)
	end
end

local function wrappedRows(line)
	if line == "" then
		return 1
	end
	local rows = gutter.cache[line]
	if not rows then
		if gutter.cacheSize >= GUTTER_CACHE_LIMIT then
			wipe(gutter.cache)
			gutter.cacheSize = 0
		end
		if not gutter.lineHeight then
			gutter.measure:SetText("X")
			gutter.lineHeight = gutter.measure:GetHeight()
		end
		gutter.measure:SetText((line:gsub("|", "||")))
		rows = max(1, floor(gutter.measure:GetHeight() / gutter.lineHeight + 0.5))
		gutter.cache[line] = rows
		gutter.cacheSize = gutter.cacheSize + 1
	end
	return rows
end

local function updateGutter()
	local parts, count, number = {}, 0, 0
	for line in (editorRaw .. "\n"):gmatch("([^\n]*)\n") do
		number = number + 1
		count = count + 1
		parts[count] = number
		for _ = 2, wrappedRows(line) do
			count = count + 1
			parts[count] = ""
		end
	end
	gutter.numbers:SetText(table.concat(parts, "\n"))
end

function analyzeEditor(cursorRaw)
	analysis = Parser.Analyze(editorRaw, limitOf(editorEntry))
	renderEditor(cursorRaw)
	updateGutter()
	showIssues()
	showInfo()
end

local function onEditorTextChanged(edit)
	ScrollingEdit_OnTextChanged(edit, edit:GetParent())
	if rendering or not editorEntry then
		return
	end
	local raw, cursorRaw = Parser.Decode(edit:GetText(), edit:GetCursorPosition())
	storeRaw(raw)
	analyzeEditor(cursorRaw)
end

local function isCodeRun(value, from, to)
	local position = from
	while position <= to do
		if strbyte(value, position) ~= strbyte("|") then
			return false
		end
		local nextByte = strbyte(value, position + 1)
		if nextByte == strbyte("r") then
			position = position + 2
		elseif nextByte == strbyte("c") and strfind(value, "^%x%x%x%x%x%x%x%x", position + 2) then
			position = position + 10
		else
			return false
		end
	end
	return position == to + 1
end

local function charLength(value, position)
	local byte = strbyte(value, position)
	if not byte then
		return 0
	elseif byte == strbyte("|") then
		return 2
	elseif byte >= 0xF0 then
		return 4
	elseif byte >= 0xE0 then
		return 3
	elseif byte >= 0xC0 then
		return 2
	end
	return 1
end

local function skipCodesForward(value, position)
	while true do
		local nextByte = strbyte(value, position + 2)
		if strbyte(value, position + 1) ~= strbyte("|") then
			return position
		end
		if nextByte == strbyte("r") then
			position = position + 2
		elseif nextByte == strbyte("c") and strfind(value, "^%x%x%x%x%x%x%x%x", position + 3) then
			position = position + 10
		else
			return position
		end
	end
end

local function previousCharStart(value, position)
	local start = position
	repeat
		start = start - 1
		local byte = strbyte(value, start)
		if not byte then
			return nil
		end
	until byte < 0x80 or byte >= 0xC0
	if start > 1 and strbyte(value, start) == strbyte("|") and strbyte(value, start - 1) == strbyte("|") then
		start = start - 1
	end
	return start
end

local function skipCodesBackward(value, position)
	while position > 0 do
		if
			position >= 2
			and strsub(value, position - 1, position) == "|r"
			and strsub(value, position - 2, position - 2) ~= "|"
		then
			position = position - 2
		elseif position >= 10 and strfind(strsub(value, position - 9, position), "^|c%x%x%x%x%x%x%x%x$") then
			position = position - 10
		else
			return position
		end
	end
	return position
end

local function onEditorCursorChanged(edit, x, y, w, h)
	ScrollingEdit_OnCursorChanged(edit, x, y, w, h)
	if rendering then
		return
	end
	local position = edit:GetCursorPosition()
	local last = edit.lastCursor
	local value = edit:GetText()
	edit.lastCursor = position
	if not last or position == last or value ~= edit.lastValue or IsMouseButtonDown("LeftButton") then
		edit.lastValue = value
		return
	end
	local target
	if position > last and isCodeRun(value, last + 1, position) then
		local start = skipCodesForward(value, position)
		local length = charLength(value, start + 1)
		if length > 0 then
			target = start + length
		end
	elseif position < last and isCodeRun(value, position + 1, last) then
		local start = previousCharStart(value, skipCodesBackward(value, position) + 1)
		if start then
			target = start - 1
		end
	end
	if target and target ~= position then
		edit.lastCursor = target
		edit:SetCursorPosition(target)
	end
end

local function lineOffset(text, line)
	local position = 1
	for _ = 2, line do
		local stop = strfind(text, "[\r\n]", position)
		if not stop then
			return #text
		end
		position = stop + 1
	end
	return position - 1
end

local function jumpToLine(line)
	if not line or not editorEntry then
		return
	end
	frame.edit:SetFocus()
	renderEditor(lineOffset(editorRaw, line))
end

local function currentLineEmpty()
	local edit = frame.edit
	local _, cursorRaw = Parser.Decode(edit:GetText(), edit:GetCursorPosition())
	local before = strsub(editorRaw, 1, cursorRaw)
	local after = strsub(editorRaw, cursorRaw + 1)
	return strmatch(before, "[^\r\n]*$") == "" and strmatch(after, "^[^\r\n]*") == ""
end

local function insertAction(name, kind)
	if not name or name == "" or not frame or not frame.edit.hasFocus then
		return
	end
	local text = name
	if currentLineEmpty() then
		if kind == "item" then
			text = (GetItemSpell(name) and SLASH_USE1 or SLASH_EQUIP1) .. " " .. name
		else
			text = SLASH_CAST1 .. " " .. name
		end
	end
	frame.edit:Insert(Macros.Encode(text))
end

local function onInsertLink(text)
	if not frame or not frame:IsShown() or not frame.edit.hasFocus or type(text) ~= "string" then
		return
	end
	local spellId = strmatch(text, "|Hspell:(%d+)")
	if spellId then
		insertAction((GetSpellInfo(tonumber(spellId))), "spell")
		return
	end
	local itemId = strmatch(text, "|Hitem:(%d+)")
	if itemId then
		insertAction(GetItemInfo(tonumber(itemId)) or strmatch(text, "|h%[(.-)%]|h"), "item")
		return
	end
	if not strfind(text, "|", 1, true) then
		insertAction(text, GetItemInfo(text) and "item" or "spell")
	end
end

local function onEditorReceiveDrag(edit)
	local kind, detail, extra = GetCursorInfo()
	local name, nameKind
	if kind == "spell" then
		name, nameKind = GetSpellName(detail, extra), "spell"
	elseif kind == "item" then
		name, nameKind = GetItemInfo(detail), "item"
	elseif kind == "companion" then
		local _, _, spellId = GetCompanionInfo(extra, detail)
		name, nameKind = spellId and GetSpellInfo(spellId), "spell"
	elseif kind == "equipmentset" then
		name = detail
	end
	if not name then
		return
	end
	ClearCursor()
	edit:SetFocus()
	if kind == "equipmentset" then
		edit:Insert(Macros.Encode(currentLineEmpty() and SLASH_EQUIP_SET1 .. " " .. name or name))
	else
		insertAction(name, nameKind)
	end
end

local function updateRunButton()
	local run = frame.run
	if InCombatLockdown() then
		return
	end
	local entry = editorEntry
	if not frame:IsShown() or not entry then
		run:Hide()
		return
	end
	if isVirtual(entry) then
		run:SetAttribute("type", "click")
		run:SetAttribute("clickbutton", _G[Macros.ButtonName(entry)])
		run:SetAttribute("macro", nil)
	else
		run:SetAttribute("type", "macro")
		run:SetAttribute("macro", entry)
		run:SetAttribute("clickbutton", nil)
	end
	local slot = frame.runSlot
	local scale = slot:GetEffectiveScale() / run:GetEffectiveScale()
	run:ClearAllPoints()
	run:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", slot:GetLeft() * scale, slot:GetTop() * scale)
	run:SetSize(slot:GetWidth() * scale, slot:GetHeight() * scale)
	run:Show()
end

function loadEditor()
	saveGameMacro()
	local previous = editorEntry
	editorEntry = selected()
	gameDirty = false
	if frame.picker and editorEntry ~= previous then
		frame.picker:Hide()
	end
	local edit = frame.edit
	if not editorEntry then
		editorRaw = ""
		edit:ClearFocus()
		edit:Hide()
		frame.detail:Hide()
		analysis = { spans = {}, issues = {} }
		showIssues()
		showInfo()
		updateRunButton()
		return
	end
	edit:Show()
	frame.detail:Show()
	editorRaw = entryRawBody(editorEntry)
	analyzeEditor(0)
	frame.scroll:SetVerticalScroll(0)
	updateRunButton()
end

local function keysText(keys)
	if #keys == 0 then
		return GRAY_FONT_COLOR_CODE .. L["Not bound"] .. FONT_COLOR_CODE_CLOSE
	end
	local labels = {}
	for i = 1, #keys do
		labels[i] = keyLabel(keys[i])
	end
	return table.concat(labels, ", ")
end

function refreshDetail()
	local entry = editorEntry
	if not entry then
		return
	end
	local detail = frame.detail
	if not (frame.picker and frame.picker:IsShown()) then
		detail.icon:SetTexture(entryIcon(entry))
		detail.name:SetText(entryName(entry))
	end
	if isVirtual(entry) then
		detail.subtitle:SetText("/click " .. Macros.ButtonName(entry))
		detail.place:SetText(L["Put on action bar"])
	else
		local stubId = Macros.StubOf(select(3, GetMacroInfo(entry)))
		local target = stubId and Macros.FindById(stubId)
		if target then
			detail.subtitle:SetFormattedText(L["Runs unlimited macro %s"], target.name)
		else
			detail.subtitle:SetText(entry > Macros.MAX_ACCOUNT and L["Game macro of this character"] or L["Game macro"])
		end
		detail.place:SetText(L["Make unlimited"])
	end
	ns.FitButton(detail.place, 24, 120)
	if not detail.bind.capturing then
		detail.bind:SetText(keysText(entryKeys(entry)))
	end
	showInfo()
end

local function refreshTabs()
	local numAccount, numCharacter = GetNumMacros()
	local counts = {
		account = #Macros.GetList("account"),
		char = #Macros.GetList("char"),
		gameAccount = ("%d/%d"):format(numAccount, Macros.MAX_ACCOUNT),
		gameChar = ("%d/%d"):format(numCharacter, Macros.MAX_CHARACTER),
	}
	local selectedTab = 1
	for i = 1, #frame.tabs do
		local button = frame.tabs[i]
		local info = TABS[i]
		button:SetFormattedText("%s (%s)", L[info.label], counts[info.key])
		PanelTemplates_TabResize(button, -15)
		_G[button:GetName() .. "HighlightTexture"]:SetWidth(button:GetTextWidth() + 31)
		if info.key == tab then
			selectedTab = i
		end
	end
	PanelTemplates_SetTab(frame, selectedTab)
	local full
	if tab == "gameAccount" then
		full = numAccount >= Macros.MAX_ACCOUNT
	elseif tab == "gameChar" then
		full = numCharacter >= Macros.MAX_CHARACTER
	end
	if full then
		frame.new:Disable()
	else
		frame.new:Enable()
	end
	ns.SetShown(frame.copy, not isGame())
end

local function slotCount()
	if tab == "gameAccount" then
		return max(#entries, Macros.MAX_ACCOUNT)
	elseif tab == "gameChar" then
		return max(#entries, Macros.MAX_CHARACTER)
	end
	return max(LIST_ROWS, ceil(#entries / COLUMNS)) * COLUMNS
end

function refreshList()
	local offset = FauxScrollFrame_GetOffset(frame.listScroll)
	local current = selected()
	local slots = slotCount()
	for i = 1, #frame.cells do
		local cell = frame.cells[i]
		local index = offset * COLUMNS + i
		local entry = entries[index]
		cell.entry = entry
		if entry then
			cell.icon:SetTexture(entryIcon(entry))
			local name, unnamed = displayName(entry)
			cell.name:SetText(unnamed and "" or name)
			if errorCount(entryRawBody(entry)) > 0 then
				cell.name:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
			else
				cell.name:SetTextColor(1, 1, 1)
			end
			local key = GetBindingKey(entryCommand(entry))
			cell.key:SetText(key and keyLabel(key, true) or "")
			cell:Enable()
			cell:SetChecked(entry == current)
			cell:Show()
		elseif index <= slots then
			cell.icon:SetTexture(nil)
			cell.name:SetText("")
			cell.key:SetText("")
			cell:SetChecked(nil)
			cell:Disable()
			cell:Show()
		else
			cell:Hide()
		end
	end
	FauxScrollFrame_Update(
		frame.listScroll,
		ceil(slots / COLUMNS),
		LIST_ROWS,
		ROW_HEIGHT,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		true
	)
end

function refresh(reloadEditor)
	if not frame or not frame:IsShown() then
		return
	end
	collectEntries()
	refreshTabs()
	refreshList()
	if reloadEditor or selected() ~= editorEntry then
		loadEditor()
	end
	refreshDetail()
end

local function selectTab(key)
	if key == tab then
		return
	end
	saveGameMacro()
	frame.edit:ClearFocus()
	tab = key
	FauxScrollFrame_SetOffset(frame.listScroll, 0)
	frame.listScrollBar:SetValue(0)
	refresh(true)
end

local function selectEntry(entry)
	frame.edit:ClearFocus()
	selection[tab] = entry
	refresh(true)
end

local function createNew()
	if isGame() then
		if InCombatLockdown() then
			ns.Print(L["cannot change macros in combat"])
			return
		end
		local index = CreateMacro(L["New"], 1, "", tab == "gameChar")
		if index then
			selection[tab] = index
		end
	else
		selection[tab] = Macros.Create(tab)
	end
	if frame.picker then
		frame.picker:Hide()
	end
	refresh(true)
	openPicker(true)
end

local function copySelected()
	local entry = selected()
	if not isVirtual(entry) then
		return
	end
	selection[tab] = Macros.Create(tab, L["%s copy"]:format(entry.name), entry.icon, entry.body)
	refresh(true)
end

StaticPopupDialogs.FROSTATOMUI_MACRO_DELETE = {
	text = "Delete macro %s?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, entry)
		if InCombatLockdown() then
			ns.Print(L["cannot change macros in combat"])
			return
		end
		if isVirtual(entry) then
			Macros.Delete(entry)
		else
			DeleteMacro(entry)
		end
		if editorEntry == entry then
			gameDirty = false
			editorEntry = nil
		end
		selection[tab] = nil
		refresh(true)
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

ns.OnLocaleReady(function()
	StaticPopupDialogs.FROSTATOMUI_MACRO_DELETE.text = L["Delete macro %s?"]
end)

local function deleteSelected()
	local entry = selected()
	if not entry then
		return
	end
	local popup = StaticPopup_Show("FROSTATOMUI_MACRO_DELETE", (displayName(entry)))
	if popup then
		popup.data = entry
	end
end

local function commitName(box)
	local entry = editorEntry
	if not entry then
		return
	end
	local name = strtrim(box:GetText())
	if name == "" or name == entryName(entry) then
		box:SetText(entryName(entry))
		return
	end
	if isVirtual(entry) then
		entry.name = name
		Macros.Apply(entry)
		refresh()
	elseif not InCombatLockdown() then
		saveGameMacro()
		local index = EditMacro(entry, name)
		selection[tab] = index
		refresh(true)
	end
end

local function setIcon(texture)
	local entry = editorEntry
	if not entry then
		return
	end
	if isVirtual(entry) then
		entry.icon = texture
		Macros.SetIcon(entry)
	elseif not InCombatLockdown() then
		saveGameMacro()
		EditMacro(entry, nil, Macros.IconIndexOf(texture))
	end
	refresh()
end

local function placeOrConvert()
	local entry = editorEntry
	if not entry then
		return
	end
	if isVirtual(entry) then
		Macros.PlaceOnBar(entry)
		return
	end
	saveGameMacro()
	local macro = Macros.ConvertGameMacro(entry)
	if macro then
		ns.Print(L["%s is now an unlimited macro; the game macro stays on your bars and runs it"], macro.name)
		tab = Macros.ScopeOf(macro)
		selection[tab] = macro
		refresh(true)
	end
end

local function normalizeKey(key)
	if key == "LeftButton" then
		return "BUTTON1"
	elseif key == "RightButton" then
		return "BUTTON2"
	elseif key == "MiddleButton" then
		return "BUTTON3"
	elseif strfind(key, "^Button%d+$") then
		return key:upper()
	end
	return key
end

local function stopCapture(bind)
	bind.capturing = false
	bind.catcher:Hide()
	bind:UnlockHighlight()
	refreshDetail()
end

local function bindKey(bind, key)
	local entry = editorEntry
	if not entry or InCombatLockdown() then
		stopCapture(bind)
		return
	end
	local combo = normalizeKey(key)
	if IsShiftKeyDown() then
		combo = "SHIFT-" .. combo
	end
	if IsControlKeyDown() then
		combo = "CTRL-" .. combo
	end
	if IsAltKeyDown() then
		combo = "ALT-" .. combo
	end
	if combo == "BUTTON1" or combo == "BUTTON2" then
		stopCapture(bind)
		return
	end
	local command = entryCommand(entry)
	local previous = GetBindingAction(combo)
	if previous and previous ~= "" and previous ~= command then
		ns.Print(L["%s was unbound from %s"], keyLabel(combo), commandLabel(previous))
	end
	if isVirtual(entry) then
		SetBindingClick(combo, Macros.ButtonName(entry), "LeftButton")
	else
		SetBindingMacro(combo, entryName(entry))
	end
	SaveBindings(GetCurrentBindingSet())
	stopCapture(bind)
	refreshList()
end

local function clearBinding()
	local entry = editorEntry
	if not entry or InCombatLockdown() then
		return
	end
	local command = entryCommand(entry)
	local key = GetBindingKey(command)
	while key do
		SetBinding(key)
		key = GetBindingKey(command)
	end
	SaveBindings(GetCurrentBindingSet())
	refreshDetail()
	refreshList()
end

local function onBindClick(bind, button)
	if InCombatLockdown() then
		ns.Print(L["cannot change bindings in combat"])
		return
	end
	if button == "RightButton" then
		clearBinding()
		return
	end
	bind.capturing = true
	bind:LockHighlight()
	bind:SetText(NORMAL_FONT_COLOR_CODE .. L["Press a key..."] .. FONT_COLOR_CODE_CLOSE)
	bind.catcher:Show()
end

local function tooltip(owner, title, ...)
	local lines = { ... }
	owner:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		for i = 1, #lines do
			GameTooltip:AddLine(lines[i], nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	owner:SetScript("OnLeave", GameTooltip_Hide)
end

local function onCellEnter(cell)
	local entry = cell.entry
	if not entry then
		return
	end
	GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
	local name, unnamed = displayName(entry)
	if unnamed then
		GameTooltip:SetText(name, 0.5, 0.5, 0.5)
	else
		GameTooltip:SetText(name, 1, 1, 1)
	end
	local keys = entryKeys(entry)
	for i = 1, #keys do
		GameTooltip:AddLine(keyLabel(keys[i]), 0.8, 0.8, 1)
	end
	if isVirtual(entry) then
		GameTooltip:AddLine("/click " .. Macros.ButtonName(entry), 0.6, 0.6, 0.6)
	end
	GameTooltip:AddLine(L["Drag to an action bar"], 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local function pickupEntry(entry)
	if not entry then
		return
	end
	if isVirtual(entry) then
		Macros.PlaceOnBar(entry)
	else
		PickupMacro(entry)
	end
end

local function onCellDrag(cell)
	pickupEntry(cell.entry)
end

local function buildIcons()
	icons = { false }
	for i = 1, GetNumMacroIcons() do
		local texture = GetMacroIconInfo(i)
		if texture then
			icons[#icons + 1] = texture
		end
	end
end

local refreshPicker

local function pickerFilter(picker)
	if not icons then
		buildIcons()
	end
	local query = strlower(strtrim(picker.search:GetText()))
	local filtered = picker.filtered
	wipe(filtered)
	for i = 1, #icons do
		local texture = icons[i]
		if query == "" or texture and strfind(strlower(texture), query, 1, true) then
			filtered[#filtered + 1] = texture
		end
	end
end

local function previewIcon(texture)
	if texture then
		return texture
	elseif isVirtual(editorEntry) then
		return virtualIcon({ body = editorEntry.body })
	end
	return ns.Media.questionMark
end

function refreshPicker()
	local picker = frame.picker
	local offset = FauxScrollFrame_GetOffset(picker.scroll)
	for i = 1, #picker.cells do
		local cell = picker.cells[i]
		local texture = picker.filtered[offset * PICKER_COLUMNS + i]
		if texture ~= nil then
			cell.texture = texture
			cell.icon:SetTexture(texture or ns.Media.questionMark)
			cell.auto:SetText(texture == false and L["Auto"] or "")
			cell:SetChecked((texture or nil) == picker.icon)
			cell:Show()
		else
			cell:Hide()
		end
	end
	FauxScrollFrame_Update(picker.scroll, ceil(#picker.filtered / PICKER_COLUMNS), PICKER_ROWS, PICKER_ROW_HEIGHT)
end

local function applyPicker()
	local picker = frame.picker
	local changed, texture = picker.iconChanged, picker.icon
	picker:Hide()
	if changed then
		setIcon(texture)
	end
	commitName(picker.name)
end

local function onPickerCellClick(cell)
	local picker = frame.picker
	picker.icon = cell.texture or nil
	picker.iconChanged = true
	frame.detail.icon:SetTexture(previewIcon(picker.icon))
	refreshPicker()
end

local function onPickerCellEnter(cell)
	GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
	if cell.texture then
		GameTooltip:SetText((cell.texture:gsub("^.*\\", "")), 1, 1, 1)
	else
		GameTooltip:SetText(L["Auto"], 1, 1, 1)
		GameTooltip:AddLine(L["The icon follows the first spell or item the macro casts."], nil, nil, nil, true)
	end
	GameTooltip:Show()
end

local function createPickerName(picker)
	local name = CreateFrame("EditBox", FRAME_NAME .. "IconsName", picker)
	name:SetSize(182, 20)
	name:SetPoint("TOPLEFT", 29, -35)
	name:SetAutoFocus(false)
	name:SetFontObject(ChatFontNormal)

	local left = name:CreateTexture(nil, "BACKGROUND")
	left:SetTexture(FILTER_BORDER)
	left:SetTexCoord(0, 0.09375, 0, 1)
	left:SetSize(12, 29)
	left:SetPoint("TOPLEFT", -11, 0)
	local middle = name:CreateTexture(nil, "BACKGROUND")
	middle:SetTexture(FILTER_BORDER)
	middle:SetTexCoord(0.09375, 0.90625, 0, 1)
	middle:SetSize(175, 29)
	middle:SetPoint("LEFT", left, "RIGHT")
	local right = name:CreateTexture(nil, "BACKGROUND")
	right:SetTexture(FILTER_BORDER)
	right:SetTexCoord(0.90625, 1, 0, 1)
	right:SetSize(12, 29)
	right:SetPoint("LEFT", middle, "RIGHT")

	name:SetScript("OnTextChanged", function(self)
		if picker:IsShown() then
			frame.detail.name:SetText(self:GetText())
		end
	end)
	name:SetScript("OnEnterPressed", applyPicker)
	name:SetScript("OnEscapePressed", function()
		picker:Hide()
	end)
	return name
end

local function createPicker()
	local picker = CreateFrame("Frame", FRAME_NAME .. "Icons", frame)
	picker:Hide()
	picker:SetSize(297, 298)
	picker:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -40)
	picker:SetToplevel(true)
	picker:EnableMouse(true)
	picker.filtered = {}

	for i = 1, #POPUP_ART do
		local art = POPUP_ART[i]
		local texture = picker:CreateTexture(nil, "BACKGROUND")
		texture:SetTexture(art[1])
		texture:SetSize(art[2], art[3])
		texture:SetPoint("TOPLEFT", art[4], art[5])
	end

	local nameLabel = ns.CreateLabel(picker, nil, "GameFontHighlightSmall")
	nameLabel:SetPoint("TOPLEFT", 24, -21)
	picker.nameLabel = nameLabel
	local chooseLabel = ns.CreateLabel(picker, MACRO_POPUP_CHOOSE_ICON, "GameFontHighlightSmall")
	chooseLabel:SetPoint("TOPLEFT", 24, -69)

	picker.name = createPickerName(picker)

	local search = ns.CreateEditBox(picker, 110, 18, FRAME_NAME .. "IconSearch", L["Search icons"])
	search:SetPoint("TOPRIGHT", -44, -64)
	search:HookScript("OnTextChanged", function()
		if not picker:IsShown() then
			return
		end
		pickerFilter(picker)
		FauxScrollFrame_SetOffset(picker.scroll, 0)
		picker.scroll.scrollBar:SetValue(0)
		refreshPicker()
	end)
	picker.search = search

	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "IconScroll", picker, "ClassTrainerListScrollFrameTemplate")
	scroll:SetSize(296, 195)
	scroll:SetPoint("TOPRIGHT", -39, -67)
	scroll.scrollBar = _G[scroll:GetName() .. "ScrollBar"]
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, PICKER_ROW_HEIGHT, refreshPicker)
	end)
	picker.scroll = scroll

	picker.cells = {}
	for i = 1, PICKER_COLUMNS * PICKER_ROWS do
		local cell = CreateFrame("CheckButton", FRAME_NAME .. "Icon" .. i, picker, "SimplePopupButtonTemplate")
		local column, row = (i - 1) % PICKER_COLUMNS, floor((i - 1) / PICKER_COLUMNS)
		cell:SetPoint("TOPLEFT", 24 + column * 46, -85 - row * 44)
		cell:SetNormalTexture(ns.Media.questionMark)
		cell.icon = cell:GetNormalTexture()
		cell.icon:ClearAllPoints()
		cell.icon:SetSize(36, 36)
		cell.icon:SetPoint("CENTER", 0, -1)
		cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		cell:GetHighlightTexture():SetBlendMode("ADD")
		cell:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
		cell:GetCheckedTexture():SetBlendMode("ADD")
		cell.auto = _G[cell:GetName() .. "Name"]
		cell:SetScript("OnClick", onPickerCellClick)
		cell:SetScript("OnEnter", onPickerCellEnter)
		cell:SetScript("OnLeave", GameTooltip_Hide)
		cell:EnableMouseWheel(true)
		cell:SetScript("OnMouseWheel", function(_, delta)
			ScrollFrameTemplate_OnMouseWheel(scroll, delta)
		end)
		picker.cells[i] = cell
	end

	local cancel = ns.CreateButton(picker, CANCEL, 78, BUTTON_HEIGHT, FRAME_NAME .. "IconsCancel")
	cancel:SetPoint("BOTTOMRIGHT", -11, 13)
	cancel:SetScript("OnClick", function()
		picker:Hide()
		PlaySound("gsTitleOptionOK")
	end)
	local okay = ns.CreateButton(picker, OKAY, 78, BUTTON_HEIGHT, FRAME_NAME .. "IconsOkay")
	okay:SetPoint("RIGHT", cancel, "LEFT", -2, 0)
	okay:SetScript("OnClick", function()
		applyPicker()
		PlaySound("gsTitleOptionOK")
	end)

	picker:SetScript("OnShow", function(self)
		local entry = editorEntry
		local virtual = isVirtual(entry)
		self.iconChanged = nil
		if virtual then
			self.icon = entry.icon
		else
			self.icon = select(2, GetMacroInfo(entry))
		end
		self.name:SetMaxLetters(virtual and 64 or 16)
		self.nameLabel:SetText(virtual and L["Enter Macro Name (Max 64 Characters):"] or MACRO_POPUP_TEXT)
		self.name:SetText(entryName(entry))
		pickerFilter(self)
		refreshPicker()
	end)
	picker:SetScript("OnHide", function(self)
		self.name:ClearFocus()
		refreshDetail()
	end)
	frame.picker = picker
end

function openPicker(focusName)
	if not editorEntry then
		return
	end
	if not frame.picker then
		createPicker()
	end
	frame.picker:Show()
	if focusName then
		frame.picker.name:SetFocus()
		frame.picker.name:HighlightText()
	end
end

local function togglePicker()
	if frame.picker and frame.picker:IsShown() then
		frame.picker:Hide()
	else
		openPicker()
	end
end

local function createEditor()
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetPoint("TOPLEFT", 18, -305)
	holder:SetSize(EDITOR_WIDTH, EDITOR_HEIGHT)
	holder:SetBackdrop(TOOLTIP_BACKDROP)
	holder:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	holder:SetBackdropColor(
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
	)

	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "EditorScroll", holder, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 9, -6)
	scroll:SetPoint("BOTTOMRIGHT", -30, 6)

	local edit = CreateFrame("EditBox", FRAME_NAME .. "Editor", scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(0)
	edit:SetMaxBytes(0)
	edit:SetWidth(EDITOR_WIDTH - 39)
	edit:SetHeight(EDITOR_HEIGHT - 12)
	edit:SetFontObject(GameFontHighlightSmall)
	edit:SetTextInsets(GUTTER_WIDTH + EDITOR_INSET, EDITOR_INSET, EDITOR_INSET, EDITOR_INSET)
	edit.cursorOffset, edit.cursorHeight = 0, 0
	scroll:SetScrollChild(edit)

	local gutterBg = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
	gutterBg:SetPoint("TOPLEFT", 5, -5)
	gutterBg:SetPoint("BOTTOMLEFT", 5, 5)
	gutterBg:SetWidth(GUTTER_WIDTH + 2)
	gutterBg:SetTexture(0, 0, 0, 0.25)

	local separator = holder:CreateTexture(nil, "BACKGROUND", nil, 2)
	separator:SetPoint("TOPLEFT", gutterBg, "TOPRIGHT")
	separator:SetPoint("BOTTOMLEFT", gutterBg, "BOTTOMRIGHT")
	separator:SetWidth(1)
	separator:SetTexture(1, 1, 1, 0.15)

	local numbers = edit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	numbers:SetJustifyH("RIGHT")
	numbers:SetJustifyV("TOP")
	numbers:SetPoint("TOPLEFT", 0, -EDITOR_INSET)
	numbers:SetWidth(GUTTER_WIDTH - 6)

	local measure = holder:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	measure:SetWidth(edit:GetWidth() - GUTTER_WIDTH - EDITOR_INSET * 2)
	measure:SetJustifyH("LEFT")
	measure:SetPoint("TOPLEFT")
	measure:SetAlpha(0)
	gutter.numbers, gutter.measure = numbers, measure

	edit:SetScript("OnTextChanged", onEditorTextChanged)
	edit:SetScript("OnCursorChanged", onEditorCursorChanged)
	edit:SetScript("OnUpdate", function(self, elapsed)
		ScrollingEdit_OnUpdate(self, elapsed, scroll)
	end)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnEditFocusGained", function(self)
		self.hasFocus = true
	end)
	edit:SetScript("OnEditFocusLost", function(self)
		self.hasFocus = false
		saveGameMacro()
	end)
	edit:SetScript("OnReceiveDrag", onEditorReceiveDrag)
	edit:SetScript("OnMouseUp", function(self)
		if GetCursorInfo() then
			onEditorReceiveDrag(self)
		end
	end)

	local focus = CreateFrame("Button", nil, holder)
	focus:SetAllPoints(scroll)
	focus:SetFrameLevel(scroll:GetFrameLevel() - 1)
	focus:SetScript("OnClick", function()
		edit:SetFocus()
		edit:SetCursorPosition(#edit:GetText())
	end)
	focus:SetScript("OnReceiveDrag", function()
		onEditorReceiveDrag(edit)
	end)

	local info = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	info:SetPoint("TOP", holder, "BOTTOM", 0, -4)
	frame.info = info

	frame.edit = edit
	frame.scroll = scroll
	frame.editorHolder = holder
end

local function onIssueEnter(row)
	local text = row.text
	if text:GetStringWidth() <= text:GetWidth() then
		return
	end
	local color = row.color or GRAY_FONT_COLOR
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(text:GetText(), color.r, color.g, color.b, 1, true)
	GameTooltip:Show()
end

local function createIssues()
	local panel = ns.CreateInset(frame, "tooltip", L["Problems"])
	panel:SetPoint("TOPLEFT", 526, -305)
	panel:SetSize(256, EDITOR_HEIGHT)

	local rows = {}
	for i = 1, ISSUE_ROWS do
		local row = CreateFrame("Button", nil, panel)
		row:SetSize(240, ISSUE_ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 8, -8 - (i - 1) * ISSUE_ROW_HEIGHT)
		ns.AddHighlight(row, "list")
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmallLeft")
		row.text:SetPoint("LEFT", 2, 0)
		row.text:SetPoint("RIGHT", -2, 0)
		row:SetScript("OnClick", function(self)
			jumpToLine(self.line)
		end)
		row:SetScript("OnEnter", onIssueEnter)
		row:SetScript("OnLeave", GameTooltip_Hide)
		row:Hide()
		rows[i] = row
	end
	frame.issueRows = rows

	local none = panel:CreateFontString(nil, "ARTWORK", "GameFontGreenSmall")
	none:SetPoint("TOPLEFT", 10, -10)
	none:SetText(L["No problems found"])
	frame.noIssues = none

	local legend = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	legend:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -4, -4)
	local c = Parser.COLORS
	legend:SetText(
		("|cff%s%s|r  |cff%s%s|r  |cff%s%s|r  |cff%s%s|r  |cff%s%s|r"):format(
			c.secure,
			L["command"],
			c.condition,
			L["condition"],
			c.item,
			L["item"],
			c.missing,
			L["missing"],
			c.error,
			L["error"]
		)
	)
end

local function onPlaceEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if isVirtual(editorEntry) then
		GameTooltip:SetText(L["Put on action bar"], 1, 1, 1)
		GameTooltip:AddLine(
			L["Creates a small game macro that runs this one and puts it on the cursor. It takes one game macro slot; key bindings need none."],
			nil,
			nil,
			nil,
			true
		)
	else
		GameTooltip:SetText(L["Make unlimited"], 1, 1, 1)
		GameTooltip:AddLine(
			L["Moves the text into an unlimited macro. The game macro stays where it is on your bars and runs the new one; its key bindings move too."],
			nil,
			nil,
			nil,
			true
		)
	end
	GameTooltip:Show()
end

local function createBindButton(detail, place)
	local bind = ns.CreateButton(detail, "", 180, BUTTON_HEIGHT, FRAME_NAME .. "BindButton")
	bind:SetPoint("RIGHT", place, "LEFT", -1, 0)
	bind:GetFontString():SetWidth(168)
	bind:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	bind:SetScript("OnClick", onBindClick)
	tooltip(
		bind,
		L["Key binding"],
		L["Left-click, then press a key or mouse button to bind it."],
		L["Right-click to clear."]
	)

	local catcher = CreateFrame("Button", nil, bind)
	catcher:SetAllPoints()
	catcher:Hide()
	catcher:EnableKeyboard(true)
	catcher:EnableMouseWheel(true)
	catcher:RegisterForClicks("AnyUp")
	catcher:SetScript("OnKeyDown", function(_, key)
		if key == "ESCAPE" then
			stopCapture(bind)
		elseif not IGNORED_KEYS[key] then
			bindKey(bind, key)
		end
	end)
	catcher:SetScript("OnMouseDown", function(_, button)
		bindKey(bind, button)
	end)
	catcher:SetScript("OnMouseWheel", function(_, delta)
		bindKey(bind, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
	end)
	catcher:SetScript("OnHide", function()
		bind.capturing = false
		bind:UnlockHighlight()
	end)
	bind.catcher = catcher
	return bind
end

local function createDetail()
	local barLeft = frame:CreateTexture(nil, "ARTWORK")
	barLeft:SetTexture(HORIZONTAL_BAR)
	barLeft:SetTexCoord(0, 1, 0, 0.25)
	barLeft:SetSize(256, 16)
	barLeft:SetPoint("TOPLEFT", 15, -220)
	local barRight = frame:CreateTexture(nil, "ARTWORK")
	barRight:SetTexture(HORIZONTAL_BAR)
	barRight:SetTexCoord(0, 0.29296875, 0.25, 0.5)
	barRight:SetSize(75, 16)
	barRight:SetPoint("TOPRIGHT", -15, -220)
	local barMiddle = frame:CreateTexture(nil, "ARTWORK")
	barMiddle:SetTexture(HORIZONTAL_BAR)
	barMiddle:SetTexCoord(0.3, 0.7, 0, 0.25)
	barMiddle:SetHeight(16)
	barMiddle:SetPoint("LEFT", barLeft, "RIGHT")
	barMiddle:SetPoint("RIGHT", barRight, "LEFT")

	local slot = frame:CreateTexture(nil, "ARTWORK")
	slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
	slot:SetSize(64, 64)
	slot:SetPoint("TOPLEFT", 16, -228)

	local enter = ns.CreateLabel(frame, ENTER_MACRO_LABEL, "GameFontHighlightSmall")
	enter:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 8, 0)

	local detail = CreateFrame("Frame", nil, frame)
	detail:SetAllPoints()
	frame.detail = detail

	local iconButton = CreateFrame("CheckButton", FRAME_NAME .. "SelectedButton", detail, "PopupButtonTemplate")
	iconButton:SetPoint("TOPLEFT", slot, "TOPLEFT", 14, -14)
	iconButton:SetScript("OnClick", function(self)
		self:SetChecked(nil)
		togglePicker()
	end)
	iconButton:RegisterForDrag("LeftButton")
	iconButton:SetScript("OnDragStart", function()
		pickupEntry(editorEntry)
	end)
	tooltip(iconButton, L["Icon"], L["Click to choose an icon, drag to put the macro on an action bar."])
	detail.icon = _G[iconButton:GetName() .. "Icon"]

	local name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	name:SetSize(310, 16)
	name:SetJustifyH("LEFT")
	name:SetPoint("TOPLEFT", slot, "TOPRIGHT", -4, -10)
	detail.name = name

	local change = ns.CreateButton(detail, CHANGE_MACRO_NAME_ICON, 170, BUTTON_HEIGHT, FRAME_NAME .. "EditButton")
	change:SetPoint("TOPLEFT", slot, "TOPLEFT", 51, -30)
	change:SetScript("OnClick", togglePicker)

	local subtitle = detail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	subtitle:SetPoint("BOTTOMRIGHT", frame.editorHolder, "TOPRIGHT", -4, 3)
	detail.subtitle = subtitle

	local runSlot = ns.CreateButton(detail, L["Run"], 80, BUTTON_HEIGHT, FRAME_NAME .. "RunSlot")
	runSlot:SetPoint("TOPRIGHT", -20, -258)
	runSlot:Disable()

	local place = ns.CreateButton(detail, "", 120, BUTTON_HEIGHT, FRAME_NAME .. "PlaceButton")
	place:SetPoint("RIGHT", runSlot, "LEFT", -1, 0)
	place:SetScript("OnClick", placeOrConvert)
	place:SetScript("OnEnter", onPlaceEnter)
	place:SetScript("OnLeave", GameTooltip_Hide)
	detail.place = place

	detail.bind = createBindButton(detail, place)

	frame.runSlot = runSlot

	local run = CreateFrame("Button", FRAME_NAME .. "Run", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
	run:Hide()
	run:SetFrameStrata("DIALOG")
	run:RegisterForClicks("LeftButtonUp")
	run:SetText(L["Run"])
	tooltip(run, L["Run"], L["Runs the macro as if its key was pressed."])
	frame.run = run
end

local function exportItem(scope, entry)
	if isVirtual(entry) then
		return { scope = scope, name = entry.name, icon = entry.icon, body = entry.body }
	end
	local name, texture, body = GetMacroInfo(entry)
	return {
		scope = scope,
		name = name,
		icon = texture ~= ns.Media.questionMark and texture or nil,
		body = (Parser.Decode(body or "")),
	}
end

local function stubTarget(entry)
	if isVirtual(entry) then
		return nil
	end
	local id = Macros.StubOf(select(3, GetMacroInfo(entry)))
	return id and Macros.FindById(id)
end

local function scopeItems(scope, items)
	if isGame(scope) then
		local first, last = gameRange(scope)
		for index = first, last do
			if not stubTarget(index) then
				items[#items + 1] = exportItem(scope, index)
			end
		end
	else
		local list = Macros.GetList(scope)
		for i = 1, #list do
			items[#items + 1] = exportItem(scope, list[i])
		end
	end
	return items
end

local function transferSummary(items)
	local counts = {}
	for i = 1, #items do
		local scope = items[i].scope
		counts[scope] = (counts[scope] or 0) + 1
	end
	local parts = {}
	for i = 1, #TABS do
		local count = counts[TABS[i].key]
		if count then
			parts[#parts + 1] = ("%s: %d"):format(L[TABS[i].label], count)
		end
	end
	return L["%d macros"]:format(#items) .. " - " .. table.concat(parts, ", ")
end

local transfer

local function createTransfer()
	transfer = ns.CreateWindow(
		FRAME_NAME .. "Transfer",
		{ width = 520, height = 340, header = true, strata = "DIALOG", movable = false }
	)
	transfer:SetPoint("CENTER")

	local holder = CreateFrame("Frame", nil, transfer)
	holder:SetPoint("TOPLEFT", 16, -30)
	holder:SetPoint("BOTTOMRIGHT", -16, 16 + BUTTON_HEIGHT + 24)
	holder:SetBackdrop(TOOLTIP_BACKDROP)
	holder:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	holder:SetBackdropColor(
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
		TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
	)

	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "TransferScroll", holder, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 9, -6)
	scroll:SetPoint("BOTTOMRIGHT", -30, 6)

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetMaxLetters(0)
	box:SetMaxBytes(0)
	box:SetWidth(520 - 32 - 39)
	box:SetFontObject(GameFontHighlightSmall)
	box:SetTextInsets(2, 2, 2, 2)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnTextChanged", function(self)
		scroll:UpdateScrollChildRect()
		if transfer.importing then
			local items, err = Macros.DecodeExport(self:GetText())
			transfer.items = items
			local color
			if items then
				transfer.summary:SetText(transferSummary(items))
				color = GREEN_FONT_COLOR
			else
				transfer.summary:SetText(strtrim(self:GetText()) == "" and "" or err)
				color = RED_FONT_COLOR
			end
			transfer.summary:SetTextColor(color.r, color.g, color.b)
			ns.SetShown(transfer.action, items ~= nil)
		end
	end)
	scroll:SetScrollChild(box)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	transfer.box = box

	local summary = transfer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 6, -6)
	summary:SetPoint("RIGHT", holder, -6, 0)
	summary:SetJustifyH("LEFT")
	transfer.summary = summary

	local close = ns.CreateButton(transfer, CLOSE, 90, BUTTON_HEIGHT, FRAME_NAME .. "TransferClose")
	close:SetPoint("BOTTOMRIGHT", -16, 16)
	close:SetScript("OnClick", function()
		transfer:Hide()
	end)

	local action = ns.CreateButton(transfer, L["Import"], 90, BUTTON_HEIGHT, FRAME_NAME .. "TransferImport")
	action:SetPoint("RIGHT", close, "LEFT", -2, 0)
	transfer.action = action
end

local function showExport(heading, items)
	if #items == 0 then
		ns.Print(L["nothing to export"])
		return
	end
	if not transfer then
		createTransfer()
	end
	transfer.importing = false
	transfer.title:SetText(heading)
	transfer.action:Hide()
	transfer.summary:SetText(transferSummary(items))
	transfer.summary:SetTextColor(1, 1, 1)
	transfer.box:SetText(Macros.Export(items))
	transfer:Show()
	transfer.box:SetFocus()
	transfer.box:HighlightText()
end

local function importItems()
	local items = transfer.items
	if not items then
		return
	end
	local count, converted, scope, entry = Macros.Import(items)
	transfer:Hide()
	ns.Print(L["%d macros imported"], count)
	if converted > 0 then
		ns.Print(
			L["%d game macros did not fit (no free slot, longer than 255 characters or in combat) and became unlimited ones"],
			converted
		)
	end
	if scope then
		selectTab(scope)
		selectEntry(entry)
	end
end

local function showImport()
	if not transfer then
		createTransfer()
	end
	transfer.importing = true
	transfer.items = nil
	transfer.title:SetText(L["Import macros"])
	transfer.action:SetScript("OnClick", importItems)
	transfer.box:SetText("")
	transfer:Show()
	transfer.box:SetFocus()
end

local function exportSelected()
	local entry = selected()
	if not entry then
		return
	end
	local target = stubTarget(entry)
	local item = target and exportItem(Macros.ScopeOf(target), target) or exportItem(tab, entry)
	showExport(L["Export macro: %s"]:format((displayName(target or entry))), { item })
end

local function exportTab()
	for i = 1, #TABS do
		if TABS[i].key == tab then
			showExport(L["Export: %s"]:format(L[TABS[i].label]), scopeItems(tab, {}))
		end
	end
end

local function exportAll()
	local items = {}
	for i = 1, #TABS do
		scopeItems(TABS[i].key, items)
	end
	showExport(L["Export all macros"], items)
end

local EXPORT_CHOICES = {
	{ label = "Selected macro", func = exportSelected },
	{ label = "This tab", func = exportTab },
	{ label = "All macros", func = exportAll },
}

local function onMenuUpdate(menu, elapsed)
	if menu:IsMouseOver() or menu.owner and menu.owner:IsMouseOver() then
		menu.idle = 0
		return
	end
	if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
		menu:Hide()
		return
	end
	menu.idle = (menu.idle or 0) + elapsed
	if menu.idle > MENU_HIDE_DELAY then
		menu:Hide()
	end
end

local function onMenuButtonClick(button)
	button:GetParent():Hide()
	if button.func then
		button.func()
	end
end

local function createMenu(style)
	local menu = CreateFrame("Frame", nil, frame)
	menu:Hide()
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:SetBackdrop(MENU_BACKDROPS[style])
	if style == "menu" then
		menu:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
		menu:SetBackdropColor(
			TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
			TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
			TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
		)
	end
	menu.buttons = {}
	menu:SetScript("OnUpdate", onMenuUpdate)
	return menu
end

local function menuButton(menu, index)
	local button = menu.buttons[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, menu)
	button:SetHeight(MENU_BUTTON_HEIGHT)
	button:SetPoint("TOPLEFT", 15, -15 - (index - 1) * MENU_BUTTON_HEIGHT)
	ns.AddHighlight(button, "list")
	local text = button:CreateFontString(nil, "ARTWORK")
	text:SetPoint("LEFT")
	button:SetFontString(text)
	button:SetNormalFontObject(GameFontHighlightSmallLeft)
	button:SetHighlightFontObject(GameFontHighlightSmallLeft)
	button:SetScript("OnClick", onMenuButtonClick)
	menu.buttons[index] = button
	return button
end

local function openMenu(menu, items, owner, point, relativeTo, relativePoint, x, y)
	local width = 0
	for i = 1, #items do
		local item = items[i]
		local button = menuButton(menu, i)
		button.func = item.func
		button:SetDisabledFontObject(item.title and GameFontNormalSmallLeft or GameFontDisableSmallLeft)
		button:SetText(item.text)
		if item.title then
			button:Disable()
		else
			button:Enable()
		end
		width = max(width, button:GetTextWidth())
		button:Show()
	end
	for i = #items + 1, #menu.buttons do
		menu.buttons[i]:Hide()
	end
	for i = 1, #items do
		menu.buttons[i]:SetWidth(width + 20)
	end
	menu:SetSize(width + 45,#items * MENU_BUTTON_HEIGHT + 30)
	menu:ClearAllPoints()
	menu:SetPoint(point, relativeTo, relativePoint, x, y)
	menu.owner = owner
	menu.idle = 0
	menu:Show()
end

local function openEntryMenu(cell)
	local entry = cell.entry
	if not frame.entryMenu then
		frame.entryMenu = createMenu("menu")
	end
	local virtual = isVirtual(entry)
	local items = {
		{ text = (displayName(entry)), title = true },
		{ text = virtual and L["Put on action bar"] or L["Make unlimited"], func = placeOrConvert },
	}
	if virtual then
		items[#items + 1] = { text = L["Copy"], func = copySelected }
	end
	items[#items + 1] = { text = L["Export"], func = exportSelected }
	items[#items + 1] = { text = DELETE, func = deleteSelected }
	items[#items + 1] = { text = CANCEL }
	local x, y = GetCursorPosition()
	local scale = frame.entryMenu:GetEffectiveScale()
	openMenu(frame.entryMenu, items, cell, "TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function onCellClick(cell, button)
	local entry = cell.entry
	if not entry then
		cell:SetChecked(nil)
		return
	end
	if entry ~= selected() then
		selectEntry(entry)
	else
		cell:SetChecked(true)
	end
	if button == "RightButton" then
		openEntryMenu(cell)
	end
end

local function createCell(index)
	local cell = CreateFrame("CheckButton", FRAME_NAME .. "Button" .. index, frame, "PopupButtonTemplate")
	local column, row = (index - 1) % COLUMNS, floor((index - 1) / COLUMNS)
	cell:SetPoint("TOPLEFT", 29 + column * COLUMN_WIDTH, -82 - row * ROW_HEIGHT)
	cell.icon = _G[cell:GetName() .. "Icon"]
	cell.name = _G[cell:GetName() .. "Name"]
	local key = cell:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	key:SetSize(36, 10)
	key:SetPoint("TOPLEFT", -2, -2)
	key:SetJustifyH("RIGHT")
	cell.key = key
	cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cell:RegisterForDrag("LeftButton")
	cell:SetScript("OnClick", onCellClick)
	cell:SetScript("OnDragStart", onCellDrag)
	cell:SetScript("OnEnter", onCellEnter)
	cell:SetScript("OnLeave", GameTooltip_Hide)
	cell:EnableMouseWheel(true)
	cell:SetScript("OnMouseWheel", function(_, delta)
		ScrollFrameTemplate_OnMouseWheel(frame.listScroll, delta)
	end)
	return cell
end

local function createButtonBar()
	local delete = ns.CreateButton(frame, DELETE, 80, BUTTON_HEIGHT, FRAME_NAME .. "DeleteButton", true)
	delete:SetPoint("BOTTOMLEFT", 16, 14)
	delete:SetScript("OnClick", deleteSelected)

	frame.copy = ns.CreateButton(frame, L["Copy"], 80, BUTTON_HEIGHT, FRAME_NAME .. "CopyButton")
	frame.copy:SetPoint("LEFT", delete, "RIGHT", 1, 0)
	frame.copy:SetScript("OnClick", copySelected)

	local exit = ns.CreateButton(frame, EXIT, 80, BUTTON_HEIGHT, FRAME_NAME .. "ExitButton")
	exit:SetPoint("BOTTOMRIGHT", -16, 14)
	exit:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame.new = ns.CreateButton(frame, NEW, 80, BUTTON_HEIGHT, FRAME_NAME .. "NewButton")
	frame.new:SetPoint("RIGHT", exit, "LEFT", -1, 0)
	frame.new:SetScript("OnClick", createNew)

	local exportItems = {}
	for i = 1, #EXPORT_CHOICES do
		exportItems[i] = { text = L[EXPORT_CHOICES[i].label], func = EXPORT_CHOICES[i].func }
	end
	frame.exportMenu = createMenu("dark")
	local export = ns.CreateButton(frame, L["Export"], 80, BUTTON_HEIGHT, FRAME_NAME .. "ExportButton")
	export:SetPoint("RIGHT", frame.new, "LEFT", -1, 0)
	export:SetScript("OnClick", function(self)
		if frame.exportMenu:IsShown() then
			frame.exportMenu:Hide()
		else
			openMenu(frame.exportMenu, exportItems, self, "BOTTOMLEFT", self, "TOPLEFT", 0, 0)
		end
	end)

	local import = ns.CreateButton(frame, L["Import"], 80, BUTTON_HEIGHT, FRAME_NAME .. "ImportButton")
	import:SetPoint("RIGHT", export, "LEFT", -1, 0)
	import:SetScript("OnClick", showImport)
end

local function createFrame()
	frame = ns.CreateWindow(FRAME_NAME, { width = WIDTH, height = HEIGHT, title = L["Macros"], movable = false })
	frame:SetPoint("CENTER")

	local labels = {}
	for i = 1, #TABS do
		labels[i] = L[TABS[i].label]
	end
	frame.tabs = ns.CreateTabs(frame, labels, {
		style = "tall",
		padding = -15,
		point = { "TOPLEFT", frame, "TOPLEFT", 20, -39 },
		onSelect = function(index)
			selectTab(TABS[index].key)
		end,
	})

	local listScroll = ns.CreateFauxScrollFrame(frame, FRAME_NAME .. "ListScroll", true)
	listScroll:SetPoint("TOPLEFT", 23, -76)
	listScroll:SetSize(COLUMNS * COLUMN_WIDTH, 146)
	listScroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, refreshList)
	end)
	frame.listScroll = listScroll
	frame.listScrollBar = listScroll.scrollBar

	frame.cells = {}
	for i = 1, COLUMNS * LIST_ROWS do
		frame.cells[i] = createCell(i)
	end

	createButtonBar()
	createEditor()
	createIssues()
	createDetail()

	frame:SetScript("OnShow", function()
		PlaySound("igCharacterInfoOpen")
		refresh(true)
		updateRunButton()
	end)
	frame:SetScript("OnHide", function()
		PlaySound("igCharacterInfoClose")
		saveGameMacro()
		frame.edit:ClearFocus()
		if frame.picker then
			frame.picker:Hide()
		end
		frame.exportMenu:Hide()
		if frame.entryMenu then
			frame.entryMenu:Hide()
		end
		if transfer then
			transfer:Hide()
		end
		if not InCombatLockdown() then
			frame.run:Hide()
		end
	end)

	hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
end

local function show()
	if not frame then
		createFrame()
	end
	frame:Show()
end

local function toggle()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		show()
	end
end
Macros.Toggle = toggle

local function onKnowledgeChanged(_, reason)
	if not frame or not frame:IsShown() then
		return
	end
	if reason == "knowledge" then
		wipe(errorCounts)
	end
	ns.Defer(frame, function()
		refresh()
		if editorEntry then
			local _, cursorRaw = Parser.Decode(frame.edit:GetText(), frame.edit:GetCursorPosition())
			analyzeEditor(frame.edit.hasFocus and cursorRaw or nil)
		end
	end)
end

Macros:OnInitialize(function(self)
	ShowMacroFrame = show
	SlashCmdList.MACRO = toggle

	self:RegisterEvent(Macros.CHANGED, onKnowledgeChanged)
	self:RegisterEvent("UPDATE_MACROS", function()
		if not frame or not frame:IsShown() then
			return
		end
		if isGame() and not frame.edit.hasFocus then
			refresh(true)
		else
			refresh()
		end
	end)
	self:RegisterEvent("UPDATE_BINDINGS", function()
		if frame and frame:IsShown() then
			refreshList()
			refreshDetail()
		end
	end)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		if frame then
			frame.run:Hide()
			if frame.detail.bind.capturing then
				stopCapture(frame.detail.bind)
			end
			showInfo()
		end
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if frame and frame:IsShown() then
			updateRunButton()
			showInfo()
		end
	end)
end)
