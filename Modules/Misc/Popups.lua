local _, ns = ...

-- Automatic answers to some popups, and flashing the window (taskbar) when
-- attention is needed.

local StaticPopupDialogs = StaticPopupDialogs
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local FlashWindow = FlashWindow or ns.noop -- server-specific API

local Misc = ns:GetModule("Misc")

local declineDuels = false

hooksecurefunc("StaticPopup_Show", function(which)
	if which == "DUEL_REQUESTED" then
		if declineDuels then
			StaticPopupDialogs[which].OnCancel()
		end
	elseif which == "DEATH" then
		-- Release instantly in battlegrounds.
		local _, instanceType = IsInInstance()
		if instanceType == "pvp" then
			StaticPopupDialogs[which].OnAccept()
		end
	elseif which == "TRADE" then
		if InCombatLockdown() then
			StaticPopupDialogs[which].OnCancel()
		end
	elseif which == "PARTY_INVITE" or which == "CONFIRM_BATTLEFIELD_ENTRY" then
		FlashWindow()
	end
end)

--------------------------------------------------
-- Invites from friends and guild members are accepted automatically.

local GetNumFriends, GetFriendInfo = GetNumFriends, GetFriendInfo
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers

local function isFriendOrGuildMate(name)
	for i = 1, GetNumFriends() do
		if GetFriendInfo(i) == name then
			return true
		end
	end
	for i = 1, GetNumGuildMembers() do
		if GetGuildRosterInfo(i) == name then
			return true
		end
	end
	return false
end

-- The roster is empty until requested once.
Misc:RegisterEvent("PLAYER_LOGIN", function()
	if IsInGuild() then
		GuildRoster()
	end
end)

Misc:RegisterEvent("PARTY_INVITE_REQUEST", function(_, leader)
	if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
		return
	end
	if isFriendOrGuildMate(leader) then
		AcceptGroup()
		StaticPopup_Hide("PARTY_INVITE")
		ns.Print("accepted %s's invite", leader)
	end
end)

Misc:RegisterEvent("CHAT_MSG_WHISPER", FlashWindow)
Misc:RegisterEvent("PLAYER_LOGOUT", FlashWindow)

Misc:RegisterEvent(ns.DB_LOADED, function(_, db)
	declineDuels = db.NoDuel
end)

SlashCmdList.FROSTATOMUI_NODUEL = function()
	declineDuels = not declineDuels
	ns:SaveVariable("NoDuel", declineDuels)
	ns.Print("NoDuel %s", declineDuels and "enabled" or "disabled")
end
SLASH_FROSTATOMUI_NODUEL1 = "/noduel"
