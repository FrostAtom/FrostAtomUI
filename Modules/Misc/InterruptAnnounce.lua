local _, ns = ...

local UnitGUID = UnitGUID
local SendChatMessage = SendChatMessage
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local IsInInstance = IsInInstance

local Misc = ns:GetModule("Misc")

local MESSAGE = "Interrupted %s's %s"

local enabled = true
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
	if event ~= "SPELL_INTERRUPT" or not enabled then
		return
	end
	if sourceGUID ~= playerGUID and sourceGUID ~= UnitGUID("pet") then
		return
	end

	local channel = groupChannel()
	if channel then
		SendChatMessage(MESSAGE:format(destName or "?", extraSpellName or "?"), channel)
	end
end

Misc:RegisterEvent("PLAYER_LOGIN", function()
	playerGUID = UnitGUID("player")
end)
Misc:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)

Misc:RegisterEvent(ns.DB_LOADED, function(_, db)
	if db.InterruptAnnounce ~= nil then
		enabled = db.InterruptAnnounce
	end
end)

SlashCmdList.FROSTATOMUI_INTERRUPT_ANNOUNCE = function()
	enabled = not enabled
	ns:SaveVariable("InterruptAnnounce", enabled)
	ns.Print("Interrupt announce %s", enabled and "enabled" or "disabled")
end
SLASH_FROSTATOMUI_INTERRUPT_ANNOUNCE1 = "/ia"
