local _, ns = ...

local Data = ns.DRData
local SPELLS = Data.SPELLS
local RESET_TIME = Data.RESET_TIME
local AURA_TIMEOUT = Data.AURA_TIMEOUT
local RECONCILE_GRACE = Data.RECONCILE_GRACE

local bit_band = bit.band
local tremove = table.remove
local wipe = wipe
local GetTime = GetTime
local UnitGUID, UnitDebuff, UnitBuff = UnitGUID, UnitDebuff, UnitBuff
local COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local GROUP_AFFILIATION = 0x6

local ARENA_PREPARATION = GetSpellInfo(32727) -- Arena Preparation
local MAX_STACKS = 3

local DR = ns:NewModule("DiminishingReturns")
ns.Mixin(DR, ns.Demand)

local states = {}
local preparing = false
local playerGUID

local function hasArenaPreparation()
	return ARENA_PREPARATION and UnitBuff("player", ARENA_PREPARATION) and true or false
end

local function prune(state, now)
	local order = state.order
	local i = 1
	while i <= #order do
		local entry = state[order[i]]
		if entry.expires <= now then
			entry.stacks = 0
			entry.active = 0
			tremove(order, i)
		else
			i = i + 1
		end
	end
end

local function onApplied(guid, category, spellId, refresh)
	local now = GetTime()
	local state = states[guid]
	if not state then
		state = { order = {} }
		states[guid] = state
	end
	prune(state, now)

	local entry = state[category]
	if not entry then
		entry = { stacks = 0, active = 0 }
		state[category] = entry
	end
	if entry.stacks == 0 then
		state.order[#state.order + 1] = category
	end
	entry.stacks = entry.stacks < MAX_STACKS and entry.stacks + 1 or MAX_STACKS
	entry.spellId = spellId
	if not refresh or entry.active == 0 then
		entry.active = entry.active + 1
	end
	entry.appliedAt = now
	entry.expires = now + AURA_TIMEOUT + RESET_TIME

	ns:Fire(ns.E.DR_UPDATED, guid)
end

local function onRemoved(guid, category)
	local state = states[guid]
	local entry = state and state[category]
	if not entry or entry.stacks == 0 or entry.active == 0 then
		return
	end
	entry.active = entry.active - 1
	if entry.active == 0 then
		entry.expires = GetTime() + RESET_TIME
		ns:Fire(ns.E.DR_UPDATED, guid)
	end
end

local function onCombatLogEvent(_, _, event, _, _, _, destGUID, _, destFlags, spellId)
	local refresh = event == "SPELL_AURA_REFRESH"
	if not (refresh or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED") then
		return
	end
	local category = SPELLS[spellId]
	if not category then
		return
	end
	playerGUID = playerGUID or UnitGUID("player")
	if
		destGUID ~= playerGUID
		and (
			bit_band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == 0
			or bit_band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == 0
				and bit_band(destFlags, GROUP_AFFILIATION) == 0
		)
	then
		return
	end
	if event == "SPELL_AURA_REMOVED" then
		onRemoved(destGUID, category)
	else
		onApplied(destGUID, category, spellId, refresh)
	end
end

local RECONCILE_UNITS = { player = true, target = true, focus = true }
for i = 1, 5 do
	RECONCILE_UNITS["arena" .. i] = true
end
for i = 1, 4 do
	RECONCILE_UNITS["party" .. i] = true
end

local carried = {}

local function onUnitAura(self, unit)
	if unit == "player" then
		if hasArenaPreparation() then
			preparing = true
		elseif preparing then
			preparing = false
			self:Reset()
			return
		end
	end
	if not RECONCILE_UNITS[unit] then
		return
	end
	local guid = UnitGUID(unit)
	local state = guid and states[guid]
	if not state then
		return
	end

	wipe(carried)
	local i = 1
	local name, _, _, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, i)
	while name do
		local category = SPELLS[spellId]
		if category then
			carried[category] = true
		end
		i = i + 1
		name, _, _, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, i)
	end

	local now = GetTime()
	local ended = false
	local order = state.order
	for j = 1, #order do
		local category = order[j]
		local entry = state[category]
		if entry.active > 0 and not carried[category] and now - entry.appliedAt > RECONCILE_GRACE then
			entry.active = 0
			entry.expires = now + RESET_TIME
			ended = true
		end
	end
	if ended then
		ns:Fire(ns.E.DR_UPDATED, guid)
	end
end

local function liveState(guid)
	local state = guid and states[guid]
	if not state then
		return
	end
	prune(state, GetTime())
	if #state.order == 0 then
		return
	end
	return state
end

local function describe(entry, now)
	return entry.stacks,
		entry.expires,
		entry.active > 0 and now < entry.appliedAt + AURA_TIMEOUT,
		entry.spellId,
		entry.appliedAt
end

function DR:GetCategory(guid, category)
	local state = liveState(guid)
	local entry = state and state[category]
	if entry and entry.stacks > 0 then
		return describe(entry, GetTime())
	end
end

local function nothing() end

function DR:IterateCategories(guid)
	local state = liveState(guid)
	if not state then
		return nothing
	end
	local order, now, i = state.order, GetTime(), 0
	return function()
		i = i + 1
		local category = order[i]
		if category then
			return category, describe(state[category], now)
		end
	end
end

function DR:Reset()
	wipe(states)
	ns:Fire(ns.E.DR_UPDATED)
end

local function onEnteringWorld(self)
	preparing = hasArenaPreparation()
	self:Reset()
end

function DR:OnDemandStart()
	preparing = hasArenaPreparation()
	ns.CombatLog.Register(self, { "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_REMOVED" }, onCombatLogEvent)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	self:RegisterEvent("UNIT_AURA", onUnitAura)
end

function DR:OnDemandStop()
	self:UnregisterEvent("UNIT_AURA")
	ns.CombatLog.Unregister(self, onCombatLogEvent)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	preparing = false
	self:Reset()
end
