local _, ns = ...

local GetTime = GetTime
local GetZoneText = GetZoneText
local ceil = math.ceil

local Misc = ns:GetModule("Misc")

local COUNTDOWN_MESSAGE = "Fifteen seconds until the Arena battle begins!"
local COUNTDOWN_SECONDS = 15
local COUNTDOWN_URGENT_SECONDS = 3

local countdown = CreateFrame("Frame")
countdown:Hide()
Misc:AnchorToConfig(countdown, "arena.countdownPoint", "Arena countdown", {
	size = function()
		local size = ns.Config.arena.countdownFont.size
		return size * 2, size * 1.4
	end,
})
countdown:SetSize(2, 2)

countdown.text = countdown:CreateFontString(nil, "BORDER")
countdown.text:SetPoint("CENTER")

countdown:SetScript("OnUpdate", function(self, elapsed)
	self.remain = self.remain - elapsed
	if self.remain <= 0 then
		self:Hide()
	elseif self.remain <= COUNTDOWN_URGENT_SECONDS then
		self.text:SetFormattedText("%.1f", self.remain)
		self.text:SetTextColor(unpack(ns.Config.arena.countdownUrgentColor))
	else
		self.text:SetText(ceil(self.remain))
		self.text:SetTextColor(unpack(ns.Config.arena.countdownColor))
	end
end)

countdown:SetScript("OnEvent", function(self, event, message)
	if event == "PLAYER_ENTERING_WORLD" then
		self:Hide()
	elseif ns.Config.arena.enabled and ns.Config.arena.countdown and message:find(COUNTDOWN_MESSAGE, 1, true) then
		self.remain = COUNTDOWN_SECONDS
		self:Show()
	end
end)
countdown:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
countdown:RegisterEvent("PLAYER_ENTERING_WORLD")

local RING_OF_VALOR = "The Ring of Valor"
local BATTLE_BEGUN_MESSAGE = "The Arena battle has begun!"
local TICK_INTERVAL = 0.05

local pillars = CreateFrame("StatusBar", nil, UIParent)
pillars:Hide()
pillars:SetStatusBarTexture(ns.Media.blank)
pillars:SetStatusBarColor(0, 0, 0, 0.7)
pillars:SetOrientation("VERTICAL")
pillars:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 2, 10)

local icon = pillars:CreateTexture(nil, "BORDER")
icon:SetTexture("Interface\\Icons\\Ability_Smash")
icon:SetAllPoints()

local pillarsText = pillars:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
pillarsText:SetPoint("CENTER")

pillars:SetScript("OnValueChanged", function(self, value)
	local _, max = self:GetMinMaxValues()
	pillarsText:SetText(ceil(max - value))
end)

local function onUpdateToggling(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick < 0 then
		self.untilTick = TICK_INTERVAL
		self:SetValue((GetTime() - self.firstToggleAt) % self.period)
	end
end

local function onUpdateWaiting(self, elapsed)
	self.untilTick = self.untilTick - elapsed
	if self.untilTick >= 0 then
		return
	end
	self.untilTick = TICK_INTERVAL

	local now = GetTime()
	if now < self.firstToggleAt then
		self:SetValue(self.firstToggle - (self.firstToggleAt - now))
	else
		self:SetMinMaxValues(0, self.period)
		self:SetScript("OnUpdate", onUpdateToggling)
		onUpdateToggling(self, 0)
	end
end

pillars:SetScript("OnShow", function(self)
	local config = ns.Config.arena
	self.firstToggle, self.period = config.pillarsFirstToggle, config.pillarsPeriod
	self.firstToggleAt = GetTime() + self.firstToggle
	self.untilTick = 0
	self:SetMinMaxValues(0, self.firstToggle)
	self:SetScript("OnUpdate", onUpdateWaiting)
end)

pillars:SetScript("OnEvent", function(self, event, message)
	if event == "PLAYER_ENTERING_WORLD" then
		self:Hide()
	elseif message == BATTLE_BEGUN_MESSAGE and GetZoneText() == RING_OF_VALOR then
		local config = ns.Config.arena
		if config.enabled and config.pillars then
			self:Show()
		end
	end
end)
pillars:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
pillars:RegisterEvent("PLAYER_ENTERING_WORLD")

local function applyConfig()
	local config = ns.Config.arena
	local font = config.countdownFont
	ns.SetFont(countdown.text, font.size, font.outline, true)
	pillars:SetSize(config.pillarsSize, config.pillarsSize)
	if not (config.enabled and config.countdown) then
		countdown:Hide()
	end
	if not (config.enabled and config.pillars) then
		pillars:Hide()
	end
end

applyConfig()
Misc:WatchConfig("arena", applyConfig)
