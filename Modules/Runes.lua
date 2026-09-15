local namespace = select(2,...)
local Runes = namespace:New("Runes")

local GetRuneType = GetRuneType
local GetRuneCooldown = GetRuneCooldown
local GetType = GetType

local RUNETYPE_BLOOD = 1
local RUNETYPE_UNHOLY = 2
local RUNETYPE_FROST = 3
local RUNETYPE_DEATH = 4

local runeColors = {
	[RUNETYPE_BLOOD] = {1,0,0},
	[RUNETYPE_UNHOLY] = {0,0.5,0},
	[RUNETYPE_FROST] = {0,1,1},
	[RUNETYPE_DEATH] = {0.8,0.1,1},
}

local framePrototype = setmetatable(CopyTable(namespace:GetObjectPrototype()),getmetatable(CastingBarFrame))
local frameMT = {__index = framePrototype}

function framePrototype:UpdateType()
	local type = GetRuneType(self:GetID())

	if type then
		local r,g,b = unpack(runeColors[type])
		self:GetStatusBarTexture():SetTexture(r,g,b)
		self.bg:SetTexture(r*0.3,g*0.3,b*0.3)
	else
		self:GetStatusBarTexture():SetTexture(0.2,0.2,0.2)
		self:SetTexture(0.2*0.3,0.2*0.3,0.2*0.3)
	end
end

function framePrototype:OnUpdate()
	local start,duration,ready = GetRuneCooldown(self:GetID())
	if ready then
		self:SetValue(1)
		self:SetScript("OnUpdate",nil)
	else
		self:SetValue((GetTime()-start)/duration)
	end
end


function framePrototype:RUNE_TYPE_UPDATE(rune)
	if rune ~= self:GetID() then
		return
	end

	self:UpdateType()
end

function framePrototype:RUNE_POWER_UPDATE(rune,usable)
	if rune ~= self:GetID() then
		return
	end

	if usable then
		self:SetValue(1)
	else
		self:SetScript("OnUpdate",self.OnUpdate)
	end
end


function Runes:Create(id)
	local frame = setmetatable(CreateFrame("StatusBar",nil,UIParent),frameMT)
	frame:SetSize(48,16)
	frame:SetMinMaxValues(0,1)

	local statusBarTexture = frame:CreateTexture(nil,"BORDER")
	statusBarTexture:SetAllPoints()
	
	local bg = frame:CreateTexture(nil,"BACKGROUND")
	bg:SetAllPoints()

	frame:RegisterEvent("PLAYER_ENTERING_WORLD","UpdateType")
	frame:RegisterEvent("RUNE_TYPE_UPDATE")
	frame:RegisterEvent("RUNE_POWER_UPDATE")

	frame:SetStatusBarTexture(statusBarTexture)
	frame:SetID(id)
	frame.bg = bg

	return frame
end

function Runes:Initialize()
	if select(2,UnitClass("player")) ~= "DEATHKNIGHT" then
		return
	end

	for i = 1,6 do
		self:Create(i):SetPoint("CENTER",-1+(3.5-i)*50,-294)
	end
end