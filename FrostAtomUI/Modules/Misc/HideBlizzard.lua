local _, ns = ...

local DestroyFrame = ns.DestroyFrame
local noop = ns.noop
local HideBlizzard = ns:NewModule("HideBlizzard")

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
local MICRO_BUTTON_WIDTH = 28
local MICRO_BUTTON_HEIGHT = 58
local MICRO_BUTTON_SPACING = -3
local MICRO_MENU_HEIGHT = 40

local function detachTalentFrame()
	PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

local microMenu, microMenuResize
local microButtons = {}
local microButtonIndex = {}

local function microMenuWidth()
	local count = max(#microButtons, 1)
	return count * MICRO_BUTTON_WIDTH + (count - 1) * MICRO_BUTTON_SPACING
end

local function isMicroButton(frame)
	if microButtonIndex[frame] or frame == microMenu or not frame:IsObjectType("Button") then
		return false
	end
	local name = frame:GetName()
	if name and name:find("MicroButton$") then
		return true
	end
	return floor(frame:GetWidth() + 0.5) == MICRO_BUTTON_WIDTH and floor(frame:GetHeight() + 0.5) == MICRO_BUTTON_HEIGHT
end

local function addMicroButton(button)
	local _, relativeTo = button:GetPoint(1)
	local position = #microButtons + 1
	for i, known in ipairs(microButtons) do
		if known == relativeTo then
			position = i + 1
			break
		end
	end
	table.insert(microButtons, position, button)
	microButtonIndex[button] = true
end

local function collectMicroButtons(parent, found)
	if not parent then
		return
	end
	for _, child in ipairs({ parent:GetChildren() }) do
		if isMicroButton(child) then
			found[#found + 1] = child
		end
	end
end

local function layoutMicroMenu()
	if InCombatLockdown() then
		HideBlizzard:RegisterEvent("PLAYER_REGEN_ENABLED", layoutMicroMenu)
		return
	end
	HideBlizzard:UnregisterEvent("PLAYER_REGEN_ENABLED", layoutMicroMenu)

	local found = {}
	collectMicroButtons(MainMenuBarArtFrame, found)
	collectMicroButtons(VehicleMenuBarArtFrame, found)
	collectMicroButtons(MainMenuBar, found)
	collectMicroButtons(microMenu, found)
	while #found > 0 do
		local index = 1
		for i, button in ipairs(found) do
			local _, relativeTo = button:GetPoint(1)
			if relativeTo and microButtonIndex[relativeTo] then
				index = i
				break
			end
		end
		addMicroButton(tremove(found, index))
	end

	for i, button in ipairs(microButtons) do
		if button:GetParent() ~= microMenu then
			button:SetParent(microMenu)
			button:Show()
		end
		button:ClearAllPoints()
		button:SetPoint("BOTTOMLEFT", microMenu, "BOTTOMLEFT", (i - 1) * (MICRO_BUTTON_WIDTH + MICRO_BUTTON_SPACING), 0)
	end

	local width = microMenuWidth()
	microMenu:SetSize(width, MICRO_MENU_HEIGHT)
	microMenuResize.minWidth = width / 2
	microMenuResize.maxWidth = width * 2
end

local function createMenus(module)
	microMenu = CreateFrame("Frame", "FrostAtomUIMicroMenu", UIParent)
	microMenuResize = {
		get = function()
			return microMenuWidth() * ns.Config.actionBar.microMenuScale, MICRO_MENU_HEIGHT
		end,
		set = function(width)
			ns:SetConfig("actionBar.microMenuScale", width / microMenuWidth())
		end,
	}
	for _, name in ipairs(MICRO_BUTTONS) do
		local button = _G[name]
		if button then
			microButtons[#microButtons + 1] = button
			microButtonIndex[button] = true
		end
	end
	layoutMicroMenu()
	hooksecurefunc("UpdateMicroButtons", layoutMicroMenu)
	module:AnchorToConfig(microMenu, "actionBar.microMenu", "Micro menu", {
		secure = true,
		resize = microMenuResize,
	})

	MainMenuBarBackpackButton:SetParent(UIParent)
	MainMenuBarBackpackButton:SetSize(BACKPACK_SIZE, BACKPACK_SIZE)
	MainMenuBarBackpackButtonNormalTexture:SetSize(BACKPACK_BORDER_SIZE, BACKPACK_BORDER_SIZE)
	module:AnchorToConfig(MainMenuBarBackpackButton, "actionBar.bagButton", "Bag button")

	local microMenuFader = ns.CreateFader({ microMenu })
	local bagFader = ns.CreateFader({ MainMenuBarBackpackButton })

	local function applyMicroMenuScale(_, path)
		ns.Movers.SetScale(microMenu, ns.Config.actionBar.microMenuScale, path == "actionBar.microMenuScale")
	end
	applyMicroMenuScale()
	module:WatchConfig("actionBar.microMenuScale", applyMicroMenuScale, true)

	local function applyMenus()
		local config = ns.Config.actionBar
		microMenuFader:Configure(config.microMenuMouseover, config.menuFadeAlpha, config.microMenuCombat)
		bagFader:Configure(config.bagButtonMouseover, config.menuFadeAlpha, config.bagButtonCombat)
	end
	applyMenus()
	module:WatchConfig("actionBar", applyMenus)
end

local function hideActionBars(module)
	InterfaceOptionsActionBarsPanelAlwaysShowActionBars:EnableMouse(false)
	InterfaceOptionsActionBarsPanelAlwaysShowActionBars:SetAlpha(0)
	InterfaceOptionsActionBarsPanelLockActionBars:EnableMouse(false)
	InterfaceOptionsActionBarsPanelLockActionBars:SetAlpha(0)
	InterfaceOptionsStatusTextPanelXP:SetAlpha(0)
	InterfaceOptionsStatusTextPanelXP:SetScale(0.0001)

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

	ns:OnAddonLoaded("Blizzard_TalentUI", detachTalentFrame)

	for _, key in ipairs(MANAGED_POSITIONS) do
		UIPARENT_MANAGED_FRAME_POSITIONS[key] = nil
	end

	KeyRingButton:SetParent(UIParent)

	for i = 0, NUM_BAG_SLOTS - 1 do
		DestroyFrame(_G["CharacterBag" .. i .. "Slot"])
	end

	createMenus(module)
end

local function hideUnitFrames()
	Arena_LoadUI = noop

	DestroyFrame(PlayerFrame, true)
	DestroyFrame(TargetFrame, true)
	DestroyFrame(FocusFrame, true)
	DestroyFrame(ComboFrame, true)
	DestroyFrame(PartyMemberBackground)

	for i = 1, MAX_PARTY_MEMBERS do
		local frame = _G["PartyMemberFrame" .. i]
		DestroyFrame(frame, true)
		hooksecurefunc(frame, "Show", frame.Hide)
		DestroyFrame(_G["PartyMemberFrame" .. i .. "PetFrame"], true)
	end

	ns:GetModule("CVars"):Pin("hidePartyInRaid", "1")
end

local function hideCastBar()
	DestroyFrame(CastingBarFrame)
	UIPARENT_MANAGED_FRAME_POSITIONS.CastingBarFrame = nil
end

local function hideBuffs()
	DestroyFrame(BuffFrame, true)
	DestroyFrame(ConsolidatedBuffs, true)
end

local function hideWeaponEnchants()
	DestroyFrame(TemporaryEnchantFrame, true)
end

local function hideRunes()
	DestroyFrame(RuneFrame, true)
end

local HIDERS = {
	actionBars = hideActionBars,
	unitFrames = hideUnitFrames,
	castBar = hideCastBar,
	buffs = hideBuffs,
	weaponEnchants = hideWeaponEnchants,
	runes = hideRunes,
}

function HideBlizzard:Initialize()
	local config = ns.Config.hideBlizzard
	for key, hide in pairs(HIDERS) do
		if config[key] then
			hide(self)
		end
	end
end
