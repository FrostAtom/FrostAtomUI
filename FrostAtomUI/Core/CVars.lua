local _, ns = ...

local SetCVar, GetCVarDefault = SetCVar, GetCVarDefault

local CVars = ns:NewModule("CVars")

local pinnedValues = {}
local eventToCVar = {}

function CVars:Pin(name, value, updateEvent)
	SetCVar(name, value)

	pinnedValues[name] = value
	if updateEvent then
		eventToCVar[updateEvent] = name
	end
end

function CVars:Unpin(name)
	if not pinnedValues[name] then
		return
	end
	pinnedValues[name] = nil
	SetCVar(name, GetCVarDefault(name))
end

function CVars:CVAR_UPDATE(name, newValue)
	name = eventToCVar[name] or name

	local pinned = pinnedValues[name]
	if pinned and pinned ~= newValue then
		SetCVar(name, pinned)
	end
end

function CVars:Initialize()
	self:RegisterEvent("CVAR_UPDATE")
end
