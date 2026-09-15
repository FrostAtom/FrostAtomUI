local namespace = select(2,...)

local _G = _G

local destroyObject = namespace.destroyObject


InterfaceOptionsActionBarsPanelAlwaysShowActionBars:EnableMouse(false)
InterfaceOptionsActionBarsPanelAlwaysShowActionBars:SetAlpha(0)

InterfaceOptionsActionBarsPanelLockActionBars:EnableMouse(false)
InterfaceOptionsActionBarsPanelLockActionBars:SetAlpha(0)

InterfaceOptionsStatusTextPanelXP:SetAlpha(0)
InterfaceOptionsStatusTextPanelXP:SetScale(0.0001)

MultiCastActionBarFrame.ignoreFramePositionManager = true
MultiBarBottomLeft.Show = namespace.null
MultiBarBottomLeft.Hide = namespace.null
MultiBarBottomRight.Hide = namespace.null
MultiBarBottomRight.Show = namespace.null
MultiBarLeft.Show = namespace.null
MultiBarLeft.Hide = namespace.null
MultiBarRight.Show = namespace.null
MultiBarRight.Hide = namespace.null
MainMenuBarVehicleLeaveButton_Update = namespace.null

destroyObject(MainMenuBar)
destroyObject(MainMenuExpBar)
destroyObject(ReputationWatchBar)
destroyObject(BonusActionBarFrame)
destroyObject(PossessBarFrame)
destroyObject(PetActionBarFrame)
destroyObject(VehicleMenuBar)
destroyObject(PossessBarFrame)
destroyObject(MainMenuBarArtFrame)
MainMenuBarArtFrame:RegisterEvent("KNOWN_CURRENCY_TYPES_UPDATE")
MainMenuBarArtFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")


for i = 1, 12 do
	destroyObject(_G["ActionButton"..i])
	destroyObject(_G["MultiBarBottomLeftButton"..i])
	destroyObject(_G["MultiBarBottomRightButton"..i])
	destroyObject(_G["MultiBarRightButton"..i])
	destroyObject(_G["MultiBarLeftButton"..i])
	destroyObject(_G["BonusActionButton"..i])

	if i <= VEHICLE_MAX_ACTIONBUTTONS then
		destroyObject(_G["VehicleMenuBarActionButton"..i])
	end
end

if PlayerTalentFrame then
	PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
else
	hooksecurefunc("TalentFrame_LoadUI", function() PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED") end)
end


if select(2,UnitClass("player")) ~= "SHAMAN" then
	destroyObject(MultiCastActionBarFrame)
	for i = 1,12 do
		destroyObject(_G["MultiCastActionButton"..i])
	end
end


do
	local tbl = {
		"MultiBarBottomLeft",
		"MultiBarRight",
		"ShapeshiftBarFrame",
		"PossessBarFrame",
		"MultiCastActionBarFrame",
		"PETACTIONBAR_YPOS",
		"MULTICASTACTIONBAR_YPOS"
	}

	local UIPARENT_MANAGED_FRAME_POSITIONS = UIPARENT_MANAGED_FRAME_POSITIONS
	for i = 1,#tbl do
		UIPARENT_MANAGED_FRAME_POSITIONS[tbl[i]] = nil
	end
end