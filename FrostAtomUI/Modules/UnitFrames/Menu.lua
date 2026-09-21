local ADDON_NAME, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local ToggleDropDownMenu = ToggleDropDownMenu
local UnitPopup_ShowMenu = UnitPopup_ShowMenu
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitInParty = UnitInParty
local GetNumRaidMembers = GetNumRaidMembers
local GetRaidRosterInfo = GetRaidRosterInfo

local function raidIndex(unit)
	for i = 1, GetNumRaidMembers() do
		if UnitIsUnit(unit, "raid" .. i) then
			return i
		end
	end
end

local function menuFor(unit)
	if UnitIsUnit(unit, "player") then
		return "SELF"
	elseif UnitIsUnit(unit, "vehicle") then
		return "VEHICLE"
	elseif UnitIsUnit(unit, "pet") then
		return "PET"
	elseif UnitIsPlayer(unit) then
		local index = raidIndex(unit)
		if index then
			return "RAID_PLAYER", GetRaidRosterInfo(index), index
		elseif UnitInParty(unit) then
			return "PARTY"
		else
			return "PLAYER"
		end
	else
		return "TARGET", RAID_TARGET_ICON
	end
end

local dropdown = CreateFrame("Frame", ADDON_NAME .. "UnitFrameDropDown", UIParent, "UIDropDownMenuTemplate")

UIDropDownMenu_Initialize(dropdown, function(self)
	local unit = self.sourceUnit
	if not unit then
		return
	end

	local menu, name, userData = menuFor(unit)
	UnitPopup_ShowMenu(self, menu, unit, name, userData)
end, "MENU")

function UF.FrameMixin:menu()
	dropdown.sourceUnit = self.unit
	ToggleDropDownMenu(1, nil, dropdown, "cursor")
end
