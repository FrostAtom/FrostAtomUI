local _, ns = ...

local GetSpellInfo = GetSpellInfo

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

Data.IMMUNITIES = { immune = true, magicImmune = true, physicalImmune = true }

Data.SPELLS = {
	immune = {
		{ 642 }, -- Divine Shield
		{ 45438 }, -- Ice Block
		{ 19263 }, -- Deterrence
		{ 19753 }, -- Divine Intervention
	},
	magicImmune = {
		{ 31224 }, -- Cloak of Shadows
		{ 48707 }, -- Anti-Magic Shell
	},
	physicalImmune = {
		{ 1022, 5599, 10278 }, -- Hand of Protection
	},
	stun = {
		{ 853, 5588, 5589, 10308 }, -- Hammer of Justice
		{ 2812, 10318, 27139, 48816, 48817 }, -- Holy Wrath
		{ 20170 }, -- Stun
		{ 408, 8643 }, -- Kidney Shot
		{ 1833 }, -- Cheap Shot
		{ 5211, 6798, 8983, 58861 }, -- Bash
		{ 9005, 9823, 9827, 27006, 49803 }, -- Pounce
		{ 22570, 49802 }, -- Maim
		{ 7922 }, -- Charge Stun
		{ 20253, 30153, 30195, 30197, 47995 }, -- Intercept
		{ 12809 }, -- Concussion Blow
		{ 46968 }, -- Shockwave
		{ 44572 }, -- Deep Freeze
		{ 12355 }, -- Impact
		{ 30283, 30413, 30414, 47846, 47847 }, -- Shadowfury
		{ 22703 }, -- Inferno Effect
		{ 60995 }, -- Demon Charge
		{ 24394 }, -- Intimidation
		{ 50519, 53564, 53565, 53566, 53567, 53568 }, -- Sonic Blast
		{ 50518, 53558, 53559, 53560, 53561, 53562 }, -- Ravage
		{ 47481 }, -- Gnaw
		{ 39796 }, -- Stoneclaw Stun
		{ 20549 }, -- War Stomp
		{ 46567 }, -- Rocket Launch
	},
	incapacitate = {
		{ 33786 }, -- Cyclone
		{ 710, 18647 }, -- Banish
		{ 118, 12824, 12825, 12826, 28271, 28272, 61025, 61305, 61721, 61780, 71319 }, -- Polymorph
		{ 51514 }, -- Hex
		{ 2070, 6770, 11297, 51724 }, -- Sap
		{ 1776 }, -- Gouge
		{ 2094 }, -- Blind
		{ 20066 }, -- Repentance
		{ 3355, 14308, 14309, 55041 }, -- Freezing Trap Effect
		{ 60210 }, -- Freezing Arrow Effect
		{ 19386, 24132, 24133, 27068, 49011, 49012 }, -- Wyvern Sting
		{ 19503 }, -- Scatter Shot
		{ 31661, 33041, 33042, 33043, 42949, 42950 }, -- Dragon's Breath
		{ 2637, 18657, 18658 }, -- Hibernate
		{ 9484, 9485, 10955 }, -- Shackle Undead
		{ 51209 }, -- Hungering Cold
		{ 605 }, -- Mind Control
		{ 13181 }, -- Gnomish Mind Control Cap
		{ 30501, 30504 }, -- Poultryized!
		{ 30216 }, -- Fel Iron Bomb
		{ 30217 }, -- Adamantite Grenade
		{ 30461 }, -- The Bigger One
		{ 67769 }, -- Cobalt Frag Bomb
		{ 53261 }, -- Saronite Grenade
		{ 71988 }, -- Vile Fumes
	},
	fear = {
		{ 5782, 6213, 6215 }, -- Fear
		{ 5484, 17928 }, -- Howl of Terror
		{ 6358 }, -- Seduction
		{ 6789, 17925, 17926, 27223, 47859, 47860 }, -- Death Coil
		{ 8122, 8124, 10888, 10890 }, -- Psychic Scream
		{ 64044 }, -- Psychic Horror
		{ 5246, 20511 }, -- Intimidating Shout
		{ 1513, 14326, 14327 }, -- Scare Beast
		{ 10326 }, -- Turn Evil
		{ 35474 }, -- Drums of Panic
	},
	silence = {
		{ 15487 }, -- Silence
		{ 1330 }, -- Garrote - Silence
		{ 18425 }, -- Silenced - Improved Kick
		{ 34490 }, -- Silencing Shot
		{ 47476, 49913, 49914, 49915, 49916 }, -- Strangulate
		{ 24259 }, -- Spell Lock
		{ 31117, 43523 }, -- Unstable Affliction
		{ 18469, 55021 }, -- Silenced - Improved Counterspell
		{ 18498, 74347 }, -- Silenced - Gag Order
		{ 63529 }, -- Silenced - Shield of the Templar
		{ 25046, 28730, 50613 }, -- Arcane Torrent
		{ 19821 }, -- Arcane Bomb
	},
	disarm = {
		{ 676 }, -- Disarm
		{ 51722 }, -- Dismantle
		{ 64058 }, -- Psychic Horror
		{ 53359 }, -- Chimera Shot - Scorpid
		{ 50541, 53537, 53538, 53540, 53542, 53543 }, -- Snatch
		{ 64346 }, -- Fiery Payback
	},
	root = {
		{
			339,
			1062,
			5195,
			5196,
			9852,
			9853,
			19970,
			19971,
			19972,
			19973,
			19974,
			19975,
			26989,
			27010,
			53308,
			53313,
			66070,
		}, -- Entangling Roots
		{ 45334 }, -- Feral Charge Effect
		{ 122, 865, 6131, 10230, 27088, 42917 }, -- Frost Nova
		{ 33395, 63685 }, -- Freeze
		{ 12494 }, -- Frostbite
		{ 55080 }, -- Shattered Barrier
		{ 64695 }, -- Earthgrab
		{ 23694 }, -- Improved Hamstring
		{ 58373 }, -- Glyph of Hamstring
		{ 19185, 64803, 64804 }, -- Entrapment
		{ 19306, 20909, 20910, 27067, 48998, 48999 }, -- Counterattack
		{ 50245, 53544, 53545, 53546, 53547, 53548 }, -- Pin
		{ 54706, 55505, 55506, 55507, 55508, 55509 }, -- Venom Web Spray
		{ 4167 }, -- Web
		{ 53148 }, -- Charge
		{ 13099, 13119 }, -- Net-o-Matic
		{ 31367 }, -- Netherweave Net
		{ 31368 }, -- Heavy Netherweave Net
		{ 55536 }, -- Frostweave Net
		{ 39965 }, -- Frost Grenade
	},
}

local byId, controlNames = {}, {}
for category, spells in pairs(Data.SPELLS) do
	for _, spell in ipairs(spells) do
		spell.category = category
		for i = 1, #spell do
			byId[spell[i]] = spell
		end
		local name = not Data.IMMUNITIES[category] and GetSpellInfo(spell[1])
		if name then
			controlNames[name] = true
		end
	end
end
Data.BY_ID = byId
Data.CONTROL_NAMES = controlNames
