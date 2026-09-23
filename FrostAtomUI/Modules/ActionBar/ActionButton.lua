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
local PlaceAction = PlaceAction
local GetActionInfo = GetActionInfo
local GetMacroSpell = GetMacroSpell
local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local GetTime = GetTime
local GameTooltip = GameTooltip

local Media = ns.Media
local Auras = ns.Auras
local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

local config = ns.Config.actionBar
local WHITE = { 1, 1, 1 }
local BUTTON_NAME = ADDON_NAME .. "ActionButton%d"
local BINDING_NAME = "CLICK " .. BUTTON_NAME .. ":LeftButton"
local RANGE_CHECK_INTERVAL = 0.1
local GCD_DURATION = 1.5
local MAX_INTERRUPT_LOCKOUT = 8
local INTERRUPT_TOLERANCE = 0.5

local LOCK, SILENCE = 1, 2

local LOCK_SPELLS = {
	47481, -- Gnaw
	51209, -- Hungering Cold
	5211, -- Bash
	33786, -- Cyclone
	2637, -- Hibernate
	22570, -- Maim
	9005, -- Pounce
	60210, -- Freezing Arrow Effect
	3355, -- Freezing Trap Effect
	24394, -- Intimidation
	1513, -- Scare Beast
	19503, -- Scatter Shot
	19386, -- Wyvern Sting
	50519, -- Sonic Blast
	50518, -- Ravage
	44572, -- Deep Freeze
	31661, -- Dragon's Breath
	12355, -- Impact
	118, -- Polymorph
	853, -- Hammer of Justice
	2812, -- Holy Wrath
	20066, -- Repentance
	20170, -- Stun
	10326, -- Turn Evil
	605, -- Mind Control
	64044, -- Psychic Horror
	8122, -- Psychic Scream
	9484, -- Shackle Undead
	2094, -- Blind
	1833, -- Cheap Shot
	1776, -- Gouge
	408, -- Kidney Shot
	6770, -- Sap
	39796, -- Stoneclaw Stun
	51514, -- Hex
	710, -- Banish
	6789, -- Death Coil
	5782, -- Fear
	5484, -- Howl of Terror
	6358, -- Seduction
	30283, -- Shadowfury
	22703, -- Inferno Effect
	7922, -- Charge Stun
	12809, -- Concussion Blow
	20253, -- Intercept
	5246, -- Intimidating Shout
	12798, -- Revenge Stun
	46968, -- Shockwave
	20549, -- War Stomp
	30217, -- Adamantite Grenade
	67769, -- Cobalt Frag Bomb
	30216, -- Fel Iron Bomb
}

local SILENCE_SPELLS = {
	47476, -- Strangulate
	34490, -- Silencing Shot
	18469, -- Silenced - Improved Counterspell
	63529, -- Silenced - Shield of the Templar
	15487, -- Silence
	1330, -- Garrote - Silence
	18425, -- Silenced - Improved Kick
	24259, -- Spell Lock
	18498, -- Silenced - Gag Order
	25046, -- Arcane Torrent
}

local ID_CATEGORIES = {
	[31117] = SILENCE, -- Unstable Affliction
	[64058] = false, -- Psychic Horror
}

local CC_USABLE_SPELLS = {
	59752, -- Every Man for Himself
	7744, -- Will of the Forsaken
	45438, -- Ice Block
	642, -- Divine Shield
	33206, -- Pain Suppression
	22812, -- Barkskin
	18499, -- Berserker Rage
	1953, -- Blink
	48792, -- Icebound Fortitude
}

local SILENCE_IMMUNE_CLASSES = {
	WARRIOR = true,
	ROGUE = true,
}

local PHYSICAL_POWER_TYPES = {
	[1] = true,
	[3] = true,
}

local function mapSpellNames(target, spells, value)
	for i = 1, #spells do
		local name = GetSpellInfo(spells[i])
		if name then
			target[name] = value
		end
	end
end

local NAME_CATEGORIES = {}
mapSpellNames(NAME_CATEGORIES, LOCK_SPELLS, LOCK)
mapSpellNames(NAME_CATEGORIES, SILENCE_SPELLS, SILENCE)

local CC_USABLE_NAMES = {}
mapSpellNames(CC_USABLE_NAMES, CC_USABLE_SPELLS, true)

local silenceImmune = SILENCE_IMMUNE_CLASSES[ns.PLAYER_CLASS]
local lockEnd, lockDuration = 0, 0
local silenceEnd, silenceDuration = 0, 0
local interruptedAt = -math.huge
local actionButtons = {}

local DRAG_MODIFIERS = {
	shift = IsShiftKeyDown,
	ctrl = IsControlKeyDown,
	alt = IsAltKeyDown,
}

local ACTION_EVENTS = {
	UPDATE_BINDINGS = "UpdateBindings",
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
		self.name:SetText(count > 999 and "*" or count)
	else
		self.name:SetText(GetActionText(action))
	end
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

local function actionSpellName(action)
	local actionType, id, _, spellId = GetActionInfo(action)
	if actionType == "spell" then
		return spellId and GetSpellInfo(spellId)
	elseif actionType == "macro" then
		return GetMacroSpell(id)
	end
end

function ActionButtonMixin:UpdateSpellFlags()
	local name = actionSpellName(self.action)
	if not name then
		self.ccUsable, self.silenceable = true, false
		return
	end
	self.ccUsable = CC_USABLE_NAMES[name] == true
	if silenceImmune or self.ccUsable then
		self.silenceable = false
	else
		local _, _, _, _, _, powerType = GetSpellInfo(name)
		self.silenceable = not PHYSICAL_POWER_TYPES[powerType]
	end
end

function ActionButtonMixin:UpdateLockout(now)
	local start, duration, endTime = 0, 0, 0
	if self.hasAction then
		if lockEnd > 0 and not self.ccUsable then
			start, duration, endTime = lockEnd - lockDuration, lockDuration, lockEnd
		end
		if silenceEnd > endTime and self.silenceable then
			start, duration, endTime = silenceEnd - silenceDuration, silenceDuration, silenceEnd
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
		self:SetScript("OnUpdate", self.OnUpdate)

		self.usable, self.notEnoughMana = IsUsableAction(action)
		self.outOfRange = IsActionInRange(action) == 0
		self.rangeTimer = 0
		self.hasAction = true
	elseif self.hasAction then
		for event, method in pairs(ACTION_EVENTS) do
			self:UnregisterEvent(event, method)
		end
		self:SetScript("OnUpdate", nil)

		self.usable = true
		self.notEnoughMana, self.outOfRange = nil, nil
		self.hasAction = false
	end

	self:UpdateColors()
	self:UpdateEquipped()
	self:UpdateState()
	self:UpdateBindings()
	self:UpdateIcon()
	self:UpdateSpellFlags()
	self:UpdateCooldown()
	self:UpdateName()
end

function ActionButtonMixin:OnUpdate(elapsed)
	self.rangeTimer = self.rangeTimer - elapsed
	if self.rangeTimer > 0 then
		return
	end
	self.rangeTimer = RANGE_CHECK_INTERVAL

	local expiry = self.expiry
	if expiry and GetTime() >= expiry then
		self:UpdateCooldown()
	end

	local outOfRange = IsActionInRange(self.action) == 0
	if outOfRange ~= self.outOfRange then
		self.outOfRange = outOfRange
		self:UpdateColors()
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

function ActionButtonMixin:OnReceiveDrag()
	if not InCombatLockdown() then
		PlaceAction(self.action)
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
	button.action = action
	button.bindingName = BINDING_NAME:format(action)

	self:StyleButton(button)

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	CooldownTimer:Attach(button.cooldown)

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

	button:RegisterForClicks("LeftButtonDown")
	button:RegisterForDrag(config.dragButton)
	button:SetScript("OnDragStart", button.OnDragStart)
	button:SetScript("OnReceiveDrag", button.OnReceiveDrag)
	button:SetScript("OnAttributeChanged", button.OnAttributeChanged)
	button:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	button:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	self:AttachTooltip(button, button.SetTooltip)

	button.usable = true
	button.cooldownEnd = 0
	button:Update()

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

local function scanLossOfControl()
	local newLockEnd, newLockDuration, newSilenceEnd, newSilenceDuration = 0, 0, 0, 0
	if config.lossOfControl then
		local auras, count = Auras.Get("player", "HARMFUL")
		for i = 1, count do
			local aura = auras[i]
			local category = ID_CATEGORIES[aura.spellId]
			if category == nil then
				category = NAME_CATEGORIES[aura.name]
			end
			local duration, expires = aura.duration, aura.expires
			if category and duration and duration > 0 then
				if category == LOCK then
					if expires > newLockEnd then
						newLockEnd, newLockDuration = expires, duration
					end
				elseif expires > newSilenceEnd then
					newSilenceEnd, newSilenceDuration = expires, duration
				end
			end
		end
	end

	if
		newLockEnd ~= lockEnd
		or newLockDuration ~= lockDuration
		or newSilenceEnd ~= silenceEnd
		or newSilenceDuration ~= silenceDuration
	then
		lockEnd, lockDuration = newLockEnd, newLockDuration
		silenceEnd, silenceDuration = newSilenceEnd, newSilenceDuration
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
