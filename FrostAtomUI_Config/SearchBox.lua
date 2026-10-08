local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local P = ns.private
local LIST_WIDTH = P.LIST_WIDTH
local LIST_X = P.LIST_X
local MARKER_SIZE = P.MARKER_SIZE
local PANEL_TOP = P.PANEL_TOP
local SEARCH_DELAY = P.SEARCH_DELAY
local SEARCH_INSET = P.SEARCH_INSET
local adoptEntries = P.adoptEntries
local createEditBox = P.createEditBox
local createGlyph = P.createGlyph
local elementButton = P.elementButton
local elements = P.elements
local font = P.font
local pages = P.pages
local searchPage = P.searchPage
local selectPage = P.selectPage
local showPage = P.showPage

local lower = ui.Lower
local changes = P.changes
local searchSources

local FILTERS = {
	changed = function(entry)
		return changes.IsModified(entry)
	end,
	preset = function(entry)
		return changes.IsPreset(entry)
	end,
	new = function(entry)
		return P.isReleaseEntry(entry)
	end,
	reload = function(entry)
		return entry.path ~= nil and ns.NeedsReload(entry) and true or false
	end,
	off = function(entry)
		return entry.type == "toggle"
			and type(entry.path) == "string"
			and entry.path:find("%.enabled$") ~= nil
			and ui:GetConfig(entry.path) == false
	end,
}

local function accept(filter, entry)
	return FILTERS[filter](entry)
end

do
	local RANK_TAB, RANK_PAGE, RANK_ELEMENT = 1, 2, 3

	local function currentSchema(source, page, tabKey)
		if not source.buildSchema then
			return source.schema
		end
		local signature = source.signature and source.signature()
		if source.searchSchema and source.searchSignature == signature then
			return source.searchSchema
		end
		local schema = source.buildSchema()
		adoptEntries(schema, page, tabKey)
		source.searchSchema, source.searchSignature = schema, signature
		return schema
	end

	local fallbackEntries = {}
	local positionEntries = {}

	local function positionEntry(element)
		local entry = positionEntries[element.path]
		if not entry then
			entry = {
				type = "point",
				path = element.path,
				label = L["Position"],
				keywords = L["Anchor and offset"],
				desc = L["Drag the frame to move it; snapping to another frame attaches it to that frame."],
			}
			adoptEntries({ entry }, element)
			positionEntries[element.path] = entry
		end
		return entry
	end

	local function elementFallback(element, page, context)
		local key = "element:" .. element.path
		return {
			key = key,
			name = lower(element.name),
			context = context,
			build = function()
				local entry = fallbackEntries[key]
				if not entry then
					entry = elementButton(element, page)
					fallbackEntries[key] = entry
				end
				return entry
			end,
		}
	end

	function searchSources()
		local sources = {}
		for _, page in ipairs(pages) do
			local pageContext = lower(page.name) .. " " .. lower(ui.SourceText(page.name) or "")
			sources[#sources + 1] = {
				entries = page.noSearch and {} or currentSchema(page, page),
				title = page.name,
				context = pageContext,
				glyph = page.glyph,
				rank = RANK_PAGE,
			}
			for _, tab in ipairs(page.tabs or {}) do
				sources[#sources + 1] = {
					entries = currentSchema(tab, page, tab.key),
					title = page.name .. " / " .. tab.name,
					context = pageContext .. " " .. lower(tab.name),
					glyph = tab.glyph or page.glyph,
					rank = RANK_TAB,
				}
			end
			for _, element in ipairs(elements) do
				if element.page == page.key and not element.hidden then
					local entries = element.searchEntries
					if not entries then
						entries = { positionEntry(element) }
						for _, entry in ipairs(element.schema) do
							entries[#entries + 1] = entry
						end
						element.searchEntries = entries
					end
					sources[#sources + 1] = {
						entries = entries,
						title = page.name .. " / " .. element.name,
						context = pageContext .. " " .. lower(element.name),
						glyph = page.glyph,
						rank = RANK_ELEMENT,
						fallback = elementFallback(element, page, pageContext),
					}
				end
			end
		end
		return sources
	end
end

local function collectSearch(search)
	return ns.Search.Collect(searchSources(), search)
end

local cursor
local FLASH_SECONDS = 1.5

local function clearCursor()
	if cursor and cursor.highlight then
		cursor.highlight:Hide()
	end
	cursor = nil
end

local function resultRows()
	local rows = {}
	for _, item in ipairs(searchPage.items or {}) do
		local row = item.row
		if not item.header and row.entry and row:IsShown() and not row.entry.description and row.highlight then
			rows[#rows + 1] = row
		end
	end
	return rows
end

local function scrollToRow(row)
	local _, _, _, _, y = row:GetPoint(1)
	local scroll = P.frame.scroll
	scroll:UpdateScrollChildRect()
	local top, height = -y, row:GetHeight()
	local current, visible = scroll:GetVerticalScroll(), scroll:GetHeight()
	if top < current then
		scroll:SetVerticalScroll(math.max(0, top - 8))
	elseif top + height > current + visible then
		scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), top + height - visible + 8))
	end
end

local function moveCursor(delta)
	if P.currentPage ~= searchPage then
		return
	end
	local rows = resultRows()
	if #rows == 0 then
		return
	end
	local index = 0
	for i, row in ipairs(rows) do
		if row == cursor then
			index = i
		end
	end
	clearCursor()
	index = index + delta
	if index < 1 then
		index = #rows
	elseif index > #rows then
		index = 1
	end
	cursor = rows[index]
	cursor.highlight:Show()
	scrollToRow(cursor)
end

local function flashEntry(entry)
	local page = P.currentPage
	local view = page and (page.tabs and page.activeTab and page.activeTab.view or page)
	for _, item in ipairs(view and view.items or {}) do
		local row = item.row
		if row.entry == entry and row:IsShown() and row.highlight then
			scrollToRow(row)
			row.highlight:Show()
			ui.After(FLASH_SECONDS, function()
				if not row:IsMouseOver() then
					row.highlight:Hide()
				end
			end)
			return
		end
	end
end

local function openCursor()
	local row = cursor
	if not row or P.currentPage ~= searchPage or not row:IsShown() then
		return false
	end
	local entry = row.entry
	local owner = entry.page
	if type(owner) ~= "table" or not owner.key then
		return false
	end
	clearCursor()
	if owner.path and owner.page then
		ns.Toggle(owner.page, owner.tab, owner)
		return true
	end
	ns.Toggle(owner.key, entry.seenTab)
	ui.After(0.05, function()
		flashEntry(entry)
	end)
	return true
end

local NEAREST_PAGES = 3

local function trigrams(text)
	local set, count = {}, 0
	text = " " .. text .. " "
	for i = 1, #text - 2 do
		local gram = text:sub(i, i + 2)
		if not set[gram] then
			set[gram] = true
			count = count + 1
		end
	end
	return set, count
end

local function pageText(page)
	local parts = { page.name, ui.SourceText(page.name) or "" }
	for _, tab in ipairs(page.tabs or {}) do
		parts[#parts + 1] = tab.name
	end
	return lower(table.concat(parts, " "))
end

local function nearestPages(query, schema)
	local wanted, size = trigrams(query)
	if size == 0 then
		return
	end
	local scored = {}
	for _, page in ipairs(pages) do
		if not page.noSearch then
			local have, total = trigrams(pageText(page))
			local hits = 0
			for gram in pairs(wanted) do
				if have[gram] then
					hits = hits + 1
				end
			end
			if hits > 0 then
				scored[#scored + 1] = { page = page, score = hits / math.sqrt(size * total) }
			end
		end
	end
	table.sort(scored, function(a, b)
		return a.score > b.score
	end)
	if #scored == 0 then
		return
	end
	schema[#schema + 1] = { header = L["Maybe on these pages"], glyph = "lightbulb" }
	for i = 1, math.min(NEAREST_PAGES, #scored) do
		local page = scored[i].page
		schema[#schema + 1] = {
			type = "execute",
			label = page.name,
			text = L["Open"],
			glyph = page.glyph,
			desc = page.desc,
			func = function()
				P.frame.searchBox:SetText("")
				ns.Toggle(page.key)
			end,
		}
	end
end

local function runSearch()
	clearCursor()
	local query = lower(P.frame.searchBox:GetText():trim()):gsub("%s+", " ")
	if query == "" then
		if P.currentPage == searchPage then
			showPage(P.lastNavPage or pages[1])
		end
		return
	end
	if searchPage.query == query then
		selectPage(searchPage)
		return
	end
	local search = ns.Search.ParseQuery(query)
	search.accept = accept
	local schema, count, shown = collectSearch(search)
	local name = count > 0 and L["Search: %d results"]:format(count) or L["Search: no results"]
	if count == 0 and not ns.Search.HasOperators(search) then
		local latin = ui.FromRussianLayout(query)
		if latin ~= query then
			schema, count, shown = collectSearch(ns.Search.ParseQuery(latin))
			name = L['Search: %d results for "%s"']:format(count, latin)
		end
		local fixed = count == 0 and ns.Search.Correct(query, searchSources())
		if fixed then
			schema, count, shown = collectSearch(ns.Search.ParseQuery(fixed))
			name = L['Search: %d results for "%s"']:format(count, fixed)
		end
	end
	if count == 0 then
		name = L["Search: no results"]
		schema = { { description = L['Nothing found. Try "castbar", "trinket", "cd" or a page on the left.'] } }
		if ns.Search.HasOperators(search) then
			schema[1].description = L["Nothing matches these filters."]
		else
			nearestPages(query, schema)
		end
	elseif shown < count then
		schema[#schema + 1] =
			{ description = L["%d more results: add a word to narrow the search."]:format(count - shown) }
	end
	if searchPage.content then
		searchPage.content:Hide()
	end
	if P.currentPage == searchPage then
		P.currentPage = nil
	end
	searchPage.query = query
	searchPage.schema = schema
	searchPage.content = nil
	searchPage.rows = nil
	searchPage.name = name
	showPage(searchPage)
end

local function scheduleSearch()
	local token = (P.frame.searchToken or 0) + 1
	P.frame.searchToken = token
	ui.After(SEARCH_DELAY, function()
		if P.frame.searchToken == token then
			runSearch()
		end
	end)
end

local function createSearchBox()
	local box = createEditBox(P.frame, LIST_WIDTH - 15)
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
		if not openCursor() then
			runSearch()
		end
	end)
	box:SetScript("OnKeyDown", function(_, key)
		if key == "DOWN" then
			moveCursor(1)
		elseif key == "UP" then
			moveCursor(-1)
		end
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
	P.frame.searchBox = box
end

local SEARCH_KEY = "CTRL-F"
local searchKey

local function bindSearchKey(active)
	if not searchKey then
		searchKey = CreateFrame("Button", P.FRAME_NAME .. "SearchKey", P.frame)
		searchKey:SetScript("OnClick", function()
			local box = P.frame.searchBox
			box:SetFocus()
			box:HighlightText()
		end)
	end
	if InCombatLockdown() then
		return
	end
	ClearOverrideBindings(searchKey)
	local action = GetBindingAction(SEARCH_KEY)
	if active and (not action or action == "") then
		SetOverrideBindingClick(searchKey, false, SEARCH_KEY, searchKey:GetName())
	end
end

local keyWatcher = ui.Mixin({}, ui.EventMixin)
keyWatcher:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if searchKey then
		ClearOverrideBindings(searchKey)
	end
end)
keyWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if P.frame and P.frame:IsShown() then
		bindSearchKey(true)
	end
end)

P.bindSearchKey = bindSearchKey
P.createSearchBox = createSearchBox
P.runSearch = runSearch
