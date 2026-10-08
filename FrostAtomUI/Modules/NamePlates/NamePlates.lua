local _, ns = ...

local UnitGUID, UnitIsUnit, UnitCanAttack = UnitGUID, UnitIsUnit, UnitCanAttack
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local GetTime = GetTime
local huge, min, abs, exp = math.huge, math.min, math.abs, math.exp
local sort = table.sort

local NamePlates = ns:NewModule("NamePlates")
ns:RegisterReloadPaths("namePlates.enabled")
local PlateLayer = ns.PlateLayer
local FRIENDLY = PlateLayer.FRIENDLY

local config = ns.Config.namePlates
local themeConfig, castConfig = ns.Config.theme, ns.Config.castbar
local renderHealthTags = ns.Tags.RenderHealth
local BACKDROP = ns.CreateBackdrop(8, 2)
local BORDER_INSET = 3
local TARGET_EDGE_CORNER = 5 * 16 / 14
local TARGET_EDGE_OUTSET = 1
local TARGET_BACKGROUND = { 1, 1, 1, 1 }
local TARGET_RELIEF_ALPHA = 0.6
local TEXT_INSET = 3
local ICON_GAP = 2
local WHITE = { 1, 1, 1 }
local SHIELD_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Small-Shield"
local SHIELD_TEXCOORD = { 0, 39 / 256, 10 / 64, 57 / 64 }
local SHIELD_HOLE = 19
local SHIELD_INSETS = { 10.5, 11.5, 9.5, 16.5 }
local CAST_GLOW_SIZE = 4
local COMPACT_CAST_HEIGHT = 5
local CAST_TIMING = ns.Cast.TIMING
local CAST_FINISH_WINDOW = CAST_TIMING.FINISH_WINDOW
local CAST_LATE_INTERRUPT = CAST_TIMING.LATE_INTERRUPT
local CAST_FLASH_TIME = CAST_TIMING.FLASH_TIME
local CAST_FLASH_ALPHA = CAST_TIMING.FLASH_ALPHA
local CAST_FADE_SPEED = CAST_TIMING.FADE_SPEED
local CAST_INTERRUPT_HOLD = CAST_TIMING.INTERRUPT_HOLD
local CAST_INTERRUPT_COLOR = CAST_TIMING.INTERRUPT_COLOR
local STACK_BASE_LEVEL = 21
local STACK_STEP = 3
local HOVER_ALPHA = 0.15
local ARENA_LABEL_COLOR = { 1, 0.82, 0 }
local SPREAD_SPEED = 3
local SPREAD_RAISE = 1
local SPREAD_LOWER = 0.8
local SPREAD_GAP = 2
local SPREAD_FRAME_TIME = 1 / 60
local SPREAD_MAX_STEPS = 3
local HIT_PADDING = 4
local HOSTILE_COLOR = ns.HOSTILE_COLOR
local NEUTRAL_COLOR = ns.NEUTRAL_COLOR
local FRIENDLY_COLOR = ns.FRIENDLY_COLOR
local FRIENDLY_PLAYER_COLOR = { 0.31, 0.45, 0.63 }
local NAME_REACTION_COLORS = {
	[HOSTILE_COLOR] = { 1, 0.35, 0.35 },
	[NEUTRAL_COLOR] = { 1, 0.9, 0.3 },
	[FRIENDLY_COLOR] = { 0.4, 1, 0.4 },
	[FRIENDLY_PLAYER_COLOR] = { 0.5, 0.7, 1 },
}

local CVars = ns:GetModule("CVars")
CVars:Pin("showVKeyCastbar", "1", "SHOW_TARGET_CASTBAR_IN_V_KEY")
CVars:Pin("ShowClassColorInNameplate", "1")

local plates = {}
local onPlateShow = {}
local onPlateHide = {}
local onPlateLayout = {}
NamePlates.plates = plates
NamePlates.onPlateShow = onPlateShow
NamePlates.onPlateHide = onPlateHide
NamePlates.onPlateLayout = onPlateLayout
NamePlates.onPlateSetup = {}
NamePlates.onIdentity = {}
NamePlates.onUnitAdded = {}
NamePlates.onUnitRemoved = {}
NamePlates.onPass = {}

local PLUGIN_HOOKS = {
	Show = "onPlateShow",
	Hide = "onPlateHide",
	Layout = "onPlateLayout",
	Identity = "onIdentity",
	UnitAdded = "onUnitAdded",
	UnitRemoved = "onUnitRemoved",
	Pass = "onPass",
	Setup = "onPlateSetup",
}
local plugins = {}
NamePlates.plugins = plugins

function NamePlates.RegisterPlugin(plugin)
	assert(type(plugin.name) == "string", "nameplate plugin needs a name")
	plugins[#plugins + 1] = plugin
	for key, list in pairs(PLUGIN_HOOKS) do
		local hook = plugin[key]
		if hook then
			local hooks = NamePlates[list]
			hooks[#hooks + 1] = hook
		end
	end
	for event, handler in pairs(plugin.Log or {}) do
		NamePlates.AddLogHandler(event, handler)
	end
end

NamePlates.BORDER_INSET = BORDER_INSET
NamePlates.ICON_GAP = ICON_GAP
NamePlates.CAST_GLOW_SIZE = CAST_GLOW_SIZE
NamePlates.CAST_FINISH_WINDOW = CAST_FINISH_WINDOW
NamePlates.CAST_LATE_INTERRUPT = CAST_LATE_INTERRUPT

local spreadActive = false

local trash = CreateFrame("Frame")
trash:Hide()

local PlateMixin = {}

local classColors, classBarColors = ns.Colors.class, ns.Colors.classBar

function PlateMixin:ApplyBarColor(force)
	local healthbar = self.healthbar
	local r, g, b = self.barR, self.barG, self.barB
	if self.healthMode == "health" then
		local _, max = healthbar:GetMinMaxValues()
		r, g, b = ns.HealthColor(max > 0 and healthbar:GetValue() / max or 0)
	end

	if not force and r == healthbar.setR and g == healthbar.setG and b == healthbar.setB then
		return
	end
	PlateLayer.SetHealthColor(self.info, r, g, b)
	healthbar.bg:SetTexture(r * 0.3, g * 0.3, b * 0.3)
	healthbar.setR, healthbar.setG, healthbar.setB = r, g, b
end

function PlateMixin:UpdateColors()
	local info = self.info
	local reaction = info.reaction or PlateLayer.HOSTILE
	local isPlayer = info.isPlayer
	if isPlayer == nil then
		isPlayer = PlateLayer.IsPlayerGUID(self.guid)
	end
	local class = info.class

	local reactionColor, settings
	if reaction == FRIENDLY then
		reactionColor = isPlayer and FRIENDLY_PLAYER_COLOR or FRIENDLY_COLOR
		settings = isPlayer and config.friendlyPlayer or config.friendlyNpc
	else
		reactionColor = reaction == PlateLayer.NEUTRAL and NEUTRAL_COLOR or HOSTILE_COLOR
		settings = isPlayer and config.enemyPlayer or config.enemyNpc
	end
	self.reaction = reaction
	NamePlates.Totems.SetReaction(self, reaction)

	if settings ~= self.settings then
		self.settings = settings
		self.layoutDirty = true
		self.borderState = nil
	end

	local mode = settings.healthColorMode
	local barColor = reactionColor
	if mode == "class" and class and classBarColors[class] then
		barColor = classBarColors[class]
	elseif mode == "custom" then
		barColor = settings.healthColor
	end
	self.healthMode = mode
	self.barR, self.barG, self.barB = barColor[1], barColor[2], barColor[3]
	self:ApplyBarColor(true)

	local nameMode = settings.nameColorMode
	local nameColor = WHITE
	if nameMode == "class" and class and classColors[class] then
		nameColor = classColors[class]
	elseif nameMode == "reaction" then
		nameColor = NAME_REACTION_COLORS[reactionColor]
	end
	self.nameColor = nameColor
	self:SetNameColor(nameColor[1], nameColor[2], nameColor[3])
end

function PlateMixin:SetNameColor(r, g, b)
	if r ~= self.nameR or g ~= self.nameG or b ~= self.nameB then
		self.nameR, self.nameG, self.nameB = r, g, b
		self.name:SetTextColor(r, g, b)
	end
end

function PlateMixin:IsTarget()
	return PlateLayer.IsTarget(self.info)
end

local hiddenNames = {}

local function updateHiddenNames()
	wipe(hiddenNames)
	if not config.hideByName then
		return
	end
	for _, name in ipairs(config.hiddenNames) do
		hiddenNames[ns.Lower(name)] = true
	end
end

local function isHiddenName(name)
	return name ~= nil and hiddenNames[ns.Lower(name)] == true
end

local function isFilteredTotem(spellId)
	return spellId ~= nil and config.totemFilter == "important" and not ns.TotemData.IsImportant(spellId)
end

local WorldChildren = ns.WorldChildren
local snap, snapX, snapY = WorldChildren.Snap, WorldChildren.SnapX, WorldChildren.SnapY

function PlateMixin:HitPadding()
	return WorldChildren.Pixel() * HIT_PADDING
end

function PlateMixin:SnapHolder()
	local holder = self.holder
	local left, top = self:GetLeft(), self:GetTop()
	if not left then
		return
	end
	local x = snapX(left + (self:GetWidth() - holder:GetWidth()) / 2) - left
	local y = snapY(top - self:HitPadding()) - top
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
	setLevel(self.holder.targetEdge, level)
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
	local controlIcon = self.controlIcon
	if controlIcon then
		setLevel(controlIcon, level + 2)
	end
	setLevel(self.totem, level)
end

function PlateMixin:UpdateHitRect()
	local visible = self.totem:IsShown() and self.totem or self.holder
	local padding = 2 * self:HitPadding()
	NamePlates.HitRect.Update(self, visible:GetWidth() + padding, visible:GetHeight() + padding, self.hiddenByName)
end

function PlateMixin:SetStackLevel(level)
	if level ~= self.stackLevel or self.holder:GetFrameLevel() ~= level then
		self.stackLevel = level
		self:ApplyStackLevel()
	end
end

local function setHealthText(text, value, max, isTarget, shown, enemy)
	local template = config.healthTag
	if not (shown == "all" or isTarget and shown == "target") or max <= 0 or template == "" then
		if text.template then
			text.template = nil
			text:SetText("")
		end
		return
	end
	if value == text.value and max == text.max and template == text.template and enemy == text.enemy then
		return
	end
	text.value, text.max, text.template, text.enemy = value, max, template, enemy
	text:SetText(renderHealthTags(template, value, max, enemy))
end

local function applyHighlight(plate)
	local hovered = config.hoverHighlight and plate.info.isMouseover or false
	if plate.hovered ~= hovered then
		plate.hovered = hovered
		ns.SetShown(plate.hover, hovered)
	end
end

function PlateMixin:OnUpdate()
	if self.hiddenByName then
		return
	end
	local isTarget = self:IsTarget()
	if not isTarget and self:GetAlpha() < 1 then
		self:SetAlpha(config.nonTargetAlpha)
	end
	if self.stackLevel and self.holder:GetFrameLevel() ~= self.stackLevel then
		self:ApplyStackLevel()
	end

	applyHighlight(self)

	if self.healthMode == "health" then
		self:ApplyBarColor()
	end

	if self.totem:IsShown() then
		NamePlates.Totems.Update(self, isTarget)
		return
	end

	if (isTarget and self.settings.targetScale or 1) ~= self.layoutScale then
		self.layoutDirty = true
	end
	if self.layoutDirty then
		self:ApplyLayout()
		self:UpdateHitRect()
		for i = 1, #onPlateLayout do
			onPlateLayout[i](self)
		end
	end

	self:SnapHolder()

	local threat = self.threat
	local hasThreat = threat:IsShown()
	local holder = self.holder
	if hasThreat and not isTarget then
		local r, g, b = threat:GetVertexColor()
		holder:SetBackdropBorderColor(r, g, b)
	end
	local nameColor = self.nameColor
	self:SetNameColor(nameColor[1], nameColor[2], nameColor[3])

	local borderState = isTarget and "target" or hasThreat and "threat" or "normal"
	if borderState ~= self.borderState then
		self.borderState = borderState
		local targeted = isTarget and config.targetBorder
		if borderState ~= "threat" then
			local settings = self.settings
			local color = settings.ownBorderColor and settings.borderColor or themeConfig.borderColor
			holder:SetBackdropBorderColor(color[1], color[2], color[3], targeted and 0 or 1)
		end
		local background = targeted and TARGET_BACKGROUND or themeConfig.backdropColor
		holder:SetBackdropColor(background[1], background[2], background[3], background[4] or 1)
		ns.SetShown(holder.targetEdge, targeted)
	end

	local healthbar = self.healthbar
	local _, max = healthbar:GetMinMaxValues()
	setHealthText(
		healthbar.percent,
		healthbar:GetValue(),
		max,
		isTarget,
		self.settings.healthText,
		self.reaction ~= FRIENDLY
	)
end

local function setIconShown(icon, shown)
	ns.SetShown(icon, shown)
	ns.SetShown(icon.border, shown)
end

local function refreshCastbarLayout(plate)
	local castbar = plate.castbar
	if castbar:IsShown() then
		if plate.settings.showCastbar then
			castbar:Layout()
		else
			castbar:Hide()
		end
	end
end

function PlateMixin:ApplyLayout()
	self.layoutDirty = nil
	local settings = self.settings
	local holder = self.holder
	local scale = self:IsTarget() and settings.targetScale or 1
	self.layoutScale = scale
	holder:SetSize(snap(settings.width * scale + BORDER_INSET * 2), snap(settings.height * scale + BORDER_INSET * 2))
	self.snapX = nil
	self:SnapHolder()
	ns.SetShown(self.name, settings.showName)
	refreshCastbarLayout(self)
end

function PlateMixin:ApplyHidden()
	NamePlates.Totems.Hide(self)
	self.holder:Hide()
	self.healthbar:Hide()
	self.overlay:Hide()
	self.castbar:Hide()
	self.castbar.result:Hide()
	if self.vcast then
		self.vcast:Hide()
	end
	for i = 1, #onPlateShow do
		onPlateShow[i](self, self.plateName)
	end
	self:UpdateHitRect()
end

function PlateMixin:OnShow()
	local name = self.info.name
	self.plateName = name
	self.spreadPos = 0
	if spreadActive then
		self.clampOn = true
		self.clampLeft = nil
	end
	local Totems = NamePlates.Totems
	self:UpdateColors()
	local totemSpell = config.totemIcons and Totems.Identify(self)
	self.hiddenByName = isHiddenName(name) or isFilteredTotem(totemSpell)
	if self.hiddenByName then
		self:ApplyHidden()
		return
	end
	self.overlay:Show()
	local unitIcon, unitIconCoords
	if not totemSpell then
		unitIcon, unitIconCoords = NamePlates.ArenaIcons.Identify(self)
	end

	if totemSpell or unitIcon then
		if totemSpell then
			Totems.Show(self, totemSpell)
		else
			Totems.ShowIcon(self, unitIcon, unitIconCoords, self.settings.arenaIconSize)
			refreshCastbarLayout(self)
		end
		self.holder:Hide()
		self.healthbar:Hide()
		self.raidicon:SetAlpha(0)
	else
		local holder, healthbar = self.holder, self.healthbar
		self:ApplyLayout()
		local inset = snap(BORDER_INSET)
		healthbar:ClearAllPoints()
		healthbar:SetPoint("TOPLEFT", holder, inset, -inset)
		healthbar:SetPoint("BOTTOMRIGHT", holder, -inset, inset)
		healthbar:SetWidth(0)
		self.raidicon:SetSize(config.raidIconSize, config.raidIconSize)
		holder:Show()
		healthbar:Show()

		Totems.Hide(self)
		self.name:SetText(name)
		self.raidicon:SetAlpha(config.showRaidIcon and 1 or 0)
	end
	for i = 1, #onPlateShow do
		onPlateShow[i](self, name)
	end
	local updateVirtualCast = NamePlates.UpdateVirtualCast
	if updateVirtualCast then
		updateVirtualCast(self)
	end
	self:UpdateHitRect()
end

function PlateMixin:OnHide()
	if self.totemSpell or self.unitIcon then
		NamePlates.Totems.Hide(self)
	end
	for i = 1, #onPlateHide do
		onPlateHide[i](self)
	end
end

local function castAnchor(plate)
	if plate.unitIcon then
		return plate.totem, COMPACT_CAST_HEIGHT, true
	end
	return plate.holder, plate.settings.castbarHeight, false
end
NamePlates.CastAnchor = castAnchor

function NamePlates.LayoutCastbar(bar)
	local plate = bar:GetParent()
	local anchor, height, compact = castAnchor(plate)
	local offset = config.castbarGap + BORDER_INSET + (plate.comboOffset or 0)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", BORDER_INSET, -offset)
	bar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -BORDER_INSET, -offset)
	bar:SetWidth(0)
	bar:SetHeight(height)
	local size = config.castbarIconSize
	local icon = bar.icon
	icon:SetSize(size, size)
	local scale = size / SHIELD_HOLE
	local shield = bar.shieldIcon
	shield:ClearAllPoints()
	shield:SetPoint("TOPLEFT", icon, -SHIELD_INSETS[1] * scale, SHIELD_INSETS[2] * scale)
	shield:SetPoint("BOTTOMRIGHT", icon, SHIELD_INSETS[3] * scale, -SHIELD_INSETS[4] * scale)
	ns.SetShown(bar.spellText, not compact)
	ns.SetShown(bar.targetText, not compact)
	bar.compact = compact
end

function NamePlates.CreateShield(bar)
	local shield = bar:CreateTexture(nil, "OVERLAY", nil, -1)
	shield:SetTexture(SHIELD_TEXTURE)
	shield:SetTexCoord(unpack(SHIELD_TEXCOORD))
	shield:Hide()
	bar.shieldIcon = shield
end

function NamePlates.ApplyShield(bar, locked)
	local shielded = locked and not bar.compact
	local icon = bar.icon
	icon:SetDesaturated(locked and not shielded and 1 or nil)
	setIconShown(icon, not bar.compact)
	if shielded then
		icon.border:Hide()
		bar.shieldIcon:Show()
	else
		bar.shieldIcon:Hide()
	end
end

local CastbarMixin = {}

local function isTargetPlate(plate)
	local guid = UnitGUID("target")
	if not guid or plate.blizzardName:GetText() ~= UnitName("target") then
		return false
	end
	if plate.guid then
		return plate.guid == guid
	end
	local owner = NamePlates.unitPlates.target
	return owner == nil or owner == plate or owner.guid ~= guid
end

function CastbarMixin:Layout()
	NamePlates.LayoutCastbar(self)
	self.locked = nil
end

function CastbarMixin:UpdateLock()
	local locked = self.shield:IsShown() or self.immune
	if locked ~= self.locked then
		self.locked = locked
		self.barR = nil
		NamePlates.ApplyShield(self, locked)
	end

	local r, g, b, a = self:GetStatusBarColor()
	if r ~= self.barR or g ~= self.barG or b ~= self.barB then
		local color = locked and config.castbarLockedColor or config.castbarColor
		self:SetStatusBarColor(color[1], color[2], color[3], a)
		self.barR, self.barG, self.barB = self:GetStatusBarColor()
	end
end

function CastbarMixin:OnUpdate(elapsed)
	if not isTargetPlate(self:GetParent()) then
		if self.casting then
			self:StopCast()
		end
		self:Hide()
		return
	end
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
		ns.Cast.PulseGlow(self.glow, elapsed)
	end
end

function CastbarMixin:OnShow()
	local plate = self:GetParent()
	if plate.hiddenByName or plate.totemSpell or not plate.settings.showCastbar then
		self:Hide()
		return
	end
	if plate.vcast then
		plate.vcast:Hide()
	end

	self:Layout()
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
	local color = targetingYou and castConfig.targetingYouColor or themeConfig.borderColor
	self.holder:SetBackdropBorderColor(color[1], color[2], color[3])
end

function CastbarMixin:UpdateTarget()
	if not self.casting then
		return
	end
	ns.Cast.ShowCastTarget(self.targetText, "target", "targettarget", self.spellName)
	self:SetTargetingYou(
		castConfig.targetingYou and UnitIsUnit("targettarget", "player") and UnitCanAttack("player", "target")
	)
end

function CastbarMixin:StopCast()
	self.casting = false
	self.stoppedAt = GetTime()
	self.glow:Hide()
	self.targetText:SetText("")
	self.spellText:SetText("")
	self:SetTargetingYou(false)
end

function CastbarMixin:StartCast()
	self.result:Hide()
	if not isTargetPlate(self:GetParent()) then
		if self.casting then
			self:StopCast()
		end
		self:Hide()
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
		self:Hide()
		return
	end

	if activeCastbar and activeCastbar ~= self then
		activeCastbar:StopCast()
	end
	activeCastbar = self
	self.casting = true
	self.isChannel = isChannel
	self.spellName = name
	self.endTime = endTime / 1e3
	self.guid = UnitGUID("target")
	self.immune = ns.HasCastImmunity and ns.HasCastImmunity("target") or false
	self.important = castConfig.important and ns.Cast.importantCasts[name] or false
	if self.important then
		if not self.glow:IsShown() then
			ns.Cast.StartGlow(self.glow, castConfig.importantColor)
		end
	else
		self.glow:Hide()
	end
	self.spellText:SetText(config.castbarSpellName and name or "")
	self:UpdateTarget()
end

local function showCastResult(plate, texture, iconShown, locked, interruptText, cancelled)
	if plate.hiddenByName then
		return
	end
	local result = plate.castbar.result
	local anchor, height, compact = castAnchor(plate)
	local offset = config.castbarGap + (plate.comboOffset or 0)
	result:ClearAllPoints()
	result:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -offset)
	result:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -offset)
	result:SetHeight(height + BORDER_INSET * 2)
	ns.SetShown(result.text, not compact)

	local icon = result.icon
	icon:SetSize(config.castbarIconSize, config.castbarIconSize)
	icon:SetTexture(texture)
	setIconShown(icon, iconShown and not compact)

	local bar = result.bar
	bar:SetTexture(ns.Media.statusbar)
	local color = interruptText and CAST_INTERRUPT_COLOR or locked and config.castbarLockedColor or config.castbarColor
	bar:SetVertexColor(color[1], color[2], color[3])
	if interruptText or cancelled then
		result.text:SetText(interruptText or ns.Cast.CANCELLED_TEXT)
		result.hold = CAST_INTERRUPT_HOLD
		result.flashing = false
		result.flash:Hide()
	else
		result.text:SetText("")
		result.hold = CAST_FLASH_TIME
		result.flashing = true
		result.flash:SetAlpha(CAST_FLASH_ALPHA)
		result.flash:Show()
	end
	result.interrupted = interruptText ~= nil
	result.cancelled = not interruptText and cancelled or false
	result:SetAlpha(1)
	result:Show()
end
NamePlates.ShowCastResult = showCastResult

function CastbarMixin:ShowResult(interruptText, cancelled)
	showCastResult(self:GetParent(), self.icon:GetTexture(), self.icon:IsShown(), self.locked, interruptText, cancelled)
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
	if castbar and GetTime() >= castbar.endTime - CAST_FINISH_WINDOW then
		castbar:ShowResult()
	end
end

local function onTargetCastInterrupted()
	local castbar = stopActiveCast()
	if castbar and castConfig.interrupter then
		local text = ns.Cast.RecentSilence(castbar.guid)
		if text then
			castbar:ShowResult(text)
		else
			castbar:ShowResult(nil, true)
		end
	end
end

local function onCastSilenced(_, guid, text)
	local castbar = activeCastbar
	if not (castConfig.interrupter and castbar and castbar.guid == guid) or castbar.casting then
		return
	end
	local result = castbar.result
	if result:IsShown() and result.cancelled and GetTime() - castbar.stoppedAt < CAST_LATE_INTERRUPT then
		castbar:ShowResult(text)
	end
end

local function onCastInterrupter(_, guid, text)
	local castbar = activeCastbar
	if not (castConfig.interrupter and castbar and castbar.guid == guid) then
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
	local plate = PlateLayer.GetTargetPlate()
	if plate and plate.castbar:IsShown() then
		plate.castbar:StartCast()
	end
end

local function onTargetCastStart()
	ns.Defer(refreshTargetCast, refreshTargetCast)
end

local function onTargetChanged()
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

onPlateShow[#onPlateShow + 1] = function(plate)
	local castbar = plate.castbar
	castbar.result:Hide()
	if castbar:IsShown() then
		castbar:OnShow()
	end
end

local function styleHolder(holder)
	holder:SetBackdropColor(unpack(themeConfig.backdropColor))
	holder:SetBackdropBorderColor(unpack(themeConfig.borderColor))
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
	text:SetTextColor(unpack(themeConfig.textColor))
end

local function createText(parent, font)
	local text = parent:CreateFontString(nil, "OVERLAY")
	styleText(text, font)
	return text
end

local function createCastTexts(castbar)
	local targetText = createText(castbar, config.castbarFont)
	targetText:SetPoint("RIGHT", -TEXT_INSET, 0)
	targetText:SetJustifyH("RIGHT")
	targetText:SetWordWrap(false)
	castbar.targetText = targetText

	local spellText = createText(castbar, config.castbarFont)
	spellText:SetPoint("LEFT", TEXT_INSET, 0)
	spellText:SetPoint("RIGHT", targetText, "LEFT", -TEXT_INSET, 0)
	spellText:SetJustifyH("LEFT")
	spellText:SetWordWrap(false)
	castbar.spellText = spellText
end

local function styleCastTexts(castbar)
	ns.SetFont(castbar.targetText, config.castbarFont.size, config.castbarFont.outline)
	styleText(castbar.spellText, config.castbarFont)
end

NamePlates.CreateHolder = createHolder
NamePlates.StyleHolder = styleHolder
NamePlates.CreateText = createText
NamePlates.CreateCastTexts = createCastTexts
NamePlates.StyleCastTexts = styleCastTexts

local function edgeTexture(edge, layer, blend, alpha)
	local texture = edge:CreateTexture(nil, layer)
	texture:SetTexture(ns.Media.border)
	texture:SetBlendMode(blend)
	texture:SetVertexColor(1, 1, 1, alpha)
	return texture
end

local function edgeCorner(edge, layer, blend, alpha, point, segment, left, right, top, bottom)
	local texture = edgeTexture(edge, layer, blend, alpha)
	texture:SetSize(TARGET_EDGE_CORNER, TARGET_EDGE_CORNER)
	texture:SetPoint(point)
	local u = segment * 16
	texture:SetTexCoord((u + left) / 128, (u + right) / 128, top / 16, bottom / 16)
	return texture
end

local function createEdgeTextures(edge, layer, blend, alpha)
	local topLeft = edgeCorner(edge, layer, blend, alpha, "TOPLEFT", 4, 1, 6, 1, 6)
	local topRight = edgeCorner(edge, layer, blend, alpha, "TOPRIGHT", 5, 10, 15, 1, 6)
	local bottomLeft = edgeCorner(edge, layer, blend, alpha, "BOTTOMLEFT", 6, 1, 6, 10, 15)
	local bottomRight = edgeCorner(edge, layer, blend, alpha, "BOTTOMRIGHT", 7, 10, 15, 10, 15)

	local left = edgeTexture(edge, layer, blend, alpha)
	left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
	left:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT")
	left:SetTexCoord(1 / 128, 6 / 128, 1 / 16, 15 / 16)
	local right = edgeTexture(edge, layer, blend, alpha)
	right:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT")
	right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")
	right:SetTexCoord(26 / 128, 31 / 128, 1 / 16, 15 / 16)
	local top = edgeTexture(edge, layer, blend, alpha)
	top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
	top:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMLEFT")
	top:SetTexCoord(33 / 128, 1 / 16, 38 / 128, 1 / 16, 33 / 128, 15 / 16, 38 / 128, 15 / 16)
	local bottom = edgeTexture(edge, layer, blend, alpha)
	bottom:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
	bottom:SetTexCoord(58 / 128, 1 / 16, 63 / 128, 1 / 16, 58 / 128, 15 / 16, 63 / 128, 15 / 16)
end

function NamePlates.CreateTargetEdge(parent, outset)
	local edge = CreateFrame("Frame", nil, parent)
	edge:SetPoint("TOPLEFT", -outset, outset)
	edge:SetPoint("BOTTOMRIGHT", outset, -outset)
	createEdgeTextures(edge, "BORDER", "BLEND", TARGET_RELIEF_ALPHA)
	createEdgeTextures(edge, "ARTWORK", "ADD", 1)
	edge:Hide()
	return edge
end

local function setupHealthbar(plate, healthbar, blizzardBackground)
	local holder = createHolder(plate, plate:GetFrameLevel())
	holder:SetPoint("TOPLEFT")
	plate.holder = holder

	local targetEdge = NamePlates.CreateTargetEdge(holder, TARGET_EDGE_OUTSET)
	targetEdge:SetFrameLevel(holder:GetFrameLevel())
	holder.targetEdge = targetEdge

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
	icon:SetNonBlocking(true)
	icon:SetSize(config.castbarIconSize, config.castbarIconSize)
	icon:SetPoint("RIGHT", holder, "LEFT", -ICON_GAP, 0)
	NamePlates.SkinIcon(castbar, icon)
	castbar.icon = icon
	castbar.blizzardIcon = blizzardIcon
	blizzardIcon:SetParent(trash)

	NamePlates.CreateShield(castbar)

	createCastTexts(castbar)

	castbar.glow = ns.Cast.CreateGlow(castbar, holder, CAST_GLOW_SIZE)
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
	resultIcon:SetNonBlocking(true)
	resultIcon:SetPoint("RIGHT", result, "LEFT", -ICON_GAP, 0)
	NamePlates.SkinIcon(result, resultIcon)
	result.icon = resultIcon
	local resultText = createText(result, config.castbarFont)
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

local function styleArenaLabel(plate)
	local font = config.arenaNumberFont
	ns.SetFont(plate.arenaLabel, font.size, font.outline, true)
end

local function setupNamePlate(plate, info)
	local healthbar, castbar = info.healthbar, info.castbar
	local threat, background, castBorder, castShield, castIcon =
		info.threat, info.border, info.castBorder, info.castShield, info.castIcon
	local highlight, name, level, bossIcon, raidIcon, elite =
		info.highlight, info.nameText, info.levelText, info.bossIcon, info.raidIcon, info.eliteIcon

	ns.Mixin(plate, PlateMixin)
	plate.info = info
	plate.settings = config.enemyNpc

	local overlay = CreateFrame("Frame", nil, plate)
	overlay:SetAllPoints()
	plate.overlay = overlay

	setupHealthbar(plate, healthbar, background)
	setupCastbar(plate, castbar, castIcon, castShield)
	local setups = NamePlates.onPlateSetup
	for i = 1, #setups do
		setups[i](plate)
	end

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

	if castbar:IsShown() then
		castbar:OnShow()
	end

	plates[#plates + 1] = plate
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
		if plate:IsShown() and not plate.hiddenByName then
			count = count + 1
			stack[count] = plate
			plate.stackIndex = i
			if plate:IsTarget() then
				plate.stackKey = -huge
			else
				plate.stackKey = plate:GetTop() or 0
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
		if plate:IsShown() and not plate.hiddenByName and plate.reaction ~= FRIENDLY and not plate.totem:IsShown() then
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

	local step = SPREAD_SPEED * min(elapsed / SPREAD_FRAME_TIME, SPREAD_MAX_STEPS)
	for i = 1, count do
		local plate = spread[i]
		local x, y, pos = plate.spreadX, plate.spreadY, plate.spreadPos
		local settings = plate.settings
		local halfWidth = settings.width / 2 + BORDER_INSET
		local ySpace = settings.height + BORDER_INSET * 2 + SPREAD_GAP
		local minDist, reset = huge, true
		for j = 1, count do
			if i ~= j then
				local other = spread[j]
				if abs(x - other.spreadX) < halfWidth + other.settings.width / 2 + BORDER_INSET then
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

local layerHandlers = {
	created = setupNamePlate,
	shown = PlateMixin.OnShow,
	hidden = PlateMixin.OnHide,
	renamed = PlateMixin.OnShow,
	recolored = PlateMixin.UpdateColors,
	update = PlateMixin.OnUpdate,
}

local function applyStyle()
	updateHiddenNames()
	for i = 1, #plates do
		local plate = plates[i]
		styleText(plate.name, config.nameFont)
		styleText(plate.healthbar.percent, config.percentFont)
		styleHolder(plate.holder)
		styleHolder(plate.castbar.holder)
		NamePlates.Totems.ApplyStyle(plate)
		plate.borderState = nil
		plate.nameR = nil
		local percent = plate.healthbar.percent
		percent.template = nil
		percent:SetText("")
		styleArenaLabel(plate)
		applyHighlight(plate)
		plate:UpdateColors()
		if plate:IsShown() then
			plate:OnShow()
		end
		local castbar = plate.castbar
		styleCastTexts(castbar)
		local result = castbar.result
		styleText(result.text, config.castbarFont)
		styleHolder(result)
		result:Hide()
		if castbar:IsShown() then
			castbar:OnShow()
		end
	end
end

local function onIdentity(plate)
	if not plate:IsShown() then
		return
	end
	if config.totemIcons and NamePlates.Totems.Identify(plate) ~= plate.totemSpell then
		plate:OnShow()
	else
		plate:UpdateColors()
	end
end

function NamePlates:Initialize()
	WorldChildren.UpdatePixel()
	updateHiddenNames()
	NamePlates.RegisterPlugin({
		name = "style",
		Identity = onIdentity,
	})
	local function onPixelChanged()
		WorldChildren.UpdatePixel()
		applyStyle()
	end
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", onPixelChanged)
	self:RegisterEvent(ns.E.PIXEL_CHANGED, onPixelChanged)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", onTargetChanged)
	self:RegisterUnitEvent("UNIT_AURA", "target", onTargetAura)
	self:RegisterEvent(ns.E.CAST_INTERRUPTED, onCastInterrupter)
	self:RegisterEvent(ns.E.CAST_SILENCED, onCastSilenced)
	self:RegisterUnitEvent("UNIT_TARGET", "target", onTargetTargetChanged)
	self:RegisterUnitEvent("UNIT_SPELLCAST_START", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "target", onTargetCastStart)
	self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target", onTargetCastStop)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target", onTargetCastStop)
	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target", onTargetCastInterrupted)
	self:WatchConfig("namePlates", applyStyle)
	self:WatchConfig("theme", applyStyle)
	self:WatchConfig("castbar", applyStyle)
	if config.enabled then
		PlateLayer.Register(layerHandlers)
		CreateFrame("Frame"):SetScript("OnUpdate", function(_, elapsed)
			updateStacking()
			updateSpread(elapsed)
		end)
	end
end
