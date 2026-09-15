local namespace = select(2,...)
local CooldownTimer = namespace:New("CooldownTimer")

local ceil = ceil
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc


function CooldownTimer.OnUpdate(self,elapsed)
	if not self.remain then return end

	local remain = self.remain - elapsed
    if remain > 0 then
        if remain <= 3 then
            self.timer:SetTextColor(1,0,0)
            self.timer:SetFormattedText("%.1f",remain)
        elseif remain <= 60 then
            self.timer:SetTextColor(1,1,0)
            self.timer:SetText(ceil(remain))
        elseif remain <= 3600 then
            self.timer:SetText(ceil(remain/60).."m")
            self.timer:SetTextColor(1,1,1)
        else
            self.timer:SetText(ceil(remain/3600).."h")
            self.timer:SetTextColor(0.6,0.6,0.6)
        end
		self.remain = remain
    else
        self.remain = nil
    	self.timer:Hide()
    end
end

function CooldownTimer.SetCooldown(self,startTime,duration)
    if duration > 1.5 then
        self.remain = startTime + duration - GetTime()
        self.timer:Show()
    else
        self.remain = nil
        self.timer:Hide()
    end
end

function CooldownTimer:Create(cooldownFrame,fontSize)
    local timer = cooldownFrame:CreateFontString(nil,"ARTWORK")
    timer:SetPoint("CENTER")
    timer:SetFont("Fonts\\ARIALN.ttf",fontSize or 12,"OUTLINE")
    timer:SetShadowOffset(1,-1)
    cooldownFrame.timer = timer
    self:Setup(cooldownFrame)
end

function CooldownTimer:Setup(cooldownFrame)
    cooldownFrame:SetScript("OnUpdate",self.OnUpdate)
    hooksecurefunc(cooldownFrame,"SetCooldown",self.SetCooldown)
end
