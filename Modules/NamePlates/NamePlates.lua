local namespace = select(2,...)
if true then return end

namespace:Get("CVars"):SetCVar("showVKeyCastbar","0","SHOW_TARGET_CASTBAR_IN_V_KEY")

local pixelPerfect = namespace.pixelPerfect


local fireEvent
do
	local pcall = pcall
	local SetEvent = namespace.SetEvent
	fireEvent = function(...)
		local retOK,err = pcall(SetEvent,nil,...)
		if not retOK then
			geterrorhandler()(err)
		end
	end
end

local function HealthBar_UpdateColors(self,r,g,b)
	if g + b == 0 then -- red
		r,g,b = 0.69,0.31,0.31
	elseif r + b == 0 then -- green
		r,g,b = 0.33,0.59,0.33
	elseif r + g == 0 then -- blue
		r,g,b = 0.31,0.45,0.63
	elseif r + g > 1.99 and b == 0 then -- yellow
		r,g,b = 0.65,0.63,0.35
	end

	self:SetStatusBarColor(r,g,b)
	self.bg:SetTexture(r*0.3,g*0.3,b*0.3)

	self.r,self.g,self.b = r,g,b
end

local function HealthBar_OnUpdate(self)
	local r,g,b = self:GetStatusBarColor()
	if r ~= self.r or g ~= self.g or b ~= self.b then
		HealthBar_UpdateColors(self,r,g,b)
	end

	--[[local plate = self:GetParent()
	if plate:GetAlpha() < 1 then
		plate:SetAlpha(66/100)
	end]]
end

local function NamePlate_OnShow(self)
	local healthbar = self.healthbar
	healthbar:ClearAllPoints()
	healthbar:SetSize(120,6)
	healthbar:SetPoint("TOP",0,-4)
	HealthBar_UpdateColors(healthbar,healthbar:GetStatusBarColor())

	local name = self.origName:GetText()
	self.newName:SetText(name)

	self.highlight:SetAllPoints(healthbar)
	self.level:Hide()

	fireEvent("NamePlate_OnShow",self,name)
end

local function NamePlate_OnHide(self)
	self.highlight:Hide()
	fireEvent("NamePlate_OnHide",self,self.newName:GetText())
end

local BACKDROP = namespace:GetMedia("BACKDROP")

local function InitNamePlate(self)
	local healthbar = self:GetChildren()
	local threat,hpborder,cbshield,cbborder,cbicon,highlight,name,level,bossicon,raidicon,elite = self:GetRegions()
	healthbar:SetFrameLevel(self:GetFrameLevel())

	healthbar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

	local bg = CreateFrame("frame",nil,healthbar)
	bg:SetFrameLevel(healthbar:GetFrameLevel()-1)
	bg:SetPoint("TOPRIGHT",2,2)
	bg:SetPoint("BOTTOMLEFT",-2,-2)
	bg:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		
		bgFile = "Interface\\Buttons\\WHITE8x8",
		insets = {
			top = pixelPerfect(1),
			bottom = pixelPerfect(1),
			left = pixelPerfect(1),
			right = pixelPerfect(1),
		}
	})
	bg:SetBackdropColor(0.137,0.137,0.137)
	bg:SetBackdropBorderColor(0.2,0.2,0.2)

	self.healthbar = healthbar

	hpborder:SetTexture(0.3,0.3,0.3)
	hpborder:SetDrawLayer("BACKGROUND")
	hpborder:SetAllPoints(healthbar)
	healthbar.bg = hpborder

	healthbar:SetScript("OnUpdate",HealthBar_OnUpdate)


	threat:SetTexture(nil)
	bossicon:SetTexture(nil)
	elite:SetTexture(nil)
	name:Hide()


	local newName = self:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
	newName:SetPoint("BOTTOM",healthbar,"TOP")
	newName:SetTextColor(1,0.9,0.8)
	self.origName,self.newName = name,newName

	highlight:SetTexture(1,1,1,0.4)
	self.highlight = highlight

	self.level = level
	self.raidicon = raidicon


	self:SetScript("OnShow",NamePlate_OnShow)
	self:SetScript("OnHide",NamePlate_OnHide)

	fireEvent("NamePlate_OnInit",self)

	NamePlate_OnShow(self)
end

local InitChatBubble
do
	local function ChatBubble_OnShow(self)
		self.bg:SetSize(math.min(self.text:GetStringWidth(),310)+8,self.text:GetStringHeight()+8)
	end

	local function inner(first,obj,next,...)
		if not next then
			return first,obj
		end 
		obj:SetTexture(nil)
		obj:Hide()
		return inner(first,next,...)
	end

	InitChatBubble = function(self)
		local bg,text = inner(self:GetRegions())
		bg:SetTexture(0,0,0,0.5)
		bg:ClearAllPoints()
		bg:SetPoint("CENTER")
		self.bg = bg

		local r,g,b = text:GetTextColor()
		text:SetFontObject("NumberFontNormal")
		text:SetTextColor(r,g,b)
		self.text = text

		ChatBubble_OnShow(self)
		self:SetScript("OnShow",ChatBubble_OnShow)
	end
end


local function IdentifyFrame(self)
    if self:GetName() then return end
    if self.GetRegions then
        local region = self:GetRegions()
        if region.GetTexture then
        	local texturePath = region:GetTexture()
        	if texturePath == "Interface\\TargetingFrame\\UI-TargetingFrame-Flash" then
        		return "NamePlate"
        	elseif texturePath == "Interface\\Tooltips\\ChatBubble-Background" then
        		return "ChatBubble"
        	end
        end
    end
end

local function iterateChildrens(object,...)
	if not object then return end

	local type = IdentifyFrame(object)
	if type == "NamePlate" then
		InitNamePlate(object)
	elseif type == "ChatBubble" then
		InitChatBubble(object)
	end

	return iterateChildrens(...)
end


local select,WorldFrame = select,WorldFrame
local lastChildrensCount = 0
CreateFrame("frame"):SetScript("OnUpdate",function()
	if WorldFrame:GetNumChildren() ~= lastChildrensCount then
		iterateChildrens(select(lastChildrensCount+1,WorldFrame:GetChildren()))
		lastChildrensCount = WorldFrame:GetNumChildren()
	end
end)