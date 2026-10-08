local _, ns = ...

local Data = {}
ns.LoseControlData = Data

Data.CATEGORIES = {
	"immune",
	"magicImmune",
	"physicalImmune",
	"stun",
	"incapacitate",
	"fear",
	"silence",
	"disarm",
	"root",
}

Data.CATEGORY_NAMES = {
	immune = "Damage immunity",
	magicImmune = "Magic immunity",
	physicalImmune = "Physical immunity",
	stun = "Stuns",
	incapacitate = "Incapacitates",
	fear = "Fears and horrors",
	silence = "Silences",
	disarm = "Disarms",
	root = "Roots",
}

Data.PRIORITY = {
	immune = 7,
	magicImmune = 6,
	physicalImmune = 5,
	stun = 4,
	incapacitate = 4,
	fear = 4,
	silence = 3,
	disarm = 2,
	root = 1,
}

Data.SPELLS = {}
for _, category in ipairs(Data.CATEGORIES) do
	Data.SPELLS[category] = {}
end
for _, effect in ns.SpellDB.IterateEffects() do
	local list = effect.control and Data.SPELLS[effect.control]
	if list then
		list[#list + 1] = effect
	end
end

local byId = {}
for category, spells in pairs(Data.SPELLS) do
	for _, spell in ipairs(spells) do
		spell.category = category
		for i = 1, #spell do
			byId[spell[i]] = spell
		end
	end
end
Data.BY_ID = byId
Data.CONTROL_NAMES = ns.SpellDB.ControlNames()
