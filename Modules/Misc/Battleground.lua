local _, ns = ...

-- Battleground/arena system messages ("The flag has been taken!", ...) are
-- also shown as a raid warning in the middle of the screen.

local IsInInstance = IsInInstance
local RaidNotice_AddMessage = RaidNotice_AddMessage

local Misc = ns:GetModule("Misc")

local function onSystemMessage(_, message)
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" or instanceType == "arena" then
		RaidNotice_AddMessage(RaidBossEmoteFrame, message, ChatTypeInfo.RAID_BOSS_EMOTE)
	end
end

Misc:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE", onSystemMessage)
Misc:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE", onSystemMessage)
Misc:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL", onSystemMessage)
