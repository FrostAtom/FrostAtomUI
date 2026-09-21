local _, ns = ...

local CreateFrame = CreateFrame
local unpack = unpack

local Misc = ns:GetModule("Misc")

local FADE_SPEED = 2

local alert = CreateFrame("Frame", nil, UIParent)
alert:SetSize(200, 30)
Misc:AnchorToConfig(alert, "combatAlert.point")
alert:SetFrameStrata("HIGH")
alert:Hide()

local text = alert:CreateFontString(nil, "OVERLAY")
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

local function show(message, color)
	local config = ns.Config.combatAlert
	if not config.enabled then
		return
	end
	text:SetText(message)
	text:SetTextColor(unpack(color))
	alert.hold = config.duration
	alert:SetAlpha(1)
	alert:Show()
end

local function applyConfig()
	local font = ns.Config.combatAlert.font
	text:SetFont(ns.Media.fontBold, font.size, font.outline)
end

applyConfig()
Misc:WatchConfig("combatAlert", applyConfig)

Misc:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	local config = ns.Config.combatAlert
	show(config.enterText, config.enterColor)
end)

Misc:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	local config = ns.Config.combatAlert
	show(config.leaveText, config.leaveColor)
end)
