local _, ns = ...

local GetSpellInfo = GetSpellInfo

local SpellDB = {}
ns.SpellDB = SpellDB

local IMMUNITIES = { immune = true, magicImmune = true, physicalImmune = true }

local effects = ns.Effects
local effectOf = {}
for _, effect in ipairs(effects) do
	for i = 1, #effect do
		effectOf[effect[i]] = effect
	end
end

function SpellDB.Effect(spellId)
	return effectOf[spellId]
end

function SpellDB.IterateEffects()
	return ipairs(effects)
end

function SpellDB.DR(spellId)
	local effect = effectOf[spellId]
	if effect then
		return effect.drs and effect.drs[spellId] or effect.dr
	end
end

function SpellDB.Control(spellId)
	local effect = effectOf[spellId]
	return effect and effect.control
end

function SpellDB.Duration(spellId)
	local effect = effectOf[spellId]
	if effect then
		return effect.durations and effect.durations[spellId] or effect.duration
	end
end

local controlNames, locByName

local function indexNames()
	controlNames, locByName = {}, {}
	for _, effect in ipairs(effects) do
		local name = not effect.byId and GetSpellInfo(effect[1])
		if name then
			if effect.loc and not locByName[name] then
				locByName[name] = effect.loc
			end
			if effect.control and not IMMUNITIES[effect.control] then
				controlNames[name] = true
			end
		end
	end
end

function SpellDB.IsCCName(name)
	if not controlNames then
		indexNames()
	end
	return name ~= nil and controlNames[name] == true
end

function SpellDB.ControlNames()
	if not controlNames then
		indexNames()
	end
	return controlNames
end

function SpellDB.LossOfControl(spellId, name)
	local effect = effectOf[spellId]
	if effect and effect.loc then
		return effect.loc
	end
	if not locByName then
		indexNames()
	end
	return name and locByName[name]
end

function SpellDB.DRSpells()
	local spells = {}
	for id in pairs(effectOf) do
		spells[id] = SpellDB.DR(id)
	end
	return spells
end

local lockouts

function SpellDB.Lockout(spellId)
	if not lockouts then
		local abilities = ns.CooldownData
		lockouts = {}
		for spell, seconds in pairs(abilities.INTERRUPT_EFFECTS) do
			lockouts[spell] = seconds
		end
		for _, list in pairs(abilities.SPELLS) do
			for _, ability in ipairs(list) do
				if ability.lockout then
					lockouts[ability[1]] = ability.lockout
					for _, rank in ipairs(ability.ranks or {}) do
						lockouts[rank] = ability.lockouts and ability.lockouts[rank] or ability.lockout
					end
				end
			end
		end
	end
	return lockouts[spellId]
end
