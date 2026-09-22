if not GetCVar("realmlist"):lower():find("circle") then
	return
end

local _, ns = ...

local CombatLogClearEntries = CombatLogClearEntries
local IsInInstance = IsInInstance

local CombatLogFix = ns:NewModule("CombatLogFix")

local SILENCE_TIMEOUT = 0.8

local watchdog = CreateFrame("Frame")
watchdog:Hide()
watchdog:SetScript("OnShow", function(self)
	self.remain = SILENCE_TIMEOUT
end)
watchdog:SetScript("OnUpdate", function(self, elapsed)
	self.remain = self.remain - elapsed
	if self.remain < 0 then
		CombatLogClearEntries()
		self:Hide()
	end
end)

function CombatLogFix:UNIT_SPELLCAST_SENT()
	watchdog:Show()
end

function CombatLogFix:COMBAT_LOG_EVENT_UNFILTERED()
	watchdog:Hide()
end

function CombatLogFix:PLAYER_ENTERING_WORLD()
	if ns.Config.combatLogFix.enabled and IsInInstance() then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:RegisterEvent("UNIT_SPELLCAST_SENT")
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("UNIT_SPELLCAST_SENT")
		watchdog:Hide()
	end
end

function CombatLogFix:Initialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:WatchConfig("combatLogFix", self.PLAYER_ENTERING_WORLD)
end
