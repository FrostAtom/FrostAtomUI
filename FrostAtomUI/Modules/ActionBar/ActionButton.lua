local ADDON_NAME, ns = ...

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetActionTexture = GetActionTexture
local GetActionCooldown = GetActionCooldown
local GetActionCount = GetActionCount
local GetActionText = GetActionText
local GetBindingKey = GetBindingKey
local HasAction = HasAction
local IsActionInRange = IsActionInRange
local IsUsableAction = IsUsableAction
local IsEquippedAction = IsEquippedAction
local IsCurrentAction = IsCurrentAction
local IsAutoRepeatAction = IsAutoRepeatAction
local IsConsumableAction = IsConsumableAction
local IsStackableAction = IsStackableAction
local InCombatLockdown = InCombatLockdown
local PickupAction = PickupAction
local GetActionInfo = GetActionInfo
local GetMacroSpell = GetMacroSpell
local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local GetTime = GetTime
local GameTooltip = GameTooltip
local max = math.max
local band = bit.band

local Media = ns.Media
local Auras = ns.Auras
local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

local config = ns.Config.actionBar
local WHITE = { 1, 1, 1 }
local BUTTON_NAME = ADDON_NAME .. "ActionButton%d"
local BINDING_NAME = "CLICK " .. BUTTON_NAME .. ":LeftButton"
local SLOT_NAME = ADDON_NAME .. "ActionSlot%d"
ActionBar.BINDING_NAME = BINDING_NAME
local RANGE_CHECK_INTERVAL = 0.1
local GCD_DURATION = 1.5
local MAX_INTERRUPT_LOCKOUT = 8
local INTERRUPT_TOLERANCE = 0.5
local RECEIVE_DRAG_SNIPPET = [[
	if not kind then
		return false
	end
	return "action", self:GetAttribute("action")
]]
local SLOT_VISIBILITY_SNIPPET = [[
	local button = self:GetFrameRef("button")
	if self:IsShown() and button:GetAttribute("slotactive") then
		button:Show()
	else
		button:Hide()
	end
]]

local AURA_POSSESS, AURA_CONFUSE, AURA_CHARM, AURA_FEAR, AURA_STUN = 2, 5, 6, 7, 12
local AURA_PACIFY, AURA_SILENCE, AURA_PACIFY_SILENCE, AURA_AOE_CHARM = 25, 27, 60, 177
local AURA_STATE_IMMUNITY, AURA_SCHOOL_IMMUNITY, AURA_DISPEL_IMMUNITY = 38, 39, 41
local AURA_MECHANIC_IMMUNITY, AURA_IMMUNE_AURA_APPLY_SCHOOL = 77, 267

local USABLE_STUNNED, USABLE_FEARED, USABLE_CONFUSED = 1, 2, 4
local IGNORES_LOSS_OF_CONTROL, IGNORES_CASTER_AURAS, IMMUNE_SHIELD = 8, 16, 32
local UNAFFECTED_BY_INVULNERABILITY, UNAFFECTED_BY_SCHOOL_IMMUNE = 1, 2

local PREVENTION_SILENCE, PREVENTION_PACIFY = 1, 2
local MECHANIC_BANISH_MASK = 262144
local PAIN_SUPPRESSION = 33206
local GLYPH_OF_PAIN_SUPPRESSION = 63248

local LockoutData = ns.LockoutData
local SPELL_RANKS = LockoutData.SPELL_RANKS
local LOCKOUT_AURAS = LockoutData.AURAS
local DEFAULT_SPELL = { PREVENTION_SILENCE, 0, 0 }
local DEFAULT_ITEM = { 0, 0, 0 }

local function mapByName(spells)
	local byName = {}
	for id, spell in pairs(spells) do
		local name = GetSpellInfo(id)
		if name then
			byName[name] = spell
		end
	end
	return byName
end

local SPELL_NAMES = mapByName(LockoutData.SPELLS)
local ITEM_SPELL_NAMES = mapByName(LockoutData.ITEM_SPELLS)

local activeControls = {}
local controlCount = 0

local function auraHasEffect(aura, auraType)
	for i = 6, #aura, 2 do
		if aura[i] == auraType then
			return true
		end
	end
	return false
end

local function hasControl(first, auraType, otherType, thirdType)
	for i = first, controlCount do
		local aura = activeControls[i].aura
		if
			auraHasEffect(aura, auraType)
			or otherType and auraHasEffect(aura, otherType)
			or thirdType and auraHasEffect(aura, thirdType)
		then
			return true
		end
	end
	return false
end

local function cancelsAuraEffect(spell, aura, auraType, effectMechanic)
	if band(aura[5], UNAFFECTED_BY_INVULNERABILITY) ~= 0 then
		return false
	end
	for i = 4, #spell, 2 do
		local immunity, value = spell[i], spell[i + 1]
		if immunity == AURA_STATE_IMMUNITY then
			if value == auraType then
				return true
			end
		elseif immunity == AURA_SCHOOL_IMMUNITY or immunity == AURA_IMMUNE_AURA_APPLY_SCHOOL then
			if band(aura[5], UNAFFECTED_BY_SCHOOL_IMMUNE) == 0 and band(aura[1], value) ~= 0 then
				return true
			end
		elseif immunity == AURA_DISPEL_IMMUNITY then
			if value == aura[4] then
				return true
			end
		elseif immunity == AURA_MECHANIC_IMMUNITY then
			if value == aura[2] or value == effectMechanic then
				return true
			end
		end
	end
	return false
end

local function cancelsControl(spell, first, auraType)
	local found = false
	for i = first, controlCount do
		local aura = activeControls[i].aura
		for j = 6, #aura, 2 do
			if aura[j] == auraType then
				if not cancelsAuraEffect(spell, aura, auraType, aura[j + 1]) then
					return true, false
				end
				found = true
			end
		end
	end
	return found, found
end

local function clientCancels(spell, first, auraType)
	local _, cancelled = cancelsControl(spell, first, auraType)
	return cancelled
end

local function serverCancels(spell, first, auraType)
	local found, cancelled = cancelsControl(spell, first, auraType)
	return cancelled or not found
end

local function hasDisallowedMechanic(first, auraType, allowed)
	for i = first, controlCount do
		local aura = activeControls[i].aura
		local mechanics = aura[3]
		if mechanics ~= 0 and band(mechanics, allowed) == 0 and auraHasEffect(aura, auraType) then
			return true
		end
	end
	return false
end

local function hasBanish(first)
	for i = first, controlCount do
		if band(activeControls[i].aura[3], MECHANIC_BANISH_MASK) ~= 0 then
			return true
		end
	end
	return false
end

local function hasGlyph(glyphSpell)
	for i = 1, GetNumGlyphSockets() do
		local enabled, _, spellId = GetGlyphSocketInfo(i)
		if enabled and spellId == glyphSpell then
			return true
		end
	end
	return false
end

local function clientBlocks(spell, first)
	local prevention, flags = spell[1], spell[2]
	local ignoresControl = band(flags, IGNORES_LOSS_OF_CONTROL) ~= 0
	if
		hasControl(first, AURA_CHARM, AURA_AOE_CHARM, AURA_POSSESS)
		and not (
			clientCancels(spell, first, AURA_CHARM)
			or clientCancels(spell, first, AURA_AOE_CHARM)
			or clientCancels(spell, first, AURA_POSSESS)
		)
	then
		return true
	end
	if
		hasControl(first, AURA_STUN)
		and not ignoresControl
		and band(flags, USABLE_STUNNED) == 0
		and not clientCancels(spell, first, AURA_STUN)
	then
		return true
	end
	if
		prevention == PREVENTION_SILENCE
		and hasControl(first, AURA_SILENCE, AURA_PACIFY_SILENCE)
		and not (clientCancels(spell, first, AURA_SILENCE) or clientCancels(spell, first, AURA_PACIFY_SILENCE))
	then
		return true
	end
	if
		prevention == PREVENTION_PACIFY
		and hasControl(first, AURA_PACIFY, AURA_PACIFY_SILENCE)
		and not (clientCancels(spell, first, AURA_PACIFY) or clientCancels(spell, first, AURA_PACIFY_SILENCE))
	then
		return true
	end
	if
		hasControl(first, AURA_FEAR)
		and not ignoresControl
		and band(flags, USABLE_FEARED) == 0
		and not clientCancels(spell, first, AURA_FEAR)
	then
		return true
	end
	return hasControl(first, AURA_CONFUSE)
		and not ignoresControl
		and band(flags, USABLE_CONFUSED) == 0
		and not clientCancels(spell, first, AURA_CONFUSE)
end

local function serverBlocks(spell, first)
	local prevention, flags, allowed = spell[1], spell[2], spell[3]
	if band(flags, IGNORES_CASTER_AURAS) ~= 0 then
		return false
	end
	if
		hasControl(first, AURA_CHARM, AURA_AOE_CHARM, AURA_POSSESS)
		and not (
			serverCancels(spell, first, AURA_CHARM)
			and serverCancels(spell, first, AURA_AOE_CHARM)
			and serverCancels(spell, first, AURA_POSSESS)
		)
	then
		return true
	end
	if hasControl(first, AURA_STUN) then
		if
			band(flags, USABLE_STUNNED) ~= 0
			and (spell ~= SPELL_RANKS[PAIN_SUPPRESSION] or hasGlyph(GLYPH_OF_PAIN_SUPPRESSION))
		then
			return hasDisallowedMechanic(first, AURA_STUN, allowed)
		end
		return not serverCancels(spell, first, AURA_STUN) or band(flags, IMMUNE_SHIELD) ~= 0 and hasBanish(first)
	end
	if
		prevention == PREVENTION_SILENCE
		and hasControl(first, AURA_SILENCE, AURA_PACIFY_SILENCE)
		and not (serverCancels(spell, first, AURA_SILENCE) and serverCancels(spell, first, AURA_PACIFY_SILENCE))
	then
		return true
	end
	if
		prevention == PREVENTION_PACIFY
		and hasControl(first, AURA_PACIFY, AURA_PACIFY_SILENCE)
		and not (serverCancels(spell, first, AURA_PACIFY) and serverCancels(spell, first, AURA_PACIFY_SILENCE))
	then
		return true
	end
	if hasControl(first, AURA_FEAR) then
		if band(flags, USABLE_FEARED) ~= 0 then
			return hasDisallowedMechanic(first, AURA_FEAR, allowed)
		end
		return not serverCancels(spell, first, AURA_FEAR)
	end
	if hasControl(first, AURA_CONFUSE) then
		if band(flags, USABLE_CONFUSED) ~= 0 then
			return hasDisallowedMechanic(first, AURA_CONFUSE, allowed)
		end
		return not serverCancels(spell, first, AURA_CONFUSE)
	end
	return false
end

local function isBlocked(spell, first)
	return clientBlocks(spell, first) or serverBlocks(spell, first)
end

local interruptedAt = -math.huge
local actionButtons = {}
local hasTarget = false

local DRAG_MODIFIERS = {
	shift = IsShiftKeyDown,
	ctrl = IsControlKeyDown,
	alt = IsAltKeyDown,
}

local ACTION_EVENTS = {
	UPDATE_SHAPESHIFT_FORM = "Update",
	UPDATE_MACROS = "Update",
	ACTIONBAR_UPDATE_USABLE = "UpdateUsable",
	ACTIONBAR_UPDATE_COOLDOWN = "UpdateCooldown",
	ACTIONBAR_UPDATE_STATE = "UpdateState",
	PLAYER_EQUIPMENT_CHANGED = "UpdateEquipped",
	UNIT_ENTERED_VEHICLE = "UpdateStateForUnit",
	UNIT_EXITED_VEHICLE = "UpdateStateForUnit",
	TRADE_SKILL_SHOW = "UpdateState",
	TRADE_SKILL_CLOSE = "UpdateState",
	COMPANION_UPDATE = "UpdateStateForCompanion",
	BAG_UPDATE = "UpdateName",
	SPELL_UPDATE_USABLE = "UpdateUsable",
}

local KEY_ABBREVIATIONS = {
	{ "BUTTON", "B" },
	{ "ALT%-", "A" },
	{ "CTRL%-", "C" },
	{ "SHIFT%-", "S" },
	{ "MOUSEWHEELUP", "WU" },
	{ "MOUSEWHEELDOWN", "WD" },
	{ "CAPSLOCK", "Caps\nLock" },
}

local function abbreviateKey(key)
	for i = 1, #KEY_ABBREVIATIONS do
		local pair = KEY_ABBREVIATIONS[i]
		key = key:gsub(pair[1], pair[2])
	end
	return key
end
local function updateHotkey(button)
	local key = GetBindingKey(button.bindingName)
	if not key and button.blizzardBinding then
		key = GetBindingKey(button.blizzardBinding)
	end
	if key then
		button.hotkey:SetText(abbreviateKey(key))
		button.hotkey:Show()
	else
		button.hotkey:Hide()
	end
end
ActionBar.UpdateHotkey = updateHotkey

local ActionButtonMixin = {}

local function applyColors(button, r, g, b)
	button.icon:SetVertexColor(r, g, b)
	button:GetNormalTexture():SetVertexColor(r, g, b)
end

function ActionButtonMixin:UpdateColors()
	local color
	if self.notEnoughMana then
		color = config.manaColor
	elseif self.outOfRange and config.rangeIconTint then
		color = config.rangeColor
	elseif self.usable then
		color = WHITE
	else
		color = config.unusableColor
	end
	applyColors(self, color[1], color[2], color[3])

	color = self.outOfRange and config.rangeHotkey and config.rangeColor or WHITE
	self.hotkey:SetTextColor(color[1], color[2], color[3])
end

function ActionButtonMixin:UpdateUsable()
	self.usable, self.notEnoughMana = IsUsableAction(self.action)
	self:UpdateColors()
end

function ActionButtonMixin:UpdateEquipped()
	ActionBar:SetButtonEquipped(self, IsEquippedAction(self.action))
end

function ActionButtonMixin:UpdateState()
	ActionBar:SetButtonChecked(self, IsCurrentAction(self.action) or IsAutoRepeatAction(self.action))
end

function ActionButtonMixin:UpdateStateForUnit(unit)
	if unit == "player" then
		self:UpdateState()
	end
end

function ActionButtonMixin:UpdateStateForCompanion(companionType)
	if companionType == "MOUNT" then
		self:UpdateState()
	end
end

function ActionButtonMixin:UpdateBindings()
	updateHotkey(self)
end

function ActionButtonMixin:UpdateName()
	local action = self.action
	if IsConsumableAction(action) or IsStackableAction(action) then
		local count = GetActionCount(action)
		self.count:SetText(count > 999 and "*" or count)
		self.name:SetText("")
	else
		self.count:SetText("")
		self.name:SetText(GetActionText(action))
	end
end

function ActionButtonMixin:UpdateGrid()
	if InCombatLockdown() then
		return
	end
	local slot = self.slot
	local extra = (config.hideEmptyButtons and 0 or 1) + (ActionBar:IsBindMode() and 1 or 0)
	local grid = max(slot:GetAttribute("showgrid") - self.gridExtra + extra, 0)
	self.gridExtra = extra
	slot:SetAttribute("showgrid", grid)
	if grid > 0 then
		ActionButton_ShowGrid(slot)
	else
		ActionButton_HideGrid(slot)
	end
	ns.SetShown(self, self:GetAttribute("slotactive") and slot:IsShown())
end

function ActionButtonMixin:UpdateIcon()
	local texture = GetActionTexture(self.action)
	if not texture then
		texture = Media.emptySlot
	elseif texture == "" then
		texture = Media.questionMark
	end
	self.icon:SetTexture(texture)
end

local function spellLockout(spellId, name)
	return SPELL_RANKS[spellId] or SPELL_NAMES[name] or DEFAULT_SPELL
end

local function itemLockout(item)
	local name = GetItemSpell(item)
	return name and (ITEM_SPELL_NAMES[name] or DEFAULT_ITEM)
end

local function actionLockout(action)
	local actionType, id, _, spellId = GetActionInfo(action)
	if actionType == "spell" then
		return spellId and spellLockout(spellId, GetSpellInfo(spellId))
	elseif actionType == "item" then
		return itemLockout(id)
	elseif actionType == "macro" then
		local name = GetMacroSpell(id)
		if name then
			local link = GetSpellLink(name)
			return spellLockout(link and tonumber(link:match("spell:(%d+)")), name)
		end
		local _, link = GetMacroItem(id)
		return link and itemLockout(link)
	end
end

function ActionButtonMixin:UpdateLockoutSpell()
	self.lockoutSpell = actionLockout(self.action)
end

function ActionButtonMixin:UpdateLockout(now)
	local start, duration, endTime = 0, 0, 0
	if self.hasAction then
		local spell = self.lockoutSpell
		if spell and controlCount > 0 and isBlocked(spell, 1) then
			local first = 2
			while first <= controlCount and isBlocked(spell, first) do
				first = first + 1
			end
			local control = activeControls[first - 1]
			start, duration, endTime = control.expires - control.duration, control.duration, control.expires
		end
		if self.schoolLocked and self.cooldownEnd > endTime then
			start, duration, endTime = self.cooldownEnd - self.cooldownDuration, self.cooldownDuration, self.cooldownEnd
		end
	end

	local lockout = self.lockout
	if endTime > now and endTime >= self.cooldownEnd then
		if not lockout then
			lockout = CreateFrame("Cooldown", nil, self)
			lockout:SetAllPoints()
			lockout:SetFrameLevel(self.cooldown:GetFrameLevel() + 1)
			lockout.tint = lockout:CreateTexture(nil, "BACKGROUND")
			lockout.tint:SetAllPoints()
			lockout.tint:SetTexture(Media.blank)
			self.lockout = lockout
		end
		local color = config.lossOfControlColor
		lockout.tint:SetVertexColor(color[1], color[2], color[3], color[4])
		if not lockout:IsShown() then
			lockout:Show()
			self.cooldown:SetAlpha(0)
		end
		if start ~= lockout.start or duration ~= lockout.duration then
			lockout.start, lockout.duration = start, duration
			lockout:SetCooldown(start, duration)
		end
		self.lockoutEnd = endTime
	elseif lockout and lockout:IsShown() then
		lockout.start = nil
		lockout:Hide()
		self.cooldown:SetAlpha(1)
		self.lockoutEnd = nil
	end
end

function ActionButtonMixin:UpdateCooldown()
	local start, duration, enable = GetActionCooldown(self.action)
	CooldownFrame_SetTimer(self.cooldown, start, duration, enable)

	local now = GetTime()
	local endTime = start + duration
	if enable == 1 and duration > GCD_DURATION and endTime > now then
		self.cooldownEnd, self.cooldownDuration = endTime, duration
		self.schoolLocked = config.interruptLockout
			and duration <= MAX_INTERRUPT_LOCKOUT
			and start > interruptedAt - INTERRUPT_TOLERANCE
			and start < interruptedAt + INTERRUPT_TOLERANCE
	else
		self.cooldownEnd, self.cooldownDuration = 0, 0
		self.schoolLocked = false
	end

	local desaturated = config.desaturateOnCooldown and self.cooldownEnd > 0 or false
	if desaturated ~= self.desaturated then
		self.desaturated = desaturated
		self.icon:SetDesaturated(desaturated)
	end

	self:UpdateLockout(now)

	local expiry = self.lockoutEnd
	if desaturated and (not expiry or self.cooldownEnd < expiry) then
		expiry = self.cooldownEnd
	end
	self.expiry = expiry
end

function ActionButtonMixin:Update()
	local action = self.action

	if HasAction(action) then
		for event, method in pairs(ACTION_EVENTS) do
			self:RegisterEvent(event, method)
		end

		self.usable, self.notEnoughMana = IsUsableAction(action)
		self.outOfRange = hasTarget and IsActionInRange(action) == 0
		self.hasAction = true
	elseif self.hasAction then
		for event, method in pairs(ACTION_EVENTS) do
			self:UnregisterEvent(event, method)
		end

		self.usable = true
		self.notEnoughMana, self.outOfRange = nil, nil
		self.hasAction = false
	end

	self:UpdateGrid()
	self:UpdateColors()
	self:UpdateEquipped()
	self:UpdateState()
	self:UpdateBindings()
	self:UpdateIcon()
	self:UpdateLockoutSpell()
	self:UpdateCooldown()
	self:UpdateName()
end

function ActionButtonMixin:UpdateRange()
	local outOfRange = hasTarget and IsActionInRange(self.action) == 0
	if outOfRange ~= self.outOfRange then
		self.outOfRange = outOfRange
		self:UpdateColors()
	end
end

local nextRangeCheck = 0

local rangeTicker = CreateFrame("Frame")
rangeTicker:Hide()
rangeTicker:SetScript("OnUpdate", function()
	local now = GetTime()
	if now < nextRangeCheck then
		return
	end
	nextRangeCheck = now + RANGE_CHECK_INTERVAL

	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			local expiry = button.expiry
			if expiry and now >= expiry then
				button:UpdateCooldown()
			end
			if hasTarget and button:IsVisible() then
				button:UpdateRange()
			end
		end
	end
end)

function ActionBar:UpdateGrid()
	for i = 1, #actionButtons do
		actionButtons[i]:UpdateGrid()
	end
end

local function onTargetChanged()
	hasTarget = UnitExists("target") and true or false
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			button:UpdateRange()
		end
	end
end

function ActionButtonMixin:OnAttributeChanged(attribute, value)
	if attribute == "action" then
		self.action = value
		self:Update()
	end
end

function ActionButtonMixin:OnDragStart()
	local modifier = DRAG_MODIFIERS[config.dragModifier]
	if (not modifier or modifier()) and not InCombatLockdown() then
		PickupAction(self.action)
	end
end

function ActionButtonMixin:ACTIONBAR_SLOT_CHANGED(slot)
	if slot == 0 or slot == self.action then
		self:Update()
	end
end

function ActionButtonMixin:SetTooltip()
	if HasAction(self.action) then
		GameTooltip:SetAction(self.action)
	else
		GameTooltip:Hide()
	end
end

function ActionBar:CreateActionButton(action, parent)
	local button = CreateFrame("Button", BUTTON_NAME:format(action), parent, "SecureActionButtonTemplate")
	ns.Mixin(button, ns.EventMixin, ActionButtonMixin)

	button:SetAttribute("checkselfcast", true)
	button:SetAttribute("type", "action")
	button:SetAttribute("action", action)
	button:SetAttribute("slotactive", true)
	button.action = action
	button.bindingName = BINDING_NAME:format(action)

	self:StyleButton(button)

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	CooldownTimer:Attach(button.cooldown, config.cooldownFont.size)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()

	button.hotkey = button:CreateFontString(nil, "ARTWORK")
	button.hotkey:SetPoint("TOPRIGHT")
	button.hotkey:SetJustifyH("LEFT")
	button.hotkey:SetJustifyV("BOTTOM")
	self:StyleHotkey(button.hotkey)

	button.name = button:CreateFontString(nil, "ARTWORK")
	button.name:SetPoint("BOTTOM", 0, 2)
	ns.SetFont(button.name, config.nameFont.size, config.nameFont.outline)

	button.count = button:CreateFontString(nil, "ARTWORK")
	button.count:SetPoint("BOTTOMRIGHT", -2, 2)
	ns.SetFont(button.count, config.countFont.size, config.countFont.outline)

	button:RegisterForClicks("LeftButtonDown")
	button:RegisterForDrag(config.dragButton)
	button:SetScript("OnDragStart", button.OnDragStart)
	button:SetScript("OnAttributeChanged", button.OnAttributeChanged)
	parent:WrapScript(button, "OnReceiveDrag", RECEIVE_DRAG_SNIPPET)
	button:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	button:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	button:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
	self:AttachTooltip(button, button.SetTooltip)

	local slot = CreateFrame("CheckButton", SLOT_NAME:format(action), nil, "ActionBarButtonTemplate")
	slot:SetAlpha(0)
	slot:EnableMouse(false)
	slot:SetScript("OnUpdate", nil)
	slot:SetAttribute("action", action)
	SecureHandlerSetFrameRef(slot, "button", button)
	SecureHandlerSetFrameRef(button, "slot", slot)
	parent:WrapScript(slot, "OnShow", SLOT_VISIBILITY_SNIPPET)
	parent:WrapScript(slot, "OnHide", SLOT_VISIBILITY_SNIPPET)
	button.slot = slot
	button.gridExtra = 0

	button.usable = true
	button.cooldownEnd = 0
	button:Update()

	if #actionButtons == 0 then
		self:RegisterEvent("PLAYER_TARGET_CHANGED", onTargetChanged)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", onTargetChanged)
		rangeTicker:Show()
	end
	actionButtons[#actionButtons + 1] = button
	return button
end

local function updateCooldowns()
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			button:UpdateCooldown()
		end
	end
end

local scannedControls = {}

local function collectControls(filter, count)
	local auras, auraCount = Auras.Get("player", filter)
	for i = 1, auraCount do
		local aura = auras[i]
		local control = LOCKOUT_AURAS[aura.spellId]
		local duration, expires = aura.duration, aura.expires
		if control and duration and duration > 0 then
			count = count + 1
			local active = scannedControls[count]
			if not active then
				active = {}
				scannedControls[count] = active
			end
			active.aura, active.expires, active.duration = control, expires, duration
		end
	end
	return count
end

local function sortByExpiry(a, b)
	return a.expires < b.expires
end

local function scanLossOfControl()
	local count = 0
	if config.lossOfControl then
		count = collectControls("HELPFUL", collectControls("HARMFUL", 0))
	end
	for i = #scannedControls, count + 1, -1 do
		scannedControls[i] = nil
	end
	table.sort(scannedControls, sortByExpiry)

	local changed = count ~= controlCount
	for i = 1, count do
		local scanned, active = scannedControls[i], activeControls[i]
		if not active then
			active = {}
			activeControls[i] = active
		end
		if active.aura ~= scanned.aura or active.expires ~= scanned.expires or active.duration ~= scanned.duration then
			active.aura, active.expires, active.duration = scanned.aura, scanned.expires, scanned.duration
			changed = true
		end
	end
	controlCount = count
	if changed then
		updateCooldowns()
	end
end

local playerGUID

local function onCombatLog(_, _, event, _, _, _, destGUID)
	if event ~= "SPELL_INTERRUPT" then
		return
	end
	playerGUID = playerGUID or UnitGUID("player")
	if destGUID == playerGUID then
		interruptedAt = GetTime()
		updateCooldowns()
	end
end

function ActionBar:UpdateLockoutTracking()
	if config.lossOfControl then
		self:RegisterUnitEvent("UNIT_AURA", "player", scanLossOfControl)
	else
		self:UnregisterUnitEvent("UNIT_AURA", "player", scanLossOfControl)
	end
	if config.interruptLockout then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	end
	scanLossOfControl()
	updateCooldowns()
end
