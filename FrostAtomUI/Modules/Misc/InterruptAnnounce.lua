local _, ns = ...

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
	local config = ns.Config.announce
	if event ~= "SPELL_INTERRUPT" or not config.interrupts then
		return
	end
	if sourceGUID ~= playerGUID and sourceGUID ~= UnitGUID("pet") then
		return
	end

	local channel = groupChannel()
	if channel then
		SendChatMessage(config.interruptMessage:format(destName or "?", extraSpellName or "?"), channel)
	end
end

Misc:RegisterEvent("PLAYER_LOGIN", function()
	playerGUID = UnitGUID("player")
end)
Misc:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)

Misc:RegisterEvent(ns.DB_LOADED, function(_, db)
	if db.InterruptAnnounce ~= nil then
		db.config = db.config or {}
		db.config.announce = db.config.announce or {}
		db.config.announce.interrupts = db.InterruptAnnounce
		ns.Config.announce.interrupts = db.InterruptAnnounce
		db.InterruptAnnounce = nil
	end
end)

SlashCmdList.FROSTATOMUI_INTERRUPT_ANNOUNCE = function()
	local enabled = not ns.Config.announce.interrupts
	ns:SetConfig("announce.interrupts", enabled)
	ns.Print("Interrupt announce %s", enabled and "enabled" or "disabled")
end
SLASH_FROSTATOMUI_INTERRUPT_ANNOUNCE1 = "/ia"
