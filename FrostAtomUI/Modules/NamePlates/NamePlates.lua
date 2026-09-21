local _, ns = ...

local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
local UnitExists = UnitExists
local select = select
local pcall = pcall
local format = string.format

local NamePlates = ns:NewModule("NamePlates")

local NAMEPLATE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash"
local CHAT_BUBBLE_TEXTURE = "Interface\\Tooltips\\ChatBubble-Background"

local config = ns.Config.namePlates
local NAME_OFFSET = 1
local WHITE = { 1, 1, 1 }
local ICON_TEXCOORD_LEFT, ICON_TEXCOORD_RIGHT, ICON_TEXCOORD_TOP, ICON_TEXCOORD_BOTTOM = 0.07, 0.93, 0.07, 0.93

ns.CHAT_BUBBLE_CREATED = "FrostAtomUI_CHAT_BUBBLE_CREATED"

local CVars = ns:GetModule("CVars")
CVars:Pin("showVKeyCastbar", "1", "SHOW_TARGET_CASTBAR_IN_V_KEY")
CVars:Pin("ShowClassColorInNameplate", "1")

local plates = {}
local onPlateShow = {}
NamePlates.plates = plates
NamePlates.onPlateShow = onPlateShow

local trash = CreateFrame("Frame")
trash:Hide()

local PlateMixin = {}

local UF = ns:GetModule("UnitFrames")
local classColors, classBarColors = UF.classColors, UF.classBarColors
local classKeys = {}
local function colorKey(r, g, b)
	return format("%d,%d,%d", r * 100 + 0.5, g * 100 + 0.5, b * 100 + 0.5)
end
for class, color in pairs(RAID_CLASS_COLORS) do
	classKeys[colorKey(color.r, color.g, color.b)] = class
end

function PlateMixin:UpdateColors(r, g, b)
	local class = classKeys[colorKey(r, g, b)]
	if class then
		local barColor = classBarColors[class]
		r, g, b = barColor[1], barColor[2], barColor[3]
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

	local nameColor = class and classColors[class] or WHITE
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
	local threat = self.threat
	local hasThreat = threat:IsShown()
	if isTarget then
		border:SetTexture(1, 1, 1)
		border:SetAlpha(config.targetBorderAlpha)
	elseif hasThreat then
		border:SetTexture(1, 1, 1)
		border:SetAlpha(0.4)
	else
		border:SetTexture(0, 0, 0)
		border:SetAlpha(1)
	end

	if hasThreat then
		self.name:SetTextColor(threat:GetVertexColor())
	else
		local nameColor = self.nameColor
		self.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
	end

	local percent = healthbar.percent
	if isTarget and config.showTargetPercent then
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
	local totem = self.totem

	if totemIcon then
		totem:SetTexture(totemIcon)
		totem:SetSize(config.totemIconSize, config.totemIconSize)
		totem:Show()
		totem.bg:Show()
		self.name:Hide()
		self.healthbar:Hide()
		self.raidicon:SetAlpha(0)
	else
		local healthbar = self.healthbar
		healthbar:ClearAllPoints()
		healthbar:SetSize(config.barWidth, config.barHeight)
		healthbar:SetPoint("TOP", 0, -4)
		self.raidicon:SetSize(config.raidIconSize, config.raidIconSize)
		healthbar:Show()
		self:UpdateColors(healthbar:GetStatusBarColor())

		totem:Hide()
		totem.bg:Hide()
		self.name:SetText(name)
		self.name:Show()
		self.raidicon:SetAlpha(1)
	end

	self.level:Hide()

	for i = 1, #onPlateShow do
		onPlateShow[i](self, name)
	end
end

local CastbarMixin = {}

function CastbarMixin:OnUpdate()
	self:ClearAllPoints()
	self:SetPoint("TOP", self:GetParent().healthbar, "BOTTOM", 0, -3)
	self:SetSize(config.barWidth, config.castbarHeight)

	local icon = self.icon
	icon:SetTexture(self.blizzardIcon:GetTexture())
	icon:SetSize(config.castbarIconSize, config.castbarIconSize)

	local color
	if self.shield:IsShown() then
		color = config.castbarLockedColor
		icon:SetDesaturated(1)
	else
		color = config.castbarColor
		icon:SetDesaturated(nil)
	end
	self:SetStatusBarColor(color[1], color[2], color[3])
end

function CastbarMixin:OnShow()
	if self:GetParent().totem:IsShown() then
		self:Hide()
		return
	end

	self:OnUpdate()
end

local function createBorder(parent, anchor, layer, sublevel)
	local size = ns.PixelPerfect(1)
	local border = parent:CreateTexture(nil, layer, nil, sublevel)
	border:SetTexture(0, 0, 0)
	border:SetPoint("TOPRIGHT", anchor, size, size)
	border:SetPoint("BOTTOMLEFT", anchor, -size, -size)
	return border
end

local function setupHealthbar(plate, healthbar, blizzardBackground)
	healthbar:SetFrameLevel(plate:GetFrameLevel())
	healthbar:SetStatusBarTexture(ns.Media.blank)
	healthbar.border = createBorder(healthbar, healthbar, "BACKGROUND")

	blizzardBackground:SetParent(healthbar)
	blizzardBackground:SetDrawLayer("BORDER")
	blizzardBackground:SetAllPoints(healthbar)
	blizzardBackground:SetAlpha(0.9)
	healthbar.bg = blizzardBackground

	local percent = healthbar:CreateFontString(nil, "OVERLAY")
	percent:SetFont(ns.Media.font, config.percentFont.size, config.percentFont.outline)
	percent:SetPoint("LEFT", healthbar, "RIGHT", 3, 0)
	percent:SetTextColor(1, 1, 1)
	percent:Hide()
	healthbar.percent = percent
end

local function setupCastbar(plate, castbar, blizzardIcon, shield)
	ns.Mixin(castbar, CastbarMixin)
	castbar:SetFrameLevel(plate:GetFrameLevel())
	castbar:SetStatusBarTexture(ns.Media.blank)

	shield:SetTexture(nil)
	castbar.shield = shield

	createBorder(castbar, castbar, "BACKGROUND", -1)

	local bg = castbar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(0.2, 0.2, 0.2)
	bg:SetAllPoints()
	bg:SetAlpha(0.9)

	local icon = castbar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(config.castbarIconSize, config.castbarIconSize)
	icon:SetPoint("RIGHT", castbar, "LEFT", -3, 0)
	icon:SetTexCoord(ICON_TEXCOORD_LEFT, ICON_TEXCOORD_RIGHT, ICON_TEXCOORD_TOP, ICON_TEXCOORD_BOTTOM)
	createBorder(castbar, icon, "BORDER")
	castbar.icon = icon
	castbar.blizzardIcon = blizzardIcon
	blizzardIcon:SetParent(trash)

	castbar:SetScript("OnShow", castbar.OnShow)
	castbar:SetScript("OnUpdate", castbar.OnUpdate)
end

local function setupTotemIcon(plate)
	local totem = plate:CreateTexture(nil, "ARTWORK")
	totem:SetSize(config.totemIconSize, config.totemIconSize)
	totem:SetPoint("TOP")
	totem:SetTexCoord(ICON_TEXCOORD_LEFT, ICON_TEXCOORD_RIGHT, ICON_TEXCOORD_TOP, ICON_TEXCOORD_BOTTOM)
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
	newName:SetFont(ns.Media.font, config.nameFont.size, config.nameFont.outline)
	newName:SetPoint("BOTTOM", healthbar, "TOP", 0, NAME_OFFSET)
	newName:SetTextColor(1, 1, 1)
	name:Hide()

	raidIcon:SetSize(config.raidIconSize, config.raidIconSize)
	raidIcon:ClearAllPoints()
	raidIcon:SetPoint("RIGHT", healthbar, "LEFT", -15, 0)

	highlight:SetTexture(nil)
	bossIcon:SetParent(trash)
	elite:SetParent(trash)
	castBorder:SetParent(trash)
	threat:SetParent(trash)

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

	plates[#plates + 1] = plate
end

function NamePlates:GetTargetPlate()
	if not UnitExists("target") then
		return
	end
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and plate:IsTarget() then
			return plate
		end
	end
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

local function setupNewChildren(frame, ...)
	if not frame then
		return
	end

	local kind = identifyFrame(frame)
	if kind == "NamePlate" and config.enabled then
		local ok, err = pcall(setupNamePlate, frame)
		if not ok then
			geterrorhandler()(err)
		end
	elseif kind == "ChatBubble" then
		ns:Fire(ns.CHAT_BUBBLE_CREATED, frame)
	end

	return setupNewChildren(...)
end

function NamePlates:Initialize()
	self:WatchConfig("namePlates", function()
		for i = 1, #plates do
			local plate = plates[i]
			plate.name:SetFont(ns.Media.font, config.nameFont.size, config.nameFont.outline)
			plate.healthbar.percent:SetFont(ns.Media.font, config.percentFont.size, config.percentFont.outline)
			if plate:IsShown() then
				plate:OnShow()
			end
		end
	end)
end

local knownChildren = 0
CreateFrame("Frame"):SetScript("OnUpdate", function()
	if not config.enabled then
		return
	end
	local numChildren = WorldFrame:GetNumChildren()
	if numChildren ~= knownChildren then
		setupNewChildren(select(knownChildren + 1, WorldFrame:GetChildren()))
		knownChildren = numChildren
	end
end)
