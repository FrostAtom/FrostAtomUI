local _, ns = ...

-- Action bars layout:
--
--   [shapeshift] [pet]
--   [   bar 3   ]
--   [   bar 2   ]        [ bar 5 ]
--   [ bar 4 ]   [   bar 1   ]
--
-- Bars 4/5 are 4x3 squares to the sides of bar 1.

local CreateFrame = CreateFrame
local RegisterStateDriver = RegisterStateDriver
local floor = math.floor

local ActionBar = ns:NewModule("ActionBar")

local BUTTONS_PER_BAR = 12
local BUTTON_SIZE = 36
local BUTTON_GAP = 2
local SLOT = BUTTON_SIZE + BUTTON_GAP

ActionBar.BUTTON_SIZE = BUTTON_SIZE
ActionBar.SMALL_BUTTON_SIZE = 30
ActionBar.BUTTON_GAP = BUTTON_GAP

-- Common look for every action-like button (action, pet, shapeshift).
function ActionBar:StyleButton(button, size)
	button:SetSize(size, size)
	button:SetNormalTexture(ns.Media.buttonNormal)
	button:GetNormalTexture():SetAllPoints()
	button:SetHighlightTexture(ns.Media.buttonHighlight)
	button:HookScript("OnClick", self.PlayClickAnimation)
end

-- Icon shade and border color; `button.icon` must exist.
function ActionBar:SetButtonColors(button, iconShade, borderR, borderG, borderB)
	button.icon:SetVertexColor(iconShade, iconShade, iconShade)
	button:GetNormalTexture():SetVertexColor(borderR, borderG, borderB)
end

--------------------------------------------------
-- Tooltips
--
-- `setTooltip(button)` fills GameTooltip for the button; it is re-run while
-- hovering so cooldowns and ranks stay current.

local TOOLTIP_REFRESH_INTERVAL = 0.2

-- One refresher for whichever button is hovered, so buttons keep their own
-- OnUpdate scripts.
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

-- Position of the i-th button in a single 12-wide row, centered on the bar.
local function rowPoint(i)
	return "BOTTOM", SLOT / 2 + (i - 7) * SLOT, 0
end

-- Position of the i-th button in a 4x3 block, centered on the bar.
local function squarePoint(i)
	local row = floor((i - 1) / 4)
	return "BOTTOM", SLOT / 2 + (i % 4 - 2) * SLOT, row * SLOT
end

-- Creates a secure bar holding the 12 action slots of the given page.
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

-- Bar 1 swaps its page like Blizzard's main bar: vehicle/possess bars, then
-- class forms. No manual paging ([bar:N]): pages 2-5 are the other bars,
-- always on screen, and the client remembers a flipped page across reloads.
--
-- Pages 7-10 are the "bonus" bars: warrior stances, druid forms (cat 7,
-- prowl 8, bear 9, moonkin/tree 10), rogue stealth 7, priest shadowform 7.
local CLASS_PAGE_CONDITIONS = {
	WARRIOR = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;",
	DRUID = "[bonusbar:1,stealth] 8; [bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10;",
	ROGUE = "[bonusbar:1] 7;",
	PRIEST = "[bonusbar:1] 7;",
}

local function pageDriverCondition()
	-- 3.3.5 has no [possessbar]; possession sets bonusbar 5 like vehicles do.
	local condition = "[vehicleui] 11; [bonusbar:5] 11; "
	local classCondition = CLASS_PAGE_CONDITIONS[ns.PLAYER_CLASS]
	if classCondition then
		condition = condition .. classCondition .. " "
	end
	return condition .. "1"
end

-- Secure snippet run on every bar 1 button when the page changes.
local PAGE_CHANGED_SNIPPET = [[
	self:SetAttribute("action", (message - 1) * 12 + self:GetAttribute("id"))
]]

local function setupPagedButton(button, index)
	button:SetAttribute("id", index)
	button:SetAttribute("_childupdate-page", PAGE_CHANGED_SNIPPET)
end

function ActionBar:Initialize()
	local bar1 = self:CreateBar(1, rowPoint, setupPagedButton)
	bar1:SetPoint("BOTTOM", 0, 2)
	bar1:SetAttribute("_onstate-page", [[ control:ChildUpdate("page", newstate) ]])
	RegisterStateDriver(bar1, "page", pageDriverCondition())

	local bar2 = self:CreateBar(2, rowPoint)
	bar2:SetPoint("BOTTOM", bar1, 0, SLOT)

	local bar3 = self:CreateBar(3, rowPoint)
	bar3:SetPoint("BOTTOM", bar2, 0, SLOT)

	local bar4 = self:CreateBar(4, squarePoint)
	bar4:SetPoint("BOTTOM", bar1, -SLOT * 8 - 12, 0)

	local bar5 = self:CreateBar(5, squarePoint)
	bar5:SetPoint("BOTTOM", bar1, SLOT * 8 + 12, 0)

	local shapeshiftBar = CreateFrame("Frame", nil, UIParent)
	shapeshiftBar:SetSize(2, 2)
	shapeshiftBar:SetPoint("BOTTOM", bar3, -SLOT * 5, SLOT)
	self:InitializeShapeshiftBar(shapeshiftBar)

	local petBar = CreateFrame("Frame", nil, UIParent)
	petBar:SetSize(2, 2)
	petBar:SetPoint("BOTTOM", bar3, -SLOT * 2, SLOT)
	self:InitializePetBar(petBar)

	self.bars = { bar1, bar2, bar3, bar4, bar5 }
end
