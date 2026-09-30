local _, ns = ...

local UnitAura = UnitAura
local UnitGUID = UnitGUID
local GetTime = GetTime
local abs = math.abs

local MAX_AURAS = 40
local DURATION_TOLERANCE = 0.2

local Auras = ns.Mixin({}, ns.EventMixin)
ns.Auras = Auras

local cache = {}

local function observe(set, aura, now)
	local expires = aura.expires
	if expires == 0 then
		return
	end
	local scanId = set.scanId
	local timings = set.timings
	local spellId = aura.spellId
	local timing = timings[spellId]
	if timing and timing.scanId == scanId then
		return
	end
	local present = timing and timing.scanId == scanId - 1
	if not timing then
		timing = {}
		timings[spellId] = timing
	end
	timing.scanId = scanId
	if present and timing.expires == expires then
		aura.duration = timing.duration
		return
	end

	local duration = aura.duration
	local start
	if set.baseline then
		start = expires - duration
	elseif present and expires < timing.expires then
		start = timing.start
	else
		start = now
	end
	if duration > 0 and abs(expires - start - duration) <= DURATION_TOLERANCE then
		start = expires - duration
	else
		duration = expires - start
	end
	timing.expires, timing.start, timing.duration = expires, start, duration
	aura.duration = duration
end

local function scan(set)
	local unit, filter = set.unit, set.filter
	local timings = set.timings
	local now = timings and GetTime()
	if timings then
		set.scanId = set.scanId + 1
	end
	local n = 0
	for i = 1, MAX_AURAS do
		local name, _, icon, count, debuffType, duration, expires, caster, stealable, _, spellId =
			UnitAura(unit, i, filter)
		if not name then
			break
		end
		n = i
		local aura = set[i]
		if not aura then
			aura = {}
			set[i] = aura
		end
		aura.name = name
		aura.icon = icon
		aura.count = count
		aura.debuffType = debuffType
		aura.duration = duration
		aura.expires = expires
		aura.caster = caster
		aura.stealable = stealable
		aura.spellId = spellId
		if timings then
			observe(set, aura, now)
		end
	end
	set.n = n
	set.dirty = false
	set.baseline = false
end

function Auras.Get(unit, filter)
	local byFilter = cache[unit]
	if not byFilter then
		byFilter = {}
		cache[unit] = byFilter
	end
	local set = byFilter[filter]
	if not set then
		set = { unit = unit, filter = filter, n = 0, dirty = true }
		if unit == "player" then
			set.timings, set.scanId, set.baseline = {}, 0, true
		end
		byFilter[filter] = set
	end

	local guid = UnitGUID(unit)
	if set.dirty or set.guid ~= guid then
		set.guid = guid
		scan(set)
	end
	return set, set.n
end

function Auras.Find(unit, spellId, filter)
	local set, n = Auras.Get(unit, filter)
	for i = 1, n do
		local aura = set[i]
		if aura.spellId == spellId then
			return aura
		end
	end
end

function Auras.Invalidate(unit)
	local byFilter = cache[unit]
	if byFilter then
		for _, set in pairs(byFilter) do
			set.dirty = true
		end
	end
end

Auras:RegisterEvent("UNIT_AURA", function(_, unit)
	Auras.Invalidate(unit)
	if unit == "player" and cache.player then
		for _, set in pairs(cache.player) do
			scan(set)
		end
	end
end)

Auras:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local byFilter = cache.player
	if byFilter then
		for _, set in pairs(byFilter) do
			wipe(set.timings)
			set.baseline = true
			scan(set)
		end
	end
end)

local CAST_IMMUNITY = {
	[642] = true, -- Divine Shield
	[45438] = true, -- Ice Block
	[31224] = true, -- Cloak of Shadows
	[54748] = true, -- Burning Determination
}
local AURA_MASTERY = 31821
local CONCENTRATION_AURA = 19746

function ns.HasCastImmunity(unit)
	local set, n = Auras.Get(unit, "HELPFUL")
	local mastery, concentration = false, false
	for i = 1, n do
		local spellId = set[i].spellId
		if CAST_IMMUNITY[spellId] then
			return true
		elseif spellId == AURA_MASTERY then
			mastery = true
		elseif spellId == CONCENTRATION_AURA then
			concentration = true
		end
	end
	return mastery and concentration
end
