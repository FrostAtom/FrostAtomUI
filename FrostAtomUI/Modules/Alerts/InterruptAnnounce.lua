local _, ns = ...

local L = ns.L

local UnitGUID = UnitGUID
local SendChatMessage = SendChatMessage

local InterruptAnnounce = ns:NewModule("InterruptAnnounce")

local playerGUID

local groupChannel = ns.GroupChannel

local function onCombatLogEvent(_, _, event, sourceGUID, _, _, _, destName, _, _, _, _, _, extraSpellName)
	if event ~= "SPELL_INTERRUPT" then
		return
	end
	if sourceGUID ~= playerGUID and sourceGUID ~= UnitGUID("pet") then
		return
	end

	local channel = groupChannel()
	if channel then
		local ok, message = pcall(format, ns.Config.announce.interruptMessage, destName or "?", extraSpellName or "?")
		if ok then
			SendChatMessage(message, channel)
		end
	end
end

local function applyConfig()
	local config = ns.Config.announce
	if config.enabled and config.interrupts then
		ns.CombatLog.Register(InterruptAnnounce, { "SPELL_INTERRUPT" }, onCombatLogEvent)
	else
		ns.CombatLog.Unregister(InterruptAnnounce, onCombatLogEvent)
	end
end

InterruptAnnounce:RegisterEvent("PLAYER_LOGIN", function()
	playerGUID = UnitGUID("player")
end)
InterruptAnnounce:WatchConfig("announce", applyConfig)

SlashCmdList.FROSTATOMUI_INTERRUPT_ANNOUNCE = function()
	local enabled = not ns.Config.announce.interrupts
	ns:SetConfig("announce.interrupts", enabled)
	ns.Print(L["Interrupt announce %s"], enabled and L["enabled"] or L["disabled"])
end
SLASH_FROSTATOMUI_INTERRUPT_ANNOUNCE1 = "/ia"
