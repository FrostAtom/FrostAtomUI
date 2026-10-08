local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local max = math.max
local min = math.min
local floor = math.floor

local P = ns.private
local CONTENT_TOP = P.CONTENT_TOP
local CONTENT_WIDTH = P.CONTENT_WIDTH
local EDGE = P.EDGE
local ELEMENT = P.ELEMENT
local FOOTER_BUTTON_WIDTH = P.FOOTER_BUTTON_WIDTH
local FOOTER_TOP = P.FOOTER_TOP
local FRAME_NAME = P.FRAME_NAME
local GLYPH_GAP = P.GLYPH_GAP
local GLYPH_SIZE = P.GLYPH_SIZE
local HEIGHT = P.HEIGHT
local PANEL_RIGHT = P.PANEL_RIGHT
local PANEL_TOP = P.PANEL_TOP
local PANEL_X = P.PANEL_X
local SCROLL = P.SCROLL
local TITLE_GLYPH_SIZE = P.TITLE_GLYPH_SIZE
local WIDTH = P.WIDTH
local buildPage = P.buildPage
local changes = P.changes
local confirmDefaults = P.confirmDefaults
local createButton = P.createButton
local createCategoryList = P.createCategoryList
local createCopyButton = P.createCopyButton
local createGlyph = P.createGlyph
local createNavButton = P.createNavButton
local createSearchBox = P.createSearchBox
local createWindow = P.createWindow
local elementFor = P.elementFor
local fitElementFrame = P.fitElementFrame
local font = P.font
local history = P.history
local initSeen = P.initSeen
local pageByKey = P.pageByKey
local pages = P.pages
local refreshPage = P.refreshPage
local reload = P.reload
local runSearch = P.runSearch
local selectPage = P.selectPage
local selectTab = P.selectTab
local showContent = P.showContent
local showTooltip = P.showTooltip
local addTooltipLine = P.addTooltipLine

local LEGEND = {
	{ L["Blue dot: you changed it"], { r = 0.35, g = 0.75, b = 1 } },
	{ L["Grey dot: set by a play style, a layout or your previous version"], { r = 0.55, g = 0.55, b = 0.55 } },
	{ L["Arrow on the right: return the value"], HIGHLIGHT_FONT_COLOR },
	{ L["Orange arrows: takes effect after a UI reload"], P.RELOAD_COLOR },
	{ L["NEW: added in this version"], GREEN_FONT_COLOR },
}
local tabByKey = P.tabByKey

local function createPanelScroll(parent, name)
	local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", SCROLL.LEFT, SCROLL.TOP)
	scroll:SetPoint("BOTTOMRIGHT", SCROLL.RIGHT, SCROLL.BOTTOM)
	scroll.scrollBarHideable = true
	scroll:SetScript("OnSizeChanged", function(self)
		self:UpdateScrollChildRect()
		ScrollFrame_OnScrollRangeChanged(self)
	end)
	return scroll
end

local SCALE_MIN, SCALE_MAX = 0.6, 1.4
local GRIP_SIZE = 16
local GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

local function topLeft(frame)
	return frame:GetLeft(), frame:GetTop()
end

local function placeAt(frame, left, top)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function savePlacement()
	local left, top = topLeft(P.frame)
	if left then
		ui.API.SetUIState("windowPoint", { floor(left + 0.5), floor(top + 0.5) })
	end
	local scale = P.frame:GetScale()
	ui.API.SetUIState("windowScale", scale ~= 1 and scale or nil)
end

local function restorePlacement()
	local scale = tonumber(ui.API.GetUIState("windowScale"))
	P.frame:SetScale(scale and max(SCALE_MIN, min(SCALE_MAX, scale)) or 1)
	local point = ui.API.GetUIState("windowPoint")
	if type(point) == "table" and tonumber(point[1]) and tonumber(point[2]) then
		placeAt(P.frame, point[1], point[2])
	else
		P.frame:ClearAllPoints()
		P.frame:SetPoint("CENTER")
	end
end

local function resetScale()
	local left, top = topLeft(P.frame)
	local scale = P.frame:GetScale()
	P.frame:SetScale(1)
	if left then
		placeAt(P.frame, left * scale, top * scale)
	end
	savePlacement()
end

local function onGripUpdate(grip)
	local frame = P.frame
	local x = GetCursorPosition() / UIParent:GetEffectiveScale()
	local drag = grip.drag
	local width = drag.width + x - drag.x
	local scale = max(SCALE_MIN, min(SCALE_MAX, drag.scale * width / drag.width))
	frame:SetScale(scale)
	placeAt(frame, drag.left * drag.scale / scale, drag.top * drag.scale / scale)
end

local function createScaleGrip()
	local grip = CreateFrame("Button", nil, P.frame)
	grip:SetSize(GRIP_SIZE, GRIP_SIZE)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(P.frame:GetFrameLevel() + 10)
	grip:SetNormalTexture(GRIP_TEXTURE .. "Up")
	grip:SetPushedTexture(GRIP_TEXTURE .. "Down")
	grip:SetHighlightTexture(GRIP_TEXTURE .. "Highlight")
	grip:RegisterForClicks("RightButtonUp")
	grip:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		local left, top = topLeft(P.frame)
		local scale = P.frame:GetScale()
		self.drag = {
			x = GetCursorPosition() / UIParent:GetEffectiveScale(),
			width = P.frame:GetWidth() * scale,
			scale = scale,
			left = left,
			top = top,
		}
		self:SetScript("OnUpdate", onGripUpdate)
	end)
	grip:SetScript("OnMouseUp", function(self)
		if self.drag then
			self.drag = nil
			self:SetScript("OnUpdate", nil)
			savePlacement()
			refreshPage(P.currentPage)
		end
	end)
	grip:SetScript("OnClick", function()
		resetScale()
		refreshPage(P.currentPage)
	end)
	grip:SetScript("OnEnter", function(self)
		showTooltip(self, L["Window scale"], L["Drag to scale the settings window, right-click to return 100%."])
	end)
	grip:SetScript("OnLeave", GameTooltip_Hide)
end

local function createFrame()
	initSeen()
	reload.Pending()

	P.frame = createWindow(FRAME_NAME, {
		width = WIDTH,
		height = HEIGHT,
		title = "FrostAtom UI",
		header = true,
	})
	P.frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePlacement()
	end)
	restorePlacement()
	createScaleGrip()
	P.frame:SetScript("OnShow", function()
		PlaySound("igMainMenuOption")
		ui.Undo.SetKeysOwner(P.frame, true)
		P.bindSearchKey(true)
		if P.currentPage and P.currentPage.onShow then
			P.currentPage.onShow()
		end
		refreshPage(P.currentPage)
		changes.UpdateNav()
		history.Update()
		reload.Update()
	end)
	P.frame:SetScript("OnHide", function()
		PlaySound("gsTitleOptionExit")
		ui.Undo.SetKeysOwner(P.frame, false)
		P.bindSearchKey(false)
		reload.OnClose()
		if P.currentPage and P.currentPage.onHide then
			P.currentPage.onHide()
		end
	end)

	createCategoryList()

	local panel = ui.CreateInset(P.frame, "panel")
	panel:SetPoint("TOPLEFT", PANEL_X, PANEL_TOP)
	panel:SetPoint("BOTTOMRIGHT", PANEL_RIGHT, FOOTER_TOP)

	local title = panel:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(font("GameFontNormalLarge"))
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetJustifyH("LEFT")
	P.frame.pageTitle = title

	local pageDesc = panel:CreateFontString(nil, "ARTWORK")
	pageDesc:SetFontObject(font("GameFontHighlightSmall"))
	pageDesc:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	pageDesc:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 12, 1)
	pageDesc:SetJustifyH("LEFT")
	pageDesc:SetHeight(12)
	P.frame.pageDesc = pageDesc

	local pageGlyph = createGlyph(panel, "gear", TITLE_GLYPH_SIZE, NORMAL_FONT_COLOR)
	pageGlyph:SetPoint("CENTER", title, "LEFT", -GLYPH_GAP - (TITLE_GLYPH_SIZE + 4) / 2, 0)
	pageGlyph:Hide()
	P.frame.pageGlyph = pageGlyph
	P.frame.panel = panel

	createCopyButton(panel)

	local defaults = createButton(P.frame, L["Reset..."], FOOTER_BUTTON_WIDTH, true, nil, "rotate-left")
	defaults:SetPoint("BOTTOMLEFT", EDGE, EDGE)
	defaults:SetScript("OnClick", confirmDefaults)
	defaults:HookScript("OnEnter", function(self)
		if self:IsEnabled() ~= 1 then
			showTooltip(self, L["Reset..."], L["There is nothing to reset on this page."])
		end
	end)
	defaults:HookScript("OnLeave", GameTooltip_Hide)
	P.frame.resetButton = defaults

	local unlock = createButton(P.frame, L["Unlock frames"], 120, nil, nil, "up-down-left-right")
	unlock:SetPoint("LEFT", defaults, "RIGHT", 4, 0)
	unlock:SetScript("OnClick", function()
		ui.Movers.Unlock()
		if ui.Movers.IsUnlocked() then
			P.frame:Hide()
		end
	end)

	local undo = createButton(P.frame, L["Undo"], FOOTER_BUTTON_WIDTH, true, nil, "arrow-rotate-left")
	undo:SetPoint("LEFT", unlock, "RIGHT", 4, 0)
	undo:SetScript("OnClick", function()
		ui.Undo.Undo()
	end)
	undo:HookScript("OnEnter", history.ShowTooltip)
	undo:HookScript("OnLeave", GameTooltip_Hide)
	P.frame.undoButton = undo
	history.Update()

	local help = ui.CreateGlyphButton(P.frame, "circle-question", 16, L["Help"])
	help:SetPoint("LEFT", undo, "RIGHT", 8, 0)
	help:SetScript("OnClick", function()
		ns.Toggle("help")
	end)
	help:HookScript("OnEnter", function(self)
		showTooltip(self, L["Help"], L["Click to open the help. Marks next to settings:"])
		for _, line in ipairs(LEGEND) do
			addTooltipLine(line[1], line[2])
		end
		GameTooltip:Show()
	end)
	help:HookScript("OnLeave", GameTooltip_Hide)

	local showAll = ui.CreateCheckButton(P.frame, L["Show all settings"], nil, true)
	showAll:SetPoint("LEFT", help, "RIGHT", 10, 0)
	showAll:SetChecked(ui.API.GetUIState("showAll") == true)
	showAll:SetScript("OnClick", function(self)
		ui.API.SetUIState("showAll", self:GetChecked() and true or nil)
		P.rebuildPages()
	end)
	showAll:HookScript("OnEnter", function(self)
		showTooltip(self, L["Show all settings"], L['Open every "More settings" block on every page.'])
	end)
	showAll:HookScript("OnLeave", GameTooltip_Hide)

	local okay = createButton(P.frame, L["Close"], FOOTER_BUTTON_WIDTH)
	okay:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	okay:SetScript("OnClick", function()
		P.frame:Hide()
	end)

	local reloadButton = createButton(P.frame, L["Reload UI"], FOOTER_BUTTON_WIDTH, nil, nil, "rotate")
	reloadButton:SetPoint("RIGHT", okay, "LEFT", -4, 0)
	reloadButton:SetScript("OnClick", ReloadUI)
	reloadButton:Hide()
	P.frame.reloadButton = reloadButton

	P.frame.scroll = createPanelScroll(panel, FRAME_NAME .. "Scroll")

	createSearchBox()
	for i, page in ipairs(pages) do
		createNavButton(page, i)
	end
	P.layoutNav()

	local last = ui.API.GetUIState("lastPage")
	last = last and (ns.PAGE_ALIASES[last] or { last })[1]
	selectPage(last and pageByKey(last) or pages[1])
end

local function placeElementFrame(anchor)
	P.elementFrame:ClearAllPoints()
	local left, right = anchor and anchor:GetLeft(), anchor and anchor:GetRight()
	if not left then
		P.elementFrame:SetPoint("CENTER")
		return
	end
	local scale = anchor:GetEffectiveScale() / P.elementFrame:GetEffectiveScale()
	local top = anchor:GetTop() * scale
	local screenWidth = UIParent:GetWidth() * UIParent:GetEffectiveScale() / P.elementFrame:GetEffectiveScale()
	local width = P.elementFrame:GetWidth()
	local x
	if right * scale + ELEMENT.GAP + width <= screenWidth then
		x = right * scale + ELEMENT.GAP
	elseif left * scale - ELEMENT.GAP - width >= 0 then
		x = left * scale - ELEMENT.GAP - width
	else
		x = (screenWidth - width) / 2
	end
	P.elementFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
end

local SECTION_MENU_WIDTH = 220
local SECTION_MENU_HEIGHT = 30
local POSITION_SECTION = "position"
local chosenSections = {}
local sectionValues, selectSection

local function createElementFrame()
	initSeen()
	reload.Pending()
	P.elementFrame = createWindow(FRAME_NAME .. "Element", {
		width = ELEMENT.WIDTH,
		height = 200,
		header = true,
		strata = ELEMENT.STRATA,
	})
	P.elementFrame:SetScript("OnDragStart", function(self)
		self.userPlaced = true
		self:StartMoving()
	end)
	P.elementFrame:SetScript("OnHide", function(self)
		self.userPlaced = nil
		ui.Movers.ClearSelection()
	end)

	local titleGlyph = createGlyph(P.elementFrame.header, "gear", GLYPH_SIZE, NORMAL_FONT_COLOR)
	titleGlyph:SetPoint("RIGHT", P.elementFrame.title, "LEFT", -GLYPH_GAP, 0)
	titleGlyph:Hide()
	P.elementFrame.titleGlyph = titleGlyph

	local panel = ui.CreateInset(P.elementFrame, "panel")
	panel:SetPoint("TOPLEFT", EDGE, ELEMENT.TOP)
	panel:SetPoint("BOTTOMRIGHT", -EDGE, ELEMENT.BOTTOM)

	local resetPosition = createButton(P.elementFrame, L["Move back"], 120, true, nil, "location-crosshairs")
	resetPosition:SetPoint("BOTTOMLEFT", EDGE, EDGE)
	resetPosition:SetScript("OnClick", function()
		ui.Movers.ResetPosition(P.elementFrame.view.element.path)
	end)
	resetPosition:HookScript("OnEnter", function(self)
		local text = L['Back to its place in the "%s" layout.']
		showTooltip(self, L["Move back"], text:format(ui.Movers.GetBaseLayoutName()))
	end)
	resetPosition:HookScript("OnLeave", GameTooltip_Hide)
	P.elementFrame.resetPosition = resetPosition

	local function restoreSchema(schema)
		for _, entry in ipairs(schema) do
			if entry.path and not entry.noReset then
				ui.Movers.RestoreValue(entry.path)
				if entry.pathY then
					ui.Movers.RestoreValue(entry.pathY)
				end
			end
		end
	end

	local resetAll = createButton(P.elementFrame, L["Reset size and position"], 100, true, nil, "rotate-left")
	resetAll:SetPoint("LEFT", resetPosition, "RIGHT", 4, 0)
	resetAll:SetScript("OnClick", function()
		local view = P.elementFrame.view
		local text = L['Restore the size and position of "%s" from the "%s" layout?']
		ns.Confirm(text:format(view.element.name, ui.Movers.GetBaseLayoutName()), function()
			ui.Undo.Run(L['Reset "%s"']:format(view.element.name), restoreSchema, view.schema)
		end)
	end)
	P.elementFrame.resetAll = resetAll

	local more = createButton(P.elementFrame, L["All settings"], 120, nil, nil, "sliders")
	more:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	more:SetScript("OnClick", function()
		local element = P.elementFrame.view.element
		ui.Movers.Lock()
		ns.Toggle(element.page, element.tab, element)
	end)
	P.elementFrame.more = more

	local scroll = createPanelScroll(panel, FRAME_NAME .. "ElementScroll")
	scroll:SetPoint("TOPLEFT", SCROLL.LEFT, -SCROLL.LEFT)
	P.elementFrame.scroll = scroll

	local sectionMenu =
		ui.CreateDropdown(panel, SECTION_MENU_WIDTH, sectionValues, selectSection, FRAME_NAME .. "ElementSection")
	sectionMenu:SetPoint("TOPLEFT", -6, -4)
	sectionMenu:Hide()
	P.elementFrame.sectionMenu = sectionMenu
end

local function showElementTitle(element)
	local glyph = element.glyph
	local titleGlyph = P.elementFrame.titleGlyph
	local shift = 0
	if glyph then
		ui.SetGlyph(titleGlyph, glyph)
		shift = (titleGlyph:GetStringWidth() + GLYPH_GAP) / 2
	end
	ui.SetShown(titleGlyph, glyph)
	P.elementFrame.title:SetPoint("TOP", P.elementFrame.header.middle, "TOP", shift, -14)
	P.elementFrame.title:SetText(element.name)
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
		scroll = P.elementFrame.scroll,
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

local function elementSections(element)
	if element.sections ~= nil then
		return element.sections or nil
	end
	local page = element.page and pageByKey(element.page)
	local tab = page and element.tab and page.tabs and tabByKey(page, element.tab)
	local sections, current = {}, nil
	for _, entry in ipairs(tab and not tab.buildSchema and tab.schema or {}) do
		if entry.header then
			current = { header = entry, entries = { entry } }
			sections[#sections + 1] = current
		elseif current and entry.type ~= "elements" and not entry.element and not entry.alias then
			current.entries[#current.entries + 1] = entry
			current.useful = current.useful or entry.path ~= nil and not entry.hidden
		end
	end
	local useful = {}
	for _, section in ipairs(sections) do
		if section.useful then
			useful[#useful + 1] = section
		end
	end
	element.sections = #useful > 0 and useful or false
	return element.sections or nil
end

local function sectionView(element, index)
	element.sectionViews = element.sectionViews or {}
	local view = element.sectionViews[index]
	if not view then
		view = {
			key = element.key .. ":section" .. index,
			element = element,
			scroll = P.elementFrame.scroll,
			width = CONTENT_WIDTH,
			schema = elementSections(element)[index].entries,
		}
		element.sectionViews[index] = view
	end
	return view
end

local function chosenView(element)
	local sections = elementSections(element)
	local index = chosenSections[element.path]
	if sections and type(index) == "number" and sections[index] then
		return sectionView(element, index)
	end
	return elementView(element)
end

function sectionValues()
	local view = P.elementFrame and P.elementFrame.view
	local sections = view and elementSections(view.element)
	local values = { { POSITION_SECTION, L["Size and position"] } }
	for index, section in ipairs(sections or {}) do
		values[#values + 1] = { index, section.header.header }
	end
	return values
end

local showElementView

function selectSection(value)
	local element = P.elementFrame.view.element
	chosenSections[element.path] = value
	showElementView(element, chosenView(element))
end

function ns.OpenElement(path, anchor)
	if not P.elementFrame then
		createElementFrame()
	end
	local element = elementFor(path)
	showElementView(element, chosenView(element), anchor)
end

function showElementView(element, view, anchor)
	if P.elementFrame:IsShown() and P.elementFrame.view == view then
		refreshPage(view)
		return
	end
	if P.elementFrame.view and P.elementFrame.view.content then
		P.elementFrame.view.content:Hide()
	end
	P.elementFrame.view = view
	showElementTitle(element)
	local menu = P.elementFrame.sectionMenu
	local sections = elementSections(element)
	P.elementFrame.sectionOffset = sections and SECTION_MENU_HEIGHT or 0
	P.elementFrame.scroll:SetPoint("TOPLEFT", SCROLL.LEFT, -SCROLL.LEFT - P.elementFrame.sectionOffset)
	if sections then
		menu:Select(chosenSections[element.path] or POSITION_SECTION)
		menu:Show()
	else
		menu:Hide()
	end
	if not view.content then
		buildPage(view)
	end
	showContent(view, P.elementFrame.scroll, 0)
	ui.SetShown(P.elementFrame.more, element.page ~= nil)
	ui.SetShown(P.elementFrame.resetPosition, not element.noReset)
	ui.SetShown(P.elementFrame.resetAll, not element.noReset and view == element.view)

	fitElementFrame(view)
	if not P.elementFrame.userPlaced or not P.elementFrame:IsShown() then
		placeElementFrame(anchor)
	end
	P.elementFrame:Show()
	refreshPage(view)
end

function ns.CloseElement()
	if P.elementFrame and P.elementFrame:IsShown() then
		P.elementFrame:Hide()
	end
end

function ns.GetOpenElement()
	local view = P.elementFrame and P.elementFrame:IsShown() and P.elementFrame.view
	return view and view.element.path or nil
end

function ns.EditElement(path)
	if InCombatLockdown() then
		ui.Print(L["cannot move frames in combat, try again after it ends"])
		return
	end
	P.frame:Hide()
	ui.Movers.Unlock(path)
	if not ui.Movers.IsUnlocked() then
		return
	end
	if not ui.Movers.Select(path) then
		ns.OpenElement(path)
	end
end
P.EditElement = ns.EditElement

local function refreshShown()
	if P.frame and P.frame:IsShown() then
		refreshPage(P.currentPage)
		changes.ScheduleNav()
		reload.Update()
	end
	if P.elementFrame and P.elementFrame:IsShown() then
		refreshPage(P.elementFrame.view)
	end
end

local function queueRefresh()
	ui.Defer(refreshShown, refreshShown)
end

local watcher = ui.Mixin({}, ui.EventMixin)
watcher:RegisterEvent(ui.E.CONFIG_CHANGED, queueRefresh)
watcher:RegisterEvent(ui.E.PROFILES_CHANGED, queueRefresh)
watcher:RegisterEvent(ui.E.HISTORY_CHANGED, function()
	history.Update()
	if P.frame and P.frame:IsShown() and P.currentPage and P.currentPage.history then
		refreshPage(P.currentPage)
	end
end)
watcher:RegisterEvent("UPDATE_BINDINGS", refreshShown)
watcher:RegisterEvent(ui.E.RELOAD_REQUIRED, function()
	reload.Update()
end)

local function scrollToElement(page, element)
	local view = page.tabs and page.activeTab and page.activeTab.view or page
	for _, item in ipairs(view.items or {}) do
		local entry = item.header and item.section.header or item.row.entry
		if entry and entry.element == element then
			local _, _, _, _, y = item.row:GetPoint(1)
			local scroll = P.frame.scroll
			scroll:UpdateScrollChildRect()
			scroll:SetVerticalScroll(max(0, min(-y - CONTENT_TOP, scroll:GetVerticalScrollRange())))
			return
		end
	end
end

function ns.Toggle(pageKey, tabKey, element)
	if not P.frame then
		createFrame()
	end
	if not pageKey then
		if P.frame:IsShown() then
			P.frame:Hide()
		else
			P.frame:Show()
		end
		return
	end
	local alias = ns.PAGE_ALIASES[pageKey]
	if alias then
		pageKey, tabKey = alias[1], tabKey or alias[2]
	end
	local page = pageByKey(pageKey)
	if page then
		P.frame.searchBox:SetText("")
		selectPage(page)
		local tab = tabKey and page.tabs and tabByKey(page, tabKey)
		if tab and tab ~= page.activeTab then
			selectTab(page, tab)
		end
	else
		P.frame.searchBox:SetText(pageKey)
		runSearch()
	end
	P.frame:Show()
	if page and element then
		ui.After(0.05, function()
			scrollToElement(page, element)
		end)
	end
end

function ns.HideWindow()
	if P.frame and P.frame:IsShown() then
		P.frame:Hide()
	end
end

function ns.IsWindowShown()
	return P.frame ~= nil and P.frame:IsShown() and true or false
end

local scaleWatcher = ui.Mixin({}, ui.EventMixin)
scaleWatcher:RegisterEvent(ui.E.PIXEL_CHANGED, function()
	ns.RefreshPage()
end)

ui.API.SetSettingsHost(ns)
