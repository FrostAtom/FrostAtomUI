local _, ns = ...

-- Re-uses Blizzard's ShapeshiftButton1..N (they cast forms securely) and only
-- restyles/repositions them. Their original bar frame is destroyed.

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local GetSpellInfo = GetSpellInfo
local InCombatLockdown = InCombatLockdown
local NUM_SHAPESHIFT_SLOTS = NUM_SHAPESHIFT_SLOTS

local ActionBar = ns:GetModule("ActionBar")
local CooldownTimer = ns:GetModule("CooldownTimer")

-- Some forms report this placeholder icon; the spell's own icon is used instead.
local PLACEHOLDER_TEXTURE = "Interface\\Icons\\Spell_Nature_WispSplode"

local buttons = {}

local function setButtonColors(button, iconShade, borderR, borderG, borderB)
	button.icon:SetVertexColor(iconShade, iconShade, iconShade)
	button:GetNormalTexture():SetVertexColor(borderR, borderG, borderB)
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

		if isCastable and (isActive or currentForm == 0) then
			if currentForm == i then
				setButtonColors(button, 1, 1, 0.8, 0)
			else
				setButtonColors(button, 1, 1, 1, 1)
			end
		else
			setButtonColors(button, 0.4, 0.4, 0.4, 0.4)
		end
	end
end

function ActionBar:UpdateShapeshiftCooldowns()
	for i = 1, GetNumShapeshiftForms() do
		CooldownFrame_SetTimer(buttons[i].cooldown, GetShapeshiftFormCooldown(i))
	end
end

-- Shows a button per known form. Deferred until after combat if needed.
function ActionBar:UpdateShapeshiftVisibility()
	local numForms = GetNumShapeshiftForms()
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		local button = buttons[i]
		local shouldShow = i <= numForms
		local isShown = button:IsShown() and true or false -- 3.3.5 returns 1/nil

		if shouldShow ~= isShown then
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

	self:StyleButton(button, self.SMALL_BUTTON_SIZE)
	button:SetCheckedTexture(nil)
	button:SetPushedTexture(nil)
	button:SetScript("OnEnter", nil)
	button:SetScript("OnLeave", nil)

	button.icon = _G[name .. "Icon"]
	button.cooldown = _G[name .. "Cooldown"]
	CooldownTimer:Attach(button.cooldown)

	_G[name .. "HotKey"]:Hide()
	_G[name .. "Count"]:Hide()

	buttons[button:GetID()] = button
	return button
end

function ActionBar:InitializeShapeshiftBar(parent)
	self.shapeshiftBar = parent

	local slot = self.SMALL_BUTTON_SIZE + self.BUTTON_GAP
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		local button = self:SetupShapeshiftButton(_G["ShapeshiftButton" .. i])
		button:SetParent(parent)
		button:ClearAllPoints()
		button:SetPoint("BOTTOM", (i - 1) * slot, 0)
	end

	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", "UpdateShapeshiftCooldowns")
	self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "UpdateShapeshiftVisibility")
	self:UpdateShapeshiftBar()

	ns.DestroyFrame(ShapeshiftBarFrame)
	UIPARENT_MANAGED_FRAME_POSITIONS.ShapeshiftBarFrame = nil
end
