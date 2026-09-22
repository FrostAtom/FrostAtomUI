local _, ns = ...

local L = ns.L

local UnitGUID = UnitGUID
local SendChatMessage = SendChatMessage
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local IsInInstance = IsInInstance

local Misc = ns:GetModule("Misc")

local playerGUID

local function groupChannel()
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" then
		return "BATTLEGROUND"
	elseif GetNumRaidMembers() > 0 then
		return "RAID"
	elseif GetNumPartyMembers() > 0 then
		return "PARTY"
	end
end

local function onCombatLogEvent(_, _, event, sourceGUID, _, _, _, destName, _, _, _, _, _, extraSpellName)
	if event ~= "SPELL_INTERRUPT" then
		return
	end
	if sourceGUID ~= playerGUID and sourceGUID ~= UnitGUID("pet") then
		return
	end

	local channel = groupChannel()
	if channel then
		SendChatMessage(ns.Config.announce.interruptMessage:format(destName or "?", extraSpellName or "?"), channel)
	end
end

local function applyConfig()
	local config = ns.Config.announce
	if config.enabled and config.interrupts then
		Misc:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
	else
		Misc:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
	end
end

Misc:RegisterEvent("PLAYER_LOGIN", function()
	playerGUID = UnitGUID("player")
end)
Misc:WatchConfig("announce", applyConfig)

Misc:RegisterEvent(ns.DB_LOADED, function(_, db)
	if db.InterruptAnnounce ~= nil then
		ns:SetConfig("announce.interrupts", db.InterruptAnnounce and true or false)
		db.InterruptAnnounce = nil
	end
end)

SlashCmdList.FROSTATOMUI_INTERRUPT_ANNOUNCE = function()
	local enabled = not ns.Config.announce.interrupts
	ns:SetConfig("announce.interrupts", enabled)
	ns.Print(L["Interrupt announce %s"], enabled and L["enabled"] or L["disabled"])
end
SLASH_FROSTATOMUI_INTERRUPT_ANNOUNCE1 = "/ia"
