local _, ns = ...

local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local max, min, ceil, floor = math.max, math.min, math.ceil, math.floor

local ActionBar = ns:GetModule("ActionBar")

local config = ns.Config.actionBar
local BLIZZARD_BUTTON_SIZE = 30
local VISIBILITY_SHOWN = "[vehicleui] hide; show"
local ARROW_WIDTH, ARROW_HEIGHT = 28, 18
local ARROW_HIGHLIGHT_WIDTH, ARROW_HIGHLIGHT_HEIGHT = 20, 11
local FLYOUT_PADDING = 5
local FLYOUT_CLOSE_GAP = 2
local FLYOUT_BACKDROP = ns.CreateBackdrop(14, 3)
local FLYOUT_BACKGROUND_ALPHA = 0.85

local holder, bar
local items = {}
local mouseFrames = {}

local function isFlyoutOpen()
	return MultiCastFlyoutFrame:IsShown()
end

local function sizeArrow(button, width, height)
	height = height or width * ARROW_HEIGHT / ARROW_WIDTH
	button:SetSize(width, height)
	button:GetHighlightTexture():SetSize(
		width * ARROW_HIGHLIGHT_WIDTH / ARROW_WIDTH,
		height * ARROW_HIGHLIGHT_HEIGHT / ARROW_HEIGHT
	)
	return height
end

local function layoutFlyout()
	local flyout = MultiCastFlyoutFrame
	if not flyout:IsShown() or not flyout.buttons then
		return
	end
	local barConfig = config.totemBar
	local size, gap, perColumn = barConfig.flyoutButtonSize, barConfig.flyoutSpacing, barConfig.flyoutRows
	local step = size + gap

	local shown = 0
	for _, button in ipairs(flyout.buttons) do
		if button:IsShown() then
			local column, row = floor(shown / perColumn), shown % perColumn
			button:SetSize(size, size)
			button:ClearAllPoints()
			button:SetPoint("BOTTOMLEFT", flyout, "BOTTOMLEFT", FLYOUT_PADDING + column * step, FLYOUT_PADDING + row * step)
			shown = shown + 1
		end
	end

	local columns, rows = max(ceil(shown / perColumn), 1), max(min(shown, perColumn), 1)
	local close = MultiCastFlyoutFrameCloseButton
	local closeHeight = sizeArrow(close, size)
	close:ClearAllPoints()
	close:SetPoint("TOP", flyout, "TOP", 0, -FLYOUT_PADDING)
	flyout:SetSize(
		columns * step - gap + FLYOUT_PADDING * 2,
		rows * step - gap + FLYOUT_CLOSE_GAP + closeHeight + FLYOUT_PADDING * 2
	)
end

local function sizeOpenButton(button)
	local parent = button:GetParent()
	sizeArrow(button, parent:GetWidth(), parent:GetHeight())
end

local function skinFlyout()
	local flyout = MultiCastFlyoutFrame
	flyout.top:Hide()
	flyout.middle:Hide()
	flyout:SetBackdrop(FLYOUT_BACKDROP)
	flyout:SetBackdropColor(0, 0, 0, FLYOUT_BACKGROUND_ALPHA)
end

local function setBinding(button, blizzardBinding)
	button.bindingName = "CLICK " .. button:GetName() .. ":LeftButton"
	button.blizzardBinding = blizzardBinding
end

local function updateSummonBinding()
	MultiCastSummonSpellButton.blizzardBinding = "MULTICASTSUMMONBUTTON" .. MultiCastSummonSpellButton:GetID()
end

local function placeButton(button, index, columns, slot)
	if button:IsProtected() and InCombatLockdown() then
		return
	end
	local point, x, y = ns.GridPoint("BOTTOMLEFT", index, columns, slot)
	button:ClearAllPoints()
	button:SetPoint(point, bar, point, x, y)
end

local function layoutButtons()
	local combat = InCombatLockdown()
	if combat then
		ActionBar:RegisterEvent("PLAYER_REGEN_ENABLED", layoutButtons)
	else
		ActionBar:UnregisterEvent("PLAYER_REGEN_ENABLED", layoutButtons)
	end

	local barConfig = config.totemBar
	local scale = barConfig.buttonSize / BLIZZARD_BUTTON_SIZE
	local gap = barConfig.spacing / scale
	local slot = BLIZZARD_BUTTON_SIZE + gap

	if not combat then
		bar:SetParent(holder)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", holder)
		bar:SetScale(scale)
		MultiCastFlyoutFrame:SetScale(1 / scale)
	end

	wipe(items)
	if MultiCastSummonSpellButton:IsShown() then
		items[#items + 1] = MultiCastSummonSpellButton
	end
	for i = 1, bar.numActiveSlots or 0 do
		items[#items + 1] = i
	end
	if MultiCastRecallSpellButton:IsShown() then
		items[#items + 1] = MultiCastRecallSpellButton
	end

	local count = max(#items, 1)
	local columns = max(min(barConfig.columns, count), 1)
	local rows = ceil(count / columns)
	for index, item in ipairs(items) do
		if type(item) == "number" then
			placeButton(_G["MultiCastSlotButton" .. item], index, columns, slot)
			for page = 1, NUM_MULTI_CAST_PAGES do
				local id = (page - 1) * NUM_MULTI_CAST_BUTTONS_PER_PAGE + item
				placeButton(_G["MultiCastActionButton" .. id], index, columns, slot)
			end
		else
			placeButton(item, index, columns, slot)
		end
	end

	if combat then
		return
	end
	local width, height = columns * slot - gap, rows * slot - gap
	bar:SetSize(width, height)
	holder:SetSize(width * scale, height * scale)
end

function ActionBar:LayoutTotemBar()
	if not holder then
		return
	end
	local barConfig = config.totemBar
	layoutButtons()
	layoutFlyout()
	ns.ApplyPoint(holder, "actionBar.totemBar.point")
	holder.fader:Configure(barConfig.mouseover, barConfig.fadeAlpha, barConfig.combat)
	RegisterStateDriver(holder, "visibility", barConfig.enabled and VISIBILITY_SHOWN or "hide")
end

function ActionBar:InitializeTotemBar()
	bar = MultiCastActionBarFrame
	if ns.PLAYER_CLASS ~= "SHAMAN" or not bar then
		return
	end

	holder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	holder.fader = ns.CreateFader({ holder }, nil, isFlyoutOpen)

	mouseFrames[1] = MultiCastSummonSpellButton
	mouseFrames[2] = MultiCastRecallSpellButton
	for i = 1, NUM_MULTI_CAST_BUTTONS_PER_PAGE do
		mouseFrames[#mouseFrames + 1] = _G["MultiCastSlotButton" .. i]
	end
	for i = 1, NUM_MULTI_CAST_PAGES * NUM_MULTI_CAST_BUTTONS_PER_PAGE do
		mouseFrames[#mouseFrames + 1] = _G["MultiCastActionButton" .. i]
	end
	holder.fader:SetMouseFrames(mouseFrames)

	for i = 1, NUM_MULTI_CAST_PAGES * NUM_MULTI_CAST_BUTTONS_PER_PAGE do
		setBinding(_G["MultiCastActionButton" .. i], "MULTICASTACTIONBUTTON" .. i)
	end
	setBinding(MultiCastRecallSpellButton, "MULTICASTRECALLBUTTON1")
	setBinding(MultiCastSummonSpellButton)
	updateSummonBinding()
	hooksecurefunc("ChangeMultiCastActionPage", updateSummonBinding)

	bar:SetScript("OnUpdate", nil)
	bar:SetScript("OnShow", nil)
	bar:SetScript("OnHide", nil)
	bar:EnableMouse(false)
	skinFlyout()

	hooksecurefunc("MultiCastActionBarFrame_Update", layoutButtons)
	hooksecurefunc("MultiCastFlyoutFrame_ToggleFlyout", layoutFlyout)
	hooksecurefunc("MultiCastFlyoutFrameOpenButton_Show", sizeOpenButton)

	self:LayoutTotemBar()
	self:RegisterMover(holder, "actionBar.totemBar.point", "Totem bar", { secure = true })
end
