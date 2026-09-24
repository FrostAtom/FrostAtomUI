local _, ns = ...

local SendChatMessage = SendChatMessage
local UnitName = UnitName
local UnitExists = UnitExists
local UnitGUID = UnitGUID

local Misc = ns:GetModule("Misc")

if ns.PLAYER_CLASS == "PALADIN" then
	local UnitInRaid = UnitInRaid
	local IsPartyLeader = IsPartyLeader
	local UnitBuff = UnitBuff

	local AURA_MASTERY = GetSpellInfo(31821)
	local CONCENTRATION_AURA = GetSpellInfo(19746)

	local function groupChannel()
		local inRaid = UnitInRaid("player")
		if inRaid and IsPartyLeader() then
			return "RAID_WARNING"
		elseif inRaid or UnitExists("party1") then
			return "PARTY"
		end
	end

	Misc:RegisterEvent("COMBAT_TEXT_UPDATE", function(_, messageType, spellName)
		local config = ns.Config.announce
		if
			messageType ~= "SPELL_AURA_START"
			or spellName ~= AURA_MASTERY
			or not (config.enabled and config.auraMastery)
		then
			return
		end
		if not UnitBuff("player", CONCENTRATION_AURA) then
			return
		end

		local channel = groupChannel()
		local message = config.auraMasteryMessage
		if channel and message ~= "" then
			SendChatMessage(message, channel)
			SendChatMessage(message, channel)
		end
	end)
end

local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
local GetBattlefieldWinner = GetBattlefieldWinner
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local GetBattlefieldArenaFaction = GetBattlefieldArenaFaction
local IsInInstance = IsInInstance
local GetNumPartyMembers = GetNumPartyMembers
local tconcat = table.concat
local format = string.format

local UNKNOWN_NAME = UNKNOWNOBJECT
local MAX_ARENA_OPPONENTS = 5

local ourNames, enemyNames = {}, {}
local ourSeen, enemySeen = {}, {}
local inArena = false

local function addName(list, seen, name)
	if not name or name == UNKNOWN_NAME or seen[name] then
		return
	end
	seen[name] = true
	list[#list + 1] = name
end

local function collectParty()
	addName(ourNames, ourSeen, UnitName("player"))
	for i = 1, GetNumPartyMembers() do
		addName(ourNames, ourSeen, UnitName("party" .. i))
	end
end

local function collectArenaUnit(unit)
	if UnitGUID(unit) then
		addName(enemyNames, enemySeen, UnitName(unit))
	end
end

local function collectArenaUnits()
	for i = 1, MAX_ARENA_OPPONENTS do
		collectArenaUnit("arena" .. i)
	end
end

local function scoreEntry(i)
	local name, _, _, _, _, teamIndex = GetBattlefieldScore(i)
	return name:match("^([^%-]+)") or name, teamIndex
end

local function collectScores()
	local playerTeam = GetBattlefieldArenaFaction()
	local numScores = GetNumBattlefieldScores()
	if playerTeam ~= 0 and playerTeam ~= 1 then
		playerTeam = nil
		local playerName = UnitName("player")
		for i = 1, numScores do
			local name, teamIndex = scoreEntry(i)
			if name == playerName then
				playerTeam = teamIndex
				break
			end
		end
	end
	for i = 1, numScores do
		local name, teamIndex = scoreEntry(i)
		if teamIndex == playerTeam then
			addName(ourNames, ourSeen, name)
		else
			addName(enemyNames, enemySeen, name)
		end
	end
	return playerTeam
end

local function teamSummary(teamIndex, playerTeam)
	local name, lost, gained, rating = GetBattlefieldTeamInfo(teamIndex)

	if name:find("^Solo Team [1-2]$") then
		local names = playerTeam == teamIndex and ourNames or enemyNames
		name = #names > 0 and tconcat(names, ", ") or name
	end

	local change = gained > 0 and ("+" .. gained) or lost > 0 and ("-" .. lost) or "0"
	return format('"%s"(%d) %s', name, rating, change)
end

local ratingReported = false

Misc:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	ratingReported = false
	inArena = select(2, IsInInstance()) == "arena"
	if inArena then
		wipe(ourNames)
		wipe(enemyNames)
		wipe(ourSeen)
		wipe(enemySeen)
		collectParty()
		collectArenaUnits()
	end
end)

Misc:RegisterEvent("PARTY_MEMBERS_CHANGED", function()
	if inArena then
		collectParty()
	end
end)

Misc:RegisterEvent("ARENA_OPPONENT_UPDATE", function(_, unit)
	if inArena and unit:find("^arena%d$") then
		collectArenaUnit(unit)
	end
end)

Misc:RegisterEvent("UNIT_NAME_UPDATE", function(_, unit)
	if inArena and unit:find("^arena%d$") then
		collectArenaUnit(unit)
	end
end)

Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function()
	if ratingReported or not (IsActiveBattlefieldArena() and GetBattlefieldWinner()) then
		return
	end
	ratingReported = true

	local config = ns.Config.announce
	if not (config.enabled and config.arenaResult) then
		return
	end

	local playerTeam = collectScores() or 0
	local message = teamSummary(playerTeam, playerTeam) .. " VS " .. teamSummary(1 - playerTeam, playerTeam)
	if config.arenaResultToParty and UnitExists("party1") then
		SendChatMessage(message, "PARTY")
	else
		ns.Print("%s", message)
	end
end)
