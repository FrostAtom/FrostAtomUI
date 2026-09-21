local _, ns = ...

local StaticPopupDialogs = StaticPopupDialogs
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local GetNumFriends, GetFriendInfo = GetNumFriends, GetFriendInfo
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers

local Misc = ns:GetModule("Misc")

local DECLINES = {
	declineDuels = { event = "DUEL_REQUESTED", decline = function() CancelDuel() end, message = ERR_DUEL_CANCELLED },
	declineInvites = { event = "PARTY_INVITE_REQUEST", decline = function() DeclineGroup() end },
	declineTrades = { event = "TRADE_REQUEST", decline = function() CancelTrade() end, message = ERR_TRADE_CANCELLED },
}

local function applyDecline(key)
	local decline = DECLINES[key]
	if ns.Config.popups[key] then
		UIParent:UnregisterEvent(decline.event)
		Misc:RegisterEvent(decline.event, decline.decline)
	else
		Misc:UnregisterEvent(decline.event, decline.decline)
		UIParent:RegisterEvent(decline.event)
	end
end

local function isDeclinedMessage(message)
	for key, decline in pairs(DECLINES) do
		if decline.message == message and ns.Config.popups[key] then
			return true
		end
	end
	return false
end

UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
Misc:RegisterEvent("UI_INFO_MESSAGE", function(_, message)
	if isDeclinedMessage(message) then
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
	local config = ns.Config.popups
	if which == "DEATH" then
		local _, instanceType = IsInInstance()
		if config.autoRelease and instanceType == "pvp" then
			StaticPopupDialogs[which].OnAccept()
		end
	elseif which == "TRADE" then
		if config.declineTradeInCombat and InCombatLockdown() then
			StaticPopupDialogs[which].OnCancel()
		end
	elseif which == "DELETE_GOOD_ITEM" or which == "DELETE_GOOD_QUEST_ITEM" then
		if config.fillDeleteConfirm then
			fillDeleteConfirmation(which)
		end
	end
end)

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
	local config = ns.Config.popups
	if not config.autoAcceptInvites or config.declineInvites or GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
		return
	end
	if isFriendOrGuildMate(leader) then
		AcceptGroup()
		StaticPopup_Hide("PARTY_INVITE")
		ns.Print("accepted %s's invite", leader)
	end
end)

Misc:RegisterEvent(ns.DB_LOADED, function(_, db)
	if db.NoDuel ~= nil then
		db.config = db.config or {}
		db.config.popups = db.config.popups or {}
		db.config.popups.declineDuels = db.NoDuel
		ns.Config.popups.declineDuels = db.NoDuel
		db.NoDuel = nil
	end
	for key in pairs(DECLINES) do
		applyDecline(key)
	end
end)

local function toggleDecline(key, label, args)
	local enabled, status = ns.ParseToggle(args, ns.Config.popups[key])
	if not status then
		ns:SetConfig("popups." .. key, enabled)
	end
	ns.Print("%s %s", label, enabled and "enabled" or "disabled")
end

for key in pairs(DECLINES) do
	Misc:WatchConfig("popups." .. key, function()
		applyDecline(key)
	end)
end

SlashCmdList.FROSTATOMUI_NODUEL = function(args)
	toggleDecline("declineDuels", "NoDuel", args)
end
SLASH_FROSTATOMUI_NODUEL1 = "/noduel"

SlashCmdList.FROSTATOMUI_NOPARTY = function(args)
	toggleDecline("declineInvites", "NoParty", args)
end
SLASH_FROSTATOMUI_NOPARTY1 = "/noparty"

SlashCmdList.FROSTATOMUI_NOTRADE = function(args)
	toggleDecline("declineTrades", "NoTrade", args)
end
SLASH_FROSTATOMUI_NOTRADE1 = "/notrade"
