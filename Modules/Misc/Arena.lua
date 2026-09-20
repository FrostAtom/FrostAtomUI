local _, ns = ...

local CreateFrame = CreateFrame
local GetTime = GetTime
local GetZoneText = GetZoneText
local ceil = math.ceil
local FlashWindow = FlashWindow or ns.noop

local COUNTDOWN_MESSAGE = "Fifteen seconds until the Arena battle begins!"
local COUNTDOWN_SECONDS = 15

local countdown = CreateFrame("Frame")
countdown:Hide()
countdown:SetPoint("CENTER", 0, 180)
countdown:SetSize(2, 2)

countdown.text = countdown:CreateFontString(nil, "BORDER")
countdown.text:SetPoint("CENTER")
countdown.text:SetFont(ns.Media.fontBold, 24, "OUTLINE")

countdown:SetScript("OnUpdate", function(self, elapsed)
	self.remain = self.remain - elapsed
	if self.remain <= 0 then
		self:Hide()
		FlashWindow()
	elseif self.remain <= 3 then
		self.text:SetFormattedText("%.1f", self.remain)
		self.text:SetTextColor(1, 0, 0)
	else
		self.text:SetText(ceil(self.remain))
		self.text:SetTextColor(1, 1, 1)
	end
end)

countdown:SetScript("OnEvent", function(self, event, message)
	if event == "PLAYER_ENTERING_WORLD" then
		self:Hide()
	elseif message:find(COUNTDOWN_MESSAGE) then
		self.remain = COUNTDOWN_SECONDS
		self:Show()
	end
end)
countdown:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
countdown:RegisterEvent("PLAYER_ENTERING_WORLD")

local RING_OF_VALOR = "The Ring of Valor"
local BATTLE_BEGUN_MESSAGE = "The Arena battle has begun!"
local FIRST_TOGGLE = 45
local TOGGLE_PERIOD = 25
local TICK_INTERVAL = 0.05

local pillars = CreateFrame("StatusBar", nil, UIParent)
pillars:Hide()
pillars:SetStatusBarTexture(ns.Media.blank)
pillars:SetStatusBarColor(0, 0, 0, 0.7)
pillars:SetOrientation("VERTICAL")
pillars:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 2, 10)
pillars:SetSize(36, 36)

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
		self:SetValue((GetTime() - self.firstToggleAt) % TOGGLE_PERIOD)
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
		self:SetValue(FIRST_TOGGLE - (self.firstToggleAt - now))
	else
		self:SetMinMaxValues(0, TOGGLE_PERIOD)
		self:SetScript("OnUpdate", onUpdateToggling)
		onUpdateToggling(self, 0)
	end
end

pillars:SetScript("OnShow", function(self)
	self.firstToggleAt = GetTime() + FIRST_TOGGLE
	self.untilTick = 0
	self:SetMinMaxValues(0, FIRST_TOGGLE)
	self:SetScript("OnUpdate", onUpdateWaiting)
end)

pillars:SetScript("OnEvent", function(self, event, message)
	if event == "PLAYER_ENTERING_WORLD" then
		self:Hide()
	elseif message == BATTLE_BEGUN_MESSAGE and GetZoneText() == RING_OF_VALOR then
		self:Show()
	end
end)
pillars:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
pillars:RegisterEvent("PLAYER_ENTERING_WORLD")
