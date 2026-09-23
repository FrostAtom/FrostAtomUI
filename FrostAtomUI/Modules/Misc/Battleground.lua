local _, ns = ...

local IsInInstance = IsInInstance
local GetBattlefieldWinner = GetBattlefieldWinner
local GetBattlefieldInstanceExpiration = GetBattlefieldInstanceExpiration
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local SecondsToTime = SecondsToTime
local GetTime = GetTime
local RaidNotice_AddMessage = RaidNotice_AddMessage
local RaidBossEmoteFrame = RaidBossEmoteFrame
local RaidWarningFrame = RaidWarningFrame
local RAID_BOSS_EMOTE_INFO = ChatTypeInfo.RAID_BOSS_EMOTE
local RAID_WARNING_INFO = ChatTypeInfo.RAID_WARNING
local format = string.format

local Misc = ns:GetModule("Misc")

local CLOSE_THRESHOLDS = { 600, 300, 60, 15 }
local CHECK_INTERVAL = 1

local function onSystemMessage(_, message)
	local config = ns.Config.battleground
	local _, instanceType = IsInInstance()
	if config.enabled and config.raidWarnings and (instanceType == "pvp" or instanceType == "arena") then
		RaidNotice_AddMessage(RaidBossEmoteFrame, message, RAID_BOSS_EMOTE_INFO)
	end
end

Misc:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE", onSystemMessage)
Misc:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE", onSystemMessage)
Misc:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL", onSystemMessage)

local closeTimer = CreateFrame("Frame")
closeTimer:Hide()

local function warnClose(seconds)
	local template = IsActiveBattlefieldArena() and ARENA_COMPLETE_MESSAGE or BATTLEGROUND_COMPLETE_MESSAGE
	RaidNotice_AddMessage(RaidWarningFrame, format(template, SecondsToTime(seconds)), RAID_WARNING_INFO)
end

closeTimer:SetScript("OnUpdate", function(self, elapsed)
	self.untilCheck = self.untilCheck - elapsed
	if self.untilCheck > 0 then
		return
	end
	self.untilCheck = CHECK_INTERVAL
	if not GetBattlefieldWinner() then
		self:Hide()
		return
	end
	local threshold = CLOSE_THRESHOLDS[self.nextIndex]
	if self.closeAt - GetTime() <= threshold then
		warnClose(threshold)
		self.nextIndex = self.nextIndex + 1
		if not CLOSE_THRESHOLDS[self.nextIndex] then
			self:Hide()
		end
	end
end)

local function trackClose()
	local config = ns.Config.battleground
	if not config.enabled or not config.closeWarnings or not GetBattlefieldWinner() then
		closeTimer:Hide()
		return
	end
	local expiration = GetBattlefieldInstanceExpiration()
	if not expiration or expiration <= 0 then
		return
	end
	local remaining = expiration / 1000
	closeTimer.closeAt = GetTime() + remaining
	if closeTimer:IsShown() or closeTimer.warningsScheduled then
		return
	end
	local index = 1
	while CLOSE_THRESHOLDS[index] and CLOSE_THRESHOLDS[index] >= remaining do
		index = index + 1
	end
	closeTimer.warningsScheduled = true
	if CLOSE_THRESHOLDS[index] then
		closeTimer.nextIndex = index
		closeTimer.untilCheck = 0
		closeTimer:Show()
	end
end

Misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", trackClose)
Misc:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", trackClose)
Misc:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	closeTimer.warningsScheduled = nil
	closeTimer:Hide()
end)
Misc:WatchConfig("battleground", trackClose)
