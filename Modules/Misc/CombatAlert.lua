local _, ns = ...

local CreateFrame = CreateFrame

local Misc = ns:GetModule("Misc")

local HOLD_TIME = 1
local FADE_SPEED = 2

local alert = CreateFrame("Frame", nil, UIParent)
alert:SetSize(200, 30)
alert:SetPoint(unpack(ns.Config.combatAlert))
alert:SetFrameStrata("HIGH")
alert:Hide()

local text = alert:CreateFontString(nil, "OVERLAY")
text:SetFont(ns.Media.fontBold, 22, "OUTLINE")
text:SetPoint("CENTER")

alert:SetScript("OnUpdate", function(self, elapsed)
	if self.hold > 0 then
		self.hold = self.hold - elapsed
		return
	end

	local alpha = self:GetAlpha() - elapsed * FADE_SPEED
	if alpha > 0 then
		self:SetAlpha(alpha)
	else
		self:Hide()
	end
end)

local function show(message, r, g, b)
	text:SetText(message)
	text:SetTextColor(r, g, b)
	alert.hold = HOLD_TIME
	alert:SetAlpha(1)
	alert:Show()
end

Misc:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	show("+ combat", 1, 0.3, 0.3)
end)

Misc:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	show("- combat", 0.3, 1, 0.3)
end)
