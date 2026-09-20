local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local unpack = unpack

local TruncateUTF8 = ns.TruncateUTF8
local NICKNAME = ns.Config.nickname

local function update(frame)
	local unit = frame.unit
	local name = frame.name

	local text
	if NICKNAME and UnitIsUnit(unit, "player") then
		text = NICKNAME
	else
		text = UnitName(unit) or "UNKNOWN"
	end
	name:SetText(name.maxLength and TruncateUTF8(text, name.maxLength) or text)
end

local function create(frame, maxLength)
	local name = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
	name:SetTextColor(unpack(UF.textColor))
	name.maxLength = maxLength

	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)

	return name
end

UF:RegisterElement("name", create, update)
