local ADDON_NAME, ns = ...

local CreateFrame = CreateFrame
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetPetActionCooldown = GetPetActionCooldown
local GetPetActionInfo = GetPetActionInfo
local GetPetActionSlotUsable = GetPetActionSlotUsable
local RegisterStateDriver = RegisterStateDriver
local GetBindingKey = GetBindingKey
local GameTooltip = GameTooltip
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS

local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

local BUTTON_NAME = ADDON_NAME .. "PetButton%d"
local buttons = {}

local tokenTextures = setmetatable({}, {
	__index = function(self, token)
		local path = _G[token]
		self[token] = path or false
		return path
	end,
})

local function setTooltip(button)
	if GetPetActionInfo(button:GetID()) then
		GameTooltip:SetPetAction(button:GetID())
	else
		GameTooltip:Hide()
	end
end

local function updateHotkey(button)
	local key = GetBindingKey("BONUSACTIONBUTTON" .. button:GetID())
	if key then
		button.hotkey:SetText(ActionBar.AbbreviateKey(key))
		button.hotkey:Show()
	else
		button.hotkey:Hide()
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
		local _, _, texture, isToken, isActive = GetPetActionInfo(i)

		if texture then
			if isToken then
				texture = tokenTextures[texture]
			end
			button.icon:SetTexture(texture)
			button.icon:SetDesaturated(not GetPetActionSlotUsable(i))

			if isToken then
				if isActive then
					self:SetButtonColors(button, 1, 1, 0.8, 0)
				else
					self:SetButtonColors(button, 0.4, 0.4, 0.4, 0.4)
				end
			else
				self:SetButtonColors(button, 1, 1, 1, 1)
			end
		else
			button.icon:SetTexture(ns.Media.emptySlot)
			button.icon:SetDesaturated(nil)
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
	local button = CreateFrame("Button", BUTTON_NAME:format(index), parent, "SecureActionButtonTemplate")
	button:SetAttribute("checkselfcast", true)
	button:SetAttribute("type", "pet")
	button:SetAttribute("action", index)

	self:StyleButton(button, self.SMALL_BUTTON_SIZE)

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetPoint("TOPRIGHT", -2, -2)
	button.cooldown:SetPoint("BOTTOMLEFT", 2, 2)
	CooldownTimer:Attach(button.cooldown)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()

	button.hotkey = button:CreateFontString(nil, "ARTWORK")
	button.hotkey:SetFont(ns.Media.font, 9, "OUTLINE")
	button.hotkey:SetPoint("TOPRIGHT")

	button:RegisterForClicks("LeftButtonDown")
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

function ActionBar:InitializePetBar(parent)
	self.petBar = parent

	local slot = self.SMALL_BUTTON_SIZE + self.BUTTON_GAP
	for i = 1, NUM_PET_ACTION_SLOTS do
		self:CreatePetButton(i, parent):SetPoint("BOTTOM", (i - 1) * slot, 0)
	end

	RegisterStateDriver(parent, "visibility", "[vehicleui] hide; [@pet,exists] show; hide")
	parent:SetScript("OnShow", function()
		self:UpdatePetBar()
	end)

	self:RegisterEvent("UNIT_FLAGS", onPetUnitEvent)
	self:RegisterEvent("UNIT_AURA", onPetUnitEvent)
	self:RegisterEvent("UNIT_PET", onPlayerUnitEvent)
	self:RegisterEvent("PET_BAR_UPDATE", "UpdatePetBar")
	self:RegisterEvent("PET_BAR_UPDATE_USABLE", "UpdatePetBar")
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", "UpdatePetCooldowns")
	self:RegisterEvent("PLAYER_CONTROL_LOST", "UpdatePetBar")
	self:RegisterEvent("PLAYER_CONTROL_GAINED", "UpdatePetBar")
	self:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED", "UpdatePetBar")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdatePetHotkeys")
end
