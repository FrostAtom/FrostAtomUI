local namespace = select(2,...)
local TE = namespace:New("TemporaryEnchant")

local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local CancelItemTempEnchantment = CancelItemTempEnchantment
local GameTooltip = GameTooltip
local select = select
local math = math


local frames = setmetatable({},{
	__index = function(self,i)
		local frame = TE:CreateFrame()
		frame:SetPoint("TOPLEFT",Minimap,"BOTTOMLEFT",(i-1)*32,-4)
		frame:SetID(i)
		self[i] = frame
		return frame
	end
})

local function OnClick(self)
	CancelItemTempEnchantment(self.id)
end

local function OnUpdate(self)
	GameTooltip:SetInventoryItem("player",15+self.id)
end

local function OnEnter(self)
	GameTooltip:SetOwner(self,"ANCHOR_BOTTOMLEFT")

	OnUpdate(self)
	self:SetScript("OnUpdate",OnUpdate)
end

local function OnLeave(self)
	GameTooltip:Hide()
	self:SetScript("OnUpdate",nil)
end

function TE:CreateFrame()
	local frame = CreateFrame("Button",nil,UIParent)
	frame:RegisterForClicks("RightButtonDown")
	frame:SetScript("OnClick",OnClick)
	frame:SetScript("OnEnter",OnEnter)
	frame:SetScript("OnLeave",OnLeave)
	frame:SetSize(30,30)

	local texture = frame:CreateTexture(nil,"BORDER")
	texture:SetAllPoints()

	--[[local cd = CreateFrame("Cooldown",nil,frame)
	cd:SetReverse(true)
	cd:SetDrawEdge(true)
	cd:SetAllPoints()]]

	frame.texture = texture
	--frame.cd = cd

	return frame
end

local function inner(...)
	local visible,frame = 0
	local has,remain,_
	for i = 1,select("#",...),3 do
		has,remain,_ = select(i,...)

		if has then
			visible = visible + 1

			frame = frames[visible]
			frame.id = math.ceil(i/3)
			frame.texture:SetTexture(GetInventoryItemTexture("player",15+frame.id))
			--frame.cd:SetCooldown(GetTime()-(3600-remain/1e3),3600)
			frame:Show()
		end
	end

	for i = visible+1,#frames do
		frames[i]:Hide()
	end
end

function TE:Update()
	inner(GetWeaponEnchantInfo())
end

function TE:UNIT_INVENTORY_CHANGED(unit)
	if unit ~= "player" then
		return
	end

	self:Update()
end

function TE:Initialize()
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD","Update")
end