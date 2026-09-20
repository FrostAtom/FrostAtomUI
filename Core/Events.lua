local _, ns = ...

local tContains, tDeleteItem = ns.tContains, ns.tDeleteItem
local IsAddOnLoaded = IsAddOnLoaded
local pairs, next, type = pairs, next, type

local eventFrame = CreateFrame("Frame")

local callbacks = {}

local function resolveHandler(owner, event, handler)
	handler = handler or event
	if type(handler) ~= "function" then
		local method = owner[handler]
		assert(type(method) == "function", ("no method [%s] for event %s"):format(tostring(handler), event))
		handler = method
	end
	return handler
end

local EventMixin = {}
ns.EventMixin = EventMixin

function EventMixin:RegisterEvent(event, handler)
	assert(type(event) == "string", "event name must be a string")
	handler = resolveHandler(self, event, handler)

	local owners = callbacks[event]
	if not owners then
		owners = {}
		callbacks[event] = owners
		eventFrame:RegisterEvent(event)
	end

	local handlers = owners[self]
	if not handlers then
		owners[self] = { handler }
	elseif not tContains(handlers, handler) then
		handlers[#handlers + 1] = handler
	end
end

function EventMixin:UnregisterEvent(event, handler)
	local owners = callbacks[event]
	local handlers = owners and owners[self]
	if not handlers then
		return
	end

	if handler then
		tDeleteItem(handlers, resolveHandler(self, event, handler))
	end

	if not handler or #handlers == 0 then
		owners[self] = nil
		if not next(owners) then
			callbacks[event] = nil
			eventFrame:UnregisterEvent(event)
		end
	end
end

function EventMixin:UnregisterAllEvents()
	for event, owners in pairs(callbacks) do
		if owners[self] then
			self:UnregisterEvent(event)
		end
	end
end

function EventMixin:IsEventRegistered(event)
	local owners = callbacks[event]
	return owners ~= nil and owners[self] ~= nil
end

function ns:Fire(event, ...)
	local owners = callbacks[event]
	if not owners then
		return
	end

	for owner, handlers in pairs(owners) do
		for i = 1, #handlers do
			local handler = handlers[i]
			if handler then
				handler(owner, ...)
			end
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
