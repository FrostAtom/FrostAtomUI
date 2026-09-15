local engine = select(2,...)
local UF = engine:Get("UnitFrames")

local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitHealth,UnitHealthMax = UnitHealth,UnitHealthMax

local formatV = engine.formatV
local colorGradient = UF.ColorGradient


local COLORS = function() return
	0.8,0.2,0.2,
	0.65,0.63,0.35,
	0.33,0.59,0.33
end

local function updateFunc(self)
	local unit = self.unit
	local health = self.health
	local text = health.text

	if not UnitIsConnected(unit) then
		health:SetMinMaxValues(0,1)
		health:SetValue(0)
		health.bg:SetVertexColor(self:GetBackdropColor())

		text:SetText("offline")
	elseif UnitIsDeadOrGhost(unit) then
		health:SetMinMaxValues(0,1)
		health:SetValue(0)

		local r,g,b = colorGradient(0,COLORS())
		health.bg:SetVertexColor(r*0.3,g*0.3,b*0.3)

		text:SetText("RIP")
	else
		local min,max = UnitHealth(unit),UnitHealthMax(unit)
		health:SetMinMaxValues(0,max)
		health:SetValue(min)

		local r,g,b = colorGradient(min/max,COLORS())
		health:SetStatusBarColor(r,g,b)
		health.bg:SetVertexColor(r*0.3,g*0.3,b*0.3)

		text:SetText(formatV(min))
	end
end

local function UNIT_HEALTH(self,unit)
	if unit ~= self.unit then
		return
	end

	updateFunc(self)
end

local function onUpdate(self)
	local min = UnitHealth(self.unit)
	if min ~= self.min then
		self.min = min

		updateFunc(self:GetParent())
	end
end

local function createFunc(self)
	local health = CreateFrame("StatusBar",nil,self)
	health:SetFrameLevel(self:GetFrameLevel())
	health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

	local bg = health:CreateTexture(nil,"BORDER")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8x8")

	local text = health:CreateFontString(nil,"OVERLAY","SystemFont_Outline_Small")
    text:SetTextColor(1,0.9,0.8)

	health:SetScript("OnUpdate",onUpdate)
	self:RegisterEvent("UNIT_MAXHEALTH",UNIT_HEALTH)


	health.unit = self.unit
	health.bg = bg
	health.text = text
	return health
end

UF:AddModule("health",createFunc,updateFunc)


