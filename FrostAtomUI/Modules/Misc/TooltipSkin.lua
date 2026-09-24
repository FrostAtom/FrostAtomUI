local _, ns = ...

local Misc = ns:GetModule("Misc")
local config = ns.Config.tooltip

local TOOLTIP_NAMES = {
	"GameTooltip",
	"ItemRefTooltip",
	"ShoppingTooltip1",
	"ShoppingTooltip2",
	"ShoppingTooltip3",
	"ItemRefShoppingTooltip1",
	"ItemRefShoppingTooltip2",
	"ItemRefShoppingTooltip3",
	"WorldMapTooltip",
	"WorldMapCompareTooltip1",
	"WorldMapCompareTooltip2",
	"WorldMapCompareTooltip3",
	"FriendsTooltip",
}
local BORDER_DIM = 0.85
local TINT = 0.12
local GRADIENT_HEIGHT = 32
local GRADIENT_ALPHA = 0.12
local SIDE_ICON_SIZE = 36
local SIDE_ICON_GAP = 2
local MIN_UNIT_WIDTH = 125
local BAR_INSET = 8
local BAR_HEIGHT = 6
local THIN_BAR_HEIGHT = 3
local THIN_BAR_INSET = 4
local DEBUFF_OVERLAY = "Interface\\Buttons\\UI-Debuff-Overlays"

local Skin = {}
ns.TooltipSkin = Skin

local enabled = config.enabled and config.skin
local backdrop = ns.CreateBackdrop(14, 3)
local states = {}

local function paint(tooltip)
	local state = states[tooltip]
	if not enabled then
		if state and state.bordered then
			tooltip:SetBackdropBorderColor(state.br, state.bg, state.bb)
		end
		return
	end
	local color = config.backdropColor
	local r, g, b = color[1], color[2], color[3]
	if state.tinted and config.reactionBackground then
		r = r + (state.tr - r) * TINT
		g = g + (state.tg - g) * TINT
		b = b + (state.tb - b) * TINT
	end
	tooltip:SetBackdropColor(r, g, b, color[4])
	if state.bordered then
		tooltip:SetBackdropBorderColor(state.br, state.bg, state.bb)
	else
		local border = config.borderColor
		tooltip:SetBackdropBorderColor(border[1], border[2], border[3])
	end
end

local function stateOf(tooltip)
	local state = states[tooltip]
	if not state then
		state = {}
		states[tooltip] = state
	end
	return state
end

function Skin.SetBorder(tooltip, r, g, b)
	local state = stateOf(tooltip)
	state.bordered = true
	state.br, state.bg, state.bb = r * BORDER_DIM, g * BORDER_DIM, b * BORDER_DIM
	paint(tooltip)
end

function Skin.SetTint(tooltip, r, g, b)
	local state = stateOf(tooltip)
	state.tinted = true
	state.tr, state.tg, state.tb = r, g, b
	paint(tooltip)
end

function Skin.Clear(tooltip)
	local state = states[tooltip]
	if not state or not (state.bordered or state.tinted) then
		return
	end
	local bordered = state.bordered
	state.bordered, state.tinted = false, false
	if enabled then
		paint(tooltip)
	elseif bordered then
		tooltip:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	end
end

local function skinTooltip(tooltip)
	tooltip:SetBackdrop(backdrop)
	local gradient = tooltip:CreateTexture(nil, "BORDER")
	gradient:SetTexture(1, 1, 1, 1)
	gradient:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, GRADIENT_ALPHA)
	gradient:SetPoint("TOPLEFT", 3, -3)
	gradient:SetPoint("TOPRIGHT", -3, -3)
	gradient:SetHeight(GRADIENT_HEIGHT)
	stateOf(tooltip).gradient = gradient
	tooltip:HookScript("OnShow", paint)
	paint(tooltip)
end

local function applyGradients()
	for tooltip, state in pairs(states) do
		if state.gradient then
			ns.SetShown(state.gradient, config.gradient)
		end
	end
end

local function repaint()
	for tooltip in pairs(states) do
		if enabled then
			paint(tooltip)
		end
	end
	applyGradients()
end

local function applyFonts()
	local size = config.fontSize
	ns.SetFont(GameTooltipHeaderText, size + 2, "", true)
	ns.SetFont(GameTooltipText, size, "")
	ns.SetFont(GameTooltipTextSmall, size - 1, "")
end

local MONEY_TEXTS = { "PrefixText", "SuffixText", "GoldButtonText", "SilverButtonText", "CopperButtonText" }
local moneyTexts = {}

local function applyMoneyFonts()
	for region in pairs(moneyTexts) do
		ns.SetFont(region, config.fontSize, "")
	end
end

local function skinMoney(tooltip)
	local name = tooltip:GetName()
	for i = 1, tooltip.shownMoneyFrames or 0 do
		local frameName = name .. "MoneyFrame" .. i
		for _, suffix in ipairs(MONEY_TEXTS) do
			local region = _G[frameName .. suffix]
			if region and not moneyTexts[region] then
				moneyTexts[region] = true
				ns.SetFont(region, config.fontSize, "")
			end
		end
	end
end

local function skinMenus()
	local menuBackdrop = ns.CreateBackdrop(14, 3)
	for i = 1, UIDROPDOWNMENU_MAXLEVELS do
		for _, suffix in ipairs({ "Backdrop", "MenuBackdrop" }) do
			local frame = _G["DropDownList" .. i .. suffix]
			if frame then
				frame:SetBackdrop(menuBackdrop)
				local color, border = config.backdropColor, config.borderColor
				frame:SetBackdropColor(color[1], color[2], color[3], color[4])
				frame:SetBackdropBorderColor(border[1], border[2], border[3])
			end
		end
	end
end

local function skinCloseButton(button)
	button:SetNormalTexture("")
	button:SetPushedTexture("")
	button:SetHighlightTexture("")
	button:SetSize(14, 14)
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", -2, -2)
	local text = ns.CreateGlyph(button, "xmark", 10, "OVERLAY", "OUTLINE")
	text:SetPoint("CENTER")
	text:SetTextColor(0.7, 0.7, 0.7)
	button:HookScript("OnEnter", function()
		text:SetTextColor(1, 0.3, 0.3)
	end)
	button:HookScript("OnLeave", function()
		text:SetTextColor(0.7, 0.7, 0.7)
	end)
end

local function skinStatusBar(bar)
	if bar.skinned then
		return
	end
	bar.skinned = true
	ns.SkinStatusBar(bar)
	local background = bar:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(ns.Media.blank)
	background:SetVertexColor(0, 0, 0, 0.5)
	background:SetAllPoints()
end

local healthBar = GameTooltipStatusBar

local function layoutHealthBar()
	healthBar:ClearAllPoints()
	local mode = enabled and config.healthBar or "outside"
	if mode == "inside" then
		healthBar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", BAR_INSET, BAR_INSET)
		healthBar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -BAR_INSET, BAR_INSET)
		healthBar:SetHeight(BAR_HEIGHT)
	elseif mode == "thin" then
		healthBar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", THIN_BAR_INSET, THIN_BAR_INSET)
		healthBar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -THIN_BAR_INSET, THIN_BAR_INSET)
		healthBar:SetHeight(THIN_BAR_HEIGHT)
	else
		healthBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 2, -1)
		healthBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -2, -1)
		healthBar:SetHeight(8)
	end
end

function Skin.HealthBarMode()
	return enabled and config.healthBar or "outside"
end

local reserveKey = {}

local function reserveHealthBarLine()
	if GameTooltip:IsShown() and healthBar:IsShown() and GameTooltip:GetUnit() and config.healthBar == "inside" then
		GameTooltip:AddLine(" ")
		GameTooltip:Show()
	end
end

function Skin.PrepareUnit(tooltip)
	if tooltip ~= GameTooltip or not enabled or not healthBar:IsShown() then
		return
	end
	if config.healthBar == "inside" then
		ns.Defer(reserveKey, reserveHealthBarLine)
	end
	tooltip:SetMinimumWidth(MIN_UNIT_WIDTH)
end

local sideIcon = CreateFrame("Frame", nil, GameTooltip)
sideIcon:SetSize(SIDE_ICON_SIZE, SIDE_ICON_SIZE)
sideIcon:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -SIDE_ICON_GAP, 0)
sideIcon:SetBackdrop(ns.CreateBackdrop(8, 2))
sideIcon:SetBackdropColor(0, 0, 0, 1)
sideIcon:Hide()
local sideTexture = sideIcon:CreateTexture(nil, "ARTWORK")
sideTexture:SetPoint("TOPLEFT", 3, -3)
sideTexture:SetPoint("BOTTOMRIGHT", -3, 3)
sideTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local function ownerShowsIcon(owner)
	if not owner or owner == UIParent then
		return false
	end
	if owner.icon or owner.Icon or owner.hasItem or owner.action or owner.spellID then
		return true
	end
	local name = owner:GetName()
	return name and (_G[name .. "Icon"] or _G[name .. "IconTexture"]) and true or false
end

function Skin.ShowIcon(tooltip, texture)
	if tooltip ~= GameTooltip or not enabled or not config.sideIcon or not texture then
		return false
	end
	if ownerShowsIcon(tooltip:GetOwner()) then
		sideIcon:Hide()
		return true
	end
	sideTexture:SetTexture(texture)
	local border = config.borderColor
	sideIcon:SetBackdropBorderColor(border[1], border[2], border[3])
	sideIcon:Show()
	return true
end

function Skin.SetIconBorder(r, g, b)
	if sideIcon:IsShown() then
		sideIcon:SetBackdropBorderColor(r * BORDER_DIM, g * BORDER_DIM, b * BORDER_DIM)
	end
end

function Skin.HideIcon()
	sideIcon:Hide()
end

function Skin.StyleAuraBorder(border, isDebuff, r, g, b)
	if isDebuff and enabled then
		border:SetTexture(DEBUFF_OVERLAY)
		border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
	else
		border:SetTexture(ns.Media.buttonNormal)
		border:SetTexCoord(0, 1, 0, 1)
	end
	border:SetVertexColor(r, g, b)
end

for _, name in ipairs(TOOLTIP_NAMES) do
	local tooltip = _G[name]
	if tooltip then
		stateOf(tooltip)
		if enabled then
			skinTooltip(tooltip)
		end
	end
end

if config.enabled then
	skinStatusBar(healthBar)
end

if enabled then
	applyFonts()
	applyGradients()
	skinMenus()
	skinCloseButton(ItemRefCloseButton)
	hooksecurefunc("GameTooltip_ShowStatusBar", function(tooltip)
		local bar = _G[tooltip:GetName() .. "StatusBar" .. (tooltip.shownStatusBars or 1)]
		if bar then
			skinStatusBar(bar)
		end
	end)
	hooksecurefunc("SetTooltipMoney", function(frame)
		if states[frame] then
			skinMoney(frame)
		end
	end)
	Misc:WatchConfig("tooltip.fontSize", function()
		applyFonts()
		applyMoneyFonts()
	end)
	Misc:WatchConfig("tooltip.backdropColor", repaint)
	Misc:WatchConfig("tooltip.borderColor", repaint)
	Misc:WatchConfig("tooltip.reactionBackground", repaint)
	Misc:WatchConfig("tooltip.gradient", applyGradients)
end

layoutHealthBar()
Misc:WatchConfig("tooltip.healthBar", layoutHealthBar)
