local _, ns = ...
local L = ns.L

local RegisterStateDriver = RegisterStateDriver
local GameTooltip = GameTooltip
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetCursorInfo = GetCursorInfo
local InCombatLockdown = InCombatLockdown
local max, min, ceil = math.max, math.min, math.ceil

local Media = ns.Media
local ActionBar = ns:NewModule("ActionBar")
ActionBar.configKey = "actionBar"

local config = ns.Config.actionBar
local BUTTONS_PER_BAR = 12
local NUM_BARS = 6
local BAR_KEYS = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "stance", "pet" }
local EQUIPPED_BORDER_SCALE = 62 / 36
local AUTOCAST_BORDER_SCALE = 58 / 30

local PAGE_BINDINGS = {
	[1] = "ACTIONBUTTON%d",
	[3] = "MULTIACTIONBAR3BUTTON%d",
	[4] = "MULTIACTIONBAR4BUTTON%d",
	[5] = "MULTIACTIONBAR2BUTTON%d",
	[6] = "MULTIACTIONBAR1BUTTON%d",
}

ActionBar.NUM_BARS = NUM_BARS

ActionBar.bars = {}
ActionBar.petButtons = {}
ActionBar.shapeshiftButtons = {}

function ActionBar:StyleButton(button)
	button:SetNormalTexture(Media.buttonNormal)
	button:GetNormalTexture():SetAllPoints()
	button:SetHighlightTexture(Media.buttonHighlight)
	button:HookScript("OnClick", self.PlayClickAnimation)

	button.checkedTexture = button:CreateTexture(nil, "OVERLAY")
	button.checkedTexture:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	button.checkedTexture:SetBlendMode("ADD")
	button.checkedTexture:SetAllPoints()
	button.checkedTexture:Hide()

	button.equippedTexture = button:CreateTexture(nil, "OVERLAY")
	button.equippedTexture:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	button.equippedTexture:SetBlendMode("ADD")
	button.equippedTexture:SetVertexColor(0, 1, 0, 0.35)
	button.equippedTexture:SetPoint("CENTER")
	button.equippedTexture:Hide()
end

function ActionBar:SetButtonColors(button, shade)
	button.icon:SetVertexColor(shade, shade, shade)
	button:GetNormalTexture():SetVertexColor(shade, shade, shade)
end

function ActionBar:SetButtonChecked(button, checked)
	if checked then
		button.checkedTexture:Show()
	else
		button.checkedTexture:Hide()
	end
end

function ActionBar:SetButtonEquipped(button, equipped)
	if equipped then
		button.equippedTexture:Show()
	else
		button.equippedTexture:Hide()
	end
end

function ActionBar:StyleHotkey(hotkey)
	ns.SetFont(hotkey, config.hotkeyFont.size, config.hotkeyFont.outline)
	hotkey:SetAlpha(config.showHotkeys and 1 or 0)
end

local TOOLTIP_REFRESH_INTERVAL = 0.2

local tooltipRefresher = CreateFrame("Frame")
tooltipRefresher:Hide()
tooltipRefresher:SetScript("OnUpdate", function(self, elapsed)
	self.timer = self.timer - elapsed
	if self.timer <= 0 then
		self.timer = TOOLTIP_REFRESH_INTERVAL
		self.button.setTooltip(self.button)
	end
end)

local function onTooltipEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	button.setTooltip(button)
	tooltipRefresher.button = button
	tooltipRefresher.timer = TOOLTIP_REFRESH_INTERVAL
	tooltipRefresher:Show()
end

local function onTooltipLeave()
	tooltipRefresher:Hide()
	tooltipRefresher.button = nil
	GameTooltip:Hide()
end

function ActionBar:AttachTooltip(button, setTooltip)
	button.setTooltip = setTooltip
	button:SetScript("OnEnter", onTooltipEnter)
	button:SetScript("OnLeave", onTooltipLeave)
end

local function cursorHoldsAction()
	return GetCursorInfo() ~= nil
end

local function createBarFrame(buttons)
	local bar = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	bar.fader = ns.CreateFader({ bar }, nil, cursorHoldsAction)
	bar.fader:SetMouseFrames(buttons)
	bar.buttons = buttons
	return bar
end

function ActionBar:CreateBar(page, onButtonCreated)
	local bar = createBarFrame({})
	bar.limited = true
	local firstAction = (page - 1) * BUTTONS_PER_BAR
	local blizzardBinding = PAGE_BINDINGS[page]

	for i = 1, BUTTONS_PER_BAR do
		local button = self:CreateActionButton(firstAction + i, bar)
		if blizzardBinding then
			button.blizzardBinding = blizzardBinding:format(i)
			self.UpdateHotkey(button)
		end
		bar.buttons[i] = button
		if onButtonCreated then
			onButtonCreated(button, i)
		end
	end

	self.bars[page] = bar
	return bar
end

local CLASS_PAGE_CONDITIONS = {
	WARRIOR = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;",
	DRUID = "[bonusbar:1,stealth] 8; [bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10;",
	ROGUE = "[bonusbar:1] 7; [bonusbar:2] 8;",
	PRIEST = "[bonusbar:1] 7;",
}

local classPageCondition = CLASS_PAGE_CONDITIONS[ns.PLAYER_CLASS]
local PAGE_DRIVER_CONDITION = "[vehicleui] 11; [bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
	.. (classPageCondition and classPageCondition .. " " or "")
	.. "1"

local PAGE_CHANGED_SNIPPET = [[
	self:SetAttribute("action", (message - 1) * 12 + self:GetAttribute("id"))
]]

local function setupPagedButton(button, index)
	button:SetAttribute("id", index)
	button:SetAttribute("_childupdate-page", PAGE_CHANGED_SNIPPET)
end

local function layoutBar(bar, barConfig, count, path)
	local size, gap = barConfig.buttonSize, barConfig.spacing
	local slot = size + gap
	local columns = max(min(barConfig.columns, count), 1)
	local rows = max(ceil(count / columns), 1)
	local buttons = bar.buttons

	for i = 1, #buttons do
		local button = buttons[i]
		if i <= count then
			button:SetSize(size, size)
			button.equippedTexture:SetSize(size * EQUIPPED_BORDER_SCALE, size * EQUIPPED_BORDER_SCALE)
			if button.autoCastable then
				button.autoCastable:SetSize(size * AUTOCAST_BORDER_SCALE, size * AUTOCAST_BORDER_SCALE)
			end
			button:ClearAllPoints()
			button:SetPoint(ns.GridPoint("BOTTOMLEFT", i, columns, slot))
			if bar.limited then
				button:Show()
			end
		elseif bar.limited then
			button:Hide()
		end
	end

	bar:SetSize(columns * slot - gap, rows * slot - gap)
	ns.ApplyPoint(bar, path)
	bar.fader:Configure(barConfig.mouseover, barConfig.fadeAlpha, barConfig.combat)
	if barConfig.enabled ~= nil then
		if barConfig.enabled then
			bar:Show()
		else
			bar:Hide()
		end
	end
end

function ActionBar:LayoutBar(key)
	local barConfig = config[key]
	local path = "actionBar." .. key .. ".point"
	if key == "vehicleExit" then
		self:LayoutVehicleExit()
	elseif key == "totemBar" then
		self:LayoutTotemBar()
	elseif key == "pet" then
		layoutBar(self.petBar, barConfig, #self.petButtons, path)
	elseif key == "stance" then
		layoutBar(self.stanceBar, barConfig, GetNumShapeshiftForms(), path)
	else
		local bar = self.bars[tonumber(key:match("%d+"))]
		layoutBar(bar, barConfig, barConfig.buttons, path)
	end
end

function ActionBar:StyleButtons()
	for page = 1, NUM_BARS do
		for _, button in ipairs(self.bars[page].buttons) do
			self:StyleHotkey(button.hotkey)
			button:RegisterForDrag(config.dragButton)
			button:UpdateColors()
			ns.SetFont(button.name, config.nameFont.size, config.nameFont.outline)
			ns.SetFont(button.count, config.countFont.size, config.countFont.outline)
			ns.SetFont(button.cooldown.timer, config.cooldownFont.size, config.cooldownFont.outline)
			if config.showNames then
				button.name:Show()
			else
				button.name:Hide()
			end
			if config.showCounts then
				button.count:Show()
			else
				button.count:Hide()
			end
		end
	end
	self:StylePetButtons()
	for i = 1, #self.shapeshiftButtons do
		self:StyleShapeshiftHotkey(self.shapeshiftButtons[i].hotkey)
	end
end

function ActionBar:Layout(path)
	local key = path and path:match("^actionBar%.(%w+)%.")
	if key and type(config[key]) == "table" and config[key].buttonSize then
		self:LayoutBar(key)
		return
	end
	for _, barKey in ipairs(BAR_KEYS) do
		self:LayoutBar(barKey)
	end
	self:LayoutVehicleExit()
	self:LayoutTotemBar()
	self:StyleButtons()
	self:UpdateLockoutTracking()
end

function ActionBar:Initialize()
	self:HideBlizzard()

	local bar1 = self:CreateBar(1, setupPagedButton)
	bar1:SetAttribute("_onstate-page", [[ control:ChildUpdate("page", newstate) ]])
	RegisterStateDriver(bar1, "page", PAGE_DRIVER_CONDITION)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		if not InCombatLockdown() then
			RegisterStateDriver(bar1, "page", PAGE_DRIVER_CONDITION)
		end
	end)

	for page = 2, NUM_BARS do
		self:CreateBar(page)
	end

	self.stanceBar = createBarFrame(self.shapeshiftButtons)
	self.petBar = createBarFrame(self.petButtons)
	self:InitializeShapeshiftBar(self.stanceBar)
	self:InitializePetBar(self.petBar)
	self:InitializeVehicleExit()
	self:InitializeTotemBar()

	self:Layout()
	self:WatchConfig("actionBar", self.Layout, true)

	local function layoutStance()
		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", layoutStance)
			return
		end
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", layoutStance)
		self:LayoutBar("stance")
	end
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", layoutStance)
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", layoutStance)
	self:RegisterEvent("CHARACTER_POINTS_CHANGED", layoutStance)

	self:InitializeOverrideBindings()

	for page = 1, NUM_BARS do
		self:RegisterMover(
			self.bars[page],
			"actionBar.bar" .. page .. ".point",
			L["Action bar %d"]:format(page),
			{ secure = true }
		)
	end
	self:RegisterMover(self.stanceBar, "actionBar.stance.point", "Stance bar", { secure = true })
	self:RegisterMover(self.petBar, "actionBar.pet.point", "Pet bar", { secure = true })
end
