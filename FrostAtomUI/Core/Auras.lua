local _, ns = ...

local UnitAura = UnitAura
local UnitGUID = UnitGUID

local MAX_AURAS = 40

local Auras = ns.Mixin({}, ns.EventMixin)
ns.Auras = Auras

local cache = {}

local function scan(set)
	local unit, filter = set.unit, set.filter
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
	end
	set.n = n
	set.dirty = false
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
end)
