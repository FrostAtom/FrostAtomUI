local namespace = select(2,...)

local CreateFrame = CreateFrame
local RegisterStateDriver = RegisterStateDriver


local ActionBar = namespace:New("ActionBar")

local OFFSET = 2
local SIZE = 36
local TOTALSIZE = SIZE+OFFSET


function ActionBar:CreateBar(page,calculatePointFunc,postCreateFunc)
	local frame = CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate")
	local FIRSTACTION = (page-1)*12

	local action,button
	for i = 1,12 do
		action = FIRSTACTION+i
		button = self:CreateButton(action,frame)
		button:SetSize(SIZE,SIZE)
		if calculatePointFunc then
			button:SetPoint("BOTTOM",calculatePointFunc(i))
		end
		if postCreateFunc then
			postCreateFunc(button,i)
		end
	end

	return frame
end

function ActionBar:Initialize()
	local function initMainBarButton(self,id)
		self:SetAttribute("id",id)
		self:SetAttribute("_childupdate-page",[[
			self:SetAttribute("action",(message-1)*12+self:GetAttribute("id"))
		]])
	end

	local function row(i)
		return TOTALSIZE/2+(-7+i)*TOTALSIZE,0
	end

	local function square(i)
		local row = floor((i-1)/4)
		return TOTALSIZE/2+(-2+i%4)*TOTALSIZE,row*TOTALSIZE
	end

	local bar1 = self:CreateBar(1,row,initMainBarButton)
	bar1:SetPoint("BOTTOM",0,2)
	bar1:SetAttribute("_onstate-page",[[ control:ChildUpdate("page", newstate) ]])

	local playerClass = select(2,UnitClass("player"))
	local classRule 
	if playerClass == "WARRIOR" then
		classRule = "[stance:1] 7; [stance:2] 8; [stance:3] 9;"
	end
	RegisterStateDriver(bar1,"page",("[vehicleui] 11; %s 1"):format(classRule or ""))
	self.bar1 = bar1

	local bar2 = self:CreateBar(2,row)
	bar2:SetPoint("BOTTOM",bar1,0,TOTALSIZE)
	self.bar2 = bar2

	local bar3 = self:CreateBar(3,row)
	bar3:SetPoint("BOTTOM",bar2,0,TOTALSIZE)
	self.bar3 = bar3

	local barLeft = self:CreateBar(4,square)
	barLeft:SetPoint("BOTTOM",bar1,-TOTALSIZE*8-12,0)
	self.bar4 = barLeft

	local barRight = self:CreateBar(5,square)
	barRight:SetPoint("BOTTOM",bar1,TOTALSIZE*8+12,0)
	self.bar5 = barRight

	local barShapeshift = CreateFrame("frame",nil,UIParent)
	barShapeshift:SetSize(2,2)
	barShapeshift:SetPoint("BOTTOM",bar3,-TOTALSIZE*5,TOTALSIZE)
	self:InitializeShapeshiftBar(barShapeshift)
	self.barShapeshift = barShapeshift

	local barPet = CreateFrame("frame",nil,UIParent)
	barPet:SetSize(2,2)
	barPet:SetPoint("BOTTOM",bar3,-TOTALSIZE*2,TOTALSIZE)
	self:InitializePetBar(barPet)
	self.barPet = barPet
end


--[[local f = UIParent:CreateTexture(nil,"OVERLAY")
f:SetTexture("Interface\\Buttons\\WHITE8x8")
f:SetWidth(2)
f:SetVertexColor(0,0,0)
f:SetPoint("TOP")
f:SetPoint("BOTTOM")]]