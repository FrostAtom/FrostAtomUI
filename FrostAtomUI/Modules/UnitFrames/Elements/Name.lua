local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local EVENTS = { "UNIT_NAME_UPDATE", "UNIT_FLAGS", "PLAYER_FLAGS_CHANGED", "UNIT_LEVEL", "UNIT_FACTION" }
UF.NAME_EVENTS = EVENTS

local function update(frame)
	UF.UpdateText(frame, frame.name)
end

local function create(frame, template)
	local name = UF.CreateText(frame)
	name.template = template

	for i = 1, #EVENTS do
		frame:RegisterUnitEvent(EVENTS[i], update)
	end

	return name
end

UF:RegisterElement({ name = "name", Create = create, Update = update, Test = update })
