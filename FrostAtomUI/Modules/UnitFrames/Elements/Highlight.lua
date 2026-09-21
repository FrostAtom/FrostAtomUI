local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitIsUnit = UnitIsUnit
local unpack = unpack

local config = ns.Config.unitFrames

local function setHighlight(frame, kind)
	if kind == "target" then
		frame:SetBackdropBorderColor(unpack(config.targetBorderColor))
	elseif kind == "focus" then
		frame:SetBackdropBorderColor(unpack(config.focusBorderColor))
	else
		frame:SetBackdropBorderColor(unpack(config.borderColor))
	end
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
	setHighlight(frame, TEST_KINDS[math.random(#TEST_KINDS)] or nil)
end

local function create(frame)
	frame:RegisterEvent("PLAYER_TARGET_CHANGED", update)
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED", update)
	return true
end

UF:RegisterElement("highlight", create, update, test)
