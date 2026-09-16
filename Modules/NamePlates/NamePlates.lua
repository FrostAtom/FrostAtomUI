local _, ns = ...

local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
local UnitExists = UnitExists
local select = select
local math = math

local NamePlates = ns:NewModule("NamePlates")

local NAMEPLATE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash"
local CHAT_BUBBLE_TEXTURE = "Interface\\Tooltips\\ChatBubble-Background"

local BAR_WIDTH, BAR_HEIGHT = 77, 6
local CASTBAR_HEIGHT = 8
local CASTBAR_ICON_SIZE = 14
local NAME_FONT_SIZE = 9
local NAME_OFFSET = 1
local PERCENT_FONT_SIZE = 9
local WHITE = { 1, 1, 1 }
local CAST_COLOR = { 0.75, 0.4, 0 }
local CAST_SHIELDED_COLOR = { 0.4, 0.4, 0.4 }
local TOTEM_ICON_SIZE = 24
local RAID_ICON_SIZE = 22
local ICON_TEXCOORD = { 0.07, 0.93, 0.07, 0.93 }
local CHAT_BUBBLE_MAX_WIDTH = 310

ns:GetModule("CVars"):Pin("showVKeyCastbar", "1", "SHOW_TARGET_CASTBAR_IN_V_KEY")
ns:GetModule("CVars"):Pin("ShowClassColorInNameplate", "1")

NamePlates.plates = {}

NamePlates.onPlateShow = {}

local trash = CreateFrame("Frame")
trash:Hide()

local PlateMixin = {}

local classColorKeys = {}
local function colorKey(r, g, b)
	return ("%d,%d,%d"):format(r * 100 + 0.5, g * 100 + 0.5, b * 100 + 0.5)
end
for class, color in pairs(RAID_CLASS_COLORS) do
	classColorKeys[colorKey(color.r, color.g, color.b)] = ns:GetModule("UnitFrames").classColors[class]
end

function PlateMixin:UpdateColors(r, g, b)
	local classColor = classColorKeys[colorKey(r, g, b)]
	if classColor then
		r, g, b = classColor[1], classColor[2], classColor[3]
	elseif g + b == 0 then
		r, g, b = 0.69, 0.31, 0.31
	elseif r + b == 0 then
		r, g, b = 0.33, 0.59, 0.33
	elseif r + g == 0 then
		r, g, b = 0.31, 0.45, 0.63
	elseif r + g > 1.99 and b == 0 then
		r, g, b = 0.65, 0.63, 0.35
	end

	local healthbar = self.healthbar
	healthbar:SetStatusBarColor(r, g, b)
	healthbar.bg:SetTexture(r * 0.3, g * 0.3, b * 0.3)
	self.totem.bg:SetTexture(r, g, b)
	healthbar.r, healthbar.g, healthbar.b = r, g, b

	local nameColor = classColor or WHITE
	self.nameColor = nameColor
	self.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
end

function PlateMixin:IsTarget()
	return UnitExists("target") and self:GetAlpha() == 1
end

function PlateMixin:OnUpdate()
	local healthbar = self.healthbar

	local r, g, b = healthbar:GetStatusBarColor()
	if r ~= healthbar.r or g ~= healthbar.g or b ~= healthbar.b then
		self:UpdateColors(r, g, b)
	end

	if self.totem:IsShown() then
		return
	end

	local border = healthbar.border
	local isTarget = self:IsTarget()
	if isTarget then
		border:SetTexture(1, 1, 1)
		border:SetAlpha(0.67)
	elseif self.threat:IsShown() then
		border:SetTexture(1, 1, 1)
		border:SetAlpha(0.4)
	else
		border:SetTexture(0, 0, 0)
		border:SetAlpha(1)
	end

	if self.threat:IsShown() then
		self.name:SetTextColor(self.threat:GetVertexColor())
	else
		local nameColor = self.nameColor
		self.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
	end

	local percent = healthbar.percent
	if isTarget then
		local _, max = healthbar:GetMinMaxValues()
		percent:SetFormattedText("%d%%", max > 0 and healthbar:GetValue() / max * 100 or 0)
		percent:Show()
	else
		percent:Hide()
	end
end

function PlateMixin:OnShow()
	local name = self.blizzardName:GetText()
	local totemIcon = NamePlates.totemIcons[name]

	if totemIcon then
		self.totem:SetTexture(totemIcon)
		self.totem:Show()
		self.totem.bg:Show()
		self.name:Hide()
		self.healthbar:Hide()
		self.raidicon:SetAlpha(0)
	else
		local healthbar = self.healthbar
		healthbar:ClearAllPoints()
		healthbar:SetSize(BAR_WIDTH, BAR_HEIGHT)
		healthbar:SetPoint("TOP", 0, -4)
		healthbar:Show()
		self:UpdateColors(healthbar:GetStatusBarColor())

		self.totem:Hide()
		self.totem.bg:Hide()
		self.name:SetText(name)
		self.name:Show()
		self.raidicon:SetAlpha(1)
	end

	self.level:Hide()

	for _, callback in ipairs(NamePlates.onPlateShow) do
		callback(self, name)
	end
end

local CastbarMixin = {}

function CastbarMixin:OnUpdate()
	self:ClearAllPoints()
	self:SetPoint("TOP", self:GetParent().healthbar, "BOTTOM", 0, -3)
	self:SetSize(BAR_WIDTH, CASTBAR_HEIGHT)

	local icon = self.icon
	icon:ClearAllPoints()
	icon:SetPoint("RIGHT", self, "LEFT", -3, 0)
	icon:SetSize(CASTBAR_ICON_SIZE, CASTBAR_ICON_SIZE)
	icon:SetTexCoord(unpack(ICON_TEXCOORD))

	if self.shield:IsShown() then
		self:SetStatusBarColor(unpack(CAST_SHIELDED_COLOR))
		icon:SetDesaturated(1)
	else
		self:SetStatusBarColor(unpack(CAST_COLOR))
		icon:SetDesaturated(nil)
	end
end

function CastbarMixin:OnShow()
	if self:GetParent().totem:IsShown() then
		self:Hide()
		self.icon:SetAlpha(0)
		return
	end

	self.icon:SetAlpha(1)
	self:OnUpdate()
end

local function setupHealthbar(plate, healthbar, blizzardBackground)
	healthbar:SetFrameLevel(plate:GetFrameLevel())
	healthbar:SetStatusBarTexture(ns.Media.blank)

	local borderSize = ns.PixelPerfect(1)
	local border = healthbar:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(0, 0, 0)
	border:SetPoint("TOPRIGHT", borderSize, borderSize)
	border:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)
	healthbar.border = border

	blizzardBackground:SetParent(healthbar)
	blizzardBackground:SetDrawLayer("BORDER")
	blizzardBackground:SetAllPoints(healthbar)
	blizzardBackground:SetAlpha(0.9)
	healthbar.bg = blizzardBackground

	local percent = healthbar:CreateFontString(nil, "OVERLAY")
	percent:SetFont(ns.Media.font, PERCENT_FONT_SIZE, "OUTLINE")
	percent:SetPoint("LEFT", healthbar, "RIGHT", 3, 0)
	percent:SetTextColor(1, 1, 1)
	percent:Hide()
	healthbar.percent = percent
end

local function setupCastbar(plate, castbar, icon, shield)
	ns.Mixin(castbar, CastbarMixin)
	castbar:SetFrameLevel(plate:GetFrameLevel())
	castbar:SetStatusBarTexture(ns.Media.blank)

	shield:SetTexture(nil)
	castbar.shield = shield

	local borderSize = ns.PixelPerfect(1)
	local border = castbar:CreateTexture(nil, "BACKGROUND", nil, -1)
	border:SetTexture(0, 0, 0)
	border:SetPoint("TOPRIGHT", borderSize, borderSize)
	border:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)

	local bg = castbar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(0.2, 0.2, 0.2)
	bg:SetAllPoints()
	bg:SetAlpha(0.9)

	icon:SetDrawLayer("ARTWORK")
	local iconBorder = castbar:CreateTexture(nil, "BORDER")
	iconBorder:SetTexture(0, 0, 0)
	iconBorder:SetPoint("TOPRIGHT", icon, borderSize, borderSize)
	iconBorder:SetPoint("BOTTOMLEFT", icon, -borderSize, -borderSize)
	castbar.icon = icon

	castbar:SetScript("OnShow", castbar.OnShow)
	castbar:SetScript("OnUpdate", castbar.OnUpdate)
end

local function setupTotemIcon(plate)
	local totem = plate:CreateTexture(nil, "ARTWORK")
	totem:SetSize(TOTEM_ICON_SIZE, TOTEM_ICON_SIZE)
	totem:SetPoint("TOP")
	totem:SetTexCoord(unpack(ICON_TEXCOORD))
	totem:Hide()

	local bg = plate:CreateTexture(nil, "BORDER")
	bg:SetTexture(ns.Media.blank)
	bg:SetAllPoints(totem)
	totem.bg = bg

	plate.totem = totem
end

local function setupNamePlate(plate)
	local healthbar, castbar = plate:GetChildren()
	-- luacheck: ignore 631 (Blizzard's region order, all eleven are needed)
	local threat, background, castBorder, castShield, castIcon, highlight, name, level, bossIcon, raidIcon, elite =
		plate:GetRegions()

	ns.Mixin(plate, PlateMixin)

	setupHealthbar(plate, healthbar, background)
	setupCastbar(plate, castbar, castIcon, castShield)
	setupTotemIcon(plate)

	local newName = plate:CreateFontString(nil, "ARTWORK")
	newName:SetFont(ns.Media.font, NAME_FONT_SIZE, "OUTLINE")
	newName:SetPoint("BOTTOM", healthbar, "TOP", 0, NAME_OFFSET)
	newName:SetTextColor(1, 1, 1)
	name:Hide()

	raidIcon:SetSize(RAID_ICON_SIZE, RAID_ICON_SIZE)
	raidIcon:ClearAllPoints()
	raidIcon:SetPoint("RIGHT", healthbar, "LEFT", -15, 0)

	highlight:SetTexture(nil)
	for _, region in ipairs({ bossIcon, elite, castBorder, threat }) do
		region:SetParent(trash)
	end

	plate.healthbar = healthbar
	plate.castbar = castbar
	plate.blizzardName = name
	plate.name = newName
	plate.level = level
	plate.raidicon = raidIcon
	plate.threat = threat

	plate:SetScript("OnShow", plate.OnShow)
	plate:SetScript("OnUpdate", plate.OnUpdate)

	plate:OnShow()
	if castbar:IsShown() then
		castbar:OnShow()
	end

	NamePlates.plates[#NamePlates.plates + 1] = plate
end

function NamePlates:GetTargetPlate()
	if not UnitExists("target") then
		return
	end
	for _, plate in ipairs(self.plates) do
		if plate:IsShown() and plate:IsTarget() then
			return plate
		end
	end
end

local function onChatBubbleShow(bubble)
	local text = bubble.text
	bubble.bg:SetSize(math.min(text:GetStringWidth(), CHAT_BUBBLE_MAX_WIDTH) + 8, text:GetStringHeight() + 8)
end

local function collapseRegions(first, region, nextRegion, ...)
	if not nextRegion then
		return first, region
	end
	region:SetTexture(nil)
	region:Hide()
	return collapseRegions(first, nextRegion, ...)
end

local function setupChatBubble(bubble)
	local bg, text = collapseRegions(bubble:GetRegions())

	bg:SetTexture(0, 0, 0, 0.5)
	bg:ClearAllPoints()
	bg:SetPoint("CENTER")

	local r, g, b = text:GetTextColor()
	text:SetFontObject("NumberFontNormal")
	text:SetTextColor(r, g, b)

	bubble.bg = bg
	bubble.text = text

	onChatBubbleShow(bubble)
	bubble:SetScript("OnShow", onChatBubbleShow)
end

local function identifyFrame(frame)
	if frame:GetName() or not frame.GetRegions then
		return
	end

	local region = frame:GetRegions()
	if not (region and region.GetTexture) then
		return
	end

	local texture = region:GetTexture()
	if texture == NAMEPLATE_TEXTURE then
		return "NamePlate"
	elseif texture == CHAT_BUBBLE_TEXTURE then
		return "ChatBubble"
	end
end

local function safeSetup(setup, frame)
	local ok, err = pcall(setup, frame)
	if not ok then
		geterrorhandler()(err)
	end
end

local function setupNewChildren(frame, ...)
	if not frame then
		return
	end

	local kind = identifyFrame(frame)
	if kind == "NamePlate" then
		safeSetup(setupNamePlate, frame)
	elseif kind == "ChatBubble" then
		safeSetup(setupChatBubble, frame)
	end

	return setupNewChildren(...)
end

local knownChildren = 0
CreateFrame("Frame"):SetScript("OnUpdate", function()
	local numChildren = WorldFrame:GetNumChildren()
	if numChildren ~= knownChildren then
		setupNewChildren(select(knownChildren + 1, WorldFrame:GetChildren()))
		knownChildren = numChildren
	end
end)
