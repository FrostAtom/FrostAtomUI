local _, ns = ...

local CombatLog = {}
ns.CombatLog = CombatLog

local ALL = "*"
CombatLog.ALL = ALL

local routes = {}
local listening = false
local bus = ns.Mixin({ name = "CombatLog" }, ns.EventMixin)

local EVENT = "COMBAT_LOG_EVENT_UNFILTERED"

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
end

local function listen()
	local wanted = next(routes) ~= nil
	if wanted ~= listening then
		listening = wanted
		if wanted then
			bus:RegisterEvent(EVENT, dispatch)
		else
			bus:UnregisterEvent(EVENT, dispatch)
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
