local _, ns = ...

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local GetSpellInfo = GetSpellInfo
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local GameTooltip = GameTooltip
local NUM_SHAPESHIFT_SLOTS = NUM_SHAPESHIFT_SLOTS

local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

local config = ns.Config.actionBar
local PLACEHOLDER_TEXTURE = "Interface\\Icons\\Spell_Nature_WispSplode"

local buttons = ActionBar.shapeshiftButtons
local updateHotkey = ActionBar.UpdateHotkey

local function setTooltip(button)
	local id = button:GetID()
	if id <= GetNumShapeshiftForms() then
		GameTooltip:SetShapeshift(id)
	else
		GameTooltip:Hide()
	end
end

function ActionBar:StyleShapeshiftHotkey(hotkey)
	self:StyleHotkey(hotkey)
	if not config.showShapeshiftHotkeys then
		hotkey:SetAlpha(0)
	end
end

function ActionBar:UpdateShapeshiftHotkeys()
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		updateHotkey(buttons[i])
	end
end

function ActionBar:UpdateShapeshiftBar()
	local currentForm = GetShapeshiftForm()

	for i = 1, GetNumShapeshiftForms() do
		local button = buttons[i]
		local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)

		if texture then
			if texture == PLACEHOLDER_TEXTURE then
				texture = select(3, GetSpellInfo(name))
			end
			button.icon:SetTexture(texture)
			button.cooldown:Show()
		else
			button.icon:SetTexture(nil)
			button.cooldown:Hide()
		end

		CooldownFrame_SetTimer(button.cooldown, GetShapeshiftFormCooldown(i))

		self:SetButtonChecked(button, currentForm == i)
		if isCastable and (isActive or currentForm == 0) then
			self:SetButtonColors(button, 1)
		else
			self:SetButtonColors(button, 0.4)
		end
	end
end

function ActionBar:UpdateShapeshiftCooldowns()
	for i = 1, GetNumShapeshiftForms() do
		CooldownFrame_SetTimer(buttons[i].cooldown, GetShapeshiftFormCooldown(i))
	end
end

function ActionBar:UpdateShapeshiftVisibility()
	local numForms = GetNumShapeshiftForms()
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		local button = buttons[i]
		local shouldShow = i <= numForms
		if shouldShow ~= (button:IsShown() and true or false) then
			if InCombatLockdown() then
				self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateShapeshiftVisibility")
				return
			end
			if shouldShow then
				button:Show()
			else
				button:Hide()
			end
		end
	end

	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateShapeshiftVisibility")
	self:UpdateShapeshiftBar()
end

function ActionBar:SetupShapeshiftButton(button)
	local name = button:GetName()

	self:StyleButton(button)
	button:SetCheckedTexture(nil)
	button:SetPushedTexture(nil)

	button.icon = _G[name .. "Icon"]
	button.cooldown = _G[name .. "Cooldown"]
	CooldownTimer:Attach(button.cooldown)
	self:AttachTooltip(button, setTooltip)

	_G[name .. "Count"]:Hide()

	button.bindingName = "CLICK " .. name .. ":LeftButton"
	button.blizzardBinding = "SHAPESHIFTBUTTON" .. button:GetID()
	button.hotkey = _G[name .. "HotKey"]
	button.hotkey:ClearAllPoints()
	button.hotkey:SetPoint("TOPRIGHT")
	button.hotkey:SetJustifyH("LEFT")
	button.hotkey:SetJustifyV("BOTTOM")
	self:StyleShapeshiftHotkey(button.hotkey)
	updateHotkey(button)

	buttons[button:GetID()] = button
	return button
end

function ActionBar:InitializeShapeshiftBar(parent)
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		self:SetupShapeshiftButton(_G["ShapeshiftButton" .. i]):SetParent(parent)
	end

	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", "UpdateShapeshiftCooldowns")
	self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "UpdateShapeshiftVisibility")
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "UpdateShapeshiftVisibility")
	self:RegisterEvent("CHARACTER_POINTS_CHANGED", "UpdateShapeshiftVisibility")
	self:RegisterEvent("SPELL_UPDATE_USABLE", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateShapeshiftHotkeys")
	self:UpdateShapeshiftBar()
	RegisterStateDriver(parent, "visibility", "[vehicleui][bonusbar:5] hide; show")

	ns.DestroyFrame(ShapeshiftBarFrame)
	UIPARENT_MANAGED_FRAME_POSITIONS.ShapeshiftBarFrame = nil
end
