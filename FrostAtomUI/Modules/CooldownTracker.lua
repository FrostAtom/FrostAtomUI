local _, ns = ...

local Data = ns.CooldownData
local SPELLS = Data.SPELLS
local SHARED_COOLDOWNS = Data.SHARED_COOLDOWNS
local RESETS = Data.RESETS
local CDMOD, CDMOD_MULT = Data.CDMOD, Data.CDMOD_MULT
local FORBEARANCE, FORBEARANCE_SPELLS = Data.FORBEARANCE, Data.FORBEARANCE_SPELLS
local TALENT_SWAP = Data.TALENT_SWAP
local SPEC_HINTS, MOD_TALENTS = Data.SPEC_HINTS, Data.MOD_TALENTS
local RACIALS, PVP_TRINKET = Data.RACIALS, Data.PVP_TRINKET

local DUPLICATE_WINDOW = 2
local FORBEARANCE_DURATION = 120

local bit_band = bit.band
local strsub = string.sub
local min = math.min
local max = math.max
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitRace = UnitRace
local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET

local CooldownTracker = ns:NewModule("CooldownTracker")
ns.Mixin(CooldownTracker, ns.Demand)
local Talents = ns:GetModule("Talents")

local spellInfo = {}
local baseSpell = {}
local auraSpell = {}

for _, spells in pairs(SPELLS) do
	for i = 1, #spells do
		local entry = spells[i]
		local id = entry[1]
		local preactive = entry.preactive == true and id or entry.preactive
		spellInfo[id] = {
			cooldown = entry[2],
			pet = entry.pet,
			talent = entry.talent == true and id or entry.talent,
			preactive = preactive,
			buff = entry.buff and id,
			dynamic = entry.dynamic,
			category = entry.cat,
			hidden = entry.hide,
			icon = entry.icon,
		}
		baseSpell[id] = id
		local ranks = entry.ranks
		if ranks then
			for j = 1, #ranks do
				baseSpell[ranks[j]] = id
			end
		end
		if preactive then
			auraSpell[preactive] = id
		end
		if entry.buff then
			auraSpell[id] = id
		end
	end
end

local cooldowns = {}

local function getEntries(guid)
	local entries = cooldowns[guid]
	if not entries then
		entries = {}
		cooldowns[guid] = entries
	end
	return entries
end

local function getEntry(entries, id)
	local entry = entries[id]
	if not entry then
		entry = {}
		entries[id] = entry
	end
	return entry
end

local function endsBefore(entry, endTime)
	return not entry or not entry.start or entry.start + entry.duration < endTime
end

local function hasTalent(guid, id, info, talents, entries, strict)
	if not info.talent then
		return true
	elseif talents then
		return talents[info.talent] ~= nil
	end
	local hint = SPEC_HINTS[id]
	if not hint then
		return true
	elseif strict then
		return (entries and entries[id]) ~= nil or Talents:GetProven(guid, hint.tree) > hint.points
	end
	return not Talents:IsExcluded(guid, hint)
end

local trackedList = {}
function CooldownTracker:GetTrackedFor(guid, class, race, strict, out)
	local spells = class and SPELLS[class]
	if not spells then
		return
	end

	local talents = guid and Talents:Get(guid)
	local entries = guid and cooldowns[guid]

	local list = out or trackedList
	wipe(list)
	for i = 1, #spells do
		local id = spells[i][1]
		if hasTalent(guid, id, spellInfo[id], talents, entries, strict) then
			list[#list + 1] = id
		end
	end
	list[#list + 1] = PVP_TRINKET
	local racial = RACIALS[race]
	if racial then
		list[#list + 1] = racial
	end
	if entries then
		local common = SPELLS.COMMON
		for i = 1, #common do
			local entry = common[i]
			local id = entry[1]
			if entry.dynamic and entries[id] then
				list[#list + 1] = id
			end
		end
	end
	return list
end

function CooldownTracker:GetTracked(unit)
	local _, class = UnitClass(unit)
	local _, race = UnitRace(unit)
	return self:GetTrackedFor(UnitGUID(unit), class, race)
end

ns.API.RegisterAction("cooldownInfo", function(id)
	return CooldownTracker:GetInfo(id)
end)

function CooldownTracker:GetInfo(id)
	return spellInfo[id]
end

function CooldownTracker:GetCooldown(guid, id)
	local entries = guid and cooldowns[guid]
	local entry = entries and entries[id]
	if entry and entry.start and entry.start + entry.duration > GetTime() then
		return entry.start, entry.duration
	end
end

function CooldownTracker:IsHighlighted(guid, id)
	local entries = guid and cooldowns[guid]
	local entry = entries and entries[id]
	return entry ~= nil and (entry.active or entry.pending) == true
end

local function hasModifier(guid, talents, id)
	if talents then
		return talents[id]
	end
	local talent = MOD_TALENTS[id]
	if not talent then
		return true, true
	end
	local reachable = Talents:GetReachableRanks(guid, talent.tree, talent.points)
	return talent.rank <= reachable and (talent.rank == talent.maxRank or talent.rank + 1 > reachable)
end

function CooldownTracker:GetDuration(guid, id)
	local duration = spellInfo[id].cooldown
	local longest = duration
	local talents = Talents:Get(guid)
	local assumed = false
	local mod = CDMOD[id]
	if mod then
		for i = 1, #mod, 2 do
			local has, guessed = hasModifier(guid, talents, mod[i])
			if has and (not guessed or mod[i + 1] > 0) then
				duration = duration - mod[i + 1]
				assumed = assumed or guessed or false
			end
			if has and not guessed then
				longest = longest - mod[i + 1]
			end
		end
	end
	local mult = CDMOD_MULT[id]
	if mult then
		for i = 1, #mult, 2 do
			local has, guessed = hasModifier(guid, talents, mult[i])
			if has and (not guessed or mult[i + 1] < 1) then
				duration = duration * mult[i + 1]
				assumed = assumed or guessed or false
			end
			if has and not guessed then
				longest = longest * mult[i + 1]
			end
		end
	end
	duration = duration > 0 and duration or 0
	return duration, assumed, assumed and max(longest, duration) or duration
end

function CooldownTracker:GetMaybeReady(guid, id)
	local entries = guid and cooldowns[guid]
	local entry = entries and entries[id]
	if not (entry and entry.assumed and entry.start and entry.longest) then
		return
	end
	local readyAt, lastReady = entry.start + entry.duration, entry.start + entry.longest
	local now = GetTime()
	if now >= readyAt and now < lastReady then
		return lastReady
	end
end

local function startCooldown(entries, id, duration, now)
	local entry = getEntry(entries, id)
	entry.start = now
	entry.duration = duration
	entry.pending = nil
	entry.forbearance = nil
	entry.assumed, entry.longest = nil, nil
	return entry
end

local function clearCooldown(entry)
	entry.start = nil
	entry.duration = nil
	entry.forbearance = nil
	entry.assumed, entry.longest = nil, nil
end

local function clearCooldowns(entries, ids)
	for i = 1, #ids do
		local entry = entries[ids[i]]
		if entry then
			clearCooldown(entry)
		end
	end
end

local function applyResets(guid, id, entries)
	local resets = RESETS[id]
	if not resets then
		return
	end
	clearCooldowns(entries, resets)
	if resets.glyph and Talents:Has(guid, resets.glyph) then
		clearCooldowns(entries, resets.glyphed)
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
		local entry = getEntry(entries, id)
		clearCooldown(entry)
		entry.pending = true
		entry.pendingAt = now
		ns:Fire(ns.E.COOLDOWN_UPDATED, guid)
		return true
	end

	local duration, assumed, longest = self:GetDuration(guid, id)
	local entry = startCooldown(entries, id, duration, now)
	entry.assumed = assumed or nil
	entry.longest = assumed and longest or nil

	local shared = SHARED_COOLDOWNS[id]
	if shared then
		for i = 1, #shared, 2 do
			local other, duration = shared[i], shared[i + 1]
			if endsBefore(entries[other], now + duration) then
				startCooldown(entries, other, duration, now)
			end
		end
	end

	applyResets(guid, id, entries)

	ns:Fire(ns.E.COOLDOWN_UPDATED, guid)
	return true
end

local function auraToSpell(spellId)
	local base = baseSpell[spellId]
	return auraSpell[spellId] or (base and auraSpell[base])
end

function CooldownTracker:AuraCategory(spellId)
	local id = auraToSpell(spellId)
	local info = id and spellInfo[id]
	return info and info.category
end

local function onAuraApplied(guid, spellId, destGUID)
	local id = auraToSpell(spellId)
	local info = id and spellInfo[id]
	if not info then
		return
	end
	if info.buff or (info.preactive and guid == destGUID) then
		local entry = getEntry(getEntries(guid), id)
		if not entry.active then
			entry.active = true
			ns:Fire(ns.E.COOLDOWN_UPDATED, guid)
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
		startCooldown(entries, id, CooldownTracker:GetDuration(guid, id), GetTime())
		changed = true
	end

	if changed then
		ns:Fire(ns.E.COOLDOWN_UPDATED, guid)
	end
end

local function onForbearanceApplied(guid)
	local now = GetTime()
	local duration = FORBEARANCE_DURATION
	local unit = ns.UnitByGUID(guid)
	if unit then
		ns.Auras.Invalidate(unit)
		local aura = ns.Auras.Find(unit, FORBEARANCE, "HARMFUL")
		if aura and aura.duration and aura.duration > 0 and aura.expires then
			duration = aura.expires - now
		end
	end

	local entries = getEntries(guid)
	local endTime = now + duration
	for i = 1, #FORBEARANCE_SPELLS do
		local id = FORBEARANCE_SPELLS[i]
		if endsBefore(entries[id], endTime) then
			startCooldown(entries, id, duration, now).forbearance = true
		end
	end
	ns:Fire(ns.E.COOLDOWN_UPDATED, guid)
end

local function onForbearanceRemoved(guid)
	local entries = cooldowns[guid]
	if not entries then
		return
	end
	for i = 1, #FORBEARANCE_SPELLS do
		local entry = entries[FORBEARANCE_SPELLS[i]]
		if entry and entry.forbearance then
			clearCooldown(entry)
		end
	end
	ns:Fire(ns.E.COOLDOWN_UPDATED, guid)
end

function CooldownTracker:Reset(guid)
	if guid then
		cooldowns[guid] = nil
	else
		wipe(cooldowns)
	end
	ns:Fire(ns.E.COOLDOWN_UPDATED, guid)
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
	arena4 = "arenapet4",
	arena5 = "arenapet5",
}

local petOwners = {}

local function cachePetOwner(owner)
	local petGUID = UnitGUID(OWNER_PETS[owner])
	if petGUID then
		petOwners[petGUID] = UnitGUID(owner)
	end
end

local function cachePetOwners()
	for owner in pairs(OWNER_PETS) do
		cachePetOwner(owner)
	end
end

local function rebuildPetOwners()
	wipe(petOwners)
	cachePetOwners()
end

local function petOwnerGUID(petGUID)
	local owner = petOwners[petGUID]
	if owner ~= nil then
		return owner or nil
	end
	cachePetOwners()
	owner = petOwners[petGUID]
	if not owner then
		petOwners[petGUID] = false
	end
	return owner
end

local SUBEVENT_HANDLERS = {
	SPELL_CAST_SUCCESS = function(self, sourceGUID, spellId)
		if TALENT_SWAP[spellId] then
			Talents:Invalidate(sourceGUID)
		else
			self:OnCast(sourceGUID, spellId, false)
		end
	end,
	SPELL_AURA_APPLIED = function(self, sourceGUID, spellId, destGUID)
		self:OnCast(sourceGUID, spellId, true)
		onAuraApplied(sourceGUID, spellId, destGUID)
	end,
	SPELL_MISSED = function(self, sourceGUID, spellId)
		self:OnCast(sourceGUID, spellId, true)
	end,
	SPELL_AURA_REMOVED = function(_, sourceGUID, spellId, destGUID)
		onAuraRemoved(sourceGUID, spellId, destGUID)
	end,
}

local function onCombatLogEvent(self, _, event, sourceGUID, _, sourceFlags, destGUID, _, _, spellId)
	local handler = SUBEVENT_HANDLERS[event]
	local hint = SPEC_HINTS[spellId]
	if not handler and not hint then
		return
	end

	if spellId == FORBEARANCE then
		if event == "SPELL_AURA_APPLIED" then
			onForbearanceApplied(destGUID)
			return
		elseif event == "SPELL_AURA_REMOVED" then
			onForbearanceRemoved(destGUID)
			return
		end
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

	if hint and event ~= "SPELL_AURA_BROKEN_SPELL" and strsub(event, 1, 6) == "SPELL_" then
		Talents:Observe(sourceGUID, hint)
	end

	if handler then
		handler(self, sourceGUID, spellId, destGUID)
	end
end

function CooldownTracker:PLAYER_ENTERING_WORLD()
	self:Reset()
	rebuildPetOwners()
end

function CooldownTracker:UNIT_PET(unit)
	if OWNER_PETS[unit] then
		cachePetOwner(unit)
	end
end

function CooldownTracker:OnDemandStart()
	ns.CombatLog.Register(self, ns.CombatLog.ALL, onCombatLogEvent)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", rebuildPetOwners)
	self:RegisterEvent("ARENA_OPPONENT_UPDATE", rebuildPetOwners)
	rebuildPetOwners()
end

function CooldownTracker:OnDemandStop()
	ns.CombatLog.Unregister(self, onCombatLogEvent)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("UNIT_PET")
	self:UnregisterEvent("PARTY_MEMBERS_CHANGED")
	self:UnregisterEvent("ARENA_OPPONENT_UPDATE")
	self:Reset()
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

	for i = 1, #TEST_UNITS do
		local unit = TEST_UNITS[i]
		local guid = UnitGUID(unit)
		local _, class = UnitClass(unit)
		local spells = guid and SPELLS[class]
		if spells then
			for j = 1, min(TEST_SPELLS, #spells) do
				CooldownTracker:OnCast(guid, spells[j][1])
			end
			CooldownTracker:OnCast(guid, PVP_TRINKET)
		end
	end
end
SLASH_FROSTATOMUI_COOLDOWN_TEST1 = "/cdtest"
