local _, ns = ...

local CreateFrame = CreateFrame
local RegisterStateDriver = RegisterStateDriver
local GameTooltip = GameTooltip
local floor = math.floor

local Media = ns.Media
local ActionBar = ns:NewModule("ActionBar")

local BUTTONS_PER_BAR = 12
local BUTTON_SIZE = 36
local BUTTON_GAP = 2
local SLOT = BUTTON_SIZE + BUTTON_GAP

ActionBar.BUTTON_SIZE = BUTTON_SIZE
ActionBar.SMALL_BUTTON_SIZE = 30
ActionBar.BUTTON_GAP = BUTTON_GAP

function ActionBar:StyleButton(button, size)
	button:SetSize(size, size)
	button:SetNormalTexture(Media.buttonNormal)
	button:GetNormalTexture():SetAllPoints()
	button:SetHighlightTexture(Media.buttonHighlight)
	button:HookScript("OnClick", self.PlayClickAnimation)
end

function ActionBar:SetButtonColors(button, iconShade, borderR, borderG, borderB)
	button.icon:SetVertexColor(iconShade, iconShade, iconShade)
	button:GetNormalTexture():SetVertexColor(borderR, borderG, borderB)
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

local function rowPoint(i)
	return "BOTTOM", SLOT / 2 + (i - 7) * SLOT, 0
end

local function squarePoint(i)
	local row = floor((i - 1) / 4)
	return "BOTTOM", SLOT / 2 + (i % 4 - 2) * SLOT, row * SLOT
end

function ActionBar:CreateBar(page, pointFunc, onButtonCreated)
	local bar = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
	local firstAction = (page - 1) * BUTTONS_PER_BAR

	for i = 1, BUTTONS_PER_BAR do
		local button = self:CreateActionButton(firstAction + i, bar)
		button:SetPoint(pointFunc(i))
		if onButtonCreated then
			onButtonCreated(button, i)
		end
	end

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

local function createSmallBarAnchor(anchor, x)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(2, 2)
	frame:SetPoint("BOTTOM", anchor, x, SLOT)
	return frame
end

function ActionBar:Initialize()
	local bar1 = self:CreateBar(1, rowPoint, setupPagedButton)
	bar1:SetPoint("BOTTOM", 0, 2)
	bar1:SetAttribute("_onstate-page", [[ control:ChildUpdate("page", newstate) ]])
	RegisterStateDriver(bar1, "page", PAGE_DRIVER_CONDITION)

	local bar2 = self:CreateBar(2, rowPoint)
	bar2:SetPoint("BOTTOM", bar1, 0, SLOT)

	local bar3 = self:CreateBar(3, rowPoint)
	bar3:SetPoint("BOTTOM", bar2, 0, SLOT)

	self:CreateBar(4, squarePoint):SetPoint("BOTTOM", bar1, -SLOT * 8 - 12, 0)
	self:CreateBar(5, squarePoint):SetPoint("BOTTOM", bar1, SLOT * 8 + 12, 0)

	self:InitializeShapeshiftBar(createSmallBarAnchor(bar3, -SLOT * 5))
	self:InitializePetBar(createSmallBarAnchor(bar3, -SLOT * 2))
end
