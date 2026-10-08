local _, ns = ...

local L = ns.L

local StaticPopupDialogs = StaticPopupDialogs
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local GetNumFriends, GetFriendInfo = GetNumFriends, GetFriendInfo
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers

local Popups = ns:NewModule("Popups")

local DECLINES = {
	declineDuels = {
		slashLabel = "NoDuel",
		event = "DUEL_REQUESTED",
		decline = function()
			CancelDuel()
		end,
		message = ERR_DUEL_CANCELLED,
	},
	declineInvites = {
		slashLabel = "NoParty",
		event = "PARTY_INVITE_REQUEST",
		decline = function()
			DeclineGroup()
		end,
	},
	declineTrades = {
		slashLabel = "NoTrade",
		event = "TRADE_REQUEST",
		decline = function()
			CancelTrade()
		end,
		message = ERR_TRADE_CANCELLED,
	},
}

local function applyDecline(key)
	local decline = DECLINES[key]
	local config = ns.Config.popups
	if config.enabled and config[key] then
		UIParent:UnregisterEvent(decline.event)
		Popups:RegisterEvent(decline.event, decline.decline)
	else
		Popups:UnregisterEvent(decline.event, decline.decline)
		UIParent:RegisterEvent(decline.event)
	end
end

local function isDeclinedMessage(message)
	local config = ns.Config.popups
	if not config.enabled then
		return false
	end
	for key, decline in pairs(DECLINES) do
		if decline.message == message and config[key] then
			return true
		end
	end
	return false
end

UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
Popups:RegisterEvent("UI_INFO_MESSAGE", function(_, message)
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
			dialog.editBox:ClearFocus()
			return
		end
	end
end

local AUTO_RELEASE_DELAY = 1.5

local function autoRelease()
	local _, instanceType = IsInInstance()
	if
		instanceType == "pvp"
		and UnitIsDead("player")
		and StaticPopup_Visible("DEATH")
		and not HasSoulstone()
		and not IsShiftKeyDown()
	then
		StaticPopupDialogs.DEATH.OnAccept()
	end
end

hooksecurefunc("StaticPopup_Show", function(which)
	local config = ns.Config.popups
	if not config.enabled then
		return
	end
	if which == "DEATH" then
		local _, instanceType = IsInInstance()
		if config.autoRelease and instanceType == "pvp" and not HasSoulstone() then
			ns.Scheduler.After(AUTO_RELEASE_DELAY, autoRelease)
		end
	elseif which == "TRADE" then
		if config.declineTradeInCombat and InCombatLockdown() then
			StaticPopupDialogs[which].OnCancel()
		end
	elseif which == "DELETE_GOOD_ITEM" then
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

Popups:RegisterEvent("PLAYER_LOGIN", function()
	if IsInGuild() then
		GuildRoster()
	end
end)

Popups:RegisterEvent("PARTY_INVITE_REQUEST", function(_, leader)
	local config = ns.Config.popups
	if not (config.enabled and config.autoAcceptInvites) or config.declineInvites then
		return
	end
	if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
		return
	end
	if isFriendOrGuildMate(leader) then
		AcceptGroup()
		StaticPopup_Hide("PARTY_INVITE")
		ns.Print(L["accepted %s's invite"], leader)
	end
end)

local function applyDeclines()
	for key in pairs(DECLINES) do
		applyDecline(key)
	end
end

Popups:RegisterEvent(ns.E.DB_LOADED, applyDeclines)

local function toggleDecline(key, label, args)
	local enabled, status = ns.ParseToggle(args, ns.Config.popups[key])
	if not status then
		ns:SetConfig("popups." .. key, enabled)
	end
	ns.Print("%s %s", label, enabled and L["enabled"] or L["disabled"])
end

Popups:WatchConfig("popups", applyDeclines)

for key, decline in pairs(DECLINES) do
	local label = decline.slashLabel
	local command = "FROSTATOMUI_" .. label:upper()
	SlashCmdList[command] = function(args)
		toggleDecline(key, label, args)
	end
	_G["SLASH_" .. command .. "1"] = "/" .. label:lower()
end
