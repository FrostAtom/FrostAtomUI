local AddOnName,namespace = ...

local CreateFrame = CreateFrame
local GetPetActionCooldown = GetPetActionCooldown
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local SetDesaturation = SetDesaturation
local GetPetActionSlotUsable = GetPetActionSlotUsable
local GetPetActionInfo = GetPetActionInfo

local ActionBar = namespace:Get("ActionBar")
local CooldownTimer = namespace:Get("CooldownTimer")
local buttons = {}

local TEXTURE = namespace:GetMedia("textureNormal")
local NAME = AddOnName.."PetButton"
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS
local OFFSET = 2
local SIZE = 30
local TOTALSIZE = SIZE+OFFSET
local TOKENS = setmetatable({},{
	__index = function(self,key)
		local value = _G[key]
		self[key] = value or false
		return value
	end
})


function ActionBar:UpdatePet()
	if not self.barPet:IsShown() then return end

	local texture,isToken,isActive,autoCastAllowed,autoCastEnabled,_
	local button
	for i = 1,NUM_PET_ACTION_SLOTS do
		button = buttons[i]

		_,_,texture,isToken,isActive,autoCastAllowed,autoCastEnabled = GetPetActionInfo(i)
		if texture then
			if isToken then
				texture = TOKENS[texture]
			end

			button.icon:SetTexture(texture)
			button.icon:SetDesaturated(not GetPetActionSlotUsable(i))

			if isToken then
				if isActive then
					button.icon:SetVertexColor(1,1,1)
					button:GetNormalTexture():SetVertexColor(1,0.8,0)
				else
					button.icon:SetVertexColor(0.4,0.4,0.4)
					button:GetNormalTexture():SetVertexColor(0.4,0.4,0.4)
				end
			--[[else
				if autoCastAllowed and autoCastEnabled then
					button.icon:SetVertexColor(1,1,1)
					button:GetNormalTexture():SetVertexColor(1,0.8,0)
				else
					button.icon:SetVertexColor(0.4,0.4,0.4)
					button:GetNormalTexture():SetVertexColor(0.4,0.4,0.4)
				end]]
			end
		else
			button.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
			button.icon:SetDesaturated(nil)
		end
	end

	self:UpdatePetCooldown()
end

function ActionBar:UpdatePetCooldown()
	for i = 1,NUM_PET_ACTION_SLOTS do
		CooldownFrame_SetTimer(buttons[i].cooldown,GetPetActionCooldown(i))
	end
end

function ActionBar:CreatePetButton(action,parent)
	local button = CreateFrame("Button",NAME..action,parent,"SecureActionButtonTemplate")
	button:SetSize(SIZE,SIZE)
	button:SetAttribute("checkselfcast",true)
	button:SetAttribute("type","pet")
	button:SetAttribute("action",action)

	button:SetNormalTexture(TEXTURE)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

	button.cooldown = CreateFrame("Cooldown",nil,button)
	button.cooldown:SetPoint("TOPRIGHT",-2,-2)
	button.cooldown:SetPoint("BOTTOMLEFT",2,2)
	CooldownTimer:Create(button.cooldown)

	button.icon = button:CreateTexture(nil,"BORDER")
	button.icon:SetAllPoints()

	button:RegisterForClicks("LeftButtonDown")
	button:HookScript("OnClick",self.PlayAnimation)

	buttons[action] = button
	return button
end

function ActionBar:InitializePetBar(parent)
	RegisterStateDriver(parent,"visibility","[vehicleui] hide; [@pet,exists] show; hide")
	parent:SetScript("OnShow",function() self:UpdatePet() end)

	for i = 1,NUM_PET_ACTION_SLOTS do
		self:CreatePetButton(i,parent):SetPoint("BOTTOM",(i-1)*TOTALSIZE,0)
	end

	local unitIsPetCheck = function(self,unit) if unit == "pet" then self:UpdatePet() end end
	self:RegisterEvent("UNIT_FLAGS",unitIsPetCheck)
	self:RegisterEvent("UNIT_AURA",unitIsPetCheck)
	self:RegisterEvent("UNIT_PET",function(self,unit) if unit == "player" then self:UpdatePet() end end)
	self:RegisterEvent("PET_BAR_UPDATE","UpdatePet")
	self:RegisterEvent("PLAYER_CONTROL_LOST","UpdatePet")
	self:RegisterEvent("PLAYER_CONTROL_GAINED","UpdatePet")
	self:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED","UpdatePet")
	self:RegisterEvent("PET_BAR_UPDATE_USABLE","UpdatePet")
	self:RegisterEvent("PLAYER_CONTROL_LOST","UpdatePet")
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN","UpdatePetCooldown")

end