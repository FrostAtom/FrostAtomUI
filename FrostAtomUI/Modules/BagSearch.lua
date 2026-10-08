local _, ns = ...

local L = ns.L

local GameTooltip = GameTooltip

local Bags = ns:GetModule("Bags")
local P = Bags.shared

local HEADER_HEIGHT = P.HEADER_HEIGHT
local SEARCH_ICON_SIZE = 10
local SEARCH_TEXT_INSET = 18

local BagItems = ns.BagItems

local searchResults = P.searchResults
local frames = P.frames

local function itemMatchesSearch(itemId)
	local result = searchResults[itemId]
	if result == nil then
		local uncertain
		result, uncertain = BagItems.Matches(P.searchQuery, itemId)
		if not uncertain then
			searchResults[itemId] = result
		end
	end
	return result
end
P.itemMatchesSearch = itemMatchesSearch

local function setSearch(text, force)
	text = ns.Lower(text)
	if text == P.searchText and not force then
		return
	end
	P.searchText = text
	P.searchQuery = BagItems.CompileSearch(text)
	wipe(searchResults)
	for i = 1, #frames do
		local frame = frames[i]
		if ns.Lower(frame.search:GetText()) ~= text then
			frame.search:SetText(text)
		end
		if frame:IsShown() then
			frame:ForEachButton("UpdateSearch")
		end
	end
end
P.setSearch = setSearch

local function onSearchEscape(self)
	self:SetText("")
	self:ClearFocus()
end

local function onSearchFocusGained(self)
	self.placeholder:Hide()
end

local function onSearchFocusLost(self)
	if self:GetText() == "" then
		self.placeholder:Show()
	end
end

local function onSearchTextChanged(self)
	local text = self:GetText()
	setSearch(text)
	if text ~= "" then
		self.placeholder:Hide()
	elseif not self:HasFocus() then
		self.placeholder:Show()
	end
end

local SEARCH_HELP = {
	{ "q:epic  q>=3", "quality" },
	{ "ilvl>=251  ilvl<200", "item level" },
	{ "t:cloth  n:frost", "type / name" },
	{ "tt:text", "tooltip text" },
	{ "s:name", "equipment set" },
	{ "boe  bop  boa  quest", "binding" },
	{ "!a   a | b   a b", "not / or / and" },
}

local function onSearchEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(L["Search"], 1, 1, 1)
	GameTooltip:AddLine(L["Plain text matches name, type and slot."], 0.8, 0.8, 0.8)
	for i = 1, #SEARCH_HELP do
		local line = SEARCH_HELP[i]
		GameTooltip:AddDoubleLine(line[1], L[line[2]], 1, 0.82, 0, 0.8, 0.8, 0.8)
	end
	GameTooltip:Show()
end
ns.ShowItemSearchHelp = onSearchEnter

local function createSearchBox(frame, title)
	local search = CreateFrame("EditBox", nil, frame)
	search:SetAutoFocus(false)
	search:SetHeight(HEADER_HEIGHT)
	ns.SetFont(search, 12)
	search:SetTextInsets(SEARCH_TEXT_INSET, 4, 0, 0)
	search:SetMaxLetters(80)
	search:SetBackdrop(ns.CreateBackdrop(8))
	search:SetBackdropColor(0, 0, 0, 0.5)
	search:SetBackdropBorderColor(0.6, 0.6, 0.6)

	local icon = ns.CreateGlyph(search, "magnifying-glass", SEARCH_ICON_SIZE)
	icon:SetTextColor(0.5, 0.5, 0.5)
	icon:SetPoint("CENTER", search, "LEFT", SEARCH_TEXT_INSET / 2 + 1, 0)

	local placeholder = search:CreateFontString(nil, "OVERLAY")
	ns.SetFont(placeholder, 12)
	placeholder:SetTextColor(0.5, 0.5, 0.5)
	placeholder:SetPoint("LEFT", SEARCH_TEXT_INSET, 0)
	placeholder:SetText(title)
	search.placeholder = placeholder

	search:SetScript("OnEscapePressed", onSearchEscape)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	search:SetScript("OnEditFocusGained", onSearchFocusGained)
	search:SetScript("OnEditFocusLost", onSearchFocusLost)
	search:SetScript("OnTextChanged", onSearchTextChanged)
	search:SetScript("OnEnter", onSearchEnter)
	search:SetScript("OnLeave", GameTooltip_Hide)

	return search
end
P.createSearchBox = createSearchBox
