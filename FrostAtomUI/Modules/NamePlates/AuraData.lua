local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local GetSpellInfo = GetSpellInfo

local CC_DURATIONS = {
	[118] = 10, -- Polymorph
	[6770] = 10, -- Sap
	[1776] = 4, -- Gouge
	[2094] = 10, -- Blind
	[1833] = 4, -- Cheap Shot
	[408] = 6, -- Kidney Shot
	[1330] = 3, -- Garrote - Silence
	[18425] = 2, -- Silenced - Improved Kick
	[51722] = 10, -- Dismantle
	[5782] = 10, -- Fear
	[5484] = 8, -- Howl of Terror
	[6358] = 10, -- Seduction
	[6789] = 3, -- Death Coil
	[30283] = 3, -- Shadowfury
	[24259] = 3, -- Spell Lock
	[31117] = 5, -- Unstable Affliction
	[710] = 6, -- Banish
	[8122] = 8, -- Psychic Scream
	[64044] = 3, -- Psychic Horror
	[64058] = 10, -- Psychic Horror
	[15487] = 5, -- Silence
	[9484] = 10, -- Shackle Undead
	[853] = 6, -- Hammer of Justice
	[20066] = 6, -- Repentance
	[10326] = 10, -- Turn Evil
	[2812] = 3, -- Holy Wrath
	[63529] = 3, -- Silenced - Shield of the Templar
	[20170] = 2, -- Stun
	[33786] = 6, -- Cyclone
	[5211] = 4, -- Bash
	[22570] = 5, -- Maim
	[9005] = 3, -- Pounce
	[2637] = 10, -- Hibernate
	[339] = 10, -- Entangling Roots
	[45334] = 4, -- Feral Charge Effect
	[19503] = 4, -- Scatter Shot
	[3355] = 10, -- Freezing Trap Effect
	[60210] = 10, -- Freezing Arrow Effect
	[19386] = 6, -- Wyvern Sting
	[34490] = 3, -- Silencing Shot
	[24394] = 3, -- Intimidation
	[53359] = 10, -- Chimera Shot - Scorpid
	[19306] = 5, -- Counterattack
	[19185] = 2, -- Entrapment
	[64803] = 3, -- Entrapment
	[64804] = 4, -- Entrapment
	[50519] = 2, -- Sonic Blast
	[50518] = 2, -- Ravage
	[50541] = 6, -- Snatch
	[53148] = 1, -- Charge
	[50245] = 4, -- Pin
	[54706] = 4, -- Venom Web Spray
	[4167] = 4, -- Web
	[1513] = 10, -- Scare Beast
	[12355] = 2, -- Impact
	[44572] = 5, -- Deep Freeze
	[31661] = 5, -- Dragon's Breath
	[122] = 8, -- Frost Nova
	[33395] = 8, -- Freeze
	[18469] = 2, -- Silenced - Improved Counterspell
	[55021] = 4, -- Silenced - Improved Counterspell
	[55080] = 8, -- Shattered Barrier
	[12494] = 5, -- Frostbite
	[64346] = 6, -- Fiery Payback
	[5246] = 8, -- Intimidating Shout
	[20511] = 8, -- Intimidating Shout
	[676] = 10, -- Disarm
	[12809] = 5, -- Concussion Blow
	[46968] = 4, -- Shockwave
	[7922] = 1.5, -- Charge Stun
	[20253] = 3, -- Intercept
	[30153] = 3, -- Intercept
	[23694] = 5, -- Improved Hamstring
	[58373] = 5, -- Glyph of Hamstring
	[18498] = 3, -- Silenced - Gag Order
	[47476] = 5, -- Strangulate
	[49203] = 10, -- Hungering Cold
	[47481] = 3, -- Gnaw
	[51514] = 10, -- Hex
	[39796] = 3, -- Stoneclaw Stun
	[58861] = 2, -- Bash
	[64695] = 5, -- Earthgrab
	[63685] = 5, -- Freeze
	[60995] = 3, -- Demon Charge
	[22703] = 2, -- Inferno Effect
	[605] = 10, -- Mind Control
	[20549] = 2, -- War Stomp
	[25046] = 2, -- Arcane Torrent
	[28730] = 2, -- Arcane Torrent
	[50613] = 2, -- Arcane Torrent
	[39965] = 5, -- Frost Grenade
	[55536] = 3, -- Frostweave Net
	[30216] = 3, -- Fel Iron Bomb
	[30217] = 3, -- Adamantite Grenade
	[67769] = 3, -- Cobalt Frag Bomb
	[13181] = 10, -- Gnomish Mind Control Cap
}

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

local Data = {
	KIND_OWN_CC = KIND_OWN_CC,
	KIND_CC = KIND_CC,
	KIND_DEFENSIVE = KIND_DEFENSIVE,
	KIND_OWN = KIND_OWN,
	KIND_PURGE = KIND_PURGE,
	KIND_OTHER = KIND_OTHER,
	PURGE_MAX_DURATION = 60,
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

local ccSpellNames = ns:GetModule("UnitFrames").ccSpellNames

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
		and duration <= Data.PURGE_MAX_DURATION
	then
		return KIND_PURGE
	end
end
