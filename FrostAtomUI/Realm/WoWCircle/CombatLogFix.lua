local _, ns = ...

ns.OnRealm("wowcircle", function()
	local CombatLogClearEntries = CombatLogClearEntries
	local IsInInstance = IsInInstance

	local CombatLogFix = ns:NewModule("CombatLogFix")

	local SILENCE_TIMEOUT = 0.8

	-- 3.3.5 (seen on WoW Circle): the combat log can stall after a cast until CombatLogClearEntries
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
			ns.CombatLog.Register(self, ns.CombatLog.ALL, self.COMBAT_LOG_EVENT_UNFILTERED)
			self:RegisterEvent("UNIT_SPELLCAST_SENT")
		else
			ns.CombatLog.Unregister(self, self.COMBAT_LOG_EVENT_UNFILTERED)
			self:UnregisterEvent("UNIT_SPELLCAST_SENT")
			watchdog:Hide()
		end
	end

	function CombatLogFix:Initialize()
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:WatchConfig("combatLogFix", self.PLAYER_ENTERING_WORLD)
	end
end)
