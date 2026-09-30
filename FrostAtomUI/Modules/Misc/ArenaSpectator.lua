local _, ns = ...

if not ns.IS_WOWCIRCLE then
	return
end

local UnitName = UnitName
local SelectGossipOption = SelectGossipOption
local ipairs, pairs, tonumber, wipe = ipairs, pairs, tonumber, wipe
local tinsert, tsort = table.insert, table.sort

local UF = ns:GetModule("UnitFrames")

local NPC_NAME = "Arena Spectator"
local ICON_SIZE = 17
local ICON_GAP = 1
local VS_GAP = 6
local LIST_TOP = 10
local NAV_WIDTH = 78
local NAV_HEIGHT = 22
local NAV_LEFT = 21
local NAV_BOTTOM = 73
local NAV_GAP = 2
local CARD_LEFT = 4
local CARD_RIGHT = -6
local CARD_INK = { 0.22, 0.13, 0.04 }
local CARD_BACKDROP = {
	bgFile = ns.Media.blank,
	edgeFile = ns.Media.blank,
	edgeSize = 1,
}
local CARD_FILL = { 0.35, 0.22, 0.08, 0.16 }
local CARD_FILL_HOVER = { 0.55, 0.35, 0.08, 0.38 }
local CARD_EDGE = { 0.3, 0.18, 0.06, 0.45 }
local CARD_EDGE_HOVER = { 0.35, 0.2, 0.04, 1 }
local DIM_ALPHA = 0.45
local BRACKET_HEIGHT = 44
local BRACKET_GAP = 8
local BRACKET_LABEL_SIZE = 17
local BRACKET_COUNT_SIZE = 12
local BRACKET_COUNT_X = 8
local BRACKET_COUNT_Y = 6
local MATCH_HEIGHT = 27
local MATCH_GAP = 4
local MATCH_PADDING = 8
local MATCH_RATING_SIZE = 14
local MATCH_VS_SIZE = 11
local BRACKET_PATTERN = "^%s*(.-)%s*%-%s*Spectators count:%s*(%d+)%s*$"
local ICON_TRIM = UF.ICON_TRIM

local CLASS_SUFFIXES = {
	warrior = "WARRIOR",
	paladin = "PALADIN",
	pala = "PALADIN",
	hunter = "HUNTER",
	hunt = "HUNTER",
	rogue = "ROGUE",
	priest = "PRIEST",
	deathknight = "DEATHKNIGHT",
	dk = "DEATHKNIGHT",
	shaman = "SHAMAN",
	mage = "MAGE",
	warlock = "WARLOCK",
	lock = "WARLOCK",
	druid = "DRUID",
}

local SPEC_NAMES = {
	DEATHKNIGHT = { "blood", "frost", "unholy" },
	DRUID = { "balance", "feral", "restoration" },
	HUNTER = { "beastmastery", "marksmanship", "survival" },
	MAGE = { "arcane", "fire", "frost" },
	PALADIN = { "holy", "protection", "retribution" },
	PRIEST = { "discipline", "holy", "shadow" },
	ROGUE = { "assassination", "combat", "subtlety" },
	SHAMAN = { "elemental", "enhancement", "restoration" },
	WARLOCK = { "affliction", "demonology", "destruction" },
	WARRIOR = { "arms", "fury", "protection" },
}

local SPEC_ALIASES = {
	HUNTER = { bm = 1, mm = 2, sv = 3 },
}

local HEALER_SPECS = {
	DRUID = { [3] = true },
	PALADIN = { [1] = true },
	PRIEST = { [1] = true, [2] = true },
	SHAMAN = { [3] = true },
}

local suffixes = {}
for suffix in pairs(CLASS_SUFFIXES) do
	tinsert(suffixes, suffix)
end
tsort(suffixes, function(a, b)
	return #a > #b
end)

local function parseSpec(class, prefix)
	if prefix == "" then
		return nil
	end
	local aliases = SPEC_ALIASES[class]
	if aliases and aliases[prefix] then
		return aliases[prefix]
	end
	for index, name in ipairs(SPEC_NAMES[class]) do
		if name:sub(1, #prefix) == prefix then
			return index
		end
	end
end

local function parsePlayer(token)
	local lower = token:lower()
	for _, suffix in ipairs(suffixes) do
		if #lower > #suffix and lower:sub(-#suffix) == suffix or lower == suffix then
			local class = CLASS_SUFFIXES[suffix]
			local spec = parseSpec(class, lower:sub(1, -#suffix - 1))
			local healers = HEALER_SPECS[class]
			return {
				class = class,
				spec = spec,
				specName = spec and SPEC_NAMES[class][spec],
				healer = spec and healers and healers[spec] or false,
			}
		end
	end
end

local function comparePlayers(a, b)
	if a.healer ~= b.healer then
		return b.healer
	end
	if a.class ~= b.class then
		return a.class < b.class
	end
	if not a.specName or not b.specName then
		return a.specName ~= nil and b.specName == nil
	end
	return a.specName < b.specName
end

local function parseTeam(text)
	local team = {}
	for token in text:gmatch("%S+") do
		local player = parsePlayer(token)
		if not player then
			return nil
		end
		tinsert(team, player)
	end
	if #team == 0 then
		return nil
	end
	tsort(team, comparePlayers)
	return team
end

local function parseMatch(text)
	local players1, rating1, players2, rating2 = text:match("^%s*(.-)%s*%[(%d+)%]%s*%-%s*(.-)%s*%[(%d+)%]%s*$")
	if not players1 then
		return nil
	end
	local team1, team2 = parseTeam(players1), parseTeam(players2)
	if team1 and team2 then
		rating1, rating2 = tonumber(rating1), tonumber(rating2)
		if rating2 > rating1 then
			return team2, rating2, team1, rating1
		end
		return team1, rating1, team2, rating2
	end
end

local function compareMatches(a, b)
	if a.spectatorRating ~= b.spectatorRating then
		return a.spectatorRating > b.spectatorRating
	end
	if a.spectatorRatingLow ~= b.spectatorRatingLow then
		return a.spectatorRatingLow > b.spectatorRatingLow
	end
	return a:GetID() < b:GetID()
end

local function onCardClick(card)
	SelectGossipOption(card:GetParent():GetID())
end

local function paintCard(card, hovered)
	local fill = hovered and CARD_FILL_HOVER or CARD_FILL
	local edge = hovered and CARD_EDGE_HOVER or CARD_EDGE
	card:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
	card:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

local function onCardEnter(card)
	paintCard(card, true)
end

local function onCardLeave(card)
	paintCard(card, false)
end

local function pressCard(card, x, y)
	local content = card.content
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", x, y)
	content:SetPoint("BOTTOMRIGHT", x, y)
end

local function onCardMouseDown(card)
	pressCard(card, 1, -1)
end

local function onCardMouseUp(card)
	pressCard(card, 0, 0)
end

local function createText(parent, size, alpha)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(STANDARD_TEXT_FONT, size)
	text:SetTextColor(CARD_INK[1], CARD_INK[2], CARD_INK[3])
	text:SetAlpha(alpha or 1)
	return text
end

local function createCard(button)
	local card = CreateFrame("Button", nil, button)
	card:SetPoint("TOPLEFT", CARD_LEFT, 0)
	card:SetPoint("TOPRIGHT", CARD_RIGHT, 0)
	card:SetBackdrop(CARD_BACKDROP)
	card:SetScript("OnClick", onCardClick)
	card:SetScript("OnEnter", onCardEnter)
	card:SetScript("OnLeave", onCardLeave)
	card:SetScript("OnMouseDown", onCardMouseDown)
	card:SetScript("OnMouseUp", onCardMouseUp)
	card.content = CreateFrame("Frame", nil, card)
	pressCard(card, 0, 0)

	local bracket = CreateFrame("Frame", nil, card.content)
	bracket:SetAllPoints()
	bracket.label = createText(bracket, BRACKET_LABEL_SIZE)
	bracket.label:SetPoint("CENTER")
	bracket.count = createText(bracket, BRACKET_COUNT_SIZE, DIM_ALPHA)
	bracket.count:SetPoint("BOTTOMRIGHT", -BRACKET_COUNT_X, BRACKET_COUNT_Y)
	card.bracket = bracket

	local match = CreateFrame("Frame", nil, card.content)
	match:SetAllPoints()
	match.left = createText(match, MATCH_RATING_SIZE)
	match.left:SetPoint("LEFT", MATCH_PADDING, 0)
	match.right = createText(match, MATCH_RATING_SIZE)
	match.right:SetPoint("RIGHT", -MATCH_PADDING, 0)
	match.vs = createText(match, MATCH_VS_SIZE, DIM_ALPHA)
	match.vs:SetPoint("CENTER")
	match.vs:SetText("vs")
	match.icons = {}
	card.match = match

	button.spectatorCard = card
	return card
end

local function showCard(button, height, gap, kind)
	local card = button.spectatorCard or createCard(button)
	card:SetHeight(height)
	ns.SetShown(card.bracket, kind == "bracket")
	ns.SetShown(card.match, kind == "match")
	paintCard(card, card:IsMouseOver())
	_G[button:GetName() .. "GossipIcon"]:Hide()
	button:EnableMouse(false)
	button:SetText("")
	button:SetHeight(height + gap)
	card:Show()
	return card
end

local function getIcon(match, index)
	local icon = match.icons[index]
	if not icon then
		icon = match:CreateTexture(nil, "ARTWORK")
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		match.icons[index] = icon
	end
	return icon
end

local function setIcon(icon, player)
	UF.SetClassTexture(icon, player.class, player.spec)
	if player.spec then
		icon:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
	end
	icon:Show()
end

local function layoutTeam(match, team, first, point, relativePoint, direction)
	local anchor = match.vs
	local count = #team
	for i = 1, count do
		local icon = getIcon(match, first + i - 1)
		setIcon(icon, team[direction > 0 and i or count - i + 1])
		icon:ClearAllPoints()
		icon:SetPoint(point, anchor, relativePoint, direction * (i == 1 and VS_GAP or ICON_GAP), 0)
		anchor = icon
	end
end

local function showMatch(button, team1, rating1, team2, rating2)
	local match = showCard(button, MATCH_HEIGHT, MATCH_GAP, "match").match
	match.left:SetText(rating1)
	match.right:SetText(rating2)
	layoutTeam(match, team1, 1, "RIGHT", "LEFT", -1)
	layoutTeam(match, team2, #team1 + 1, "LEFT", "RIGHT", 1)
	for i = #team1 + #team2 + 1, #match.icons do
		match.icons[i]:Hide()
	end
end

local function showBracket(button, name, count)
	local bracket = showCard(button, BRACKET_HEIGHT, BRACKET_GAP, "bracket").bracket
	bracket.label:SetText(name)
	bracket.count:SetText(count)
end

local function resetButton(button)
	if button.spectatorCard then
		button.spectatorCard:Hide()
	end
	_G[button:GetName() .. "GossipIcon"]:Show()
	button:EnableMouse(true)
end

local function onNavClick(self)
	SelectGossipOption(self:GetID())
end

local function createNavButton(text)
	local button = CreateFrame("Button", nil, GossipFrameGreetingPanel, "UIPanelButtonTemplate")
	button:SetSize(NAV_WIDTH, NAV_HEIGHT)
	button:SetText(text)
	button:SetScript("OnClick", onNavClick)
	button:Hide()
	return button
end

local navButtons = {}
navButtons.Back = createNavButton("Back")
navButtons.Back:SetPoint("BOTTOMLEFT", GossipFrame, "BOTTOMLEFT", NAV_LEFT, NAV_BOTTOM)
navButtons.Refresh = createNavButton("Refresh")

local function layoutNavButtons()
	local refresh, back = navButtons.Refresh, navButtons.Back
	refresh:ClearAllPoints()
	if back:IsShown() then
		refresh:SetPoint("LEFT", back, "RIGHT", NAV_GAP, 0)
	else
		refresh:SetPoint("BOTTOMLEFT", GossipFrame, "BOTTOMLEFT", NAV_LEFT, NAV_BOTTOM)
	end
end

local applied
local rows, matchRows, matchSlots = {}, {}, {}

local function restore()
	applied = false
	GossipGreetingText:Show()
	for _, nav in pairs(navButtons) do
		nav:Hide()
	end
	for i = 1, NUMGOSSIPBUTTONS do
		local button = _G["GossipTitleButton" .. i]
		button:ClearAllPoints()
		if i == 1 then
			button:SetPoint("TOPLEFT", GossipGreetingText, "BOTTOMLEFT", -10, -20)
		else
			button:SetPoint("TOPLEFT", _G["GossipTitleButton" .. (i - 1)], "BOTTOMLEFT", 0, -3)
		end
		resetButton(button)
	end
end

local function update()
	if UnitName("npc") ~= NPC_NAME then
		if applied then
			restore()
		end
		return
	end
	applied = true
	GossipGreetingText:Hide()
	for _, nav in pairs(navButtons) do
		nav:Hide()
	end

	wipe(rows)
	wipe(matchRows)
	wipe(matchSlots)
	for i = 1, NUMGOSSIPBUTTONS do
		local button = _G["GossipTitleButton" .. i]
		resetButton(button)
		if button:IsShown() then
			local text = button.type == "Gossip" and button:GetText() or ""
			local nav = navButtons[text]
			if nav then
				nav:SetID(button:GetID())
				nav:Show()
				button:Hide()
			else
				tinsert(rows, button)
				local bracket, count = text:match(BRACKET_PATTERN)
				if bracket then
					showBracket(button, bracket, count)
				else
					local team1, rating1, team2, rating2 = parseMatch(text)
					if team1 then
						showMatch(button, team1, rating1, team2, rating2)
						button.spectatorRating = rating1
						button.spectatorRatingLow = rating2
						tinsert(matchRows, button)
						tinsert(matchSlots, #rows)
					end
				end
			end
		end
	end

	tsort(matchRows, compareMatches)
	for i, slot in ipairs(matchSlots) do
		rows[slot] = matchRows[i]
	end

	local previous
	for _, button in ipairs(rows) do
		button:ClearAllPoints()
		if previous then
			button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -3)
		else
			button:SetPoint("TOPLEFT", GossipGreetingScrollChildFrame, "TOPLEFT", 0, -LIST_TOP)
		end
		previous = button
	end

	layoutNavButtons()

	if previous then
		GossipSpacerFrame:SetPoint("TOP", previous, "BOTTOM", 0, 0)
		GossipSpacerFrame:Show()
	else
		GossipSpacerFrame:Hide()
	end
end

hooksecurefunc("GossipFrameUpdate", update)
