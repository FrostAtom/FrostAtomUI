local namespace = select(2,...)

local assert = assert
local type = type
local error = error
local setmetatable = setmetatable
local tremove = table.remove
local tinsert = tinsert
local tContains = namespace.tContains
local tWipe = namespace.tWipe
local tNew = namespace.tNew
local tDel = namespace.tDel
local tPush = namespace.tPush


local prototype = namespace:GetObjectPrototype()
local frame = CreateFrame("frame")
local callbacks = {}

local callMT = {
	__call = function(tbl,...)
		for i = 1,#tbl do
			tbl[i](...)
		end
	end
}

local GetFreeEventTable = setmetatable({},{
	__call = function(tbl,...)
		return tPush(tremove(tbl) or setmetatable(tNew(),callMT),...)
	end,
})


function prototype:RegisterEvent(event,func)
	assert(event and type(event)=="string")
	func = func or event

	local func_type = type(func)
	if func_type~="function" then
		assert((func_type=="number" or func_type=="string") and type(self[func])=="function")
		func = self[func]
	end

	if callbacks[event] then
		if callbacks[event][self] then
			local callbacks_event_self = callbacks[event][self]
			if type(callbacks_event_self)=="table" then
				if not tContains(callbacks_event_self,func) then
					tinsert(callbacks_event_self,func)
				end
			else
				if callbacks_event_self~=func then
					callbacks[event][self] = GetFreeEventTable(callbacks_event_self,func)
				end
			end
		else
			callbacks[event][self] = func
		end
	else
		local tbl = tNew()
		tbl[self] = func
		callbacks[event] = tbl

		frame:RegisterEvent(event)
	end
end

function prototype:UnregisterEvent(event,func)
	assert(event and type(event)=="string")

	if callbacks[event] and callbacks[event][self] then
		local callbacks_event_self = callbacks[event][self]
		if func then
			local func_type = type(func)
			if func_type~="function" then
				assert((func_type=="number" or func_type=="string") and type(self[func])=="function")
				func = self[func]
			end

			if type(callbacks_event_self)=="table" then
				if tDeleteItem(callbacks_event_self,func) then
					if #callbacks_event_self == 1 then
						callbacks[event][self] = tremove(callbacks_event_self)
						GetFreeEventTable[#GetFreeEventTable+1] = callbacks_event_self
					end
				end
			else
				if func == callbacks_event_self then
					callbacks[event][self] = nil
					if not next(callbacks[event]) then
						callbacks[event] = tDel(callbacks[event])
						frame:UnregisterEvent(event)
					end
				end
			end
		else
			if type(callbacks_event_self)=="table" then
				callbacks[event][self] = tDel(callbacks_event_self)
			else
				callbacks[event][self] = nil
			end

			if not next(callbacks[event]) then
				callbacks[event] = tDel(callbacks[event])
				frame:UnregisterEvent(event)
			end
		end
	end
end

function prototype:UnregisterAllEvents()
	for event,tbl in pairs(callbacks) do
		if tbl[self] then
			if type(tbl[self])=="table" then
				GetFreeEventTable[#GetFreeEventTable+1] = tWipe(tbl[self])
			end
			tbl[self] = nil
		end
	end
end

function prototype:IsEventRegistered(event)
	if callbacks[event] and callbacks[event][self] then
		return 1
	end
end

function namespace:SetEvent(event,...)
	if callbacks[event] then
		for obj,func in pairs(callbacks[event]) do
			func(obj,...)
		end
	end
end

frame:SetScript("OnEvent",namespace.SetEvent)