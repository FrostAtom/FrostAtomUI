local _, ns = ...

local L = ns.L

local GetBattlefieldWinner = GetBattlefieldWinner
local GetBattlefieldInstanceExpiration = GetBattlefieldInstanceExpiration
local GetBattlefieldInstanceRunTime = GetBattlefieldInstanceRunTime
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local LeaveBattlefield = LeaveBattlefield
local GetRealZoneText = GetRealZoneText
local UnitName = UnitName
local GetTime = GetTime
local ShowUIPanel = ShowUIPanel
local HideUIPanel = HideUIPanel
local GameTooltip = GameTooltip
local FauxScrollFrame_Update = FauxScrollFrame_Update
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local floor, ceil, min = math.floor, math.ceil, math.min
local format = string.format
local sort = table.sort

local Misc = ns:GetModule("Misc")
local UF = ns:GetModule("UnitFrames")
local History = ns.ArenaHistory
local createStrip = History.CreateStrip
local setStripColor = History.SetStripColor

local FRAME_NAME = "FrostAtomUIMatchResults"
local WIDTH = 620
local INSET = ns.WINDOW_INSET
local INSET_PADDING = 4
local BANNER_TOP = 20
local BANNER_HEIGHT = 20
local LINE_HEIGHT = 18
local ROW_HEIGHT = 18
local COLUMN_HEADER_HEIGHT = 24
local MAX_ROWS = 15
local ICON_SIZE = 16
local BUTTON_HEIGHT = 22
local BUTTON_WIDTH = 100
local LEAVE_WIDTH = 150
local GAP = 8
local TICK_INTERVAL = 0.2
local UNKNOWN_NAME = UNKNOWNOBJECT
local SEPARATOR = "  " .. GRAY_FONT_COLOR_CODE .. "-|r  "

local RESULT_COLORS = { win = { 0.1, 1, 0.1 }, loss = { 1, 0.1, 0.1 }, draw = { 1, 0.82, 0 } }
local RESULT_STRIPS = { win = { 0.19, 0.57, 0.11 }, loss = { 0.52, 0.075, 0.18 }, draw = { 0.85, 0.71, 0.26 } }
local RESULT_TEXTS = { win = "Victory", loss = "Defeat", draw = "Draw" }
local ARENA_TEAM_COLORS = { [0] = { 0.1, 1, 0.1 }, [1] = { 1, 0.82, 0 } }
local FACTION_COLORS = { [0] = { 1, 0.1, 0.1 }, [1] = { 0, 0.68, 0.94 } }
local ARENA_TEAM_STRIPS = { [0] = { 0.19, 0.57, 0.11 }, [1] = { 0.85, 0.71, 0.26 } }
local FACTION_STRIPS = { [0] = { 0.52, 0.075, 0.18 }, [1] = { 0.11, 0.26, 0.51 } }

local CLASS_ICONS = UF.CLASS_ICONS
local ICON_TRIM = UF.ICON_TRIM
local classCoords = UF.classCoords

local KEYS = { "name", "kb", "deaths", "hk", "honor", "damage", "healing" }
local TITLES = {
	name = "Name",
	kb = "Kills",
	deaths = "Deaths",
	hk = "Honor kills",
	honor = "Honor",
	damage = "Damage",
	healing = "Healing",
}
local TOOLTIP_LABELS = {
	kb = "Killing blows",
	deaths = "Deaths",
	hk = "Honorable kills",
	honor = "Honor",
	damage = "Damage",
	healing = "Healing",
}
local ABBREVIATED = { damage = true, healing = true }

local ARENA_COLUMNS = {
	{ key = "name", width = 0 },
	{ key = "kb", width = 60 },
	{ key = "deaths", width = 60 },
	{ key = "damage", width = 90 },
	{ key = "healing", width = 90 },
}
local BG_COLUMNS = {
	{ key = "name", width = 0 },
	{ key = "kb", width = 50 },
	{ key = "deaths", width = 55 },
	{ key = "hk", width = 80 },
	{ key = "honor", width = 55 },
	{ key = "damage", width = 80 },
	{ key = "healing", width = 80 },
}

local function localizeValues(labels)
	for key, value in pairs(labels) do
		labels[key] = L[value]
	end
end

ns.OnLocaleReady(function()
	localizeValues(TITLES)
	localizeValues(TOOLTIP_LABELS)
	localizeValues(RESULT_TEXTS)
end)

local CONTENT_WIDTH = WIDTH - INSET.left - INSET.right
local LIST_WIDTH = CONTENT_WIDTH - INSET_PADDING * 2 - ns.SCROLLBAR_TRACK_WIDTH

local function layoutColumns(columns)
	local byKey = {}
	local x = 0
	local fixed = 0
	for i = 1, #columns do
		fixed = fixed + columns[i].width
	end
	for i = 1, #columns do
		local column = columns[i]
		column.x = x
		if column.width == 0 then
			column.width = LIST_WIDTH - fixed
		end
		x = x + column.width
		byKey[column.key] = column
	end
	columns.byKey = byKey
end

layoutColumns(ARENA_COLUMNS)
layoutColumns(BG_COLUMNS)

local frame
local rows = {}
local scores = {}
local teams = {}
local winner, isArena, isRated, playerTeam, duration
local closeAt
local dismissed = false
local sortKey, sortDescending

local function hexColor(color)
	return format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

local function classColor(class)
	local color = class and RAID_CLASS_COLORS[class]
	if color then
		return color.r, color.g, color.b
	end
	return 1, 1, 1
end

local function formatNumber(value)
	local text, count = tostring(value), 1
	while count > 0 do
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	end
	return text
end

local function formatRemaining(seconds)
	if seconds >= 60 then
		return format(L["%dm %ds"], floor(seconds / 60), seconds % 60)
	end
	return format(L["%ds"], seconds)
end

local function teamColor(teamIndex)
	return (isArena and ARENA_TEAM_COLORS or FACTION_COLORS)[teamIndex]
end

local function teamStrip(teamIndex)
	return (isArena and ARENA_TEAM_STRIPS or FACTION_STRIPS)[teamIndex]
end

local function matchResult()
	if winner ~= 0 and winner ~= 1 then
		return "draw"
	end
	if playerTeam then
		return winner == playerTeam and "win" or "loss"
	end
end

local function compare(a, b)
	if sortKey then
		local x, y = a[sortKey], b[sortKey]
		if x ~= y then
			if sortDescending then
				return x > y
			end
			return x < y
		end
	end
	if a.side ~= b.side then
		return a.side < b.side
	end
	if a.damage ~= b.damage then
		return a.damage > b.damage
	end
	return a.name < b.name
end

local function collect()
	winner = GetBattlefieldWinner()
	isArena, isRated = IsActiveBattlefieldArena()
	History.ReadScores(scores)
	playerTeam = History.PlayerTeamOf(scores)

	wipe(rows)
	local record, recordTeam = History.GetCurrent()
	if isArena and record and record.players and recordTeam then
		playerTeam = recordTeam
		duration = record.duration
		local players = record.players
		for i = 1, #players do
			local player = players[i]
			rows[i] = {
				name = player.name,
				class = player.class,
				teamIndex = player.team == 1 and recordTeam or 1 - recordTeam,
				kb = player.kb,
				deaths = player.deaths,
				hk = 0,
				honor = 0,
				damage = player.damage,
				healing = player.healing,
			}
		end
	else
		for i = 1, #scores do
			rows[i] = scores[i]
		end
	end

	local playerName = UnitName("player")
	for i = 1, #rows do
		local row = rows[i]
		row.name = row.name or UNKNOWN_NAME
		row.isPlayer = row.name == playerName
		if playerTeam then
			row.side = row.teamIndex == playerTeam and 1 or 2
		else
			row.side = (row.teamIndex or 0) + 1
		end
	end
	sort(rows, compare)

	if not duration then
		duration = floor(GetBattlefieldInstanceRunTime() / 1000)
	end
	if isArena then
		teams[0] = History.ReadTeam(0)
		teams[1] = History.ReadTeam(1)
	end
end

local function syncExpiration()
	local expiration = GetBattlefieldInstanceExpiration()
	if expiration and expiration > 0 then
		closeAt = GetTime() + expiration / 1000
	end
end

local function teamLine(teamIndex, side)
	local team = teams[teamIndex]
	local name = team.name
	if not name or name == "" then
		name = side == 1 and L["Team"] or L["Enemy"]
	end
	local change
	if team.change > 0 then
		change = format("%s+%d|r", GREEN_FONT_COLOR_CODE, team.change)
	elseif team.change < 0 then
		change = format("%s-%d|r", RED_FONT_COLOR_CODE, -team.change)
	else
		change = GRAY_FONT_COLOR_CODE .. L["Rating unchanged"] .. "|r"
	end
	return hexColor(teamColor(teamIndex))
		.. name
		.. "|r"
		.. SEPARATOR
		.. change
		.. SEPARATOR
		.. HIGHLIGHT_FONT_COLOR_CODE
		.. format(L["MMR %d"], team.mmr)
		.. "|r"
end

local function showTeams()
	return isArena and teams[0] and (isRated or teams[0].mmr > 0 or teams[1].mmr > 0)
end

local function setIcon(icon, class)
	local coords = classCoords[class]
	if coords then
		icon:SetTexture(CLASS_ICONS)
		icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		icon:SetTexture(ns.Media.questionMark)
		icon:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
	end
end

local function currentColumns()
	return isArena and ARENA_COLUMNS or BG_COLUMNS
end

local function placeCell(cell, column)
	cell:ClearAllPoints()
	if column.key == "name" then
		cell:SetPoint("LEFT", column.x + ICON_SIZE + 8, 0)
		cell:SetSize(column.width - ICON_SIZE - 12, ROW_HEIGHT)
	else
		cell:SetPoint("LEFT", column.x + 4, 0)
		cell:SetSize(column.width - 8, ROW_HEIGHT)
	end
	cell:Show()
end

local function applyColumns()
	local columns = currentColumns()
	if frame.columns == columns then
		return
	end
	frame.columns = columns
	local byKey = columns.byKey
	for i = 1, #KEYS do
		local key = KEYS[i]
		local column = byKey[key]
		local header = frame.headers[key]
		if column then
			local overlap = column.x > 0 and 2 or 0
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", column.x - overlap, 0)
			WhoFrameColumn_SetWidth(header, column.width + overlap)
			local text = header:GetFontString()
			text:ClearAllPoints()
			if key == "name" then
				text:SetPoint("LEFT", overlap + 4, 0)
			else
				text:SetPoint("RIGHT", -4, 0)
			end
			header:Show()
		else
			header:Hide()
		end
		for j = 1, MAX_ROWS do
			local cell = frame.rows[j].cells[key]
			if column then
				placeCell(cell, column)
			else
				cell:Hide()
			end
		end
	end
end

local function fillRow(row, data)
	row.data = data
	local cells = row.cells
	setIcon(row.icon, data.class)
	cells.name:SetText(data.name)
	if data.isPlayer then
		cells.name:SetTextColor(1, 1, 1)
		row:LockHighlight()
	else
		cells.name:SetTextColor(classColor(data.class))
		row:UnlockHighlight()
	end
	for i = 2, #KEYS do
		local key = KEYS[i]
		local value = data[key] or 0
		cells[key]:SetText(ABBREVIATED[key] and ns.FormatValue(value) or value)
	end
	local color = teamStrip(data.teamIndex)
	if color then
		setStripColor(row.strip, color)
	end
	ns.SetShown(row.strip[1], color)
	ns.SetShown(row.strip[2], color)
end

local function refreshList()
	local offset = FauxScrollFrame_GetOffset(frame.scroll)
	for i = 1, MAX_ROWS do
		local row = frame.rows[i]
		local data = rows[i + offset]
		if data and i <= frame.visibleRows then
			fillRow(row, data)
			row:Show()
		else
			row:Hide()
		end
	end
	FauxScrollFrame_Update(frame.scroll, #rows, frame.visibleRows, ROW_HEIGHT)
end

local function refreshHeaders()
	for key, header in pairs(frame.headers) do
		local text = TITLES[key]
		if key == sortKey then
			header:SetText(NORMAL_FONT_COLOR_CODE .. text .. (sortDescending and " v" or " ^") .. "|r")
		else
			header:SetText(text)
		end
	end
end

local lastRemaining

local function refreshLeave()
	local remaining = closeAt and ceil(closeAt - GetTime()) or 0
	if remaining == lastRemaining then
		return
	end
	lastRemaining = remaining
	if remaining > 0 then
		frame.leave.text:SetFormattedText(L["Leave (%s)"], formatRemaining(remaining))
	else
		frame.leave.text:SetText(L["Leave"])
	end
end

local function refresh()
	if not frame or not frame:IsShown() then
		return
	end

	local result = matchResult()
	local banner = frame.banner
	if result then
		banner.text:SetText(RESULT_TEXTS[result])
		banner.text:SetTextColor(unpack(RESULT_COLORS[result]))
		setStripColor(banner.strip, RESULT_STRIPS[result])
	else
		banner.text:SetText(_G[(isArena and "VICTORY_TEXT_ARENA" or "VICTORY_TEXT") .. winner] or "")
		banner.text:SetTextColor(unpack(teamColor(winner) or RESULT_COLORS.draw))
		setStripColor(banner.strip, teamStrip(winner) or RESULT_STRIPS.draw)
	end
	frame.subtitle:SetText(GetRealZoneText() .. SEPARATOR .. format("%d:%02d", duration / 60, duration % 60))

	local y = BANNER_TOP + BANNER_HEIGHT + LINE_HEIGHT
	if showTeams() then
		local own = playerTeam or 0
		frame.teams[1]:SetText(teamLine(own, 1))
		frame.teams[2]:SetText(teamLine(1 - own, 2))
		for side = 1, 2 do
			frame.teams[side]:SetPoint("TOPLEFT", INSET.left + INSET_PADDING, -y)
			frame.teams[side]:Show()
			y = y + LINE_HEIGHT
		end
	else
		frame.teams[1]:Hide()
		frame.teams[2]:Hide()
	end
	y = y + GAP

	applyColumns()
	refreshHeaders()
	frame.visibleRows = min(#rows, MAX_ROWS)
	local listHeight = frame.visibleRows * ROW_HEIGHT
	frame.listInset:SetPoint("TOPLEFT", INSET.left, -y)
	frame.listInset:SetHeight(INSET_PADDING * 2 + COLUMN_HEADER_HEIGHT + listHeight)
	frame.list:SetHeight(listHeight)
	refreshList()
	y = y + frame.listInset:GetHeight() + GAP

	ns.SetShown(frame.history, isArena and History.GetCurrent())
	refreshLeave()
	frame:SetHeight(y + BUTTON_HEIGHT + INSET.bottom)
end

local function onHeaderClick(self)
	local key = self.key
	if sortKey == key then
		sortDescending = not sortDescending
	else
		sortKey = key
		sortDescending = key ~= "name"
	end
	sort(rows, compare)
	refresh()
end

local function onRowEnter(self)
	local data = self.data
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(data.name, classColor(data.class))
	local columns = frame.columns.byKey
	for i = 2, #KEYS do
		local key = KEYS[i]
		if columns[key] then
			GameTooltip:AddDoubleLine(TOOLTIP_LABELS[key], formatNumber(data[key] or 0), 0.7, 0.7, 0.7, 1, 1, 1)
		end
	end
	GameTooltip:Show()
end

local function createRow(parent, index)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT")
	local highlight = ns.AddHighlight(row, "list")
	highlight:ClearAllPoints()
	highlight:SetPoint("TOPLEFT", 0, -1)
	highlight:SetPoint("BOTTOMRIGHT", 0, 1)
	row.strip = createStrip(row)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.icon:SetPoint("LEFT", 4, 0)

	local cells = {}
	for i = 1, #KEYS do
		local key = KEYS[i]
		local cell =
			row:CreateFontString(nil, "OVERLAY", key == "name" and "GameFontHighlight" or "GameFontHighlightSmall")
		cell:SetJustifyH(key == "name" and "LEFT" or "RIGHT")
		cell:SetJustifyV("MIDDLE")
		cells[key] = cell
	end
	row.cells = cells

	row:SetScript("OnEnter", onRowEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)
	return row
end

local function onUpdate(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick > 0 then
		return
	end
	self.untilTick = TICK_INTERVAL
	refreshLeave()
end

local function createFrame()
	frame = ns.CreateWindow(FRAME_NAME, { width = WIDTH, height = 300, background = "dark" })
	Misc:AnchorToConfig(frame, "matchResults.point", "Match results")
	frame.untilTick = 0
	frame:SetScript("OnUpdate", onUpdate)
	frame:SetScript("OnShow", function(self)
		self.untilTick = 0
		lastRemaining = nil
		refresh()
	end)
	frame:SetScript("OnHide", function()
		dismissed = true
	end)

	local banner = CreateFrame("Frame", nil, frame)
	banner:SetPoint("TOPLEFT", INSET.left, -BANNER_TOP)
	banner:SetPoint("TOPRIGHT", -40, -BANNER_TOP)
	banner:SetHeight(BANNER_HEIGHT)
	banner.strip = createStrip(banner)
	banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	banner.text:SetPoint("CENTER")
	frame.banner = banner

	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOP", 0, -(BANNER_TOP + BANNER_HEIGHT))
	subtitle:SetHeight(LINE_HEIGHT)
	frame.subtitle = subtitle

	frame.teams = {}
	for side = 1, 2 do
		local team = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		team:SetHeight(LINE_HEIGHT)
		team:SetJustifyV("MIDDLE")
		frame.teams[side] = team
	end

	local listInset = ns.CreateInset(frame, "box")
	listInset:SetWidth(CONTENT_WIDTH)
	frame.listInset = listInset

	local header = CreateFrame("Frame", nil, listInset)
	header:SetPoint("TOPLEFT", INSET_PADDING, -INSET_PADDING)
	header:SetSize(LIST_WIDTH, COLUMN_HEADER_HEIGHT)
	frame.headers = {}
	for i = 1, #KEYS do
		local key = KEYS[i]
		local button = CreateFrame("Button", FRAME_NAME .. "Header" .. i, header, "WhoFrameColumnHeaderTemplate")
		button.key = key
		button:SetScript("OnClick", function(self)
			PlaySound("igMainMenuOptionCheckBoxOn")
			onHeaderClick(self)
		end)
		frame.headers[key] = button
	end

	local list = CreateFrame("Frame", nil, listInset)
	list:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	list:SetWidth(LIST_WIDTH)
	frame.list = list

	local scroll = ns.CreateFauxScrollFrame(list, FRAME_NAME .. "Scroll")
	scroll:SetAllPoints()
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, refreshList)
	end)
	local scrollBar = scroll.scrollBar
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, -16)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 16)
	ns.SkinScrollBar(scroll)
	frame.scroll = scroll

	frame.rows = {}
	for i = 1, MAX_ROWS do
		frame.rows[i] = createRow(list, i)
	end
	frame.visibleRows = 0

	local leave = ns.CreateButton(frame, L["Leave"], LEAVE_WIDTH, BUTTON_HEIGHT)
	leave:SetPoint("BOTTOMRIGHT", -INSET.right, INSET.bottom)
	leave:SetScript("OnClick", LeaveBattlefield)
	frame.leave = leave

	local scoreboard = ns.CreateButton(frame, L["Scoreboard"], BUTTON_WIDTH, BUTTON_HEIGHT)
	scoreboard:SetPoint("BOTTOMLEFT", INSET.left, INSET.bottom)
	scoreboard:SetScript("OnClick", function()
		frame:Hide()
		ShowUIPanel(WorldStateScoreFrame)
	end)

	local history = ns.CreateButton(frame, L["History"], BUTTON_WIDTH, BUTTON_HEIGHT)
	history:SetPoint("LEFT", scoreboard, "RIGHT", 4, 0)
	history:SetScript("OnClick", History.Toggle)
	frame.history = history
end

local function suppressScoreboard()
	if frame and frame:IsShown() and ns.Config.matchResults.replaceScoreboard and WorldStateScoreFrame:IsShown() then
		HideUIPanel(WorldStateScoreFrame)
	end
end

hooksecurefunc("WorldStateScoreFrame_Update", suppressScoreboard)
hooksecurefunc("ToggleWorldStateScoreFrame", function()
	if not frame or not frame:IsShown() then
		return
	end
	if WorldStateScoreFrame:IsShown() then
		frame:Hide()
	elseif ns.Config.matchResults.replaceScoreboard then
		frame:Hide()
		ShowUIPanel(WorldStateScoreFrame)
	end
end)

local function shouldShow()
	local config = ns.Config.matchResults
	return config.enabled and GetBattlefieldWinner() and (config.battlegrounds or IsActiveBattlefieldArena())
end

local function onScoreUpdate()
	if not shouldShow() then
		return
	end
	syncExpiration()
	local shown = frame and frame:IsShown()
	if not shown and dismissed then
		return
	end
	collect()
	if shown then
		refresh()
		return
	end
	if not frame then
		createFrame()
	end
	frame:Show()
	suppressScoreboard()
end

Misc:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", onScoreUpdate)

Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function()
	if not shouldShow() then
		return
	end
	syncExpiration()
	if not frame or not frame:IsShown() and not dismissed then
		RequestBattlefieldScoreData()
	end
end)

Misc:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if frame then
		frame:Hide()
	end
	dismissed = false
	closeAt = nil
	duration = nil
	wipe(rows)
	wipe(teams)
end)

Misc:WatchConfig("matchResults", function()
	if frame and frame:IsShown() and not shouldShow() then
		frame:Hide()
	end
end)
