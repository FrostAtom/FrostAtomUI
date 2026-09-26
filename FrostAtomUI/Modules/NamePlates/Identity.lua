local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local UnitExists, UnitGUID, UnitName = UnitExists, UnitGUID, UnitName
local UnitIsPlayer, UnitIsUnit = UnitIsPlayer, UnitIsUnit
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local GetTime = GetTime
local band = bit.band
local match = string.match
local abs = math.abs
local wipe = wipe

local config = ns.Config.namePlates
local plates = NamePlates.plates

local RESOLVE_INTERVAL = 0.2
local HEALTH_TOLERANCE = 0.02
local CONFIRM_HOLD = 1
local MAX_ARENA = 5
local MAX_PARTY = 4
local MAX_RAID = 40
local MAX_NAMEPLATE_TOKENS = 40
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE

local C_NamePlate = _G.C_NamePlate
local hasNamePlateTokens = C_NamePlate and C_NamePlate.GetNamePlateForUnit and true or false
NamePlates.hasNamePlateTokens = hasNamePlateTokens

local ARENA_UNITS, ARENA_PET_UNITS = {}, {}
for i = 1, MAX_ARENA do
	ARENA_UNITS[i] = "arena" .. i
	ARENA_PET_UNITS[i] = "arenapet" .. i
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
local NAMEPLATE_UNITS = {}
if hasNamePlateTokens then
	for i = 1, MAX_NAMEPLATE_TOKENS do
		NAMEPLATE_UNITS[i] = "nameplate" .. i
	end
end

local EVENT_UNITS = { target = true, focus = true }
for i = 1, MAX_ARENA do
	EVENT_UNITS[ARENA_UNITS[i]] = true
	EVENT_UNITS[ARENA_PET_UNITS[i]] = true
end
for i = 1, #NAMEPLATE_UNITS do
	EVENT_UNITS[NAMEPLATE_UNITS[i]] = true
end
NamePlates.ARENA_UNITS = ARENA_UNITS
NamePlates.ARENA_PET_UNITS = ARENA_PET_UNITS
NamePlates.NAMEPLATE_UNITS = NAMEPLATE_UNITS
NamePlates.EVENT_UNITS = EVENT_UNITS

local targetOf = setmetatable({}, {
	__index = function(self, unit)
		local token = unit .. "target"
		self[unit] = token
		return token
	end,
})
NamePlates.targetOf = targetOf

local guidPlates = {}
local enemyPlayers = {}
local knownGUIDs = {}
local onIdentity = {}
local onPass = {}
local groupTargets, groupTargetCount = {}, 0
NamePlates.guidPlates = guidPlates
NamePlates.enemyPlayers = enemyPlayers
NamePlates.onIdentity = onIdentity
NamePlates.onPass = onPass

local nameIndex = {}
local passUnit = {}
local passArena = {}
local tokenPlates = {}

local function notify(plate)
	for i = 1, #onIdentity do
		onIdentity[i](plate)
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
			other.guid = nil
			other.unit = nil
			other.arenaIndex = nil
			notify(other)
		end
		guidPlates[guid] = plate
	end
	return true
end

local function setUnit(plate, unit, arenaIndex)
	if plate.unit == unit and plate.arenaIndex == arenaIndex then
		return false
	end
	plate.unit = unit
	plate.arenaIndex = arenaIndex
	return true
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

local function unbind(plate)
	local changed = setGUID(plate, nil)
	if setUnit(plate, nil, nil) then
		changed = true
	end
	if changed then
		updateArenaLabel(plate)
		notify(plate)
	end
end

function NamePlates.GetPlateUnit(plate)
	local unit = plate.unit
	if unit and plate.guid and UnitGUID(unit) == plate.guid then
		return unit
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

local function assign(plate, unit, guid, now)
	if setGUID(plate, guid) then
		plate.dirty = true
	end
	plate.confirmedAt = now
	if not passUnit[plate] then
		passUnit[plate] = unit
	end
end

local function isCandidate(plate, guid, now)
	return not passUnit[plate] and (plate.guid == nil or plate.guid == guid or now - plate.confirmedAt > CONFIRM_HOLD)
end

local function resolveUnit(unit, now)
	local guid = UnitGUID(unit)
	if not guid then
		return
	end
	local name = UnitName(unit)
	local plate = guidPlates[guid]
	if plate and plate:IsShown() and plate.plateName == name then
		assign(plate, unit, guid, now)
		return plate
	end

	local candidate = nameIndex[name]
	if candidate == nil then
		return
	end
	if candidate then
		if isCandidate(candidate, guid, now) and (UnitIsPlayer(unit) or healthMatches(candidate, unit)) then
			assign(candidate, unit, guid, now)
			return candidate
		end
		return
	end

	local found
	for i = 1, #plates do
		local other = plates[i]
		if
			other.plateName == name
			and other:IsShown()
			and isCandidate(other, guid, now)
			and healthMatches(other, unit)
		then
			if found then
				return
			end
			found = other
		end
	end
	if found then
		assign(found, unit, guid, now)
		return found
	end
end

local function resolveTarget(now)
	if not NamePlates.GetTargetName() then
		return
	end
	local found
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and plate:IsTarget() then
			if found then
				return
			end
			found = plate
		end
	end
	if found then
		assign(found, "target", UnitGUID("target"), now)
	end
end

local function resolveMouseover(now)
	if not UnitExists("mouseover") then
		return
	end
	local name = UnitName("mouseover")
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and ns.PlateLayer.IsMouseover(plate.info) and plate.plateName == name then
			assign(plate, "mouseover", UnitGUID("mouseover"), now)
			return
		end
	end
end

local function pass()
	if not config.enabled then
		return
	end
	local now = GetTime()
	wipe(nameIndex)
	wipe(passUnit)
	wipe(passArena)

	local shown = 0
	for i = 1, #plates do
		local plate = plates[i]
		local name = plate.plateName
		if plate:IsShown() and name and not plate.totem:IsShown() then
			shown = shown + 1
			nameIndex[name] = nameIndex[name] == nil and plate
		end
	end
	if shown == 0 then
		return
	end

	for unit, plate in pairs(tokenPlates) do
		if plate:IsShown() and plate.healthbar then
			local guid = UnitGUID(unit)
			if guid then
				assign(plate, unit, guid, now)
			end
		end
	end
	resolveTarget(now)
	resolveUnit("focus", now)
	for i = 1, MAX_ARENA do
		local plate = resolveUnit(ARENA_UNITS[i], now)
		if plate then
			passArena[plate] = i
		end
		resolveUnit(ARENA_PET_UNITS[i], now)
	end
	resolveMouseover(now)
	for i = 1, groupTargetCount do
		resolveUnit(groupTargets[i], now)
	end

	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() then
			local unit = passUnit[plate]
			if not unit and not plate.guid then
				local name = plate.plateName
				local guid = name and enemyPlayers[name]
				if guid and nameIndex[name] == plate and not guidPlates[guid] then
					setGUID(plate, guid)
					plate.dirty = true
				end
			end
			if setUnit(plate, unit, passArena[plate]) then
				plate.dirty = true
			end
			if plate.dirty then
				plate.dirty = nil
				updateArenaLabel(plate)
				notify(plate)
			end
		end
	end

	for i = 1, #onPass do
		onPass[i](now)
	end
end

local function requestPass()
	ns.Defer(pass, pass)
end
NamePlates.RequestIdentityPass = requestPass

local function updateRoster()
	groupTargetCount = 0
	local raidCount = GetNumRaidMembers()
	local units, targets, count
	if raidCount > 0 then
		units, targets, count = RAID_UNITS, RAID_TARGETS, raidCount
	else
		units, targets, count = PARTY_UNITS, PARTY_TARGETS, GetNumPartyMembers()
	end
	for i = 1, count do
		local unit = units[i]
		if UnitExists(unit) and not UnitIsUnit(unit, "player") then
			groupTargetCount = groupTargetCount + 1
			groupTargets[groupTargetCount] = targets[i]
		end
	end
	for i = groupTargetCount + 1, #groupTargets do
		groupTargets[i] = nil
	end
end

local function rememberEnemy(guid, name, flags)
	if knownGUIDs[guid] or band(flags, TYPE_PLAYER) == 0 or band(flags, REACTION_HOSTILE) == 0 then
		return
	end
	knownGUIDs[guid] = true
	enemyPlayers[match(name, "^[^%-]+")] = guid
end

local logHandlers = {}

function NamePlates.AddLogHandler(event, handler)
	local list = logHandlers[event]
	if not list then
		list = {}
		logHandlers[event] = list
	end
	list[#list + 1] = handler
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

local function onCombatLog(_, _, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
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
	requestPass()
end

local function onPlateShow(plate, name)
	if plate.identityName ~= name then
		plate.identityName = name
		unbind(plate)
	end
end

local function onPlateHide(plate)
	plate.identityName = nil
	unbind(plate)
end

local function onNamePlateAdded(_, unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if plate then
		tokenPlates[unit] = plate
		requestPass()
	end
end

local function onNamePlateRemoved(_, unit)
	local plate = tokenPlates[unit]
	tokenPlates[unit] = nil
	if plate and plate.unit == unit then
		plate.unit = nil
		requestPass()
	end
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
	NamePlates.onPlateShow[#NamePlates.onPlateShow + 1] = onPlateShow
	NamePlates.onPlateHide[#NamePlates.onPlateHide + 1] = onPlateHide
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", updateRoster)
	self:RegisterEvent("RAID_ROSTER_UPDATE", updateRoster)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", requestPass)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", requestPass)
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", requestPass)
	self:RegisterEvent("ARENA_OPPONENT_UPDATE", requestPass)
	if hasNamePlateTokens then
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED", onNamePlateAdded)
		self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", onNamePlateRemoved)
	end
	self:WatchConfig("namePlates", applyArenaLabels)
	ns.Scheduler.AddTicker(pass, pass, RESOLVE_INTERVAL)
	updateRoster()
end)
