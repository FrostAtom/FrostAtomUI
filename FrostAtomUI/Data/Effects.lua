local _, ns = ...

ns.Effects = {
	{ 642, control = "immune" }, -- Divine Shield
	{ 45438, control = "immune" }, -- Ice Block
	{ 19263, control = "immune" }, -- Deterrence
	{ 19753, control = "immune" }, -- Divine Intervention
	{ 31224, control = "magicImmune" }, -- Cloak of Shadows
	{ 48707, control = "magicImmune" }, -- Anti-Magic Shell
	{ 1022, 5599, 10278, control = "physicalImmune" }, -- Hand of Protection
	{ 853, 5588, 5589, 10308, control = "stun", dr = "stun", loc = "stun", duration = 6 }, -- Hammer of Justice
	{ 2812, 10318, 27139, 48816, 48817, control = "stun", dr = "stun", loc = "stun", duration = 3 }, -- Holy Wrath
	{ 20170, control = "stun", dr = "randomstun", loc = "stun", duration = 2 }, -- Stun
	{ 408, 8643, control = "stun", dr = "stun", loc = "stun", duration = 6 }, -- Kidney Shot
	{ 1833, control = "stun", dr = "openingstun", loc = "stun", duration = 4 }, -- Cheap Shot
	{ 5211, 6798, 8983, 58861, control = "stun", dr = "stun", loc = "stun", duration = 4, durations = { [58861] = 2 } }, -- Bash
	{ 9005, 9823, 9827, 27006, 49803, control = "stun", dr = "openingstun", loc = "stun", duration = 3 }, -- Pounce
	{ 22570, 49802, control = "stun", dr = "stun", loc = "stun", duration = 5 }, -- Maim
	{ 7922, control = "stun", dr = "charge", loc = "stun", duration = 1.5 }, -- Charge Stun
	{ 20253, 30153, 30195, 30197, 47995, control = "stun", dr = "stun", loc = "stun", duration = 3 }, -- Intercept
	{ 12809, control = "stun", dr = "stun", loc = "stun", duration = 5 }, -- Concussion Blow
	{ 46968, control = "stun", dr = "stun", loc = "stun", duration = 4 }, -- Shockwave
	{ 44572, control = "stun", dr = "stun", loc = "stun", duration = 5 }, -- Deep Freeze
	{ 12355, control = "stun", dr = "randomstun", loc = "stun", duration = 2 }, -- Impact
	{ 30283, 30413, 30414, 47846, 47847, control = "stun", dr = "stun", loc = "stun", duration = 3 }, -- Shadowfury
	{ 22703, control = "stun", dr = "stun", loc = "stun", duration = 2 }, -- Inferno Effect
	{ 60995, control = "stun", dr = "stun", loc = "stun", duration = 3 }, -- Demon Charge
	{ 24394, control = "stun", dr = "randomstun", loc = "stun", duration = 3 }, -- Intimidation
	{ 50519, 53564, 53565, 53566, 53567, 53568, control = "stun", dr = "stun", loc = "stun", duration = 2 }, -- Sonic Blast
	{ 50518, 53558, 53559, 53560, 53561, 53562, control = "stun", dr = "stun", loc = "stun", duration = 2 }, -- Ravage
	{ 47481, control = "stun", dr = "stun", loc = "stun", duration = 3 }, -- Gnaw
	{ 39796, control = "stun", dr = "randomstun", loc = "stun", duration = 3 }, -- Stoneclaw Stun
	{ 20549, control = "stun", dr = "stun", loc = "stun", duration = 2 }, -- War Stomp
	{ 46567, control = "stun", dr = "stun", loc = "stun" }, -- Rocket Launch
	{ 33786, control = "incapacitate", dr = "cyclone", loc = "cyclone", duration = 6 }, -- Cyclone
	{ 710, 18647, control = "incapacitate", dr = "banish", loc = "banish", duration = 6 }, -- Banish
	{
		118,
		12824,
		12825,
		12826,
		28271,
		28272,
		61025,
		61305,
		61721,
		61780,
		71319,
		control = "incapacitate",
		dr = "disorient",
		loc = "polymorph",
		duration = 10,
	}, -- Polymorph
	{ 51514, control = "incapacitate", dr = "disorient", loc = "polymorph", duration = 10 }, -- Hex
	{ 2070, 6770, 11297, 51724, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 10 }, -- Sap
	{ 1776, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 4 }, -- Gouge
	{ 2094, control = "incapacitate", dr = "fear", loc = "disorient", duration = 10 }, -- Blind
	{ 20066, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 6 }, -- Repentance
	{ 3355, 14308, 14309, 55041, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 10 }, -- Freezing Trap Effect
	{ 60210, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 10 }, -- Freezing Arrow Effect
	{
		19386,
		24132,
		24133,
		27068,
		49011,
		49012,
		control = "incapacitate",
		dr = "disorient",
		loc = "sleep",
		duration = 6,
		byId = true,
	}, -- Wyvern Sting
	{ 19503, control = "incapacitate", dr = "scatter", loc = "disorient", duration = 4 }, -- Scatter Shot
	{
		31661,
		33041,
		33042,
		33043,
		42949,
		42950,
		control = "incapacitate",
		dr = "dragonsbreath",
		loc = "disorient",
		duration = 5,
	}, -- Dragon's Breath
	{ 2637, 18657, 18658, control = "incapacitate", dr = "sleep", loc = "sleep", duration = 10 }, -- Hibernate
	{ 9484, 9485, 10955, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 10 }, -- Shackle Undead
	{ 51209, control = "incapacitate", dr = "disorient", loc = "incapacitate" }, -- Hungering Cold
	{ 605, control = "incapacitate", dr = "mindcontrol", loc = "charm", duration = 10 }, -- Mind Control
	{ 13181, control = "incapacitate", dr = "mindcontrol", loc = "charm", duration = 10 }, -- Gnomish Mind Control Cap
	{ 30501, 30504, control = "incapacitate", dr = "disorient", loc = "polymorph" }, -- Poultryized!
	{ 30216, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 3 }, -- Fel Iron Bomb
	{ 30217, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 3 }, -- Adamantite Grenade
	{ 30461, control = "incapacitate", dr = "disorient", loc = "incapacitate" }, -- The Bigger One
	{ 67769, control = "incapacitate", dr = "disorient", loc = "incapacitate", duration = 3 }, -- Cobalt Frag Bomb
	{ 53261, control = "incapacitate", dr = "disorient" }, -- Saronite Grenade
	{ 71988, control = "incapacitate", dr = "disorient", loc = "incapacitate" }, -- Vile Fumes
	{ 5782, 6213, 6215, control = "fear", dr = "fear", loc = "fear", duration = 10 }, -- Fear
	{ 5484, 17928, control = "fear", dr = "fear", loc = "fear", duration = 8 }, -- Howl of Terror
	{ 6358, control = "fear", dr = "fear", loc = "seduce", duration = 10 }, -- Seduction
	{ 6789, 17925, 17926, 27223, 47859, 47860, control = "fear", dr = "horror", loc = "horror", duration = 3 }, -- Death Coil
	{ 8122, 8124, 10888, 10890, control = "fear", dr = "fear", loc = "fear", duration = 8 }, -- Psychic Scream
	{ 64044, control = "fear", dr = "horror", loc = "horror", duration = 3 }, -- Psychic Horror
	{ 5246, 20511, control = "fear", dr = "fear", loc = "fear", duration = 8 }, -- Intimidating Shout
	{ 1513, 14326, 14327, control = "fear", dr = "fear", loc = "fear", duration = 10 }, -- Scare Beast
	{ 10326, control = "fear", dr = "fear", loc = "fear", duration = 10 }, -- Turn Evil
	{ 35474, control = "fear", dr = "fear", loc = "fear" }, -- Drums of Panic
	{ 15487, control = "silence", dr = "silence", loc = "silence", duration = 5 }, -- Silence
	{ 1330, control = "silence", dr = "silence", loc = "silence", duration = 3 }, -- Garrote - Silence
	{ 18425, control = "silence", dr = "silence", loc = "silence", duration = 2 }, -- Silenced - Improved Kick
	{ 34490, control = "silence", dr = "silence", loc = "silence", duration = 3 }, -- Silencing Shot
	{ 47476, control = "silence", dr = "silence", loc = "silence", duration = 5 }, -- Strangulate
	{ 24259, control = "silence", dr = "silence", loc = "silence", duration = 3 }, -- Spell Lock
	{ 31117, 43523, control = "silence", dr = "silence", loc = "silence", duration = 5, byId = true }, -- Unstable Affliction
	{ 18469, 55021, control = "silence", dr = "silence", loc = "silence", duration = 2, durations = { [55021] = 4 } }, -- Silenced - Improved Counterspell
	{ 18498, 74347, control = "silence", dr = "silence", loc = "silence", duration = 3 }, -- Silenced - Gag Order
	{ 63529, control = "silence", dr = "silence", loc = "silence", duration = 3 }, -- Silenced - Shield of the Templar
	{ 25046, 28730, 50613, control = "silence", dr = "silence", loc = "silence", duration = 2 }, -- Arcane Torrent
	{ 19821, control = "silence", dr = "silence", loc = "silence" }, -- Arcane Bomb
	{ 676, control = "disarm", dr = "disarm", loc = "disarm", duration = 10 }, -- Disarm
	{ 51722, control = "disarm", dr = "disarm", loc = "disarm", duration = 10 }, -- Dismantle
	{ 64058, control = "disarm", dr = "disarm", loc = "disarm", duration = 10, byId = true }, -- Psychic Horror
	{ 53359, control = "disarm", dr = "disarm", loc = "disarm", duration = 10 }, -- Chimera Shot - Scorpid
	{ 50541, 53537, 53538, 53540, 53542, 53543, control = "disarm", dr = "disarm", loc = "disarm", duration = 6 }, -- Snatch
	{ 64346, control = "disarm", dr = "disarm", loc = "disarm", duration = 6 }, -- Fiery Payback
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
		control = "root",
		dr = "root",
		loc = "root",
		duration = 10,
	}, -- Entangling Roots
	{ 45334, control = "root", dr = "root", loc = "root", duration = 4 }, -- Feral Charge Effect
	{ 122, 865, 6131, 10230, 27088, 42917, control = "root", dr = "root", loc = "root", duration = 8 }, -- Frost Nova
	{
		33395,
		63685,
		control = "root",
		dr = "root",
		drs = { [63685] = "randomroot" },
		loc = "root",
		duration = 8,
		durations = { [63685] = 5 },
	}, -- Freeze
	{ 12494, control = "root", dr = "randomroot", loc = "root", duration = 5 }, -- Frostbite
	{ 55080, control = "root", dr = "randomroot", loc = "root", duration = 8 }, -- Shattered Barrier
	{ 64695, control = "root", dr = "randomroot", loc = "root", duration = 5 }, -- Earthgrab
	{ 23694, control = "root", dr = "randomroot", loc = "root", duration = 5 }, -- Improved Hamstring
	{ 58373, control = "root", dr = "randomroot", loc = "root", duration = 5 }, -- Glyph of Hamstring
	{
		19185,
		64803,
		64804,
		control = "root",
		dr = "randomroot",
		loc = "root",
		duration = 2,
		durations = { [64803] = 3, [64804] = 4 },
	}, -- Entrapment
	{ 19306, 20909, 20910, 27067, 48998, 48999, control = "root", dr = "root", loc = "root", duration = 5 }, -- Counterattack
	{ 50245, 53544, 53545, 53546, 53547, 53548, control = "root", dr = "root", loc = "root", duration = 4 }, -- Pin
	{ 54706, 55505, 55506, 55507, 55508, 55509, control = "root", dr = "root", loc = "root", duration = 4 }, -- Venom Web Spray
	{ 4167, control = "root", dr = "root", loc = "root", duration = 4 }, -- Web
	{ 53148, control = "root", dr = "stun", loc = "root", duration = 1 }, -- Charge
	{ 13099, 13119, control = "root" }, -- Net-o-Matic
	{ 31367, control = "root", dr = "stun", loc = "root" }, -- Netherweave Net
	{ 31368, control = "root", dr = "stun", loc = "root" }, -- Heavy Netherweave Net
	{ 55536, control = "root", dr = "root", loc = "root", duration = 3 }, -- Frostweave Net
	{ 39965, control = "root", dr = "root", loc = "root", duration = 5 }, -- Frost Grenade
	{ 1098, 11725, 11726, 61191, dr = "mindcontrol" }, -- Enslave Demon
	{ 49203, dr = "disorient", duration = 10 }, -- Hungering Cold
	{ 56350, dr = "disorient", loc = "incapacitate" }, -- Saronite Bomb
}
