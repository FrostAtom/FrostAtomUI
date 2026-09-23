local _, ns = ...

local L = ns.L

local UnitGUID, UnitName, UnitClass = UnitGUID, UnitName, UnitClass
local UnitIsPlayer, UnitCanAttack, UnitIsUnit = UnitIsPlayer, UnitCanAttack, UnitIsUnit
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local IsInInstance, GetTime, PlaySound = IsInInstance, GetTime, PlaySound
local wipe = wipe

local Misc = ns:GetModule("Misc")
local UF = ns:GetModule("UnitFrames")
local Auras = ns.Auras

local canDispel = UF.canDispel
local events = ns.Mixin({}, ns.EventMixin)

local WATCHED_TARGETS = { target = "targettarget", focus = "focustarget" }
for i = 1, 5 do
	WATCHED_TARGETS["arena" .. i] = "arena" .. i .. "target"
end

local lastPlayed = 0
local inArena = false
local targeting = {}
local seenDebuffs, scannedDebuffs = {}, {}

local function play(sound)
	local now = GetTime()
	if now - lastPlayed < ns.Config.soundAlerts.throttle then
		return
	end
	lastPlayed = now
	PlaySound(sound)
end

local function classColoredName(unit)
	local name = UnitName(unit)
	local _, class = UnitClass(unit)
	local color = class and RAID_CLASS_COLORS[class]
	if name and color then
		return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, name)
	end
	return name
end

local function announceTargeted(unit)
	local config = ns.Config.soundAlerts
	play(config.targetedSound)
	if config.targetedText then
		local name = classColoredName(unit)
		if name then
			UIErrorsFrame:AddMessage(L["Targeted by %s"]:format(name), 1, 0.3, 0.3)
		end
	end
end

local function onUnitTarget(_, unit)
	local unitTarget = WATCHED_TARGETS[unit]
	if not unitTarget or (ns.Config.soundAlerts.targetedArenaOnly and not inArena) then
		return
	end
	if not UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
		return
	end
	local guid = UnitGUID(unit)
	if not guid then
		return
	end
	if UnitIsUnit(unitTarget, "player") then
		if not targeting[guid] then
			targeting[guid] = true
			announceTargeted(unit)
		end
	else
		targeting[guid] = nil
	end
end

local function resetTargeting()
	wipe(targeting)
end

local function onZoneChanged()
	local _, instanceType = IsInInstance()
	inArena = instanceType == "arena"
	wipe(targeting)
end

local function alertCast(unit, notInterruptible)
	if notInterruptible or not UnitCanAttack("player", unit) then
		return
	end
	if unit == "focus" and UnitIsUnit("focus", "target") then
		return
	end
	play(ns.Config.soundAlerts.interruptibleSound)
end

local function onCastStart(_, unit)
	local _, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
	alertCast(unit, notInterruptible)
end

local function onChannelStart(_, unit)
	local _, _, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
	alertCast(unit, notInterruptible)
end

local function scanDebuffs(silent)
	local minDuration = ns.Config.soundAlerts.dispellableMinDuration
	local auras, count = Auras.Get("player", "HARMFUL")
	local alert = false
	for i = 1, count do
		local aura = auras[i]
		local spellId, expires = aura.spellId, aura.expires
		if spellId then
			scannedDebuffs[spellId] = expires
			local debuffType = aura.debuffType
			if
				debuffType
				and canDispel[debuffType]
				and aura.duration >= minDuration
				and seenDebuffs[spellId] ~= expires
			then
				alert = true
			end
		end
	end
	seenDebuffs, scannedDebuffs = scannedDebuffs, seenDebuffs
	wipe(scannedDebuffs)
	if alert and not silent then
		play(ns.Config.soundAlerts.dispellableSound)
	end
end

local function onPlayerAura()
	scanDebuffs(false)
end

local function onCombatLog(_, _, event, sourceGUID)
	if event ~= "SPELL_INTERRUPT" then
		return
	end
	if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then
		play(ns.Config.soundAlerts.interruptSuccessSound)
	end
end

local function applyConfig()
	local config = ns.Config.soundAlerts
	events:UnregisterAllEvents()
	if not config.enabled then
		return
	end

	if config.targeted then
		onZoneChanged()
		events:RegisterEvent("UNIT_TARGET", onUnitTarget)
		events:RegisterEvent("PLAYER_ENTERING_WORLD", onZoneChanged)
		events:RegisterEvent("ZONE_CHANGED_NEW_AREA", onZoneChanged)
		events:RegisterEvent("PLAYER_REGEN_ENABLED", resetTargeting)
	end

	if config.interruptible then
		events:RegisterUnitEvent("UNIT_SPELLCAST_START", "target", onCastStart)
		events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target", onChannelStart)
		if config.interruptibleFocus then
			events:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus", onCastStart)
			events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus", onChannelStart)
		end
	end

	if config.dispellable and canDispel then
		scanDebuffs(true)
		events:RegisterUnitEvent("UNIT_AURA", "player", onPlayerAura)
	end

	if config.interruptSuccess then
		events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	end
end

Misc:WatchConfig("soundAlerts", function(_, path)
	if path and path:find("Sound$") then
		PlaySound(ns:GetConfig(path))
	end
	applyConfig()
end)
