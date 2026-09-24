local _, ns = ...

local WorldFrame = WorldFrame
local UnitExists = UnitExists
local UnitName, UnitGUID, UnitIsUnit, UnitCanAttack = UnitName, UnitGUID, UnitIsUnit, UnitCanAttack
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime
local GetCurrentResolution, GetScreenResolutions = GetCurrentResolution, GetScreenResolutions
local floor, huge, min, abs, exp = math.floor, math.huge, math.min, math.abs, math.exp
local sort = table.sort

local NamePlates = ns:NewModule("NamePlates")

local NAMEPLATE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash"
local CHAT_BUBBLE_TEXTURE = "Interface\\Tooltips\\ChatBubble-Background"

local config = ns.Config.namePlates
local frameConfig = ns.Config.unitFrames
local BACKDROP = ns.CreateBackdrop(8, 2)
local BORDER_INSET = 3
local TEXT_INSET = 3
local ICON_GAP = 2
local WHITE = { 1, 1, 1 }
local SHIELD_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Small-Shield"
local SHIELD_TEXCOORD = { 0, 0.16, 0.15, 0.85 }
local CAST_GLOW_SIZE = 4
local CAST_FINISH_WINDOW = 0.5
local CAST_LATE_INTERRUPT = 0.3
local CAST_FLASH_TIME = 0.5
local CAST_FLASH_ALPHA = 0.5
local CAST_FADE_SPEED = 1 / 0.3
local CAST_INTERRUPT_HOLD = 1
local CAST_INTERRUPT_COLOR = { 0.8, 0.1, 0.1 }
local STACK_BASE_LEVEL = 21
local STACK_STEP = 3
local HOVER_ALPHA = 0.15
local ARENA_LABEL_COLOR = { 1, 0.82, 0 }
local ARENA_LABEL_GROWTH = 3
local SPREAD_SPEED = 3
local SPREAD_RAISE = 1
local SPREAD_LOWER = 0.8
local SPREAD_GAP = 2
local SPREAD_FRAME_TIME = 1 / 60
local SPREAD_MAX_STEPS = 3
local FRIENDLY_PLAYER_COLOR = { 0.31, 0.45, 0.63 }

ns.CHAT_BUBBLE_CREATED = "FrostAtomUI_CHAT_BUBBLE_CREATED"

local CVars = ns:GetModule("CVars")
CVars:Pin("showVKeyCastbar", "1", "SHOW_TARGET_CASTBAR_IN_V_KEY")
CVars:Pin("ShowClassColorInNameplate", "1")

local plates = {}
local onPlateShow = {}
local onPlateHide = {}
local rosterClasses = {}
NamePlates.plates = plates
NamePlates.onPlateShow = onPlateShow
NamePlates.onPlateHide = onPlateHide
NamePlates.rosterClasses = rosterClasses
NamePlates.BORDER_INSET = BORDER_INSET
NamePlates.TEXT_INSET = TEXT_INSET
NamePlates.ICON_GAP = ICON_GAP
NamePlates.CAST_GLOW_SIZE = CAST_GLOW_SIZE
NamePlates.CAST_FINISH_WINDOW = CAST_FINISH_WINDOW
NamePlates.CAST_LATE_INTERRUPT = CAST_LATE_INTERRUPT
NamePlates.SHIELD_TEXTURE = SHIELD_TEXTURE
NamePlates.SHIELD_TEXCOORD = SHIELD_TEXCOORD

local targetName
local spreadActive = false

local trash = CreateFrame("Frame")
trash:Hide()

local PlateMixin = {}

local UF = ns:GetModule("UnitFrames")
local classColors, classBarColors = UF.classColors, UF.classBarColors
local classKeys = {}
local function colorKey(r, g, b)
	return floor(r * 100 + 0.5) * 10000 + floor(g * 100 + 0.5) * 100 + floor(b * 100 + 0.5)
end
for class, color in pairs(RAID_CLASS_COLORS) do
	classKeys[colorKey(color.r, color.g, color.b)] = class
end

function PlateMixin:ApplyBarColor(force)
	local healthbar = self.healthbar
	local r, g, b = self.barR, self.barG, self.barB
	if config.healthColorMode == "health" then
		local _, max = healthbar:GetMinMaxValues()
		r, g, b = ns.HealthColor(max > 0 and healthbar:GetValue() / max or 0)
	end

	if not force and r == healthbar.setR and g == healthbar.setG and b == healthbar.setB then
		return
	end
	healthbar:SetStatusBarColor(r, g, b)
	healthbar.bg:SetTexture(r * 0.3, g * 0.3, b * 0.3)
	healthbar.setR, healthbar.setG, healthbar.setB = r, g, b
	healthbar.r, healthbar.g, healthbar.b = healthbar:GetStatusBarColor()
end

function PlateMixin:UpdateColors(r, g, b)
	self.rawR, self.rawG, self.rawB = r, g, b

	local class = classKeys[colorKey(r, g, b)]
	local reaction = "hostile"
	if class and config.healthColorMode == "class" then
		local barColor = classBarColors[class]
		r, g, b = barColor[1], barColor[2], barColor[3]
	elseif class or g + b == 0 then
		r, g, b = 0.69, 0.31, 0.31
	elseif r + b == 0 then
		reaction = "friendly"
		r, g, b = 0.33, 0.59, 0.33
	elseif r + g == 0 then
		reaction = "friendly"
		class = config.friendlyClassColors and rosterClasses[self.plateName]
		local barColor = class and config.healthColorMode == "class" and classBarColors[class] or FRIENDLY_PLAYER_COLOR
		r, g, b = barColor[1], barColor[2], barColor[3]
	elseif r + g > 1.99 and b == 0 then
		reaction = "neutral"
		r, g, b = 0.65, 0.63, 0.35
	end
	self.reaction = reaction

	self.barR, self.barG, self.barB = r, g, b
	self:ApplyBarColor(true)

	local nameColor = class and classColors[class] or WHITE
	self.nameColor = nameColor
	self:SetNameColor(nameColor[1], nameColor[2], nameColor[3])
end

function PlateMixin:RefreshColors()
	local healthbar = self.healthbar
	local r, g, b = healthbar:GetStatusBarColor()
	if self.rawR and r == healthbar.r and g == healthbar.g and b == healthbar.b then
		r, g, b = self.rawR, self.rawG, self.rawB
	end
	self:UpdateColors(r, g, b)
end

function PlateMixin:SetNameColor(r, g, b)
	if r ~= self.nameR or g ~= self.nameG or b ~= self.nameB then
		self.nameR, self.nameG, self.nameB = r, g, b
		self.name:SetTextColor(r, g, b)
	end
end

function PlateMixin:IsTarget()
	return targetName ~= nil and self.plateName == targetName and self:GetAlpha() == 1
end

function NamePlates.GetTargetName()
	return targetName
end

local function updateTargetName()
	targetName = UnitExists("target") and UnitName("target") or nil
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
	local x = snap(left + (self:GetWidth() - holder:GetWidth()) / 2) - left
	local y = snap(top) - top
	if x ~= self.snapX or y ~= self.snapY then
		self.snapX, self.snapY = x, y
		holder:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
	end
end

local function setLevel(frame, level)
	for _ = 1, 3 do
		if frame:GetFrameLevel() == level then
			return
		end
		frame:SetFrameLevel(level)
	end
end

function PlateMixin:ApplyStackLevel()
	local level = self.stackLevel
	local castbar = self.castbar
	setLevel(self.holder, level)
	setLevel(self.healthbar, level + 1)
	setLevel(castbar, level + 1)
	setLevel(castbar.holder, level)
	setLevel(castbar.glow, level + 1)
	setLevel(castbar.result, level + 2)
	setLevel(self.overlay, level + 2)
	local vcast = self.vcast
	if vcast then
		setLevel(vcast, level + 1)
		setLevel(vcast.holder, level)
		setLevel(vcast.glow, level + 1)
	end
	local auraRow = self.auraRow
	if auraRow then
		setLevel(auraRow, level + 2)
	end
end

function PlateMixin:SetStackLevel(level)
	if level ~= self.stackLevel or self.holder:GetFrameLevel() ~= level then
		self.stackLevel = level
		self:ApplyStackLevel()
	end
end

local function setHealthText(text, value, max, isTarget)
	local mode = config.healthTextFormat
	if not (config.showTargetPercent and (isTarget or config.healthTextAll)) or max <= 0 then
		if text.mode then
			text.mode = nil
			text:SetText("")
		end
		return
	end
	if value == text.value and max == text.max and mode == text.mode then
		return
	end
	text.value, text.max, text.mode = value, max, mode
	local percent = floor(value / max * 100)
	if mode == "percent" then
		text:SetFormattedText("%d%%", percent)
	elseif value < 1e3 then
		if mode == "both" then
			text:SetFormattedText("%d | %d%%", value, percent)
		else
			text:SetFormattedText("%d", value)
		end
	elseif mode == "both" then
		text:SetFormattedText("%s | %d%%", ns.FormatValue(value), percent)
	else
		text:SetText(ns.FormatValue(value))
	end
end

local function applyHighlight(plate)
	local hovered = config.hoverHighlight and plate.highlight:IsShown() or false
	if plate.hovered ~= hovered then
		plate.hovered = hovered
		ns.SetShown(plate.hover, hovered)
	end
end

function PlateMixin:OnUpdate()
	if self.blizzardName:GetText() ~= self.plateName then
		self:OnShow()
	end

	if self.stackLevel and self.holder:GetFrameLevel() ~= self.stackLevel then
		self:ApplyStackLevel()
	end

	applyHighlight(self)

	local healthbar = self.healthbar

	local r, g, b = healthbar:GetStatusBarColor()
	if r ~= healthbar.r or g ~= healthbar.g or b ~= healthbar.b then
		self:UpdateColors(r, g, b)
	elseif config.healthColorMode == "health" then
		self:ApplyBarColor()
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
		self:SetNameColor(r, g, b)
		if not isTarget then
			holder:SetBackdropBorderColor(r, g, b)
		end
	else
		local nameColor = self.nameColor
		self:SetNameColor(nameColor[1], nameColor[2], nameColor[3])
	end

	local borderState = isTarget and "target" or hasThreat and "threat" or "normal"
	if borderState ~= self.borderState then
		self.borderState = borderState
		if borderState ~= "threat" then
			local color = isTarget and config.targetBorder and frameConfig.targetBorderColor or frameConfig.borderColor
			holder:SetBackdropBorderColor(color[1], color[2], color[3])
		end
	end

	local _, max = healthbar:GetMinMaxValues()
	setHealthText(healthbar.percent, healthbar:GetValue(), max, isTarget)
end

local function setIconShown(icon, shown)
	if shown then
		icon:Show()
		icon.border:Show()
	else
		icon:Hide()
		icon.border:Hide()
	end
end

function PlateMixin:OnShow()
	local name = self.blizzardName:GetText()
	self.plateName = name
	self.spreadPos = 0
	if spreadActive then
		self.clampOn = true
		self.clampLeft = nil
	end
	local totemIcon = config.totemIcons and NamePlates.totemIcons[name]
	local totem = self.totem

	if totemIcon then
		totem:SetTexture(totemIcon)
		totem:SetSize(config.totemIconSize, config.totemIconSize)
		setIconShown(totem, true)
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
		self:RefreshColors()

		setIconShown(totem, false)
		self.name:SetText(name)
		if config.showName then
			self.name:Show()
		else
			self.name:Hide()
		end
		self.raidicon:SetAlpha(config.showRaidIcon and 1 or 0)
	end
	for i = 1, #onPlateShow do
		onPlateShow[i](self, name)
	end
end

function PlateMixin:OnHide()
	for i = 1, #onPlateHide do
		onPlateHide[i](self)
	end
end

local CastbarMixin = {}

function CastbarMixin:Layout()
	local holder = self:GetParent().holder
	local offset = config.castbarGap + BORDER_INSET
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", BORDER_INSET, -offset)
	self:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", -BORDER_INSET, -offset)
	self:SetHeight(config.castbarHeight)
	self.icon:SetSize(config.castbarIconSize, config.castbarIconSize)
end

function CastbarMixin:UpdateLock()
	local locked = self.shield:IsShown() or self.immune
	if locked ~= self.locked then
		self.locked = locked
		self.barR = nil
		local shielded = locked and config.castbarShield
		local icon = self.icon
		icon:SetDesaturated(locked and not shielded and 1 or nil)
		setIconShown(icon, not shielded)
		if shielded then
			self.shieldIcon:Show()
		else
			self.shieldIcon:Hide()
		end
	end

	local r, g, b, a = self:GetStatusBarColor()
	if r ~= self.barR or g ~= self.barG or b ~= self.barB then
		local color = locked and config.castbarLockedColor or config.castbarColor
		self:SetStatusBarColor(color[1], color[2], color[3], a)
		self.barR, self.barG, self.barB = self:GetStatusBarColor()
	end
end

function CastbarMixin:OnUpdate(elapsed)
	if self:GetNumPoints() ~= 2 then
		self:Layout()
	end
	local texture = self.blizzardIcon:GetTexture()
	if texture ~= self.iconTexture then
		self.iconTexture = texture
		self.icon:SetTexture(texture)
	end
	self:UpdateLock()
	if self.important and self.casting then
		UF.PulseCastGlow(self.glow, elapsed)
	end
end

function CastbarMixin:OnShow()
	local plate = self:GetParent()
	if plate.totem:IsShown() then
		self:Hide()
		return
	end
	if plate.vcast then
		plate.vcast:Hide()
	end

	self:Layout()
	self.locked = nil
	self:OnUpdate(0)
	self:StartCast()
end

local function refreshVirtualCast(key)
	local update = NamePlates.UpdateVirtualCast
	if update then
		update(key.plate)
	end
end

function CastbarMixin:OnHide()
	ns.Defer(self.hideKey, refreshVirtualCast)
end

local activeCastbar

function CastbarMixin:SetTargetingYou(targetingYou)
	local color = targetingYou and frameConfig.castbarTargetingYouColor or frameConfig.borderColor
	self.holder:SetBackdropBorderColor(color[1], color[2], color[3])
end

function CastbarMixin:UpdateTarget()
	if not self.casting then
		return
	end
	local name = config.castbarTargetName and not UnitIsUnit("targettarget", "target") and UnitName("targettarget")
	if name then
		UF.SetCastTargetText(self.targetText, "targettarget", name)
	else
		self.targetText:SetText("")
	end
	self:SetTargetingYou(
		config.castbarTargetingYou and UnitIsUnit("targettarget", "player") and UnitCanAttack("player", "target")
	)
end

function CastbarMixin:StopCast()
	self.casting = false
	self.stoppedAt = GetTime()
	self.glow:Hide()
	self.targetText:SetText("")
	self:SetTargetingYou(false)
end

function CastbarMixin:StartCast()
	self.result:Hide()
	if not UnitExists("target") or self:GetParent().blizzardName:GetText() ~= UnitName("target") then
		if self.casting then
			self:StopCast()
		end
		return
	end

	local isChannel = false
	local name, _, _, _, _, endTime = UnitCastingInfo("target")
	if not name then
		isChannel = true
		name, _, _, _, _, endTime = UnitChannelInfo("target")
	end
	if not name then
		self:StopCast()
		return
	end

	if activeCastbar and activeCastbar ~= self then
		activeCastbar:StopCast()
	end
	activeCastbar = self
	self.casting = true
	self.isChannel = isChannel
	self.endTime = endTime / 1e3
	self.guid = UnitGUID("target")
	self.immune = ns.HasCastImmunity and ns.HasCastImmunity("target") or false
	self.important = config.castbarImportant and UF.importantCasts[name] or false
	if self.important then
		if not self.glow:IsShown() then
			UF.StartCastGlow(self.glow, frameConfig.castbarImportantColor)
		end
	else
		self.glow:Hide()
	end
	self:UpdateTarget()
end

local function showCastResult(plate, texture, iconShown, locked, interruptText)
	local result = plate.castbar.result
	local plateHolder = plate.holder
	result:SetPoint("TOPLEFT", plateHolder, "BOTTOMLEFT", 0, -config.castbarGap)
	result:SetPoint("TOPRIGHT", plateHolder, "BOTTOMRIGHT", 0, -config.castbarGap)
	result:SetHeight(config.castbarHeight + BORDER_INSET * 2)

	local icon = result.icon
	icon:SetSize(config.castbarIconSize, config.castbarIconSize)
	icon:SetTexture(texture)
	setIconShown(icon, iconShown)

	local bar = result.bar
	bar:SetTexture(ns.Media.statusbar)
	if interruptText then
		bar:SetVertexColor(CAST_INTERRUPT_COLOR[1], CAST_INTERRUPT_COLOR[2], CAST_INTERRUPT_COLOR[3])
		result.text:SetText(interruptText)
		result.hold = CAST_INTERRUPT_HOLD
		result.flashing = false
		result.flash:Hide()
	else
		local color = locked and config.castbarLockedColor or config.castbarColor
		bar:SetVertexColor(color[1], color[2], color[3])
		result.text:SetText("")
		result.hold = CAST_FLASH_TIME
		result.flashing = true
		result.flash:SetAlpha(CAST_FLASH_ALPHA)
		result.flash:Show()
	end
	result.interrupted = interruptText ~= nil
	result:SetAlpha(1)
	result:Show()
end
NamePlates.ShowCastResult = showCastResult

function CastbarMixin:ShowResult(interruptText)
	showCastResult(self:GetParent(), self.icon:GetTexture(), self.icon:IsShown(), self.locked, interruptText)
end

local function onCastResultUpdate(result, elapsed)
	local hold = result.hold
	if hold > 0 then
		hold = hold - elapsed
		result.hold = hold
		if result.flashing then
			if hold > 0 then
				result.flash:SetAlpha(CAST_FLASH_ALPHA * hold / CAST_FLASH_TIME)
			else
				result.flash:Hide()
				result.flashing = false
			end
		end
		return
	end
	local alpha = result:GetAlpha() - elapsed * CAST_FADE_SPEED
	if alpha > 0 then
		result:SetAlpha(alpha)
	else
		result:Hide()
	end
end

local function stopActiveCast()
	local castbar = activeCastbar
	if castbar and castbar.casting then
		castbar:StopCast()
		return castbar
	end
end

local function onTargetCastStop()
	local castbar = stopActiveCast()
	if castbar and config.castbarFinishFlash and GetTime() >= castbar.endTime - CAST_FINISH_WINDOW then
		castbar:ShowResult()
	end
end

local function onTargetCastInterrupted()
	local castbar = stopActiveCast()
	if castbar and config.castbarInterrupter then
		castbar:ShowResult(UF.INTERRUPTED_TEXT)
	end
end

local function onCastInterrupter(_, guid, text)
	local castbar = activeCastbar
	if not (config.castbarInterrupter and castbar and castbar.guid == guid) then
		return
	end
	local result = castbar.result
	if castbar.casting then
		castbar:StopCast()
		castbar:ShowResult(text)
	elseif result:IsShown() and result.interrupted then
		result.text:SetText(text)
	elseif GetTime() - castbar.stoppedAt < CAST_LATE_INTERRUPT then
		castbar:ShowResult(text)
	end
end

local function updateCastTarget(castbar)
	castbar:UpdateTarget()
end

local function onTargetTargetChanged()
	if activeCastbar and activeCastbar.casting then
		ns.Defer(activeCastbar, updateCastTarget)
	end
end

local function refreshTargetCast()
	local plate = NamePlates:GetTargetPlate()
	if plate and plate.castbar:IsShown() then
		plate.castbar:StartCast()
	end
end

local function onTargetCastStart()
	ns.Defer(refreshTargetCast, refreshTargetCast)
end

local function onTargetChanged()
	updateTargetName()
	if activeCastbar and activeCastbar.guid ~= UnitGUID("target") then
		activeCastbar:StopCast()
		activeCastbar = nil
	end
end

local function onTargetAura()
	local castbar = activeCastbar
	if castbar and castbar.casting and ns.HasCastImmunity then
		castbar.immune = ns.HasCastImmunity("target") or false
	end
end

NamePlates.SetIconShown = setIconShown

onPlateShow[#onPlateShow + 1] = function(plate)
	plate.castbar.result:Hide()
end

local function styleHolder(holder)
	holder:SetBackdropColor(unpack(frameConfig.backdropColor))
	holder:SetBackdropBorderColor(unpack(frameConfig.borderColor))
end

local function createHolder(parent, level)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetFrameLevel(level)
	holder:SetBackdrop(BACKDROP)
	styleHolder(holder)
	return holder
end

function NamePlates.SkinIcon(parent, icon)
	local border = parent:CreateTexture(nil, "ARTWORK")
	border:SetTexture(ns.Media.buttonNormal)
	border:SetAllPoints(icon)
	icon.border = border
end

local function styleText(text, font)
	ns.SetFont(text, font.size, font.outline)
	text:SetTextColor(unpack(frameConfig.textColor))
end

local function createText(parent, font)
	local text = parent:CreateFontString(nil, "OVERLAY")
	styleText(text, font)
	return text
end

NamePlates.CreateHolder = createHolder
NamePlates.StyleHolder = styleHolder
NamePlates.CreateText = createText

local function setupHealthbar(plate, healthbar, blizzardBackground)
	local holder = createHolder(plate, plate:GetFrameLevel())
	holder:SetPoint("TOPLEFT")
	plate.holder = holder

	healthbar:SetFrameLevel(plate:GetFrameLevel() + 1)
	ns.SkinStatusBar(healthbar)

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
	ns.SkinStatusBar(castbar)

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

	local shieldIcon = castbar:CreateTexture(nil, "BORDER")
	shieldIcon:SetAllPoints(icon)
	shieldIcon:SetTexture(SHIELD_TEXTURE)
	shieldIcon:SetTexCoord(unpack(SHIELD_TEXCOORD))
	shieldIcon:Hide()
	castbar.shieldIcon = shieldIcon

	local targetText = createText(castbar, config.nameFont)
	targetText:SetPoint("LEFT", TEXT_INSET, 0)
	targetText:SetPoint("RIGHT", -TEXT_INSET, 0)
	targetText:SetJustifyH("RIGHT")
	targetText:SetWordWrap(false)
	castbar.targetText = targetText

	castbar.glow = UF.CreateCastGlow(castbar, holder, CAST_GLOW_SIZE)
	castbar.stoppedAt = 0

	local result = createHolder(plate, plate:GetFrameLevel() + 2)
	result:Hide()
	result.hold = 0
	result:SetScript("OnUpdate", onCastResultUpdate)
	local bar = result:CreateTexture(nil, "BORDER")
	bar:SetPoint("TOPLEFT", BORDER_INSET, -BORDER_INSET)
	bar:SetPoint("BOTTOMRIGHT", -BORDER_INSET, BORDER_INSET)
	result.bar = bar
	local flash = result:CreateTexture(nil, "ARTWORK")
	flash:SetAllPoints(bar)
	flash:SetTexture(ns.Media.blank)
	flash:SetBlendMode("ADD")
	result.flash = flash
	local resultIcon = result:CreateTexture(nil, "BORDER")
	resultIcon:SetPoint("RIGHT", result, "LEFT", -ICON_GAP, 0)
	NamePlates.SkinIcon(result, resultIcon)
	result.icon = resultIcon
	local resultText = createText(result, config.nameFont)
	resultText:SetPoint("LEFT", bar, TEXT_INSET, 0)
	resultText:SetPoint("RIGHT", bar, -TEXT_INSET, 0)
	resultText:SetWordWrap(false)
	result.text = resultText
	castbar.result = result

	castbar.hideKey = { plate = plate }
	castbar:SetScript("OnShow", castbar.OnShow)
	castbar:SetScript("OnHide", castbar.OnHide)
	castbar:SetScript("OnUpdate", castbar.OnUpdate)
end

local function setupTotemIcon(plate)
	local overlay = plate.overlay
	local totem = overlay:CreateTexture(nil, "BORDER")
	totem:SetSize(config.totemIconSize, config.totemIconSize)
	totem:SetPoint("TOP", plate)
	totem:Hide()

	NamePlates.SkinIcon(overlay, totem)
	totem.border:Hide()

	plate.totem = totem
end

local function styleArenaLabel(plate)
	local font = config.nameFont
	ns.SetFont(plate.arenaLabel, font.size + ARENA_LABEL_GROWTH, font.outline, true)
end

local function setupNamePlate(plate)
	local healthbar, castbar = plate:GetChildren()
	-- luacheck: ignore 631 (Blizzard's region order, all eleven are needed)
	local threat, background, castBorder, castShield, castIcon, highlight, name, level, bossIcon, raidIcon, elite =
		plate:GetRegions()

	ns.Mixin(plate, PlateMixin)

	local overlay = CreateFrame("Frame", nil, plate)
	overlay:SetAllPoints()
	plate.overlay = overlay

	setupHealthbar(plate, healthbar, background)
	setupCastbar(plate, castbar, castIcon, castShield)
	setupTotemIcon(plate)

	name:Hide()

	local arenaLabel = overlay:CreateFontString(nil, "OVERLAY")
	arenaLabel:SetPoint("RIGHT", plate.holder, "LEFT", -ICON_GAP, 0)
	arenaLabel:SetTextColor(ARENA_LABEL_COLOR[1], ARENA_LABEL_COLOR[2], ARENA_LABEL_COLOR[3])
	plate.arenaLabel = arenaLabel

	raidIcon:SetParent(overlay)
	raidIcon:SetSize(config.raidIconSize, config.raidIconSize)
	raidIcon:ClearAllPoints()
	raidIcon:SetPoint("RIGHT", arenaLabel, "LEFT")

	highlight:SetTexture(nil)
	plate.highlight = highlight

	local hover = healthbar:CreateTexture(nil, "OVERLAY")
	hover:SetAllPoints(healthbar)
	hover:SetTexture(ns.Media.blank)
	hover:SetBlendMode("ADD")
	hover:SetVertexColor(1, 1, 1, HOVER_ALPHA)
	hover:Hide()
	plate.hover = hover
	bossIcon:SetParent(trash)
	elite:SetParent(trash)
	castBorder:SetParent(trash)
	threat:SetParent(trash)
	level:SetParent(trash)

	plate.healthbar = healthbar
	plate.castbar = castbar
	plate.blizzardName = name
	plate.raidicon = raidIcon
	plate.threat = threat

	styleArenaLabel(plate)
	applyHighlight(plate)

	plate:SetScript("OnShow", plate.OnShow)
	plate:SetScript("OnHide", plate.OnHide)
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

local stack = {}

local function stackOrder(a, b)
	if a.stackKey ~= b.stackKey then
		return a.stackKey > b.stackKey
	end
	return a.stackIndex < b.stackIndex
end

local function updateStacking()
	local count = 0
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() then
			count = count + 1
			stack[count] = plate
			plate.stackIndex = i
			if plate:IsTarget() then
				plate.stackKey = -huge
			else
				plate.stackKey = plate:GetBottom() or 0
			end
		end
	end
	for i = count + 1, #stack do
		stack[i] = nil
	end
	sort(stack, stackOrder)
	for i = 1, count do
		stack[i]:SetStackLevel(STACK_BASE_LEVEL + (i - 1) * STACK_STEP)
	end
end

local spread = {}

local function setClamp(plate, clamped, left, right, top, bottom)
	if
		plate.clampOn == clamped
		and plate.clampLeft == left
		and plate.clampRight == right
		and plate.clampTop == top
		and plate.clampBottom == bottom
	then
		return
	end
	plate.clampOn = clamped
	plate.clampLeft, plate.clampRight, plate.clampTop, plate.clampBottom = left, right, top, bottom
	plate:SetClampedToScreen(clamped)
	plate:SetClampRectInsets(left, right, top, bottom)
end

local function clearSpread(plate)
	plate.spreadPos = 0
	if plate.clampOn then
		setClamp(plate, false, 0, 0, 0, 0)
	end
end

local function spreadPlates(elapsed)
	local count = 0
	for i = 1, #plates do
		local plate = plates[i]
		local x, y
		if plate:IsShown() and plate.reaction ~= "friendly" and not plate.totem:IsShown() then
			local _
			_, _, _, x, y = plate:GetPoint(1)
		end
		if x then
			count = count + 1
			spread[count] = plate
			plate.spreadX, plate.spreadY = x, y
			plate.spreadPos = plate.spreadPos or 0
		elseif plate.clampOn then
			clearSpread(plate)
		end
	end
	for i = count + 1, #spread do
		spread[i] = nil
	end

	local xSpace = config.barWidth + BORDER_INSET * 2
	local ySpace = config.barHeight + BORDER_INSET * 2 + SPREAD_GAP
	local step = SPREAD_SPEED * min(elapsed / SPREAD_FRAME_TIME, SPREAD_MAX_STEPS)
	for i = 1, count do
		local plate = spread[i]
		local x, y, pos = plate.spreadX, plate.spreadY, plate.spreadPos
		local minDist, reset = huge, true
		for j = 1, count do
			if i ~= j then
				local other = spread[j]
				if abs(x - other.spreadX) < xSpace then
					local otherTop = other.spreadY + other.spreadPos
					local diff = y + pos - otherTop
					if diff >= 0 and diff < minDist then
						minDist = diff
					end
					if abs(y - otherTop) < ySpace then
						reset = false
					end
				end
			end
		end

		if pos >= SPREAD_SPEED and reset then
			pos = pos - exp(-10 / pos) * step
		elseif minDist < ySpace then
			pos = pos + exp(-minDist / ySpace) * step * SPREAD_RAISE
		elseif pos >= SPREAD_SPEED and minDist > ySpace + SPREAD_SPEED then
			pos = pos - exp(-ySpace / minDist) * step * SPREAD_LOWER
		end
		if pos < 0 then
			pos = 0
		end
		plate.spreadPos = pos

		local width, height = plate:GetWidth(), plate:GetHeight()
		setClamp(plate, true, width / 2, -width / 2, -height, height - y - pos)
	end
end

local function updateSpread(elapsed)
	if config.spreadPlates then
		spreadActive = true
		spreadPlates(elapsed)
	elseif spreadActive then
		spreadActive = false
		for i = 1, #plates do
			clearSpread(plates[i])
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
	if kind == "NamePlate" then
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
		styleText(plate.name, config.nameFont)
		styleText(plate.healthbar.percent, config.percentFont)
		styleHolder(plate.holder)
		styleHolder(plate.castbar.holder)
		plate.borderState = nil
		plate.nameR = nil
		plate.healthbar.percent.mode = nil
		styleArenaLabel(plate)
		applyHighlight(plate)
		plate:RefreshColors()
		if plate:IsShown() then
			plate:OnShow()
		end
		local castbar = plate.castbar
		ns.SetFont(castbar.targetText, config.nameFont.size, config.nameFont.outline)
		local result = castbar.result
		styleText(result.text, config.nameFont)
		styleHolder(result)
		result:Hide()
		if castbar:IsShown() then
			castbar:OnShow()
		end
	end
end

function NamePlates.RefreshAllColors()
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and not plate.totem:IsShown() then
			plate:RefreshColors()
		end
	end
end

function NamePlates:Initialize()
	updatePixel()
	updateTargetName()
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", function()
		updatePixel()
		applyStyle()
	end)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", onTargetChanged)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", updateTargetName)
	self:RegisterUnitEvent("UNIT_NAME_UPDATE", "target", updateTargetName)
	self:RegisterUnitEvent("UNIT_AURA", "target", onTargetAura)
	self:RegisterEvent(UF.CAST_INTERRUPTED, onCastInterrupter)
	self:RegisterUnitEvent("UNIT_TARGET", "target", onTargetTargetChanged)
	self:RegisterUnitEvent("UNIT_SPELLCAST_START", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target", onTargetCastStop)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target", onTargetCastStop)
	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target", onTargetCastInterrupted)
	self:WatchConfig("namePlates", applyStyle)
	self:WatchConfig("unitFrames", applyStyle)
end

local knownChildren = 0
CreateFrame("Frame"):SetScript("OnUpdate", function(_, elapsed)
	if not config.enabled then
		return
	end
	local numChildren = WorldFrame:GetNumChildren()
	if numChildren ~= knownChildren then
		setupNewChildren(select(knownChildren + 1, WorldFrame:GetChildren()))
		knownChildren = numChildren
	end
	updateStacking()
	updateSpread(elapsed)
end)
