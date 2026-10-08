local _, ns = ...

local GetArenaTeamRosterInfo = GetArenaTeamRosterInfo
local GetBattlefieldScore = GetBattlefieldScore
local GetFriendInfo = GetFriendInfo
local GetGuildRosterInfo = GetGuildRosterInfo
local GetGuildRosterSelection = GetGuildRosterSelection
local GetNumArenaTeamMembers = GetNumArenaTeamMembers
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetNumFriends = GetNumFriends
local GetNumGuildMembers = GetNumGuildMembers
local GetNumWhoResults = GetNumWhoResults
local GetQuestDifficultyColor = GetQuestDifficultyColor
local GetWhoInfo = GetWhoInfo
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local SearchLFGGetResults = SearchLFGGetResults
local UnitClass = UnitClass
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FRIENDS_BUTTON_TYPE_WOW = FRIENDS_BUTTON_TYPE_WOW
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
local format, gsub = string.format, string.gsub
local min = math.min
local select = select

local ClassColor = ns.ClassColor
local ClassColorText = ns.ClassColorText

local ClassNames = ns:NewModule("ClassNames")

local LEVEL_TEMPLATE = gsub(gsub(FRIENDS_LEVEL_TEMPLATE, "%%d", "%%s"), "%$d", "$s")
local playerName = UnitName("player")

local classTokens = {}
for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
	classTokens[name] = token
end
for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
	classTokens[name] = token
end

local knownClasses = {}

local function settings(key)
	local db = ns.Config.classNames
	local active = db.enabled and db[key]
	return active, active and db.levels
end

local function levelColor(level)
	local color = GetQuestDifficultyColor(level)
	return color.r, color.g, color.b
end

local function levelText(level, colored)
	if not colored then
		return level
	end
	local r, g, b = levelColor(level)
	return format("|cff%02x%02x%02x%d|r", r * 255, g * 255, b * 255, level)
end

local function rows(count, prefix, fields)
	local list = {}
	for i = 1, count do
		local name = prefix .. i
		local row = { button = _G[name] }
		for key, suffix in pairs(fields) do
			row[key] = _G[name .. suffix]
		end
		list[i] = row
	end
	return list
end

local LIST_FIELDS = { name = "Name", level = "Level", class = "Class" }

local guildRows = rows(GUILDMEMBERS_TO_DISPLAY, "GuildFrameButton", LIST_FIELDS)
local statusRows = rows(GUILDMEMBERS_TO_DISPLAY, "GuildFrameGuildStatusButton", { name = "Name", online = "Online" })
local whoRows = rows(WHOS_TO_DISPLAY, "WhoFrameButton", LIST_FIELDS)
local channelRows = rows(MAX_CHANNEL_MEMBER_BUTTONS, "ChannelMemberButton", { name = "Name" })
local arenaRows = rows(MAX_ARENA_TEAM_MEMBERS, "PVPTeamDetailsButton", { name = "NameText", class = "ClassText" })
local scoreRows = rows(MAX_WORLDSTATE_SCORE_BUTTONS, "WorldStateScoreButton", { name = "NameText" })

local function updateFriends(scrollFrame)
	if scrollFrame ~= FriendsFrameFriendsScrollFrame then
		return
	end
	local active, levels = settings("friends")
	if not active then
		return
	end
	local buttons = scrollFrame.buttons
	for i = scrollFrame.topIndex > 1 and 2 or 1, scrollFrame.usedButtons do
		local button = buttons[i]
		if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
			local name, level, class, _, connected = GetFriendInfo(button.id)
			if connected and name and class then
				local info = format(LEVEL_TEMPLATE, levelText(level, levels), class)
				button.name:SetText(ClassColorText(classTokens[class], name) .. ", " .. info)
			end
		end
	end
end

local function updateGuild()
	local active, levels = settings("guild")
	if not active then
		return
	end
	local selected = GetGuildRosterSelection()
	if selected > 0 then
		local name, _, _, level, class, _, _, _, _, _, token = GetGuildRosterInfo(selected)
		if name then
			GuildMemberDetailName:SetText(ClassColorText(token, name))
			GuildMemberDetailLevel:SetFormattedText(LEVEL_TEMPLATE, levelText(level, levels), class)
		end
	end
	local playerStatus = FriendsFrame.playerStatusFrame
	local list = playerStatus and guildRows or statusRows
	for i = 1, #list do
		local row = list[i]
		local _, _, _, level, _, _, _, _, online, _, token = GetGuildRosterInfo(row.button.guildIndex)
		if online and token then
			local r, g, b = ClassColor(token)
			row.name:SetTextColor(r, g, b)
			if playerStatus then
				row.class:SetTextColor(r, g, b)
				if levels then
					row.level:SetTextColor(levelColor(level))
				end
			else
				row.online:SetTextColor(r, g, b)
			end
		end
	end
end

local function updateWho()
	local active, levels = settings("who")
	for i = 1, #whoRows do
		local row = whoRows[i]
		local _, _, level, _, _, _, token = GetWhoInfo(row.button.whoIndex)
		if active and token then
			local r, g, b = ClassColor(token)
			row.name:SetTextColor(r, g, b)
			row.class:SetTextColor(r, g, b)
		else
			row.name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		end
		if levels and level then
			row.level:SetTextColor(levelColor(level))
		else
			row.level:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	end
end

local function updateChannel()
	local active = settings("other")
	for i = 1, #channelRows do
		local row = channelRows[i]
		local name = row.button.name
		local token = active and name and (knownClasses[name] or select(2, UnitClass(name)))
		if token then
			row.name:SetTextColor(ClassColor(token))
		else
			row.name:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	end
end

local function updateBrowse(button, index)
	local active, levels = settings("other")
	if not active then
		return
	end
	local name, level, _, _, _, _, _, token = SearchLFGGetResults(index)
	if not token or name == playerName then
		return
	end
	local r, g, b = ClassColor(token)
	button.name:SetTextColor(r, g, b)
	button.class:SetTextColor(r, g, b)
	if levels then
		button.level:SetTextColor(levelColor(level))
	end
end

local function updateArenaTeam(id)
	if not settings("other") then
		return
	end
	for i = 1, min(GetNumArenaTeamMembers(id, 1), #arenaRows) do
		local _, _, _, class, online = GetArenaTeamRosterInfo(id, i)
		local token = online and classTokens[class]
		if token then
			local row = arenaRows[i]
			local r, g, b = ClassColor(token)
			row.name:SetTextColor(r, g, b)
			row.class:SetTextColor(r, g, b)
		end
	end
end

local function updateScore()
	if not settings("scoreboard") then
		return
	end
	local isArena = IsActiveBattlefieldArena()
	local offset = FauxScrollFrame_GetOffset(WorldStateScoreScrollFrame)
	for i = 1, min(GetNumBattlefieldScores() - offset, #scoreRows) do
		local name, _, _, _, _, faction, _, _, _, token = GetBattlefieldScore(offset + i)
		if faction and token and (isArena or name ~= playerName) then
			scoreRows[i].name:SetVertexColor(ClassColor(token))
		end
	end
end

local function rememberGuild()
	if not settings("other") then
		return
	end
	for i = 1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, _, _, _, token = GetGuildRosterInfo(i)
		if name and token then
			knownClasses[name] = token
		end
	end
end

local function rememberFriends()
	if not settings("other") then
		return
	end
	for i = 1, GetNumFriends() do
		local name, _, class = GetFriendInfo(i)
		local token = class and classTokens[class]
		if name and token then
			knownClasses[name] = token
		end
	end
end

local function rememberWho()
	if not settings("other") then
		return
	end
	for i = 1, GetNumWhoResults() do
		local name, _, _, _, _, _, token = GetWhoInfo(i)
		if name and token then
			knownClasses[name] = token
		end
	end
end

local function refresh()
	rememberGuild()
	rememberFriends()
	rememberWho()
	if FriendsListFrame:IsVisible() then
		FriendsList_Update()
	end
	if WhoFrame:IsVisible() then
		WhoList_Update()
	end
	if GuildFrame:IsVisible() then
		GuildStatus_Update()
	end
	if ChannelFrame:IsVisible() then
		ChannelRoster_Update()
	end
	if LFRBrowseFrame:IsVisible() then
		LFRBrowseFrameList_Update()
	end
	if PVPTeamDetails:IsVisible() then
		PVPTeamDetails_Update(PVPTeamDetails.team)
	end
	if WorldStateScoreFrame:IsVisible() then
		WorldStateScoreFrame_Update()
	end
end

hooksecurefunc("DynamicScrollFrame_Update", updateFriends)
hooksecurefunc("GuildStatus_Update", updateGuild)
hooksecurefunc("WhoList_Update", updateWho)
hooksecurefunc("ChannelRoster_Update", updateChannel)
hooksecurefunc("LFRBrowseFrameListButton_SetData", updateBrowse)
hooksecurefunc("PVPTeamDetails_Update", updateArenaTeam)
hooksecurefunc("WorldStateScoreFrame_Update", updateScore)

ClassNames:RegisterEvent("GUILD_ROSTER_UPDATE", rememberGuild)
ClassNames:RegisterEvent("FRIENDLIST_UPDATE", rememberFriends)
ClassNames:RegisterEvent("WHO_LIST_UPDATE", rememberWho)
ClassNames:WatchConfig("classNames", refresh, true)
