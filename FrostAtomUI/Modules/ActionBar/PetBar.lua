local ADDON_NAME, ns = ...

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetPetActionCooldown = GetPetActionCooldown
local GetPetActionInfo = GetPetActionInfo
local GetPetActionSlotUsable = GetPetActionSlotUsable
local PickupPetAction = PickupPetAction
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local AutoCastShine_AutoCastStart = AutoCastShine_AutoCastStart
local AutoCastShine_AutoCastStop = AutoCastShine_AutoCastStop
local GameTooltip = GameTooltip
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS

local Media = ns.Media
local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

local config = ns.Config.actionBar
local BUTTON_NAME = ADDON_NAME .. "PetButton%d"
local AUTOCAST_TEXTURE = "Interface\\Buttons\\UI-AutoCastableOverlay"
local buttons = ActionBar.petButtons
local updateHotkey = ActionBar.UpdateHotkey

local DRAG_MODIFIERS = {
	shift = IsShiftKeyDown,
	ctrl = IsControlKeyDown,
	alt = IsAltKeyDown,
}

local tokenTextures = setmetatable({}, {
	__index = function(self, token)
		local path = _G[token]
		self[token] = path or false
		return path
	end,
})

local function setTooltip(button)
	local id = button:GetID()
	if GetPetActionInfo(id) then
		GameTooltip:SetPetAction(id)
	else
		GameTooltip:Hide()
	end
end

local function onDragStart(button)
	local modifier = DRAG_MODIFIERS[config.dragModifier]
	if (not modifier or modifier()) and not InCombatLockdown() then
		PickupPetAction(button:GetID())
	end
end

local function onReceiveDrag(button)
	if not InCombatLockdown() then
		PickupPetAction(button:GetID())
	end
end

local function setAutoCast(button, allowed, enabled)
	if allowed then
		button.autoCastable:Show()
	else
		button.autoCastable:Hide()
	end
	enabled = enabled and true or false
	if enabled ~= button.autoCasting then
		button.autoCasting = enabled
		if enabled then
			AutoCastShine_AutoCastStart(button.shine)
		else
			AutoCastShine_AutoCastStop(button.shine)
		end
	end
end

function ActionBar:UpdatePetHotkeys()
	for i = 1, NUM_PET_ACTION_SLOTS do
		updateHotkey(buttons[i])
	end
end

function ActionBar:UpdatePetBar()
	if not self.petBar:IsShown() then
		return
	end

	for i = 1, NUM_PET_ACTION_SLOTS do
		local button = buttons[i]
		local _, _, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)

		if texture then
			if isToken then
				texture = tokenTextures[texture]
			end
			button.icon:SetTexture(texture)
			button.icon:SetDesaturated(not GetPetActionSlotUsable(i))

			self:SetButtonChecked(button, isActive)
			if isToken and not isActive then
				self:SetButtonColors(button, 0.4)
			else
				self:SetButtonColors(button, 1)
			end
			setAutoCast(button, autoCastAllowed, autoCastEnabled)
		else
			button.icon:SetTexture(Media.emptySlot)
			button.icon:SetDesaturated(nil)
			self:SetButtonChecked(button, false)
			setAutoCast(button, false, false)
		end
	end

	self:UpdatePetCooldowns()
end

function ActionBar:UpdatePetCooldowns()
	for i = 1, NUM_PET_ACTION_SLOTS do
		CooldownFrame_SetTimer(buttons[i].cooldown, GetPetActionCooldown(i))
	end
end

function ActionBar:CreatePetButton(index, parent)
	local name = BUTTON_NAME:format(index)
	local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
	button:SetID(index)
	button:SetAttribute("checkselfcast", true)
	button:SetAttribute("type", "pet")
	button:SetAttribute("action", index)
	button:SetAttribute("type2", "click")
	button:SetAttribute("clickbutton2", _G["PetActionButton" .. index])
	button.bindingName = "CLICK " .. name .. ":LeftButton"
	button.blizzardBinding = "BONUSACTIONBUTTON" .. index

	self:StyleButton(button)

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetPoint("TOPRIGHT", -2, -2)
	button.cooldown:SetPoint("BOTTOMLEFT", 2, 2)
	CooldownTimer:Attach(button.cooldown)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()

	button.autoCastable = button:CreateTexture(nil, "OVERLAY")
	button.autoCastable:SetTexture(AUTOCAST_TEXTURE)
	button.autoCastable:SetPoint("CENTER")
	button.autoCastable:Hide()

	button.shine = CreateFrame("Frame", name .. "Shine", button, "AutoCastShineTemplate")
	button.shine:SetPoint("TOPLEFT", 1, -1)
	button.shine:SetPoint("BOTTOMRIGHT", -1, 1)
	button.autoCasting = false

	button.hotkey = button:CreateFontString(nil, "ARTWORK")
	button.hotkey:SetPoint("TOPRIGHT")
	self:StyleHotkey(button.hotkey)

	button:RegisterForClicks("LeftButtonDown", "RightButtonUp")
	button:RegisterForDrag(config.dragButton)
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnReceiveDrag", onReceiveDrag)
	self:AttachTooltip(button, setTooltip)
	updateHotkey(button)

	buttons[index] = button
	return button
end

local function onPetUnitEvent(self, unit)
	if unit == "pet" then
		self:UpdatePetBar()
	end
end

local function onPlayerUnitEvent(self, unit)
	if unit == "player" then
		self:UpdatePetBar()
	end
end

function ActionBar:StylePetButtons()
	for i = 1, #buttons do
		local button = buttons[i]
		self:StyleHotkey(button.hotkey)
		button:RegisterForDrag(config.dragButton)
	end
end

function ActionBar:InitializePetBar(parent)
	self.petBar = parent

	for i = 1, NUM_PET_ACTION_SLOTS do
		self:CreatePetButton(i, parent)
	end

	RegisterStateDriver(parent, "visibility", "[vehicleui] hide; [@pet,exists] show; hide")
	parent:SetScript("OnShow", function()
		self:UpdatePetBar()
	end)

	self:RegisterEvent("UNIT_FLAGS", onPetUnitEvent)
	self:RegisterEvent("UNIT_AURA", onPetUnitEvent)
	self:RegisterEvent("UNIT_PET", onPlayerUnitEvent)
	for _, event in ipairs({
		"PET_BAR_UPDATE",
		"PET_BAR_UPDATE_USABLE",
		"PLAYER_CONTROL_LOST",
		"PLAYER_CONTROL_GAINED",
		"PLAYER_FARSIGHT_FOCUS_CHANGED",
	}) do
		self:RegisterEvent(event, "UpdatePetBar")
	end
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", "UpdatePetCooldowns")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdatePetHotkeys")
end
