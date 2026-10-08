local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local UnitExists, UnitGUID, UnitName = UnitExists, UnitGUID, UnitName
local UnitIsPlayer, UnitIsUnit = UnitIsPlayer, UnitIsUnit
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local GetTime = GetTime
local band = bit.band
local match = string.match
local abs, huge = math.abs, math.huge
local next, pairs, wipe = next, pairs, wipe

local config = ns.Config.namePlates
local plates = NamePlates.plates

local RESOLVE_INTERVAL = 0.2
local HEALTH_TOLERANCE = 0.02
local CONFIRM_HOLD = 1
local MAX_ARENA = 5
local MAX_PARTY = 4
local MAX_RAID = 40
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE

local ARENA_UNITS, ARENA_PET_UNITS = {}, {}
local ARENA_INDEX = {}
for i = 1, MAX_ARENA do
	ARENA_UNITS[i] = "arena" .. i
	ARENA_PET_UNITS[i] = "arenapet" .. i
	ARENA_INDEX[ARENA_UNITS[i]] = i
end
local PARTY_UNITS, PARTY_TARGETS = {}, {}
for i = 1, MAX_PARTY do
	PARTY_UNITS[i] = "party" .. i
	PARTY_TARGETS[i] = "party" .. i .. "target"
end
local RAID_UNITS, RAID_TARGETS = {}, {}
for i = 1, MAX_RAID do
	RAID_UNITS[i] = "raid" .. i
	RAID_TARGETS[i] = "raid" .. i .. "target"
end
local GROUP_UNITS = {}
for i = 1, MAX_PARTY do
	GROUP_UNITS[PARTY_UNITS[i]] = true
end
for i = 1, MAX_RAID do
	GROUP_UNITS[RAID_UNITS[i]] = true
end

local EVENT_UNITS = { target = true, focus = true }
for i = 1, MAX_ARENA do
	EVENT_UNITS[ARENA_UNITS[i]] = true
	EVENT_UNITS[ARENA_PET_UNITS[i]] = true
end
NamePlates.ARENA_UNITS = ARENA_UNITS
NamePlates.ARENA_PET_UNITS = ARENA_PET_UNITS
NamePlates.EVENT_UNITS = EVENT_UNITS

local FIXED_UNITS = { "target", "focus" }
for i = 1, MAX_ARENA do
	FIXED_UNITS[#FIXED_UNITS + 1] = ARENA_UNITS[i]
end
for i = 1, MAX_ARENA do
	FIXED_UNITS[#FIXED_UNITS + 1] = ARENA_PET_UNITS[i]
end
FIXED_UNITS[#FIXED_UNITS + 1] = "mouseover"

local targetOf = setmetatable({}, {
	__index = function(self, unit)
		local token = unit .. "target"
		self[unit] = token
		return token
	end,
})
NamePlates.targetOf = targetOf

local guidPlates = {}
local unitPlates = {}
local enemyPlayers = {}
local knownGUIDs = {}
local onIdentity = NamePlates.onIdentity
local onUnitAdded = NamePlates.onUnitAdded
local onUnitRemoved = NamePlates.onUnitRemoved
local onPass = NamePlates.onPass
NamePlates.guidPlates = guidPlates
NamePlates.unitPlates = unitPlates

local units, priority = {}, {}
local nameIndex = {}
local resolved = {}
local claims = {}
local owners = {}
local changed = {}
local stale = {}

local function notify(plate)
	for i = 1, #onIdentity do
		onIdentity[i](plate)
	end
end

local function fire(handlers, plate, unit)
	for i = 1, #handlers do
		handlers[i](plate, unit)
	end
end

local function updateArenaLabel(plate)
	local label = plate.arenaLabel
	local index = config.arenaNumbers and not plate.totem:IsShown() and plate.arenaIndex
	if index then
		label:SetFormattedText("%d", index)
	else
		label:SetText("")
	end
end

local function refreshUnits(plate)
	local best, bestRank, arenaIndex
	for unit in pairs(plate.units) do
		local rank = priority[unit] or huge
		if not bestRank or rank < bestRank then
			best, bestRank = unit, rank
		end
		local index = ARENA_INDEX[unit]
		if index and (not arenaIndex or index < arenaIndex) then
			arenaIndex = index
		end
	end
	plate.unit = best
	if plate.arenaIndex ~= arenaIndex then
		plate.arenaIndex = arenaIndex
		updateArenaLabel(plate)
	end
end

local function attach(plate, unit)
	local set = plate.units
	if not set then
		set = {}
		plate.units = set
	end
	unitPlates[unit] = plate
	set[unit] = true
	refreshUnits(plate)
	fire(onUnitAdded, plate, unit)
end

local function detach(plate, unit)
	unitPlates[unit] = nil
	plate.units[unit] = nil
	refreshUnits(plate)
	fire(onUnitRemoved, plate, unit)
end

local function detachAll(plate)
	local set = plate.units
	if not set then
		return
	end
	local unit = next(set)
	while unit do
		detach(plate, unit)
		unit = next(set)
	end
end

local function setGUID(plate, guid)
	local old = plate.guid
	if old == guid then
		return false
	end
	if old and guidPlates[old] == plate then
		guidPlates[old] = nil
	end
	plate.guid = guid
	plate.confirmedAt = 0
	if guid then
		local other = guidPlates[guid]
		if other and other ~= plate then
			detachAll(other)
			other.guid = nil
			notify(other)
		end
		guidPlates[guid] = plate
	end
	return true
end

local function release(plate)
	detachAll(plate)
	if setGUID(plate, nil) then
		notify(plate)
	end
end

function NamePlates.GetPlateUnit(plate)
	local unit = plate.unit
	if not unit then
		return
	end
	local guid = plate.guid
	if UnitGUID(unit) == guid then
		return unit
	end
	for other in pairs(plate.units) do
		if UnitGUID(other) == guid then
			return other
		end
	end
end

local function healthMatches(plate, unit)
	local healthbar = plate.healthbar
	local _, max = healthbar:GetMinMaxValues()
	local unitMax = UnitHealthMax(unit)
	if not max or max <= 0 or unitMax <= 0 then
		return false
	end
	return abs(healthbar:GetValue() / max - UnitHealth(unit) / unitMax) <= HEALTH_TOLERANCE
end

local function isCandidate(plate, guid, now)
	local claimed = claims[plate]
	if claimed then
		return claimed == guid
	end
	return plate.guid == nil or plate.guid == guid or now - plate.confirmedAt > CONFIRM_HOLD
end

local function knownPlate(guid, name)
	local plate = guidPlates[guid]
	if plate and plate:IsShown() and plate.plateName == name then
		return plate
	end
end

local function targetPlate(name)
	local found
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and plate:IsTarget() and plate.plateName == name then
			if found then
				return
			end
			found = plate
		end
	end
	return found
end

local function mouseoverPlate(name)
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and plate.plateName == name and ns.PlateLayer.IsMouseover(plate.info) then
			return plate
		end
	end
end

local function matchPlate(unit, guid, name, now)
	local candidate = nameIndex[name]
	if candidate == nil then
		return
	end
	if candidate then
		if isCandidate(candidate, guid, now) and (UnitIsPlayer(unit) or healthMatches(candidate, unit)) then
			return candidate
		end
		return
	end

	local found
	for i = 1, #plates do
		local plate = plates[i]
		if
			plate.plateName == name
			and plate:IsShown()
			and isCandidate(plate, guid, now)
			and healthMatches(plate, unit)
		then
			if found then
				return
			end
			found = plate
		end
	end
	return found
end

local function resolve(unit, now)
	local guid = UnitGUID(unit)
	if not guid then
		return
	end
	local owner = owners[guid]
	if owner then
		return owner
	end
	local name = UnitName(unit)
	local plate
	if unit == "target" then
		plate = targetPlate(name) or knownPlate(guid, name)
	elseif unit == "mouseover" then
		plate = mouseoverPlate(name) or knownPlate(guid, name)
	else
		plate = knownPlate(guid, name) or matchPlate(unit, guid, name, now)
	end
	if not plate or claims[plate] then
		return
	end
	owners[guid] = plate
	claims[plate] = guid
	return plate
end

local function bindEnemyPlayers()
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and not plate.guid and not claims[plate] then
			local name = plate.plateName
			local guid = name and enemyPlayers[name]
			if guid and nameIndex[name] == plate and not guidPlates[guid] then
				setGUID(plate, guid)
				changed[plate] = true
			end
		end
	end
end

local function pass()
	if not config.enabled then
		return
	end
	local now = GetTime()
	wipe(nameIndex)
	wipe(resolved)
	wipe(claims)
	wipe(owners)
	wipe(changed)

	for i = 1, #plates do
		local plate = plates[i]
		local name = plate.plateName
		if plate:IsShown() and name and not plate.totemSpell then
			nameIndex[name] = nameIndex[name] == nil and plate
		end
	end

	for i = 1, #units do
		local unit = units[i]
		resolved[unit] = resolve(unit, now)
	end

	local count = 0
	for unit, plate in pairs(unitPlates) do
		if resolved[unit] ~= plate or claims[plate] ~= plate.guid then
			count = count + 1
			stale[count] = unit
		end
	end
	for i = 1, count do
		local unit = stale[i]
		stale[i] = nil
		local plate = unitPlates[unit]
		if plate then
			detach(plate, unit)
		end
	end

	for plate, guid in pairs(claims) do
		if setGUID(plate, guid) then
			changed[plate] = true
		end
		plate.confirmedAt = now
	end
	bindEnemyPlayers()
	for plate in pairs(changed) do
		if plate:IsShown() then
			notify(plate)
		end
	end

	for i = 1, #units do
		local unit = units[i]
		local plate = resolved[unit]
		if plate and unitPlates[unit] ~= plate and plate.guid == claims[plate] then
			attach(plate, unit)
		end
	end

	for i = 1, #onPass do
		onPass[i](now)
	end
end

local function requestPass()
	ns.Defer(pass, pass)
end

local function updateRoster()
	wipe(units)
	wipe(priority)
	for i = 1, #FIXED_UNITS do
		units[i] = FIXED_UNITS[i]
	end
	local raidCount = GetNumRaidMembers()
	local members, targets, count
	if raidCount > 0 then
		members, targets, count = RAID_UNITS, RAID_TARGETS, raidCount
	else
		members, targets, count = PARTY_UNITS, PARTY_TARGETS, GetNumPartyMembers()
	end
	for i = 1, count do
		local unit = members[i]
		if UnitExists(unit) and not UnitIsUnit(unit, "player") then
			units[#units + 1] = targets[i]
		end
	end
	for i = 1, #units do
		priority[units[i]] = i
	end
	requestPass()
end

local function onUnitTarget(_, unit)
	if GROUP_UNITS[unit] then
		requestPass()
	end
end

local function rememberEnemy(guid, name, flags)
	if knownGUIDs[guid] or band(flags, TYPE_PLAYER) == 0 or band(flags, REACTION_HOSTILE) == 0 then
		return
	end
	knownGUIDs[guid] = true
	enemyPlayers[match(name, "^[^%-]+")] = guid
end

local NAME_EVENTS = {
	SWING_DAMAGE = true,
	RANGE_DAMAGE = true,
	SPELL_DAMAGE = true,
	SPELL_PERIODIC_DAMAGE = true,
	SPELL_HEAL = true,
	SPELL_PERIODIC_HEAL = true,
	SPELL_CAST_SUCCESS = true,
	SPELL_CAST_START = true,
	SPELL_AURA_APPLIED = true,
	SPELL_AURA_REFRESH = true,
	SPELL_MISSED = true,
}

local logHandlers = {}
local onCombatLog
local listening = false

local function subscribe()
	local events = {}
	for event in pairs(NAME_EVENTS) do
		events[event] = true
	end
	for event in pairs(logHandlers) do
		events[event] = true
	end
	listening = true
	ns.CombatLog.Register(NamePlates, events, onCombatLog)
end

function NamePlates.AddLogHandler(event, handler)
	local list = logHandlers[event]
	if not list then
		list = {}
		logHandlers[event] = list
	end
	list[#list + 1] = handler
	if listening then
		subscribe()
	end
end

function onCombatLog(_, _, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	if NAME_EVENTS[event] then
		if srcName then
			rememberEnemy(srcGUID, srcName, srcFlags)
		end
		if dstName then
			rememberEnemy(dstGUID, dstName, dstFlags)
		end
	end
	local handlers = logHandlers[event]
	if handlers then
		for i = 1, #handlers do
			handlers[i](srcGUID, srcFlags, dstGUID, dstFlags, ...)
		end
	end
end

local function onEnteringWorld()
	wipe(enemyPlayers)
	wipe(knownGUIDs)
	updateRoster()
end

local function onPlateShow(plate, name)
	if plate.identityName ~= name then
		plate.identityName = name
		release(plate)
		requestPass()
	end
end

local function onPlateHide(plate)
	plate.identityName = nil
	release(plate)
end

local function applyArenaLabels()
	for i = 1, #plates do
		updateArenaLabel(plates[i])
	end
end

NamePlates:OnInitialize(function(self)
	if not config.enabled then
		return
	end
	NamePlates.RegisterPlugin({
		name = "identity",
		Show = onPlateShow,
		Hide = onPlateHide,
	})
	subscribe()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", updateRoster)
	self:RegisterEvent("RAID_ROSTER_UPDATE", updateRoster)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", requestPass)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", requestPass)
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", requestPass)
	self:RegisterEvent("ARENA_OPPONENT_UPDATE", requestPass)
	self:RegisterEvent("UNIT_TARGET", onUnitTarget)
	self:WatchConfig("namePlates", applyArenaLabels)
	ns.Scheduler.AddTicker(pass, pass, RESOLVE_INTERVAL)
	updateRoster()
end)
