local _, ns = ...

-- Hides Blizzard's own action bars and re-homes the pieces we still use
-- (bags, micro menu).

local DestroyFrame = ns.DestroyFrame
local noop = ns.noop

--------------------------------------------------
-- Options that no longer make sense

InterfaceOptionsActionBarsPanelAlwaysShowActionBars:EnableMouse(false)
InterfaceOptionsActionBarsPanelAlwaysShowActionBars:SetAlpha(0)
InterfaceOptionsActionBarsPanelLockActionBars:EnableMouse(false)
InterfaceOptionsActionBarsPanelLockActionBars:SetAlpha(0)
InterfaceOptionsStatusTextPanelXP:SetAlpha(0)
InterfaceOptionsStatusTextPanelXP:SetScale(0.0001)

--------------------------------------------------
-- Bars

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
-- The art frame still owns the currency (honor/arena points) updates.
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

-- Dual spec swaps would otherwise re-show the bars.
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

--------------------------------------------------
-- Bags: bottom right corner

KeyRingButton:SetParent(UIParent)
MainMenuBarBackpackButton:SetParent(UIParent)
MainMenuBarBackpackButton:SetPoint("BOTTOMRIGHT", -2, 40)

local previous = MainMenuBarBackpackButton
for i = 0, NUM_BAG_SLOTS - 1 do
	local bag = _G["CharacterBag" .. i .. "Slot"]
	bag:SetParent(UIParent)
	bag:ClearAllPoints()
	bag:SetPoint("BOTTOMRIGHT", previous, "BOTTOMLEFT", -3, 0)
	previous = bag
end

--------------------------------------------------
-- Micro menu: bottom right corner, above the bags

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
