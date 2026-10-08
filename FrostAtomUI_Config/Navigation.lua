local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local P = ns.private
local FOOTER_TOP = P.FOOTER_TOP
local FRAME_NAME = P.FRAME_NAME
local GLYPH_BOX = P.GLYPH_BOX
local GLYPH_GAP = P.GLYPH_GAP
local GLYPH_SIZE = P.GLYPH_SIZE
local LIST_TOP = P.LIST_TOP
local LIST_WIDTH = P.LIST_WIDTH
local LIST_X = P.LIST_X
local NAV_GLYPH_X = P.NAV_GLYPH_X
local TEXTURE = P.TEXTURE
local addTooltipLine = P.addTooltipLine
local changes = P.changes
local createGlyph = P.createGlyph
local font = P.font
local newestUnseen = P.newestUnseen
local pages = P.pages
local paintNavGlyph = P.paintNavGlyph
local seenAtOpen = P.seenAtOpen
local seenStore = P.seenStore
local selectPage = P.selectPage
local setButtonFonts = P.setButtonFonts
local showTooltip = P.showTooltip

local NAV_LABEL_HEIGHT = 18
local NAV_SCROLL_STEP = 36
local NAV_BUTTON_HEIGHT = P.NAV_BUTTON_HEIGHT
local max, min = math.max, math.min

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
	local edge = listTexture(list, TEXTURE.LIST_BORDER, left)
	edge:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
	edge:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
end

local function listSpacer(list, point, from, fromPoint, y, to, toPoint)
	local spacer = listTexture(list, TEXTURE.SPACER)
	spacer:SetHeight(16)
	spacer:SetPoint(point .. "LEFT", from, fromPoint, 0, y)
	spacer:SetPoint(point .. "RIGHT", to, toPoint)
end

local function createCategoryList()
	local list = CreateFrame("Frame", FRAME_NAME .. "CategoryList", P.frame)
	list:SetWidth(LIST_WIDTH)
	list:SetPoint("TOPLEFT", LIST_X, LIST_TOP)
	list:SetPoint("BOTTOMLEFT", LIST_X, FOOTER_TOP)

	local corners = {}
	for point, left in pairs(LIST_CORNERS) do
		local corner = listTexture(list, TEXTURE.LIST_BORDER, left)
		corner:SetSize(16, 16)
		corner:SetPoint(point)
		corners[point] = corner
	end
	listEdge(list, 0, corners.TOPLEFT, corners.BOTTOMLEFT)
	listEdge(list, 0.125, corners.TOPRIGHT, corners.BOTTOMRIGHT)
	listSpacer(list, "TOP", corners.TOPLEFT, "TOPRIGHT", 7, corners.TOPRIGHT, "TOPLEFT")
	listSpacer(list, "BOTTOM", corners.BOTTOMLEFT, "BOTTOMRIGHT", -2, corners.BOTTOMRIGHT, "BOTTOMLEFT")

	local scroll = CreateFrame("ScrollFrame", nil, list)
	scroll:SetPoint("TOPLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", 0, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(LIST_WIDTH, 1)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local limit = max(0, content:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(min(limit, max(0, self:GetVerticalScroll() - delta * NAV_SCROLL_STEP)))
	end)
	list.scroll = scroll
	list.content = content
	P.frame.list = list
end

local function createNavButton(page, index)
	local name = FRAME_NAME .. "Category" .. index
	local button = CreateFrame("Button", name, P.frame.list.content, "OptionsListButtonTemplate")
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
	button:HookScript("OnEnter", function(self)
		showTooltip(self, page.name, page.desc)
		local newest = badge:IsShown() and newestUnseen(page)
		if newest then
			addTooltipLine(L["Added in %s"]:format(newest), GREEN_FONT_COLOR)
		end
		if self.off then
			addTooltipLine(L["The module is off: turn it on at the top of the page."], GRAY_FONT_COLOR, true)
		end
		GameTooltip:Show()
	end)
	button:HookScript("OnLeave", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	changes.AttachNav(button)

	button:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		P.frame.searchBox:SetText("")
		selectPage(page)
	end)
	page.button = button
end

local GROUP_TITLES = {
	start = "START",
	frames = "FRAMES",
	pvp = "PVP & COMBAT",
	interface = "INTERFACE",
	system = "SYSTEM",
}

local function collapsedGroups()
	return ui.API.UIStore("navCollapsed")
end

local labels = {}

local function groupLabel(group)
	local label = labels[group]
	if label then
		return label
	end
	label = CreateFrame("Button", nil, P.frame.list.content)
	label:SetSize(LIST_WIDTH - 8, NAV_LABEL_HEIGHT)
	local text = label:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(font("GameFontNormalSmall"))
	text:SetTextColor(0.6, 0.6, 0.6)
	text:SetPoint("BOTTOMLEFT", NAV_GLYPH_X, 3)
	text:SetText(L[GROUP_TITLES[group] or group])
	local arrow = createGlyph(label, "chevron-down", 8, { r = 0.6, g = 0.6, b = 0.6 })
	arrow:SetPoint("LEFT", text, "RIGHT", 4, 0)
	label.arrow = arrow
	label:SetScript("OnClick", function()
		local collapsed = collapsedGroups()
		collapsed[group] = not collapsed[group] or nil
		PlaySound(collapsed[group] and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
		P.layoutNav()
	end)
	labels[group] = label
	return label
end

local function layoutNav()
	local collapsed = collapsedGroups()
	local y, group = -2, nil
	for _, page in ipairs(pages) do
		local button = page.button
		if button then
			if page.group ~= group then
				group = page.group
				local label = groupLabel(group)
				label:ClearAllPoints()
				label:SetPoint("TOPLEFT", 0, y)
				ui.SetGlyph(label.arrow, collapsed[group] and "chevron-right" or "chevron-down")
				y = y - NAV_LABEL_HEIGHT
			end
			local shown = not collapsed[group] or page == P.currentPage
			ui.SetShown(button, shown)
			if shown then
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", 0, y)
				y = y - NAV_BUTTON_HEIGHT
			end
		end
	end
	local list = P.frame.list
	list.content:SetHeight(-y + 6)
	list.scroll:UpdateScrollChildRect()
	local limit = max(0, list.content:GetHeight() - list.scroll:GetHeight())
	list.scroll:SetVerticalScroll(min(limit, list.scroll:GetVerticalScroll()))
end

local SEEN_MOVES = {
	losecontrol = { "control", "control:frames" },
	pvp = {
		"control",
		"control:alert",
		"control:defensives",
		"alerts",
		"alerts:sounds",
		"alerts:queue",
		"alerts:battleground",
	},
	spellalerts = { "alerts", "alerts:voice" },
	qol = { "automation", "blizzard:windows", "blizzard:elements" },
	transfer = { "profiles:transfer" },
	backups = { "profiles:backups" },
	profiles = { "profiles:profiles" },
	blizzard = { "blizzard:hidden" },
}

local function initSeen()
	if P.seenLoaded then
		return
	end
	P.seenLoaded = true
	ui.API.SetUIState("showAdvancedSettings", nil)
	local legacy = ui.API.GetUIState("seenNew")
	if legacy then
		local store = seenStore()
		for _, page in ipairs(pages) do
			local version = legacy[page.key]
			if version then
				store[page.key] = store[page.key] or version
				for _, tab in ipairs(page.tabs or {}) do
					local key = page.key .. ":" .. tab.key
					store[key] = store[key] or version
				end
			end
		end
		ui.API.SetUIState("seenNew", nil)
	end
	local store = seenStore()
	for old, targets in pairs(SEEN_MOVES) do
		local version = store[old]
		if version then
			for _, key in ipairs(targets) do
				store[key] = store[key] or version
			end
		end
	end
	for key, version in pairs(store) do
		seenAtOpen[key] = version
	end
end

P.createCategoryList = createCategoryList
P.createNavButton = createNavButton
P.layoutNav = layoutNav
P.initSeen = initSeen
