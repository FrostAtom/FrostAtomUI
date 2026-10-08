local _, ns = ...

local CombatAlert = ns:NewModule("CombatAlert")

local HOLD_TIME = 1
local FADE_TIME = 0.5

local alert = CreateFrame("Frame", nil, UIParent)
alert:SetSize(200, 30)
CombatAlert:AnchorToConfig(alert, "combatAlert.point", "Combat alert", { floating = true })
alert:SetFrameStrata("HIGH")
alert:Hide()

local text = alert:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER")

alert:SetScript("OnUpdate", function(self, elapsed)
	if self.hold > 0 then
		self.hold = self.hold - elapsed
		return
	end

	local alpha = self:GetAlpha() - elapsed / FADE_TIME
	if alpha > 0 then
		self:SetAlpha(alpha)
	else
		self:Hide()
	end
end)

local function showAlert(message, color)
	local config = ns.Config.combatAlert
	if not config.enabled then
		return
	end
	text:SetText(message)
	text:SetTextColor(unpack(color))
	alert.hold = HOLD_TIME
	alert:SetAlpha(1)
	alert:Show()
end

local function showEnterAlert()
	local config = ns.Config.combatAlert
	showAlert(config.enterText, config.enterColor)
	ns.ExplainOnce("combatAlert")
end

local function showLeaveAlert()
	local config = ns.Config.combatAlert
	showAlert(config.leaveText, config.leaveColor)
end

ns.API.RegisterAction("combatAlertTest", function()
	CombatAlert:TestCombatAlert()
end)

function CombatAlert:TestCombatAlert()
	showEnterAlert()
end

local function applyConfig()
	local font = ns.Config.combatAlert.font
	ns.SetFont(text, font.size, font.outline, true)
end

applyConfig()
CombatAlert:WatchConfig("combatAlert", applyConfig)

CombatAlert:RegisterEvent("PLAYER_REGEN_DISABLED", showEnterAlert)
CombatAlert:RegisterEvent("PLAYER_REGEN_ENABLED", showLeaveAlert)
