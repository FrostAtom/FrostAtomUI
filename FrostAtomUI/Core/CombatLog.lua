local _, ns = ...

local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local wipe = wipe

local CombatLog = {}
ns.CombatLog = CombatLog

local ALL = "*"
CombatLog.ALL = ALL

local routes = {}
local listening = false
local bus = ns.Mixin({ name = "CombatLog" }, ns.EventMixin)

local EVENT = "COMBAT_LOG_EVENT_UNFILTERED"
local CHANNEL_STOP = "UNIT_SPELLCAST_CHANNEL_STOP"

-- 3.3.5: the client drops SPELL_INTERRUPT when the interrupted spell is hidden from the combat log (attributes 0x100)
local HIDDEN_INTERRUPT_CHANNELS = {
	47540, 2, -- Penance
	5143, 64, -- Arcane Missiles
}

local hiddenChannels = {}
for i = 1, #HIDDEN_INTERRUPT_CHANNELS, 2 do
	local id = HIDDEN_INTERRUPT_CHANNELS[i]
	local name = GetSpellInfo(id)
	if name then
		hiddenChannels[name] = { id = id, name = name, school = HIDDEN_INTERRUPT_CHANNELS[i + 1] }
	end
end

local stoppedChannels = {}

local function forgetStoppedChannels()
	wipe(stoppedChannels)
end

local function onChannelStop(_, unit, spellName)
	local channel = hiddenChannels[spellName]
	local guid = channel and UnitGUID(unit)
	if guid then
		stoppedChannels[guid] = channel
		ns.Defer(stoppedChannels, forgetStoppedChannels)
	end
end

local function run(list, ...)
	local call = ns.CallHandler
	for i = 1, #list do
		local record = list[i]
		if not record.removed then
			call(EVENT, record, ...)
		end
	end
end

local function dispatch(_, timestamp, subevent, ...)
	local list = routes[subevent]
	if list then
		run(list, timestamp, subevent, ...)
	end
	list = routes[ALL]
	if list then
		run(list, timestamp, subevent, ...)
	end
	if subevent ~= "SPELL_CAST_SUCCESS" then
		return
	end
	local srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool = ...
	local channel = stoppedChannels[dstGUID]
	if channel and ns.SpellDB.Lockout(spellId) then
		stoppedChannels[dstGUID] = nil
		dispatch(
			nil,
			timestamp,
			"SPELL_INTERRUPT",
			srcGUID,
			srcName,
			srcFlags,
			dstGUID,
			dstName,
			dstFlags,
			spellId,
			spellName,
			spellSchool,
			channel.id,
			channel.name,
			channel.school
		)
	end
end

local function listen()
	local wanted = next(routes) ~= nil
	if wanted ~= listening then
		listening = wanted
		if wanted then
			bus:RegisterEvent(EVENT, dispatch)
			bus:RegisterEvent(CHANNEL_STOP, onChannelStop)
		else
			bus:UnregisterEvent(EVENT, dispatch)
			bus:UnregisterEvent(CHANNEL_STOP, onChannelStop)
		end
	end
end

local function names(subevents)
	if subevents == ALL then
		return { ALL }
	elseif subevents[1] then
		return subevents
	end
	local list = {}
	for name in pairs(subevents) do
		list[#list + 1] = name
	end
	return list
end

function CombatLog.Unregister(owner, handler)
	for name, list in pairs(routes) do
		local kept = {}
		for i = 1, #list do
			local record = list[i]
			if record.owner ~= owner or (handler and record.handler ~= handler) then
				kept[#kept + 1] = record
			else
				record.removed = true
			end
		end
		if #kept ~= #list then
			routes[name] = #kept > 0 and kept or nil
		end
	end
	listen()
end

function CombatLog.Register(owner, subevents, handler)
	assert(type(handler) == "function", "combat log handler must be a function")
	CombatLog.Unregister(owner, handler)
	local record = { owner = owner, handler = handler }
	for _, name in ipairs(names(subevents)) do
		local list = {}
		for i, other in ipairs(routes[name] or {}) do
			list[i] = other
		end
		list[#list + 1] = record
		routes[name] = list
	end
	listen()
end

function CombatLog.IsRegistered(owner, handler)
	for _, list in pairs(routes) do
		for i = 1, #list do
			if list[i].owner == owner and (not handler or list[i].handler == handler) then
				return true
			end
		end
	end
	return false
end

function CombatLog.Subscribers()
	local counts = {}
	for name, list in pairs(routes) do
		counts[name] = #list
	end
	return counts
end
