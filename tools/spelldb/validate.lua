local ROOT = arg[1] or "."
local A = ROOT .. "/FrostAtomUI/"
local NAMES = dofile(ROOT .. "/tools/spelldb/names.lua")
local GITHUB = os.getenv("GITHUB_ACTIONS") == "true"

local errors, warnings = 0, 0

local function report(kind, file, message)
	if kind == "error" then
		errors = errors + 1
	else
		warnings = warnings + 1
	end
	if GITHUB then
		print(("::%s file=FrostAtomUI/%s::%s"):format(kind, file, message))
	else
		print(("%s: FrostAtomUI/%s: %s"):format(kind, file, message))
	end
end

local function nm(id)
	return NAMES[id] or ("#" .. tostring(id))
end

local env = setmetatable({}, { __index = _G })
env.GetSpellInfo = function(id)
	if type(id) == "number" then
		return NAMES[id], "", "Interface\\Icons\\" .. id
	end
end
env.UnitClass = function()
	return "Mage", "MAGE"
end
env.GetLocale = function()
	return "enUS"
end
env.CreateFrame = function()
	return setmetatable({}, {
		__index = function()
			return function() end
		end,
	})
end

local ns = { modules = {} }
function ns:NewModule(name)
	local module = {}
	self.modules[name] = module
	return module
end
function ns:GetModule(name)
	return self.modules[name] or self:NewModule(name)
end
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})

local function load(rel)
	local chunk = assert(loadfile(A .. rel))
	setfenv(chunk, env)
	chunk("FrostAtomUI", ns)
end

local function read(rel)
	local f = assert(io.open(A .. rel, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

load("Data/Effects.lua")
load("Core/SpellDB.lua")
load("Modules/DRData.lua")
load("Modules/LoseControlData.lua")
load("Data/Abilities.lua")
load("Modules/SpellAlertData.lua")

local EFFECTS = "Data/Effects.lua"
local DR_OF_CONTROL = {
	stun = { stun = true, openingstun = true, randomstun = true, charge = true },
	root = { root = true, randomroot = true, entrapment = true },
	incapacitate = {
		disorient = true,
		cyclone = true,
		sleep = true,
		scatter = true,
		dragonsbreath = true,
		mindcontrol = true,
		banish = true,
	},
	fear = { fear = true, horror = true },
	silence = { silence = true },
	disarm = { disarm = true },
}
local IMMUNITIES = { immune = true, magicImmune = true, physicalImmune = true }
local MECHANIC_DR = {
	[2094] = "Blind shares the fear DR group in TrinityCore 3.3.5",
	[53148] = "TrinityCore takes the DR group from the stun mechanic, the aura only roots",
	[31367] = "TrinityCore takes the DR group from the stun mechanic, the aura only roots",
	[31368] = "TrinityCore takes the DR group from the stun mechanic, the aura only roots",
}
local NO_DR = {
	[13099] = "Net-o-Matic: the root has no DR mechanic",
	[55536] = "Frostweave Net: the root has no DR mechanic",
	[39965] = "Frost Grenade: the root has no DR mechanic",
}

local seen = {}
for _, effect in ipairs(ns.Effects) do
	local first = effect[1]
	for i = 1, #effect do
		local id = effect[i]
		if seen[id] then
			report("error", EFFECTS, ("%d %s is listed in two effects"):format(id, nm(id)))
		end
		seen[id] = true
		if not NAMES[id] then
			report("warning", EFFECTS, ("%d has no name in tools/spelldb/names.lua"):format(id))
		end
	end
	local control = effect.control
	if control and not IMMUNITIES[control] then
		for i = 1, #effect do
			local id = effect[i]
			local dr = ns.SpellDB.DR(id)
			if dr == nil and not NO_DR[first] then
				report("error", EFFECTS, ("%d %s is %s control without a DR group"):format(id, nm(id), control))
			elseif dr and not DR_OF_CONTROL[control][dr] and not MECHANIC_DR[id] then
				report("error", EFFECTS, ("%d %s: control %s does not fit DR group %s"):format(id, nm(id), control, dr))
			end
		end
	end
	local function checkDuration(id, value)
		if value and (value <= 0 or value > 10) then
			report("error", EFFECTS, ("%d %s: duration %s is outside (0, 10]"):format(id, nm(id), tostring(value)))
		end
	end
	checkDuration(first, effect.duration)
	for id, value in pairs(effect.durations or {}) do
		checkDuration(id, value)
	end
end

local cc = {}
for _, effect in ipairs(ns.Effects) do
	if effect.control and not IMMUNITIES[effect.control] or effect.dr then
		for i = 1, #effect do
			cc[effect[i]] = effect
		end
	end
end
local nameOwner = {}
local auraData = read("Modules/NamePlates/AuraData.lua")
for _, tableName in ipairs({ "DEBUFF_DURATIONS", "DEFENSIVE_DURATIONS", "PURGE_DURATIONS" }) do
	for id in auraData:match("local " .. tableName .. " = (%b{})"):gmatch("%[(%d+)%]") do
		id = tonumber(id)
		if not cc[id] and NAMES[id] then
			nameOwner[NAMES[id]] = nameOwner[NAMES[id]] or id
		end
	end
end
for _, effect in ipairs(ns.Effects) do
	local name = NAMES[effect[1]]
	if cc[effect[1]] and not effect.byId and name and nameOwner[name] then
		report(
			"error",
			EFFECTS,
			("%d %s shares its name with non-control spell %d: match it by id (byId = true)"):format(
				effect[1],
				name,
				nameOwner[name]
			)
		)
	end
end

local CD = ns.CooldownData
local CD_FILE = "Data/Abilities.lua"
local abilities = {}
for _, list in pairs(CD.SPELLS) do
	for _, entry in ipairs(list) do
		abilities[entry[1]] = entry
	end
end
for id, mods in pairs(CD.CDMOD) do
	local entry = abilities[id]
	if not entry then
		report("error", CD_FILE, ("CDMOD for unknown ability %d %s"):format(id, nm(id)))
	else
		local best = {}
		for i = 1, #mods, 2 do
			local talent = CD.MOD_TALENTS[mods[i]]
			local key = talent and (talent.tree .. "/" .. talent.points) or mods[i]
			best[key] = math.max(best[key] or -math.huge, mods[i + 1])
		end
		local reduce = 0
		for _, value in pairs(best) do
			reduce = reduce + math.max(value, 0)
		end
		local mult = 1
		local multipliers = CD.CDMOD_MULT[id]
		if multipliers then
			local least = {}
			for i = 1, #multipliers, 2 do
				least[multipliers[i]] = math.min(least[multipliers[i]] or 1, multipliers[i + 1])
			end
			for _, value in pairs(least) do
				mult = mult * value
			end
		end
		local shortest = (entry[2] - reduce) * mult
		if shortest <= 0 then
			report("error", CD_FILE, ("%d %s: cooldown after all modifiers is %.1f s"):format(id, nm(id), shortest))
		end
	end
end
for id, shared in pairs(CD.SHARED_COOLDOWNS) do
	for i = 1, #shared, 2 do
		local other = shared[i]
		if not abilities[other] then
			report("error", CD_FILE, ("%d shares a cooldown with unknown ability %d"):format(id, other))
		end
		local back = CD.SHARED_COOLDOWNS[other]
		local found = false
		for j = 1, back and #back or 0, 2 do
			found = found or back[j] == id
		end
		if not found then
			report("error", CD_FILE, ("shared cooldown %d -> %d has no way back"):format(id, other))
		end
	end
end
for id, targets in pairs(CD.RESETS) do
	for _, target in ipairs(targets) do
		if not abilities[target] then
			report("error", CD_FILE, ("%d resets unknown ability %d"):format(id, target))
		end
	end
end

local SA = ns.SpellAlertData
local SA_FILE = "Modules/SpellAlertData.lua"
local keys = { interrupted = true }
for _, list in pairs(SA.SPELLS) do
	for _, spell in ipairs(list) do
		for _, field in ipairs({ "sound", "youSound", "downSound" }) do
			if spell[field] then
				keys[spell[field]] = true
			end
		end
	end
end
for _, class in pairs(SA.CLASS_SOUNDS) do
	keys["trinket" .. class] = true
end
for key in pairs(keys) do
	if not SA.LENGTHS[key] then
		report("error", SA_FILE, ("voice %q has no length"):format(key))
	end
	local f = io.open(A .. "Media/Voice/" .. key .. ".wav", "rb")
	if f then
		f:close()
	else
		report("error", SA_FILE, ("voice %q has no wav file"):format(key))
	end
end
for key in pairs(SA.LENGTHS) do
	if not keys[key] then
		report("warning", SA_FILE, ("length for voice %q that no alert uses"):format(key))
	end
end

for id, entry in pairs(abilities) do
	local seconds = entry.lockout
	if seconds and (entry.cat ~= "interrupt" or seconds > 8) then
		report(
			"error",
			CD_FILE,
			("%d %s: lockout %s s on a non-interrupt or longer than 8 s"):format(id, nm(id), seconds)
		)
	end
	local ranks = {}
	for _, rank in ipairs(entry.ranks or {}) do
		ranks[rank] = true
	end
	for rank, value in pairs(entry.lockouts or {}) do
		if value > 8 or not ranks[rank] then
			report("error", CD_FILE, ("%d %s: bad lockout %s s for rank %d"):format(id, nm(id), value, rank))
		end
	end
end
for id, seconds in pairs(CD.INTERRUPT_EFFECTS) do
	if seconds > 8 then
		report("error", CD_FILE, ("interrupt effect %d %s lasts %s s"):format(id, nm(id), seconds))
	end
end

print(("spelldb: %d effects, %d abilities, %d errors, %d warnings"):format(
	#ns.Effects,
	(function()
		local n = 0
		for _ in pairs(abilities) do
			n = n + 1
		end
		return n
	end)(),
	errors,
	warnings
))
os.exit(errors == 0 and 0 or 1)
