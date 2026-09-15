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
