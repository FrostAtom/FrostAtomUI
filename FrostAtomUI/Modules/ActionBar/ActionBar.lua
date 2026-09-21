local _, ns = ...

local CreateFrame = CreateFrame
local RegisterStateDriver = RegisterStateDriver
local GameTooltip = GameTooltip
local floor = math.floor

local Media = ns.Media
local ActionBar = ns:NewModule("ActionBar")
ActionBar.configKey = "actionBar"

local config = ns.Config.actionBar
local BUTTONS_PER_BAR = 12
local SIDE_BAR_GAP = 12
local NUM_BARS = 5

ActionBar.bars = {}
ActionBar.petButtons = {}
ActionBar.shapeshiftButtons = {}

function ActionBar:StyleButton(button)
	button:SetNormalTexture(Media.buttonNormal)
	button:GetNormalTexture():SetAllPoints()
	button:SetHighlightTexture(Media.buttonHighlight)
	button:HookScript("OnClick", self.PlayClickAnimation)
end

function ActionBar:SetButtonColors(button, iconShade, borderR, borderG, borderB)
	button.icon:SetVertexColor(iconShade, iconShade, iconShade)
	button:GetNormalTexture():SetVertexColor(borderR, borderG, borderB)
end

function ActionBar:StyleHotkey(hotkey)
	hotkey:SetFont(Media.font, config.hotkeyFont.size, config.hotkeyFont.outline)
	if config.showHotkeys then
		hotkey:SetAlpha(1)
	else
		hotkey:SetAlpha(0)
	end
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

local function rowPoint(i, slot)
	return "BOTTOM", slot / 2 + (i - 7) * slot, 0
end

local function squarePoint(i, slot)
	local row = floor((i - 1) / 4)
	return "BOTTOM", slot / 2 + (i % 4 - 2) * slot, row * slot
end

function ActionBar:CreateBar(page, pointFunc, onButtonCreated)
	local bar = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	bar.pointFunc = pointFunc
	bar.buttons = {}
	local firstAction = (page - 1) * BUTTONS_PER_BAR

	for i = 1, BUTTONS_PER_BAR do
		local button = self:CreateActionButton(firstAction + i, bar)
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
	ROGUE = "[bonusbar:1] 7;",
	PRIEST = "[bonusbar:1] 7;",
}

local classPageCondition = CLASS_PAGE_CONDITIONS[ns.PLAYER_CLASS]
local PAGE_DRIVER_CONDITION = "[vehicleui] 11; [bonusbar:5] 11; "
	.. (classPageCondition and classPageCondition .. " " or "")
	.. "1"

local PAGE_CHANGED_SNIPPET = [[
	self:SetAttribute("action", (message - 1) * 12 + self:GetAttribute("id"))
]]

local function setupPagedButton(button, index)
	button:SetAttribute("id", index)
	button:SetAttribute("_childupdate-page", PAGE_CHANGED_SNIPPET)
end

local function layoutSmallBar(buttons, size, gap)
	for i = 1, #buttons do
		local button = buttons[i]
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("BOTTOM", (i - 1) * (size + gap), 0)
	end
end

function ActionBar:Layout()
	local size, gap = config.buttonSize, config.gap
	local slot = size + gap
	local bars = self.bars

	for page = 1, NUM_BARS do
		local bar = bars[page]
		for i, button in ipairs(bar.buttons) do
			button:SetSize(size, size)
			button:ClearAllPoints()
			button:SetPoint(bar.pointFunc(i, slot))
			self:StyleHotkey(button.hotkey)
			button:UpdateColors()
			button.name:SetFont(Media.font, config.nameFont.size, config.nameFont.outline)
			if config.showNames then
				button.name:Show()
			else
				button.name:Hide()
			end
		end
		bar:ClearAllPoints()
		if page > 1 then
			if config["showBar" .. page] then
				bar:Show()
			else
				bar:Hide()
			end
		end
	end

	bars[1]:SetPoint("BOTTOM", 0, config.bottomOffset)
	bars[2]:SetPoint("BOTTOM", bars[1], 0, slot)
	bars[3]:SetPoint("BOTTOM", bars[2], 0, slot)
	bars[4]:SetPoint("BOTTOM", bars[1], -slot * 8 - SIDE_BAR_GAP, 0)
	bars[5]:SetPoint("BOTTOM", bars[1], slot * 8 + SIDE_BAR_GAP, 0)

	self.shapeshiftAnchor:ClearAllPoints()
	self.shapeshiftAnchor:SetPoint("BOTTOM", bars[3], -slot * 5, slot)
	self.petAnchor:ClearAllPoints()
	self.petAnchor:SetPoint("BOTTOM", bars[3], -slot * 2, slot)

	layoutSmallBar(self.petButtons, config.smallButtonSize, gap)
	layoutSmallBar(self.shapeshiftButtons, config.smallButtonSize, gap)
	for i = 1, #self.petButtons do
		self:StyleHotkey(self.petButtons[i].hotkey)
	end
end

local function createSmallBarAnchor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(2, 2)
	return frame
end

function ActionBar:Initialize()
	self:HideBlizzard()

	local bar1 = self:CreateBar(1, rowPoint, setupPagedButton)
	bar1:SetAttribute("_onstate-page", [[ control:ChildUpdate("page", newstate) ]])
	RegisterStateDriver(bar1, "page", PAGE_DRIVER_CONDITION)

	self:CreateBar(2, rowPoint)
	self:CreateBar(3, rowPoint)
	self:CreateBar(4, squarePoint)
	self:CreateBar(5, squarePoint)

	self.shapeshiftAnchor = createSmallBarAnchor()
	self.petAnchor = createSmallBarAnchor()
	self:InitializeShapeshiftBar(self.shapeshiftAnchor)
	self:InitializePetBar(self.petAnchor)

	self:Layout()
	self:WatchConfig("actionBar", self.Layout, true)
end
