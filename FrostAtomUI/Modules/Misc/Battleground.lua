local _, ns = ...

local IsInInstance = IsInInstance
local RaidNotice_AddMessage = RaidNotice_AddMessage
local RaidBossEmoteFrame = RaidBossEmoteFrame
local RAID_BOSS_EMOTE_INFO = ChatTypeInfo.RAID_BOSS_EMOTE

local Misc = ns:GetModule("Misc")

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
