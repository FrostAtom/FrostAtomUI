local ADDON_NAME, ns = ...

local CreateFrame = CreateFrame
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
local IsAltKeyDown = IsAltKeyDown
local InCombatLockdown = InCombatLockdown
local PickupAction = PickupAction
local PlaceAction = PlaceAction
local GameTooltip = GameTooltip
local pairs = pairs

local Media = ns.Media
local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

local BUTTON_NAME = ADDON_NAME .. "ActionButton%d"
local BINDING_NAME = "CLICK " .. BUTTON_NAME .. ":LeftButton"
local RANGE_CHECK_INTERVAL = 0.1

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
ActionBar.AbbreviateKey = abbreviateKey

local ActionButtonMixin = {}

local function applyColors(button, r, g, b)
	button.icon:SetVertexColor(r, g, b)

	local border = button:GetNormalTexture()
	if button.checked then
		border:SetVertexColor(1, 0.8, 0)
	elseif button.equipped then
		border:SetVertexColor(0.2, 0.8, 0.2)
	else
		border:SetVertexColor(r, g, b)
	end
end

function ActionButtonMixin:UpdateColors()
	if self.notEnoughMana then
		applyColors(self, 0.5, 0.5, 1)
	elseif self.outOfRange then
		applyColors(self, 1, 0, 0)
	elseif self.usable then
		applyColors(self, 1, 1, 1)
	else
		applyColors(self, 0.4, 0.4, 0.4)
	end
end

function ActionButtonMixin:UpdateUsable()
	self.usable, self.notEnoughMana = IsUsableAction(self.action)
	self:UpdateColors()
end

function ActionButtonMixin:UpdateEquipped()
	self.equipped = IsEquippedAction(self.action)
	self:UpdateColors()
end

function ActionButtonMixin:UpdateState()
	self.checked = IsCurrentAction(self.action) or IsAutoRepeatAction(self.action)
	self:UpdateColors()
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
	local key = GetBindingKey(self.bindingName)
	if key then
		self.hotkey:SetText(abbreviateKey(key))
		self.hotkey:Show()
	else
		self.hotkey:Hide()
	end
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

function ActionButtonMixin:UpdateCooldown()
	CooldownFrame_SetTimer(self.cooldown, GetActionCooldown(self.action))
end

function ActionButtonMixin:Update()
	local action = self.action

	if HasAction(action) then
		for event, method in pairs(ACTION_EVENTS) do
			self:RegisterEvent(event, method)
		end
		self:SetScript("OnUpdate", self.OnUpdate)

		self.usable, self.notEnoughMana = IsUsableAction(action)
		self.equipped = IsEquippedAction(action)
		self.checked = IsCurrentAction(action) or IsAutoRepeatAction(action)
		self.outOfRange = IsActionInRange(action) == 0
		self.rangeTimer = 0
		self.hasAction = true
	elseif self.hasAction then
		for event, method in pairs(ACTION_EVENTS) do
			self:UnregisterEvent(event, method)
		end
		self:SetScript("OnUpdate", nil)

		self.usable = true
		self.notEnoughMana, self.equipped, self.checked, self.outOfRange = nil, nil, nil, nil
		self.hasAction = false
	end

	self:UpdateColors()
	self:UpdateBindings()
	self:UpdateIcon()
	self:UpdateCooldown()
	self:UpdateName()
end

function ActionButtonMixin:OnUpdate(elapsed)
	self.rangeTimer = self.rangeTimer - elapsed
	if self.rangeTimer > 0 then
		return
	end
	self.rangeTimer = RANGE_CHECK_INTERVAL

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
	if IsAltKeyDown() and not InCombatLockdown() then
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

	self:StyleButton(button, self.BUTTON_SIZE)

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	CooldownTimer:Attach(button.cooldown)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()

	button.hotkey = button:CreateFontString(nil, "ARTWORK")
	button.hotkey:SetFont(Media.font, 9, "OUTLINE")
	button.hotkey:SetPoint("TOPRIGHT")
	button.hotkey:SetJustifyH("LEFT")
	button.hotkey:SetJustifyV("BOTTOM")

	button.name = button:CreateFontString(nil, "ARTWORK")
	button.name:SetFont(Media.font, 9, "OUTLINE")
	button.name:SetPoint("BOTTOM", 0, 2)

	button:RegisterForClicks("LeftButtonDown")
	button:RegisterForDrag("RightButton")
	button:SetScript("OnDragStart", button.OnDragStart)
	button:SetScript("OnReceiveDrag", button.OnReceiveDrag)
	button:SetScript("OnAttributeChanged", button.OnAttributeChanged)
	button:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	button:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	self:AttachTooltip(button, button.SetTooltip)

	button.usable = true
	button:Update()

	return button
end
