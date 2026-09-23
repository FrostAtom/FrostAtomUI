local _, ns = ...

local DestroyFrame = ns.DestroyFrame
local noop = ns.noop
local ActionBar = ns:GetModule("ActionBar")

local BUTTON_PREFIXES = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"BonusActionButton",
}

local MANAGED_POSITIONS = {
	"MultiBarBottomLeft",
	"MultiBarRight",
	"ShapeshiftBarFrame",
	"PossessBarFrame",
	"MultiCastActionBarFrame",
	"PETACTIONBAR_YPOS",
	"MULTICASTACTIONBAR_YPOS",
}

local MICRO_BUTTONS = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"SocialsMicroButton",
	"PVPMicroButton",
	"LFDMicroButton",
	"MainMenuMicroButton",
	"HelpMicroButton",
}

local BACKPACK_SIZE = 32
local BACKPACK_BORDER_SIZE = BACKPACK_SIZE * 64 / 36
local MICRO_MENU_WIDTH = 252
local MICRO_MENU_HEIGHT = 40

local function detachTalentFrame()
	PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

function ActionBar:HideBlizzard()
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

	for _, frame in ipairs({
		MainMenuBar,
		MainMenuExpBar,
		ReputationWatchBar,
		BonusActionBarFrame,
		PossessBarFrame,
		PetActionBarFrame,
		VehicleMenuBar,
		MainMenuBarArtFrame,
	}) do
		DestroyFrame(frame)
	end
	MainMenuBarArtFrame:RegisterEvent("KNOWN_CURRENCY_TYPES_UPDATE")
	MainMenuBarArtFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

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

	if PlayerTalentFrame then
		detachTalentFrame()
	else
		hooksecurefunc("TalentFrame_LoadUI", detachTalentFrame)
	end

	for _, key in ipairs(MANAGED_POSITIONS) do
		UIPARENT_MANAGED_FRAME_POSITIONS[key] = nil
	end

	KeyRingButton:SetParent(UIParent)

	for i = 0, NUM_BAG_SLOTS - 1 do
		DestroyFrame(_G["CharacterBag" .. i .. "Slot"])
	end

	local microMenu = CreateFrame("Frame", "FrostAtomUIMicroMenu", UIParent)
	microMenu:SetSize(MICRO_MENU_WIDTH, MICRO_MENU_HEIGHT)
	for _, name in ipairs(MICRO_BUTTONS) do
		_G[name]:SetParent(microMenu)
	end
	CharacterMicroButton:ClearAllPoints()
	CharacterMicroButton:SetPoint("BOTTOMLEFT", microMenu, "BOTTOMLEFT", 0, 0)
	self:AnchorToConfig(microMenu, "actionBar.microMenu", "Micro menu", {
		resize = {
			minWidth = MICRO_MENU_WIDTH / 2,
			maxWidth = MICRO_MENU_WIDTH * 2,
			get = function()
				return MICRO_MENU_WIDTH * ns.Config.actionBar.microMenuScale, MICRO_MENU_HEIGHT
			end,
			set = function(width)
				ns:SetConfig("actionBar.microMenuScale", width / MICRO_MENU_WIDTH)
			end,
		},
	})

	MainMenuBarBackpackButton:SetParent(UIParent)
	MainMenuBarBackpackButton:SetSize(BACKPACK_SIZE, BACKPACK_SIZE)
	MainMenuBarBackpackButtonNormalTexture:SetSize(BACKPACK_BORDER_SIZE, BACKPACK_BORDER_SIZE)
	self:AnchorToConfig(MainMenuBarBackpackButton, "actionBar.bagButton", "Bag button")

	local microMenuFader = ns.CreateFader({ microMenu })
	local bagFader = ns.CreateFader({ MainMenuBarBackpackButton })

	local function applyMenus(_, path)
		local config = ns.Config.actionBar
		ns.Movers.SetScale(microMenu, config.microMenuScale, path == "actionBar.microMenuScale")
		microMenuFader:Configure(config.microMenuMouseover, config.menuFadeAlpha)
		bagFader:Configure(config.bagButtonMouseover, config.menuFadeAlpha)
	end
	applyMenus()
	self:WatchConfig("actionBar", applyMenus)
end
