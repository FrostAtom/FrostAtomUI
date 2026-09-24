local _, ns = ...

local CanInspect = CanInspect
local CheckInteractDistance = CheckInteractDistance
local InCombatLockdown = InCombatLockdown
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitIsVisible = UnitIsVisible
local UnitIsConnected = UnitIsConnected
local UnitCanAttack = UnitCanAttack
local UnitLevel = UnitLevel
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetInspectArenaTeamData = GetInspectArenaTeamData
local RequestInspectHonorData = RequestInspectHonorData
local GetSpellInfo = GetSpellInfo
local GetTalentInfo = GetTalentInfo
local GetNumTalents = GetNumTalents
local IsInInstance = IsInInstance
local GetTime = GetTime

local TICK = 0.1
local SEND_INTERVAL = 1.5
local URGENT_DELAY = 0.2
local MANUAL_BACKOFF = 2
local TIMEOUT = 5
local MAX_RETRIES = 4
local GEAR_DELAY = 0.3
local GEAR_RETRIES = 10
local LAST_SLOT = 19
local MIN_LEVEL = 10
local CACHE_TIME = 900
local ARENA_REFRESH_INTERVAL = 12
local ARENA_REFRESH_COUNT = 6
local HONOR_WAIT = 1
local MAX_ARENA_TEAMS = 3
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }
local WATCHED_UNITS = { "party1", "party2", "party3", "party4", "target", "focus", "mouseover" }
local LOOKUP_UNITS = {}
for i = 1, #WATCHED_UNITS do
	LOOKUP_UNITS[i] = WATCHED_UNITS[i]
	LOOKUP_UNITS[#WATCHED_UNITS + i] = WATCHED_UNITS[i] .. "target"
end

local TREE1_TALENTS = {
	DEATHKNIGHT = 48979, -- Butchery
	DRUID = 16814, -- Starlight Wrath
	HUNTER = 19552, -- Improved Aspect of the Hawk
	MAGE = 11210, -- Arcane Subtlety
	PALADIN = 20205, -- Spiritual Focus
	PRIEST = 14522, -- Unbreakable Will
	ROGUE = 14162, -- Improved Eviscerate
	SHAMAN = 16039, -- Convection
	WARLOCK = 18827, -- Improved Curse of Agony
	WARRIOR = 12282, -- Improved Heroic Strike
}

ns.INSPECT_TALENTS_READY = "FrostAtomUI_INSPECT_TALENTS_READY"
ns.INSPECT_GEAR_READY = "FrostAtomUI_INSPECT_GEAR_READY"
ns.INSPECT_TEAMS_READY = "FrostAtomUI_INSPECT_TEAMS_READY"

local Inspect = ns:NewModule("Inspect")

local pending = {}
local retries = {}
local inspected = {}
local request = {}
local urgentGuid, urgentTime
local gearGuid, gearUnit, gearTries, gearAt
local loadedGuid
local teamsWanted, teamsGuid, teamsAt, teamsReplied
local lastSend, manualTime = -SEND_INTERVAL, -MANUAL_BACKOFF
local arenaRefreshes, nextArenaRefresh = 0, 0

local queue = CreateFrame("Frame")
queue:Hide()

function Inspect:UnitByGUID(guid, hint)
	if hint and UnitGUID(hint) == guid then
		return hint
	end
	for i = 1, #LOOKUP_UNITS do
		local unit = LOOKUP_UNITS[i]
		if UnitGUID(unit) == guid then
			return unit
		end
	end
end

local function isInspectable(unit)
	return UnitExists(unit)
		and UnitIsPlayer(unit)
		and not UnitIsUnit(unit, "player")
		and UnitLevel(unit) >= MIN_LEVEL
		and not UnitCanAttack("player", unit)
end

local function isReachable(unit)
	return UnitIsVisible(unit) and UnitIsConnected(unit) and CanInspect(unit) and CheckInteractDistance(unit, 1)
end

function Inspect:Request(unit, maxAge, urgent)
	if not isInspectable(unit) then
		return
	end
	local guid = UnitGUID(unit)
	local now = GetTime()
	if maxAge and inspected[guid] and now - inspected[guid] < maxAge then
		return
	end
	if request.guid == guid or gearGuid == guid then
		return
	end
	pending[guid] = true
	if urgent then
		urgentGuid, urgentTime = guid, now
	end
	queue:Show()
end

function Inspect:WantTeams()
	teamsWanted = true
end

function Inspect:IsLoaded(guid)
	return guid ~= nil and guid == loadedGuid
end

function Inspect:GetTime(guid)
	return inspected[guid]
end

local function requestUnits(units, maxAge)
	for i = 1, #units do
		Inspect:Request(units[i], maxAge)
	end
end

local function fail(guid)
	local count = (retries[guid] or 0) + 1
	if count > MAX_RETRIES then
		retries[guid] = nil
		pending[guid] = nil
	else
		retries[guid] = count
		pending[guid] = true
		queue:Show()
	end
end

local function talentsMatchClass(class)
	local id = class and TREE1_TALENTS[class]
	local expected = id and GetSpellInfo(id)
	if not expected then
		return true
	end
	for i = 1, GetNumTalents(1, true) do
		if GetTalentInfo(1, i, true) == expected then
			return true
		end
	end
	return false
end

local function isGearComplete(unit)
	for slot = 1, LAST_SLOT do
		if GetInventoryItemID(unit, slot) and not GetInventoryItemLink(unit, slot) then
			return false
		end
	end
	return true
end

local function checkGear(now)
	local unit = Inspect:UnitByGUID(gearGuid, gearUnit)
	if not unit then
		gearGuid = nil
		return
	end
	gearUnit = unit
	if gearTries < GEAR_RETRIES and not isGearComplete(unit) then
		gearTries = gearTries + 1
		gearAt = now + GEAR_DELAY
		return
	end
	local guid = gearGuid
	gearGuid = nil
	loadedGuid = guid
	ns:Fire(ns.INSPECT_GEAR_READY, guid, unit)
end

local function readTeams()
	local guid = teamsGuid
	teamsGuid = nil
	if not teamsReplied then
		return
	end
	local teams = {}
	for i = 1, MAX_ARENA_TEAMS do
		local name, size, rating, _, _, _, personal = GetInspectArenaTeamData(i)
		if name then
			teams[#teams + 1] = { name = name, size = size, rating = rating, personal = personal }
		end
	end
	ns:Fire(ns.INSPECT_TEAMS_READY, guid, teams)
end

local function send(now)
	if InCombatLockdown() or (InspectFrame and InspectFrame:IsShown()) then
		return
	end
	if now < lastSend + SEND_INTERVAL or now < manualTime + MANUAL_BACKOFF then
		return
	end
	if urgentGuid then
		if now < urgentTime + URGENT_DELAY then
			return
		end
		local unit = Inspect:UnitByGUID(urgentGuid)
		urgentGuid = nil
		if unit and isReachable(unit) then
			NotifyInspect(unit)
			return
		end
	end
	for guid in pairs(pending) do
		local unit = Inspect:UnitByGUID(guid)
		if not unit then
			pending[guid] = nil
			retries[guid] = nil
		elseif isReachable(unit) then
			NotifyInspect(unit)
			return
		end
	end
end

queue:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < TICK then
		return
	end
	self.elapsed = 0
	local now = GetTime()

	if request.guid and now - request.time > TIMEOUT then
		local guid = request.guid
		request.guid = nil
		fail(guid)
	end

	if arenaRefreshes > 0 and now >= nextArenaRefresh then
		arenaRefreshes = arenaRefreshes - 1
		nextArenaRefresh = now + ARENA_REFRESH_INTERVAL
		requestUnits(PARTY_UNITS)
	end

	if gearGuid and now >= gearAt then
		checkGear(now)
	end

	if teamsGuid and now >= teamsAt then
		readTeams()
	end

	if not request.guid and not gearGuid and not teamsGuid then
		send(now)
	end

	if
		not request.guid
		and not gearGuid
		and not teamsGuid
		and not urgentGuid
		and not next(pending)
		and arenaRefreshes == 0
	then
		self:Hide()
	end
end)

hooksecurefunc("NotifyInspect", function(unit)
	local guid = UnitGUID(unit)
	if not guid or not UnitIsPlayer(unit) or UnitCanAttack("player", unit) then
		return
	end
	lastSend = GetTime()
	if guid ~= loadedGuid then
		loadedGuid = nil
	end
	if guid ~= gearGuid then
		gearGuid = nil
	end
	if guid ~= teamsGuid then
		teamsGuid = nil
	end
	local _, class = UnitClass(unit)
	request.guid, request.unit, request.class, request.time = guid, unit, class, lastSend
	queue:Show()
end)

hooksecurefunc("InspectUnit", function()
	manualTime = GetTime()
end)

hooksecurefunc("ClearInspectPlayer", function()
	request.guid = nil
	gearGuid = nil
	teamsGuid = nil
	loadedGuid = nil
end)

function Inspect:INSPECT_TALENT_READY()
	local guid = request.guid
	if not guid then
		return
	end
	request.guid = nil
	if guid == UnitGUID("player") then
		return
	end
	if not talentsMatchClass(request.class) then
		fail(guid)
		return
	end
	local now = GetTime()
	retries[guid] = nil
	pending[guid] = nil
	inspected[guid] = now
	local unit = self:UnitByGUID(guid, request.unit)
	ns:Fire(ns.INSPECT_TALENTS_READY, guid, unit)
	if unit then
		gearGuid, gearUnit, gearTries, gearAt = guid, unit, 0, now
		queue:Show()
	end
	if teamsWanted then
		teamsGuid, teamsAt, teamsReplied = guid, now + HONOR_WAIT, false
		RequestInspectHonorData()
		queue:Show()
	end
end

function Inspect:INSPECT_HONOR_UPDATE()
	if teamsGuid then
		teamsReplied = true
	end
end

function Inspect:PARTY_MEMBERS_CHANGED()
	requestUnits(PARTY_UNITS, CACHE_TIME)
end

function Inspect:PLAYER_TARGET_CHANGED()
	self:Request("target", CACHE_TIME)
end

function Inspect:PLAYER_FOCUS_CHANGED()
	self:Request("focus", CACHE_TIME)
end

function Inspect:UPDATE_MOUSEOVER_UNIT()
	self:Request("mouseover", CACHE_TIME)
end

function Inspect:PLAYER_ENTERING_WORLD()
	wipe(pending)
	wipe(retries)
	request.guid = nil
	urgentGuid = nil
	gearGuid = nil
	teamsGuid = nil
	loadedGuid = nil
	requestUnits(WATCHED_UNITS, CACHE_TIME)
	if select(2, IsInInstance()) == "arena" then
		arenaRefreshes = ARENA_REFRESH_COUNT
		nextArenaRefresh = GetTime() + ARENA_REFRESH_INTERVAL
		queue:Show()
	else
		arenaRefreshes = 0
	end
end

function Inspect:Initialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	self:RegisterEvent("INSPECT_TALENT_READY")
	self:RegisterEvent("INSPECT_HONOR_UPDATE")
end
