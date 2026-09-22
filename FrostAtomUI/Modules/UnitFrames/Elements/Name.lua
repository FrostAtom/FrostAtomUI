local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local config = ns.Config

local EVENTS = { "UNIT_NAME_UPDATE", "UNIT_FLAGS", "PLAYER_FLAGS_CHANGED", "UNIT_LEVEL", "UNIT_FACTION" }

local function update(frame)
	UF.UpdateText(frame, frame.name, "left")
end

local function create(frame, template)
	local name = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(name, config.unitFrames.textFont.size, config.unitFrames.textFont.outline)
	name:SetTextColor(unpack(UF.textColor))
	name.template = template

	for i = 1, #EVENTS do
		frame:RegisterUnitEvent(EVENTS[i], update)
	end

	return name
end

UF:RegisterElement("name", create, update, update)
