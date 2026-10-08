local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local max = math.max
local min = math.min

local P = ns.private
local CONTENT_BOTTOM = P.CONTENT_BOTTOM
local CONTENT_WIDTH = P.CONTENT_WIDTH
local FRAME_NAME = P.FRAME_NAME
local GLYPH_BOX = P.GLYPH_BOX
local GLYPH_GAP = P.GLYPH_GAP
local GLYPH_SIZE = P.GLYPH_SIZE
local SCROLL = P.SCROLL
local TITLE_GLYPH_SIZE = P.TITLE_GLYPH_SIZE
local addNewBadge = P.addNewBadge
local addTooltipLine = P.addTooltipLine
local buildPage = P.buildPage
local changes = P.changes
local createButton = P.createButton
local createGlyph = P.createGlyph
local createHighlight = P.createHighlight
local createSpacerLine = P.createSpacerLine
local elements = P.elements
local font = P.font
local isNewEntry = P.isNewEntry
local markSeen = P.markSeen
local refreshPage = P.refreshPage
local setControlEnabled = P.setControlEnabled
local showContent = P.showContent
local showTooltip = P.showTooltip
local updateNavBadge = P.updateNavBadge
local versionValue = P.versionValue

local function paintNavGlyph(button)
	local glyph = button and button.glyph
	if not glyph then
		return
	end
	local color = button.off and GRAY_FONT_COLOR or NORMAL_FONT_COLOR
	if button.hovered or (P.currentPage and P.currentPage.button == button) then
		color = HIGHLIGHT_FONT_COLOR
	end
	glyph:SetTextColor(color.r, color.g, color.b)
end

local function showPageTitle(page)
	local glyph = page.glyph
	local title = P.frame.pageTitle
	local titleX = glyph and 16 + TITLE_GLYPH_SIZE + 4 + GLYPH_GAP or 16
	title:SetPoint("TOPLEFT", titleX, -16)
	title:SetText(page.name)
	if glyph then
		ui.SetGlyph(P.frame.pageGlyph, glyph)
	end
	ui.SetShown(P.frame.pageGlyph, glyph)
	local desc = P.frame.pageDesc
	desc:SetText(page.desc or "")
	desc:SetWidth(max(1, P.frame.panel:GetWidth() - titleX - title:GetStringWidth() - 170))
end

local tabByKey, placeScroll, updateCopyButton, selectTab, showTabbedPage, hidePageContent, createCopyButton

do
	local TAB_HEIGHT = 22
	local TAB_PADDING = 8
	local TAB_GAP = 2
	local TAB_BAR_GAP = 6

	local function tabStore()
		return ui.API.UIStore("settingsTabs")
	end

	function tabByKey(page, key)
		for _, tab in ipairs(page.tabs) do
			if tab.key == key then
				return tab
			end
		end
	end

	function placeScroll(offset)
		P.frame.scroll:SetPoint("TOPLEFT", SCROLL.LEFT, SCROLL.TOP - offset)
	end

	local function placeTabs(page)
		local head = page.head
		local height = #head.items > 0 and head.content:GetHeight() - CONTENT_BOTTOM or 0
		page.tabBar:SetPoint("TOPLEFT", P.frame.panel, "TOPLEFT", SCROLL.LEFT, SCROLL.TOP - height)
		if P.currentPage == page then
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

	local function copyGroup(key)
		if key:find("Castbar") then
			return "castbar"
		elseif key:find("Debuff") or key:find("Buff") or key:find("Aura") then
			return "auras"
		end
		return "frame"
	end
	P.copyGroup = copyGroup

	local function copyTab(page, source, target, group)
		local index = pathEntries(page)
		local clamped = {}
		ui.Undo.Begin(L['Copy from "%s"']:format(source.name))
		for key, path in pairs(target.copy) do
			local from = source.copy[key]
			if from and from ~= path and (not group or copyGroup(key) == group) then
				local value = ui:GetConfig(from)
				local info = index[path]
				if type(value) == "table" then
					value = CopyTable(value)
				elseif type(value) == "number" and info and info.min then
					local fitted = max(info.min, min(info.max, value))
					if fitted ~= value then
						clamped[#clamped + 1] = ("%s: %s → %s"):format(ns.SettingLabel(path) or path, value, fitted)
					end
					value = fitted
				end
				if type(value) == "table" or value ~= ui:GetConfig(path) then
					ui:SetConfig(path, value)
				end
			end
		end
		ui.Undo.End()
		if #clamped > 0 then
			ui.Print(L["some values did not fit the limits of this tab: %s"], table.concat(clamped, "; "))
		end
		refreshPage(page)
	end

	function updateCopyButton(page)
		local tab = page and page.tabs and page.activeTab
		ui.SetShown(P.frame.copyButton, tab and #copySources(page, tab) > 0)
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

	local function tabNewest(tab, page, group)
		local newest
		for _, entry in ipairs(tab.schema) do
			if isNewEntry(entry) and versionValue(entry.new) > versionValue(newest) then
				newest = entry.new
			end
		end
		if group then
			for _, child in ipairs(page.tabs) do
				local version = child.parent == tab.key and tabNewest(child)
				if version and versionValue(version) > versionValue(newest) then
					newest = version
				end
			end
		end
		return newest
	end

	local function showTabTooltip(button)
		if button.newBadge and button.newBadge:IsShown() then
			showTooltip(button, button.tab.name)
			addTooltipLine(L["Added in %s"]:format(button.newVersion), GREEN_FONT_COLOR)
			GameTooltip:Show()
		end
	end

	local function createTabButton(bar, page, tab, group)
		local button = CreateFrame("Button", nil, bar)
		button:SetHeight(TAB_HEIGHT)
		button.page = page
		button.tab = tab
		button.group = group

		local selected = createHighlight(button, 0.8)
		local underline = button:CreateTexture(nil, "ARTWORK")
		underline:SetTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		underline:SetHeight(2)
		underline:SetPoint("BOTTOMLEFT", 2, 0)
		underline:SetPoint("BOTTOMRIGHT", -2, 0)
		button.selected = selected
		button.underline = underline

		button:SetHighlightTexture(createHighlight(button, 0.35))

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
		local newest = tabNewest(tab, page, group)
		if newest then
			local badge = addNewBadge(button, text, text:GetStringWidth() + GLYPH_GAP)
			width = width + GLYPH_GAP + badge:GetStringWidth()
			button.newBadge = badge
			button.newVersion = newest
		end
		button:SetWidth(width)

		button:SetScript("OnEnter", function(self)
			self.hovered = true
			paintTab(self)
			showTabTooltip(self)
		end)
		button:SetScript("OnLeave", function(self)
			self.hovered = nil
			paintTab(self)
			if GameTooltip:IsOwned(self) then
				GameTooltip:Hide()
			end
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
		local bar = CreateFrame("Frame", nil, P.frame.panel)
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
		bar.line = createSpacerLine(bar)
		page.tabBar = bar
		layoutTabBar(page)
	end

	function selectTab(page, tab)
		local previous = page.activeTab
		if previous and previous.view and previous.view.content and previous.view.content:IsShown() then
			P.scrollMemory[previous.view.key] = P.frame.scroll:GetVerticalScroll()
		end
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
		showContent(view, P.frame.scroll, P.scrollMemory[view.key] or 0)
		markSeen(page, view.key)
		updateNavBadge(page)
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
				parent = P.frame.panel,
				onLayout = function()
					placeTabs(page)
				end,
			}
			buildPage(page.head)
			page.head.content:SetPoint("TOPLEFT", SCROLL.LEFT, SCROLL.TOP)
		end
		page.head.content:Show()
		page.tabBar:Show()
		placeTabs(page)
		selectTab(page, tabByKey(page, tabStore()[page.key]) or page.tabs[1])
	end

	function hidePageContent(page)
		local view = page.tabs and page.activeTab and page.activeTab.view or page
		if view.content and view.content:IsShown() and page ~= P.searchPage then
			P.scrollMemory[view.key] = P.frame.scroll:GetVerticalScroll()
		end
		if not page.tabs then
			page.content:Hide()
			return
		end
		page.head.content:Hide()
		page.tabBar:Hide()
		if view ~= page and view.content then
			view.content:Hide()
		end
	end

	function createCopyButton(panel)
		local copyMenu = CreateFrame("Frame", FRAME_NAME .. "CopyMenu", P.frame, "UIDropDownMenuTemplate")
		local COPY_GROUP_NAMES = { frame = "Size", castbar = "Castbar", auras = "Auras" }
		local COPY_GROUP_ORDER = { "frame", "castbar", "auras" }

		local function addCopyButton(text, level, func)
			local info = UIDropDownMenu_CreateInfo()
			info.text = text
			info.notCheckable = 1
			info.func = func
			UIDropDownMenu_AddButton(info, level)
		end

		local function confirmCopy(page, source, target, group)
			CloseDropDownMenus()
			local what = group and L[COPY_GROUP_NAMES[group]] or L["Everything"]
			ns.Confirm(L["Copy %s settings to %s?"]:format(source.name .. " (" .. what .. ")", target.name), function()
				copyTab(page, source, target, group)
			end)
		end

		UIDropDownMenu_Initialize(copyMenu, function(_, level)
			local page = P.currentPage
			local target = page and page.tabs and page.activeTab
			if not target then
				return
			end
			local sources = copySources(page, target)
			if level == 2 then
				local source = sources[UIDROPDOWNMENU_MENU_VALUE]
				if not source then
					return
				end
				addCopyButton(L["Everything"], level, function()
					confirmCopy(page, source, target)
				end)
				local present = {}
				for key, path in pairs(target.copy) do
					if source.copy[key] and source.copy[key] ~= path then
						present[copyGroup(key)] = true
					end
				end
				for _, group in ipairs(COPY_GROUP_ORDER) do
					if present[group] then
						addCopyButton(L[COPY_GROUP_NAMES[group]], level, function()
							confirmCopy(page, source, target, group)
						end)
					end
				end
				return
			end
			for index, source in ipairs(sources) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = source.name
				info.notCheckable = 1
				info.hasArrow = 1
				info.value = index
				info.func = function()
					confirmCopy(page, source, target)
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end, "MENU")

		local copy = createButton(panel, L["Copy from..."], 100, true, 20, "copy")
		copy:SetPoint("TOPRIGHT", -12, -12)
		copy:SetScript("OnClick", function(self)
			ToggleDropDownMenu(1, nil, copyMenu, self, 0, 0)
		end)
		copy:HookScript("OnEnter", function(self)
			showTooltip(
				self,
				L["Copy from..."],
				L["Copy the settings this tab shares with another tab, such as sizes and castbar."]
			)
		end)
		copy:HookScript("OnLeave", GameTooltip_Hide)
		copy:Hide()
		P.frame.copyButton = copy
	end
end

function P.rebuildPages()
	for _, page in ipairs(P.pages) do
		if not page.tabs and page.content then
			page.content:Hide()
			page.content = nil
		end
		for _, tab in ipairs(page.tabs or {}) do
			if tab.view and tab.view.content then
				tab.view.content:Hide()
				tab.view.content = nil
			end
		end
	end
	local current = P.currentPage
	if not current or current == P.searchPage then
		return
	end
	if current.tabs then
		selectTab(current, current.activeTab or current.tabs[1])
	else
		buildPage(current)
		showContent(current, P.frame.scroll, 0)
		refreshPage(current)
	end
end

local function showPage(page)
	if P.currentPage then
		if P.currentPage.onHide then
			P.currentPage.onHide()
		end
		hidePageContent(P.currentPage)
		if P.currentPage.button then
			P.currentPage.button:UnlockHighlight()
		end
	end
	local previous = P.currentPage
	P.currentPage = page
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
		showContent(page, P.frame.scroll, page == P.searchPage and 0 or P.scrollMemory[page.key] or 0)
	end
	if page.button then
		page.button:LockHighlight()
		paintNavGlyph(page.button)
		P.lastNavPage = page
		ui.API.SetUIState("lastPage", page.key)
		if not page.button:IsShown() then
			P.layoutNav()
		end
		markSeen(page, page.key)
		updateNavBadge(page)
		changes.PlaceNav(page.button)
	end
	setControlEnabled(P.frame.resetButton, not page.noReset)
	showPageTitle(page)
	if page.onShow then
		page.onShow()
	end
	refreshPage(page)
end

local function selectPage(page)
	if P.currentPage ~= page then
		showPage(page)
	end
end

P.createCopyButton = createCopyButton
P.paintNavGlyph = paintNavGlyph
P.selectPage = selectPage
P.selectTab = selectTab
P.showPage = showPage
P.tabByKey = tabByKey
