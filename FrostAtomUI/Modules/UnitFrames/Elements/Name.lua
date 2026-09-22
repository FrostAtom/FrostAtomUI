local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitName = UnitName

local TruncateUTF8 = ns.TruncateUTF8
local config = ns.Config

local function update(frame)
	local name = frame.name
	local text = UnitName(frame.unit) or "UNKNOWN"
	name:SetText(name.maxLength and TruncateUTF8(text, name.maxLength) or text)
end

local function test(frame)
	local name, text = frame.name, frame.test.name
	name:SetText(name.maxLength and TruncateUTF8(text, name.maxLength) or text)
end

local function create(frame, maxLength)
	local name = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(name, config.unitFrames.textFont.size, config.unitFrames.textFont.outline)
	name:SetTextColor(unpack(UF.textColor))
	name.maxLength = maxLength

	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)

	return name
end

UF:RegisterElement("name", create, update, test)
