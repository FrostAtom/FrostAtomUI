local _, ns = ...

local L = ns.L

local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
local GetBattlefieldWinner = GetBattlefieldWinner
local GetBattlefieldInstanceRunTime = GetBattlefieldInstanceRunTime
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local GetBattlefieldArenaFaction = GetBattlefieldArenaFaction
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
local tinsert, tremove, tconcat, sort = table.insert, table.remove, table.concat, table.sort
local format, find, strtrim = string.format, string.find, strtrim

local Misc = ns:GetModule("Misc")
local UF = ns:GetModule("UnitFrames")
local Talents = ns:GetModule("Talents")

local FRAME_NAME = "FrostAtomUIArenaHistory"
local MAX_TEAM = 5
local WIDTH = 800
local INSET = ns.WINDOW_INSET
local INSET_PADDING = 4
local TOOLBAR_HEIGHT = 22
local SEARCH_WIDTH = 160
local SEARCH_GAP = 12
local SECTION_GAP = 8
local LIST_ROWS = 14
local LIST_ROW_HEIGHT = 18
local DETAIL_ROW_HEIGHT = 16
local COLUMN_HEADER_HEIGHT = 24
local BANNER_HEIGHT = 16
local ICON_SIZE = 16
local ICON_GAP = 1
local LIST_STRIP_ALPHA = 0.5
local UNKNOWN_NAME = UNKNOWNOBJECT
local ARENA_PREPARATION = GetSpellInfo(32727) -- Arena Preparation
local SEPARATOR = "  " .. GRAY_FONT_COLOR_CODE .. "-|r  "
local STRIP_TEXTURE = "Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight"
local STRIP_COLORS = {
	win = { 0.19, 0.57, 0.11 },
	loss = { 0.52, 0.075, 0.18 },
	left = { 0.6, 0.3, 0 },
	none = { 0.3, 0.3, 0.3 },
}

local CLASS_ICONS = UF.CLASS_ICONS
local ICON_TRIM = UF.ICON_TRIM
local classCoords = UF.classCoords
local specIcons = UF.specIcons

local FILTERS = { { "all", "All" }, { "2v2", "2v2" }, { "3v3", "3v3" }, { "solo", "Solo" } }
local BRACKET_LABELS = { solo = "Solo" }
local MAP_KEYS = {
	["Nagrand Arena"] = "nagrand",
	["Арена Награнда"] = "nagrand",
	["Blade's Edge Arena"] = "bladesEdge",
	["Арена Острогорья"] = "bladesEdge",
	["Ruins of Lordaeron"] = "lordaeron",
	["Руины Лордерона"] = "lordaeron",
	["Dalaran Sewers"] = "dalaran",
	["Dalaran Arena"] = "dalaran",
	["Стоки Даларана"] = "dalaran",
	["Арена Даларана"] = "dalaran",
	["The Ring of Valor"] = "ringOfValor",
	["Арена Доблести"] = "ringOfValor",
	["Круг Доблести"] = "ringOfValor",
	["Кольцо Доблести"] = "ringOfValor",
}
ns.ARENA_MAP_KEYS = MAP_KEYS
local MAP_LABELS = {
	nagrand = "Nagrand",
	bladesEdge = "Blade's Edge",
	lordaeron = "Lordaeron",
	dalaran = "Dalaran",
	ringOfValor = "Ring of Valor",
}

local ICONS_WIDTH = MAX_TEAM * (ICON_SIZE + ICON_GAP) + 8
local LIST_COLUMNS = {
	{ key = "date", title = "Date", width = 90 },
	{ key = "bracket", title = "Type", width = 42 },
	{ key = "map", title = "Map", width = 100 },
	{ key = "duration", title = "Time", width = 46 },
	{ key = "result", title = "Result", width = 72 },
	{ key = "mmr", title = "MMR", width = 46, font = "GameFontNormalSmall" },
	{ key = "team", title = "Team", width = ICONS_WIDTH, icons = 1 },
	{ key = "enemy", title = "Enemy", width = ICONS_WIDTH, icons = 2 },
	{ key = "names", title = "", width = 0 },
}
local DETAIL_COLUMNS = {
	{ key = "name", title = "Name", width = 0, font = "GameFontNormal" },
	{ key = "race", title = "Race", width = 120 },
	{ key = "kb", title = "Kills", width = 70, right = true, font = "GameFontNormalSmall" },
	{ key = "deaths", title = "Deaths", width = 80, right = true, font = "GameFontNormalSmall" },
	{ key = "damage", title = "Damage", width = 100, right = true, font = "GameFontNormalSmall" },
	{ key = "healing", title = "Healing", width = 100, right = true, font = "GameFontNormalSmall" },
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
	local fixed = 0
	for i = 1, #columns do
		fixed = fixed + columns[i].width
	end
	local x = 0
	for i = 1, #columns do
		local column = columns[i]
		column.x = x
		if column.width == 0 then
			column.width = totalWidth - fixed
		end
		x = x + column.width
	end
end

local CONTENT_WIDTH = WIDTH - INSET.left - INSET.right
local LIST_WIDTH = CONTENT_WIDTH - INSET_PADDING * 2 - ns.SCROLLBAR_TRACK_WIDTH
local DETAIL_WIDTH = CONTENT_WIDTH - INSET_PADDING * 2
layoutColumns(LIST_COLUMNS, LIST_WIDTH)
layoutColumns(DETAIL_COLUMNS, DETAIL_WIDTH)

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
local ended = false
local arenaMap
local arenaFaction

local frame
local filter = "all"
local query = ""
local filtered = {}
local selected

local lowered = setmetatable({}, {
	__index = function(cache, text)
		local value = ns.Lower(text)
		cache[text] = value
		return value
	end,
})

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
	local guid = UnitGUID(unit)
	if not guid or UnitExists(unit) and not UnitIsPlayer(unit) then
		return
	end
	local name = stripRealm(UnitName(unit))
	if not name or name == UNKNOWN_NAME then
		return
	end
	local entry = addPlayer(name, side)
	entry.guid = guid
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
	if IsActiveBattlefieldArena() then
		local faction = GetBattlefieldArenaFaction()
		if faction == 0 or faction == 1 then
			arenaFaction = faction
		end
	end
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
	if IsActiveBattlefieldArena() then
		local faction = GetBattlefieldArenaFaction()
		if faction == 0 or faction == 1 then
			return faction
		end
	end
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

local function insertRecord(record)
	tinsert(history, 1, record)
	while #history > ns.Config.arenaHistory.maxGames do
		tremove(history)
	end
end

local function newPlayer(entry)
	entry.spec = entry.guid and Talents:GetSpec(entry.guid) or entry.spec
	return { name = entry.name, class = entry.class, race = entry.race, spec = entry.spec, team = entry.team }
end

local rosterNames = {}

local function rosterKey(players, side)
	wipe(rosterNames)
	for i = 1, #players do
		local player = players[i]
		if player.team == side and player.name ~= UNKNOWN_NAME then
			rosterNames[#rosterNames + 1] = player.name
		end
	end
	sort(rosterNames)
	return tconcat(rosterNames, ",")
end

local function knownTeamName(players, side)
	local key = rosterKey(players, side)
	if key == "" then
		return
	end
	for i = 1, #history do
		local record = history[i]
		local team = side == 1 and record.team or record.enemy
		local name = team and team.name
		if name and name ~= "" and record.players and rosterKey(record.players, side) == key then
			return name
		end
	end
end

local function recordLeave()
	if not inArena or current or ended or not startTime or not history or not ns.Config.arenaHistory.enabled then
		return
	end
	local players, counts = {}, { 0, 0 }
	for i = 1, #sightings do
		local player = newPlayer(sightings[i])
		counts[player.team] = counts[player.team] + 1
		players[#players + 1] = player
	end
	if #players == 0 then
		return
	end
	local function team(teamIndex)
		return { name = teamIndex and teamNames[teamIndex], lost = 0, gained = 0, change = 0, mmr = 0 }
	end
	local record = {
		time = time(),
		left = true,
		map = arenaMap,
		mapKey = MAP_KEYS[arenaMap],
		duration = time() - startTime,
		win = false,
		team = team(arenaFaction),
		enemy = team(arenaFaction and 1 - arenaFaction),
		players = players,
	}
	record.bracket = bracketOf(record.team.name, max(counts[1], counts[2]))
	if record.bracket ~= "solo" then
		record.team.name = record.team.name or knownTeamName(players, 1)
		record.enemy.name = record.enemy.name or knownTeamName(players, 2)
	end
	insertRecord(record)
	refresh()
end

local function snapshot()
	local winner = GetBattlefieldWinner()
	if winner then
		ended = true
	end
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
		insertRecord(record)
	end
	record.map = GetRealZoneText()
	record.mapKey = MAP_KEYS[record.map]
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
		if not entry.scored then
			for j = 1, #unknowns do
				if unknowns[j].team == entry.team then
					mergeScore(entry, tremove(unknowns, j))
					break
				end
			end
		end
		counts[entry.team] = counts[entry.team] + 1
		local player = newPlayer(entry)
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
	recordLeave()
	inArena = select(2, IsInInstance()) == "arena"
	current = nil
	currentTeam = nil
	preparing = inArena and UnitBuff("player", ARENA_PREPARATION) ~= nil
	startTime = nil
	ended = false
	arenaMap = inArena and GetRealZoneText() or nil
	arenaFaction = nil
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

Misc:RegisterUnitEvent("UNIT_AURA", "player", function()
	if not inArena or startTime then
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
	local config = ns.Config.arenaHistory
	if record.left then
		return unpack(win and config.winColor or config.leftColor)
	end
	if not played(record) then
		return GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b
	end
	return unpack(win and config.winColor or config.lossColor)
end

local function stripColor(record, win)
	if record.left then
		return win and STRIP_COLORS.win or STRIP_COLORS.left
	end
	if not played(record) then
		return STRIP_COLORS.none
	end
	return win and STRIP_COLORS.win or STRIP_COLORS.loss
end

local function formatDuration(seconds)
	return format("%d:%02d", seconds / 60, seconds % 60)
end

local function formatChange(change)
	if change > 0 then
		return format("%s+%d|r", GREEN_FONT_COLOR_CODE, change)
	elseif change < 0 then
		return format("%s%d|r", RED_FONT_COLOR_CODE, change)
	end
	return GRAY_FONT_COLOR_CODE .. "0|r"
end

local function bracketLabel(record)
	return BRACKET_LABELS[record.bracket] or record.bracket
end

local function mapLabel(record)
	local key = record.mapKey or MAP_KEYS[record.map]
	return key and MAP_LABELS[key] or record.map or UNKNOWN_NAME
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
	return format("%s  %s%d|r  %s", name, HIGHLIGHT_FONT_COLOR_CODE, team.mmr, formatChange(team.change))
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

local function createCells(row, columns, height)
	local cells = {}
	for i = 1, #columns do
		local column = columns[i]
		if not column.icons then
			local cell = row:CreateFontString(nil, "OVERLAY", column.font or "GameFontHighlightSmall")
			cell:SetPoint("LEFT", column.x + 4, 0)
			cell:SetSize(column.width - 8, height)
			cell:SetJustifyH(column.right and "RIGHT" or "LEFT")
			cell:SetJustifyV("MIDDLE")
			cells[column.key] = cell
		end
	end
	row.cells = cells
end

local function createColumnHeaders(parent, columns, prefix)
	local headers = {}
	for i = 1, #columns do
		local column = columns[i]
		local overlap = i == 1 and 0 or 2
		local header = CreateFrame("Button", prefix .. i, parent, "WhoFrameColumnHeaderTemplate")
		header:SetPoint("TOPLEFT", column.x - overlap, 0)
		WhoFrameColumn_SetWidth(header, column.width + overlap)
		header:SetText(column.title)
		header:SetScript("OnClick", nil)
		header:EnableMouse(false)
		local text = header:GetFontString()
		text:ClearAllPoints()
		if column.right then
			text:SetPoint("RIGHT", -4, 0)
		else
			text:SetPoint("LEFT", overlap + 4, 0)
		end
		headers[i] = header
	end
	return headers
end

local function setStripColor(strip, color, alpha)
	for i = 1, 2 do
		strip[i]:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	end
end

local function createStrip(parent)
	local left = parent:CreateTexture(nil, "BACKGROUND")
	left:SetTexture(STRIP_TEXTURE)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(256)

	local right = parent:CreateTexture(nil, "BACKGROUND")
	right:SetTexture(STRIP_TEXTURE)
	right:SetTexCoord(1, 0, 0, 1)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	return { left, right }
end

local function setStripShown(strip, shown)
	ns.SetShown(strip[1], shown)
	ns.SetShown(strip[2], shown)
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
	if record.left then
		cells.result:SetText(L["Left game"])
		cells.mmr:SetText("")
	elseif played(record) then
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
	if record.left or played(record) then
		setStripColor(row.strip, stripColor(record, record.win), LIST_STRIP_ALPHA)
		setStripShown(row.strip, true)
	else
		setStripShown(row.strip, false)
	end
	if record == selected then
		row:LockHighlight()
	else
		row:UnlockHighlight()
	end
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
	GameTooltip:AddLine(L["Right-click to delete"], GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	GameTooltip:Show()
end

local function onRowClick(self, button)
	if button == "RightButton" then
		StaticPopup_Show("FROSTATOMUI_ARENA_HISTORY_DELETE", nil, nil, self.record)
	else
		PlaySound("igMainMenuOptionCheckBoxOn")
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
	local highlight = ns.AddHighlight(row)
	highlight:ClearAllPoints()
	highlight:SetPoint("TOPLEFT", 0, -1)
	highlight:SetPoint("BOTTOMRIGHT", 0, 1)
	row.strip = createStrip(row)

	createCells(row, LIST_COLUMNS, LIST_ROW_HEIGHT)
	row.icons = { createIcons(row, LIST_COLUMNS[7]), createIcons(row, LIST_COLUMNS[8]) }

	row:SetScript("OnEnter", onRowEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row:SetScript("OnClick", onRowClick)
	return row
end

local function createDetailRow(detail, index)
	local row = CreateFrame("Frame", nil, detail.content)
	row:SetSize(DETAIL_WIDTH, DETAIL_ROW_HEIGHT)
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
	cells.kb:SetText(player.kb or "")
	cells.deaths:SetText(player.deaths or "")
	cells.damage:SetText(player.damage and ns.FormatValue(player.damage) or "")
	cells.healing:SetText(player.healing and ns.FormatValue(player.healing) or "")
end

local function refreshDetail()
	local detail = frame.detail
	local record = selected
	if not record then
		detail.content:Hide()
		return
	end
	detail.content:Show()

	local title = mapLabel(record)
		.. SEPARATOR
		.. bracketLabel(record)
		.. SEPARATOR
		.. date("%d.%m.%Y %H:%M", record.time)
		.. SEPARATOR
		.. formatDuration(record.duration)
	if record.left then
		title = title .. SEPARATOR .. L["Left the arena"]
	elseif not played(record) then
		title = title .. SEPARATOR .. L["No game"]
	end
	local banner = detail.banner
	banner.text:SetText(title)
	banner.text:SetTextColor(resultColor(record, record.win))
	setStripColor(banner.strip, stripColor(record, record.win))

	local y = -(INSET_PADDING + BANNER_HEIGHT + INSET_PADDING + COLUMN_HEADER_HEIGHT)
	local rowIndex = 0
	local players = record.players
	for side = 1, 2 do
		local win = record.win == (side == 1)
		local header = detail.teamHeaders[side]
		header:SetPoint("TOPLEFT", INSET_PADDING, y)
		header.text:SetText(teamLabel(record, side))
		header.text:SetTextColor(resultColor(record, win))
		setStripColor(header.strip, stripColor(record, win))
		y = y - DETAIL_ROW_HEIGHT

		for i = 1, #players do
			local player = players[i]
			if player.team == side then
				rowIndex = rowIndex + 1
				local row = detail.rows[rowIndex] or createDetailRow(detail, rowIndex)
				row:SetPoint("TOPLEFT", INSET_PADDING, y)
				fillDetailRow(row, player)
				row:Show()
				y = y - DETAIL_ROW_HEIGHT
			end
		end
	end
	for i = rowIndex + 1, #detail.rows do
		detail.rows[i]:Hide()
	end
end

local function createTeamHeader(parent)
	local header = CreateFrame("Frame", nil, parent)
	header:SetSize(DETAIL_WIDTH, DETAIL_ROW_HEIGHT)
	header.strip = createStrip(header)
	header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.text:SetPoint("LEFT", 4, 0)
	return header
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
	frame.empty:SetText(#history == 0 and L["No games recorded yet"] or L["Nothing found"])
	ns.SetShown(frame.empty, #filtered == 0)
end

local function refreshStats()
	local total, wins, change, left = 0, 0, 0, 0
	for i = 1, #filtered do
		local record = filtered[i]
		if record.left then
			left = left + 1
		elseif played(record) then
			total = total + 1
			if record.win then
				wins = wins + 1
			end
			change = change + record.team.change
		end
	end
	local losses = total - wins
	local leftText = ""
	if left > 0 then
		local r, g, b = unpack(ns.Config.arenaHistory.leftColor)
		leftText = format("   |cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, format(L["%d left"], left))
	end
	if total == 0 then
		frame.stats:SetText(leftText:sub(4))
		return
	end
	frame.stats:SetFormattedText(
		"%s   %s%d|r - %s%d|r   %d%%   %s%s",
		format(L["%d games"], total),
		GREEN_FONT_COLOR_CODE,
		wins,
		RED_FONT_COLOR_CODE,
		losses,
		wins / total * 100,
		formatChange(change),
		leftText
	)
end

local function refreshFilters()
	local filters = frame.filters
	for i = 1, #filters do
		if filters[i] == filter then
			ns.SelectTab(frame, i)
			return
		end
	end
end

local function contains(text, needle)
	return text ~= nil and find(lowered[text], needle, 1, true) ~= nil
end

local function matchesQuery(record)
	if query == "" or contains(record.team.name, query) or contains(record.enemy.name, query) then
		return true
	end
	local players = record.players
	for i = 1, #players do
		if contains(players[i].name, query) then
			return true
		end
	end
	return false
end

function refresh()
	if not frame or not frame:IsShown() then
		return
	end

	wipe(filtered)
	for i = 1, #history do
		local record = history[i]
		if (filter == "all" or record.bracket == filter) and matchesQuery(record) then
			filtered[#filtered + 1] = record
		end
	end
	if not selected or not ns.tContains(filtered, selected) then
		selected = filtered[1]
	end

	refreshFilters()
	refreshStats()
	refreshList()
	refreshDetail()
end

local function resetList()
	selected = nil
	FauxScrollFrame_SetOffset(frame.scroll, 0)
	frame.scrollBar:SetValue(0)
	refresh()
end

local function onFilterSelect(index)
	filter = frame.filters[index]
	resetList()
end

local function onSearchChanged(box)
	local text = ns.Lower(strtrim(box:GetText()))
	if text ~= query then
		query = text
		resetList()
	end
end

local function onSearchEscape(box)
	box:SetText("")
	box:ClearFocus()
end

local function createFrame()
	frame =
		ns.CreateWindow(FRAME_NAME, { width = WIDTH, title = L["Arena history"], background = "dark", movable = false })
	frame:SetPoint("CENTER")
	frame:SetScript("OnShow", function()
		PlaySound("igCharacterInfoOpen")
		refresh()
	end)
	frame:SetScript("OnHide", function()
		PlaySound("igCharacterInfoClose")
		frame.search:ClearFocus()
	end)

	local filters, labels = {}, {}
	for i = 1, #FILTERS do
		local key = FILTERS[i][1]
		if key ~= "solo" or ns.IS_WOWCIRCLE then
			filters[#filters + 1] = key
			labels[#labels + 1] = FILTERS[i][2]
		end
	end
	frame.filters = filters
	ns.CreateTabs(frame, labels, { style = "bottom", onSelect = onFilterSelect })

	local clear = ns.CreateButton(frame, L["Clear"], 80, TOOLBAR_HEIGHT)
	clear:SetPoint("TOPRIGHT", -INSET.right, -INSET.top)
	clear:SetScript("OnClick", function()
		StaticPopup_Show("FROSTATOMUI_ARENA_HISTORY_CLEAR")
	end)

	local search = ns.CreateEditBox(frame, SEARCH_WIDTH, 20, FRAME_NAME .. "Search", L["Team or player"])
	search:SetPoint("RIGHT", clear, "LEFT", -SEARCH_GAP, 0)
	search.placeholder:SetFontObject(GameFontDisableSmall)
	search:HookScript("OnTextChanged", onSearchChanged)
	search:SetScript("OnEscapePressed", onSearchEscape)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	frame.search = search

	local stats = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	stats:SetPoint("LEFT", frame, "TOPLEFT", INSET.left + INSET_PADDING, -(INSET.top + TOOLBAR_HEIGHT / 2))
	frame.stats = stats

	local listTop = INSET.top + TOOLBAR_HEIGHT + SECTION_GAP
	local listHeight = LIST_ROWS * LIST_ROW_HEIGHT
	local listInset = ns.CreateInset(frame, "box")
	listInset:SetPoint("TOPLEFT", INSET.left, -listTop)
	listInset:SetSize(CONTENT_WIDTH, INSET_PADDING * 2 + COLUMN_HEADER_HEIGHT + listHeight)

	local listHeader = CreateFrame("Frame", nil, listInset)
	listHeader:SetPoint("TOPLEFT", INSET_PADDING, -INSET_PADDING)
	listHeader:SetSize(LIST_WIDTH, COLUMN_HEADER_HEIGHT)
	createColumnHeaders(listHeader, LIST_COLUMNS, FRAME_NAME .. "ListHeader")

	local list = CreateFrame("Frame", nil, listInset)
	list:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT")
	list:SetSize(LIST_WIDTH, listHeight)

	local scroll = ns.CreateFauxScrollFrame(list, FRAME_NAME .. "Scroll")
	scroll:SetAllPoints()
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, LIST_ROW_HEIGHT, refreshList)
	end)
	local scrollBar = scroll.scrollBar
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, -16)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 16)
	ns.SkinScrollBar(scroll)
	frame.scroll = scroll
	frame.scrollBar = scrollBar

	local rows = {}
	for i = 1, LIST_ROWS do
		rows[i] = createListRow(list, i)
	end
	frame.rows = rows

	local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	empty:SetPoint("CENTER")
	empty:SetText(L["No games recorded yet"])
	frame.empty = empty

	local detailHeight = INSET_PADDING * 3
		+ BANNER_HEIGHT
		+ COLUMN_HEADER_HEIGHT
		+ (MAX_TEAM + 1) * 2 * DETAIL_ROW_HEIGHT
	local detail = ns.CreateInset(frame, "box")
	detail:SetPoint("TOPLEFT", listInset, "BOTTOMLEFT", 0, -SECTION_GAP)
	detail:SetSize(CONTENT_WIDTH, detailHeight)
	detail.rows = {}
	frame.detail = detail
	frame:SetHeight(listTop + listInset:GetHeight() + SECTION_GAP + detailHeight + INSET.bottom)

	local content = CreateFrame("Frame", nil, detail)
	content:SetAllPoints()
	detail.content = content

	local banner = CreateFrame("Frame", nil, content)
	banner:SetPoint("TOPLEFT", INSET_PADDING, -INSET_PADDING)
	banner:SetSize(DETAIL_WIDTH, BANNER_HEIGHT)
	banner.strip = createStrip(banner)
	banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	banner.text:SetPoint("CENTER")
	detail.banner = banner

	local detailHeader = CreateFrame("Frame", nil, content)
	detailHeader:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -INSET_PADDING)
	detailHeader:SetSize(DETAIL_WIDTH, COLUMN_HEADER_HEIGHT)
	createColumnHeaders(detailHeader, DETAIL_COLUMNS, FRAME_NAME .. "DetailHeader")

	detail.teamHeaders = { createTeamHeader(content), createTeamHeader(content) }
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
	preferredIndex = 3,
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
	preferredIndex = 3,
}

ns.OnLocaleReady(function()
	StaticPopupDialogs.FROSTATOMUI_ARENA_HISTORY_CLEAR.text = L["Clear the whole arena history?"]
	StaticPopupDialogs.FROSTATOMUI_ARENA_HISTORY_DELETE.text = L["Delete this game from the history?"]
end)

Misc:WatchConfig("arenaHistory", refresh)

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
	CreateStrip = createStrip,
	SetStripColor = setStripColor,
	GetCurrent = function()
		return current, currentTeam
	end,
}

SlashCmdList.FROSTATOMUI_ARENA_HISTORY = toggle
SLASH_FROSTATOMUI_ARENA_HISTORY1 = "/history"
SLASH_FROSTATOMUI_ARENA_HISTORY2 = "/ah"

Misc:OnInitialize(function()
	local button = ns.CreateButton(PVPFrame, L["Arena history"], 120, 22, FRAME_NAME .. "Button")
	ns.FitButton(button, 20, 120)
	button:SetPoint("TOPRIGHT", PVPFrame, "BOTTOMRIGHT", -38, 77)
	button:SetScript("OnClick", toggle)
end)
