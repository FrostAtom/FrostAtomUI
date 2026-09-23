local ADDON_NAME, ns = ...
local UF = ns:GetModule("UnitFrames")

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

local COPY_NAME_BUTTON = "FROSTATOMUI_COPY_NAME"
local REPORT_AFK_BUTTON = "FROSTATOMUI_REPORT_AFK"

local function fullName(menu)
	local name, server = menu.name, menu.server
	if server and server ~= "" and (not menu.unit or not UnitIsSameServer("player", menu.unit)) then
		return name .. "-" .. server
	end
	return name
end

local function canReportAfk(menu)
	if not UnitInBattleground("player") or GetCVar("enablePVPNotifyAFK") == "0" then
		return false
	end
	local unit = menu.unit
	if unit then
		return not UnitIsUnit(unit, "player") and UnitInBattleground(unit) and not PlayerIsPVPInactive(unit)
	end
	local name = menu.name
	return name ~= nil and name ~= UnitName("player") and UnitInBattleground(name) ~= nil
end

local function addCopyName(which)
	local buttons = UnitPopupMenus[which]
	for i = #buttons, 1, -1 do
		if buttons[i] == "CANCEL" then
			tinsert(buttons, i, COPY_NAME_BUTTON)
			return
		end
	end
	buttons[#buttons + 1] = COPY_NAME_BUTTON
end

local function replaceReportAfk(which)
	local buttons = UnitPopupMenus[which]
	for i = 1, #buttons do
		if buttons[i] == "PVP_REPORT_AFK" then
			buttons[i] = REPORT_AFK_BUTTON
		end
	end
end

local function onHideButtons()
	local menu = UIDROPDOWNMENU_INIT_MENU
	local buttons = menu and UnitPopupMenus[menu.which]
	if not buttons then
		return
	end
	local shown = UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL]
	for i = 1, #buttons do
		local value = buttons[i]
		if value == COPY_NAME_BUTTON then
			if not menu.name or menu.name == UnitName("player") then
				shown[i] = 0
			end
		elseif value == REPORT_AFK_BUTTON then
			if not canReportAfk(menu) then
				shown[i] = 0
			end
		end
	end
end

local function onPopupClick(self)
	local value = self.value
	if value ~= COPY_NAME_BUTTON and value ~= REPORT_AFK_BUTTON then
		return
	end
	local name = fullName(UIDROPDOWNMENU_INIT_MENU)
	if value == COPY_NAME_BUTTON then
		ns.ShowCopyPopup(name)
	else
		local dialog = StaticPopup_Show("FROSTATOMUI_REPORT_AFK", name)
		if dialog then
			dialog.data = name
		end
	end
end

StaticPopupDialogs.FROSTATOMUI_REPORT_AFK = {
	text = "Report %s as away from keyboard?",
	button1 = YES,
	button2 = NO,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnAccept = function(_, name)
		ReportPlayerIsPVPAFK(name)
	end,
}

UnitPopupButtons[COPY_NAME_BUTTON] = { text = COPY_NAME, dist = 0 }
UnitPopupButtons[REPORT_AFK_BUTTON] = { text = PVP_REPORT_AFK, dist = 0 }

for _, which in ipairs({ "FRIEND", "FRIEND_OFFLINE", "TEAM", "CHAT_ROSTER" }) do
	addCopyName(which)
end
replaceReportAfk("FRIEND")

hooksecurefunc("UnitPopup_HideButtons", onHideButtons)
hooksecurefunc("UnitPopup_OnClick", onPopupClick)

ns.OnLocaleReady(function()
	StaticPopupDialogs.FROSTATOMUI_REPORT_AFK.text = ns.L["Report %s as away from keyboard?"]
end)

UF:OnInitialize(function()
	for _, which in ipairs({ "PLAYER", "PARTY", "RAID_PLAYER" }) do
		addCopyName(which)
	end
	for _, which in ipairs({ "PARTY", "RAID_PLAYER", "RAID" }) do
		replaceReportAfk(which)
	end
end)
