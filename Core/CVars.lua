local namespace = select(2,...)

local SetCVar = SetCVar
local tNew,tDel = namespace.tNew,namespace.tDel


local CVars = namespace:New("CVars")

local cvar2value,subEvent2cvar = {},{}

function CVars:CVAR_UPDATE(name,newValue)
	name = subEvent2cvar[name] or name

	local value = cvar2value[name]
	if value and value ~= newValue then
		SetCVar(name,value)
	end
end

function CVars:SetCVar(name,value,event)
	SetCVar(name,value)
	
	cvar2value[name] = value
	if event then
		subEvent2cvar[event] = name
	end
end


function CVars:Initialize()
	self:RegisterEvent("CVAR_UPDATE")
end