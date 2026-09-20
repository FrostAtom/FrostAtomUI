local _, ns = ...

local StaticPopupDialogs = StaticPopupDialogs
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance

local Misc = ns:GetModule("Misc")

local declineDuels = false

local function cancelDuel()
	CancelDuel()
end

local function setDeclineDuels(enabled)
	declineDuels = enabled
	if enabled then
		UIParent:UnregisterEvent("DUEL_REQUESTED")
		Misc:RegisterEvent("DUEL_REQUESTED", cancelDuel)
	else
		Misc:UnregisterEvent("DUEL_REQUESTED")
		UIParent:RegisterEvent("DUEL_REQUESTED")
	end
end

UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
Misc:RegisterEvent("UI_INFO_MESSAGE", function(_, message)
	if declineDuels and message == ERR_DUEL_CANCELLED then
		return
	end
	UIErrorsFrame:AddMessage(message, 1, 1, 0, 1)
end)

local function fillDeleteConfirmation(which)
	for i = 1, STATICPOPUP_NUMDIALOGS do
		local dialog = _G["StaticPopup" .. i]
		if dialog:IsShown() and dialog.which == which then
			dialog.editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
			return
		end
	end
end

hooksecurefunc("StaticPopup_Show", function(which)
	if which == "DEATH" then
		local _, instanceType = IsInInstance()
		if instanceType == "pvp" then
			StaticPopupDialogs[which].OnAccept()
		end
	elseif which == "TRADE" then
		if InCombatLockdown() then
			StaticPopupDialogs[which].OnCancel()
		end
	elseif which == "DELETE_GOOD_ITEM" or which == "DELETE_GOOD_QUEST_ITEM" then
		fillDeleteConfirmation(which)
	end
end)

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

Misc:RegisterEvent(ns.DB_LOADED, function(_, db)
	setDeclineDuels(db.NoDuel)
end)

SlashCmdList.FROSTATOMUI_NODUEL = function()
	setDeclineDuels(not declineDuels)
	ns:SaveVariable("NoDuel", declineDuels)
	ns.Print("NoDuel %s", declineDuels and "enabled" or "disabled")
end
SLASH_FROSTATOMUI_NODUEL1 = "/noduel"
