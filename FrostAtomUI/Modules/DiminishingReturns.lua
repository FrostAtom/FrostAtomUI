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
local UnitGUID, UnitDebuff = UnitGUID, UnitDebuff
local COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE

local BATTLE_BEGUN_MESSAGE = "The Arena battle has begun!"
local MAX_STACKS = 3

ns.DR_UPDATED = "FrostAtomUI_DR_UPDATED"

local DR = ns:NewModule("DiminishingReturns")

local states = {}

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

	ns:Fire(ns.DR_UPDATED, guid)
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
		ns:Fire(ns.DR_UPDATED, guid)
	end
end

local function onCombatLogEvent(_, _, event, _, _, _, destGUID, _, destFlags, spellId)
	local refresh = event == "SPELL_AURA_REFRESH"
	if not (refresh or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED") then
		return
	end
	local category = SPELLS[spellId]
	if
		not category
		or bit_band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == 0
		or bit_band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == 0
	then
		return
	end
	if event == "SPELL_AURA_REMOVED" then
		onRemoved(destGUID, category)
	else
		onApplied(destGUID, category, spellId, refresh)
	end
end

local RECONCILE_UNITS = { target = true, focus = true }
for i = 1, 5 do
	RECONCILE_UNITS["arena" .. i] = true
end

local carried = {}

local function onUnitAura(_, unit)
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
		local entry = state[order[j]]
		if entry.active > 0 and not carried[order[j]] and now - entry.appliedAt > RECONCILE_GRACE then
			entry.active = 0
			entry.expires = now + RESET_TIME
			ended = true
		end
	end
	if ended then
		ns:Fire(ns.DR_UPDATED, guid)
	end
end

function DR:Get(guid)
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

function DR:IsAuraActive(entry, now)
	return entry.active > 0 and now < entry.appliedAt + AURA_TIMEOUT
end

function DR:Reset()
	wipe(states)
	ns:Fire(ns.DR_UPDATED)
end

local function onSystemMessage(self, message)
	if message == BATTLE_BEGUN_MESSAGE then
		self:Reset()
	end
end

local function applyEnabled(self)
	if ns.Config.diminishingReturns.enabled then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", self.Reset)
		self:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL", onSystemMessage)
		self:RegisterEvent("UNIT_AURA", onUnitAura)
	else
		self:UnregisterEvent("UNIT_AURA")
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
		self:Reset()
	end
end

function DR:Initialize()
	applyEnabled(self)
	self:WatchConfig("diminishingReturns.enabled", applyEnabled)
end
