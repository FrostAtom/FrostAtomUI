local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local GetSpellInfo = GetSpellInfo

local CC_DURATIONS = {}
for _, effect in ns.SpellDB.IterateEffects() do
	for i = 1, #effect do
		CC_DURATIONS[effect[i]] = ns.SpellDB.Duration(effect[i])
	end
end

local DEBUFF_DURATIONS = {
	[1715] = 10, -- Hamstring
	[12323] = 6, -- Piercing Howl
	[3409] = 10, -- Crippling Poison
	[26679] = 6, -- Deadly Throw
	[116] = 9, -- Frostbolt
	[120] = 8, -- Cone of Cold
	[31589] = 15, -- Slow
	[11113] = 6, -- Blast Wave
	[44614] = 9, -- Frostfire Bolt
	[5116] = 4, -- Concussive Shot
	[2974] = 10, -- Wing Clip
	[45524] = 10, -- Chains of Ice
	[8056] = 8, -- Frost Shock
	[58180] = 12, -- Infected Wounds
	[18223] = 12, -- Curse of Exhaustion
	[12294] = 10, -- Mortal Strike
	[13218] = 15, -- Wound Poison
	[19434] = 10, -- Aimed Shot
	[772] = 15, -- Rend
	[30108] = 15, -- Unstable Affliction
	[172] = 18, -- Corruption
	[348] = 15, -- Immolate
	[980] = 24, -- Curse of Agony
	[1714] = 12, -- Curse of Tongues
	[48181] = 12, -- Haunt
	[589] = 18, -- Shadow Word: Pain
	[34914] = 15, -- Vampiric Touch
	[2944] = 24, -- Devouring Plague
	[8050] = 18, -- Flame Shock
	[8921] = 12, -- Moonfire
	[5570] = 12, -- Insect Swarm
	[1978] = 15, -- Serpent Sting
	[3034] = 8, -- Viper Sting
	[703] = 18, -- Garrote
	[1822] = 9, -- Rake
	[44457] = 12, -- Living Bomb
	[55095] = 15, -- Frost Fever
	[55078] = 15, -- Blood Plague
}

local DEFENSIVE_DURATIONS = {
	[642] = 12, -- Divine Shield
	[498] = 12, -- Divine Protection
	[1022] = 10, -- Hand of Protection
	[1044] = 6, -- Hand of Freedom
	[6940] = 12, -- Hand of Sacrifice
	[64205] = 10, -- Divine Sacrifice
	[31821] = 6, -- Aura Mastery
	[45438] = 10, -- Ice Block
	[31224] = 5, -- Cloak of Shadows
	[5277] = 15, -- Evasion
	[51713] = 6, -- Shadow Dance
	[48707] = 5, -- Anti-Magic Shell
	[48792] = 12, -- Icebound Fortitude
	[49039] = 10, -- Lichborne
	[46924] = 6, -- Bladestorm
	[871] = 12, -- Shield Wall
	[23920] = 5, -- Spell Reflection
	[12975] = 20, -- Last Stand
	[18499] = 10, -- Berserker Rage
	[55694] = 10, -- Enraged Regeneration
	[20230] = 12, -- Retaliation
	[19263] = 5, -- Deterrence
	[34471] = 10, -- The Beast Within
	[54216] = 4, -- Master's Call
	[33206] = 8, -- Pain Suppression
	[47788] = 10, -- Guardian Spirit
	[47585] = 6, -- Dispersion
	[22812] = 12, -- Barkskin
	[61336] = 20, -- Survival Instincts
	[30823] = 15, -- Shamanistic Rage
	[54748] = 20, -- Burning Determination
}

local PURGE_DURATIONS = {
	[17] = 30, -- Power Word: Shield
	[11426] = 60, -- Ice Barrier
	[29166] = 10, -- Innervate
	[10060] = 15, -- Power Infusion
	[6346] = 180, -- Fear Ward
	[54428] = 15, -- Divine Plea
	[12042] = 15, -- Arcane Power
	[12472] = 20, -- Icy Veins
	[31884] = 20, -- Avenging Wrath
	[2825] = 40, -- Bloodlust
	[32182] = 40, -- Heroism
	[139] = 15, -- Renew
	[774] = 15, -- Rejuvenation
	[8936] = 21, -- Regrowth
	[33763] = 7, -- Lifebloom
	[61295] = 15, -- Riptide
	[16188] = 0, -- Nature's Swiftness
	[17116] = 0, -- Nature's Swiftness
	[12043] = 0, -- Presence of Mind
}

local KIND_OWN_CC, KIND_CC, KIND_DEFENSIVE, KIND_OWN, KIND_PURGE, KIND_OTHER = 1, 2, 3, 4, 5, 6
local PURGE_MAX_DURATION = 60

local Data = {
	KIND_OWN_CC = KIND_OWN_CC,
	KIND_CC = KIND_CC,
	KIND_DEFENSIVE = KIND_DEFENSIVE,
	KIND_OWN = KIND_OWN,
	KIND_PURGE = KIND_PURGE,
	KIND_OTHER = KIND_OTHER,
}
NamePlates.AuraData = Data

local durations, durationsByName = {}, {}
local ccSpells, ccNames = {}, {}
local debuffSpells, debuffNames = {}, {}
local defensiveSpells, defensiveNames = {}, {}
local purgeSpells, purgeNames = {}, {}

local function index(source, spells, names)
	for spellId, duration in pairs(source) do
		spells[spellId] = true
		durations[spellId] = duration > 0 and duration or nil
		local name = GetSpellInfo(spellId)
		if name then
			names[name] = true
			if duration > 0 then
				durationsByName[name] = duration
			end
		end
	end
end

index(CC_DURATIONS, ccSpells, ccNames)
index(DEBUFF_DURATIONS, debuffSpells, debuffNames)
index(DEFENSIVE_DURATIONS, defensiveSpells, defensiveNames)
index(PURGE_DURATIONS, purgeSpells, purgeNames)

for spellId in pairs(ns.DRData.SPELLS) do
	ccSpells[spellId] = true
end

for spellId, spell in pairs(ns.LoseControlData.BY_ID) do
	if spell.byId then
		ccSpells[spellId] = true
		local name = GetSpellInfo(spellId)
		if name then
			ccNames[name] = nil
			durationsByName[name] = nil
		end
	end
end

local ccSpellNames = ns.LoseControlData.CONTROL_NAMES

function Data.Duration(spellId, name, learned)
	return learned and learned[spellId] or durations[spellId] or durationsByName[name]
end

function Data.ClassifyDebuff(spellId, name, own)
	if ccSpells[spellId] or ccNames[name] or ccSpellNames[name] then
		return own and KIND_OWN_CC or KIND_CC
	elseif own then
		return KIND_OWN
	elseif debuffSpells[spellId] or debuffNames[name] then
		return KIND_OTHER
	end
end

function Data.ClassifyBuff(spellId, name, debuffType, duration)
	if defensiveSpells[spellId] or defensiveNames[name] then
		return KIND_DEFENSIVE
	elseif purgeSpells[spellId] or purgeNames[name] then
		return KIND_PURGE
	elseif
		(debuffType == "Magic" or debuffType == "Enrage")
		and duration
		and duration > 0
		and duration <= PURGE_MAX_DURATION
	then
		return KIND_PURGE
	end
end
