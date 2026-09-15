-- WoWCircle-specific: inside instances the combat log sometimes stops
-- delivering events. If a cast is sent and no combat log event follows within
-- a short time, the log is cleared, which un-sticks it.
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
		ns.Print("combat log reset")
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
	if IsInInstance() then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:RegisterEvent("UNIT_SPELLCAST_SENT")
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("UNIT_SPELLCAST_SENT")
	end
end

function CombatLogFix:Initialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end
