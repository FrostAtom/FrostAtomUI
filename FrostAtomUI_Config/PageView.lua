local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local max = math.max
local min = math.min
local abs = math.abs
local tinsert = tinsert

local P = ns.private
local CONTENT_BOTTOM = P.CONTENT_BOTTOM
local CONTENT_TOP = P.CONTENT_TOP
local CONTENT_WIDTH = P.CONTENT_WIDTH
local ELEMENT = P.ELEMENT
local GLYPH_BOX = P.GLYPH_BOX
local GLYPH_GAP = P.GLYPH_GAP
local LABEL_X = P.LABEL_X
local MARKER_SIZE = P.MARKER_SIZE
local ROW_HEIGHT = P.ROW_HEIGHT
local SCROLL = P.SCROLL
local SECTION_GAP = P.SECTION_GAP
local addNewBadge = P.addNewBadge
local changes = P.changes
local createGlyph = P.createGlyph
local createHighlight = P.createHighlight
local creators = P.creators
local expandSchema = P.expandSchema
local font = P.font
local isEntryEnabled = P.isEntryEnabled
local isNewEntry = P.isNewEntry
local searchPage = P.searchPage
local setTextEnabled = P.setTextEnabled

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

	local SHOWN_EXTRA = 2
	local SECONDARY_TYPES = { font = true, offset = true }
	local MAX_BASIC = 10
	local VIEW_BUDGET = 25

	local function pinned(entry)
		return entry.type == "execute"
			or entry.danger
			or entry.description ~= nil
			or type(entry.path) == "string" and entry.path:find("%.enabled$") ~= nil
	end

	local function limitBasic(section)
		local kept, moved, controls = {}, {}, 0
		for _, entry in ipairs(section.basic) do
			if pinned(entry) then
				kept[#kept + 1] = entry
			elseif controls < MAX_BASIC then
				controls = controls + 1
				kept[#kept + 1] = entry
			else
				moved[#moved + 1] = entry
			end
		end
		if #moved == 0 then
			return
		end
		for i = #moved, 1, -1 do
			tinsert(section.extra, 1, moved[i])
		end
		section.basic = kept
	end

	function sectionsOf(schema, all, headControls)
		all = all or ui.API.GetUIState("showAll") == true
		local sections = {}
		local section = { basic = {}, extra = {} }
		local function close()
			if section.hidden then
				return
			end
			if not all then
				limitBasic(section)
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
		local function openSmallExtras()
			local total = 0
			for _, item in ipairs(sections) do
				total = total + countControls(item.basic)
			end
			for _, item in ipairs(sections) do
				local header = item.header
				if
					item.extraCount > 0
					and item.extraCount <= SHOWN_EXTRA
					and countControls(item.basic) + item.extraCount <= MAX_BASIC
					and total + item.extraCount <= VIEW_BUDGET - (headControls or 0)
					and not (header and header.extraLabel)
				then
					for _, entry in ipairs(item.extra) do
						item.basic[#item.basic + 1] = entry
					end
					total = total + item.extraCount
					item.extra, item.extraCount = {}, 0
				end
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
				local secondary = entry.advanced or entry.basic == nil and SECONDARY_TYPES[entry.type]
				local list = (section.advanced or (secondary and not all)) and section.extra or section.basic
				list[#list + 1] = entry
			end
		end
		close()
		if not all then
			openSmallExtras()
		end
		return sections
	end
end

local function expandedStore()
	return ui.API.UIStore("expandedSettings")
end

local function firstPath(section)
	for _, list in ipairs({ section.basic, section.extra }) do
		for _, entry in ipairs(list) do
			if type(entry.path) == "string" then
				return entry.path
			end
		end
	end
end

local function sectionKey(page, section, index)
	local path = firstPath(section)
	local key = page.key .. ":" .. (path or index)
	local header = section.header
	local textKey = header and page.key .. ":" .. header.header
	local store = expandedStore()
	if textKey and textKey ~= key and store[textKey] ~= nil then
		if store[key] == nil then
			store[key] = store[textKey]
		end
		store[textKey] = nil
	end
	return key
end

local function isExpanded(section)
	local stored = expandedStore()[section.key]
	if stored == nil then
		return section.modified or false
	end
	return stored
end

local function fitElementFrame(view)
	local height = -ELEMENT.TOP
		+ SCROLL.LEFT
		+ (P.elementFrame.sectionOffset or 0)
		+ view.content:GetHeight()
		+ SCROLL.BOTTOM
		+ ELEMENT.BOTTOM
	P.elementFrame:SetHeight(max(ELEMENT.MIN_HEIGHT, min(ELEMENT.MAX_HEIGHT, height)))
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
	local expanded = not isExpanded(section)
	local store = expandedStore()
	if expanded == (section.modified or false) then
		store[section.key] = nil
	else
		store[section.key] = expanded
	end
	PlaySound(expanded and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
	layoutPage(page)
	local scroll = page.scroll or P.frame.scroll
	scroll:UpdateScrollChildRect()
	if page.element and P.elementFrame.view == page then
		fitElementFrame(page)
	end
end

local function createExpander(parent, page, section)
	local button = CreateFrame("Button", nil, parent)
	button.section = section
	button:SetHeight(ROW_HEIGHT)
	button:SetPoint("LEFT")
	button:SetPoint("RIGHT")

	button:SetHighlightTexture(createHighlight(button, 0.35))

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
		toggleSection(page, button.section)
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
		local shown = changedCount > 0 and not isExpanded(button.section)
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
		local expanded = isExpanded(button.section)
		local header = button.section.header
		ui.SetGlyph(glyph, expanded and "chevron-down" or "chevron-right")
		if header and header.extraLabel then
			label:SetText(expanded and header.lessLabel or header.extraLabel:format(button.section.extraCount))
		else
			label:SetText(expanded and L["Fewer settings"] or L["More settings (%d)"]:format(button.section.extraCount))
		end
		place()
	end
	button.UpdateChanges = function(items)
		local count = 0
		for _, item in ipairs(items) do
			if item.section == button.section and item.extra and item.row.modified then
				count = count + 1
			end
		end
		changedCount = count
		place()
	end
	return button
end

local measureHost

-- Text measured under a hidden parent ignores the UI scale, so rows are built on a visible, transparent host
local function moveToMeasureHost(content)
	local parent = content:GetParent()
	if not measureHost then
		measureHost = CreateFrame("Frame", nil, UIParent)
		measureHost:SetSize(1, 1)
		measureHost:SetPoint("TOPLEFT")
		measureHost:SetAlpha(0)
	end
	measureHost:SetScale(parent:GetEffectiveScale() / UIParent:GetEffectiveScale())
	content:SetParent(measureHost)
	content:Show()
	return parent
end

local function buildPage(page)
	local content = page.container
	if not content then
		content = CreateFrame("Frame", nil, page.parent or page.scroll or P.frame.scroll)
		content:SetWidth(page.width or CONTENT_WIDTH)
		page.container = content
	end
	local parent = moveToMeasureHost(content)
	page.content = content
	page.rows = {}
	page.items = {}

	local cache = page.rowCache
	if not cache then
		cache = setmetatable({}, { __mode = "k" })
		page.rowCache = cache
	end
	for _, row in pairs(cache) do
		row:Hide()
	end
	local used = {}
	local searching = page == searchPage

	local function keyOf(entry)
		if searching and entry.header then
			return "header:" .. entry.header .. ":" .. tostring(entry.glyph)
		elseif searching and entry.build and type(entry.key) == "string" then
			return "fallback:" .. entry.key
		end
		return entry
	end

	local function reuse(key, make)
		local row = cache[key]
		if row and not used[row] then
			used[row] = true
			return row
		end
		row = make()
		used[row] = true
		if not cache[key] then
			cache[key] = row
		end
		return row
	end

	local function add(row, section, extra, header)
		page.items[#page.items + 1] = { row = row, section = section, extra = extra, header = header }
		if row.Refresh then
			tinsert(page.rows, row)
		end
	end

	local function addEntries(section, entries, extra)
		for _, entry in ipairs(entries) do
			add(
				reuse(keyOf(entry), function()
					return creators[entry.type or "description"](content, entry)
				end),
				section,
				extra
			)
		end
	end

	local headControls = 0
	if page.tab and page.owner then
		for _, entry in ipairs(page.owner.schema or {}) do
			if not entry.header and not entry.hidden and not entry.description then
				headControls = headControls + 1
			end
		end
	end
	for index, section in
		ipairs(sectionsOf(expandSchema(page), page == searchPage or page.element ~= nil, headControls))
	do
		local header = section.header
		section.key = sectionKey(page, section, index)
		if header then
			add(
				reuse(keyOf(header), function()
					return creators.header(content, header)
				end),
				section,
				false,
				true
			)
		end
		addEntries(section, section.basic, false)
		if section.extraCount > 0 then
			section.modified = false
			for _, entry in ipairs(section.extra) do
				if changes.IsModified(entry) then
					section.modified = true
					break
				end
			end
			local expander = reuse(section.key, function()
				return createExpander(content, page, section)
			end)
			expander.section = section
			add(expander, section, false)
			addEntries(section, section.extra, true)
		end
	end
	layoutPage(page)
	content:Hide()
	content:SetParent(parent)
	page.builtScale = parent:GetEffectiveScale()
end

local function rebuildPage(page)
	local scroll = page.scroll or P.frame.scroll
	local offset = scroll:GetVerticalScroll()
	page.content:Hide()
	buildPage(page)
	showContent(page, scroll, offset)
end

local function refreshView(page)
	if not page or not page.rows then
		return
	end
	local scaled = abs(page.content:GetParent():GetEffectiveScale() - page.builtScale) > 0.001
	if scaled or page.signature and page.signature() ~= page.lastSignature then
		rebuildPage(page)
	end
	P.refreshing = true
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
	P.refreshing = false
end

local function refreshPage(page)
	if page and page.tabs then
		refreshView(page.head)
		if page.activeTab then
			refreshView(page.activeTab.view)
		end
		return
	end
	refreshView(page)
end

P.buildPage = buildPage
P.fitElementFrame = fitElementFrame
P.refreshPage = refreshPage
P.showContent = showContent
