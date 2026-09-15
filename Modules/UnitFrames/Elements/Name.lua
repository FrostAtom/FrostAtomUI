local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitName = UnitName
local unpack = unpack

local classColors = UF.classColors

-- Shown on the player's own frame instead of the character name.
local PLAYER_NICKNAME = "Cute Boy"

-- Cyrillic letters take two bytes in UTF-8, so allow twice the length for them.
local function truncate(text, maxLength)
	local byteLength = text:find("[\208\209]") and maxLength * 2 or maxLength
	return text:sub(1, byteLength)
end

local function update(frame)
	local unit = frame.unit
	local name = frame.name

	local text
	if UnitIsUnit(unit, "player") then
		text = PLAYER_NICKNAME
	else
		text = UnitName(unit) or "UNKNOWN"
	end
	name:SetText(name.maxLength and truncate(text, name.maxLength) or text)

	local _, class = UnitClass(unit)
	if UnitIsPlayer(unit) and class then
		name:SetTextColor(unpack(classColors[class]))
	else
		name:SetTextColor(unpack(UF.textColor))
	end
end

local function create(frame, maxLength)
	local name = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
	name.maxLength = maxLength

	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)

	return name
end

UF:RegisterElement("name", create, update)
