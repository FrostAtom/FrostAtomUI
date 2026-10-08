local ADDON_NAME, ns = ...

local ui = FrostAtomUI
local L = ui.L

local tinsert, sort = tinsert, table.sort

local FRAME_NAME = ADDON_NAME .. "Frame"
local WIDTH, HEIGHT = 780, 600
local EDGE = 16
local LIST_X, LIST_TOP, LIST_WIDTH = 22, -64, 175
local PANEL_X, PANEL_TOP, PANEL_RIGHT = 213, -40, -22
local FOOTER_TOP = 50
local SCROLL = {
	LEFT = 8,
	TOP = -40,
	RIGHT = -27,
	BOTTOM = 6,
}
local CONTENT_WIDTH = WIDTH - PANEL_X + PANEL_RIGHT - SCROLL.LEFT + SCROLL.RIGHT
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
local ELEMENT = {
	WIDTH = EDGE * 2 + SCROLL.LEFT - SCROLL.RIGHT + CONTENT_WIDTH,
	TOP = -30,
	BOTTOM = 46,
	GAP = 8,
	MIN_HEIGHT = 140,
	MAX_HEIGHT = 560,
	STRATA = "FULLSCREEN",
}
local POPUP_STRATA = "FULLSCREEN_DIALOG"
local FONT_SIZE = { MIN = 6, MAX = 32 }
local TEXTURE = {
	HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight",
	SPACER = "Interface\\OptionsFrame\\UI-OptionsFrame-Spacer",
	LIST_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
	SWATCH = "Interface\\ChatFrame\\ChatFrameColorSwatch",
}
local HIGHLIGHT_COLOR = { 0.196, 0.388, 0.8 }
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

local P = {}
ns.private = P
P.refreshing = false
P.widgetCount = 0
P.seenLoaded = false
P.scrollMemory = {}

local changes = {}

local searchPage = { key = "search", name = L["Search"], glyph = "magnifying-glass", schema = {}, noReset = true }

local function adoptEntries(schema, owner, tabKey)
	for _, entry in ipairs(schema) do
		entry.page = owner
		entry.seenTab = tabKey
	end
end

function ns.SetBlizzardSwap(handler)
	ns.blizzardSwap = handler
end

ns.UNITS = {
	s = L["%s s"],
	ms = L["%s ms"],
	min = L["%s min"],
	px = L["%s px"],
}

do
	local LAYOUT_TYPES = { point = true, offset = true }
	local LAYOUT_KEYS = {
		"size",
		"width",
		"height",
		"scale",
		"spacing",
		"padding",
		"gap",
		"column",
		"perrow",
		"rows?$",
		"^buttons$",
		"max$",
		"^max",
		"grow",
		"direction",
		"orientation",
		"anchor",
		"offset",
		"attach",
		"position",
	}
	local NOT_LAYOUT_KEYS = { "font", "text", "border" }

	function ns.IsLayoutEntry(entry)
		if entry.layout ~= nil then
			return entry.layout
		elseif LAYOUT_TYPES[entry.type] then
			return true
		elseif not entry.path or entry.type == "font" or entry.type == "color" then
			return false
		end
		local key = entry.path:match("[^.]+$"):lower()
		for _, word in ipairs(NOT_LAYOUT_KEYS) do
			if key:find(word) then
				return false
			end
		end
		for _, word in ipairs(LAYOUT_KEYS) do
			if key:find(word) then
				return true
			end
		end
		return false
	end

	function ns.FindEntry(page, path)
		local schemas = { page.schema }
		for _, tab in ipairs(page.tabs or {}) do
			schemas[#schemas + 1] = tab.schema
		end
		for _, schema in ipairs(schemas) do
			for _, entry in ipairs(schema) do
				if entry.path == path then
					return entry
				end
			end
		end
	end
end

local pendingTabs = {}

local function sortTabs(page)
	sort(page.tabs, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)
end

function ns.RegisterPage(page)
	page.schema = page.schema or {}
	adoptEntries(page.schema, page)
	local pending = pendingTabs[page.key]
	if pending then
		page.tabs = page.tabs or {}
		for _, tab in ipairs(pending) do
			tinsert(page.tabs, tab)
		end
		pendingTabs[page.key] = nil
	end
	for _, tab in ipairs(page.tabs or {}) do
		tab.schema = tab.schema or {}
		adoptEntries(tab.schema, page, tab.key)
	end
	if page.tabs then
		sortTabs(page)
	end
	tinsert(pages, page)
	sort(pages, function(a, b)
		return a.order < b.order
	end)
end

function ns.AddTab(pageKey, tab)
	for _, page in ipairs(pages) do
		if page.key == pageKey then
			tab.schema = tab.schema or {}
			adoptEntries(tab.schema, page, tab.key)
			page.tabs = page.tabs or {}
			tinsert(page.tabs, tab)
			sortTabs(page)
			return
		end
	end
	pendingTabs[pageKey] = pendingTabs[pageKey] or {}
	tinsert(pendingTabs[pageKey], tab)
end

ns.PAGE_ALIASES = {
	qol = { "automation" },
	pvp = { "control" },
	losecontrol = { "control", "frames" },
	spellalerts = { "alerts", "voice" },
	transfer = { "profiles", "transfer" },
	backups = { "profiles", "backups" },
}

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
		disabledDesc = element.disabledDesc,
		new = element.new,
		glyph = element.glyph or "up-down-left-right",
		page = page,
		func = function()
			P.EditElement(element.path)
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

function ns.TabRequires(enabledBy, entries)
	for _, entry in ipairs(entries) do
		if entry.path ~= enabledBy and (entry.path or entry.type or entry.header or entry.description) then
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

local clickThroughEntries = {}

function ns.ClickThrough(path, enabledBy, enabledByAny)
	local entry = {
		path = path,
		new = "1.5.0",
		label = L["Click-through"],
		type = "toggle",
		advanced = true,
		enabledBy = enabledBy,
		enabledByAny = enabledByAny,
		desc = L["The icons ignore the mouse: no tooltips and no right-click, clicks pass through to the world behind them."],
	}
	clickThroughEntries[#clickThroughEntries + 1] = entry
	return entry
end

local function clickThroughPaths()
	local paths, seen = {}, {}
	for _, entry in ipairs(clickThroughEntries) do
		local path = entry.path
		if type(path) == "string" and path:find(".", 1, true) and not seen[path] then
			seen[path] = true
			paths[#paths + 1] = path
		end
	end
	return paths
end

function ns.AllClickThrough()
	local paths = clickThroughPaths()
	for _, path in ipairs(paths) do
		if not ui:GetConfig(path) then
			return false
		end
	end
	return #paths > 0
end

function ns.SetAllClickThrough(value)
	ui.Undo.Run(L["Aura icons ignore the mouse"], function()
		for _, path in ipairs(clickThroughPaths()) do
			ui:SetConfig(path, value and true or false)
		end
	end)
end

P.CHILD_INDENT = CHILD_INDENT
P.CONTENT_BOTTOM = CONTENT_BOTTOM
P.CONTENT_TOP = CONTENT_TOP
P.CONTENT_WIDTH = CONTENT_WIDTH
P.CONTROL_X = CONTROL_X
P.EDGE = EDGE
P.ELEMENT = ELEMENT
P.FONT_OBJECTS = FONT_OBJECTS
P.FONT_SLIDER_WIDTH = FONT_SLIDER_WIDTH
P.FOOTER_BUTTON_WIDTH = FOOTER_BUTTON_WIDTH
P.FOOTER_TOP = FOOTER_TOP
P.FRAME_NAME = FRAME_NAME
P.GLYPH_BOX = GLYPH_BOX
P.GLYPH_GAP = GLYPH_GAP
P.GLYPH_SIZE = GLYPH_SIZE
P.HEADER_HEIGHT = HEADER_HEIGHT
P.HEIGHT = HEIGHT
P.HIGHLIGHT_COLOR = HIGHLIGHT_COLOR
P.INLINE_FLAT_CONTROLS = INLINE_FLAT_CONTROLS
P.LABEL_X = LABEL_X
P.LIST_TOP = LIST_TOP
P.LIST_WIDTH = LIST_WIDTH
P.LIST_X = LIST_X
P.MARKER_SIZE = MARKER_SIZE
P.NAV_BUTTON_HEIGHT = NAV_BUTTON_HEIGHT
P.NAV_GLYPH_X = NAV_GLYPH_X
P.NAV_GROUP_GAP = NAV_GROUP_GAP
P.OUTLINES = OUTLINES
P.PANEL_RIGHT = PANEL_RIGHT
P.PANEL_TOP = PANEL_TOP
P.PANEL_X = PANEL_X
P.POPUP_STRATA = POPUP_STRATA
P.RELOAD_COLOR = RELOAD_COLOR
P.REVERT_SECONDS = REVERT_SECONDS
P.ROW_HEIGHT = ROW_HEIGHT
P.SCROLL = SCROLL
P.SEARCH_DELAY = SEARCH_DELAY
P.SEARCH_INSET = SEARCH_INSET
P.SECTION_GAP = SECTION_GAP
P.SLIDER_WIDTH = SLIDER_WIDTH
P.TEXTURE = TEXTURE
P.TITLE_GLYPH_SIZE = TITLE_GLYPH_SIZE
P.VALUE_BOX_WIDTH = VALUE_BOX_WIDTH
P.WIDTH = WIDTH
P.FONT_SIZE = FONT_SIZE
P.adoptEntries = adoptEntries
P.changes = changes
P.elementButton = elementButton
P.elementFor = elementFor
P.elements = elements
P.pages = pages
P.searchPage = searchPage
