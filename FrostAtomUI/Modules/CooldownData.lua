local _, ns = ...

local SPELLS = {
	DEATHKNIGHT = {
		{ 47528, 10, cat = "interrupt" }, -- Mind Freeze
		{ 47476, 120, cat = "interrupt" }, -- Strangulate
		{ 49203, 60, cat = "cc", talent = true, tree = 2, points = 30 }, -- Hungering Cold
		{ 48707, 45, cat = "defensive", buff = true }, -- Anti-Magic Shell
		{ 48792, 120, cat = "defensive", buff = true }, -- Icebound Fortitude
		{ 49039, 120, cat = "defensive", talent = true, tree = 2, points = 10, buff = true }, -- Lichborne
		{ 51052, 120, cat = "defensive", talent = true, tree = 3, points = 30 }, -- Anti-Magic Zone
		{ 48743, 120, cat = "defensive" }, -- Death Pact
		{ 55233, 60, cat = "defensive", talent = true, tree = 1, points = 40, buff = true }, -- Vampiric Blood
		{ 49222, 60, cat = "defensive", talent = true, tree = 3, points = 35, buff = true, hide = true }, -- Bone Shield
		{ 51271, 60, cat = "defensive", talent = true, tree = 2, points = 40, buff = true }, -- Unbreakable Armor
		{ 49005, 180, cat = "defensive", talent = true, tree = 1, points = 20, hide = true }, -- Mark of Blood
		{ 49576, 35, cat = "cc" }, -- Death Grip
		{ 49028, 90, cat = "offensive", talent = true, tree = 1, points = 50, buff = true }, -- Dancing Rune Weapon
		{ 49016, 180, cat = "offensive", talent = true, tree = 1, points = 30, buff = true }, -- Hysteria
		{ 49206, 180, cat = "offensive", talent = true, tree = 3, points = 50 }, -- Summon Gargoyle
		{ 47568, 300, cat = "offensive" }, -- Empower Rune Weapon
		{ 46584, 180, cat = "utility" }, -- Raise Dead
		{ 42650, 600, cat = "utility", hide = true }, -- Army of the Dead
		{ 45529, 60, cat = "utility", hide = true }, -- Blood Tap
		{ 43265, 30, cat = "utility", ranks = { 49936, 49937, 49938 }, hide = true }, -- Death and Decay
	},
	DRUID = {
		{ 16979, 15, cat = "interrupt", talent = 49377, tree = 2, points = 25 }, -- Feral Charge - Bear
		{ 49376, 30, cat = "mobility", talent = 49377, tree = 2, points = 25 }, -- Feral Charge - Cat
		{ 5211, 60, cat = "cc", ranks = { 6798, 8983 } }, -- Bash
		{ 22570, 10, cat = "cc", ranks = { 49802 } }, -- Maim
		{
			50516,
			20,
			cat = "cc",
			ranks = { 53223, 53225, 53226, 53227, 61384, 61387, 61388, 61390, 61391 },
			talent = true,
			tree = 1,
			points = 40,
		}, -- Typhoon
		{ 22812, 60, cat = "defensive", buff = true }, -- Barkskin
		{ 61336, 180, cat = "defensive", talent = true, tree = 2, points = 10, buff = true }, -- Survival Instincts
		{ 22842, 180, cat = "defensive", buff = true }, -- Frenzied Regeneration
		{ 17116, 180, cat = "utility", talent = true, tree = 3, points = 20, preactive = true }, -- Nature's Swiftness
		{ 18562, 15, cat = "utility", talent = true, tree = 3, points = 30, hide = true }, -- Swiftmend
		{ 16689, 60, cat = "cc", ranks = { 16810, 16811, 16812, 16813, 17329, 27009, 53312 }, buff = true }, -- Nature's Grasp
		{ 29166, 180, cat = "utility", buff = true }, -- Innervate
		{ 50334, 180, cat = "offensive", talent = true, tree = 2, points = 50, buff = true }, -- Berserk
		{ 33831, 180, cat = "offensive", talent = true, tree = 1, points = 40 }, -- Force of Nature
		{ 48505, 90, cat = "offensive", ranks = { 53199, 53200, 53201 }, talent = true, tree = 1, points = 50 }, -- Starfall
		{ 1850, 180, cat = "mobility", ranks = { 9821, 33357 }, buff = true }, -- Dash
		{ 20484, 600, cat = "utility", ranks = { 20739, 20742, 20747, 20748, 26994, 48477 }, hide = true }, -- Rebirth
	},
	HUNTER = {
		{ 34490, 20, cat = "interrupt", talent = true, tree = 2, points = 45 }, -- Silencing Shot
		{ 19503, 30, cat = "cc", talent = true, tree = 3, points = 10 }, -- Scatter Shot
		{
			19386,
			60,
			cat = "cc",
			ranks = { 24132, 24133, 27068, 49011, 49012 },
			talent = true,
			tree = 3,
			points = 30,
		}, -- Wyvern Sting
		{ 1499, 30, cat = "cc", ranks = { 14310, 14311 } }, -- Freezing Trap
		{ 60192, 30, cat = "cc", hide = true }, -- Freezing Arrow
		{ 13809, 30, cat = "cc", hide = true }, -- Frost Trap
		{ 34600, 30, cat = "utility", hide = true }, -- Snake Trap
		{ 19577, 60, cat = "cc", talent = true, tree = 1, points = 20 }, -- Intimidation
		{ 19263, 90, cat = "defensive", buff = true }, -- Deterrence
		{ 5384, 30, cat = "defensive", buff = true, hide = true }, -- Feign Death
		{ 53271, 60, cat = "mobility", buff = true }, -- Master's Call
		{ 781, 25, cat = "mobility" }, -- Disengage
		{ 23989, 180, cat = "utility", talent = true, tree = 2, points = 25 }, -- Readiness
		{ 19574, 120, cat = "offensive", talent = true, tree = 1, points = 35, buff = true }, -- Bestial Wrath
		{ 3045, 300, cat = "offensive", buff = true }, -- Rapid Fire
		{ 19801, 8, cat = "utility", hide = true }, -- Tranquilizing Shot
		{ 53480, 60, cat = "defensive", pet = true }, -- Roar of Sacrifice
		{ 1543, 20, cat = "utility", hide = true }, -- Flare
	},
	MAGE = {
		{ 2139, 24, cat = "interrupt" }, -- Counterspell
		{ 44572, 30, cat = "cc", talent = true, tree = 3, points = 50 }, -- Deep Freeze
		{
			31661,
			20,
			cat = "cc",
			ranks = { 33041, 33042, 33043, 42949, 42950 },
			talent = true,
			tree = 2,
			points = 40,
		}, -- Dragon's Breath
		{
			11113,
			30,
			cat = "cc",
			ranks = { 13018, 13019, 13020, 13021, 27133, 33933, 42944, 42945 },
			talent = true,
			tree = 2,
			points = 25,
			hide = true,
		}, -- Blast Wave
		{ 122, 25, cat = "cc", ranks = { 865, 6131, 10230, 27088, 42917 } }, -- Frost Nova
		{ 45438, 300, cat = "defensive", buff = true }, -- Ice Block
		{ 11958, 480, cat = "utility", talent = true, tree = 3, points = 20 }, -- Cold Snap
		{
			11426,
			30,
			cat = "defensive",
			ranks = { 13031, 13032, 13033, 27134, 33405, 43038, 43039 },
			talent = true,
			tree = 3,
			points = 30,
			buff = true,
			hide = true,
		}, -- Ice Barrier
		{ 543, 30, cat = "defensive", ranks = { 8457, 8458, 10223, 10225, 27128, 43010 }, buff = true, hide = true }, -- Fire Ward
		{ 6143, 30, cat = "defensive", ranks = { 8461, 8462, 10177, 28609, 32796, 43012 }, buff = true, hide = true }, -- Frost Ward
		{ 66, 180, cat = "defensive", buff = true }, -- Invisibility
		{ 1953, 15, cat = "mobility" }, -- Blink
		{ 12472, 180, cat = "offensive", talent = true, tree = 3, points = 10, buff = true }, -- Icy Veins
		{ 12042, 120, cat = "offensive", talent = true, tree = 1, points = 35, buff = true }, -- Arcane Power
		{ 12043, 120, cat = "offensive", talent = true, tree = 1, points = 25, preactive = true }, -- Presence of Mind
		{ 11129, 120, cat = "offensive", talent = true, tree = 2, points = 30, preactive = 28682 }, -- Combustion
		{ 55342, 180, cat = "defensive", buff = true }, -- Mirror Image
		{ 31687, 180, cat = "utility", talent = true, tree = 3, points = 40, hide = true }, -- Summon Water Elemental
		{ 12051, 240, cat = "utility" }, -- Evocation
	},
	PALADIN = {
		{ 853, 60, cat = "cc", ranks = { 5588, 5589, 10308 } }, -- Hammer of Justice
		{ 20066, 60, cat = "cc", talent = true, tree = 3, points = 35 }, -- Repentance
		{
			31935,
			30,
			cat = "cc",
			ranks = { 32699, 32700, 48826, 48827 },
			talent = true,
			tree = 2,
			points = 45,
			hide = true,
		}, -- Avenger's Shield
		{ 2812, 30, cat = "cc", ranks = { 10318, 27139, 48816, 48817 }, hide = true }, -- Holy Wrath
		{ 642, 300, cat = "defensive", buff = true }, -- Divine Shield
		{ 498, 180, cat = "defensive", buff = true }, -- Divine Protection
		{ 1022, 300, cat = "defensive", ranks = { 5599, 10278 }, buff = true }, -- Hand of Protection
		{ 6940, 120, cat = "defensive", buff = true }, -- Hand of Sacrifice
		{ 64205, 120, cat = "defensive", talent = true, tree = 2, points = 10, buff = true }, -- Divine Sacrifice
		{ 1044, 25, cat = "mobility", buff = true }, -- Hand of Freedom
		{ 31821, 120, cat = "defensive", talent = true, tree = 1, points = 15, buff = true }, -- Aura Mastery
		{ 633, 1200, cat = "defensive", ranks = { 2799, 10310, 27154, 48788 } }, -- Lay on Hands
		{ 19752, 600, cat = "utility", hide = true }, -- Divine Intervention
		{ 31884, 180, cat = "offensive", buff = true }, -- Avenging Wrath
		{ 20216, 120, cat = "offensive", talent = true, tree = 1, points = 20, preactive = true }, -- Divine Favor
		{ 31842, 180, cat = "utility", talent = true, tree = 1, points = 40, buff = true }, -- Divine Illumination
		{ 54428, 60, cat = "utility" }, -- Divine Plea
	},
	PRIEST = {
		{ 15487, 45, cat = "interrupt", talent = true, tree = 3, points = 20 }, -- Silence
		{ 64044, 120, cat = "cc", talent = true, tree = 3, points = 40 }, -- Psychic Horror
		{ 8122, 30, cat = "cc", ranks = { 8124, 10888, 10890 } }, -- Psychic Scream
		{ 33206, 180, cat = "defensive", talent = true, tree = 1, points = 45, buff = true }, -- Pain Suppression
		{ 47788, 180, cat = "defensive", talent = true, tree = 2, points = 50, buff = true }, -- Guardian Spirit
		{ 47585, 120, cat = "defensive", talent = true, tree = 3, points = 50, buff = true }, -- Dispersion
		{
			19236,
			120,
			cat = "defensive",
			ranks = { 19238, 19240, 19241, 19242, 19243, 25437, 48172, 48173 },
			talent = true,
			tree = 2,
			points = 10,
		}, -- Desperate Prayer
		{ 6346, 180, cat = "defensive", buff = true }, -- Fear Ward
		{ 586, 30, cat = "defensive", ranks = { 9578, 9579, 9592, 10941, 10942, 25429 }, buff = true, hide = true }, -- Fade
		{ 32379, 12, cat = "utility", ranks = { 32996, 48157, 48158 }, hide = true }, -- Shadow Word: Death
		{ 14751, 180, cat = "utility", talent = true, tree = 1, points = 10, preactive = true }, -- Inner Focus
		{ 10060, 120, cat = "offensive", talent = true, tree = 1, points = 30, buff = true }, -- Power Infusion
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
		{ 14185, 480, cat = "utility", talent = true, tree = 3, points = 20 }, -- Preparation
		{ 36554, 30, cat = "mobility", talent = true, tree = 3, points = 45 }, -- Shadowstep
		{ 2983, 180, cat = "mobility", ranks = { 8696, 11305 }, buff = true }, -- Sprint
		{ 51713, 60, cat = "offensive", talent = true, tree = 3, points = 50, buff = true }, -- Shadow Dance
		{ 14177, 180, cat = "offensive", talent = true, tree = 1, points = 20, preactive = true }, -- Cold Blood
		{ 13750, 180, cat = "offensive", talent = true, tree = 2, points = 30, buff = true }, -- Adrenaline Rush
		{ 51690, 120, cat = "offensive", talent = true, tree = 2, points = 50 }, -- Killing Spree
		{ 13877, 120, cat = "offensive", talent = true, tree = 2, points = 20, buff = true }, -- Blade Flurry
		{ 14183, 20, cat = "utility", talent = true, tree = 3, points = 30, hide = true }, -- Premeditation
		{ 57934, 30, cat = "utility", preactive = true, hide = true }, -- Tricks of the Trade
		{ 1784, 10, cat = "utility", ranks = { 1785, 1786, 1787 }, preactive = true, hide = true }, -- Stealth
	},
	SHAMAN = {
		{ 57994, 6, cat = "interrupt" }, -- Wind Shear
		{ 51514, 45, cat = "cc" }, -- Hex
		{ 8177, 15, cat = "defensive" }, -- Grounding Totem
		{ 2484, 15, cat = "utility", hide = true }, -- Earthbind Totem
		{ 51490, 45, cat = "cc", ranks = { 59156, 59158, 59159 }, talent = true, tree = 1, points = 50 }, -- Thunderstorm
		{ 30823, 60, cat = "defensive", talent = true, tree = 2, points = 45, buff = true }, -- Shamanistic Rage
		{ 16188, 120, cat = "utility", talent = true, tree = 3, points = 20, preactive = true }, -- Nature's Swiftness
		{ 16190, 300, cat = "utility", talent = true, tree = 3, points = 30 }, -- Mana Tide Totem
		{ 2825, 300, cat = "offensive", ranks = { 32182 }, buff = true }, -- Bloodlust / Heroism
		{ 16166, 180, cat = "offensive", talent = true, tree = 1, points = 30, preactive = true }, -- Elemental Mastery
		{ 51533, 180, cat = "offensive", talent = true, tree = 2, points = 50 }, -- Feral Spirit
		{ 55198, 180, cat = "utility", talent = true, tree = 3, points = 10, buff = true, hide = true }, -- Tidal Force
	},
	WARLOCK = {
		{ 19244, 24, cat = "interrupt", ranks = { 19647 }, pet = true }, -- Spell Lock
		{ 19505, 8, cat = "utility", ranks = { 19731, 19734, 19736, 27276, 27277 }, pet = true, hide = true }, -- Devour Magic
		{ 6789, 120, cat = "cc", ranks = { 17925, 17926, 27223, 47859, 47860 } }, -- Death Coil
		{ 5484, 40, cat = "cc", ranks = { 17928 } }, -- Howl of Terror
		{ 30283, 20, cat = "cc", ranks = { 30413, 30414, 47846, 47847 }, talent = true, tree = 3, points = 40 }, -- Shadowfury
		{ 54785, 45, cat = "mobility", talent = 59672, tree = 2, points = 50 }, -- Demon Charge
		{ 48020, 30, cat = "mobility" }, -- Demonic Circle: Teleport
		{ 6229, 30, cat = "defensive", ranks = { 11739, 11740, 28610, 47890, 47891 }, buff = true, hide = true }, -- Shadow Ward
		{ 47241, 180, cat = "offensive", talent = 59672, tree = 2, points = 50, buff = true }, -- Metamorphosis
		{ 47193, 60, cat = "utility", talent = true, tree = 2, points = 30, buff = true, hide = true }, -- Demonic Empowerment
		{ 18708, 180, cat = "utility", talent = true, tree = 2, points = 10, buff = true, hide = true }, -- Fel Domination
	},
	WARRIOR = {
		{ 6552, 10, cat = "interrupt", ranks = { 6554 } }, -- Pummel
		{ 72, 12, cat = "interrupt", ranks = { 1671, 1672, 29704 } }, -- Shield Bash
		{ 100, 15, cat = "mobility", ranks = { 6178, 11578 } }, -- Charge
		{ 20252, 30, cat = "mobility", ranks = { 20616, 20617, 25272, 25275 } }, -- Intercept
		{ 5246, 120, cat = "cc" }, -- Intimidating Shout
		{ 12809, 30, cat = "cc", talent = true, tree = 3, points = 20 }, -- Concussion Blow
		{ 46968, 20, cat = "cc", talent = true, tree = 3, points = 50 }, -- Shockwave
		{ 676, 60, cat = "cc" }, -- Disarm
		{ 23920, 10, cat = "defensive", buff = true }, -- Spell Reflection
		{ 3411, 30, cat = "mobility" }, -- Intervene
		{ 57755, 60, cat = "utility", hide = true }, -- Heroic Throw
		{ 871, 300, cat = "defensive", buff = true }, -- Shield Wall
		{ 12975, 180, cat = "defensive", talent = true, tree = 3, points = 10, buff = true }, -- Last Stand
		{ 55694, 180, cat = "defensive", buff = true }, -- Enraged Regeneration
		{ 2565, 60, cat = "defensive", buff = true, hide = true }, -- Shield Block
		{ 18499, 30, cat = "defensive", buff = true }, -- Berserker Rage
		{ 46924, 90, cat = "offensive", talent = true, tree = 1, points = 50, buff = true }, -- Bladestorm
		{ 12292, 180, cat = "offensive", talent = true, tree = 2, points = 25, buff = true }, -- Death Wish
		{ 1719, 300, cat = "offensive", buff = true }, -- Recklessness
		{ 20230, 300, cat = "defensive", buff = true }, -- Retaliation
		{ 60970, 45, cat = "mobility", talent = true, tree = 2, points = 45 }, -- Heroic Fury
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
		{ 1, 45, 55050, 55258, 55259, 55260, 55261, 55262 }, -- Heart Strike
		{ 2, 15, 51124 }, -- Killing Machine
		{ 2, 30, 59052 }, -- Freezing Fog
		{ 2, 45, 49143, 51416, 51417, 51418, 51419, 55268 }, -- Frost Strike
		{ 2, 50, 49184, 51409, 51410, 51411 }, -- Howling Blast
		{ 3, 15, 49194 }, -- Unholy Blight
		{ 3, 45, 55090, 55265, 55270, 55271 }, -- Scourge Strike
	},
	DRUID = {
		{ 1, 10, 16886 }, -- Nature's Grace
		{ 1, 20, 5570, 24974, 24975, 24976, 24977, 27013, 48468 }, -- Insect Swarm
		{ 1, 30, 24858 }, -- Moonkin Form
		{ 1, 35, 48391 }, -- Owlkin Frenzy
		{ 1, 40, 48517, 48518 }, -- Eclipse
		{ 2, 35, 17007 }, -- Leader of the Pack
		{ 2, 45, 33876, 33982, 33983, 48565, 48566, 33878, 33986, 33987, 48563, 48564 }, -- Mangle
		{ 3, 35, 48504 }, -- Living Seed
		{ 3, 40, 33891 }, -- Tree of Life
		{ 3, 50, 53248, 53249, 53250, 53251 }, -- Wild Growth
	},
	HUNTER = {
		{ 1, 45, 34692 }, -- The Beast Within
		{ 2, 10, 19434, 20900, 20901, 20902, 20903, 20904, 27065, 49049, 49050 }, -- Aimed Shot
		{ 2, 30, 19506 }, -- Trueshot Aura
		{ 2, 50, 53209 }, -- Chimera Shot
		{ 3, 20, 56453 }, -- Lock and Load
		{ 3, 35, 34837 }, -- Master Tactician
		{ 3, 45, 3674, 63668, 63669, 63670, 63671, 63672 }, -- Black Arrow
		{ 3, 50, 53301, 60051, 60052, 60053 }, -- Explosive Shot
	},
	MAGE = {
		{ 1, 15, 54646 }, -- Focus Magic
		{ 1, 40, 44413 }, -- Incanter's Absorption
		{ 1, 45, 31589 }, -- Slow
		{ 1, 50, 44401 }, -- Missile Barrage
		{ 1, 50, 44425, 44780, 44781 }, -- Arcane Barrage
		{ 2, 10, 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132, 33938, 42890, 42891 }, -- Pyroblast
		{ 2, 45, 48108 }, -- Hot Streak
		{ 2, 50, 44457, 55359, 55360 }, -- Living Bomb
		{ 3, 40, 44544 }, -- Fingers of Frost
		{ 3, 40, 57761 }, -- Brain Freeze
	},
	PALADIN = {
		{ 1, 30, 20473, 20929, 20930, 27174, 33072, 48824, 48825 }, -- Holy Shock
		{ 1, 45, 53672, 54149 }, -- Infusion of Light
		{ 1, 50, 53563 }, -- Beacon of Light
		{ 2, 20, 20911, 25899 }, -- Blessing of Sanctuary
		{ 2, 20, 20178 }, -- Reckoning
		{ 2, 30, 20925, 20927, 20928, 27179, 48951, 48952 }, -- Holy Shield
		{ 2, 50, 53595 }, -- Hammer of the Righteous
		{ 3, 10, 20375 }, -- Seal of Command
		{ 3, 35, 59578 }, -- The Art of War
		{ 3, 40, 31930 }, -- Judgements of the Wise
		{ 3, 50, 35395 }, -- Crusader Strike
		{ 3, 50, 53385 }, -- Divine Storm
	},
	PRIEST = {
		{ 1, 35, 63944 }, -- Renewed Hope
		{ 1, 40, 47753 }, -- Divine Aegis
		{ 1, 45, 47930 }, -- Grace
		{ 1, 50, 59887, 59888, 59889, 59890, 59891 }, -- Borrowed Time
		{ 1, 50, 47540, 53005, 53006, 53007 }, -- Penance
		{ 2, 20, 27827 }, -- Spirit of Redemption
		{ 2, 25, 33151 }, -- Surge of Light
		{ 2, 30, 724 }, -- Lightwell
		{ 2, 35, 65081 }, -- Body and Soul
		{ 2, 40, 63731, 63734, 63735 }, -- Serendipity
		{ 2, 45, 34861, 34863, 34864, 34865, 34866, 48088, 48089 }, -- Circle of Healing
		{ 3, 10, 15407, 17311, 17312, 17313, 17314, 18807, 25387, 48155, 48156 }, -- Mind Flay
		{ 3, 20, 15286 }, -- Vampiric Embrace
		{ 3, 30, 15473 }, -- Shadowform
		{ 3, 40, 34914, 34916, 34917, 48159, 48160 }, -- Vampiric Touch
	},
	ROGUE = {
		{ 1, 30, 58426, 58427 }, -- Overkill
		{ 1, 45, 1329, 34411, 34412, 34413, 48663, 48666 }, -- Mutilate
		{ 1, 45, 52910, 52914, 52915 }, -- Turn the Tables
		{ 1, 50, 51662 }, -- Hunger for Blood
		{ 2, 10, 14251 }, -- Riposte
		{ 2, 45, 58684 }, -- Savage Combat
		{ 3, 10, 14278 }, -- Ghostly Strike
		{ 3, 25, 16511, 17347, 17348, 26864, 48660 }, -- Hemorrhage
		{ 3, 25, 31665 }, -- Master of Subtlety
		{ 3, 30, 45182 }, -- Cheat Death
	},
	SHAMAN = {
		{ 1, 10, 16246 }, -- Clearcasting
		{ 1, 40, 30706, 57720, 57721, 57722 }, -- Totem of Wrath
		{ 1, 40, 51466, 51470 }, -- Elemental Oath
		{ 2, 15, 16257, 16277, 16278, 16279, 16280 }, -- Flurry
		{ 2, 25, 30802, 30808, 30809, 30810, 30811 }, -- Unleashed Rage
		{ 2, 35, 17364 }, -- Stormstrike
		{ 2, 40, 60103 }, -- Lava Lash
		{ 2, 50, 53817 }, -- Maelstrom Weapon
		{ 3, 30, 31616 }, -- Nature's Guardian
		{ 3, 30, 51886 }, -- Cleanse Spirit
		{ 3, 40, 52752 }, -- Ancestral Awakening
		{ 3, 45, 974, 32593, 32594, 49283, 49284 }, -- Earth Shield
		{ 3, 50, 53390 }, -- Tidal Waves
		{ 3, 50, 61295, 61299, 61300, 61301 }, -- Riptide
	},
	WARLOCK = {
		{ 1, 25, 32386, 32388, 32389, 32390, 32391 }, -- Shadow Embrace
		{ 1, 35, 64368, 64370, 64371 }, -- Eradication
		{ 1, 40, 30108, 30404, 30405, 47841, 47843 }, -- Unstable Affliction
		{ 1, 50, 48181, 59161, 59163, 59164 }, -- Haunt
		{ 2, 25, 47383 }, -- Molten Core
		{ 2, 35, 63165, 63167 }, -- Decimation
		{ 2, 40, 30146 }, -- Summon Felguard
		{ 3, 10, 17877, 18867, 18868, 18869, 18870, 18871, 27263, 30546, 47826, 47827 }, -- Shadowburn
		{ 3, 30, 17962 }, -- Conflagrate
		{ 3, 45, 54274, 54276, 54277 }, -- Backdraft
		{ 3, 50, 50796, 59170, 59171, 59172 }, -- Chaos Bolt
	},
	WARRIOR = {
		{ 1, 20, 12328 }, -- Sweeping Strikes
		{ 1, 20, 60503 }, -- Taste for Blood
		{ 1, 30, 46856, 46857 }, -- Trauma
		{ 1, 35, 12294, 21551, 21552, 21553, 25248, 30330, 47485, 47486 }, -- Mortal Strike
		{ 1, 45, 65156 }, -- Juggernaut
		{ 1, 50, 52437 }, -- Sudden Death
		{ 1, 50, 30069, 30070 }, -- Blood Frenzy
		{ 2, 20, 12880, 14201, 14202, 14203, 14204 }, -- Enrage
		{ 2, 30, 12966, 12967, 12968, 12969, 12970 }, -- Flurry
		{ 2, 35, 23881 }, -- Bloodthirst
		{ 2, 45, 29801 }, -- Rampage
		{ 2, 50, 46916 }, -- Bloodsurge
		{ 3, 30, 50720 }, -- Vigilance
		{ 3, 40, 20243, 30016, 30022, 47497, 47498 }, -- Devastate
		{ 3, 45, 50227 }, -- Sword and Board
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
for class, spells in pairs(SPELLS) do
	for i = 1, #spells do
		local entry = spells[i]
		if entry.tree then
			local hint = { class = class, tree = entry.tree, points = entry.points }
			specHints[entry[1]] = hint
			local ranks = entry.ranks
			if ranks then
				for j = 1, #ranks do
					specHints[ranks[j]] = hint
				end
			end
		end
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
