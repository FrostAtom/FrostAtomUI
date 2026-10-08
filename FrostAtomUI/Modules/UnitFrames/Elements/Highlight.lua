local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitIsUnit = UnitIsUnit

local config = ns.Config.unitFrames

local BORDER_COLOR_KEYS = { target = "targetBorderColor", focus = "focusBorderColor" }

local function setHighlight(frame, kind)
	local key = BORDER_COLOR_KEYS[kind]
	local color = key and config[key] or ns.Config.theme.borderColor
	frame:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
end

local function update(frame)
	local unit = frame.unit
	local kind
	if UnitIsUnit(unit, "target") then
		kind = "target"
	elseif UnitIsUnit(unit, "focus") then
		kind = "focus"
	end
	setHighlight(frame, kind)
end

local TEST_KINDS = { "target", "focus", false, false, false, false }

local function test(frame)
	setHighlight(frame, TEST_KINDS[math.random(#TEST_KINDS)])
end

local function create(frame)
	frame:RegisterEvent("PLAYER_TARGET_CHANGED", update)
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED", update)
	return true
end

UF:RegisterElement({ name = "highlight", Create = create, Update = update, Test = test })
