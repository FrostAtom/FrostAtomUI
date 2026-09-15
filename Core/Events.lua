local _, ns = ...

-- Central event dispatcher.
--
-- One hidden frame receives every game event the addon is interested in and
-- forwards it to the subscribed owners. Owners are modules or frames that got
-- `ns.EventMixin` mixed in; their handlers are called as `handler(owner, ...)`.
--
-- Custom (non-Blizzard) events can be raised with `ns:Fire(event, ...)`.

local tContains, tDeleteItem = ns.tContains, ns.tDeleteItem

local eventFrame = CreateFrame("Frame")

-- callbacks[event][owner] = { handler1, handler2, ... }
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

-- handler: function, method name, or nil (a method named after the event).
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

-- Without a handler every handler of this owner is removed.
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
			-- A handler may unregister itself while we iterate.
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

ns.Mixin(ns.ModulePrototype, EventMixin)
