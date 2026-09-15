local engine = select(2,...)
local UF = engine:Get("UnitFrames")


local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetTime = GetTime
local CreateFrame = CreateFrame

local pixelPerfect = engine.pixelPerfect


local function CastBar_CastEnd(self)
	self:SetValue(self.tEnd)
	self.timer:SetText("")
	self.casting = false
end

local function OnUpdate(self,elapsed)
	if self.casting then
		local remain = self.remain - elapsed

		if remain > 0 then
			if self.castId then
				self:SetValue(self.tEnd-remain)
			else
				self:SetValue(self.tEnd+remain)
			end
			self.timer:SetFormattedText("%.1f",remain)
			self.remain = remain
		else
			CastBar_CastEnd(self)
		end
	else
		local newAlpha = self:GetAlpha() - elapsed * 1.4
		if newAlpha > 0 then
			self:SetAlpha(newAlpha)
		else
			self:Hide()
		end
	end
end

local function setInterruptable(self,state)
	if state and self:GetParent().unit ~= "player" then
	    self.icon:SetDesaturated(1)
	    self:SetStatusBarColor(0.4,0.4,0.4)
	else
	    self.icon:SetDesaturated(nil)
	    self:SetStatusBarColor(0.75,0.4,0)
	end
end


local function updateFunc(self,unit)
	if unit then
		if unit ~= self.unit then
			return
		end
	else
		unit = self.unit
	end


	local name,_,_,texture,tStart,tEnd,_,castId,notInterruptible = UnitCastingInfo(unit)
	if not name then
		name,_,_,texture,tStart,tEnd,_,notInterruptible = UnitChannelInfo(unit)
	end

	if not name then
		self.castbar:Hide()
		return
	end

	tEnd,tStart = tEnd/1e3,tStart/1e3
	local castbar = self.castbar

	if name and name ~= "" then
		castbar.name:SetText(name)
	else
		castbar.name:SetText("unknown")
	end

	if texture and texture ~= "" then
		castbar.icon:SetTexture(texture)
	else
		castbar.icon:SetTexture("Interface\\Icons\\Inv_Misc_QuestionMark")
	end
	setInterruptable(castbar,notInterruptible)

	castbar:SetMinMaxValues(tStart,tEnd)
	if castId then -- is cast
		castbar.tEnd,castbar.tStart = tEnd,tStart
		castbar:SetValue(0)
	else -- is channel
		castbar.tEnd,castbar.tStart = tStart,tEnd
		castbar:SetValue(1)
	end

	local remain = tEnd-GetTime()
	castbar.timer:SetFormattedText("%.1f",remain)
	castbar.remain = remain

	castbar.castId = castId
	castbar.casting = true
	castbar:SetAlpha(1)
	castbar:Show()
end

local function UNIT_SPELLCAST_FAILED(self,unit,_,_,castId)
	if unit ~= self.unit then
		return
	end

	local castbar = self.castbar
	if castId == castbar.castId then
	    castbar.name:SetText("|cff8B0000INTERRUPTED|r")

		CastBar_CastEnd(castbar)
	end
end

local function UNIT_SPELLCAST_STOP(self,unit)
	if unit ~= self.unit then
		return
	end

	local castbar = self.castbar
	if castbar.casting then
		CastBar_CastEnd(castbar)
	end
end

local function UNIT_SPELLCAST_DELAYED(self,unit)
	if unit ~= self.unit then
		return
	end

	local castbar = self.castbar
	if castbar.casting then
		local name,_,_,_,tStart,tEnd = UnitCastingInfo(unit)

		if name then
			tStart,tEnd = tStart/1e3,tEnd/1e3
			castbar.tStart,castbar.tEnd = tStart,tEnd
			castbar.remain = tEnd-GetTime()
			castbar:SetMinMaxValues(tStart,tEnd)
			OnUpdate(castbar,0)
		else
			CastBar_CastEnd(castbar)
		end
	end
end

local function UNIT_SPELLCAST_CHANNEL_UPDATE(self,unit)
	if unit ~= self.unit then
		return
	end

	local castbar = self.castbar
	if castbar.casting then
		local name,_,_,_,tStart,tEnd = UnitChannelInfo(unit)

		if name then
			tStart,tEnd = tStart/1e3,tEnd/1e3
			castbar.tStart,castbar.tEnd = tEnd,tStart
			castbar.remain = tEnd-GetTime()
			castbar:SetMinMaxValues(tStart,tEnd)
			OnUpdate(castbar,0)
		else
			CastBar_CastEnd(castbar)
		end
	end
end

local function UNIT_SPELLCAST_INTERRUPTIBLE(self,unit)
	if unit ~= self.unit then
		return
	end

	setInterruptable(self.castbar,false)
end

local function UNIT_SPELLCAST_NOT_INTERRUPTIBLE(self,unit)
	if unit ~= self.unit then
		return
	end
	
	setInterruptable(self.castbar,true)
end


local function createFunc(self,iconAnchorRight)
	local castbar = CreateFrame("StatusBar",nil,self)
	castbar:SetFrameLevel(self:GetFrameLevel())
	castbar:SetMinMaxValues(0,1)
	castbar:SetScript("OnUpdate",OnUpdate)
	castbar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

	local bg = CreateFrame("frame",nil,castbar)
	bg:SetPoint("TOPRIGHT",3,3)
	bg:SetPoint("BOTTOMLEFT",-3,-3)
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
	bg:SetBackdropColor(0,0,0,0.8)
	bg:SetBackdropBorderColor(0.4,0.4,0.4,0.95)
	bg:SetFrameLevel(castbar:GetFrameLevel())

	local icon = castbar:CreateTexture(nil,"BORDER")
	if iconAnchorRight then
		icon:SetPoint("LEFT",castbar,"RIGHT",2,0)
	else
		icon:SetPoint("RIGHT",castbar,"LEFT",-2,0)
	end

	local timer = castbar:CreateFontString(nil,"ARTWORK")
	timer:SetFont("Fonts\\ARIALN.TTF",12,"OUTLINE")
	timer:SetPoint("RIGHT")
	timer:SetJustifyH("LEFT")

	local name = castbar:CreateFontString(nil,"ARTWORK")
	name:SetFont("Fonts\\ARIALN.TTF",12,"OUTLINE")
	name:SetPoint("CENTER")


	self:RegisterEvent("UNIT_SPELLCAST_START",updateFunc)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START",updateFunc)
	self:RegisterEvent("UNIT_SPELLCAST_FAILED",UNIT_SPELLCAST_FAILED)
	self:RegisterEvent("UNIT_SPELLCAST_STOP",UNIT_SPELLCAST_STOP)
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",UNIT_SPELLCAST_STOP)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED",UNIT_SPELLCAST_STOP)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",UNIT_SPELLCAST_STOP)
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED",UNIT_SPELLCAST_DELAYED)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE",UNIT_SPELLCAST_CHANNEL_UPDATE)
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE",UNIT_SPELLCAST_INTERRUPTIBLE)
	self:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE",UNIT_SPELLCAST_NOT_INTERRUPTIBLE)

	castbar.icon = icon
	castbar.timer = timer
	castbar.name = name
	return castbar
end

UF:AddModule("castbar",createFunc,updateFunc)