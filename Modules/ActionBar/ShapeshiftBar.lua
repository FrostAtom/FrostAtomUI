local namespace = select(2,...)

local select,_G = select,_G
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local GetSpellInfo = GetSpellInfo


local ActionBar = namespace:Get("ActionBar")
local TEXTURE = namespace:GetMedia("textureNormal")
local CooldownTimer = namespace:Get("CooldownTimer")
local buttons = {}

local NUM_SHAPESHIFT_SLOTS = NUM_SHAPESHIFT_SLOTS
local OFFSET = 2
local SIZE = 30
local TOTALSIZE = SIZE+OFFSET


function ActionBar:ShapeshiftVisibility()
	local button
	local numForms = GetNumShapeshiftForms()
	for i = 1,NUM_SHAPESHIFT_SLOTS do
		button = buttons[i]

		if i <= numForms then
			if not button:IsShown() then
				if InCombatLockdown() then
					self:RegisterEvent("PLAYER_REGED_ENABLED","ShapeshiftVisibility")
					return
				else
					button:Show()
				end
			end
		else
			if button:IsShown() then
				if InCombatLockdown() then
					self:RegisterEvent("PLAYER_REGED_ENABLED","ShapeshiftVisibility")
					return
				else
					button:Hide()
				end
			end
		end
	end
	self:UpdateShapeshift()
end

function ActionBar:UpdateShapeshift()
	local button,texture,name,isActive,isCastable
	local numForms = GetNumShapeshiftForms()
	local curForm = GetShapeshiftForm()
	for i = 1,numForms do
		button = buttons[i]
        
        if i <= numForms then
			texture,name,isActive,isCastable = GetShapeshiftFormInfo(i)

			if texture then
				if texture == "Interface\\Icons\\Spell_Nature_WispSplode" then
					texture = select(3,GetSpellInfo(name))
				end
				button.icon:SetTexture(texture)
				button.cooldown:Show()
			else
				button.icon:SetTexture(nil)
				button.cooldown:Hide()
			end

			CooldownFrame_SetTimer(button.cooldown,GetShapeshiftFormCooldown(i))

			if isCastable and (isActive or curForm == 0) then
				button.icon:SetVertexColor(1,1,1)
				if curForm == i then
					button:GetNormalTexture():SetVertexColor(1,0.8,0)
				else
					button:GetNormalTexture():SetVertexColor(1,1,1)
				end
			else
				button.icon:SetVertexColor(0.4,0.4,0.4)
				button:GetNormalTexture():SetVertexColor(0.4,0.4,0.4)
			end
		end
	end
end

function ActionBar:UpdateShapeshiftCooldown()
    for i = 1,GetNumShapeshiftForms() do
        CooldownFrame_SetTimer(buttons[i].cooldown,GetShapeshiftFormCooldown(i))
    end
end


function ActionBar:SetupShapeshiftButton(button)
	local name = button:GetName()
	button:SetSize(SIZE,SIZE)

	local cooldownName = name.."Cooldown"
	button.cooldown,_G[cooldownName] = _G[cooldownName]
	CooldownTimer:Create(button.cooldown)

	local iconName = name.."Icon"
	button.icon,_G[iconName] = _G[iconName]

	local hotKeyName = name.."HotKey"
	button.hotkey,_G[hotKeyName] = _G[hotKeyName]

	local ntex = button:GetNormalTexture()
	ntex:SetTexture(TEXTURE)
	ntex:SetAllPoints()

	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	button:SetCheckedTexture(nil)
	button:SetPushedTexture(nil)

	button:SetScript("OnEnter",nil)
	button:SetScript("OnLeave",nil)
	button:HookScript("OnClick",self.PlayAnimation)
	button:SetScript("PreClick",PreClick)
	button:SetScript("PostClick",PostClick)

	_G[name],_G[name.."Count"] = nil
	_G[name.."NormalTexture"] = ActionButton1NormalTexture

	buttons[button:GetID()] = button
	return button
end

function ActionBar:InitializeShapeshiftBar(parent)
	local button
	for i = 1,NUM_SHAPESHIFT_SLOTS do
		button = self:SetupShapeshiftButton(_G["ShapeshiftButton"..i])
		button:SetParent(parent)
		button:ClearAllPoints()
		button:SetPoint("BOTTOM",(i-1)*TOTALSIZE,0)
	end

	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN","UpdateShapeshiftCooldown")
    self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE","UpdateShapeshift")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS","ShapeshiftVisibility")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM","UpdateShapeshift")
    self:UpdateShapeshift()

	namespace.destroyObject(ShapeshiftBarFrame)
	UIPARENT_MANAGED_FRAME_POSITIONS["ShapeshiftBarFrame"] = nil
end