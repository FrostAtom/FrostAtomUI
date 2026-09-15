local engine = select(2,...)
local UF = engine:Get("UnitFrames")

local UnitAura = UnitAura
local CreateFrame = CreateFrame
local unpack = unpack
local math = math


local debuffColors = {}
for debuffType,tbl in pairs(DebuffTypeColor) do
	debuffColors[debuffType] = {tbl.r,tbl.g,tbl.b}
end


local calculatePoint = function(i,inRow,size)
	i = i - 1
	return "TOPLEFT",i%inRow*size,-floor(i/inRow)*size
end

local createIcon
do
	local function onUpdate(self)
		GameTooltip:SetUnitAura(self:GetParent():GetParent().unit,self:GetID(),self.filter)
	end

	local function onEnter(self)
		GameTooltip:SetOwner(self,"ANCHOR_BOTTOMRIGHT")
		self:SetScript("OnUpdate",onUpdate)
	end

	local function onLeave(self)
		self:SetScript("OnUpdate",nil)
		GameTooltip:Hide()
	end

	local function onClick(self)
		CancelUnitBuff("player",self:GetID(),self.filter)
	end


	createIcon = function(parent)
		local button = CreateFrame("Button",nil,parent)
		button:SetFrameLevel(parent:GetFrameLevel())
		button:SetSize(parent.size or 22,parent.size or 22)
		button:SetScript("OnEnter",onEnter)
		button:SetScript("OnLeave",onLeave)

		local cooldown = CreateFrame("Cooldown",nil,button)
		cooldown:SetAllPoints()
		cooldown:SetReverse(true)
		cooldown:SetDrawEdge(true)
		cooldown:SetFrameLevel(button:GetFrameLevel())

		local icon = button:CreateTexture(nil,"BACKGROUND")
		icon:SetAllPoints()

		local count = button:CreateFontString(nil,"OVERLAY","NumberFontNormal")
		count:SetPoint("BOTTOMRIGHT",button,-1,0)

		if parent:GetParent().unit == "player" then
			button:RegisterForClicks("RightButtonDown")
			button:SetScript("OnClick",onClick)
		else
			button:RegisterForClicks()
		end

		if parent:GetParent().debuffs == parent then -- isDebuff
			local overlay = button:CreateTexture(nil,"OVERLAY")
			overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
			overlay:SetAllPoints()
			overlay:SetTexCoord(.296875,.5703125,0,.515625)
			button.overlay = overlay
		end

		button.cooldown = cooldown
		button.icon = icon
		button.count = count
		return button
	end
end

local function inner(auras,unit,filter,isDebuff)
	local max = auras.max
	local name,texture,count,debuffType,duration,endTime,_	
	local button
	for i = 1,40 do
		name,_,texture,count,debuffType,duration,endTime = UnitAura(unit,i,filter)
		if name and (not max or max >= i) then
			button = auras[i]

			if not button then
				button = createIcon(auras)
				button:SetPoint((auras.calculatePoint or calculatePoint)(i,auras.inRow or 8,auras.size or 22))
				button.filter = filter
				button:SetID(i)

				auras[i] = button
			end


			button.icon:SetTexture(texture)

			if isDebuff then
				if debuffType then
					button.overlay:SetVertexColor(unpack(debuffColors[debuffType]))
				else
					button.overlay:SetVertexColor(unpack(debuffColors[""]))
				end
			end

			if (duration and duration > 0) then
				button.cooldown:SetCooldown(endTime-duration,duration)
			else
				button.cooldown:Hide()
			end

			if count and count > 1 then
				button.count:SetText(count)
				button.count:Show()
			else
				button.count:Hide()
			end

			button.filter = filter
			button:SetID(i)
			button:Show()
		else
			auras:SetHeight(math.max(math.ceil((i-1)/(auras.inRow or 8))*(auras.realSize or auras.size),2))

			for j = i,#auras do
				button = auras[j]
				if button:IsShown() then
					button:Hide()
				else
					break
				end
			end
			break
		end
	end
end

do
	local function updateFuncBuffs(self,unit)
		if unit then
			if unit ~= self.unit then
				return
			end
		else
			unit = self.unit
		end

		inner(self.buffs,unit,"HELPFUL")
	end

	local function createFuncBuffs(self)
		local buffs = CreateFrame("frame",nil,self)
		buffs:SetFrameLevel(self:GetFrameLevel())
		buffs:SetSize(2,2)

		self:RegisterEvent("UNIT_AURA",updateFuncBuffs)

		return buffs
	end

	UF:AddModule("buffs",createFuncBuffs,updateFuncBuffs)
end

do
	local function updateFuncDebuffs(self,unit)
		if unit then
			if unit ~= self.unit then
				return
			end
		else
			unit = self.unit
		end

		inner(self.debuffs,unit,"HARMFUL",true)
	end

	local function createFuncDebuffs(self)
		local debuffs = CreateFrame("frame",nil,self)
		debuffs:SetFrameLevel(self:GetFrameLevel())
		debuffs:SetSize(2,2)

		self:RegisterEvent("UNIT_AURA",updateFuncDebuffs)

		return debuffs
	end

	UF:AddModule("debuffs",createFuncDebuffs,updateFuncDebuffs)
end



-- aura caster
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local unpack = unpack
local UnitAura = UnitAura


local classColors = UF.classColors
local function GameTooltip_SetUnitAura(self,...)
    local _,_,_,_,_,_,_,caster,_,_,id = UnitAura(...)
    if id then
    	id = ("|cff3366ffID|r: |cffffffff%d|r"):format(id)
    	if caster then
    		local r,g,b
    		if UnitIsPlayer(caster) then
    			local _,class = UnitClass(caster)
    			r,g,b = unpack(classColors[class])
    		else
    			r,g,b = 1,0.9,0.8
    		end

    		caster = UnitName(caster)
    		self:AddDoubleLine(id,caster,nil,nil,nil,r,g,b)
    	else
    		self:AddLine(id)
    	end

	    self:Show()
	end
end


hooksecurefunc(GameTooltip,"SetUnitDebuff",function(...)
    GameTooltip_SetUnitAura(...,"HARMFUL")
end)
hooksecurefunc(GameTooltip,"SetUnitBuff",GameTooltip_SetUnitAura)
hooksecurefunc(GameTooltip,"SetUnitAura",GameTooltip_SetUnitAura)