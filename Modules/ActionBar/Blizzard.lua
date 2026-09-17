local _, ns = ...

local DestroyFrame = ns.DestroyFrame
local noop = ns.noop

InterfaceOptionsActionBarsPanelAlwaysShowActionBars:EnableMouse(false)
InterfaceOptionsActionBarsPanelAlwaysShowActionBars:SetAlpha(0)
InterfaceOptionsActionBarsPanelLockActionBars:EnableMouse(false)
InterfaceOptionsActionBarsPanelLockActionBars:SetAlpha(0)
InterfaceOptionsStatusTextPanelXP:SetAlpha(0)
InterfaceOptionsStatusTextPanelXP:SetScale(0.0001)

MultiCastActionBarFrame.ignoreFramePositionManager = true
MainMenuBarVehicleLeaveButton_Update = noop

for _, bar in ipairs({ MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight }) do
	bar.Show = noop
	bar.Hide = noop
end

DestroyFrame(MainMenuBar)
DestroyFrame(MainMenuExpBar)
DestroyFrame(ReputationWatchBar)
DestroyFrame(BonusActionBarFrame)
DestroyFrame(PossessBarFrame)
DestroyFrame(PetActionBarFrame)
DestroyFrame(VehicleMenuBar)
DestroyFrame(MainMenuBarArtFrame)
MainMenuBarArtFrame:RegisterEvent("KNOWN_CURRENCY_TYPES_UPDATE")
MainMenuBarArtFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

local BUTTON_PREFIXES = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"BonusActionButton",
}

for i = 1, NUM_ACTIONBAR_BUTTONS do
	for _, prefix in ipairs(BUTTON_PREFIXES) do
		DestroyFrame(_G[prefix .. i])
	end
end

for i = 1, VEHICLE_MAX_ACTIONBUTTONS do
	DestroyFrame(_G["VehicleMenuBarActionButton" .. i])
end

if ns.PLAYER_CLASS ~= "SHAMAN" then
	DestroyFrame(MultiCastActionBarFrame)
	for i = 1, NUM_ACTIONBAR_BUTTONS do
		DestroyFrame(_G["MultiCastActionButton" .. i])
	end
end

local function detachTalentFrame()
	PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end
if PlayerTalentFrame then
	detachTalentFrame()
else
	hooksecurefunc("TalentFrame_LoadUI", detachTalentFrame)
end

for _, key in ipairs({
	"MultiBarBottomLeft",
	"MultiBarRight",
	"ShapeshiftBarFrame",
	"PossessBarFrame",
	"MultiCastActionBarFrame",
	"PETACTIONBAR_YPOS",
	"MULTICASTACTIONBAR_YPOS",
}) do
	UIPARENT_MANAGED_FRAME_POSITIONS[key] = nil
end

KeyRingButton:SetParent(UIParent)

for i = 0, NUM_BAG_SLOTS - 1 do
	DestroyFrame(_G["CharacterBag" .. i .. "Slot"])
end

for _, button in ipairs({
	CharacterMicroButton,
	SpellbookMicroButton,
	TalentMicroButton,
	AchievementMicroButton,
	QuestLogMicroButton,
	SocialsMicroButton,
	PVPMicroButton,
	LFDMicroButton,
	MainMenuMicroButton,
	HelpMicroButton,
}) do
	button:SetParent(UIParent)
end

CharacterMicroButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMRIGHT", -254, 2)

local BACKPACK_SIZE = 32
MainMenuBarBackpackButton:SetParent(UIParent)
MainMenuBarBackpackButton:SetSize(BACKPACK_SIZE, BACKPACK_SIZE)
MainMenuBarBackpackButton:ClearAllPoints()
MainMenuBarBackpackButton:SetPoint("BOTTOMRIGHT", CharacterMicroButton, "BOTTOMLEFT", -2, 3)
MainMenuBarBackpackButtonNormalTexture:SetSize(BACKPACK_SIZE * 64 / 36, BACKPACK_SIZE * 64 / 36)
