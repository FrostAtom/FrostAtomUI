local _, ns = ...

local L = ns.L

local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
local GetBattlefieldWinner = GetBattlefieldWinner
local GetBattlefieldInstanceRunTime = GetBattlefieldInstanceRunTime
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local IsInInstance = IsInInstance
local GetRealZoneText = GetRealZoneText
local GetNumPartyMembers = GetNumPartyMembers
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitBuff = UnitBuff
local GameTooltip = GameTooltip
local StaticPopup_Show = StaticPopup_Show
local FauxScrollFrame_Update = FauxScrollFrame_Update
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local time, date = time, date
local floor, max = math.floor, math.max
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local format = string.format

local Misc = ns:GetModule("Misc")
local UF = ns:GetModule("UnitFrames")
local Talents = ns:GetModule("Talents")

local FRAME_NAME = "FrostAtomUIArenaHistory"
local MAX_TEAM = 5
local WIDTH = 800
local PADDING = 12
local HEADER_HEIGHT = 22
local FILTER_HEIGHT = 20
local FILTER_WIDTH = 46
local LIST_ROWS = 14
local LIST_ROW_HEIGHT = 20
local DETAIL_ROW_HEIGHT = 18
local DETAIL_GAP = 10
local SCROLLBAR_WIDTH = 24
local ICON_SIZE = 16
local ICON_GAP = 1
local NO_GAME_COLOR = { 0.5, 0.5, 0.5 }
local HEADER_COLOR = { 0.7, 0.7, 0.7 }
local UNKNOWN_NAME = UNKNOWNOBJECT
local ARENA_PREPARATION = GetSpellInfo(32727) -- Arena Preparation
local SEPARATOR = "   |cff7f7f7f-|r   "

local CLASS_ICONS = UF.CLASS_ICONS
local ICON_TRIM = UF.ICON_TRIM
local classCoords = UF.classCoords
local specIcons = UF.specIcons

local FILTERS = { { "all", "All" }, { "2v2", "2v2" }, { "3v3", "3v3" }, { "solo", "Solo" } }
local BRACKET_LABELS = { solo = "Solo" }
local MAP_LABELS = {
	["Nagrand Arena"] = "Nagrand",
	["Blade's Edge Arena"] = "Blade's Edge",
	["Ruins of Lordaeron"] = "Lordaeron",
	["Dalaran Sewers"] = "Dalaran",
	["The Ring of Valor"] = "Ring of Valor",
}

local ICONS_WIDTH = MAX_TEAM * (ICON_SIZE + ICON_GAP) + 8
local LIST_COLUMNS = {
	{ key = "date", title = "Date", width = 90 },
	{ key = "bracket", title = "Type", width = 42 },
	{ key = "map", title = "Map", width = 100 },
	{ key = "duration", title = "Time", width = 46 },
	{ key = "result", title = "Result", width = 72 },
	{ key = "mmr", title = "MMR", width = 46 },
	{ key = "team", title = "Team", width = ICONS_WIDTH, icons = 1 },
	{ key = "enemy", title = "Enemy", width = ICONS_WIDTH, icons = 2 },
	{ key = "names", title = "", width = 0 },
}
local DETAIL_COLUMNS = {
	{ key = "name", title = "Name", width = 170 },
	{ key = "race", title = "Race", width = 90 },
	{ key = "kb", title = "Kills", width = 50, right = true },
	{ key = "deaths", title = "Deaths", width = 60, right = true },
	{ key = "damage", title = "Damage", width = 80, right = true },
	{ key = "healing", title = "Healing", width = 80, right = true },
}

local function localizeValues(labels)
	for key, value in pairs(labels) do
		labels[key] = L[value]
	end
end

local function localizeTitles(columns)
	for i = 1, #columns do
		local column = columns[i]
		column.title = L[column.title]
	end
end

ns.OnLocaleReady(function()
	for i = 1, #FILTERS do
		FILTERS[i][2] = L[FILTERS[i][2]]
	end
	localizeValues(BRACKET_LABELS)
	localizeValues(MAP_LABELS)
	localizeTitles(LIST_COLUMNS)
	localizeTitles(DETAIL_COLUMNS)
end)

local function layoutColumns(columns, totalWidth)
	local x = 0
	for i = 1, #columns do
		local column = columns[i]
		column.x = x
		if column.width == 0 then
			column.width = totalWidth - x
		end
		x = x + column.width
	end
end

local CONTENT_WIDTH = WIDTH - PADDING * 2
layoutColumns(LIST_COLUMNS, CONTENT_WIDTH - SCROLLBAR_WIDTH)
layoutColumns(DETAIL_COLUMNS, CONTENT_WIDTH)

local history
local current
local inArena = false
local seen = {}
local sightings = {}
local unknowns = {}
local teamNames = {}
local soloQueueSearchSeen = false
local isSoloMatch = false
local preparing = false
local startTime

local frame
local filter = "all"
local filtered = {}
local selected

local function stripRealm(name)
	return name and name:match("^([^%-]+)") or name
end

local function addPlayer(name, side)
	local entry = seen[name]
	if not entry then
		entry = { name = name, team = side, kb = 0, deaths = 0, damage = 0, healing = 0 }
		seen[name] = entry
		sightings[#sightings + 1] = entry
	end
	return entry
end

local function collectUnit(unit, side)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end
	local name = stripRealm(UnitName(unit))
	if not name or name == UNKNOWN_NAME then
		return
	end
	local entry = addPlayer(name, side)
	entry.guid = UnitGUID(unit) or entry.guid
	entry.class = select(2, UnitClass(unit)) or entry.class
	entry.race = UnitRace(unit) or entry.race
end

local function collectParty()
	collectUnit("player", 1)
	for i = 1, GetNumPartyMembers() do
		collectUnit("party" .. i, 1)
	end
end

local function collectArena()
	for i = 1, MAX_TEAM do
		collectUnit("arena" .. i, 2)
	end
end

local function collectTeams()
	for teamIndex = 0, 1 do
		local name = GetBattlefieldTeamInfo(teamIndex)
		if name and name ~= "" then
			teamNames[teamIndex] = name
		end
	end
end

local function bracketOf(teamName, size)
	if teamName then
		if teamName:find("^Solo Team [1-2]$") then
			return "solo"
		end
	elseif isSoloMatch then
		return "solo"
	end
	return size .. "v" .. size
end

local function copyScore(to, from)
	to.kb, to.deaths, to.damage, to.healing = from.kb, from.deaths, from.damage, from.healing
end

local function mergeScore(to, from)
	to.kb = max(to.kb, from.kb)
	to.deaths = max(to.deaths, from.deaths)
	to.damage = max(to.damage, from.damage)
	to.healing = max(to.healing, from.healing)
end

local function readScores(rows)
	local numScores = GetNumBattlefieldScores()
	for i = 1, numScores do
		local name, kb, hk, deaths, honor, teamIndex, _, race, _, class, damage, healing = GetBattlefieldScore(i)
		local row = rows[i] or {}
		rows[i] = row
		row.name, row.teamIndex, row.race, row.class = stripRealm(name), teamIndex, race, class
		row.kb, row.hk, row.deaths, row.honor = kb or 0, hk or 0, deaths or 0, honor or 0
		row.damage, row.healing = damage or 0, healing or 0
	end
	for i = #rows, numScores + 1, -1 do
		rows[i] = nil
	end
	return rows
end

local function playerTeamOf(rows)
	local playerName = UnitName("player")
	for i = 1, #rows do
		if rows[i].name == playerName then
			return rows[i].teamIndex
		end
	end
end

local function readTeam(teamIndex)
	local name, lost, gained, mmr = GetBattlefieldTeamInfo(teamIndex)
	if not name or name == "" then
		name = teamNames[teamIndex]
	end
	lost, gained = lost or 0, gained or 0
	return { name = name, lost = lost, gained = gained, change = gained - lost, mmr = mmr or 0 }
end

local refresh
local scores = {}
local currentTeam

local function snapshot()
	local winner = GetBattlefieldWinner()
	if not winner or not history or not ns.Config.arenaHistory.enabled then
		return
	end
	readScores(scores)
	if #scores == 0 then
		return
	end

	local playerTeam = playerTeamOf(scores)
	if not playerTeam then
		return
	end
	currentTeam = playerTeam

	collectParty()
	collectArena()
	wipe(unknowns)
	for i = 1, #sightings do
		sightings[i].scored = nil
	end
	for i = 1, #scores do
		local row = scores[i]
		local name = row.name
		local side = row.teamIndex == playerTeam and 1 or 2
		local score = { kb = row.kb, deaths = row.deaths, damage = row.damage, healing = row.healing }
		if name and name ~= UNKNOWN_NAME then
			local entry = addPlayer(name, side)
			entry.class = entry.class or row.class
			entry.race = entry.race or row.race
			entry.scored = true
			mergeScore(entry, score)
		else
			score.name, score.team = UNKNOWN_NAME, side
			unknowns[#unknowns + 1] = score
		end
	end

	local record = current
	if not record then
		record = { time = time() }
		current = record
		tinsert(history, 1, record)
		while #history > ns.Config.arenaHistory.maxGames do
			tremove(history)
		end
	end
	record.map = GetRealZoneText()
	if not record.duration then
		local runTime = floor(GetBattlefieldInstanceRunTime() / 1000)
		record.duration = runTime > 0 and runTime or startTime and time() - startTime or 0
	end
	record.win = winner == playerTeam

	record.team = readTeam(playerTeam)
	record.enemy = readTeam(1 - playerTeam)

	local players, counts = {}, { 0, 0 }
	for i = 1, #sightings do
		local entry = sightings[i]
		entry.spec = entry.guid and Talents:GetSpec(entry.guid) or entry.spec
		if not entry.scored then
			for j = 1, #unknowns do
				if unknowns[j].team == entry.team then
					mergeScore(entry, tremove(unknowns, j))
					break
				end
			end
		end
		counts[entry.team] = counts[entry.team] + 1
		local player =
			{ name = entry.name, class = entry.class, race = entry.race, spec = entry.spec, team = entry.team }
		copyScore(player, entry)
		players[#players + 1] = player
	end
	for i = 1, #unknowns do
		local unknown = unknowns[i]
		local side = unknown.team
		if counts[side] < counts[3 - side] then
			counts[side] = counts[side] + 1
			players[#players + 1] = unknown
		end
	end
	record.players = players
	record.bracket = bracketOf(record.team.name, max(counts[1], counts[2]))

	refresh()
end

Misc:RegisterEvent(ns.DB_LOADED, function(_, db)
	history = db.arena_history or {}
	db.arena_history = history
end)

Misc:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	inArena = select(2, IsInInstance()) == "arena"
	current = nil
	currentTeam = nil
	preparing = false
	startTime = nil
	wipe(seen)
	wipe(sightings)
	wipe(teamNames)
	if inArena then
		isSoloMatch = soloQueueSearchSeen
		soloQueueSearchSeen = false
		collectParty()
		collectArena()
		RequestBattlefieldScoreData()
	end
end)

Misc:RegisterEvent(ns.SOLOQ_SEARCHING, function()
	soloQueueSearchSeen = true
end)

Misc:RegisterEvent("PARTY_MEMBERS_CHANGED", function()
	if inArena then
		collectParty()
	end
end)

Misc:RegisterEvent("ARENA_OPPONENT_UPDATE", function(_, unit)
	if inArena and unit:find("^arena%d$") then
		collectUnit(unit, 2)
	end
end)

Misc:RegisterEvent("UNIT_NAME_UPDATE", function(_, unit)
	if not inArena then
		return
	end
	if unit:find("^arena%d$") then
		collectUnit(unit, 2)
	elseif unit == "player" or unit:find("^party%d$") then
		collectUnit(unit, 1)
	end
end)

Misc:RegisterEvent("UNIT_AURA", function(_, unit)
	if unit ~= "player" or not inArena or startTime then
		return
	end
	if UnitBuff("player", ARENA_PREPARATION) then
		preparing = true
	elseif preparing then
		startTime = time()
		RequestBattlefieldScoreData()
	end
end)

local function onScoreUpdate()
	if inArena then
		collectTeams()
		snapshot()
	end
end
Misc:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", onScoreUpdate)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", onScoreUpdate)

local function classColor(class)
	local color = class and RAID_CLASS_COLORS[class]
	if color then
		return color.r, color.g, color.b
	end
	return 1, 1, 1
end

local classHex = {}

local function coloredName(player)
	local class = player.class or "UNKNOWN"
	local hex = classHex[class]
	if not hex then
		local r, g, b = classColor(class)
		hex = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
		classHex[class] = hex
	end
	return hex .. player.name .. "|r"
end

local function played(record)
	return record.team.mmr > 0
end

local function resultColor(record, win)
	if not played(record) then
		return unpack(NO_GAME_COLOR)
	end
	local config = ns.Config.arenaHistory
	return unpack(win and config.winColor or config.lossColor)
end

local function formatDuration(seconds)
	return format("%d:%02d", seconds / 60, seconds % 60)
end

local function formatChange(change)
	if change > 0 then
		return format("|cff4dff4d+%d|r", change)
	elseif change < 0 then
		return format("|cffff4d4d%d|r", change)
	end
	return "|cff7f7f7f0|r"
end

local function bracketLabel(record)
	return BRACKET_LABELS[record.bracket] or record.bracket
end

local function mapLabel(record)
	return MAP_LABELS[record.map] or record.map or UNKNOWN_NAME
end

local function teamLabel(record, side)
	local team = side == 1 and record.team or record.enemy
	local name = team.name
	if not name or name == "" then
		name = side == 1 and L["Team"] or L["Enemy"]
	end
	if not played(record) then
		return name
	end
	return format("%s  |cffffffff%d|r  %s", name, team.mmr, formatChange(team.change))
end

local function setPlayerIcon(icon, player)
	local class = player.class
	local specIcon = player.spec and specIcons[class] and specIcons[class][player.spec]
	local coords = classCoords[class]
	if specIcon then
		icon:SetTexture(specIcon)
		icon:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
	elseif coords then
		icon:SetTexture(CLASS_ICONS)
		icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		icon:SetTexture(ns.Media.questionMark)
		icon:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
	end
end

local listCells = {}

local function setListFont(cell)
	local font = ns.Config.arenaHistory.listFont
	ns.SetFont(cell, font.size, font.outline)
end

local function createCells(row, columns, height)
	local cells = {}
	for i = 1, #columns do
		local column = columns[i]
		if not column.icons then
			local cell = row:CreateFontString(nil, "OVERLAY")
			setListFont(cell)
			listCells[#listCells + 1] = cell
			cell:SetPoint("LEFT", column.x + 4, 0)
			cell:SetSize(column.width - 8, height)
			cell:SetJustifyH(column.right and "RIGHT" or "LEFT")
			cell:SetJustifyV("MIDDLE")
			cells[column.key] = cell
		end
	end
	row.cells = cells
end

local function createHeaders(parent, columns, y)
	for i = 1, #columns do
		local column = columns[i]
		local header = parent:CreateFontString(nil, "OVERLAY")
		ns.SetFont(header, 11, "OUTLINE", true)
		header:SetTextColor(unpack(HEADER_COLOR))
		header:SetPoint("TOPLEFT", column.x + 4, y)
		header:SetSize(column.width - 8, DETAIL_ROW_HEIGHT)
		header:SetJustifyH(column.right and "RIGHT" or "LEFT")
		header:SetJustifyV("MIDDLE")
		header:SetText(column.title)
	end
end

local function createIcons(row, column)
	local icons = {}
	for i = 1, MAX_TEAM do
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint("LEFT", column.x + 4 + (i - 1) * (ICON_SIZE + ICON_GAP), 0)
		icons[i] = icon
	end
	return icons
end

local function fillIcons(icons, record, side)
	local shown = 0
	local players = record.players
	for i = 1, #players do
		local player = players[i]
		if player.team == side and shown < MAX_TEAM then
			shown = shown + 1
			setPlayerIcon(icons[shown], player)
			icons[shown]:Show()
		end
	end
	for i = shown + 1, MAX_TEAM do
		icons[i]:Hide()
	end
end

local nameParts = {}

local function coloredTeamNames(record, side)
	wipe(nameParts)
	local players = record.players
	for i = 1, #players do
		local player = players[i]
		if player.team == side then
			nameParts[#nameParts + 1] = coloredName(player)
		end
	end
	return tconcat(nameParts, ", ")
end

local function fillListRow(row, record)
	local cells = row.cells
	row.record = record
	cells.date:SetText(date("%d.%m %H:%M", record.time))
	cells.bracket:SetText(bracketLabel(record))
	cells.map:SetText(mapLabel(record))
	cells.duration:SetText(formatDuration(record.duration))
	if played(record) then
		cells.result:SetFormattedText("%s %+d", record.win and L["Win"] or L["Loss"], record.team.change)
		cells.mmr:SetText(record.team.mmr)
	else
		cells.result:SetText(L["No game"])
		cells.mmr:SetText("")
	end
	cells.result:SetTextColor(resultColor(record, record.win))
	fillIcons(row.icons[1], record, 1)
	fillIcons(row.icons[2], record, 2)
	cells.names:SetText(coloredTeamNames(record, 2))
	ns.SetShown(row.selected, record == selected)
end

local function onRowEnter(self)
	local record = self.record
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	for side = 1, 2 do
		if side == 2 then
			GameTooltip:AddLine(" ")
		end
		GameTooltip:AddLine(teamLabel(record, side), 1, 0.82, 0)
		local players = record.players
		for i = 1, #players do
			local player = players[i]
			if player.team == side then
				GameTooltip:AddDoubleLine(coloredName(player), player.race or "", 1, 1, 1, 0.7, 0.7, 0.7)
			end
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["Right-click to delete"], 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local function onRowClick(self, button)
	if button == "RightButton" then
		StaticPopup_Show("FROSTATOMUI_ARENA_HISTORY_DELETE", nil, nil, self.record)
	else
		selected = self.record
		refresh()
	end
end

local function createListRow(parent, index)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(LIST_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * LIST_ROW_HEIGHT)
	row:SetPoint("RIGHT")
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetHighlightTexture(ns.Media.blank)
	row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)

	row.selected = row:CreateTexture(nil, "BACKGROUND")
	row.selected:SetTexture(ns.Media.blank)
	row.selected:SetVertexColor(1, 1, 1, 0.08)
	row.selected:SetAllPoints()

	createCells(row, LIST_COLUMNS, LIST_ROW_HEIGHT)
	row.icons = { createIcons(row, LIST_COLUMNS[7]), createIcons(row, LIST_COLUMNS[8]) }

	row:SetScript("OnEnter", onRowEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row:SetScript("OnClick", onRowClick)
	return row
end

local function createDetailRow(detail, index)
	local row = CreateFrame("Frame", nil, detail)
	row:SetHeight(DETAIL_ROW_HEIGHT)
	row:SetPoint("RIGHT")
	createCells(row, DETAIL_COLUMNS, DETAIL_ROW_HEIGHT)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.icon:SetPoint("LEFT", DETAIL_COLUMNS[1].x + 4, 0)
	row.cells.name:ClearAllPoints()
	row.cells.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.cells.name:SetWidth(DETAIL_COLUMNS[1].width - ICON_SIZE - 12)

	detail.rows[index] = row
	return row
end

local function fillDetailRow(row, player)
	local cells = row.cells
	setPlayerIcon(row.icon, player)
	cells.name:SetText(player.name)
	cells.name:SetTextColor(classColor(player.class))
	cells.race:SetText(player.race or "")
	cells.kb:SetText(player.kb)
	cells.deaths:SetText(player.deaths)
	cells.damage:SetText(ns.FormatValue(player.damage))
	cells.healing:SetText(ns.FormatValue(player.healing))
end

local function refreshDetail()
	local detail = frame.detail
	local record = selected
	if not record then
		detail:Hide()
		return 0
	end
	detail:Show()

	local title = mapLabel(record)
		.. SEPARATOR
		.. bracketLabel(record)
		.. SEPARATOR
		.. date("%d.%m.%Y %H:%M", record.time)
		.. SEPARATOR
		.. formatDuration(record.duration)
	if not played(record) then
		title = title .. SEPARATOR .. L["No game"]
	end
	detail.title:SetText(title)

	local y = -DETAIL_ROW_HEIGHT * 2
	local rowIndex = 0
	local players = record.players
	for side = 1, 2 do
		local header = detail.teamHeaders[side]
		header:SetPoint("TOPLEFT", 4, y)
		header:SetText(teamLabel(record, side))
		header:SetTextColor(resultColor(record, record.win == (side == 1)))
		y = y - DETAIL_ROW_HEIGHT

		for i = 1, #players do
			local player = players[i]
			if player.team == side then
				rowIndex = rowIndex + 1
				local row = detail.rows[rowIndex] or createDetailRow(detail, rowIndex)
				row:SetPoint("TOPLEFT", 0, y)
				fillDetailRow(row, player)
				row:Show()
				y = y - DETAIL_ROW_HEIGHT
			end
		end
	end
	for i = rowIndex + 1, #detail.rows do
		detail.rows[i]:Hide()
	end

	detail:SetHeight(-y)
	return -y + DETAIL_GAP
end

local function refreshList()
	local offset = FauxScrollFrame_GetOffset(frame.scroll)
	local rows = frame.rows
	for i = 1, LIST_ROWS do
		local row = rows[i]
		local record = filtered[i + offset]
		if record then
			fillListRow(row, record)
			row:Show()
		else
			row:Hide()
		end
	end
	FauxScrollFrame_Update(frame.scroll, #filtered, LIST_ROWS, LIST_ROW_HEIGHT)
	ns.SetShown(frame.empty, #filtered == 0)
end

local function refreshStats()
	local total, wins, change = 0, 0, 0
	for i = 1, #filtered do
		local record = filtered[i]
		if played(record) then
			total = total + 1
			if record.win then
				wins = wins + 1
			end
			change = change + record.team.change
		end
	end
	local losses = total - wins
	if total == 0 then
		frame.stats:SetText("")
		return
	end
	frame.stats:SetFormattedText(
		L["%d games   |cff4dff4d%d|r - |cffff4d4d%d|r   %d%%   %s"],
		total,
		wins,
		losses,
		wins / total * 100,
		formatChange(change)
	)
end

local function refreshFilters()
	local buttons = frame.filters
	for i = 1, #buttons do
		local button = buttons[i]
		if button.filter == filter then
			button:SetBackdropColor(1, 1, 1, 0.15)
			button.text:SetTextColor(1, 1, 1)
		else
			button:SetBackdropColor(0, 0, 0, 0.5)
			button.text:SetTextColor(0.7, 0.7, 0.7)
		end
	end
end

function refresh()
	if not frame or not frame:IsShown() then
		return
	end

	wipe(filtered)
	for i = 1, #history do
		local record = history[i]
		if filter == "all" or record.bracket == filter then
			filtered[#filtered + 1] = record
		end
	end
	if not selected or not ns.tContains(filtered, selected) then
		selected = filtered[1]
	end

	refreshFilters()
	refreshStats()
	refreshList()
	local detailHeight = refreshDetail()
	frame:SetHeight(frame.listBottom + detailHeight + PADDING)
end

local function onFilterClick(self)
	filter = self.filter
	selected = nil
	FauxScrollFrame_SetOffset(frame.scroll, 0)
	frame.scrollBar:SetValue(0)
	refresh()
end

local function createToolbarButton(parent, label)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(FILTER_WIDTH, FILTER_HEIGHT - 2)
	button:SetBackdrop(ns.CreateBackdrop(8))
	button:SetBackdropBorderColor(0.6, 0.6, 0.6)
	button:SetHighlightTexture(ns.Media.blank)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)

	button.text = button:CreateFontString(nil, "OVERLAY")
	ns.SetFont(button.text, 12)
	button.text:SetPoint("CENTER")
	button.text:SetText(label)
	return button
end

local function createFilterButton(parent, index, key, label)
	local button = createToolbarButton(parent, label)
	button.filter = key
	button:SetPoint("TOPLEFT", PADDING + (index - 1) * (FILTER_WIDTH + 4), -(PADDING + HEADER_HEIGHT))
	button:SetScript("OnClick", onFilterClick)
	return button
end

local function createFrame()
	frame = ns.CreateWindow(FRAME_NAME, { width = WIDTH, title = L["Arena history"] })
	Misc:AnchorToConfig(frame, "arenaHistory.point", "Arena history")
	frame:SetScript("OnShow", refresh)

	local filters = {}
	for i = 1, #FILTERS do
		local key = FILTERS[i][1]
		if key ~= "solo" or ns.IS_WOWCIRCLE then
			filters[#filters + 1] = createFilterButton(frame, #filters + 1, key, FILTERS[i][2])
		end
	end
	frame.filters = filters

	local stats = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(stats, 12)
	stats:SetPoint("LEFT", filters[#filters], "RIGHT", 12, 0)
	frame.stats = stats

	local clear = createToolbarButton(frame, L["Clear"])
	clear:SetPoint("TOPRIGHT", -PADDING, -(PADDING + HEADER_HEIGHT))
	clear:SetBackdropColor(0, 0, 0, 0.5)
	clear.text:SetTextColor(0.7, 0.7, 0.7)
	clear:SetScript("OnClick", function()
		StaticPopup_Show("FROSTATOMUI_ARENA_HISTORY_CLEAR")
	end)

	local listTop = PADDING + HEADER_HEIGHT + FILTER_HEIGHT + 6
	local list = CreateFrame("Frame", nil, frame)
	list:SetPoint("TOPLEFT", PADDING, -(listTop + DETAIL_ROW_HEIGHT))
	list:SetSize(CONTENT_WIDTH - SCROLLBAR_WIDTH, LIST_ROWS * LIST_ROW_HEIGHT)

	local listHeader = CreateFrame("Frame", nil, frame)
	listHeader:SetPoint("BOTTOMLEFT", list, "TOPLEFT")
	listHeader:SetSize(list:GetWidth(), DETAIL_ROW_HEIGHT)
	createHeaders(listHeader, LIST_COLUMNS, 0)

	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", list, "FauxScrollFrameTemplate")
	scroll:SetAllPoints()
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, LIST_ROW_HEIGHT, refreshList)
	end)
	frame.scroll = scroll
	frame.scrollBar = _G[FRAME_NAME .. "ScrollScrollBar"]

	local rows = {}
	for i = 1, LIST_ROWS do
		rows[i] = createListRow(list, i)
	end
	frame.rows = rows

	local empty = list:CreateFontString(nil, "OVERLAY")
	ns.SetFont(empty, 13)
	empty:SetTextColor(0.5, 0.5, 0.5)
	empty:SetPoint("CENTER")
	empty:SetText(L["No games recorded yet"])
	frame.empty = empty

	frame.listBottom = listTop + DETAIL_ROW_HEIGHT + LIST_ROWS * LIST_ROW_HEIGHT + DETAIL_GAP

	local detail = CreateFrame("Frame", nil, frame)
	detail:SetPoint("TOPLEFT", PADDING, -frame.listBottom)
	detail:SetWidth(CONTENT_WIDTH)
	detail.rows = {}
	frame.detail = detail

	local line = detail:CreateTexture(nil, "BACKGROUND")
	line:SetTexture(ns.Media.blank)
	line:SetVertexColor(1, 1, 1, 0.15)
	line:SetPoint("TOPLEFT", 0, DETAIL_GAP / 2)
	line:SetPoint("TOPRIGHT", 0, DETAIL_GAP / 2)
	line:SetHeight(1)

	detail.title = detail:CreateFontString(nil, "OVERLAY")
	ns.SetFont(detail.title, 12, "OUTLINE", true)
	detail.title:SetPoint("TOPLEFT", 4, 0)
	detail.title:SetHeight(DETAIL_ROW_HEIGHT)
	detail.title:SetJustifyV("MIDDLE")

	createHeaders(detail, DETAIL_COLUMNS, -DETAIL_ROW_HEIGHT)

	detail.teamHeaders = {}
	for side = 1, 2 do
		local header = detail:CreateFontString(nil, "OVERLAY")
		ns.SetFont(header, 12, "OUTLINE", true)
		header:SetHeight(DETAIL_ROW_HEIGHT)
		header:SetJustifyV("MIDDLE")
		detail.teamHeaders[side] = header
	end
end

StaticPopupDialogs.FROSTATOMUI_ARENA_HISTORY_CLEAR = {
	text = "Clear the whole arena history?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		wipe(history)
		selected = nil
		refresh()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

StaticPopupDialogs.FROSTATOMUI_ARENA_HISTORY_DELETE = {
	text = "Delete this game from the history?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, record)
		ns.tDeleteItem(history, record)
		if selected == record then
			selected = nil
		end
		refresh()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

ns.OnLocaleReady(function()
	StaticPopupDialogs.FROSTATOMUI_ARENA_HISTORY_CLEAR.text = L["Clear the whole arena history?"]
	StaticPopupDialogs.FROSTATOMUI_ARENA_HISTORY_DELETE.text = L["Delete this game from the history?"]
end)

Misc:WatchConfig("arenaHistory", function()
	for i = 1, #listCells do
		setListFont(listCells[i])
	end
	refresh()
end)

local function toggle()
	if not history then
		return
	end
	if not frame then
		createFrame()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

ns.ArenaHistory = {
	ReadScores = readScores,
	ReadTeam = readTeam,
	PlayerTeamOf = playerTeamOf,
	Toggle = toggle,
	GetCurrent = function()
		return current, currentTeam
	end,
}

SlashCmdList.FROSTATOMUI_ARENA_HISTORY = toggle
SLASH_FROSTATOMUI_ARENA_HISTORY1 = "/history"
SLASH_FROSTATOMUI_ARENA_HISTORY2 = "/ah"
