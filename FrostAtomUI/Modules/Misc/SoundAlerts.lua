local _, ns = ...

local L = ns.L

local UnitGUID, UnitName, UnitClass = UnitGUID, UnitName, UnitClass
local UnitIsPlayer, UnitCanAttack, UnitIsUnit = UnitIsPlayer, UnitCanAttack, UnitIsUnit
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local IsInInstance, GetTime = IsInInstance, GetTime
local IsSpellKnown, GetSpellInfo, GetPetActionInfo = IsSpellKnown, GetSpellInfo, GetPetActionInfo
local wipe = wipe
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS or 10

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
	ns.PlayAlertSound(sound)
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

local interrupts, petInterrupts = {}, {}
do
	local _, class = UnitClass("player")
	local SPELLS = ns.CooldownData.SPELLS
	for _, spells in ipairs({ SPELLS[class] or {}, SPELLS.COMMON }) do
		for i = 1, #spells do
			local entry = spells[i]
			if entry.cat == "interrupt" then
				local list = entry.pet and petInterrupts or interrupts
				list[#list + 1] = entry[1]
				local ranks = entry.ranks
				if ranks then
					for j = 1, #ranks do
						list[#list + 1] = ranks[j]
					end
				end
			end
		end
	end
end

local petInterruptNames = {}
for i = 1, #petInterrupts do
	local name = GetSpellInfo(petInterrupts[i])
	if name then
		petInterruptNames[name] = true
	end
end

local function hasInterrupt()
	for i = 1, #interrupts do
		if IsSpellKnown(interrupts[i]) then
			return true
		end
	end
	if #petInterrupts == 0 then
		return false
	end
	for i = 1, #petInterrupts do
		if IsSpellKnown(petInterrupts[i], true) then
			return true
		end
	end
	for i = 1, NUM_PET_ACTION_SLOTS do
		local name = GetPetActionInfo(i)
		if name and petInterruptNames[name] then
			return true
		end
	end
	return false
end

local uninterruptible = {}
for _, spellId in ipairs({ 49050, 49052 }) do -- Aimed Shot, Steady Shot
	local name = GetSpellInfo(spellId)
	if name then
		uninterruptible[name] = true
	end
end

local function alertCast(unit, spell, notInterruptible)
	if not spell or not UnitCanAttack("player", unit) then
		return
	end
	if unit == "focus" and UnitIsUnit("focus", "target") then
		return
	end
	if not hasInterrupt() then
		return
	end
	if notInterruptible then
		uninterruptible[spell] = true
		return
	end
	if uninterruptible[spell] or ns.HasCastImmunity(unit) then
		return
	end
	play(ns.Config.soundAlerts.interruptibleSound)
end

local function onCastStart(_, unit)
	local spell, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
	alertCast(unit, spell, notInterruptible)
end

local function onChannelStart(_, unit)
	local spell, _, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
	alertCast(unit, spell, notInterruptible)
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
		ns.PlayAlertSound(ns:GetConfig(path))
	end
	applyConfig()
end)
