local _, ns = ...

local Data = ns.SpellAlertData
local START, SUCCESS, AURA, AURA_NAMES, CONTROL = Data.START, Data.SUCCESS, Data.AURA, Data.AURA_NAMES, Data.CONTROL
local CAST_NAMES, MY_CONTROL, CLASS_SOUNDS = Data.CAST_NAMES, Data.MY_CONTROL, Data.CLASS_SOUNDS
local VOICE_PATH, LENGTHS, DEFAULT_LENGTH = Data.VOICE_PATH, Data.LENGTHS, Data.DEFAULT_LENGTH

local bit_band = bit.band
local tinsert, tremove, wipe = table.insert, table.remove, wipe
local GetTime, PlaySoundFile, GetPlayerInfoByGUID = GetTime, PlaySoundFile, GetPlayerInfoByGUID
local UnitGUID, UnitIsUnit, UnitIsPlayer, UnitIsEnemy = UnitGUID, UnitIsUnit, UnitIsPlayer, UnitIsEnemy
local IsInInstance = IsInInstance
local COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE

local URGENT = 3
local GAP = 0.15
local MAX_DELAY = 3
local MAX_QUEUE = 3
local REPEAT_TIME = 3

local ZONES = { arena = "arena", pvp = "battleground", none = "world" }

local CASTERS, CASTER_TARGETS = { "target", "focus", "mouseover" }, {}
for i = 1, 5 do
	CASTERS[#CASTERS + 1] = "arena" .. i
	CASTERS[#CASTERS + 1] = "arenapet" .. i
end
for i = 1, 4 do
	CASTERS[#CASTERS + 1] = "party" .. i .. "target"
end
for i = 1, #CASTERS do
	CASTER_TARGETS[i] = CASTERS[i] .. "target"
end

local PARTY = {}
for i = 1, 4 do
	PARTY[i] = "party" .. i
end

local SpellAlerts = ns:NewModule("SpellAlerts")

local config
local zone, playerGUID
local queue, recent = {}, {}
local busyUntil, pumpScheduled = 0, false

local function play(sound, now)
	PlaySoundFile(VOICE_PATH:format(sound), "Master")
	busyUntil = now + (LENGTHS[sound] or DEFAULT_LENGTH) + GAP
end

local pump

local function schedulePump(now)
	if not pumpScheduled and #queue > 0 then
		pumpScheduled = true
		ns.After(busyUntil - now, pump)
	end
end

function pump()
	pumpScheduled = false
	local now = GetTime()
	if now >= busyUntil then
		while #queue > 0 do
			local item = tremove(queue, 1)
			if now - item.time <= MAX_DELAY then
				play(item.sound, now)
				break
			end
		end
	end
	schedulePump(now)
end

local function enqueue(sound, priority)
	local now = GetTime()
	if priority >= URGENT or now >= busyUntil then
		play(sound, now)
		return
	end
	local index = #queue + 1
	while index > 1 and queue[index - 1].priority < priority do
		index = index - 1
	end
	if index > MAX_QUEUE then
		return
	end
	tinsert(queue, index, { sound = sound, priority = priority, time = now })
	queue[MAX_QUEUE + 1] = nil
	schedulePump(now)
end

local function isEnabled(spell)
	local value = config.spells[spell.key]
	if value == nil then
		value = not spell.off
	end
	return value and (not spell.arena or zone == "arena")
end

local function isHostile(flags)
	return bit_band(flags, COMBATLOG_OBJECT_CONTROL_PLAYER) ~= 0
		and bit_band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0
end

local function isCastBy(spell, guid)
	if not spell.casterClass then
		return true
	end
	local _, class = GetPlayerInfoByGUID(guid)
	return not class or class == spell.casterClass
end

local function isWatched(guid)
	return zone == "arena" or not config.targetOnly or guid == UnitGUID("target") or guid == UnitGUID("focus")
end

local function findUnit(units, guid)
	for i = 1, #units do
		if UnitGUID(units[i]) == guid then
			return i
		end
	end
end

local function alert(sound, priority, guid)
	local id = sound .. guid
	local now = GetTime()
	local last = recent[id]
	if last and now - last < REPEAT_TIME then
		return
	end
	recent[id] = now
	enqueue(sound, priority)
end

local function onCastStart(spell, sourceGUID)
	local index = findUnit(CASTERS, sourceGUID)
	if index and not spell.area and UnitIsUnit(CASTER_TARGETS[index], "player") then
		alert(spell.youSound, URGENT, sourceGUID)
	elseif isWatched(sourceGUID) then
		alert(spell.sound, spell.priority, sourceGUID)
	end
end

local function onControl(spell, sourceGUID, destGUID)
	if destGUID == playerGUID then
		if config.controlOnYou then
			alert(spell.youSound, spell.priority, sourceGUID)
		end
	elseif findUnit(PARTY, destGUID) then
		alert(spell.sound, spell.priority, sourceGUID)
	end
end

local function castSound(spell, sourceGUID)
	if spell.class then
		local _, class = GetPlayerInfoByGUID(sourceGUID)
		local suffix = class and CLASS_SOUNDS[class]
		if suffix then
			return spell.sound .. suffix
		end
	end
	return spell.sound
end

local function onCombatLog(_, _, event, sourceGUID, _, sourceFlags, destGUID, _, destFlags, spellId, spellName)
	local spell
	if event == "SPELL_CAST_START" then
		spell = START[spellId]
		if spell and isEnabled(spell) and isHostile(sourceFlags) and isCastBy(spell, sourceGUID) then
			onCastStart(spell, sourceGUID)
		end
	elseif event == "SPELL_CAST_SUCCESS" then
		spell = SUCCESS[spellId]
		if
			spell
			and isEnabled(spell)
			and isHostile(sourceFlags)
			and isWatched(sourceGUID)
			and isCastBy(spell, sourceGUID)
		then
			alert(castSound(spell, sourceGUID), spell.priority, sourceGUID)
		end
	elseif event == "SPELL_AURA_APPLIED" then
		spell = AURA[spellId] or AURA_NAMES[spellName]
		if spell then
			if isEnabled(spell) and isHostile(destFlags) and isWatched(destGUID) and isCastBy(spell, sourceGUID) then
				alert(spell.sound, spell.priority, sourceGUID)
			end
			return
		end
		spell = CONTROL[spellId]
		if spell and isEnabled(spell) and isHostile(sourceFlags) and isCastBy(spell, sourceGUID) then
			onControl(spell, sourceGUID, destGUID)
		end
	elseif event == "SPELL_AURA_REMOVED" then
		spell = AURA[spellId]
		if spell then
			if
				spell.downSound
				and config.defensiveEnd
				and isEnabled(spell)
				and isHostile(destFlags)
				and isWatched(destGUID)
				and isCastBy(spell, sourceGUID)
			then
				alert(spell.downSound, spell.priority, destGUID)
			end
			return
		end
		spell = MY_CONTROL[spellId]
		if spell and config.controlEnd and sourceGUID == playerGUID and isHostile(destFlags) then
			alert(spell.downSound, spell.priority, playerGUID)
		end
	elseif event == "SPELL_INTERRUPT" then
		if config.interrupted and destGUID == playerGUID and isHostile(sourceFlags) then
			alert("interrupted", URGENT, sourceGUID)
		end
	end
end

local function onUnitSpell(_, unit, spellName)
	local spell = CAST_NAMES[spellName]
	if spell and isEnabled(spell) and UnitIsPlayer(unit) and UnitIsEnemy("player", unit) then
		local guid = UnitGUID(unit)
		if isWatched(guid) and isCastBy(spell, guid) then
			alert(spell.sound, spell.priority, guid)
		end
	end
end

local function reset()
	wipe(queue)
	wipe(recent)
end

local function updateZone(self)
	local _, instanceType = IsInInstance()
	zone = ZONES[instanceType]
	playerGUID = UnitGUID("player")
	reset()
	if zone and config.zones[zone] then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", onUnitSpell)
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	end
end

local function applyConfig(self)
	config = ns.Config.spellAlerts
	if config.enabled then
		self:RegisterEvent("PLAYER_ENTERING_WORLD", updateZone)
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA", updateZone)
		updateZone(self)
	else
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		reset()
	end
end

function SpellAlerts:Test()
	reset()
	enqueue("polymorphYou", URGENT)
	enqueue("trinket", 2)
	enqueue("divineShield", 1)
end

function SpellAlerts:Initialize()
	applyConfig(self)
	self:WatchConfig("spellAlerts", applyConfig)
end
