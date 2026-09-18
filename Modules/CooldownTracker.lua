local _, ns = ...

local Data = ns.CooldownData
local SPELLS = Data.SPELLS
local SHARED_COOLDOWNS = Data.SHARED_COOLDOWNS
local RESETS = Data.RESETS
local CDMOD, CDMOD_MULT = Data.CDMOD, Data.CDMOD_MULT
local FORBEARANCE, FORBEARANCE_SPELLS = Data.FORBEARANCE, Data.FORBEARANCE_SPELLS
local TALENT_SWAP = Data.TALENT_SWAP
local SPEC_HINTS = Data.SPEC_HINTS
local RACIALS, PVP_TRINKET = Data.RACIALS, Data.PVP_TRINKET

local DUPLICATE_WINDOW = 2
local FORBEARANCE_DURATION = 120

local bit_band = bit.band
local strsub = string.sub
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitRace = UnitRace
local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET

ns.COOLDOWN_UPDATED = "FrostAtomUI_COOLDOWN_UPDATED"

local CooldownTracker = ns:NewModule("CooldownTracker")
local Talents = ns:GetModule("Talents")

local spellInfo = {}
local baseSpell = {}
local auraSpell = {}

do
	local order = 0
	for _, spells in pairs(SPELLS) do
		for _, entry in ipairs(spells) do
			local id = entry[1]
			order = order + 1
			spellInfo[id] = {
				id = id,
				cooldown = entry[2],
				order = order,
				pet = entry.pet,
				talent = entry.talent == true and id or entry.talent,
				preactive = entry.preactive == true and id or entry.preactive,
				buff = entry.buff and id,
				dynamic = entry.dynamic,
				tree = entry.tree,
				points = entry.points,
			}
			baseSpell[id] = id
			for _, rank in ipairs(entry.ranks or {}) do
				baseSpell[rank] = id
			end
			if entry.preactive then
				auraSpell[spellInfo[id].preactive] = id
			end
			if entry.buff then
				auraSpell[id] = id
			end
		end
	end
end

CooldownTracker.spellInfo = spellInfo

local cooldowns = {}
CooldownTracker.cooldowns = cooldowns

local function getEntries(guid)
	local entries = cooldowns[guid]
	if not entries then
		entries = {}
		cooldowns[guid] = entries
	end
	return entries
end

local function getEntry(guid, id)
	local entries = getEntries(guid)
	local entry = entries[id]
	if not entry then
		entry = {}
		entries[id] = entry
	end
	return entry
end

local function isOnCooldown(entry, now)
	return entry.start ~= nil and entry.start + entry.duration > now
end

local trackedList = {}
function CooldownTracker:GetTracked(unit)
	local _, class = UnitClass(unit)
	local spells = class and SPELLS[class]
	if not spells then
		return
	end

	local guid = UnitGUID(unit)
	local talents = Talents:Get(guid)
	local entries = cooldowns[guid]

	wipe(trackedList)
	for _, entry in ipairs(spells) do
		local id = entry[1]
		local info = spellInfo[id]
		local shown = true
		if info.talent then
			if talents then
				shown = talents[info.talent] ~= nil
			elseif info.tree then
				shown = not Talents:IsExcluded(guid, info.tree, info.points)
			end
		end
		if shown then
			trackedList[#trackedList + 1] = id
		end
	end
	trackedList[#trackedList + 1] = PVP_TRINKET
	local racial = RACIALS[select(2, UnitRace(unit))]
	if racial then
		trackedList[#trackedList + 1] = racial
	end
	for _, entry in ipairs(SPELLS.COMMON) do
		local id = entry[1]
		if entry.dynamic and entries and entries[id] then
			trackedList[#trackedList + 1] = id
		end
	end
	return trackedList
end

function CooldownTracker:GetCooldown(guid, id)
	local entries = guid and cooldowns[guid]
	local entry = entries and entries[id]
	if entry and isOnCooldown(entry, GetTime()) then
		return entry.start, entry.duration
	end
end

function CooldownTracker:IsHighlighted(guid, id)
	local entries = guid and cooldowns[guid]
	local entry = entries and entries[id]
	return entry ~= nil and (entry.active or entry.pending) == true
end

function CooldownTracker:GetDuration(guid, id)
	local duration = spellInfo[id].cooldown
	local talents = Talents:Get(guid)
	if not talents then
		return duration
	end
	local mod = CDMOD[id]
	if mod then
		for i = 1, #mod, 2 do
			if talents[mod[i]] then
				duration = duration - mod[i + 1]
			end
		end
	end
	local mult = CDMOD_MULT[id]
	if mult then
		for i = 1, #mult, 2 do
			if talents[mult[i]] then
				duration = duration * mult[i + 1]
			end
		end
	end
	return duration
end

local function startCooldown(guid, id, duration, now)
	local entry = getEntry(guid, id)
	entry.start = now
	entry.duration = duration
	entry.pending = nil
	entry.forbearance = nil
end

local function clearCooldown(entry)
	entry.start = nil
	entry.duration = nil
	entry.forbearance = nil
end

local function applyResets(guid, id, entries)
	local resets = RESETS[id]
	if not resets then
		return
	end
	if resets.all then
		for other, entry in pairs(entries) do
			if other ~= id then
				clearCooldown(entry)
			end
		end
		return
	end
	for _, other in ipairs(resets) do
		local entry = entries[other]
		if entry then
			clearCooldown(entry)
		end
	end
	if resets.glyph and Talents:Has(guid, resets.glyph) then
		for _, other in ipairs(resets.glyphed) do
			local entry = entries[other]
			if entry then
				clearCooldown(entry)
			end
		end
	end
end

function CooldownTracker:OnCast(guid, id, isDuplicateEvent)
	id = baseSpell[id]
	local info = id and spellInfo[id]
	if not info then
		return
	end

	local now = GetTime()
	local entries = getEntries(guid)
	local current = entries[id]

	if isDuplicateEvent and current then
		local since = current.pending and current.pendingAt or current.start
		if since and now - since < DUPLICATE_WINDOW then
			return
		end
	end

	if info.preactive then
		local entry = getEntry(guid, id)
		clearCooldown(entry)
		entry.pending = true
		entry.pendingAt = now
		ns:Fire(ns.COOLDOWN_UPDATED, guid)
		return true
	end

	startCooldown(guid, id, self:GetDuration(guid, id), now)

	local shared = SHARED_COOLDOWNS[id]
	if shared then
		for i = 1, #shared, 2 do
			local other, duration = shared[i], shared[i + 1]
			local entry = entries[other]
			if not entry or not entry.start or entry.start + entry.duration < now + duration then
				startCooldown(guid, other, duration, now)
			end
		end
	end

	applyResets(guid, id, entries)

	ns:Fire(ns.COOLDOWN_UPDATED, guid)
	return true
end

local function auraToSpell(spellId)
	local base = baseSpell[spellId]
	return auraSpell[spellId] or (base and auraSpell[base])
end

local function onAuraApplied(guid, spellId, destGUID)
	local id = auraToSpell(spellId)
	local info = id and spellInfo[id]
	if not info then
		return
	end
	if info.buff or (info.preactive and guid == destGUID) then
		local entry = getEntry(guid, id)
		if not entry.active then
			entry.active = true
			ns:Fire(ns.COOLDOWN_UPDATED, guid)
		end
	end
end

local function onAuraRemoved(guid, spellId, destGUID)
	local id = auraToSpell(spellId)
	local info = id and spellInfo[id]
	if not info then
		return
	end

	local entries = cooldowns[guid]
	local entry = entries and entries[id]
	if not entry then
		return
	end

	local changed = false
	if entry.active then
		entry.active = nil
		changed = true
	end

	if info.preactive and entry.pending and guid == destGUID then
		startCooldown(guid, id, CooldownTracker:GetDuration(guid, id), GetTime())
		changed = true
	end

	if changed then
		ns:Fire(ns.COOLDOWN_UPDATED, guid)
	end
end

local function onForbearanceApplied(guid)
	local now = GetTime()
	local duration = FORBEARANCE_DURATION
	local unit = ns.UnitByGUID(guid)
	if unit then
		local _, _, _, _, _, auraDuration, expires = ns.FindAura(unit, FORBEARANCE, "HARMFUL")
		if auraDuration and auraDuration > 0 and expires then
			duration = expires - now
		end
	end

	local entries = getEntries(guid)
	for _, id in ipairs(FORBEARANCE_SPELLS) do
		local entry = entries[id]
		if not entry or not entry.start or entry.start + entry.duration < now + duration then
			startCooldown(guid, id, duration, now)
			entries[id].forbearance = true
		end
	end
	ns:Fire(ns.COOLDOWN_UPDATED, guid)
end

local function onForbearanceRemoved(guid)
	local entries = cooldowns[guid]
	if not entries then
		return
	end
	for _, id in ipairs(FORBEARANCE_SPELLS) do
		local entry = entries[id]
		if entry and entry.forbearance then
			clearCooldown(entry)
		end
	end
	ns:Fire(ns.COOLDOWN_UPDATED, guid)
end

function CooldownTracker:Reset(guid)
	if guid then
		cooldowns[guid] = nil
	else
		wipe(cooldowns)
	end
	ns:Fire(ns.COOLDOWN_UPDATED, guid)
end

local OWNER_PETS = {
	player = "pet",
	party1 = "partypet1",
	party2 = "partypet2",
	party3 = "partypet3",
	party4 = "partypet4",
	arena1 = "arenapet1",
	arena2 = "arenapet2",
	arena3 = "arenapet3",
}

local petOwners = {}

local function cachePet(owner)
	local petGUID = UnitGUID(OWNER_PETS[owner])
	if petGUID then
		petOwners[petGUID] = UnitGUID(owner)
	end
end

local function cacheAllPets()
	wipe(petOwners)
	for owner in pairs(OWNER_PETS) do
		cachePet(owner)
	end
end

local function petOwnerGUID(petGUID)
	local owner = petOwners[petGUID]
	if owner then
		return owner
	end
	for unit in pairs(OWNER_PETS) do
		cachePet(unit)
	end
	return petOwners[petGUID]
end

local function onCombatLogEvent(self, _, event, sourceGUID, _, sourceFlags, destGUID, _, _, spellId)
	if event == "SPELL_AURA_APPLIED" and spellId == FORBEARANCE then
		onForbearanceApplied(destGUID)
		return
	elseif event == "SPELL_AURA_REMOVED" and spellId == FORBEARANCE then
		onForbearanceRemoved(destGUID)
		return
	end

	if bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET) ~= 0 then
		local id = baseSpell[spellId]
		if not id or not spellInfo[id].pet then
			return
		end
		sourceGUID = petOwnerGUID(sourceGUID)
		if not sourceGUID then
			return
		end
	elseif bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then
		return
	end

	local hint = strsub(event, 1, 6) == "SPELL_" and SPEC_HINTS[spellId]
	if hint then
		Talents:Observe(sourceGUID, hint.tree, hint.points)
	end

	if event == "SPELL_CAST_SUCCESS" then
		if TALENT_SWAP[spellId] then
			Talents:Invalidate(sourceGUID)
		else
			self:OnCast(sourceGUID, spellId, false)
		end
	elseif event == "SPELL_AURA_APPLIED" then
		self:OnCast(sourceGUID, spellId, true)
		onAuraApplied(sourceGUID, spellId, destGUID)
	elseif event == "SPELL_MISSED" then
		self:OnCast(sourceGUID, spellId, true)
	elseif event == "SPELL_AURA_REMOVED" then
		onAuraRemoved(sourceGUID, spellId, destGUID)
	end
end

function CooldownTracker:PLAYER_ENTERING_WORLD()
	self:Reset()
	cacheAllPets()
end

function CooldownTracker:UNIT_PET(unit)
	if OWNER_PETS[unit] then
		cachePet(unit)
	end
end

function CooldownTracker:Initialize()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", cacheAllPets)
	self:RegisterEvent("ARENA_OPPONENT_UPDATE", cacheAllPets)
end

local TEST_UNITS = { "party1", "party2", "party3", "party4", "arena1", "arena2", "arena3" }
local TEST_SPELLS = 4
local testing = false

SlashCmdList.FROSTATOMUI_COOLDOWN_TEST = function()
	testing = not testing
	if not testing then
		CooldownTracker:Reset()
		return
	end

	for _, unit in ipairs(TEST_UNITS) do
		local guid = UnitGUID(unit)
		local spells = guid and SPELLS[select(2, UnitClass(unit))]
		if spells then
			for i = 1, math.min(TEST_SPELLS, #spells) do
				CooldownTracker:OnCast(guid, spells[i][1])
			end
			CooldownTracker:OnCast(guid, 42292)
		end
	end
end
SLASH_FROSTATOMUI_COOLDOWN_TEST1 = "/cdtest"
