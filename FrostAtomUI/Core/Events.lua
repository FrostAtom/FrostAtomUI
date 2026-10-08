local ADDON_NAME, ns = ...

local IsAddOnLoaded, debugprofilestop = IsAddOnLoaded, debugprofilestop
local SafeCall = ns.SafeCall

local EVENT_PREFIX = ADDON_NAME .. "_"

local customEvents = {}
ns.E = {}
for _, key in ipairs({
	"DB_LOADED",
	"CONFIG_CHANGED",
	"PROFILES_CHANGED",
	"HISTORY_CHANGED",
	"RELOAD_REQUIRED",
	"PREVIEW_CHANGED",
	"POSITION_INVALIDATED",
	"PIXEL_CHANGED",
	"INSPECT_TALENTS_READY",
	"INSPECT_GEAR_READY",
	"INSPECT_TEAMS_READY",
	"TALENTS_UPDATED",
	"COOLDOWN_UPDATED",
	"DR_UPDATED",
	"PROC_COOLDOWN_UPDATED",
	"PREDICTION_CHANGED",
	"CAST_INTERRUPTED",
	"CAST_SILENCED",
	"PLAYER_INTERRUPTED",
	"SOLOQ_SEARCHING",
	"MACROS_CHANGED",
}) do
	local event = EVENT_PREFIX .. key
	ns.E[key] = event
	customEvents[event] = true
end

local eventFrame = CreateFrame("Frame")

local callbacks = {}
local unitCallbacks = {}
local registrations = {}

local function checkEvent(event)
	assert(type(event) == "string", "event name must be a string")
	assert(customEvents[event] or event:sub(1, #EVENT_PREFIX) ~= EVENT_PREFIX, ("unknown event %s"):format(event))
end

local function resolveHandler(owner, event, handler)
	handler = handler or event
	if type(handler) ~= "function" then
		local method = owner[handler]
		assert(type(method) == "function", ("no method [%s] for event %s"):format(tostring(handler), event))
		handler = method
	end
	return handler
end

local function retain(event)
	local count = registrations[event] or 0
	if count == 0 and not customEvents[event] then
		eventFrame:RegisterEvent(event)
	end
	registrations[event] = count + 1
end

local function release(event, count)
	if count == 0 then
		return
	end
	local remaining = registrations[event] - count
	registrations[event] = remaining
	if remaining == 0 and not customEvents[event] then
		eventFrame:UnregisterEvent(event)
	end
end

local function newList()
	return { firing = 0, dirty = false }
end

local function findRecord(list, owner, handler)
	for i = 1, #list do
		local record = list[i]
		if record.owner == owner and record.handler == handler and not record.removed then
			return record, i
		end
	end
end

local function compact(list)
	local n = 0
	for i = 1, #list do
		local record = list[i]
		list[i] = nil
		if not record.removed then
			n = n + 1
			list[n] = record
		end
	end
	list.dirty = false
end

local function addRecord(list, owner, event, handler)
	if findRecord(list, owner, handler) then
		return
	end
	list[#list + 1] = { owner = owner, handler = handler }
	retain(event)
end

local function removeRecord(list, owner, handler)
	local record, index = findRecord(list, owner, handler)
	if not record then
		return 0
	end
	record.removed = true
	if list.firing == 0 then
		table.remove(list, index)
	else
		list.dirty = true
	end
	return 1
end

local function removeOwner(list, owner)
	local removed = 0
	for i = 1, #list do
		local record = list[i]
		if record.owner == owner and not record.removed then
			record.removed = true
			removed = removed + 1
		end
	end
	if removed > 0 then
		if list.firing == 0 then
			compact(list)
		else
			list.dirty = true
		end
	end
	return removed
end

local function removeFromList(list, owner, event, handler)
	if handler then
		return removeRecord(list, owner, resolveHandler(owner, event, handler))
	end
	return removeOwner(list, owner)
end

local profile
local nestedMs = 0

local function profiledCall(event, record, ...)
	local outerNested = nestedMs
	nestedMs = 0
	local start = debugprofilestop()
	SafeCall(record.handler, record.owner, ...)
	local total = debugprofilestop() - start
	local elapsed = total - nestedMs
	nestedMs = outerNested + total
	if not profile then
		return
	end
	local byOwner = profile[event]
	if not byOwner then
		byOwner = {}
		profile[event] = byOwner
	end
	local owner = record.owner
	local entry = byOwner[owner]
	if not entry then
		entry = { calls = 0, ms = 0, max = 0 }
		byOwner[owner] = entry
	end
	entry.calls = entry.calls + 1
	entry.ms = entry.ms + elapsed
	if elapsed > entry.max then
		entry.max = elapsed
	end
end

function ns.StartEventProfile()
	profile = {}
	nestedMs = 0
end

function ns.StopEventProfile()
	local result = profile
	profile = nil
	return result
end

function ns.CallHandler(event, record, ...)
	if profile then
		profiledCall(event, record, ...)
	else
		SafeCall(record.handler, record.owner, ...)
	end
end

local function fireList(event, list, ...)
	local n = #list
	if n == 0 then
		return
	end
	list.firing = list.firing + 1
	for i = 1, n do
		local record = list[i]
		if not record.removed then
			if profile then
				profiledCall(event, record, ...)
			else
				SafeCall(record.handler, record.owner, ...)
			end
		end
	end
	list.firing = list.firing - 1
	if list.dirty and list.firing == 0 then
		compact(list)
	end
end

local EventMixin = {}
ns.EventMixin = EventMixin

function EventMixin:RegisterEvent(event, handler)
	checkEvent(event)
	handler = resolveHandler(self, event, handler)

	local list = callbacks[event]
	if not list then
		list = newList()
		callbacks[event] = list
	end
	addRecord(list, self, event, handler)
end

function EventMixin:UnregisterEvent(event, handler)
	local list = callbacks[event]
	if list then
		release(event, removeFromList(list, self, event, handler))
	end
end

function EventMixin:RegisterUnitEvent(event, unit, handler)
	checkEvent(event)
	assert(type(unit) == "string", "unit must be a string")
	handler = resolveHandler(self, event, handler)

	local byUnit = unitCallbacks[event]
	if not byUnit then
		byUnit = {}
		unitCallbacks[event] = byUnit
	end
	local list = byUnit[unit]
	if not list then
		list = newList()
		byUnit[unit] = list
	end
	addRecord(list, self, event, handler)
end

local function removeOwnerFromUnits(byUnit, owner)
	local removed = 0
	for _, list in pairs(byUnit) do
		removed = removed + removeOwner(list, owner)
	end
	return removed
end

function EventMixin:UnregisterUnitEvent(event, unit, handler)
	local byUnit = unitCallbacks[event]
	if not byUnit then
		return
	end
	if not unit then
		release(event, removeOwnerFromUnits(byUnit, self))
		return
	end
	local list = byUnit[unit]
	if list then
		release(event, removeFromList(list, self, event, handler))
	end
end

function EventMixin:UnregisterAllEvents()
	for event, list in pairs(callbacks) do
		release(event, removeOwner(list, self))
	end
	for event, byUnit in pairs(unitCallbacks) do
		release(event, removeOwnerFromUnits(byUnit, self))
	end
end

function ns:Fire(event, ...)
	local list = callbacks[event]
	if list then
		fireList(event, list, ...)
	end
	local byUnit = unitCallbacks[event]
	if byUnit then
		local unitList = byUnit[(...)]
		if unitList then
			fireList(event, unitList, ...)
		end
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	ns:Fire(event, ...)
end)

local addonWaiters = {}
local addonWatcher = ns.Mixin({}, EventMixin)

local function onAddonLoaded(_, addon)
	local waiters = addonWaiters[addon]
	if not waiters then
		return
	end
	addonWaiters[addon] = nil
	for i = 1, #waiters do
		SafeCall(waiters[i])
	end
	if not next(addonWaiters) then
		addonWatcher:UnregisterEvent("ADDON_LOADED")
	end
end

function ns:OnAddonLoaded(addon, callback)
	if IsAddOnLoaded(addon) then
		callback()
		return
	end

	local waiters = addonWaiters[addon]
	if not waiters then
		waiters = {}
		addonWaiters[addon] = waiters
		addonWatcher:RegisterEvent("ADDON_LOADED", onAddonLoaded)
	end
	waiters[#waiters + 1] = callback
end

ns.Mixin(ns.ModulePrototype, EventMixin)
