local _, ns = ...

-- Keeps selected CVars pinned to a value: if anything (the options panel,
-- another addon) changes them, the value is immediately restored.

local SetCVar = SetCVar

local CVars = ns:NewModule("CVars")

local pinnedValues = {} -- cvar name -> value
local eventToCVar = {} -- CVAR_UPDATE argument -> cvar name (they differ for some cvars)

-- `updateEvent` is the name CVAR_UPDATE reports for this cvar, when it is not
-- the cvar name itself (e.g. "SHOW_ITEM_LEVEL" for "showItemLevel").
function CVars:Pin(name, value, updateEvent)
	SetCVar(name, value)

	pinnedValues[name] = value
	if updateEvent then
		eventToCVar[updateEvent] = name
	end
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
