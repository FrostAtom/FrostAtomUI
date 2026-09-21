local _, ns = ...

local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
local UnitExists = UnitExists
local GetCurrentResolution, GetScreenResolutions = GetCurrentResolution, GetScreenResolutions
local select = select
local pcall = pcall
local unpack = unpack
local tonumber = tonumber
local floor = math.floor
local format = string.format

local NamePlates = ns:NewModule("NamePlates")

local NAMEPLATE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash"
local CHAT_BUBBLE_TEXTURE = "Interface\\Tooltips\\ChatBubble-Background"

local config = ns.Config.namePlates
local frameConfig = ns.Config.unitFrames
local BACKDROP = ns.CreateBackdrop(8, 2)
local BORDER_INSET = 3
local TEXT_INSET = 3
local CASTBAR_GAP = 3
local ICON_GAP = 2
local WHITE = { 1, 1, 1 }

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
	healthbar.r, healthbar.g, healthbar.b = r, g, b

	local nameColor = class and classColors[class] or WHITE
	self.nameColor = nameColor
	self.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
end

function PlateMixin:IsTarget()
	return UnitExists("target") and self:GetAlpha() == 1
end

local pixel = 1

local function updatePixel()
	local resolution = select(GetCurrentResolution(), GetScreenResolutions())
	local height = resolution and tonumber(resolution:match("x(%d+)$"))
	pixel = height and WorldFrame:GetHeight() / height or 1
end

local function snap(value)
	return floor(value / pixel + 0.5) * pixel
end

function PlateMixin:SnapHolder()
	local holder = self.holder
	local left, top = self:GetLeft(), self:GetTop()
	if not left then
		return
	end
	local width = self:GetWidth()
	local x = snap(left + (width - holder:GetWidth()) / 2) - left
	local y = snap(top) - top
	if x ~= self.snapX or y ~= self.snapY then
		self.snapX, self.snapY = x, y
		holder:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
	end
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

	self:SnapHolder()

	local isTarget = self:IsTarget()
	local threat = self.threat
	local hasThreat = threat:IsShown()
	local holder = self.holder
	if hasThreat then
		local r, g, b = threat:GetVertexColor()
		self.name:SetTextColor(r, g, b)
		if not isTarget then
			holder:SetBackdropBorderColor(r, g, b)
		end
	else
		local nameColor = self.nameColor
		self.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
	end

	local borderState = isTarget and "target" or hasThreat and "threat" or "normal"
	if borderState ~= self.borderState then
		self.borderState = borderState
		if borderState ~= "threat" then
			local color = isTarget and frameConfig.targetBorderColor or frameConfig.borderColor
			holder:SetBackdropBorderColor(color[1], color[2], color[3])
		end
	end

	local percent = healthbar.percent
	if isTarget and config.showTargetPercent then
		local _, max = healthbar:GetMinMaxValues()
		percent:SetFormattedText("%d%%", max > 0 and healthbar:GetValue() / max * 100 or 0)
	else
		percent:SetText("")
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
		totem.border:Show()
		self.holder:Hide()
		self.healthbar:Hide()
		self.raidicon:SetAlpha(0)
	else
		local holder, healthbar = self.holder, self.healthbar
		holder:SetSize(snap(config.barWidth + BORDER_INSET * 2), snap(config.barHeight + BORDER_INSET * 2))
		self.snapX = nil
		self:SnapHolder()
		local inset = snap(BORDER_INSET)
		healthbar:ClearAllPoints()
		healthbar:SetPoint("TOPLEFT", holder, inset, -inset)
		healthbar:SetPoint("BOTTOMRIGHT", holder, -inset, inset)
		self.raidicon:SetSize(config.raidIconSize, config.raidIconSize)
		holder:Show()
		healthbar:Show()
		self:UpdateColors(healthbar:GetStatusBarColor())

		totem:Hide()
		totem.border:Hide()
		self.name:SetText(name)
		self.raidicon:SetAlpha(1)
	end

	self.level:Hide()

	for i = 1, #onPlateShow do
		onPlateShow[i](self, name)
	end
end

local CastbarMixin = {}

function CastbarMixin:OnUpdate()
	local holder = self:GetParent().holder
	local offset = CASTBAR_GAP + BORDER_INSET
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", BORDER_INSET, -offset)
	self:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", -BORDER_INSET, -offset)
	self:SetHeight(config.castbarHeight)

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

local function createHolder(parent, level)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetFrameLevel(level)
	holder:SetBackdrop(BACKDROP)
	holder:SetBackdropColor(unpack(frameConfig.backdropColor))
	holder:SetBackdropBorderColor(unpack(frameConfig.borderColor))
	return holder
end

function NamePlates.SkinIcon(parent, icon)
	local border = parent:CreateTexture(nil, "ARTWORK")
	border:SetTexture(ns.Media.buttonNormal)
	border:SetAllPoints(icon)
	icon.border = border
	return border
end

local function createText(parent, font)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(ns.Media.font, font.size, font.outline)
	text:SetTextColor(unpack(frameConfig.textColor))
	return text
end

local function setupHealthbar(plate, healthbar, blizzardBackground)
	local holder = createHolder(plate, plate:GetFrameLevel())
	holder:SetPoint("TOPLEFT")
	plate.holder = holder

	healthbar:SetFrameLevel(plate:GetFrameLevel() + 1)
	healthbar:SetStatusBarTexture(ns.Media.blank)

	blizzardBackground:SetParent(healthbar)
	blizzardBackground:SetDrawLayer("BORDER")
	blizzardBackground:SetAllPoints(healthbar)
	healthbar.bg = blizzardBackground

	local percent = createText(healthbar, config.percentFont)
	percent:SetPoint("RIGHT", -TEXT_INSET, 0)
	healthbar.percent = percent

	local name = createText(healthbar, config.nameFont)
	name:SetPoint("LEFT", TEXT_INSET, 0)
	name:SetPoint("RIGHT", percent, "LEFT", -ICON_GAP, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	plate.name = name
end

local function setupCastbar(plate, castbar, blizzardIcon, shield)
	ns.Mixin(castbar, CastbarMixin)
	castbar:SetFrameLevel(plate:GetFrameLevel() + 1)
	castbar:SetStatusBarTexture(ns.Media.blank)

	shield:SetTexture(nil)
	castbar.shield = shield

	local holder = createHolder(castbar, plate:GetFrameLevel())
	holder:SetPoint("TOPLEFT", -BORDER_INSET, BORDER_INSET)
	holder:SetPoint("BOTTOMRIGHT", BORDER_INSET, -BORDER_INSET)
	castbar.holder = holder

	local icon = castbar:CreateTexture(nil, "BORDER")
	icon:SetSize(config.castbarIconSize, config.castbarIconSize)
	icon:SetPoint("RIGHT", holder, "LEFT", -ICON_GAP, 0)
	NamePlates.SkinIcon(castbar, icon)
	castbar.icon = icon
	castbar.blizzardIcon = blizzardIcon
	blizzardIcon:SetParent(trash)

	castbar:SetScript("OnShow", castbar.OnShow)
	castbar:SetScript("OnUpdate", castbar.OnUpdate)
end

local function setupTotemIcon(plate)
	local totem = plate:CreateTexture(nil, "BORDER")
	totem:SetSize(config.totemIconSize, config.totemIconSize)
	totem:SetPoint("TOP")
	totem:Hide()

	NamePlates.SkinIcon(plate, totem)
	totem.border:Hide()

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

	name:Hide()

	raidIcon:SetSize(config.raidIconSize, config.raidIconSize)
	raidIcon:ClearAllPoints()
	raidIcon:SetPoint("RIGHT", plate.holder, "LEFT", -ICON_GAP, 0)

	highlight:SetTexture(nil)
	bossIcon:SetParent(trash)
	elite:SetParent(trash)
	castBorder:SetParent(trash)
	threat:SetParent(trash)

	plate.healthbar = healthbar
	plate.castbar = castbar
	plate.blizzardName = name
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

local function applyStyle()
	for i = 1, #plates do
		local plate = plates[i]
		local percent = plate.healthbar.percent
		plate.name:SetFont(ns.Media.font, config.nameFont.size, config.nameFont.outline)
		plate.name:SetTextColor(unpack(frameConfig.textColor))
		percent:SetFont(ns.Media.font, config.percentFont.size, config.percentFont.outline)
		percent:SetTextColor(unpack(frameConfig.textColor))
		for _, holder in ipairs({ plate.holder, plate.castbar.holder }) do
			holder:SetBackdropColor(unpack(frameConfig.backdropColor))
			holder:SetBackdropBorderColor(unpack(frameConfig.borderColor))
		end
		plate.borderState = nil
		if plate:IsShown() then
			plate:OnShow()
		end
	end
end

function NamePlates:Initialize()
	updatePixel()
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", function()
		updatePixel()
		applyStyle()
	end)
	self:WatchConfig("namePlates", applyStyle)
	self:WatchConfig("unitFrames", applyStyle)
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
