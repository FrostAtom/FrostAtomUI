local _, ns = ...

local IsAddOnLoaded = IsAddOnLoaded

local eventFrame = CreateFrame("Frame")

local callbacks = {}
local unitCallbacks = {}
local registrations = {}

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
	if count == 0 then
		eventFrame:RegisterEvent(event)
	end
	registrations[event] = count + 1
end

local function release(event)
	local count = registrations[event] - 1
	registrations[event] = count
	if count == 0 then
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

local function findRecordForOwner(list, owner)
	for i = 1, #list do
		local record = list[i]
		if record.owner == owner and not record.removed then
			return record
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

local function addRecord(list, owner, handler)
	if findRecord(list, owner, handler) then
		return false
	end
	list[#list + 1] = { owner = owner, handler = handler }
	return true
end

local function removeRecord(list, owner, handler)
	local record, index = findRecord(list, owner, handler)
	if not record then
		return false
	end
	record.removed = true
	if list.firing == 0 then
		table.remove(list, index)
	else
		list.dirty = true
	end
	return true
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

local function fireList(list, ...)
	local n = #list
	if n == 0 then
		return
	end
	list.firing = list.firing + 1
	for i = 1, n do
		local record = list[i]
		if not record.removed then
			record.handler(record.owner, ...)
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
	assert(type(event) == "string", "event name must be a string")
	handler = resolveHandler(self, event, handler)

	local list = callbacks[event]
	if not list then
		list = newList()
		callbacks[event] = list
	end
	if addRecord(list, self, handler) then
		retain(event)
	end
end

function EventMixin:UnregisterEvent(event, handler)
	local list = callbacks[event]
	if not list then
		return
	end
	local removed
	if handler then
		removed = removeRecord(list, self, resolveHandler(self, event, handler)) and 1 or 0
	else
		removed = removeOwner(list, self)
	end
	for _ = 1, removed do
		release(event)
	end
end

function EventMixin:RegisterUnitEvent(event, unit, handler)
	assert(type(event) == "string", "event name must be a string")
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
	if addRecord(list, self, handler) then
		retain(event)
	end
end

function EventMixin:UnregisterUnitEvent(event, unit, handler)
	local byUnit = unitCallbacks[event]
	if not byUnit then
		return
	end
	local removed = 0
	if unit then
		local list = byUnit[unit]
		if list then
			if handler then
				removed = removeRecord(list, self, resolveHandler(self, event, handler)) and 1 or 0
			else
				removed = removeOwner(list, self)
			end
		end
	else
		for _, list in pairs(byUnit) do
			removed = removed + removeOwner(list, self)
		end
	end
	for _ = 1, removed do
		release(event)
	end
end

function EventMixin:UnregisterAllEvents()
	for event, list in pairs(callbacks) do
		for _ = 1, removeOwner(list, self) do
			release(event)
		end
	end
	for event, byUnit in pairs(unitCallbacks) do
		for _, list in pairs(byUnit) do
			for _ = 1, removeOwner(list, self) do
				release(event)
			end
		end
	end
end

function EventMixin:IsEventRegistered(event)
	local list = callbacks[event]
	if list and findRecordForOwner(list, self) then
		return true
	end
	local byUnit = unitCallbacks[event]
	if byUnit then
		for _, unitList in pairs(byUnit) do
			if findRecordForOwner(unitList, self) then
				return true
			end
		end
	end
	return false
end

function ns:Fire(event, ...)
	local list = callbacks[event]
	if list then
		fireList(list, ...)
	end
	local byUnit = unitCallbacks[event]
	if byUnit then
		local unitList = byUnit[(...)]
		if unitList then
			fireList(unitList, ...)
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
		waiters[i]()
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
