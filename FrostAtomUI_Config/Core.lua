local ADDON_NAME, ns = ...

local ui = FrostAtomUI
local L = ui.L

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local tinsert, sort = tinsert, table.sort

local FRAME_NAME = ADDON_NAME .. "Frame"
local WIDTH, HEIGHT = 780, 600
local EDGE = 16
local LIST_X, LIST_TOP, LIST_WIDTH = 22, -64, 175
local PANEL_X, PANEL_TOP, PANEL_RIGHT = 213, -40, -22
local FOOTER_TOP = 50
local SCROLL_LEFT, SCROLL_TOP, SCROLL_RIGHT, SCROLL_BOTTOM = 8, -40, -27, 6
local CONTENT_WIDTH = WIDTH - PANEL_X + PANEL_RIGHT - SCROLL_LEFT + SCROLL_RIGHT
local NAV_BUTTON_HEIGHT = 18
local NAV_GROUP_GAP = 8
local FOOTER_BUTTON_WIDTH = 96
local SEARCH_DELAY = 0.2
local ROW_HEIGHT = 26
local HEADER_HEIGHT = 30
local SECTION_GAP = 12
local CONTENT_TOP = 4
local INLINE_FLAT_CONTROLS = 12
local CONTENT_BOTTOM = 20
local LABEL_X = 8
local CHILD_INDENT = 16
local CONTROL_X = 230
local SLIDER_WIDTH = 180
local FONT_SLIDER_WIDTH = 80
local VALUE_BOX_WIDTH = 44
local REVERT_SECONDS = 8
local ELEMENT_WIDTH = EDGE * 2 + SCROLL_LEFT - SCROLL_RIGHT + CONTENT_WIDTH
local ELEMENT_TOP = -30
local ELEMENT_BOTTOM = 46
local ELEMENT_GAP = 8
local ELEMENT_MIN_HEIGHT = 140
local ELEMENT_MAX_HEIGHT = 560
local ELEMENT_STRATA = "FULLSCREEN"
local POPUP_STRATA = "FULLSCREEN_DIALOG"
local FONT_SIZE_MIN, FONT_SIZE_MAX = 6, 32
local HIGHLIGHT_TEXTURE = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
local HIGHLIGHT_COLOR = { 0.196, 0.388, 0.8 }
local SPACER_TEXTURE = "Interface\\OptionsFrame\\UI-OptionsFrame-Spacer"
local LIST_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local SWATCH_TEXTURE = "Interface\\ChatFrame\\ChatFrameColorSwatch"
local GLYPH_SIZE = 12
local GLYPH_BOX = GLYPH_SIZE + 4
local GLYPH_GAP = 4
local TITLE_GLYPH_SIZE = 16
local MARKER_SIZE = 10
local SEARCH_INSET = 14
local NAV_GLYPH_X = 6
local RELOAD_COLOR = { r = 1, g = 0.5, b = 0.25 }
ns.CONTROL_X = CONTROL_X

local FONT_OBJECTS = {
	"GameFontNormal",
	"GameFontNormalSmall",
	"GameFontNormalLarge",
	"GameFontHighlight",
	"GameFontHighlightSmall",
	"GameFontDisable",
	"GameFontDisableSmall",
	"GameFontGreenSmall",
}

local OUTLINES = { { "", L["None"] }, { "OUTLINE", L["Outline"] }, { "THICKOUTLINE", L["Thick outline"] } }

local pages = {}
local elements = {}
local elementsByPath = {}
local elementMatchers = {}
local elementInstances = {}
local frame
local elementFrame
local currentPage
local lastNavPage
local refreshing = false
local widgetCount = 0
local changes = {}

local searchPage = { key = "search", name = L["Search"], glyph = "magnifying-glass", schema = {}, noReset = true }

local function adoptEntries(schema, owner)
	for _, entry in ipairs(schema) do
		entry.page = owner
	end
end

function ns.RegisterPage(page)
	page.schema = page.schema or {}
	adoptEntries(page.schema, page)
	for _, tab in ipairs(page.tabs or {}) do
		tab.schema = tab.schema or {}
		adoptEntries(tab.schema, page)
	end
	tinsert(pages, page)
	sort(pages, function(a, b)
		return a.order < b.order
	end)
end

function ns.RegisterElement(element)
	if element.match then
		tinsert(elementMatchers, element)
		return
	end
	element.key = "element:" .. element.path
	element.schema = element.schema or {}
	adoptEntries(element.schema, element)
	tinsert(elements, element)
	elementsByPath[element.path] = element
end

local function instantiateMatcher(matcher, path)
	local name = matcher.name
	if type(name) == "function" then
		name = name(path)
	end
	local element = {
		key = "element:" .. path,
		path = path,
		page = matcher.page,
		tab = matcher.tab,
		name = name,
		glyph = matcher.glyph,
		schema = matcher.build and matcher.build(path) or {},
		noReset = true,
	}
	adoptEntries(element.schema, element)
	elementInstances[path] = element
	return element
end

local function elementFor(path)
	local element = elementsByPath[path] or elementInstances[path]
	if element then
		return element
	end
	for _, matcher in ipairs(elementMatchers) do
		if path:match(matcher.match) then
			return instantiateMatcher(matcher, path)
		end
	end
	return { key = "element:" .. path, path = path, name = ui.Movers.GetLabel(path), schema = {} }
end

local function elementButton(element, page, enabledBy)
	return {
		type = "execute",
		label = element.name,
		text = L["Move"],
		width = 110,
		element = element,
		desc = L["Open this frame in move mode; the window next to it holds its size and position settings."],
		enabledBy = element.enabledBy or enabledBy,
		disabled = element.disabled,
		new = element.new,
		glyph = element.glyph or "up-down-left-right",
		page = page,
		func = function()
			ns.EditElement(element.path)
		end,
		isDefault = function()
			return changes.Count(element.schema) == 0
		end,
	}
end

local function addRequirement(entry, enabledBy)
	entry.enabledBy = entry.enabledBy and { enabledBy, entry.enabledBy } or enabledBy
end
ns.AddRequirement = addRequirement

function ns.Requires(enabledBy, entries)
	for _, entry in ipairs(entries) do
		if entry.path then
			addRequirement(entry, enabledBy)
		end
	end
	return entries
end

local function prefixPaths(prefix, entries)
	for _, entry in ipairs(entries) do
		if entry.path then
			entry.path = prefix .. "." .. entry.path
		end
		if entry.pathY then
			entry.pathY = prefix .. "." .. entry.pathY
		end
	end
end

function ns.ElementSchema(prefix, entries)
	prefixPaths(prefix, entries)
	return ns.Requires(prefix .. ".enabled", entries)
end

function ns.Section(schema, header, prefix, entries, hidden, new, glyph)
	if hidden then
		return schema
	end
	local enable = prefix .. ".enabled"
	prefixPaths(prefix, entries)
	schema[#schema + 1] = { header = header, new = new, glyph = glyph }
	for _, entry in ipairs(entries) do
		if entry.path ~= enable then
			addRequirement(entry, enable)
		end
		schema[#schema + 1] = entry
	end
	return schema
end

function ns.NotClass(class)
	return ui.PLAYER_CLASS ~= class
end

function ns.ClickThrough(path, enabledBy, enabledByAny)
	return {
		path = path,
		new = "1.4.1",
		label = L["Click-through"],
		type = "toggle",
		advanced = true,
		enabledBy = enabledBy,
		enabledByAny = enabledByAny,
		desc = L["The icons ignore the mouse: no tooltips and no right-click, clicks pass through to the world behind them."],
	}
end

local function nextName()
	widgetCount = widgetCount + 1
	return FRAME_NAME .. "Widget" .. widgetCount
end

local function round(value, step)
	return floor(value / step + 0.5) * step
end

local function formatNumber(value, step)
	if step >= 1 then
		return tostring(floor(value + 0.5))
	end
	local text = ("%.2f"):format(value):gsub("0+$", "")
	return (text:gsub("%.$", ""))
end

local function formatValue(entry, value)
	if entry.zeroText and value == 0 then
		return entry.zeroText
	end
	if entry.percent then
		return formatNumber(value * 100, entry.step * 100) .. "%"
	end
	local unit = entry.unit and ns.UNITS[entry.unit]
	if unit then
		return unit:format(formatNumber(value, entry.step))
	end
	return formatNumber(value, entry.step)
end

local function parseValue(entry, text)
	text = strtrim(text)
	if entry.zeroText and text:lower() == entry.zeroText:lower() then
		return 0
	end
	local number = text:match("^[-+]?[%d.,]+")
	local value = number and tonumber((number:gsub(",", ".")))
	if value and entry.percent then
		return value / 100
	end
	return value
end

local fontObjects = {}

local function font(name)
	return fontObjects[name] or _G[name]
end
ns.Font = font

local function initFonts()
	local locale = ui.LOCALE
	if not locale or ui.CanRenderLocale(locale, (GameFontNormal:GetFont())) then
		return
	end
	for _, name in ipairs(FONT_OBJECTS) do
		local source = _G[name]
		local object = CreateFont(FRAME_NAME .. name)
		object:CopyFontObject(source)
		local _, size, flags = source:GetFont()
		object:SetFont(ui.Media.font, size, flags)
		fontObjects[name] = object
	end
end
initFonts()

local function setButtonFonts(button, normal, highlight, disabled)
	button:SetNormalFontObject(font(normal or "GameFontNormal"))
	button:SetHighlightFontObject(font(highlight or "GameFontHighlight"))
	button:SetDisabledFontObject(font(disabled or "GameFontDisable"))
end

local function setTextEnabled(region, enabled)
	local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
	region:SetTextColor(color.r, color.g, color.b)
end

local function createGlyph(parent, name, size, color)
	local glyph = ui.CreateGlyph(parent, name, size)
	glyph:SetTextColor(color.r, color.g, color.b)
	return glyph
end

local function paintButtonGlyph(button)
	local color = NORMAL_FONT_COLOR
	if button:IsEnabled() ~= 1 then
		color = GRAY_FONT_COLOR
	elseif button.hovered or button.gray then
		color = HIGHLIGHT_FONT_COLOR
	end
	button.glyph:SetTextColor(color.r, color.g, color.b)
end

local function hoverButtonGlyph(button)
	button.hovered = true
	paintButtonGlyph(button)
end

local function leaveButtonGlyph(button)
	button.hovered = nil
	paintButtonGlyph(button)
end

local function addButtonGlyph(button, name, minWidth, gray)
	local glyph = ui.CreateGlyph(button, name, GLYPH_SIZE)
	local width = glyph:GetStringWidth()
	local text = button:GetFontString()
	text:ClearAllPoints()
	text:SetPoint("CENTER", (width + GLYPH_GAP) / 2, 0)
	glyph:SetPoint("RIGHT", text, "LEFT", -GLYPH_GAP, 0)
	button.glyph = glyph
	button.gray = gray
	button:HookScript("OnEnter", hoverButtonGlyph)
	button:HookScript("OnLeave", leaveButtonGlyph)
	button:HookScript("OnEnable", paintButtonGlyph)
	button:HookScript("OnDisable", paintButtonGlyph)
	paintButtonGlyph(button)
	ui.FitButton(button, 20 + width + GLYPH_GAP, minWidth)
end

local function setControlEnabled(control, enabled)
	if enabled then
		control:Enable()
	else
		control:Disable()
	end
end

local function playCheckSound(check)
	PlaySound(check:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
end

local function versionValue(version)
	local major, minor, patch = tostring(version or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
	if not major then
		return 0
	end
	return tonumber(major) * 1000000 + (tonumber(minor) or 0) * 1000 + (tonumber(patch) or 0)
end

local releaseValue = floor(versionValue(GetAddOnMetadata("FrostAtomUI", "Version")) / 1000) * 1000
local seenAtOpen = {}

local function seenStore()
	local db = ui.db
	db.seenNew = db.seenNew or {}
	return db.seenNew
end

local function isUnseen(new, pageKey, seen)
	if not new then
		return false
	end
	local value = versionValue(new)
	return value >= releaseValue and value > versionValue(seen[pageKey])
end

local function isNewEntry(entry)
	local page = entry.page
	return page and isUnseen(entry.new, page.path and page.page or page.key, seenAtOpen) or false
end

local function newestIn(schema, key, seen, newest)
	for _, entry in ipairs(schema) do
		if isUnseen(entry.new, key, seen) and versionValue(entry.new) > versionValue(newest) then
			newest = entry.new
		end
	end
	return newest
end

local function newestUnseen(page)
	local seen = seenStore()
	local newest = isUnseen(page.new, page.key, seen) and page.new or nil
	newest = newestIn(page.schema, page.key, seen, newest)
	for _, tab in ipairs(page.tabs or {}) do
		newest = newestIn(tab.schema, page.key, seen, newest)
	end
	for _, element in ipairs(elements) do
		if element.page == page.key and not element.hidden then
			newest = newestIn(element.schema, page.key, seen, newest)
		end
	end
	return newest
end

local function markSeen(page)
	local newest = newestUnseen(page)
	if newest then
		seenStore()[page.key] = newest
	end
end

local function addNewBadge(parent, anchor, offset)
	local badge = parent:CreateFontString(nil, "OVERLAY")
	badge:SetFontObject(font("GameFontGreenSmall"))
	badge:SetText(L["NEW"])
	badge:SetPoint("LEFT", anchor, "LEFT", offset, 0)
	return badge
end

local function hasParentToggle(paths)
	if type(paths) == "table" then
		for i = 1, #paths do
			if hasParentToggle(paths[i]) then
				return true
			end
		end
		return false
	end
	return paths ~= nil and not paths:find("enabled$")
end

local function isChildEntry(entry)
	if entry.indent ~= nil then
		return entry.indent
	end
	return hasParentToggle(entry.enabledBy) or hasParentToggle(entry.enabledByAny)
end

local requirementText

local function rowEnter(row)
	row.highlight:Show()
	local entry = row.entry
	local range = entry.type == "number"
	local requirement = row.disabled and requirementText(entry)
	local default = row.modified and changes.DefaultText(entry)
	local problem = row.problem
	local wheel = range or entry.type == "font" or entry.type == "offset" or entry.type == "point"
	if not entry.desc and not wheel and not entry.reload and not requirement and not default and not problem then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(entry.label, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if entry.desc then
		GameTooltip:AddLine(entry.desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end
	if problem then
		GameTooltip:AddLine(problem.text, problem.color.r, problem.color.g, problem.color.b, true)
	end
	if requirement then
		GameTooltip:AddLine(requirement, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
	end
	if entry.reload then
		GameTooltip:AddLine(L["Requires a UI reload."], RELOAD_COLOR.r, RELOAD_COLOR.g, RELOAD_COLOR.b, true)
	end
	if range then
		GameTooltip:AddLine(
			("%s - %s"):format(formatValue(entry, entry.min), formatValue(entry, entry.max)),
			GRAY_FONT_COLOR.r,
			GRAY_FONT_COLOR.g,
			GRAY_FONT_COLOR.b
		)
	end
	if default then
		GameTooltip:AddLine(L["Default: %s"]:format(default), GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	end
	if wheel then
		GameTooltip:AddLine(
			L["Shift + mouse wheel changes the value."],
			GRAY_FONT_COLOR.r,
			GRAY_FONT_COLOR.g,
			GRAY_FONT_COLOR.b
		)
	end
	GameTooltip:Show()
end

local function rowLeave(row)
	row.highlight:Hide()
	GameTooltip:Hide()
end

local function bindRow(control, row)
	control:HookScript("OnEnter", function()
		rowEnter(row)
	end)
	control:HookScript("OnLeave", function()
		rowLeave(row)
	end)
end

local function bindHighlight(control, row)
	control:HookScript("OnEnter", function()
		row.highlight:Show()
	end)
	control:HookScript("OnLeave", function()
		row.highlight:Hide()
	end)
end

local function createButton(parent, text, width, gray, height, glyph)
	local button = ui.CreateButton(parent, text, width, height or 22, nextName(), gray)
	setButtonFonts(button, gray and "GameFontHighlight" or "GameFontNormal")
	if glyph then
		addButtonGlyph(button, glyph, width, gray)
	else
		ui.FitButton(button, 20, width)
	end
	return button
end
ns.CreateButton = createButton

local function createWindow(name, options)
	local window = ui.CreateWindow(name, options)
	window.title:SetFontObject(font("GameFontNormal"))
	window.heading = window.title
	return window
end
ns.CreateWindow = createWindow

local function createEditBox(parent, width, numeric)
	local box = ui.CreateEditBox(parent, width, 20, nextName())
	if numeric then
		box:SetMaxLetters(7)
	end
	box:HookScript("OnEditFocusGained", function(self)
		self.editing = true
		self.committed = self:GetText()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self.cancelled = true
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	box:SetScript("OnEditFocusLost", function(self)
		self.editing = nil
		self:HighlightText(0, 0)
		if self.cancelled then
			self.cancelled = nil
			self:SetText(self.committed or "")
			self:SetCursorPosition(0)
			if self.OnCancel then
				self:OnCancel()
			end
		elseif self.OnCommit then
			self:OnCommit()
		end
	end)
	return box
end

local function setEditBoxEnabled(box, enabled)
	box:EnableMouse(enabled)
	setTextEnabled(box, enabled)
	if not enabled then
		box:ClearFocus()
	end
end

local function createDropdown(parent, width, getValues, onSelect)
	local dropdown = ui.CreateDropdown(parent, width, getValues, onSelect, nextName())
	local text = _G[dropdown:GetName() .. "Text"]
	text:SetFontObject(font("GameFontHighlightSmall"))
	text:SetJustifyH("LEFT")
	return dropdown
end

local function createCheckButton(parent, template)
	local check = CreateFrame("CheckButton", nextName(), parent, template or "OptionsBaseCheckButtonTemplate")
	check:SetHitRectInsets(0, 0, 0, 0)
	return check
end

local function createRow(parent, entry)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("LEFT")
	row:SetPoint("RIGHT")
	row.entry = entry
	row:EnableMouse(true)
	row:SetScript("OnEnter", rowEnter)
	row:SetScript("OnLeave", rowLeave)

	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(HIGHLIGHT_TEXTURE)
	highlight:SetBlendMode("ADD")
	highlight:SetVertexColor(HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3], 0.35)
	highlight:SetAllPoints()
	highlight:Hide()
	row.highlight = highlight

	local indent = isChildEntry(entry) and CHILD_INDENT or 0
	local width = CONTROL_X - LABEL_X - 10 - indent
	if entry.reload then
		width = width - MARKER_SIZE - GLYPH_GAP
	end
	local label = row:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(font("GameFontHighlight"))
	label:SetPoint("LEFT", LABEL_X + indent, 0)
	label:SetWidth(width)
	label:SetJustifyH("LEFT")
	label:SetText(entry.label)
	row.label = label
	row:SetHeight(max(ROW_HEIGHT, label:GetStringHeight() + 8))

	local offset = min(label:GetStringWidth(), width) + GLYPH_GAP
	if entry.reload then
		local marker = createGlyph(row, "rotate", MARKER_SIZE, RELOAD_COLOR)
		marker:SetPoint("LEFT", label, "LEFT", offset, 0)
		offset = offset + marker:GetStringWidth() + GLYPH_GAP
	end
	if isNewEntry(entry) then
		addNewBadge(row, label, offset)
	end
	changes.Attach(row, entry)
	return row
end

local function get(entry)
	if entry.get then
		return entry.get()
	end
	return ui:GetConfig(entry.path)
end

local confirmRevert

do
	local function applyValue(entry, value)
		if entry.set then
			entry.set(value)
		else
			ui:SetConfig(entry.path, value)
		end
	end

	local revertEntry, revertValue

	local function revertText(seconds)
		return L["Keep these settings? Reverting in %d s."]:format(seconds)
	end

	StaticPopupDialogs["FROSTATOMUI_CONFIG_REVERT"] = {
		text = "%s",
		button1 = L["Keep"],
		button2 = L["Revert"],
		OnAccept = function()
			revertEntry, revertValue = nil, nil
		end,
		OnUpdate = function(dialog)
			_G[dialog:GetName() .. "Text"]:SetText(revertText(ceil(dialog.timeleft)))
		end,
		OnHide = function()
			local entry, value = revertEntry, revertValue
			revertEntry, revertValue = nil, nil
			if entry then
				applyValue(entry, value)
			end
		end,
		timeout = REVERT_SECONDS,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = 3,
	}

	function confirmRevert(entry, previous)
		local name = StaticPopup_Visible("FROSTATOMUI_CONFIG_REVERT")
		if name and revertEntry == entry then
			_G[name].timeleft = REVERT_SECONDS
			return
		end
		if name then
			revertEntry = nil
			StaticPopup_Hide("FROSTATOMUI_CONFIG_REVERT")
		end
		revertEntry, revertValue = entry, previous
		StaticPopup_Show("FROSTATOMUI_CONFIG_REVERT", revertText(REVERT_SECONDS))
	end
end

local function set(entry, value, reset)
	local previous = get(entry)
	if previous == value and not reset then
		return
	end
	if entry.confirmRevert then
		confirmRevert(entry, type(previous) == "table" and CopyTable(previous) or previous)
	end
	if entry.set then
		entry.set(value)
		return
	end
	if reset then
		reset()
	else
		ui:SetConfig(entry.path, value)
	end
	if entry.reload then
		if frame then
			frame.reloadButton:Show()
		end
		if entry.type == "toggle" then
			ns.Confirm(L["This change takes effect after a UI reload. Reload now?"], ReloadUI)
		end
	end
end

do
	local TRACKED = {
		toggle = true,
		number = true,
		string = true,
		select = true,
		multiselect = true,
		font = true,
		color = true,
		point = true,
		offset = true,
	}
	local CHANGED_COLOR = { r = 0.35, g = 0.75, b = 1 }
	local DOT_SIZE = 6
	local EPSILON = 0.0001
	local NAV_DELAY = 0.2
	local pathCache = setmetatable({}, { __mode = "k" })
	local trackCache = setmetatable({}, { __mode = "k" })
	local navToken = 0

	local function defaultOf(path)
		if path:find("%.%d+%.") or path:find("%.%d+$") then
			return false
		end
		local node, last = ui.Defaults, nil
		for key in path:gmatch("[^.]+") do
			if last ~= nil then
				node = node[last]
				if type(node) ~= "table" then
					return false
				end
			end
			last = tonumber(key) or key
		end
		return true, node[last]
	end

	local function same(a, b)
		if type(a) == "number" and type(b) == "number" then
			return math.abs(a - b) < EPSILON
		end
		if type(a) ~= "table" or type(b) ~= "table" then
			return a == b
		end
		for key, value in pairs(a) do
			if not same(value, b[key]) then
				return false
			end
		end
		for key in pairs(b) do
			if a[key] == nil then
				return false
			end
		end
		return true
	end

	local function sameColor(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then
			return a == b
		end
		for i = 1, 4 do
			if not same(a[i] or 1, b[i] or 1) then
				return false
			end
		end
		return true
	end

	local function optionsOf(values)
		if type(values) == "function" then
			return values() or {}
		end
		return values or {}
	end

	local function pathsOf(entry)
		local paths = pathCache[entry]
		if paths then
			return paths
		end
		paths = {}
		if entry.type == "multiselect" then
			for i, option in ipairs(optionsOf(entry.values)) do
				paths[i] = entry.path .. "." .. option[1]
			end
		elseif entry.type == "font" then
			paths[1], paths[2] = entry.path .. ".size", entry.path .. ".outline"
		elseif entry.type == "offset" then
			paths[1], paths[2] = entry.path, entry.pathY
		else
			paths[1] = entry.path
		end
		pathCache[entry] = paths
		return paths
	end

	local function tracks(entry)
		local tracked = trackCache[entry]
		if tracked ~= nil then
			return tracked
		end
		tracked = false
		if entry.isDefault then
			tracked = not entry.noReset
		elseif not entry.noReset and type(entry.path) == "string" and TRACKED[entry.type] then
			for _, path in ipairs(pathsOf(entry)) do
				if defaultOf(path) then
					tracked = true
					break
				end
			end
		end
		trackCache[entry] = tracked
		return tracked
	end

	local function isModified(entry)
		if not tracks(entry) then
			return false
		end
		if entry.isDefault then
			return not entry.isDefault()
		end
		local compare = entry.type == "color" and sameColor or same
		for _, path in ipairs(pathsOf(entry)) do
			local known, default = defaultOf(path)
			if known and not compare(ui:GetConfig(path), default) then
				return true
			end
		end
		return false
	end
	changes.IsModified = isModified

	function changes.Reset(entry)
		PlaySound("igMainMenuOptionCheckBoxOff")
		if entry.reset then
			entry.reset()
			return
		end
		if entry.set then
			local _, default = defaultOf(entry.path)
			set(entry, type(default) == "table" and CopyTable(default) or default)
			return
		end
		set(entry, nil, function()
			for _, path in ipairs(pathsOf(entry)) do
				if defaultOf(path) then
					ui:ResetConfig(path)
				end
			end
		end)
	end

	local function optionText(values, value)
		for _, option in ipairs(optionsOf(values)) do
			if option[1] == value then
				return option[2]
			end
		end
	end

	function changes.DefaultText(entry)
		if entry.defaultText or not tracks(entry) or entry.isDefault then
			return entry.defaultText
		end
		local kind = entry.type
		if kind == "multiselect" then
			local names = {}
			for _, option in ipairs(optionsOf(entry.values)) do
				local _, value = defaultOf(entry.path .. "." .. option[1])
				if value then
					names[#names + 1] = option[2]
				end
			end
			return #names > 0 and table.concat(names, ", ") or L["None"]
		elseif kind == "font" then
			local _, size = defaultOf(entry.path .. ".size")
			local _, outline = defaultOf(entry.path .. ".outline")
			return ("%s, %s"):format(tostring(size), optionText(OUTLINES, outline or "") or "")
		elseif kind == "offset" then
			local _, x = defaultOf(entry.path)
			local _, y = defaultOf(entry.pathY)
			return ("X %s, Y %s"):format(tostring(x), tostring(y))
		end
		local _, value = defaultOf(entry.path)
		if kind == "toggle" then
			return value and L["On"] or L["Off"]
		elseif kind == "number" and type(value) == "number" then
			return formatValue(entry, value)
		elseif kind == "select" then
			return optionText(entry.values, value)
		elseif kind == "color" and type(value) == "table" then
			return ("%02x%02x%02x"):format(value[1] * 255, value[2] * 255, value[3] * 255)
		elseif kind == "string" and type(value) == "string" then
			return value == "" and L["(empty)"] or ("\"%s\""):format(value)
		end
	end

	function changes.CreateDot(parent)
		local dot = createGlyph(parent, "circle", DOT_SIZE, CHANGED_COLOR)
		dot:Hide()
		return dot
	end

	function changes.Attach(row, entry)
		if not tracks(entry) then
			return
		end
		local dot = changes.CreateDot(row)
		dot:SetPoint("CENTER", row.label, "LEFT", -4, 0)
		row.changedDot = dot
		if entry.type == "point" or not entry.reset and not entry.path then
			return
		end
		local reset = ui.CreateGlyphButton(row, "rotate-left", GLYPH_SIZE, L["Reset to default"])
		reset:SetPoint("RIGHT", -4, 0)
		reset:SetScript("OnClick", function()
			changes.Reset(entry)
		end)
		bindHighlight(reset, row)
		reset:Hide()
		row.resetButton = reset
	end

	function changes.Update(row, enabled)
		if not row.changedDot then
			return
		end
		local modified = isModified(row.entry)
		row.modified = modified
		ui.SetShown(row.changedDot, modified)
		local reset = row.resetButton
		if reset then
			ui.SetShown(reset, modified)
			setControlEnabled(reset, enabled)
			local text = modified and changes.DefaultText(row.entry)
			reset.tooltipText = text and L["Default: %s"]:format(text) or nil
		end
	end

	function changes.Validate(row, box, text, pending)
		local ok, message = true, nil
		if text and row.entry.validate then
			ok, message = row.entry.validate(text)
		end
		local problem
		if message then
			problem = {
				text = message,
				color = ok and NORMAL_FONT_COLOR or RED_FONT_COLOR,
				rejected = pending and not ok,
			}
		end
		row.problem = problem
		local glyph = box.problemGlyph
		if problem and not glyph then
			glyph = createGlyph(box, "circle-exclamation", GLYPH_SIZE, problem.color)
			glyph:SetPoint("RIGHT", -2, 0)
			box.problemGlyph = glyph
		end
		if glyph then
			if problem then
				glyph:SetTextColor(problem.color.r, problem.color.g, problem.color.b)
			end
			ui.SetShown(glyph, problem)
			box:SetTextInsets(0, problem and GLYPH_BOX or 0, 0, 0)
		end
		return ok and true or false
	end

	function changes.Count(schema)
		local count, hidden = 0, false
		for _, entry in ipairs(schema or {}) do
			if entry.header then
				hidden = entry.hidden
			elseif not hidden and not entry.hidden and isModified(entry) then
				count = count + 1
			end
		end
		return count
	end

	local function countPage(page)
		local count = changes.Count(page.schema)
		for _, tab in ipairs(page.tabs or {}) do
			count = count + changes.Count(tab.schema)
		end
		for _, element in ipairs(elements) do
			if element.page == page.key and not element.hidden then
				count = count + changes.Count(element.schema)
			end
		end
		return count
	end

	function changes.PlaceNav(button)
		local reserved = 0
		local count = button.changedText
		if button.changedDot:IsShown() then
			reserved = count:GetStringWidth() + 2 + button.changedDot:GetStringWidth() + GLYPH_GAP
		end
		local badge = button.newBadge
		badge:ClearAllPoints()
		badge:SetPoint("RIGHT", -8 - reserved, 2)
		if badge:IsShown() then
			reserved = reserved + badge:GetStringWidth() + GLYPH_GAP
		end
		button.label:SetPoint("RIGHT", -8 - reserved, 2)
	end

	function changes.AttachNav(button)
		local count = button:CreateFontString(nil, "OVERLAY")
		count:SetFontObject(font("GameFontDisableSmall"))
		count:SetPoint("RIGHT", -8, 2)
		local dot = changes.CreateDot(button)
		dot:SetPoint("RIGHT", count, "LEFT", -2, 0)
		button.changedText = count
		button.changedDot = dot
	end

	function changes.UpdateNav()
		for _, page in ipairs(pages) do
			local button = page.button
			if button then
				local count = countPage(page)
				button.changedText:SetText(count > 0 and count or "")
				ui.SetShown(button.changedDot, count > 0)
				changes.PlaceNav(button)
			end
		end
	end

	function changes.ScheduleNav()
		navToken = navToken + 1
		local token = navToken
		ui.After(NAV_DELAY, function()
			if token == navToken and frame and frame:IsShown() then
				changes.UpdateNav()
			end
		end)
	end
end

local function createSliderBox(row, entry, sliderWidth)
	local slider = ui.CreateSlider(row, sliderWidth, entry.min, entry.max, entry.step, nextName())
	slider:SetPoint("LEFT", CONTROL_X, 0)
	slider.low:SetText("")
	slider.high:SetText("")
	bindRow(slider, row)

	local box = createEditBox(row, entry.unit and VALUE_BOX_WIDTH + 8 or VALUE_BOX_WIDTH, true)
	box:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	bindRow(box, row)

	local function commit(value)
		value = round(max(entry.min, min(entry.max, value)), entry.step)
		local limited = value
		if entry.atLeast then
			limited = max(limited, ui:GetConfig(entry.atLeast))
		end
		if entry.atMost then
			limited = min(limited, ui:GetConfig(entry.atMost))
		end
		set(entry, limited)
		if limited ~= value then
			refreshing = true
			row.Refresh()
			refreshing = false
		end
	end

	slider:SetScript("OnValueChanged", function(_, value)
		if not refreshing then
			commit(value)
		end
	end)
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		if IsShiftKeyDown() or box.editing then
			if self:IsEnabled() then
				commit(self:GetValue() + delta * entry.step)
			end
			return
		end
		local scroll = self:GetParent()
		while scroll and scroll:GetObjectType() ~= "ScrollFrame" do
			scroll = scroll:GetParent()
		end
		local handler = scroll and scroll:GetScript("OnMouseWheel")
		if handler then
			handler(scroll, delta)
		end
	end)
	box.OnCommit = function(self)
		local value = parseValue(entry, self:GetText())
		if value then
			commit(value)
		else
			row.Refresh()
		end
	end

	local function refresh()
		local value = get(entry)
		slider:SetValue(value)
		box:SetText(formatValue(entry, value))
		box:SetCursorPosition(0)
	end
	local function setEnabled(enabled)
		setControlEnabled(slider, enabled)
		local shade = enabled and 1 or 0.5
		slider:GetThumbTexture():SetVertexColor(shade, shade, shade)
		setEditBoxEnabled(box, enabled)
	end
	return box, refresh, setEnabled
end

local creators = {}
ns.creators = creators
ns.ROW_HEIGHT = ROW_HEIGHT
ns.CreateRow = createRow
ns.Get = get
ns.Set = set
ns.RowEnter = rowEnter
ns.RowLeave = rowLeave
ns.CreateCheckButton = createCheckButton
ns.PlayCheckSound = playCheckSound
ns.SetControlEnabled = setControlEnabled
ns.SetTextEnabled = setTextEnabled
ns.CreateEditBox = createEditBox
ns.SetEditBoxEnabled = setEditBoxEnabled
ns.CreateDropdown = createDropdown
ns.BindRow = bindRow
ns.BindHighlight = bindHighlight
ns.ValidateRow = changes.Validate

function creators.header(parent, entry)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(HEADER_HEIGHT)
	header:SetPoint("LEFT")
	header:SetPoint("RIGHT")

	local x = 4
	local label = header:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(font("GameFontNormal"))
	label:SetText(entry.header)
	if entry.glyph then
		local glyph = createGlyph(header, entry.glyph, GLYPH_SIZE, NORMAL_FONT_COLOR)
		glyph:SetPoint("CENTER", label, "LEFT", -GLYPH_GAP - GLYPH_BOX / 2, 0)
		x = x + GLYPH_BOX + GLYPH_GAP
	end
	label:SetPoint("BOTTOMLEFT", x, 6)
	local width = label:GetStringWidth()
	if isNewEntry(entry) then
		local badge = addNewBadge(header, label, width + 6)
		width = width + 6 + badge:GetStringWidth()
	end

	local line = header:CreateTexture(nil, "ARTWORK")
	line:SetTexture(SPACER_TEXTURE)
	line:SetVertexColor(0.6, 0.6, 0.6)
	line:SetHeight(16)
	line:SetPoint("BOTTOMLEFT", x + width + 8, 4)
	line:SetPoint("BOTTOMRIGHT", -4, 4)
	header.title = label
	header.line = line
	return header
end

function creators.description(parent, entry)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("LEFT")
	holder:SetPoint("RIGHT")

	local text = holder:CreateFontString(nil, "ARTWORK")
	text:SetFontObject(font("GameFontHighlightSmall"))
	text:SetPoint("TOPLEFT", LABEL_X, -2)
	text:SetWidth(parent:GetWidth() - LABEL_X * 2)
	text:SetJustifyH("LEFT")
	text:SetText(entry.description)
	holder:SetHeight(text:GetStringHeight() + 8)
	return holder
end

function creators.toggle(parent, entry)
	local row = createRow(parent, entry)

	local check = createCheckButton(row)
	check:SetPoint("LEFT", CONTROL_X - 4, 0)
	check:SetScript("OnClick", function(self)
		playCheckSound(self)
		set(entry, self:GetChecked() and true or false)
	end)
	bindRow(check, row)
	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and check:IsEnabled() == 1 then
			check:Click()
		end
	end)

	row.Refresh = function()
		check:SetChecked(get(entry))
	end
	row.SetEnabled = function(_, enabled)
		setControlEnabled(check, enabled)
	end
	return row
end

function creators.number(parent, entry)
	local row = createRow(parent, entry)
	local _, refresh, setEnabled = createSliderBox(row, entry, SLIDER_WIDTH)
	row.Refresh = refresh
	row.SetEnabled = function(_, enabled)
		setEnabled(enabled)
	end
	return row
end

function creators.string(parent, entry)
	local row = createRow(parent, entry)
	local box = createEditBox(row, entry.width or 200)
	box:SetPoint("LEFT", CONTROL_X + 6, 0)
	box:SetMaxLetters(entry.maxLetters or 24)
	row.box = box
	box.OnCommit = function(self)
		local text = self:GetText()
		if changes.Validate(row, self, text, true) then
			set(entry, text)
		end
	end
	box.OnCancel = function(self)
		changes.Validate(row, self)
		row.Refresh()
	end
	bindRow(box, row)
	row.Refresh = function()
		if box.editing or (row.problem and row.problem.rejected) then
			return
		end
		local text = get(entry) or ""
		box:SetText(text)
		box:SetCursorPosition(0)
		changes.Validate(row, box, text)
	end
	row.SetEnabled = function(_, enabled)
		setEditBoxEnabled(box, enabled)
	end
	return row
end

function creators.input(parent, entry)
	local row = createRow(parent, entry)
	local box = createEditBox(row, entry.width or 160)
	box:SetPoint("LEFT", CONTROL_X + 6, 0)
	box:SetMaxLetters(entry.maxLetters or 32)
	local button = createButton(row, entry.text or L["Save"], 80, nil, nil, entry.glyph)
	button:SetPoint("LEFT", box, "RIGHT", 8, 0)
	bindRow(box, row)
	bindRow(button, row)

	local function submit()
		local text = strtrim(box:GetText())
		if text ~= "" and changes.Validate(row, box, text, true) then
			box:SetText("")
			entry.func(text)
		end
	end
	box:SetScript("OnEnterPressed", function(self)
		submit()
		self:ClearFocus()
	end)
	box.OnCancel = function(self)
		self:SetText("")
		changes.Validate(row, self)
	end
	button:SetScript("OnClick", submit)

	row.Refresh = function() end
	row.SetEnabled = function(_, enabled)
		setEditBoxEnabled(box, enabled)
		setControlEnabled(button, enabled)
	end
	return row
end

function creators.select(parent, entry)
	local row = createRow(parent, entry)
	local values = entry.values
	local getValues = type(values) == "function" and values or function()
		return values
	end
	local dropdown = createDropdown(row, entry.width or 140, getValues, function(value)
		set(entry, value)
		row.Refresh()
	end)
	dropdown:SetPoint("LEFT", CONTROL_X - 16, -2)
	bindRow(_G[dropdown:GetName() .. "Button"], row)
	row.dropdown = dropdown

	row.Refresh = function()
		local value = get(entry)
		dropdown:Select(value)
		if value == nil then
			UIDropDownMenu_SetText(dropdown, entry.placeholder or "")
		end
	end
	row.SetEnabled = function(_, enabled)
		dropdown:SetEnabled(enabled)
	end
	return row
end

function creators.font(parent, entry)
	local row = createRow(parent, entry)
	local sizeEntry = { path = entry.path .. ".size", min = FONT_SIZE_MIN, max = FONT_SIZE_MAX, step = 1 }
	local outlineEntry = { path = entry.path .. ".outline" }

	local box, refreshSize, setSizeEnabled = createSliderBox(row, sizeEntry, FONT_SLIDER_WIDTH)

	local dropdown = createDropdown(row, 80, function()
		return OUTLINES
	end, function(value)
		set(outlineEntry, value)
	end)
	dropdown:SetPoint("LEFT", box, "RIGHT", -8, -2)
	bindRow(_G[dropdown:GetName() .. "Button"], row)

	row.Refresh = function()
		refreshSize()
		dropdown:Select(get(outlineEntry) or "")
	end
	row.SetEnabled = function(_, enabled)
		setSizeEnabled(enabled)
		dropdown:SetEnabled(enabled)
	end
	return row
end

local function addSquare(parent, layer, size, point, x, y, r, g, b)
	local square = parent:CreateTexture(nil, layer)
	square:SetTexture(r, g, b)
	square:SetSize(size, size)
	square:SetPoint(point, x, y)
	return square
end

function creators.color(parent, entry)
	local row = createRow(parent, entry)

	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(16, 16)
	swatch:SetPoint("LEFT", CONTROL_X + 2, 0)
	swatch:SetNormalTexture(SWATCH_TEXTURE)
	local fill = swatch:GetNormalTexture()
	local background = addSquare(swatch, "BACKGROUND", 14, "CENTER", 0, 0, 1, 1, 1)
	if entry.alpha then
		addSquare(swatch, "BORDER", 6, "TOPRIGHT", -2, -2, 0.6, 0.6, 0.6)
		addSquare(swatch, "BORDER", 6, "BOTTOMLEFT", 2, 2, 0.6, 0.6, 0.6)
	end
	swatch:SetScript("OnEnter", function()
		background:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		rowEnter(row)
	end)
	swatch:SetScript("OnLeave", function()
		background:SetVertexColor(1, 1, 1)
		rowLeave(row)
	end)

	local hex = row:CreateFontString(nil, "ARTWORK")
	hex:SetFontObject(font("GameFontHighlightSmall"))
	hex:SetPoint("LEFT", swatch, "RIGHT", 8, 0)

	local function current()
		local color = get(entry)
		return color[1], color[2], color[3], color[4] or 1
	end

	local function apply(r, g, b, a)
		local color = get(entry)
		if r ~= color[1] or g ~= color[2] or b ~= color[3] or (entry.alpha and a ~= (color[4] or 1)) then
			set(entry, entry.alpha and { r, g, b, a } or { r, g, b })
		end
	end

	local function paint()
		local r, g, b, a = current()
		if swatch:IsEnabled() ~= 1 then
			r = r * 0.3 + g * 0.59 + b * 0.11
			g, b = r, r
		end
		fill:SetVertexColor(r, g, b, a)
	end

	swatch:SetScript("OnClick", function()
		local r, g, b, a = current()
		ColorPickerFrame.hasOpacity = entry.alpha and true or false
		ColorPickerFrame.opacity = 1 - a
		ColorPickerFrame.previousValues = { r, g, b, a }
		ColorPickerFrame.func = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			apply(nr, ng, nb, entry.alpha and 1 - OpacitySliderFrame:GetValue() or 1)
		end
		ColorPickerFrame.opacityFunc = ColorPickerFrame.func
		ColorPickerFrame.cancelFunc = function(previous)
			apply(previous[1], previous[2], previous[3], previous[4])
		end
		ColorPickerFrame:SetColorRGB(r, g, b)
		ColorPickerFrame:SetFrameStrata(POPUP_STRATA)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)

	row.Refresh = function()
		local r, g, b = current()
		paint()
		hex:SetText(("%02x%02x%02x"):format(r * 255, g * 255, b * 255))
	end
	row.SetEnabled = function(_, enabled)
		setControlEnabled(swatch, enabled)
		setTextEnabled(hex, enabled)
		paint()
	end
	return row
end

function creators.execute(parent, entry)
	local row = createRow(parent, entry)
	local button =
		createButton(row, entry.text or entry.label, entry.width or 140, entry.confirm ~= nil, nil, entry.glyph)
	button:SetPoint("LEFT", CONTROL_X, 0)
	button:SetScript("OnClick", function()
		if entry.confirm then
			ns.Confirm(entry.confirm, entry.func)
		else
			entry.func()
		end
	end)
	bindRow(button, row)
	row.Refresh = function() end
	row.SetEnabled = function(_, enabled)
		setControlEnabled(button, enabled)
	end
	return row
end

do
	local IGNORED_KEYS = {
		LSHIFT = true,
		RSHIFT = true,
		LCTRL = true,
		RCTRL = true,
		LALT = true,
		RALT = true,
		UNKNOWN = true,
	}

	local MOUSE_KEYS = {
		LeftButton = "BUTTON1",
		RightButton = "BUTTON2",
		MiddleButton = "BUTTON3",
	}

	local function keyCombo(key)
		local combo = MOUSE_KEYS[key] or (key:find("^Button%d+$") and key:upper()) or key
		if IsShiftKeyDown() then
			combo = "SHIFT-" .. combo
		end
		if IsControlKeyDown() then
			combo = "CTRL-" .. combo
		end
		if IsAltKeyDown() then
			combo = "ALT-" .. combo
		end
		return combo
	end

	local function keysText(action)
		local keys = { GetBindingKey(action) }
		if #keys == 0 then
			return GRAY_FONT_COLOR_CODE .. L["Not bound"] .. FONT_COLOR_CODE_CLOSE
		end
		for i = 1, #keys do
			keys[i] = GetBindingText(keys[i], "KEY_")
		end
		return table.concat(keys, ", ")
	end

	local function clearBinding(action)
		local key = GetBindingKey(action)
		while key do
			SetBinding(key)
			key = GetBindingKey(action)
		end
	end

	function creators.keybind(parent, entry)
		local row = createRow(parent, entry)
		local action = entry.binding

		local button = createButton(row, keysText(action), entry.width or 160, true)
		button:SetPoint("LEFT", CONTROL_X, 0)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:GetFontString():SetWidth((entry.width or 160) - 12)
		bindRow(button, row)

		local catcher = CreateFrame("Button", nil, button)
		catcher:SetAllPoints()
		catcher:Hide()
		catcher:EnableKeyboard(true)
		catcher:EnableMouseWheel(true)
		catcher:RegisterForClicks("AnyUp")

		local function stopCapture()
			catcher:Hide()
			row.Refresh()
		end

		local function bindKey(key)
			local combo = keyCombo(key)
			if InCombatLockdown() or combo == "BUTTON1" or combo == "BUTTON2" then
				stopCapture()
				return
			end
			local previous = GetBindingAction(combo)
			if previous and previous ~= "" and previous ~= action then
				ui.Print(
					L["%s was unbound from %s"],
					GetBindingText(combo, "KEY_"),
					GetBindingText(previous, "BINDING_NAME_")
				)
			end
			clearBinding(action)
			SetBinding(combo, action)
			SaveBindings(GetCurrentBindingSet())
			stopCapture()
		end

		catcher:SetScript("OnKeyDown", function(_, key)
			if key == "ESCAPE" then
				stopCapture()
			elseif not IGNORED_KEYS[key] then
				bindKey(key)
			end
		end)
		catcher:SetScript("OnMouseDown", function(_, mouse)
			bindKey(mouse)
		end)
		catcher:SetScript("OnMouseWheel", function(_, delta)
			bindKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
		end)
		catcher:SetScript("OnHide", function()
			button:UnlockHighlight()
		end)

		button:SetScript("OnClick", function(_, mouse)
			if InCombatLockdown() then
				ui.Print(L["cannot change bindings in combat"])
				return
			end
			if mouse == "RightButton" then
				clearBinding(action)
				SaveBindings(GetCurrentBindingSet())
				row.Refresh()
				return
			end
			button:LockHighlight()
			button:SetText(NORMAL_FONT_COLOR_CODE .. L["Press a key..."] .. FONT_COLOR_CODE_CLOSE)
			catcher:Show()
		end)

		row.Refresh = function()
			if not catcher:IsShown() then
				button:SetText(keysText(action))
			end
		end
		row.SetEnabled = function(_, enabled)
			if not enabled then
				catcher:Hide()
			end
			setControlEnabled(button, enabled)
		end
		return row
	end
end

function creators.custom(parent, entry)
	local row = createRow(parent, entry)
	if entry.height then
		row:SetHeight(entry.height)
	end
	entry.build(row)
	row.Refresh = function()
		if entry.refresh then
			entry.refresh(row)
		end
	end
	row.SetEnabled = function(_, enabled)
		if entry.setEnabled then
			entry.setEnabled(row, enabled)
		end
	end
	return row
end

local function listsElement(view, element)
	local tab = view.tab
	if not tab then
		return element.tab == nil
	end
	return element.tab == tab.key or tab.elements == "all" or (tab.elements == "untabbed" and element.tab == nil)
end

local function inlineSchema(element, enabledBy)
	if element.inline then
		return element.inline
	end
	local inline = {}
	local first = element.schema[1]
	local title = {
		header = element.name,
		glyph = element.glyph,
		new = element.new,
		element = element,
		keep = true,
		page = element,
		enabledBy = enabledBy,
	}
	if first and first.header then
		title.advanced, title.hidden = first.advanced, first.hidden
		title.toggles, title.toggleDesc = first.toggles, first.toggleDesc
	end
	inline[1] = title
	local controls = 0
	for _, entry in ipairs(element.schema) do
		if entry.path or entry.type then
			controls = controls + 1
		end
	end
	local flat = controls <= INLINE_FLAT_CONTROLS
	local advanced = title.advanced
	if flat then
		title.advanced = nil
	end
	for index, entry in ipairs(element.schema) do
		if flat and entry.header then
			advanced = entry.advanced
		elseif flat and advanced and not entry.advanced then
			local copy = {}
			for key, value in pairs(entry) do
				copy[key] = value
			end
			copy.advanced = true
			inline[#inline + 1] = copy
		elseif not entry.header then
			inline[#inline + 1] = entry
		elseif index > 1 then
			local copy = {}
			for key, value in pairs(entry) do
				copy[key] = value
			end
			copy.header = element.name .. ": " .. entry.header
			inline[#inline + 1] = copy
		end
	end
	element.inline = inline
	return inline
end

function ns.InlineElement(path, name)
	local inline = inlineSchema(elementFor(path))
	if name then
		inline[1].header = name
	end
	return inline
end

local function expandSchema(page)
	local schema = {}
	local owner = page.owner or page
	local source = page.schema
	if page.buildSchema then
		source = page.buildSchema()
		page.lastSignature = page.signature()
		adoptEntries(source, owner)
	end
	local listed, headers = {}, {}
	for _, entry in ipairs(source) do
		if entry.path then
			listed[entry.path] = true
		elseif entry.header then
			headers[entry.header] = entry
		end
	end
	local placed, attached = {}, {}
	for _, entry in ipairs(source) do
		if entry.type == "elements" then
			local list, buttons = {}, 0
			for _, element in ipairs(elements) do
				if element.page == owner.key and not element.hidden and listsElement(page, element) then
					local inline = inlineSchema(element, entry.enabledBy)
					local rest, controls = {}, false
					for i = 2, #inline do
						local inlined = inline[i]
						if not (inlined.path and listed[inlined.path]) then
							rest[#rest + 1] = inlined
							controls = controls or not inlined.header and not inlined.description
							if inlined.path then
								listed[inlined.path] = true
							end
						end
					end
					local header = headers[element.name]
					if header then
						header.element = element
						attached[header] = rest
					elseif controls then
						list[#list + 1] = inline[1]
						for _, inlined in ipairs(rest) do
							list[#list + 1] = inlined
						end
					else
						buttons = buttons + 1
						tinsert(list, buttons, elementButton(element, owner, entry.enabledBy))
					end
				end
			end
			placed[entry] = list
		end
	end
	local pending
	local function flush()
		for _, inlined in ipairs(pending or {}) do
			schema[#schema + 1] = inlined
		end
		pending = nil
	end
	for _, entry in ipairs(source) do
		if entry.header or placed[entry] then
			flush()
		end
		if placed[entry] then
			for _, inlined in ipairs(placed[entry]) do
				schema[#schema + 1] = inlined
			end
		else
			schema[#schema + 1] = entry
			pending = attached[entry] or pending
		end
	end
	flush()
	return schema
end

local confirmAction

StaticPopupDialogs["FROSTATOMUI_CONFIG_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		confirmAction()
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

function ns.Confirm(text, action)
	confirmAction = action
	local dialog = StaticPopup_Show("FROSTATOMUI_CONFIG_CONFIRM", text)
	if dialog then
		dialog:SetFrameStrata(POPUP_STRATA)
	end
end

local function isEnabledBy(enabledBy)
	if type(enabledBy) == "table" then
		for i = 1, #enabledBy do
			if not isEnabledBy(enabledBy[i]) then
				return false
			end
		end
		return true
	end
	return ui:GetConfig(enabledBy) and true or false
end

local function isEnabledByAny(paths)
	for i = 1, #paths do
		if ui:GetConfig(paths[i]) then
			return true
		end
	end
	return false
end

local pageByKey, isEntryEnabled

do
	local function listPaths(paths, list)
		list = list or {}
		if type(paths) == "table" then
			for i = 1, #paths do
				listPaths(paths[i], list)
			end
		elseif paths then
			list[#list + 1] = paths
		end
		return list
	end

	local function contains(list, value)
		for i = 1, #list do
			if list[i] == value then
				return true
			end
		end
		return false
	end

	function pageByKey(key)
		for _, page in ipairs(pages) do
			if page.key == key then
				return page
			end
		end
	end

	local function ownerRequirements(entry)
		local owner = entry.page
		if not owner or owner.element then
			return {}
		end
		local paths = {}
		if owner.enable then
			paths[1] = owner.enable
		elseif owner.path and owner.key == "element:" .. owner.path then
			local page = pageByKey(owner.page)
			if page and page.enable then
				paths[1] = page.enable
			end
			listPaths(owner.enabledBy, paths)
		end
		local result = {}
		for i = 1, #paths do
			if paths[i] ~= entry.path and not contains(result, paths[i]) then
				result[#result + 1] = paths[i]
			end
		end
		return result
	end

	function isEntryEnabled(entry)
		if entry.disabled and entry.disabled() then
			return false
		end
		if entry.enabledBy and not isEnabledBy(entry.enabledBy) then
			return false
		end
		if entry.enabledByAny and not isEnabledByAny(entry.enabledByAny) then
			return false
		end
		local owner = ownerRequirements(entry)
		return #owner == 0 or isEnabledBy(owner)
	end

	local pathOwners

	local function indexSchema(schema, pageName)
		local header
		for _, entry in ipairs(schema) do
			if entry.header then
				header = entry.header
			elseif entry.type == "multiselect" and entry.path then
				for _, option in ipairs(entry.values) do
					local path = entry.path .. "." .. option[1]
					if not pathOwners[path] then
						pathOwners[path] = { name = ("%s: %s"):format(entry.label, option[2]), page = pageName }
					end
				end
			elseif entry.path and entry.label and not pathOwners[entry.path] then
				local name = entry.label
				if name == L["Enable"] or name == L["Show"] then
					name = header or pageName
				end
				pathOwners[entry.path] = { name = name, page = pageName }
			end
		end
	end

	local function pathName(path, entry)
		if not pathOwners then
			pathOwners = {}
			for _, page in ipairs(pages) do
				indexSchema(page.buildSchema and page.buildSchema() or page.schema, page.name)
				for _, tab in ipairs(page.tabs or {}) do
					indexSchema(tab.buildSchema and tab.buildSchema() or tab.schema, page.name)
				end
			end
			for _, element in ipairs(elements) do
				indexSchema(element.schema, element.name)
			end
		end
		local owner = pathOwners[path]
		if not owner then
			return nil
		end
		local page = entry.page
		local here = page and (page.element or page).name
		if owner.page ~= here and owner.name ~= owner.page then
			return ("%s (%s)"):format(owner.name, owner.page)
		end
		return owner.name
	end

	local function unmetNames(paths, entry, names)
		for _, path in ipairs(listPaths(paths)) do
			if not ui:GetConfig(path) then
				local name = pathName(path, entry)
				if name and not contains(names, name) then
					names[#names + 1] = name
				end
			end
		end
		return names
	end

	function requirementText(entry)
		if entry.disabled and entry.disabled() and entry.disabledDesc then
			return entry.disabledDesc
		end
		local names = unmetNames(ownerRequirements(entry), entry, {})
		unmetNames(entry.enabledBy, entry, names)
		if entry.enabledByAny and not isEnabledByAny(entry.enabledByAny) then
			local any = {}
			for _, path in ipairs(entry.enabledByAny) do
				local name = pathName(path, entry)
				if name and not contains(any, name) then
					any[#any + 1] = name
				end
			end
			if #any > 0 then
				names[#names + 1] = table.concat(any, L[" or "])
			end
		end
		if #names == 0 then
			return nil
		end
		return L["Requires: %s"]:format(table.concat(names, ", "))
	end
end

local function showContent(page, scroll, offset)
	scroll:SetScrollChild(page.content)
	page.content:Show()
	scroll:SetVerticalScroll(offset)
end

local sectionsOf

do
	local function countControls(list)
		local count = 0
		for i = 1, #list do
			if not list[i].description then
				count = count + 1
			end
		end
		return count
	end

	function sectionsOf(schema, all)
		local sections = {}
		local section = { basic = {}, extra = {} }
		local function close()
			if section.hidden then
				return
			end
			section.extraCount = countControls(section.extra)
			if section.header and countControls(section.basic) == 0 then
				for i = #section.basic, 1, -1 do
					tinsert(section.extra, 1, section.basic[i])
				end
				section.basic = {}
			end
			if section.extraCount > 0 or #section.basic > 0 or section.header and section.header.keep then
				sections[#sections + 1] = section
			end
		end
		for _, entry in ipairs(schema) do
			if entry.header then
				close()
				section = {
					header = entry,
					basic = {},
					extra = {},
					hidden = entry.hidden,
					advanced = entry.advanced and not all,
				}
			elseif not entry.hidden then
				local list = (section.advanced or (entry.advanced and not all)) and section.extra or section.basic
				list[#list + 1] = entry
			end
		end
		close()
		return sections
	end
end

local function expandedStore()
	local db = ui.db
	db.expandedSettings = db.expandedSettings or {}
	return db.expandedSettings
end

local function isExpanded(section)
	return expandedStore()[section.key] and true or false
end

local function fitElementFrame(view)
	local height = -ELEMENT_TOP + SCROLL_LEFT + view.content:GetHeight() + SCROLL_BOTTOM + ELEMENT_BOTTOM
	elementFrame:SetHeight(max(ELEMENT_MIN_HEIGHT, min(ELEMENT_MAX_HEIGHT, height)))
end

local function layoutPage(page)
	local offset = CONTENT_TOP
	local first = true
	for _, item in ipairs(page.items) do
		local shown = not item.extra or isExpanded(item.section)
		ui.SetShown(item.row, shown)
		if shown then
			if item.header and not first then
				offset = offset + SECTION_GAP
			end
			item.row:SetPoint("TOP", 0, -offset)
			offset = offset + item.row:GetHeight()
			first = false
		end
		if item.row.Update then
			item.row:Update()
		end
	end
	page.content:SetHeight(offset + CONTENT_BOTTOM)
	if page.onLayout then
		page.onLayout()
	end
end

local function toggleSection(page, section)
	local store = expandedStore()
	store[section.key] = not store[section.key] or nil
	PlaySound(store[section.key] and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
	layoutPage(page)
	local scroll = page.scroll or frame.scroll
	scroll:UpdateScrollChildRect()
	if page.element and elementFrame.view == page then
		fitElementFrame(page)
	end
end

local function createExpander(parent, page, section)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(ROW_HEIGHT)
	button:SetPoint("LEFT")
	button:SetPoint("RIGHT")

	local highlight = button:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(HIGHLIGHT_TEXTURE)
	highlight:SetBlendMode("ADD")
	highlight:SetVertexColor(HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3], 0.35)
	highlight:SetAllPoints()
	button:SetHighlightTexture(highlight)

	local glyph = createGlyph(button, "chevron-right", MARKER_SIZE, NORMAL_FONT_COLOR)
	glyph:SetPoint("CENTER", button, "LEFT", LABEL_X + GLYPH_BOX / 2, 0)

	local label = button:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(font("GameFontNormalSmall"))
	label:SetPoint("LEFT", LABEL_X + GLYPH_BOX + GLYPH_GAP, 0)

	local function paint(color)
		glyph:SetTextColor(color.r, color.g, color.b)
		label:SetTextColor(color.r, color.g, color.b)
	end
	button:SetScript("OnEnter", function()
		paint(HIGHLIGHT_FONT_COLOR)
	end)
	button:SetScript("OnLeave", function()
		paint(NORMAL_FONT_COLOR)
	end)
	button:SetScript("OnClick", function()
		toggleSection(page, section)
	end)
	local badge
	for _, entry in ipairs(section.extra) do
		if isNewEntry(entry) then
			badge = addNewBadge(button, label, 0)
			break
		end
	end

	local dot = changes.CreateDot(button)
	local changed = button:CreateFontString(nil, "ARTWORK")
	changed:SetFontObject(font("GameFontDisableSmall"))
	local changedCount = 0

	local function place()
		local x = label:GetStringWidth() + 6
		local shown = changedCount > 0 and not isExpanded(section)
		ui.SetShown(dot, shown)
		ui.SetShown(changed, shown)
		if shown then
			changed:SetText(L["%d changed"]:format(changedCount))
			dot:SetPoint("CENTER", label, "LEFT", x + 3, 0)
			changed:SetPoint("LEFT", label, "LEFT", x + 9, 0)
			x = x + 9 + changed:GetStringWidth() + 6
		end
		if badge then
			badge:SetPoint("LEFT", label, "LEFT", x, 0)
		end
	end

	button.Update = function()
		local expanded = isExpanded(section)
		ui.SetGlyph(glyph, expanded and "chevron-down" or "chevron-right")
		label:SetText(expanded and L["Fewer settings"] or L["More settings (%d)"]:format(section.extraCount))
		place()
	end
	button.UpdateChanges = function(items)
		local count = 0
		for _, item in ipairs(items) do
			if item.section == section and item.extra and item.row.modified then
				count = count + 1
			end
		end
		changedCount = count
		place()
	end
	return button
end

local function buildPage(page)
	local content = CreateFrame("Frame", nil, page.parent or page.scroll or frame.scroll)
	content:SetWidth(page.width or CONTENT_WIDTH)
	content:Hide()
	page.content = content
	page.rows = {}
	page.items = {}

	local function add(row, section, extra, header)
		page.items[#page.items + 1] = { row = row, section = section, extra = extra, header = header }
		if row.Refresh then
			tinsert(page.rows, row)
		end
	end

	local function addEntries(section, entries, extra)
		for _, entry in ipairs(entries) do
			add(creators[entry.type or "description"](content, entry), section, extra)
		end
	end

	for index, section in ipairs(sectionsOf(expandSchema(page), page == searchPage or page.element ~= nil)) do
		local header = section.header
		section.key = page.key .. ":" .. (header and header.header or index)
		if header then
			add(creators.header(content, header), section, false, true)
		end
		addEntries(section, section.basic, false)
		if section.extraCount > 0 then
			add(createExpander(content, page, section), section, false)
			addEntries(section, section.extra, true)
		end
	end
	layoutPage(page)
end

local function rebuildPage(page)
	local scroll = page.scroll or frame.scroll
	local offset = scroll:GetVerticalScroll()
	page.content:Hide()
	buildPage(page)
	showContent(page, scroll, offset)
end

local showPage

local refreshPage

local function refreshView(page)
	if not page or not page.rows then
		return
	end
	if page.signature and page.signature() ~= page.lastSignature then
		rebuildPage(page)
	end
	refreshing = true
	for _, row in ipairs(page.rows) do
		row.Refresh()
		local enabled = isEntryEnabled(row.entry)
		row.disabled = not enabled
		row:SetEnabled(enabled)
		setTextEnabled(row.label, enabled)
		changes.Update(row, enabled)
	end
	for _, item in ipairs(page.items) do
		if item.row.UpdateChanges then
			item.row.UpdateChanges(page.items)
		end
	end
	refreshing = false
end

function refreshPage(page)
	if page and page.tabs then
		refreshView(page.head)
		if page.activeTab then
			refreshView(page.activeTab.view)
		end
		return
	end
	refreshView(page)
end

function ns.RefreshPage()
	if frame and frame:IsShown() then
		refreshPage(currentPage)
	end
end

local function resetSchema(schema)
	for _, entry in ipairs(schema) do
		if entry.path and not entry.noReset then
			ui:ResetConfig(entry.path)
			if entry.pathY then
				ui:ResetConfig(entry.pathY)
			end
		end
	end
end

local function resetElement(element)
	resetSchema(element.schema)
	ui:ResetConfig(element.path)
end

local function resetPage(page)
	resetSchema(page.schema)
	for _, tab in ipairs(page.tabs or {}) do
		resetSchema(tab.schema)
	end
	for _, element in ipairs(elements) do
		if element.page == page.key then
			resetElement(element)
		end
	end
end

local function paintNavGlyph(button)
	local glyph = button and button.glyph
	if not glyph then
		return
	end
	local color = NORMAL_FONT_COLOR
	if button.hovered or (currentPage and currentPage.button == button) then
		color = HIGHLIGHT_FONT_COLOR
	end
	glyph:SetTextColor(color.r, color.g, color.b)
end

local function showPageTitle(page)
	local glyph = page.glyph
	local title = frame.pageTitle
	title:SetPoint("TOPLEFT", glyph and 16 + TITLE_GLYPH_SIZE + 4 + GLYPH_GAP or 16, -16)
	title:SetText(page.name)
	if glyph then
		ui.SetGlyph(frame.pageGlyph, glyph)
	end
	ui.SetShown(frame.pageGlyph, glyph)
end

local tabByKey, placeScroll, updateCopyButton, selectTab, showTabbedPage, hidePageContent, createCopyButton

do
	local TAB_HEIGHT = 22
	local TAB_PADDING = 8
	local TAB_GAP = 2
	local TAB_BAR_GAP = 6

	local function tabStore()
		local db = ui.db
		db.settingsTabs = db.settingsTabs or {}
		return db.settingsTabs
	end

	function tabByKey(page, key)
		for _, tab in ipairs(page.tabs) do
			if tab.key == key then
				return tab
			end
		end
	end

	function placeScroll(offset)
		frame.scroll:SetPoint("TOPLEFT", SCROLL_LEFT, SCROLL_TOP - offset)
	end

	local function placeTabs(page)
		local head = page.head
		local height = #head.items > 0 and head.content:GetHeight() - CONTENT_BOTTOM or 0
		page.tabBar:SetPoint("TOPLEFT", frame.panel, "TOPLEFT", SCROLL_LEFT, SCROLL_TOP - height)
		if currentPage == page then
			placeScroll(height + page.tabBar:GetHeight())
		end
	end

	local function copySources(page, tab)
		local list = {}
		if not tab.copy then
			return list
		end
		for _, other in ipairs(page.tabs) do
			if other ~= tab and other.copy then
				for key, path in pairs(tab.copy) do
					local from = other.copy[key]
					if from and from ~= path then
						list[#list + 1] = other
						break
					end
				end
			end
		end
		return list
	end

	local function pathEntries(page)
		local index = {}
		local function scan(schema)
			for _, entry in ipairs(schema) do
				local path = entry.path
				if path then
					local info = index[path] or {}
					index[path] = info
					info.reload = info.reload or entry.reload
					if entry.type == "number" then
						info.min = max(info.min or entry.min, entry.min)
						info.max = min(info.max or entry.max, entry.max)
					end
				end
			end
		end
		scan(page.schema)
		for _, tab in ipairs(page.tabs) do
			scan(tab.schema)
		end
		for _, element in ipairs(elements) do
			if element.page == page.key then
				scan(element.schema)
			end
		end
		return index
	end

	local function copyTab(page, source, target)
		local index = pathEntries(page)
		local reload = false
		for key, path in pairs(target.copy) do
			local from = source.copy[key]
			if from and from ~= path then
				local value = ui:GetConfig(from)
				local info = index[path]
				if type(value) == "table" then
					value = CopyTable(value)
				elseif type(value) == "number" and info and info.min then
					value = max(info.min, min(info.max, value))
				end
				if type(value) == "table" or value ~= ui:GetConfig(path) then
					ui:SetConfig(path, value)
					reload = reload or (info and info.reload) or false
				end
			end
		end
		refreshPage(page)
		if reload then
			frame.reloadButton:Show()
			ui.After(0, function()
				ns.Confirm(L["This change takes effect after a UI reload. Reload now?"], ReloadUI)
			end)
		end
	end

	function updateCopyButton(page)
		local tab = page and page.tabs and page.activeTab
		ui.SetShown(frame.copyButton, tab and #copySources(page, tab) > 0)
	end

	local function paintTab(button)
		local tab = button.tab
		local active = button.page.activeTab
		local selected = active == tab or button.group and active and active.parent == tab.key or false
		local color = (selected or button.hovered) and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
		button.text:SetTextColor(color.r, color.g, color.b)
		if button.glyph then
			button.glyph:SetTextColor(color.r, color.g, color.b)
		end
		ui.SetShown(button.selected, selected)
		ui.SetShown(button.underline, selected)
	end

	local function tabHasNew(tab, page, group)
		for _, entry in ipairs(tab.schema) do
			if isNewEntry(entry) then
				return true
			end
		end
		if group then
			for _, child in ipairs(page.tabs) do
				if child.parent == tab.key and tabHasNew(child) then
					return true
				end
			end
		end
		return false
	end

	local function createTabButton(bar, page, tab, group)
		local button = CreateFrame("Button", nil, bar)
		button:SetHeight(TAB_HEIGHT)
		button.page = page
		button.tab = tab
		button.group = group

		local selected = button:CreateTexture(nil, "BACKGROUND")
		selected:SetTexture(HIGHLIGHT_TEXTURE)
		selected:SetBlendMode("ADD")
		selected:SetVertexColor(HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3], 0.8)
		selected:SetAllPoints()
		local underline = button:CreateTexture(nil, "ARTWORK")
		underline:SetTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		underline:SetHeight(2)
		underline:SetPoint("BOTTOMLEFT", 2, 0)
		underline:SetPoint("BOTTOMRIGHT", -2, 0)
		button.selected = selected
		button.underline = underline

		local highlight = button:CreateTexture(nil, "BACKGROUND")
		highlight:SetTexture(HIGHLIGHT_TEXTURE)
		highlight:SetBlendMode("ADD")
		highlight:SetVertexColor(HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3], 0.35)
		highlight:SetAllPoints()
		button:SetHighlightTexture(highlight)

		local x = TAB_PADDING
		if tab.glyph then
			local glyph = createGlyph(button, tab.glyph, GLYPH_SIZE, NORMAL_FONT_COLOR)
			glyph:SetPoint("CENTER", button, "LEFT", x + GLYPH_BOX / 2, 0)
			button.glyph = glyph
			x = x + GLYPH_BOX + GLYPH_GAP
		end
		local text = button:CreateFontString(nil, "ARTWORK")
		text:SetFontObject(font("GameFontNormal"))
		text:SetText(tab.name)
		text:SetPoint("LEFT", x, 0)
		button.text = text
		local width = x + text:GetStringWidth() + TAB_PADDING
		if tabHasNew(tab, page, group) then
			local badge = addNewBadge(button, text, text:GetStringWidth() + GLYPH_GAP)
			width = width + GLYPH_GAP + badge:GetStringWidth()
			button.newBadge = badge
		end
		button:SetWidth(width)

		button:SetScript("OnEnter", function(self)
			self.hovered = true
			paintTab(self)
		end)
		button:SetScript("OnLeave", function(self)
			self.hovered = nil
			paintTab(self)
		end)
		button:SetScript("OnClick", function()
			PlaySound("igMainMenuOptionCheckBoxOn")
			selectTab(page, tab)
		end)
		return button
	end

	local function placeTabRow(buttons, width, indent)
		local x, y = indent, 0
		for _, button in ipairs(buttons) do
			local buttonWidth = button:GetWidth()
			if x > indent and x + buttonWidth > width then
				x, y = indent, y - TAB_HEIGHT - TAB_GAP
			end
			button:SetPoint("TOPLEFT", x, y)
			x = x + buttonWidth + TAB_GAP
		end
		return y
	end

	local function layoutTabBar(page)
		local bar = page.tabBar
		local active = page.activeTab
		local groupKey = active and (active.parent or bar.groups[active.key] and active.key)
		for key, sub in pairs(bar.groups) do
			ui.SetShown(sub, key == groupKey)
		end
		local y = bar.topY
		local sub = groupKey and bar.groups[groupKey]
		if sub then
			y = y - TAB_HEIGHT - TAB_GAP
			sub:SetPoint("TOPLEFT", 0, y)
			y = y + sub.lastY
		end
		bar.line:SetPoint("TOPLEFT", 0, y - TAB_HEIGHT + 7)
		bar.line:SetPoint("TOPRIGHT", 0, y - TAB_HEIGHT + 7)
		bar:SetHeight(-y + TAB_HEIGHT + TAB_BAR_GAP)
	end

	local function createSubTabs(bar, page, head)
		local sub = CreateFrame("Frame", nil, bar)
		sub:SetWidth(CONTENT_WIDTH)
		local background = sub:CreateTexture(nil, "BACKGROUND")
		background:SetTexture(0, 0, 0, 0.3)
		background:SetAllPoints()
		local buttons = { createTabButton(sub, page, head) }
		for _, tab in ipairs(page.tabs) do
			if tab.parent == head.key then
				buttons[#buttons + 1] = createTabButton(sub, page, tab)
			end
		end
		sub.lastY = placeTabRow(buttons, CONTENT_WIDTH, TAB_PADDING)
		sub:SetHeight(-sub.lastY + TAB_HEIGHT)
		for _, button in ipairs(buttons) do
			bar.buttons[#bar.buttons + 1] = button
		end
		sub:Hide()
		return sub
	end

	local function createTabBar(page)
		local bar = CreateFrame("Frame", nil, frame.panel)
		bar:SetWidth(CONTENT_WIDTH)
		bar.buttons = {}
		bar.groups = {}
		local hasChildren = {}
		for _, tab in ipairs(page.tabs) do
			if tab.parent then
				hasChildren[tab.parent] = true
			end
		end
		local top = {}
		for _, tab in ipairs(page.tabs) do
			if not tab.parent then
				local button = createTabButton(bar, page, tab, hasChildren[tab.key])
				top[#top + 1] = button
				bar.buttons[#bar.buttons + 1] = button
				if hasChildren[tab.key] then
					bar.groups[tab.key] = createSubTabs(bar, page, tab)
				end
			end
		end
		bar.topY = placeTabRow(top, CONTENT_WIDTH, 0)
		local line = bar:CreateTexture(nil, "ARTWORK")
		line:SetTexture(SPACER_TEXTURE)
		line:SetVertexColor(0.6, 0.6, 0.6)
		line:SetHeight(16)
		bar.line = line
		page.tabBar = bar
		layoutTabBar(page)
	end

	function selectTab(page, tab)
		local previous = page.activeTab
		if previous and previous.view and previous.view.content then
			previous.view.content:Hide()
		end
		page.activeTab = tab
		tabStore()[page.key] = tab.key
		local view = tab.view
		if not view then
			view = {
				key = page.key .. ":" .. tab.key,
				owner = page,
				tab = tab,
				schema = tab.schema,
				buildSchema = tab.buildSchema,
				signature = tab.signature,
			}
			tab.view = view
		end
		if not view.content then
			buildPage(view)
		end
		showContent(view, frame.scroll, 0)
		for _, button in ipairs(page.tabBar.buttons) do
			if button.tab == tab and button.newBadge then
				button.newBadge:Hide()
			end
			paintTab(button)
		end
		layoutTabBar(page)
		if page.head then
			placeTabs(page)
		end
		updateCopyButton(page)
		refreshPage(page)
	end

	function showTabbedPage(page)
		if not page.head then
			createTabBar(page)
			page.head = {
				key = page.key,
				owner = page,
				schema = page.schema,
				parent = frame.panel,
				onLayout = function()
					placeTabs(page)
				end,
			}
			buildPage(page.head)
			page.head.content:SetPoint("TOPLEFT", SCROLL_LEFT, SCROLL_TOP)
		end
		page.head.content:Show()
		page.tabBar:Show()
		placeTabs(page)
		selectTab(page, tabByKey(page, tabStore()[page.key]) or page.tabs[1])
	end

	function hidePageContent(page)
		if not page.tabs then
			page.content:Hide()
			return
		end
		page.head.content:Hide()
		page.tabBar:Hide()
		local view = page.activeTab and page.activeTab.view
		if view and view.content then
			view.content:Hide()
		end
	end

	function createCopyButton(panel)
		local copyMenu = CreateFrame("Frame", FRAME_NAME .. "CopyMenu", frame, "UIDropDownMenuTemplate")
		UIDropDownMenu_Initialize(copyMenu, function()
			local page = currentPage
			local target = page and page.tabs and page.activeTab
			if not target then
				return
			end
			for _, source in ipairs(copySources(page, target)) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = source.name
				info.notCheckable = 1
				info.func = function()
					CloseDropDownMenus()
					ns.Confirm(L["Copy %s settings to %s?"]:format(source.name, target.name), function()
						copyTab(page, source, target)
					end)
				end
				UIDropDownMenu_AddButton(info)
			end
		end, "MENU")

		local copy = createButton(panel, L["Copy from..."], 100, true, 20, "copy")
		copy:SetPoint("TOPRIGHT", -12, -12)
		copy:SetScript("OnClick", function(self)
			ToggleDropDownMenu(1, nil, copyMenu, self, 0, 0)
		end)
		copy:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(
				L["Copy from..."],
				HIGHLIGHT_FONT_COLOR.r,
				HIGHLIGHT_FONT_COLOR.g,
				HIGHLIGHT_FONT_COLOR.b
			)
			GameTooltip:AddLine(
				L["Copy the settings this tab shares with another tab, such as sizes and castbar."],
				NORMAL_FONT_COLOR.r,
				NORMAL_FONT_COLOR.g,
				NORMAL_FONT_COLOR.b,
				true
			)
			GameTooltip:Show()
		end)
		copy:HookScript("OnLeave", GameTooltip_Hide)
		copy:Hide()
		frame.copyButton = copy
	end
end

function showPage(page)
	if currentPage then
		if currentPage.onHide then
			currentPage.onHide()
		end
		hidePageContent(currentPage)
		if currentPage.button then
			currentPage.button:UnlockHighlight()
		end
	end
	local previous = currentPage
	currentPage = page
	if previous then
		paintNavGlyph(previous.button)
	end
	if page.tabs then
		showTabbedPage(page)
	else
		placeScroll(0)
		updateCopyButton(nil)
		if not page.content then
			buildPage(page)
		end
		showContent(page, frame.scroll, 0)
	end
	if page.button then
		page.button:LockHighlight()
		paintNavGlyph(page.button)
		lastNavPage = page
		markSeen(page)
		page.button.newBadge:Hide()
		changes.PlaceNav(page.button)
	end
	showPageTitle(page)
	if page.onShow then
		page.onShow()
	end
	refreshPage(page)
end

local function selectPage(page)
	if currentPage ~= page then
		showPage(page)
	end
end

local lower, collectSearch, parseQuery

do
	local CYRILLIC_LOWER = {}
	for byte = 0x80, 0xAF do
		local upper = "\208" .. string.char(byte)
		if byte < 0x90 then
			CYRILLIC_LOWER[upper] = "\209" .. string.char(byte + 0x10)
		elseif byte < 0xA0 then
			CYRILLIC_LOWER[upper] = "\208" .. string.char(byte + 0x20)
		else
			CYRILLIC_LOWER[upper] = "\209" .. string.char(byte - 0x20)
		end
	end

	function lower(text)
		return (text:lower():gsub("\208[\128-\175]", CYRILLIC_LOWER))
	end

	local SCORE_QUERY = 1000
	local SCORE_EXACT = 100
	local SCORE_PREFIX = 50
	local SCORE_LABEL = 20
	local SCORE_SECTION = 8
	local SCORE_DESC = 2

	local function tokenScore(label, section, desc, token)
		if label == token then
			return SCORE_EXACT
		elseif label:sub(1, #token) == token then
			return SCORE_PREFIX
		elseif label:find(token, 1, true) then
			return SCORE_LABEL
		elseif section:find(token, 1, true) then
			return SCORE_SECTION
		elseif desc:find(token, 1, true) then
			return SCORE_DESC
		end
		return 0
	end

	local function scoreText(label, section, desc, search)
		local tokens = search.tokens
		local score = label == search.query and SCORE_QUERY or 0
		for i = 1, #tokens do
			local points = tokenScore(label, section, desc, tokens[i])
			if points == 0 then
				return 0
			end
			score = score + points
		end
		return score
	end

	local function scoreEntry(entry, section, search)
		if not entry.label then
			return 0
		end
		return scoreText(lower(entry.label), section, entry.desc and lower(entry.desc) or "", search)
	end

	local function addGroup(groups, title, order, glyph)
		local group = { title = title, glyph = glyph, order = order, score = 0, results = {} }
		groups[#groups + 1] = group
		return group
	end

	local function addResult(group, entry, score)
		local results = group.results
		results[#results + 1] = { entry = entry, score = score, order = #results }
		if score > group.score then
			group.score = score
		end
	end

	local function byScore(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.order < b.order
	end

	local function collectEntries(groups, entries, title, context, search, glyph)
		local group
		local header, section = nil, context
		for _, entry in ipairs(entries) do
			if entry.header then
				header, group = entry.header, nil
				section = context .. " " .. lower(entry.header)
			elseif not entry.hidden then
				local score = scoreEntry(entry, section, search)
				if score > 0 then
					group = group or addGroup(groups, header and (title .. " / " .. header) or title, #groups, glyph)
					addResult(group, entry, score)
				end
			end
		end
	end

	function collectSearch(search)
		local groups = {}
		for _, page in ipairs(pages) do
			local pageContext = lower(page.name)
			local schema = page.schema
			if page.buildSchema then
				schema = page.buildSchema()
				adoptEntries(schema, page)
			end
			collectEntries(groups, schema, page.name, pageContext, search, page.glyph)
			for _, tab in ipairs(page.tabs or {}) do
				local tabSchema = tab.schema
				if tab.buildSchema then
					tabSchema = tab.buildSchema()
					adoptEntries(tabSchema, page)
				end
				local title = page.name .. " / " .. tab.name
				collectEntries(
					groups,
					tabSchema,
					title,
					pageContext .. " " .. lower(tab.name),
					search,
					tab.glyph or page.glyph
				)
			end
			for _, element in ipairs(elements) do
				if element.page == page.key and not element.hidden then
					local title = page.name .. " / " .. element.name
					local context = pageContext .. " " .. lower(element.name)
					local before = #groups
					collectEntries(groups, element.schema, title, context, search, page.glyph)
					if #groups == before then
						local score = scoreText(lower(element.name), pageContext, "", search)
						if score > 0 then
							addResult(addGroup(groups, title, #groups, page.glyph), elementButton(element, page), score)
						end
					end
				end
			end
		end

		sort(groups, byScore)
		local schema, count = {}, 0
		for _, group in ipairs(groups) do
			schema[#schema + 1] = { header = group.title, glyph = group.glyph }
			sort(group.results, byScore)
			for _, result in ipairs(group.results) do
				schema[#schema + 1] = result.entry
				count = count + 1
			end
		end
		return schema, count
	end

	function parseQuery(query)
		local tokens = {}
		for word in query:gmatch("%S+") do
			tokens[#tokens + 1] = word
		end
		return { query = query, tokens = tokens }
	end
end

local function runSearch()
	local query = lower(frame.searchBox:GetText():trim()):gsub("%s+", " ")
	if query == "" then
		if currentPage == searchPage then
			showPage(lastNavPage or pages[1])
		end
		return
	end
	if searchPage.query == query then
		selectPage(searchPage)
		return
	end
	local schema, count = collectSearch(parseQuery(query))
	if searchPage.content then
		searchPage.content:Hide()
	end
	if currentPage == searchPage then
		currentPage = nil
	end
	searchPage.query = query
	searchPage.schema = schema
	searchPage.content = nil
	searchPage.rows = nil
	searchPage.name = count > 0 and L["Search: %d results"]:format(count) or L["Search: no results"]
	showPage(searchPage)
end

local function scheduleSearch()
	local token = (frame.searchToken or 0) + 1
	frame.searchToken = token
	ui.After(SEARCH_DELAY, function()
		if frame.searchToken == token then
			runSearch()
		end
	end)
end

local function createSearchBox()
	local box = createEditBox(frame, LIST_WIDTH - 15)
	box:SetPoint("TOPLEFT", LIST_X + 8, PANEL_TOP + 2)
	box:SetMaxLetters(40)
	box:SetTextInsets(SEARCH_INSET, SEARCH_INSET, 0, 0)
	box.OnCommit = function() end
	box:SetScript("OnTextChanged", function(self)
		local empty = self:GetText() == ""
		ui.SetShown(self.placeholder, empty)
		ui.SetShown(self.clear, not empty)
		scheduleSearch()
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		runSearch()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		self:SetText("")
	end)

	local placeholder = box:CreateFontString(nil, "ARTWORK")
	placeholder:SetFontObject(font("GameFontDisableSmall"))
	placeholder:SetPoint("LEFT", SEARCH_INSET, 0)
	placeholder:SetText(L["Search settings..."])
	box.placeholder = placeholder

	local icon = createGlyph(box, "magnifying-glass", MARKER_SIZE, GRAY_FONT_COLOR)
	icon:SetPoint("LEFT", 0, 0)

	local clear = ui.CreateGlyphButton(box, "xmark", MARKER_SIZE)
	clear:SetPoint("RIGHT", 3, 0)
	clear:SetScript("OnClick", function()
		box:SetText("")
		box:ClearFocus()
	end)
	clear:Hide()
	box.clear = clear
	frame.searchBox = box
end

local LIST_CORNERS = {
	TOPLEFT = 0.5,
	TOPRIGHT = 0.625,
	BOTTOMLEFT = 0.75,
	BOTTOMRIGHT = 0.875,
}

local function listTexture(list, file, left)
	local texture = list:CreateTexture(nil, "BACKGROUND")
	texture:SetTexture(file)
	if left then
		texture:SetTexCoord(left, left + 0.125, 0, 1)
	end
	return texture
end

local function listEdge(list, left, top, bottom)
	local edge = listTexture(list, LIST_BORDER, left)
	edge:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
	edge:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
end

local function listSpacer(list, point, from, fromPoint, y, to, toPoint)
	local spacer = listTexture(list, SPACER_TEXTURE)
	spacer:SetHeight(16)
	spacer:SetPoint(point .. "LEFT", from, fromPoint, 0, y)
	spacer:SetPoint(point .. "RIGHT", to, toPoint)
end

local function createCategoryList()
	local list = CreateFrame("Frame", FRAME_NAME .. "CategoryList", frame)
	list:SetWidth(LIST_WIDTH)
	list:SetPoint("TOPLEFT", LIST_X, LIST_TOP)
	list:SetPoint("BOTTOMLEFT", LIST_X, FOOTER_TOP)

	local corners = {}
	for point, left in pairs(LIST_CORNERS) do
		local corner = listTexture(list, LIST_BORDER, left)
		corner:SetSize(16, 16)
		corner:SetPoint(point)
		corners[point] = corner
	end
	listEdge(list, 0, corners.TOPLEFT, corners.BOTTOMLEFT)
	listEdge(list, 0.125, corners.TOPRIGHT, corners.BOTTOMRIGHT)
	listSpacer(list, "TOP", corners.TOPLEFT, "TOPRIGHT", 7, corners.TOPRIGHT, "TOPLEFT")
	listSpacer(list, "BOTTOM", corners.BOTTOMLEFT, "BOTTOMRIGHT", -2, corners.BOTTOMRIGHT, "BOTTOMLEFT")
	frame.list = list
end

local function createNavButton(page, index, y)
	local name = FRAME_NAME .. "Category" .. index
	local button = CreateFrame("Button", name, frame.list, "OptionsListButtonTemplate")
	button:SetPoint("TOPLEFT", 0, y)
	setButtonFonts(button)
	button:SetText(page.name)

	local text = _G[name .. "Text"]
	text:ClearAllPoints()
	text:SetPoint("LEFT", NAV_GLYPH_X + GLYPH_BOX + GLYPH_GAP, 2)
	text:SetPoint("RIGHT", -8, 2)

	if page.glyph then
		local glyph = createGlyph(button, page.glyph, GLYPH_SIZE, NORMAL_FONT_COLOR)
		glyph:SetPoint("CENTER", button, "LEFT", NAV_GLYPH_X + GLYPH_BOX / 2, 2)
		button.glyph = glyph
		button:HookScript("OnEnter", function(self)
			self.hovered = true
			paintNavGlyph(self)
		end)
		button:HookScript("OnLeave", function(self)
			self.hovered = nil
			paintNavGlyph(self)
		end)
	end

	local badge = button:CreateFontString(nil, "OVERLAY")
	badge:SetFontObject(font("GameFontGreenSmall"))
	badge:SetText(L["NEW"])
	badge:SetPoint("RIGHT", -8, 2)
	button.newBadge = badge
	button.label = text
	ui.SetShown(badge, newestUnseen(page))
	changes.AttachNav(button)

	button:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		frame.searchBox:SetText("")
		selectPage(page)
	end)
	page.button = button
end

local seenLoaded = false

local function initSeen()
	if seenLoaded then
		return
	end
	seenLoaded = true
	ui.db.showAdvancedSettings = nil
	for key, version in pairs(seenStore()) do
		seenAtOpen[key] = version
	end
end

StaticPopupDialogs["FROSTATOMUI_CONFIG_DEFAULTS"] = {
	text = L["Reset all FrostAtom UI settings to defaults, or only the settings of %s?"],
	button1 = L["Reset all"],
	button3 = L["Reset page"],
	button2 = CANCEL,
	OnAccept = function()
		ui:ResetConfig()
	end,
	OnAlt = function(_, page)
		resetPage(page)
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local function confirmDefaults()
	PlaySound("igMainMenuOption")
	local page = currentPage
	if page.noReset then
		ns.Confirm(L["Reset all FrostAtom UI settings to defaults?"], function()
			ui:ResetConfig()
		end)
		return
	end
	local dialog = StaticPopup_Show("FROSTATOMUI_CONFIG_DEFAULTS", page.name, nil, page)
	if dialog then
		dialog:SetFrameStrata(POPUP_STRATA)
	end
end

local function createPanelScroll(parent, name)
	local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", SCROLL_LEFT, SCROLL_TOP)
	scroll:SetPoint("BOTTOMRIGHT", SCROLL_RIGHT, SCROLL_BOTTOM)
	scroll.scrollBarHideable = true
	scroll:SetScript("OnSizeChanged", function(self)
		self:UpdateScrollChildRect()
		ScrollFrame_OnScrollRangeChanged(self)
	end)
	return scroll
end

local function createFrame()
	initSeen()

	frame = createWindow(FRAME_NAME, {
		width = WIDTH,
		height = HEIGHT,
		title = "FrostAtom UI",
		header = true,
		noClose = true,
		movable = false,
		special = false,
	})
	frame:SetPoint("CENTER")
	ui.SetUIPanelLayout(frame, "center", 0)
	frame:SetScript("OnShow", function()
		PlaySound("igMainMenuOption")
		if currentPage and currentPage.onShow then
			currentPage.onShow()
		end
		refreshPage(currentPage)
		changes.UpdateNav()
	end)
	frame:SetScript("OnHide", function()
		PlaySound("gsTitleOptionExit")
		if currentPage and currentPage.onHide then
			currentPage.onHide()
		end
	end)

	createCategoryList()

	local panel = ui.CreateInset(frame, "panel")
	panel:SetPoint("TOPLEFT", PANEL_X, PANEL_TOP)
	panel:SetPoint("BOTTOMRIGHT", PANEL_RIGHT, FOOTER_TOP)

	local title = panel:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(font("GameFontNormalLarge"))
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetJustifyH("LEFT")
	frame.pageTitle = title

	local pageGlyph = createGlyph(panel, "gear", TITLE_GLYPH_SIZE, NORMAL_FONT_COLOR)
	pageGlyph:SetPoint("CENTER", title, "LEFT", -GLYPH_GAP - (TITLE_GLYPH_SIZE + 4) / 2, 0)
	pageGlyph:Hide()
	frame.pageGlyph = pageGlyph
	frame.panel = panel

	createCopyButton(panel)

	local defaults = createButton(frame, L["Defaults"], FOOTER_BUTTON_WIDTH, true, nil, "rotate-left")
	defaults:SetPoint("BOTTOMLEFT", EDGE, EDGE)
	defaults:SetScript("OnClick", confirmDefaults)

	local unlock = createButton(frame, L["Unlock frames"], 120, nil, nil, "up-down-left-right")
	unlock:SetPoint("LEFT", defaults, "RIGHT", 4, 0)
	unlock:SetScript("OnClick", function()
		ui.Movers.Unlock()
		if ui.Movers.IsUnlocked() then
			HideUIPanel(frame)
		end
	end)

	local okay = createButton(frame, L["Close"], FOOTER_BUTTON_WIDTH)
	okay:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	okay:SetScript("OnClick", function()
		HideUIPanel(frame)
	end)

	local reloadButton = createButton(frame, L["Reload UI"], FOOTER_BUTTON_WIDTH, nil, nil, "rotate")
	reloadButton:SetPoint("RIGHT", okay, "LEFT", -4, 0)
	reloadButton:SetScript("OnClick", ReloadUI)
	reloadButton:Hide()
	frame.reloadButton = reloadButton

	frame.scroll = createPanelScroll(panel, FRAME_NAME .. "Scroll")

	createSearchBox()
	local y, group = -8, pages[1].group
	for i, page in ipairs(pages) do
		if page.group ~= group then
			group = page.group
			y = y - NAV_GROUP_GAP
		end
		createNavButton(page, i, y)
		y = y - NAV_BUTTON_HEIGHT
	end

	selectPage(pages[1])
end

local function placeElementFrame(anchor)
	elementFrame:ClearAllPoints()
	local left, right = anchor and anchor:GetLeft(), anchor and anchor:GetRight()
	if not left then
		elementFrame:SetPoint("CENTER")
		return
	end
	local scale = anchor:GetEffectiveScale() / elementFrame:GetEffectiveScale()
	local top = anchor:GetTop() * scale
	local screenWidth = UIParent:GetWidth() * UIParent:GetEffectiveScale() / elementFrame:GetEffectiveScale()
	local width = elementFrame:GetWidth()
	local x
	if right * scale + ELEMENT_GAP + width <= screenWidth then
		x = right * scale + ELEMENT_GAP
	elseif left * scale - ELEMENT_GAP - width >= 0 then
		x = left * scale - ELEMENT_GAP - width
	else
		x = (screenWidth - width) / 2
	end
	elementFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
end

local function createElementFrame()
	initSeen()
	elementFrame = createWindow(FRAME_NAME .. "Element", {
		width = ELEMENT_WIDTH,
		height = 200,
		header = true,
		strata = ELEMENT_STRATA,
	})
	elementFrame:SetScript("OnDragStart", function(self)
		self.userPlaced = true
		self:StartMoving()
	end)
	elementFrame:SetScript("OnHide", function(self)
		self.userPlaced = nil
		ui.Movers.ClearSelection()
	end)

	local titleGlyph = createGlyph(elementFrame.header, "gear", GLYPH_SIZE, NORMAL_FONT_COLOR)
	titleGlyph:SetPoint("RIGHT", elementFrame.title, "LEFT", -GLYPH_GAP, 0)
	titleGlyph:Hide()
	elementFrame.titleGlyph = titleGlyph

	local panel = ui.CreateInset(elementFrame, "panel")
	panel:SetPoint("TOPLEFT", EDGE, ELEMENT_TOP)
	panel:SetPoint("BOTTOMRIGHT", -EDGE, ELEMENT_BOTTOM)

	local resetPosition = createButton(elementFrame, L["Reset position"], 120, true, nil, "location-crosshairs")
	resetPosition:SetPoint("BOTTOMLEFT", EDGE, EDGE)
	resetPosition:SetScript("OnClick", function()
		ui:ResetConfig(elementFrame.view.element.path)
	end)
	elementFrame.resetPosition = resetPosition

	local resetAll = createButton(elementFrame, L["Reset all"], 100, true, nil, "rotate-left")
	resetAll:SetPoint("LEFT", resetPosition, "RIGHT", 4, 0)
	resetAll:SetScript("OnClick", function()
		local view = elementFrame.view
		ns.Confirm(L["Reset %s settings to defaults?"]:format(view.element.name), function()
			resetSchema(view.schema)
		end)
	end)
	elementFrame.resetAll = resetAll

	local more = createButton(elementFrame, L["All settings"], 120, nil, nil, "sliders")
	more:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	more:SetScript("OnClick", function()
		local element = elementFrame.view.element
		ui.Movers.Lock()
		ns.Toggle(element.page, element.tab, element)
	end)
	elementFrame.more = more

	local scroll = createPanelScroll(panel, FRAME_NAME .. "ElementScroll")
	scroll:SetPoint("TOPLEFT", SCROLL_LEFT, -SCROLL_LEFT)
	elementFrame.scroll = scroll
end

local function showElementTitle(element)
	local glyph = element.glyph
	local titleGlyph = elementFrame.titleGlyph
	local shift = 0
	if glyph then
		ui.SetGlyph(titleGlyph, glyph)
		shift = (titleGlyph:GetStringWidth() + GLYPH_GAP) / 2
	end
	ui.SetShown(titleGlyph, glyph)
	elementFrame.title:SetPoint("TOP", elementFrame.header.middle, "TOP", shift, -14)
	elementFrame.title:SetText(element.name)
end

local function elementView(element)
	local view = element.view
	if view then
		return view
	end
	local schema = {}
	for _, entry in ipairs(element.schema) do
		if entry.header or ns.IsLayoutEntry(entry) then
			schema[#schema + 1] = entry
		end
	end
	local page = pageByKey(element.page)
	for _, path in ipairs(element.layout or {}) do
		local shared = page and ns.FindEntry(page, path)
		if shared then
			schema[#schema + 1] = shared
		end
	end
	view = {
		key = element.key,
		element = element,
		scroll = elementFrame.scroll,
		width = CONTENT_WIDTH,
		schema = schema,
	}
	schema[#schema + 1] = { header = L["Position"], page = view }
	schema[#schema + 1] = {
		type = "point",
		path = element.path,
		label = L["Anchor and offset"],
		desc = L["Drag the frame to move it; snapping to another frame attaches it to that frame."],
		page = view,
	}
	element.view = view
	return view
end

function ns.OpenElement(path, anchor)
	if not elementFrame then
		createElementFrame()
	end
	local element = elementFor(path)
	local view = elementView(element)
	if elementFrame:IsShown() and elementFrame.view == view then
		refreshPage(view)
		return
	end
	if elementFrame.view and elementFrame.view.content then
		elementFrame.view.content:Hide()
	end
	elementFrame.view = view
	showElementTitle(element)
	if not view.content then
		buildPage(view)
	end
	showContent(view, elementFrame.scroll, 0)
	ui.SetShown(elementFrame.more, element.page ~= nil)
	ui.SetShown(elementFrame.resetPosition, not element.noReset)
	ui.SetShown(elementFrame.resetAll, not element.noReset)

	fitElementFrame(view)
	if not elementFrame.userPlaced or not elementFrame:IsShown() then
		placeElementFrame(anchor)
	end
	elementFrame:Show()
	refreshPage(view)
end

function ns.CloseElement()
	if elementFrame and elementFrame:IsShown() then
		elementFrame:Hide()
	end
end

function ns.GetOpenElement()
	local view = elementFrame and elementFrame:IsShown() and elementFrame.view
	return view and view.element.path or nil
end

function ns.EditElement(path)
	HideUIPanel(frame)
	ui.Movers.Unlock()
	if not ui.Movers.IsUnlocked() then
		return
	end
	if not ui.Movers.Select(path) then
		ns.OpenElement(path)
	end
end

local function refreshShown()
	if frame and frame:IsShown() then
		refreshPage(currentPage)
		changes.ScheduleNav()
	end
	if elementFrame and elementFrame:IsShown() then
		refreshPage(elementFrame.view)
	end
end

local watcher = ui.Mixin({}, ui.EventMixin)
watcher:RegisterEvent(ui.CONFIG_CHANGED, refreshShown)
watcher:RegisterEvent(ui.PROFILES_CHANGED, refreshShown)
watcher:RegisterEvent("UPDATE_BINDINGS", refreshShown)

local function scrollToElement(page, element)
	local view = page.tabs and page.activeTab and page.activeTab.view or page
	for _, item in ipairs(view.items or {}) do
		local entry = item.header and item.section.header or item.row.entry
		if entry and entry.element == element then
			local _, _, _, _, y = item.row:GetPoint(1)
			local scroll = frame.scroll
			scroll:UpdateScrollChildRect()
			scroll:SetVerticalScroll(max(0, min(-y - CONTENT_TOP, scroll:GetVerticalScrollRange())))
			return
		end
	end
end

function ns.Toggle(pageKey, tabKey, element)
	if not frame then
		createFrame()
	end
	if not pageKey then
		if frame:IsShown() then
			HideUIPanel(frame)
		else
			ShowUIPanel(frame)
		end
		return
	end
	local page = pageByKey(pageKey)
	if page then
		frame.searchBox:SetText("")
		selectPage(page)
		local tab = tabKey and page.tabs and tabByKey(page, tabKey)
		if tab and tab ~= page.activeTab then
			selectTab(page, tab)
		end
	else
		frame.searchBox:SetText(pageKey)
		runSearch()
	end
	ShowUIPanel(frame)
	if page and element then
		ui.After(0.05, function()
			scrollToElement(page, element)
		end)
	end
end

_G[ADDON_NAME] = ns
