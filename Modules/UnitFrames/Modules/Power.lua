local engine = select(2,...)
local UF = engine:Get("UnitFrames")

local unpack = unpack
local UnitPower,UnitPowerMax = UnitPower,UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitIsConnected = UnitIsConnected

local formatV = engine.formatV
local powerColors = UF.powerColors



local function updateFunc(self)
	local unit = self.unit
	local power = self.power

	if not UnitIsConnected(unit) then
		power:SetMinMaxValues(0,1)
		power:SetValue(0)
		power.bg:SetVertexColor(self:GetBackdropColor())

		power.text:SetText(nil)
	else
		local min,max = UnitPower(unit),UnitPowerMax(unit)
		power:SetMinMaxValues(0,max)
		power:SetValue(min)

		local r,g,b = unpack(powerColors[UnitPowerType(unit)])
		power:SetStatusBarColor(r,g,b)
		power.bg:SetVertexColor(r*0.3,g*0.3,b*0.3)

		power.text:SetText(formatV(min))
	end
end

local function UNIT_POWER(self,unit)
	if self.unit ~= unit then
		return
	end

	updateFunc(self)
end

local function onUpdate(self)
	local min = UnitPower(self.unit)
	if min ~= self.min then
		self.min = min

		updateFunc(self:GetParent())
	end
end

local function createFunc(self)
	local power = CreateFrame("StatusBar",nil,self)
	power:SetFrameLevel(self:GetFrameLevel())
	power:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

	local bg = power:CreateTexture(nil,"BORDER")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8x8")

	local text = power:CreateFontString(nil,"OVERLAY","SystemFont_Outline_Small")
    text:SetTextColor(1,0.9,0.8)

	power:SetScript("OnUpdate",onUpdate)
	self:RegisterEvent("UNIT_MAXMANA",UNIT_POWER)
	self:RegisterEvent("UNIT_MAXRAGE",UNIT_POWER)
	self:RegisterEvent("UNIT_MAXFOCUS",UNIT_POWER)
	self:RegisterEvent("UNIT_MAXENERGY",UNIT_POWER)
	self:RegisterEvent("UNIT_DISPLAYPOWER",UNIT_POWER)
	self:RegisterEvent("UNIT_MAXRUNIC_POWER",UNIT_POWER)


	power.unit = self.unit
	power.bg = bg
	power.text = text
	return power
end

UF:AddModule("power",createFunc,updateFunc)