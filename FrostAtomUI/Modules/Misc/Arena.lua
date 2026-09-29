local _, ns = ...

local GetTime = GetTime
local GetRealZoneText = GetRealZoneText
local IsInInstance = IsInInstance
local UnitBuff = UnitBuff
local ceil = math.ceil

local Misc = ns:GetModule("Misc")

local function inArena()
	return select(2, IsInInstance()) == "arena"
end

local ARENA_PREPARATION = GetSpellInfo(32727) -- Arena Preparation
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

local function hasArenaPreparation()
	return ARENA_PREPARATION and UnitBuff("player", ARENA_PREPARATION) and true or false
end

pillars:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_ENTERING_WORLD" then
		self:Hide()
		self.preparing = inArena() and hasArenaPreparation()
	elseif unit == "player" then
		if hasArenaPreparation() then
			self.preparing = inArena()
		elseif self.preparing then
			self.preparing = false
			local config = ns.Config.arena
			if config.enabled and config.pillars and ns.ARENA_MAP_KEYS[GetRealZoneText()] == "ringOfValor" then
				self:Show()
			end
		end
	end
end)
pillars:RegisterEvent("UNIT_AURA")
pillars:RegisterEvent("PLAYER_ENTERING_WORLD")

local function applyConfig()
	local config = ns.Config.arena
	pillars:SetSize(config.pillarsSize, config.pillarsSize)
	if not (config.enabled and config.pillars) then
		pillars:Hide()
	end
end

applyConfig()
Misc:WatchConfig("arena", applyConfig)
