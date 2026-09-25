local _, ns = ...

local SPELLS = {
	DEATHKNIGHT = {
		{ 47528, 10, cat = "interrupt" }, -- Mind Freeze
		{ 47476, 120, cat = "interrupt" }, -- Strangulate
		{ 49203, 60, cat = "cc", talent = true }, -- Hungering Cold
		{ 48707, 45, cat = "defensive", buff = true }, -- Anti-Magic Shell
		{ 48792, 120, cat = "defensive", buff = true }, -- Icebound Fortitude
		{ 49039, 120, cat = "defensive", talent = true, buff = true }, -- Lichborne
		{ 51052, 120, cat = "defensive", talent = true }, -- Anti-Magic Zone
		{ 48743, 120, cat = "defensive" }, -- Death Pact
		{ 55233, 60, cat = "defensive", talent = true, buff = true }, -- Vampiric Blood
		{ 49222, 60, cat = "defensive", talent = true, buff = true, hide = true }, -- Bone Shield
		{ 51271, 60, cat = "defensive", talent = true, buff = true }, -- Unbreakable Armor
		{ 49005, 180, cat = "defensive", talent = true, hide = true }, -- Mark of Blood
		{ 49576, 35, cat = "cc" }, -- Death Grip
		{ 49028, 90, cat = "offensive", talent = true, buff = true }, -- Dancing Rune Weapon
		{ 49016, 180, cat = "offensive", talent = true, buff = true }, -- Hysteria
		{ 49206, 180, cat = "offensive", talent = true }, -- Summon Gargoyle
		{ 47568, 300, cat = "offensive" }, -- Empower Rune Weapon
		{ 46584, 180, cat = "utility" }, -- Raise Dead
		{ 42650, 600, cat = "utility", hide = true }, -- Army of the Dead
		{ 45529, 60, cat = "utility", hide = true }, -- Blood Tap
		{ 43265, 30, cat = "utility", ranks = { 49936, 49937, 49938 }, hide = true }, -- Death and Decay
	},
	DRUID = {
		{ 16979, 15, cat = "interrupt", talent = 49377 }, -- Feral Charge - Bear
		{ 49376, 30, cat = "mobility", talent = 49377 }, -- Feral Charge - Cat
		{ 5211, 60, cat = "cc", ranks = { 6798, 8983 } }, -- Bash
		{ 22570, 10, cat = "cc", ranks = { 49802 } }, -- Maim
		{
			50516,
			20,
			cat = "cc",
			ranks = { 53223, 53225, 53226, 53227, 61384, 61387, 61388, 61390, 61391 },
			talent = true,
		}, -- Typhoon
		{ 22812, 60, cat = "defensive", buff = true }, -- Barkskin
		{ 61336, 180, cat = "defensive", talent = true, buff = true }, -- Survival Instincts
		{ 22842, 180, cat = "defensive", buff = true }, -- Frenzied Regeneration
		{ 17116, 180, cat = "utility", talent = true, preactive = true }, -- Nature's Swiftness
		{ 18562, 15, cat = "utility", talent = true, hide = true }, -- Swiftmend
		{ 16689, 60, cat = "cc", ranks = { 16810, 16811, 16812, 16813, 17329, 27009, 53312 }, buff = true }, -- Nature's Grasp
		{ 29166, 180, cat = "utility", buff = true }, -- Innervate
		{ 50334, 180, cat = "offensive", talent = true, buff = true }, -- Berserk
		{ 33831, 180, cat = "offensive", talent = true }, -- Force of Nature
		{ 48505, 90, cat = "offensive", ranks = { 53199, 53200, 53201 }, talent = true }, -- Starfall
		{ 1850, 180, cat = "mobility", ranks = { 9821, 33357 }, buff = true }, -- Dash
		{ 20484, 600, cat = "utility", ranks = { 20739, 20742, 20747, 20748, 26994, 48477 }, hide = true }, -- Rebirth
	},
	HUNTER = {
		{ 34490, 20, cat = "interrupt", talent = true }, -- Silencing Shot
		{ 19503, 30, cat = "cc", talent = true }, -- Scatter Shot
		{
			19386,
			60,
			cat = "cc",
			ranks = { 24132, 24133, 27068, 49011, 49012 },
			talent = true,
		}, -- Wyvern Sting
		{ 1499, 30, cat = "cc", ranks = { 14310, 14311 } }, -- Freezing Trap
		{ 60192, 30, cat = "cc", hide = true }, -- Freezing Arrow
		{ 13809, 30, cat = "cc", hide = true }, -- Frost Trap
		{ 34600, 30, cat = "utility", hide = true }, -- Snake Trap
		{ 19577, 60, cat = "cc", talent = true }, -- Intimidation
		{ 19263, 90, cat = "defensive", buff = true }, -- Deterrence
		{ 5384, 30, cat = "defensive", buff = true, hide = true }, -- Feign Death
		{ 53271, 60, cat = "mobility", buff = true }, -- Master's Call
		{ 781, 25, cat = "mobility" }, -- Disengage
		{ 23989, 180, cat = "utility", talent = true }, -- Readiness
		{ 19574, 120, cat = "offensive", talent = true, buff = true }, -- Bestial Wrath
		{ 3045, 300, cat = "offensive", buff = true }, -- Rapid Fire
		{ 19801, 8, cat = "utility", hide = true }, -- Tranquilizing Shot
		{ 53480, 60, cat = "defensive", pet = true }, -- Roar of Sacrifice
		{ 1543, 20, cat = "utility", hide = true }, -- Flare
	},
	MAGE = {
		{ 2139, 24, cat = "interrupt" }, -- Counterspell
		{ 44572, 30, cat = "cc", talent = true }, -- Deep Freeze
		{
			31661,
			20,
			cat = "cc",
			ranks = { 33041, 33042, 33043, 42949, 42950 },
			talent = true,
		}, -- Dragon's Breath
		{
			11113,
			30,
			cat = "cc",
			ranks = { 13018, 13019, 13020, 13021, 27133, 33933, 42944, 42945 },
			talent = true,
			hide = true,
		}, -- Blast Wave
		{ 122, 25, cat = "cc", ranks = { 865, 6131, 10230, 27088, 42917 } }, -- Frost Nova
		{ 45438, 300, cat = "defensive", buff = true }, -- Ice Block
		{ 11958, 480, cat = "utility", talent = true }, -- Cold Snap
		{
			11426,
			30,
			cat = "defensive",
			ranks = { 13031, 13032, 13033, 27134, 33405, 43038, 43039 },
			talent = true,
			buff = true,
			hide = true,
		}, -- Ice Barrier
		{ 543, 30, cat = "defensive", ranks = { 8457, 8458, 10223, 10225, 27128, 43010 }, buff = true, hide = true }, -- Fire Ward
		{ 6143, 30, cat = "defensive", ranks = { 8461, 8462, 10177, 28609, 32796, 43012 }, buff = true, hide = true }, -- Frost Ward
		{ 66, 180, cat = "defensive", buff = true }, -- Invisibility
		{ 1953, 15, cat = "mobility" }, -- Blink
		{ 12472, 180, cat = "offensive", talent = true, buff = true }, -- Icy Veins
		{ 12042, 120, cat = "offensive", talent = true, buff = true }, -- Arcane Power
		{ 12043, 120, cat = "offensive", talent = true, preactive = true }, -- Presence of Mind
		{ 11129, 120, cat = "offensive", talent = true, preactive = 28682 }, -- Combustion
		{ 55342, 180, cat = "defensive", buff = true }, -- Mirror Image
		{ 31687, 180, cat = "utility", talent = true, hide = true }, -- Summon Water Elemental
		{ 12051, 240, cat = "utility" }, -- Evocation
	},
	PALADIN = {
		{ 853, 60, cat = "cc", ranks = { 5588, 5589, 10308 } }, -- Hammer of Justice
		{ 20066, 60, cat = "cc", talent = true }, -- Repentance
		{
			31935,
			30,
			cat = "cc",
			ranks = { 32699, 32700, 48826, 48827 },
			talent = true,
			hide = true,
		}, -- Avenger's Shield
		{ 2812, 30, cat = "cc", ranks = { 10318, 27139, 48816, 48817 }, hide = true }, -- Holy Wrath
		{ 642, 300, cat = "defensive", buff = true }, -- Divine Shield
		{ 498, 180, cat = "defensive", buff = true }, -- Divine Protection
		{ 1022, 300, cat = "defensive", ranks = { 5599, 10278 }, buff = true }, -- Hand of Protection
		{ 6940, 120, cat = "defensive", buff = true }, -- Hand of Sacrifice
		{ 64205, 120, cat = "defensive", talent = true, buff = true }, -- Divine Sacrifice
		{ 1044, 25, cat = "mobility", buff = true }, -- Hand of Freedom
		{ 31821, 120, cat = "defensive", talent = true, buff = true }, -- Aura Mastery
		{ 633, 1200, cat = "defensive", ranks = { 2799, 10310, 27154, 48788 } }, -- Lay on Hands
		{ 19752, 600, cat = "utility", hide = true }, -- Divine Intervention
		{ 31884, 180, cat = "offensive", buff = true }, -- Avenging Wrath
		{ 20216, 120, cat = "offensive", talent = true, preactive = true }, -- Divine Favor
		{ 31842, 180, cat = "utility", talent = true, buff = true }, -- Divine Illumination
		{ 54428, 60, cat = "utility" }, -- Divine Plea
	},
	PRIEST = {
		{ 15487, 45, cat = "interrupt", talent = true }, -- Silence
		{ 64044, 120, cat = "cc", talent = true }, -- Psychic Horror
		{ 8122, 30, cat = "cc", ranks = { 8124, 10888, 10890 } }, -- Psychic Scream
		{ 33206, 180, cat = "defensive", talent = true, buff = true }, -- Pain Suppression
		{ 47788, 180, cat = "defensive", talent = true, buff = true }, -- Guardian Spirit
		{ 47585, 120, cat = "defensive", talent = true, buff = true }, -- Dispersion
		{
			19236,
			120,
			cat = "defensive",
			ranks = { 19238, 19240, 19241, 19242, 19243, 25437, 48172, 48173 },
			talent = true,
		}, -- Desperate Prayer
		{ 6346, 180, cat = "defensive", buff = true }, -- Fear Ward
		{ 586, 30, cat = "defensive", ranks = { 9578, 9579, 9592, 10941, 10942, 25429 }, buff = true, hide = true }, -- Fade
		{ 32379, 12, cat = "utility", ranks = { 32996, 48157, 48158 }, hide = true }, -- Shadow Word: Death
		{ 14751, 180, cat = "utility", talent = true, preactive = true }, -- Inner Focus
		{ 10060, 120, cat = "offensive", talent = true, buff = true }, -- Power Infusion
		{ 34433, 300, cat = "utility" }, -- Shadowfiend
	},
	ROGUE = {
		{ 1766, 10, cat = "interrupt", ranks = { 1767, 1768, 1769, 38768 } }, -- Kick
		{ 2094, 180, cat = "cc" }, -- Blind
		{ 408, 20, cat = "cc", ranks = { 8643 } }, -- Kidney Shot
		{ 1776, 10, cat = "cc", ranks = { 1777, 8629, 11285, 11286, 38764 } }, -- Gouge
		{ 51722, 60, cat = "cc" }, -- Dismantle
		{ 31224, 90, cat = "defensive", buff = true }, -- Cloak of Shadows
		{ 5277, 180, cat = "defensive", ranks = { 26669 }, buff = true }, -- Evasion
		{ 1856, 180, cat = "defensive", ranks = { 1857, 26889 } }, -- Vanish
		{ 14185, 480, cat = "utility", talent = true }, -- Preparation
		{ 36554, 30, cat = "mobility", talent = true }, -- Shadowstep
		{ 2983, 180, cat = "mobility", ranks = { 8696, 11305 }, buff = true }, -- Sprint
		{ 51713, 60, cat = "offensive", talent = true, buff = true }, -- Shadow Dance
		{ 14177, 180, cat = "offensive", talent = true, preactive = true }, -- Cold Blood
		{ 13750, 180, cat = "offensive", talent = true, buff = true }, -- Adrenaline Rush
		{ 51690, 120, cat = "offensive", talent = true }, -- Killing Spree
		{ 13877, 120, cat = "offensive", talent = true, buff = true }, -- Blade Flurry
		{ 14183, 20, cat = "utility", talent = true, hide = true }, -- Premeditation
		{ 57934, 30, cat = "utility", preactive = true, hide = true }, -- Tricks of the Trade
		{ 1784, 10, cat = "utility", ranks = { 1785, 1786, 1787 }, preactive = true, hide = true }, -- Stealth
	},
	SHAMAN = {
		{ 57994, 6, cat = "interrupt" }, -- Wind Shear
		{ 51514, 45, cat = "cc" }, -- Hex
		{ 8177, 15, cat = "defensive" }, -- Grounding Totem
		{ 2484, 15, cat = "utility", hide = true }, -- Earthbind Totem
		{ 51490, 45, cat = "cc", ranks = { 59156, 59158, 59159 }, talent = true }, -- Thunderstorm
		{ 30823, 60, cat = "defensive", talent = true, buff = true }, -- Shamanistic Rage
		{ 16188, 120, cat = "utility", talent = true, preactive = true }, -- Nature's Swiftness
		{ 16190, 300, cat = "utility", talent = true }, -- Mana Tide Totem
		{ 2825, 300, cat = "offensive", ranks = { 32182 }, buff = true }, -- Bloodlust / Heroism
		{ 16166, 180, cat = "offensive", talent = true, preactive = true }, -- Elemental Mastery
		{ 51533, 180, cat = "offensive", talent = true }, -- Feral Spirit
		{ 55198, 180, cat = "utility", talent = true, buff = true, hide = true }, -- Tidal Force
	},
	WARLOCK = {
		{ 19244, 24, cat = "interrupt", ranks = { 19647 }, pet = true }, -- Spell Lock
		{ 19505, 8, cat = "utility", ranks = { 19731, 19734, 19736, 27276, 27277, 48011 }, pet = true, hide = true }, -- Devour Magic
		{ 6789, 120, cat = "cc", ranks = { 17925, 17926, 27223, 47859, 47860 } }, -- Death Coil
		{ 5484, 40, cat = "cc", ranks = { 17928 } }, -- Howl of Terror
		{ 30283, 20, cat = "cc", ranks = { 30413, 30414, 47846, 47847 }, talent = true }, -- Shadowfury
		{ 54785, 45, cat = "mobility", talent = 59672 }, -- Demon Charge
		{ 48020, 30, cat = "mobility" }, -- Demonic Circle: Teleport
		{ 6229, 30, cat = "defensive", ranks = { 11739, 11740, 28610, 47890, 47891 }, buff = true, hide = true }, -- Shadow Ward
		{ 47241, 180, cat = "offensive", talent = 59672, buff = true }, -- Metamorphosis
		{ 47193, 60, cat = "utility", talent = true, buff = true, hide = true }, -- Demonic Empowerment
		{ 18708, 180, cat = "utility", talent = true, buff = true, hide = true }, -- Fel Domination
	},
	WARRIOR = {
		{ 6552, 10, cat = "interrupt", ranks = { 6554 } }, -- Pummel
		{ 72, 12, cat = "interrupt", ranks = { 1671, 1672, 29704 } }, -- Shield Bash
		{ 100, 15, cat = "mobility", ranks = { 6178, 11578 } }, -- Charge
		{ 20252, 30, cat = "mobility", ranks = { 20616, 20617, 25272, 25275 } }, -- Intercept
		{ 5246, 120, cat = "cc" }, -- Intimidating Shout
		{ 12809, 30, cat = "cc", talent = true }, -- Concussion Blow
		{ 46968, 20, cat = "cc", talent = true }, -- Shockwave
		{ 676, 60, cat = "cc" }, -- Disarm
		{ 23920, 10, cat = "defensive", buff = true }, -- Spell Reflection
		{ 3411, 30, cat = "mobility" }, -- Intervene
		{ 57755, 60, cat = "utility", hide = true }, -- Heroic Throw
		{ 871, 300, cat = "defensive", buff = true }, -- Shield Wall
		{ 12975, 180, cat = "defensive", talent = true, buff = true }, -- Last Stand
		{ 55694, 180, cat = "defensive", buff = true }, -- Enraged Regeneration
		{ 2565, 60, cat = "defensive", buff = true, hide = true }, -- Shield Block
		{ 18499, 30, cat = "defensive", buff = true }, -- Berserker Rage
		{ 46924, 90, cat = "offensive", talent = true, buff = true }, -- Bladestorm
		{ 12292, 180, cat = "offensive", talent = true, buff = true }, -- Death Wish
		{ 1719, 300, cat = "offensive", buff = true }, -- Recklessness
		{ 20230, 300, cat = "defensive", buff = true }, -- Retaliation
		{ 60970, 45, cat = "mobility", talent = true }, -- Heroic Fury
		{ 64382, 300, cat = "utility" }, -- Shattering Throw
	},
	COMMON = {
		{ 42292, 120, cat = "trinket" }, -- PvP Trinket
		{ 59752, 120, cat = "trinket" }, -- Every Man for Himself
		{ 7744, 120, cat = "trinket" }, -- Will of the Forsaken
		{ 20549, 120, cat = "cc" }, -- War Stomp
		{ 20589, 105, cat = "mobility" }, -- Escape Artist
		{ 28730, 120, cat = "interrupt", ranks = { 25046, 50613 } }, -- Arcane Torrent
		{ 20572, 120, cat = "offensive", ranks = { 33697, 33702 }, buff = true }, -- Blood Fury
		{ 26297, 180, cat = "offensive", buff = true }, -- Berserking
		{ 20594, 120, cat = "defensive", buff = true }, -- Stoneform
		{ 58984, 120, cat = "defensive" }, -- Shadowmeld
		{ 28880, 180, cat = "utility", ranks = { 59542, 59543, 59544, 59545, 59547, 59548 }, hide = true }, -- Gift of the Naaru
		{ 47875, 120, cat = "defensive", ranks = { 47876, 47877 }, dynamic = true }, -- Fel Healthstone
	},
}

local CATEGORIES = { "defensive", "offensive", "interrupt", "cc", "mobility", "utility" }

local SPEC_HINTS = {
	DEATHKNIGHT = {
		{ 1, 0, 51789, 64855, 64856, 64858, 64859 }, -- Blade Barrier
		{ 1, 0, 50163 }, -- Butchery
		{ 1, 5, 50421, 50422 }, -- Scent of Blood
		{ 1, 10, 48982 }, -- Rune Tap
		{ 1, 15, 50181 }, -- Vendetta
		{ 1, 20, 49005, 61607 }, -- Mark of Blood
		{ 1, 25, 53137, 53138 }, -- Abomination's Might
		{ 1, 25, 50447, 50448, 50449 }, -- Bloody Vengeance
		{ 1, 30, 50452 }, -- Bloodworms
		{ 1, 30, 49016 }, -- Hysteria
		{ 1, 30, 63611 }, -- Improved Blood Presence
		{ 1, 35, 55233 }, -- Vampiric Blood
		{ 1, 40, 55050, 55258, 55259, 55260, 55261, 55262 }, -- Heart Strike
		{ 1, 40, 49189, 50149, 50150 }, -- Will of the Necropolis
		{ 1, 45, 61154, 61155, 61156, 61157, 61158 }, -- Blood Gorged
		{ 1, 50, 49028 }, -- Dancing Rune Weapon
		{ 2, 10, 50882, 58575, 58576, 58577, 58578 }, -- Icy Talons
		{ 2, 10, 49039, 50397 }, -- Lichborne
		{ 2, 15, 51124 }, -- Killing Machine
		{ 2, 20, 49796 }, -- Deathchill
		{ 2, 25, 55610 }, -- Improved Icy Talons
		{ 2, 25, 59052 }, -- Rime
		{ 2, 30, 50434, 50435, 50436 }, -- Chilblains
		{ 2, 30, 49203, 51209 }, -- Hungering Cold
		{ 2, 35, 51271 }, -- Unbreakable Armor
		{ 2, 40, 50362, 50485, 50486, 50488, 50489, 50490 }, -- Acclimation
		{ 2, 40, 49143, 51416, 51417, 51418, 51419, 55268, 66196, 66958, 66959, 66960, 66961, 66962 }, -- Frost Strike
		{ 2, 50, 49184, 51409, 51410, 51411, 53536 }, -- Howling Blast
		{ 3, 10, 51270, 43999, 49158, 51325, 51326, 51327, 51328, 47496 }, -- Corpse Explosion
		{ 3, 10, 51460 }, -- Necrosis
		{ 3, 15, 49146, 51267 }, -- On a Pale Horse
		{ 3, 20, 50536 }, -- Unholy Blight
		{ 3, 25, 55741, 67804, 68766 }, -- Desecration
		{ 3, 30, 50461, 51052 }, -- Anti-Magic Zone
		{ 3, 30, 63583, 66800, 66801, 66802, 66803 }, -- Desolation
		{ 3, 30, 63560 }, -- Ghoul Frenzy
		{ 3, 35, 49222 }, -- Bone Shield
		{ 3, 40, 55090, 55265, 55270, 55271, 71488, 70890 }, -- Scourge Strike
		{ 3, 40, 50526 }, -- Wandering Plague
		{ 3, 50, 49206, 50514, 61777 }, -- Summon Gargoyle
	},
	DRUID = {
		{ 1, 10, 16886 }, -- Nature's Grace
		{ 1, 20, 5570, 24974, 24975, 24976, 24977, 27013, 48468 }, -- Insect Swarm
		{ 1, 30, 50170, 50171, 50172 }, -- Improved Moonkin Form
		{ 1, 30, 24907, 24858 }, -- Moonkin Form
		{ 1, 35, 48391 }, -- Owlkin Frenzy
		{ 1, 40, 48518, 48517 }, -- Eclipse
		{ 1, 40, 33831 }, -- Force of Nature
		{ 1, 40, 50516, 53223, 53225, 53226, 53227, 61384, 61387, 61388, 61390, 61391 }, -- Typhoon
		{ 1, 45, 60431, 60432, 60433 }, -- Earth and Moon
		{
			1,
			50,
			48505,
			50288,
			50294,
			53188,
			53189,
			53190,
			53191,
			53194,
			53195,
			53199,
			53200,
			53201,
			50286,
			53196,
			53197,
			53198,
		}, -- Starfall
		{ 2, 10, 50322, 61336 }, -- Survival Instincts
		{ 2, 15, 69369 }, -- Predatory Strikes
		{ 2, 15, 16953, 16959, 37116, 37117 }, -- Primal Fury
		{ 2, 20, 50259, 49377, 16979, 49376, 61132, 61138, 19675, 45334 }, -- Feral Charge
		{ 2, 20, 47179, 47180 }, -- Nurturing Instinct
		{ 2, 25, 57893, 59071, 59072 }, -- Natural Reaction
		{ 2, 30, 34299 }, -- Improved Leader of the Pack
		{ 2, 30, 24932 }, -- Leader of the Pack
		{ 2, 35, 58179, 58180, 58181 }, -- Infected Wounds
		{ 2, 40, 51185 }, -- King of the Jungle
		{ 2, 40, 33917, 33878, 33986, 33987, 48563, 48564, 33876, 33982, 33983, 48565, 48566 }, -- Mangle
		{ 2, 50, 50334, 58923 }, -- Berserk
		{ 3, 10, 17080, 35358, 35359 }, -- Intensity
		{ 3, 10, 16870, 70721 }, -- Omen of Clarity
		{ 3, 20, 17116 }, -- Nature's Swiftness
		{ 3, 30, 45281, 45282, 45283 }, -- Natural Perfection
		{ 3, 30, 18562 }, -- Swiftmend
		{ 3, 35, 48503, 48504 }, -- Living Seed
		{ 3, 40, 48540, 48541, 48542, 48543 }, -- Revitalize
		{ 3, 40, 33891, 65139 }, -- Tree of Life
		{ 3, 50, 48438, 53248, 53249, 53251 }, -- Wild Growth
	},
	HUNTER = {
		{ 1, 0, 6150 }, -- Improved Aspect of the Hawk
		{ 1, 15, 24406 }, -- Improved Mend Pet
		{ 1, 20, 19577, 24394 }, -- Intimidation
		{ 1, 30, 19574 }, -- Bestial Wrath
		{ 1, 40, 53257 }, -- Cobra Strikes
		{ 1, 40, 34471 }, -- The Beast Within
		{
			2,
			10,
			19434,
			20900,
			20901,
			20902,
			20903,
			20904,
			27065,
			27632,
			30614,
			31623,
			38370,
			38861,
			44271,
			48871,
			49049,
			49050,
			52718,
			54615,
			59243,
		}, -- Aimed Shot
		{ 2, 10, 34952, 34953 }, -- Go for the Throat
		{ 2, 10, 35098, 35099 }, -- Rapid Killing
		{ 2, 20, 35101 }, -- Concussive Barrage
		{ 2, 20, 23989 }, -- Readiness
		{ 2, 30, 63468 }, -- Piercing Shots
		{ 2, 30, 19506 }, -- Trueshot Aura
		{ 2, 35, 56654, 58882, 58883, 64180, 53230, 54227 }, -- Rapid Recuperation
		{ 2, 40, 53220 }, -- Improved Steady Shot
		{ 2, 40, 34490, 41084, 42671 }, -- Silencing Shot
		{ 2, 40, 53254 }, -- Wild Quiver
		{ 2, 50, 53209, 53359, 53353, 53358 }, -- Chimera Shot
		{ 3, 5, 19185, 64803, 64804 }, -- Entrapment
		{ 3, 10, 19503, 23601, 36732, 37506 }, -- Scatter Shot
		{ 3, 15, 56453, 67544 }, -- Lock and Load
		{ 3, 20, 19306, 20909, 20910, 27067, 48998, 48999 }, -- Counterattack
		{ 3, 30, 34501 }, -- Expose Weakness
		{ 3, 30, 34720 }, -- Thrill of the Hunt
		{ 3, 30, 19386, 24132, 24133, 27068, 49011, 49012, 24131, 24134, 24135, 27069, 49009, 49010 }, -- Wyvern Sting
		{ 3, 35, 34833, 34834, 34835, 34836, 34837 }, -- Master Tactician
		{ 3, 40, 3674, 63668, 63669, 63670, 63671, 63672 }, -- Black Arrow
		{ 3, 40, 64418, 64419, 64420 }, -- Sniper Training
		{ 3, 50, 53301, 60051, 60052, 60053, 53352 }, -- Explosive Shot
	},
	MAGE = {
		{ 1, 5, 12536 }, -- Arcane Concentration
		{ 1, 5, 29442 }, -- Magic Absorption
		{ 1, 10, 54646, 54648 }, -- Focus Magic
		{ 1, 15, 18469, 55021 }, -- Improved Counterspell
		{ 1, 20, 46989, 47000 }, -- Improved Blink
		{ 1, 20, 12043 }, -- Presence of Mind
		{ 1, 25, 57529, 57531 }, -- Arcane Potency
		{ 1, 30, 31579, 31582, 31583 }, -- Arcane Empowerment
		{ 1, 30, 12042 }, -- Arcane Power
		{ 1, 30, 44413 }, -- Incanter's Absorption
		{ 1, 40, 44401 }, -- Missile Barrage
		{ 1, 40, 31589 }, -- Slow
		{ 1, 50, 44425, 44780, 44781 }, -- Arcane Barrage
		{ 2, 5, 54748 }, -- Burning Determination
		{ 2, 5, 12654 }, -- Ignite
		{ 2, 10, 12355, 64343 }, -- Impact
		{ 2, 10, 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132, 33938, 42890, 42891 }, -- Pyroblast
		{ 2, 15, 22959 }, -- Improved Scorch
		{ 2, 15, 29077 }, -- Master of Elements
		{ 2, 20, 11113, 13018, 13019, 13020, 13021, 27133, 33933, 42944, 42945 }, -- Blast Wave
		{ 2, 25, 31643 }, -- Blazing Speed
		{ 2, 30, 11129, 28682 }, -- Combustion
		{ 2, 35, 67545 }, -- Empowered Fire
		{ 2, 35, 64346, 64353, 64357 }, -- Fiery Payback
		{ 2, 40, 31661, 33041, 33042, 33043, 42949, 42950 }, -- Dragon's Breath
		{ 2, 40, 54741 }, -- Firestarter
		{ 2, 40, 48108 }, -- Hot Streak
		{ 2, 45, 44450 }, -- Burnout
		{ 2, 50, 44457, 55359, 55360 }, -- Living Bomb
		{ 3, 0, 12494 }, -- Frostbite
		{ 3, 10, 12472 }, -- Icy Veins
		{ 3, 20, 11958 }, -- Cold Snap
		{ 3, 25, 12579 }, -- Winter's Chill
		{ 3, 30, 11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039 }, -- Ice Barrier
		{ 3, 30, 55080 }, -- Shattered Barrier
		{ 3, 35, 44544, 74396 }, -- Fingers of Frost
		{ 3, 40, 57761 }, -- Brain Freeze
		{ 3, 40, 31687, 70907, 70908 }, -- Summon Water Elemental
		{ 3, 50, 44572, 58534 }, -- Deep Freeze
	},
	PALADIN = {
		{ 1, 10, 31821, 64364 }, -- Aura Mastery
		{ 1, 10, 20272 }, -- Illumination
		{ 1, 10, 20233, 20236 }, -- Improved Lay on Hands
		{ 1, 20, 20216 }, -- Divine Favor
		{
			1,
			30,
			20473,
			20929,
			20930,
			25902,
			25911,
			25912,
			27174,
			27176,
			32771,
			33072,
			33073,
			36340,
			38921,
			48822,
			48823,
			48824,
			48825,
		}, -- Holy Shock
		{ 1, 30, 31834 }, -- Light's Grace
		{ 1, 35, 53659 }, -- Sacred Cleansing
		{ 1, 40, 31842 }, -- Divine Illumination
		{ 1, 40, 53655, 53656, 53657, 54152, 54153 }, -- Judgements of the Pure
		{ 1, 45, 66922, 53672, 54149 }, -- Infusion of Light
		{ 1, 50, 53563, 53652, 53653, 53654, 53651 }, -- Beacon of Light
		{ 2, 10, 64205 }, -- Divine Sacrifice
		{ 2, 15, 70940 }, -- Divine Guardian
		{ 2, 20, 20911, 57319, 67480, 25899 }, -- Blessing of Sanctuary
		{ 2, 20, 20178, 32746 }, -- Reckoning
		{ 2, 30, 66235 }, -- Ardent Defender
		{ 2, 30, 20925, 20927, 20928, 27179, 48951, 48952 }, -- Holy Shield
		{ 2, 30, 31786 }, -- Spiritual Attunement
		{ 2, 35, 20128, 20131, 20132 }, -- Redoubt
		{ 2, 40, 31935, 32699, 32700, 48826, 48827 }, -- Avenger's Shield
		{ 2, 40, 63521 }, -- Guarded by the Light
		{ 2, 45, 68055 }, -- Judgements of the Just
		{ 2, 45, 63529 }, -- Shield of the Templar
		{ 2, 50, 53595 }, -- Hammer of the Righteous
		{ 3, 5, 21183, 54498, 54499 }, -- Heart of the Crusader
		{ 3, 10, 20375, 20424, 33127, 42058, 57770, 69403 }, -- Seal of Command
		{ 3, 10, 67, 26017 }, -- Vindication
		{ 3, 15, 25997 }, -- Eye for an Eye
		{ 3, 20, 63531 }, -- Sanctified Retribution
		{ 3, 25, 20050, 20052, 20053 }, -- Vengeance
		{ 3, 30, 31930 }, -- Judgements of the Wise
		{ 3, 30, 20066 }, -- Repentance
		{ 3, 30, 53489, 59578 }, -- The Art of War
		{ 3, 40, 35395 }, -- Crusader Strike
		{ 3, 40, 54203 }, -- Sheath of Light
		{ 3, 45, 61840 }, -- Righteous Vengeance
		{ 3, 50, 53385, 54171, 54172 }, -- Divine Storm
	},
	PRIEST = {
		{ 1, 5, 14743, 27828 }, -- Martyrdom
		{ 1, 10, 14751 }, -- Inner Focus
		{ 1, 30, 45237, 45241, 45242 }, -- Focused Will
		{ 1, 30, 10060 }, -- Power Infusion
		{ 1, 35, 47755 }, -- Rapture
		{ 1, 35, 63944 }, -- Renewed Hope
		{ 1, 40, 47753, 54704 }, -- Divine Aegis
		{ 1, 40, 47930 }, -- Grace
		{ 1, 40, 33206, 44416 }, -- Pain Suppression
		{ 1, 45, 59887, 59888, 59889, 59890, 59891 }, -- Borrowed Time
		{ 1, 50, 47540, 53005, 53006, 53007, 47666, 52998, 52999, 53000, 47750, 52983, 52984, 52985 }, -- Penance
		{ 2, 10, 19236, 19238, 19240, 19241, 19242, 19243, 25437, 48172, 48173 }, -- Desperate Prayer
		{ 2, 10, 14893, 15357, 15359 }, -- Inspiration
		{ 2, 20, 20711, 27827 }, -- Spirit of Redemption
		{ 2, 25, 33151 }, -- Surge of Light
		{ 2, 30, 33143 }, -- Blessed Resilience
		{ 2, 30, 34754, 63724, 63725 }, -- Holy Concentration
		{ 2, 30, 724, 27870, 27871, 28275, 48086, 48087 }, -- Lightwell
		{ 2, 35, 64128, 65081, 64136 }, -- Body and Soul
		{ 2, 35, 63731, 63734, 63735 }, -- Serendipity
		{ 2, 40, 34861, 34863, 34864, 34865, 34866, 48088, 48089, 49306 }, -- Circle of Healing
		{ 2, 50, 47788, 48153 }, -- Guardian Spirit
		{ 3, 0, 49694, 59000 }, -- Improved Spirit Tap
		{ 3, 0, 15271 }, -- Spirit Tap
		{
			3,
			10,
			15407,
			17311,
			17312,
			17313,
			17314,
			18807,
			25387,
			48155,
			48156,
			16568,
			17165,
			22919,
			23953,
			26044,
			26143,
			28310,
			29570,
			32417,
			35507,
			37276,
			37330,
			37621,
			38243,
			40842,
			42396,
			43512,
			52586,
			57941,
			58381,
			59367,
			59974,
			60472,
		}, -- Mind Flay
		{ 3, 15, 15258 }, -- Shadow Weaving
		{ 3, 20, 15487 }, -- Silence
		{ 3, 20, 15286, 71269, 15290 }, -- Vampiric Embrace
		{ 3, 25, 63675, 75999 }, -- Improved Devouring Plague
		{ 3, 30, 15473, 49868, 71167 }, -- Shadowform
		{ 3, 35, 33196, 33197, 33198 }, -- Misery
		{ 3, 40, 47948 }, -- Pain and Suffering
		{ 3, 40, 64044, 64058 }, -- Psychic Horror
		{ 3, 40, 34914, 34916, 34917, 48159, 48160, 64085 }, -- Vampiric Touch
		{ 3, 50, 47585, 60069, 63230 }, -- Dispersion
	},
	ROGUE = {
		{ 1, 0, 14143, 14149 }, -- Remorseless Attacks
		{ 1, 5, 14157 }, -- Ruthlessness
		{ 1, 20, 14177 }, -- Cold Blood
		{ 1, 20, 31663 }, -- Quick Recovery
		{ 1, 25, 14189 }, -- Seal Fate
		{ 1, 30, 58427 }, -- Overkill
		{ 1, 35, 51637 }, -- Focused Attacks
		{ 1, 40, 1329, 34411, 34412, 34413, 48663, 48666, 5374, 27576, 34414, 34416, 34419, 48662, 48665 }, -- Mutilate
		{ 1, 40, 51627, 51628, 51629, 52910, 52914, 52915 }, -- Turn the Tables
		{ 1, 50, 51662, 63848 }, -- Hunger For Blood
		{ 2, 10, 14251 }, -- Riposte
		{ 2, 15, 18425 }, -- Improved Kick
		{ 2, 15, 30918 }, -- Improved Sprint
		{ 2, 20, 13877, 22482 }, -- Blade Flurry
		{ 2, 20, 66923 }, -- Hack and Slash
		{ 2, 25, 31125, 51585 }, -- Blade Twisting
		{ 2, 30, 13750 }, -- Adrenaline Rush
		{ 2, 35, 35542, 35545, 35546, 35547, 35548 }, -- Combat Potency
		{ 2, 35, 51680 }, -- Throwing Specialization
		{ 2, 40, 58684, 58683 }, -- Savage Combat
		{ 2, 40, 51675, 51677 }, -- Unfair Advantage
		{ 2, 45, 58670 }, -- Prey on the Weak
		{ 2, 50, 51690, 57840, 57841, 57842, 61851 }, -- Killing Spree
		{ 3, 0, 14181 }, -- Relentless Strikes
		{ 3, 10, 14278 }, -- Ghostly Strike
		{ 3, 15, 13977 }, -- Initiative
		{ 3, 15, 15250 }, -- Setup
		{ 3, 20, 16511, 17347, 17348, 26864, 48660 }, -- Hemorrhage
		{ 3, 20, 14185 }, -- Preparation
		{ 3, 25, 31665 }, -- Master of Subtlety
		{ 3, 30, 31231, 45182 }, -- Cheat Death
		{ 3, 30, 14183 }, -- Premeditation
		{ 3, 35, 51693 }, -- Waylay
		{ 3, 40, 51698, 51699, 51700, 51701, 52916 }, -- Honor Among Thieves
		{ 3, 40, 36554, 36563, 44373 }, -- Shadowstep
		{ 3, 50, 51713 }, -- Shadow Dance
	},
	SHAMAN = {
		{ 1, 5, 30165, 29177, 29178 }, -- Elemental Devastation
		{ 1, 10, 16246 }, -- Elemental Focus
		{ 1, 30, 16166, 64701 }, -- Elemental Mastery
		{ 1, 35, 51466, 51470 }, -- Elemental Oath
		{ 1, 35, 45284, 45286, 45287, 45288, 45289, 45290, 45291, 45292, 45293, 45294, 45295, 45296 }, -- Lightning Overload
		{ 1, 40, 52179 }, -- Astral Shift
		{ 1, 40, 30706, 57720, 57721, 57722 }, -- Totem of Wrath
		{ 1, 50, 51490, 59156, 59158, 59159 }, -- Thunderstorm
		{ 2, 15, 16257, 16277, 16278, 16279, 16280 }, -- Flurry
		{ 2, 20, 16268 }, -- Spirit Weapons
		{ 2, 25, 63685 }, -- Frozen Power
		{ 2, 25, 30802, 30808, 30809 }, -- Unleashed Rage
		{ 2, 30, 30798 }, -- Dual Wield
		{ 2, 30, 17364, 32175, 32176 }, -- Stormstrike
		{ 2, 35, 63375 }, -- Improved Stormstrike
		{ 2, 35, 60103 }, -- Lava Lash
		{ 2, 40, 30823, 30824 }, -- Shamanistic Rage
		{ 2, 45, 70831, 51529, 51530, 51531, 51532, 53817, 53818 }, -- Maelstrom Weapon
		{ 2, 50, 51533, 52120 }, -- Feral Spirit
		{ 3, 10, 16177, 16236, 16237 }, -- Ancestral Healing
		{ 3, 10, 55198 }, -- Tidal Force
		{ 3, 20, 16188 }, -- Nature's Swiftness
		{ 3, 30, 51886 }, -- Cleanse Spirit
		{ 3, 30, 16190 }, -- Mana Tide Totem
		{ 3, 30, 31616 }, -- Nature's Guardian
		{ 3, 40, 52752, 52759 }, -- Ancestral Awakening
		{ 3, 40, 974, 32593, 32594, 49283, 49284 }, -- Earth Shield
		{ 3, 45, 53390 }, -- Tidal Waves
		{ 3, 50, 61295, 61299, 61300, 61301 }, -- Riptide
	},
	WARLOCK = {
		{ 1, 15, 17941 }, -- Nightfall
		{ 1, 20, 18223, 29539 }, -- Curse of Exhaustion
		{ 1, 20, 32386, 32388, 32389, 32390, 32391, 60448, 60465, 60466, 60467 }, -- Shadow Embrace
		{ 1, 20, 63106 }, -- Siphon Life
		{ 1, 30, 18220, 18937, 18938, 27265, 59092 }, -- Dark Pact
		{ 1, 30, 64368, 64370, 64371 }, -- Eradication
		{ 1, 40, 30108, 30404, 30405, 34438, 34439, 35183, 47841, 47843, 31117 }, -- Unstable Affliction
		{ 1, 45, 47422 }, -- Everlasting Affliction
		{ 1, 50, 48181, 59161, 59163, 59164 }, -- Haunt
		{ 2, 0, 54181 }, -- Fel Synergy
		{ 2, 5, 60955, 60956 }, -- Improved Health Funnel
		{ 2, 10, 18708 }, -- Fel Domination
		{ 2, 10, 19028 }, -- Soul Link
		{ 2, 25, 47383, 71162, 71165 }, -- Molten Core
		{ 2, 30, 47193, 54435, 54436, 54443, 54444, 54508, 54509 }, -- Demonic Empowerment
		{ 2, 35, 63165, 63167 }, -- Decimation
		{ 2, 40, 30146 }, -- Summon Felguard
		{ 2, 45, 48090 }, -- Demonic Pact
		{ 2, 50, 47241, 59672, 59673, 50581, 54785 }, -- Metamorphosis
		{ 3, 0, 17800 }, -- Improved Shadow Bolt
		{ 3, 5, 18118 }, -- Aftermath
		{ 3, 10, 17877, 18867, 18868, 18869, 18870, 18871, 27263, 30546, 47826, 47827, 29341 }, -- Shadowburn
		{ 3, 20, 34936 }, -- Backlash
		{ 3, 25, 54370, 54371, 54372, 54373, 54374, 54375 }, -- Nether Protection
		{ 3, 30, 17962 }, -- Conflagrate
		{ 3, 30, 18093, 63243, 63244 }, -- Pyroclasm
		{ 3, 30, 30294, 54300, 54607, 59117, 59118 }, -- Soul Leech
		{ 3, 40, 54274, 54276, 54277 }, -- Backdraft
		{ 3, 40, 30283, 30413, 30414, 35373, 39082, 47846, 47847 }, -- Shadowfury
		{ 3, 50, 50796, 59170, 59171, 59172, 69576, 71108 }, -- Chaos Bolt
	},
	WARRIOR = {
		{ 1, 10, 12162, 12850, 12868, 12721 }, -- Deep Wounds
		{ 1, 15, 60503 }, -- Taste for Blood
		{ 1, 20, 12328, 12723, 26654 }, -- Sweeping Strikes
		{ 1, 20, 16459 }, -- Sword Specialization
		{ 1, 25, 23694 }, -- Improved Hamstring
		{ 1, 25, 46856, 46857 }, -- Trauma
		{ 1, 30, 12294, 21551, 21552, 21553, 25248, 27580, 30330, 44268, 47485, 47486 }, -- Mortal Strike
		{ 1, 30, 29841, 29842 }, -- Second Wind
		{ 1, 35, 64976, 65156 }, -- Juggernaut
		{ 1, 35, 64849, 64850 }, -- Unrelenting Assault
		{ 1, 40, 30069, 30070 }, -- Blood Frenzy
		{ 1, 40, 52437 }, -- Sudden Death
		{ 1, 45, 57518, 57519, 57520, 57521, 57522 }, -- Wrecking Crew
		{ 1, 50, 46924 }, -- Bladestorm
		{ 2, 5, 12964 }, -- Unbridled Wrath
		{ 2, 10, 16488, 16490, 16491 }, -- Blood Craze
		{ 2, 10, 12323 }, -- Piercing Howl
		{ 2, 15, 12880, 14201, 14202, 14203, 14204 }, -- Enrage
		{ 2, 20, 12292 }, -- Death Wish
		{ 2, 25, 12966, 12967, 12968, 12969, 12970 }, -- Flurry
		{ 2, 25, 23690, 23691 }, -- Improved Berserker Rage
		{ 2, 30, 23880, 23881, 23892, 23893, 23894, 25251, 30335, 23885 }, -- Bloodthirst
		{ 2, 35, 56112 }, -- Furious Attacks
		{ 2, 40, 46916 }, -- Bloodsurge
		{ 2, 40, 60970 }, -- Heroic Fury
		{ 2, 40, 29801 }, -- Rampage
		{ 3, 0, 23602 }, -- Shield Specialization
		{ 3, 10, 12975, 12976 }, -- Last Stand
		{ 3, 20, 12809 }, -- Concussion Blow
		{ 3, 20, 18498 }, -- Gag Order
		{ 3, 30, 57514, 57516 }, -- Improved Defensive Stance
		{ 3, 30, 50720, 50725, 59665 }, -- Vigilance
		{ 3, 35, 46946, 46947 }, -- Safeguard
		{ 3, 40, 20243, 30016, 30022, 47497, 47498 }, -- Devastate
		{ 3, 40, 57499 }, -- Warbringer
		{ 3, 45, 59653 }, -- Damage Shield
		{ 3, 45, 50227 }, -- Sword and Board
		{ 3, 50, 46968, 55636, 55918, 57728, 57741, 58947, 58977, 75343 }, -- Shockwave
	},
}

local specHints = {}
for class, rows in pairs(SPEC_HINTS) do
	for i = 1, #rows do
		local row = rows[i]
		local hint = { class = class, tree = row[1], points = row[2] }
		for j = 3, #row do
			specHints[row[j]] = hint
		end
	end
end

local MOD_TALENTS = {
	{ 3, 5, 48963, 49564, 49565 }, -- Morbidity
	{ 3, 5, 49588, 49589 }, -- Unholy Command
	{ 3, 15, 55620, 55623 }, -- Night of the Dead
	{ 3, 25, 52143 }, -- Master of Ghouls
	{ 2, 20, 16940, 16941 }, -- Brutal Impact
	{ 1, 40, 53262, 53263, 53264 }, -- Longevity
	{ 2, 10, 34948, 34949 }, -- Rapid Killing
	{ 3, 10, 19286, 19287 }, -- Survival Tactics
	{ 3, 25, 34491, 34492, 34493 }, -- Resourcefulness
	{ 1, 35, 44378, 44379 }, -- Arcane Flows
	{ 3, 0, 31670, 31672, 55094 }, -- Ice Floes
	{ 3, 25, 55091, 55092 }, -- Cold as Ice
	{ 1, 10, 20234, 20235 }, -- Improved Lay on Hands
	{ 1, 25, 31825, 31826 }, -- Purifying Power
	{ 2, 5, 20174, 20175 }, -- Guardian's Favor
	{ 2, 15, 20487, 20488 }, -- Improved Hammer of Justice
	{ 2, 25, 31848, 31849 }, -- Sacred Duty
	{ 2, 45, 53695, 53696 }, -- Judgements of the Just
	{ 3, 35, 53375, 53376 }, -- Sanctified Wrath
	{ 1, 35, 47507, 47508 }, -- Aspiration
	{ 3, 10, 15392, 15448 }, -- Improved Psychic Scream
	{ 3, 15, 15274, 15311 }, -- Veiled Shadows
	{ 2, 10, 13742, 13872 }, -- Endurance
	{ 3, 10, 13981, 14066 }, -- Elusiveness
	{ 3, 40, 58414, 58415 }, -- Filthy Tricks
	{ 1, 10, 16040, 16113, 16114, 16115, 16116 }, -- Reverberation
	{ 2, 0, 16043, 16130 }, -- Earth's Grasp
	{ 2, 5, 16258, 16293 }, -- Guardian Totems
	{ 2, 40, 63117, 63121, 63123 }, -- Nemesis
	{ 1, 35, 64976 }, -- Juggernaut
	{ 2, 20, 29888, 29889 }, -- Improved Intercept
	{ 2, 30, 46908, 46909, 56924 }, -- Intensify Rage
	{ 3, 10, 29598, 29599 }, -- Shield Mastery
	{ 3, 15, 12313, 12804 }, -- Improved Disarm
	{ 3, 20, 12312, 12803 }, -- Improved Disciplines
}

local modTalents = {}
for i = 1, #MOD_TALENTS do
	local row = MOD_TALENTS[i]
	local maxRank = #row - 2
	for rank = 1, maxRank do
		modTalents[row[rank + 2]] = { tree = row[1], points = row[2], rank = rank, maxRank = maxRank }
	end
end

local SHARED_COOLDOWNS = {
	[42292] = { 59752, 120, 7744, 45 },
	[59752] = { 42292, 120 },
	[7744] = { 42292, 45 },
	[16979] = { 49376, 15 },
	[49376] = { 16979, 15 },
	[871] = { 1719, 12, 20230, 12 },
	[1719] = { 871, 12, 20230, 12 },
	[20230] = { 871, 12, 1719, 12 },
	[1499] = { 13809, 30, 60192, 30 },
	[13809] = { 1499, 30, 60192, 30 },
	[60192] = { 1499, 30, 13809, 30 },
	[6552] = { 72, 10 },
	[72] = { 6552, 12 },
}

local RESETS = {
	[23989] = { all = true }, -- Readiness
	[11958] = { 45438, 122, 44572, 12472, 11426, 31687, 543, 6143 }, -- Cold Snap
	[45438] = { glyph = 56372, glyphed = { 122 } }, -- Ice Block
	[14185] = { 5277, 2983, 1856, 14177, 36554, glyph = 56819, glyphed = { 13877, 51722, 1766 } }, -- Preparation
	[60970] = { 20252 }, -- Heroic Fury
}

local CDMOD = {
	[47476] = { 58618, 20 },
	[49576] = { 49588, 5, 49589, 10 },
	[46584] = { 55620, 45, 55623, 90, 52143, 60 },
	[42650] = { 55620, 120, 55623, 240 },
	[43265] = { 48963, 5, 49564, 10, 49565, 15 },

	[5211] = { 16940, 15, 16941, 30 },
	[50516] = { 63056, 3 },
	[48505] = { 54828, 30 },

	[1499] = { 34491, 2, 34492, 4, 34493, 6 },
	[13809] = { 34491, 2, 34492, 4, 34493, 6 },
	[34600] = { 34491, 2, 34492, 4, 34493, 6 },
	[60192] = { 34491, 2, 34492, 4, 34493, 6 },
	[3045] = { 34948, 60, 34949, 120 },
	[19574] = { 56830, 2 },
	[5384] = { 57903, 5 },
	[781] = { 19286, 2, 19287, 4, 56844, 5 },
	[19263] = { 56850, 10 },
	[19386] = { 56848, 6 },

	[12051] = { 44378, 60, 44379, 120 },
	[31687] = { 56373, 30 },

	[1022] = { 20174, 60, 20175, 120 },
	[498] = { 31848, 30, 31849, 60 },
	[642] = { 31848, 30, 31849, 60 },
	[853] = { 20487, 10, 20488, 20, 53695, 5, 53696, 10 },
	[633] = { 20234, 120, 20235, 240 },
	[31884] = { 53375, 30, 53376, 60 },

	[34433] = { 15274, 60, 15311, 120 },
	[8122] = { 15392, 2, 15448, 4, 55676, -8 },
	[47585] = { 63229, 45 },
	[6346] = { 55678, 60 },

	[2094] = { 13981, 30, 14066, 60 },
	[1856] = { 13981, 30, 14066, 60 },
	[31224] = { 13981, 15, 14066, 30 },
	[5277] = { 13742, 30, 13872, 60 },
	[2983] = { 13742, 30, 13872, 60 },
	[36554] = { 58414, 5, 58415, 10 },
	[57934] = { 58414, 5, 58415, 10 },
	[14185] = { 58414, 90, 58415, 180 },
	[51690] = { 63252, 45 },

	[57994] = { 16040, 0.2, 16113, 0.4, 16114, 0.6, 16115, 0.8, 16116, 1 },
	[8177] = { 16258, 1, 16293, 2 },
	[16166] = { 55452, 30 },
	[51490] = { 63270, 10 },

	[5484] = { 56217, 8 },
	[48020] = { 63309, 4 },

	[20252] = { 29888, 5, 29889, 10 },
	[1719] = { 12312, 30, 12803, 60 },
	[20230] = { 12312, 30, 12803, 60 },
	[871] = { 12312, 30, 12803, 60, 63329, 120 },
	[100] = { 64976, -5 },
	[2565] = { 29598, 10, 29599, 20 },
	[676] = { 12313, 10, 12804, 20 },
	[12975] = { 58376, 60 },
	[46968] = { 63325, 3 },
	[46924] = { 63324, 15 },
	[23920] = { 63328, 15 },
}

local CDMOD_MULT = {
	[1850] = { 59219, 0.8 },

	[19574] = { 53262, 0.9, 53263, 0.8, 53264, 0.7 },
	[19577] = { 53262, 0.9, 53263, 0.8, 53264, 0.7 },
	[53271] = { 53262, 0.9, 53263, 0.8, 53264, 0.7 },

	[45438] = { 31670, 0.93, 31672, 0.86, 55094, 0.8 },
	[122] = { 31670, 0.93, 31672, 0.86, 55094, 0.8 },
	[12472] = { 31670, 0.93, 31672, 0.86, 55094, 0.8 },
	[11958] = { 55091, 0.9, 55092, 0.8 },
	[11426] = { 55091, 0.9, 55092, 0.8 },
	[31687] = { 55091, 0.9, 55092, 0.8 },
	[12043] = { 44378, 0.85, 44379, 0.7 },
	[12042] = { 44378, 0.85, 44379, 0.7 },
	[66] = { 44378, 0.85, 44379, 0.7 },

	[2812] = { 31825, 0.83, 31826, 0.67 },

	[14751] = { 47507, 0.9, 47508, 0.8 },
	[10060] = { 47507, 0.9, 47508, 0.8 },
	[33206] = { 47507, 0.9, 47508, 0.8 },

	[2484] = { 16043, 0.85, 16130, 0.7 },

	[47193] = { 63117, 0.9, 63121, 0.8, 63123, 0.7 },
	[47241] = { 63117, 0.9, 63121, 0.8, 63123, 0.7 },
	[18708] = { 63117, 0.9, 63121, 0.8, 63123, 0.7 },

	[18499] = { 46908, 0.89, 46909, 0.78, 56924, 0.67 },
	[1719] = { 46908, 0.89, 46909, 0.78, 56924, 0.67 },
	[12292] = { 46908, 0.89, 46909, 0.78, 56924, 0.67 },
	[100] = { 58355, 0.93 },
}

ns.CooldownData = {
	SPELLS = SPELLS,
	CATEGORIES = CATEGORIES,
	SPEC_HINTS = specHints,
	MOD_TALENTS = modTalents,
	SHARED_COOLDOWNS = SHARED_COOLDOWNS,
	RESETS = RESETS,
	CDMOD = CDMOD,
	CDMOD_MULT = CDMOD_MULT,
	FORBEARANCE = 25771,
	FORBEARANCE_SPELLS = { 642, 498, 1022, 633, 31884 },
	TALENT_SWAP = { [63644] = true, [63645] = true },
	MAX_TALENT_POINTS = 71,
	RACIALS = {
		Human = 59752,
		Scourge = 7744,
		Tauren = 20549,
		Gnome = 20589,
		BloodElf = 28730,
		Orc = 20572,
		Troll = 26297,
		Dwarf = 20594,
		NightElf = 58984,
		Draenei = 28880,
	},
	PVP_TRINKET = 42292,
}
