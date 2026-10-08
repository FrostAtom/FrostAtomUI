local _, ns = ...

local GetSpellInfo = GetSpellInfo

local Data = {}
ns.SpellAlertData = Data

Data.VOICE_PATH = "Interface\\AddOns\\FrostAtomUI\\Media\\Voice\\%s.wav"
Data.DEFAULT_LENGTH = 1
Data.LENGTHS = {
	adrenalineRush = 0.91,
	antiMagicShell = 0.94,
	antiMagicShellDown = 1.17,
	antiMagicZone = 0.98,
	arcanePower = 0.81,
	auraMastery = 0.75,
	avengingWrath = 0.82,
	banish = 0.5,
	banishDown = 0.73,
	banishYou = 0.72,
	barkskin = 0.65,
	bash = 0.49,
	bashYou = 0.61,
	berserk = 0.62,
	berserkerRage = 0.88,
	berserking = 0.69,
	bestialWrath = 0.76,
	bladestorm = 0.65,
	blind = 0.51,
	blindDown = 0.69,
	blindYou = 0.7,
	bloodFury = 0.68,
	bloodlust = 0.61,
	cheapShot = 0.66,
	cheapShotYou = 0.81,
	cheatingDeath = 0.73,
	cloakOfShadows = 0.84,
	cloakOfShadowsDown = 1.07,
	coldBlood = 0.74,
	coldSnap = 0.7,
	combustion = 0.66,
	concussionBlow = 0.93,
	concussionBlowYou = 1.17,
	cyclone = 0.64,
	cycloneDown = 0.86,
	cycloneYou = 0.84,
	dancingRuneWeapon = 1.13,
	deathCoil = 0.63,
	deathCoilYou = 0.86,
	deathGrip = 0.63,
	deathWish = 0.63,
	deepFreeze = 0.71,
	deepFreezeYou = 0.86,
	demonicCircleTeleport = 0.88,
	deterrence = 0.67,
	deterrenceDown = 0.88,
	disarm = 0.56,
	disarmYou = 0.77,
	dismantle = 0.71,
	dismantleYou = 0.96,
	dispersion = 0.7,
	divineHymn = 0.69,
	divinePlea = 0.72,
	divineProtection = 0.95,
	divineSacrifice = 1.03,
	divineShield = 0.79,
	divineShieldDown = 1.03,
	dragonsBreath = 0.87,
	dragonsBreathDown = 1.13,
	dragonsBreathYou = 1.09,
	drinking = 0.55,
	earthbindTotem = 0.88,
	elementalMastery = 1.06,
	enragedRegeneration = 1.19,
	entanglingRoots = 1.06,
	entanglingRootsYou = 1.28,
	evasion = 0.56,
	evocation = 0.76,
	fear = 0.45,
	fearDown = 0.65,
	fearWard = 0.68,
	fearYou = 0.64,
	feignDeath = 0.67,
	feralSpirit = 0.83,
	freezingArrow = 0.77,
	freezingArrowDown = 1.04,
	freezingArrowYou = 1.04,
	freezingTrap = 0.84,
	freezingTrapDown = 1.07,
	freezingTrapYou = 1.04,
	frenziedRegeneration = 1.3,
	garroteSilence = 0.52,
	garroteSilenceYou = 0.73,
	gnaw = 0.42,
	gnawYou = 0.63,
	gouge = 0.44,
	gougeDown = 0.64,
	gougeYou = 0.64,
	groundingTotem = 0.86,
	guardianSpirit = 0.89,
	hammerOfJustice = 0.94,
	hammerOfJusticeYou = 1.25,
	handOfFreedom = 0.84,
	handOfProtection = 0.98,
	handOfProtectionDown = 1.25,
	handOfSacrifice = 1.07,
	heroism = 0.7,
	hex = 0.49,
	hexDown = 0.67,
	hexYou = 0.71,
	hibernate = 0.63,
	hibernateDown = 0.87,
	hibernateYou = 0.88,
	howlOfTerror = 0.85,
	hungeringCold = 0.91,
	hungeringColdDown = 1.19,
	hungeringColdYou = 1.16,
	hymnOfHope = 0.7,
	hysteria = 0.66,
	iceBlock = 0.68,
	iceBlockDown = 0.93,
	iceboundFortitude = 1.12,
	icyVeins = 0.75,
	innerFocus = 0.79,
	innervate = 0.6,
	interrupted = 0.68,
	intimidatingShout = 1.03,
	intimidatingShoutDown = 1.3,
	intimidatingShoutYou = 1.27,
	intimidation = 0.85,
	intimidationYou = 1.06,
	invisibility = 0.85,
	kidneyShot = 0.69,
	kidneyShotYou = 0.91,
	killingSpree = 0.78,
	layOnHands = 0.82,
	lichborne = 0.6,
	maim = 0.44,
	maimYou = 0.63,
	manaTideTotem = 1.05,
	massDispel = 0.79,
	mastersCall = 0.81,
	metamorphosis = 0.93,
	mindControl = 0.81,
	mindControlYou = 0.97,
	mirrorImage = 0.75,
	naturesSwiftness = 0.99,
	painSuppression = 0.84,
	polymorph = 0.64,
	polymorphDown = 0.82,
	polymorphYou = 0.85,
	powerInfusion = 0.89,
	preparation = 0.75,
	presenceOfMind = 0.89,
	prowl = 0.49,
	psychicHorror = 0.74,
	psychicHorrorYou = 1.02,
	psychicScream = 0.83,
	psychicScreamDown = 1.02,
	psychicScreamYou = 1.01,
	rapidFire = 0.77,
	readiness = 0.6,
	recklessness = 0.73,
	repentance = 0.75,
	repentanceDown = 0.91,
	repentanceYou = 0.96,
	retaliation = 0.85,
	roarOfSacrifice = 1.01,
	sap = 0.45,
	sapDown = 0.68,
	sapYou = 0.66,
	scareBeast = 0.75,
	scareBeastDown = 0.99,
	scareBeastYou = 0.97,
	scatterShot = 0.77,
	scatterShotDown = 1.0,
	scatterShotYou = 1.04,
	seduction = 0.66,
	seductionDown = 0.91,
	seductionYou = 0.88,
	shackleUndead = 0.82,
	shackleUndeadDown = 1.1,
	shackleUndeadYou = 1.03,
	shadowDance = 0.8,
	shadowfiend = 0.73,
	shadowfury = 0.71,
	shadowfuryYou = 0.98,
	shadowmeld = 0.69,
	shadowstep = 0.74,
	shamanisticRage = 1.07,
	shatteringThrow = 0.83,
	shieldWall = 0.69,
	shockwave = 0.63,
	shockwaveYou = 0.81,
	silence = 0.58,
	silenceYou = 0.83,
	silencingShot = 0.91,
	silencingShotYou = 1.12,
	spellReflection = 0.92,
	starfall = 0.63,
	stealth = 0.54,
	stoneform = 0.65,
	strangulate = 0.74,
	strangulateYou = 0.98,
	summonGargoyle = 0.89,
	survivalInstincts = 1.15,
	tremorTotem = 0.8,
	trinket = 0.57,
	trinketDeathKnight = 0.96,
	trinketDruid = 0.87,
	trinketHunter = 0.91,
	trinketMage = 0.8,
	trinketPaladin = 0.95,
	trinketPriest = 0.85,
	trinketRogue = 0.79,
	trinketShaman = 0.91,
	trinketWarlock = 0.99,
	trinketWarrior = 0.93,
	turnEvil = 0.66,
	turnEvilDown = 0.94,
	turnEvilYou = 0.97,
	vampiricBlood = 0.9,
	vanish = 0.53,
	willOfTheForsaken = 1.01,
	wyvernSting = 0.78,
	wyvernStingDown = 1.0,
	wyvernStingYou = 1.0,
}

Data.CATEGORIES = { "cast", "control", "defensive", "offensive", "utility" }

Data.CATEGORY_NAMES = {
	cast = "Crowd control casts",
	control = "Crowd control on allies",
	defensive = "Defensive abilities",
	offensive = "Offensive cooldowns",
	utility = "Other abilities",
}

local EVENTS = {
	cast = "start",
	control = "control",
	defensive = "aura",
	offensive = "aura",
	utility = "success",
}

local PRIORITIES = {
	cast = 2,
	control = 2,
	defensive = 1,
	offensive = 1,
	utility = 1,
}

Data.SPELLS = {
	cast = {
		{ key = "polymorph", down = true, 118, 12824, 12825, 12826, 28271, 28272, 61025, 61305, 61721, 61780, 71319 }, -- Polymorph
		{ key = "hex", down = true, 51514 }, -- Hex
		{ key = "cyclone", down = true, 33786 }, -- Cyclone
		{ key = "fear", down = true, 5782, 6213, 6215 }, -- Fear
		{ key = "howlOfTerror", area = true, 5484, 17928 }, -- Howl of Terror
		{ key = "seduction", down = true, 6358 }, -- Seduction
		{ key = "mindControl", 605 }, -- Mind Control
		{ key = "massDispel", area = true, 32375 }, -- Mass Dispel
		{ key = "hibernate", down = true, 2637, 18657, 18658 }, -- Hibernate
		{ key = "turnEvil", down = true, 10326 }, -- Turn Evil
		{ key = "entanglingRoots", 339, 1062, 5195, 5196, 9852, 9853, 26989, 53308 }, -- Entangling Roots
		{ key = "scareBeast", down = true, 1513, 14326, 14327 }, -- Scare Beast
		{ key = "banish", down = true, 710, 18647 }, -- Banish
		{ key = "shackleUndead", down = true, 9484, 9485, 10955 }, -- Shackle Undead
	},
	control = {
		{ key = "blind", down = true, 2094 }, -- Blind
		{ key = "repentance", down = true, 20066 }, -- Repentance
		{ key = "sap", down = true, 2070, 6770, 11297, 51724 }, -- Sap
		{ key = "gouge", down = true, 1776 }, -- Gouge
		{ key = "hammerOfJustice", 853, 5588, 5589, 10308 }, -- Hammer of Justice
		{ key = "deepFreeze", 44572 }, -- Deep Freeze
		{ key = "kidneyShot", 408, 8643 }, -- Kidney Shot
		{ key = "psychicScream", down = true, 8122, 8124, 10888, 10890 }, -- Psychic Scream
		{ key = "psychicHorror", 64044 }, -- Psychic Horror
		{ key = "intimidatingShout", down = true, 5246, 20511 }, -- Intimidating Shout
		{ key = "deathCoil", 6789, 17925, 17926, 27223, 47859, 47860 }, -- Death Coil
		{ key = "freezingTrap", down = true, 3355, 14308, 14309, 55041 }, -- Freezing Trap Effect
		{ key = "freezingArrow", down = true, 60210 }, -- Freezing Arrow Effect
		{ key = "wyvernSting", down = true, 19386, 24132, 24133, 27068, 49011, 49012 }, -- Wyvern Sting
		{ key = "scatterShot", down = true, 19503 }, -- Scatter Shot
		{ key = "dragonsBreath", down = true, 31661, 33041, 33042, 33043, 42949, 42950 }, -- Dragon's Breath
		{ key = "hungeringCold", down = true, 51209 }, -- Hungering Cold
		{ key = "silencingShot", 34490 }, -- Silencing Shot
		{ key = "strangulate", 47476 }, -- Strangulate
		{ key = "silence", 15487 }, -- Silence
		{ key = "disarm", 676 }, -- Disarm
		{ key = "dismantle", 51722 }, -- Dismantle
		{ key = "shadowfury", off = true, 30283, 30413, 30414, 47846, 47847 }, -- Shadowfury
		{ key = "cheapShot", off = true, 1833 }, -- Cheap Shot
		{ key = "bash", off = true, 5211, 6798, 8983 }, -- Bash
		{ key = "maim", off = true, 22570, 49802 }, -- Maim
		{ key = "shockwave", off = true, 46968 }, -- Shockwave
		{ key = "concussionBlow", off = true, 12809 }, -- Concussion Blow
		{ key = "intimidation", off = true, 24394 }, -- Intimidation
		{ key = "gnaw", off = true, 47481 }, -- Gnaw
		{ key = "garroteSilence", off = true, 1330 }, -- Garrote - Silence
	},
	defensive = {
		{ key = "divineShield", down = true, priority = 2, 642 }, -- Divine Shield
		{ key = "iceBlock", down = true, priority = 2, 45438 }, -- Ice Block
		{ key = "handOfProtection", down = true, 1022, 5599, 10278 }, -- Hand of Protection
		{ key = "deterrence", down = true, 19263 }, -- Deterrence
		{ key = "cloakOfShadows", down = true, 31224 }, -- Cloak of Shadows
		{ key = "antiMagicShell", down = true, 48707 }, -- Anti-Magic Shell
		{ key = "evasion", 5277, 26669 }, -- Evasion
		{ key = "painSuppression", 33206 }, -- Pain Suppression
		{ key = "guardianSpirit", 47788 }, -- Guardian Spirit
		{ key = "dispersion", 47585 }, -- Dispersion
		{ key = "barkskin", 22812 }, -- Barkskin
		{ key = "survivalInstincts", 61336 }, -- Survival Instincts
		{ key = "shieldWall", 871 }, -- Shield Wall
		{ key = "spellReflection", 23920 }, -- Spell Reflection
		{ key = "iceboundFortitude", 48792 }, -- Icebound Fortitude
		{ key = "lichborne", 49039 }, -- Lichborne
		{ key = "shamanisticRage", 30823 }, -- Shamanistic Rage
		{ key = "divineProtection", 498 }, -- Divine Protection
		{ key = "handOfFreedom", 1044 }, -- Hand of Freedom
		{ key = "handOfSacrifice", 6940 }, -- Hand of Sacrifice
		{ key = "divineSacrifice", 64205 }, -- Divine Sacrifice
		{ key = "auraMastery", 31821 }, -- Aura Mastery
		{ key = "fearWard", 6346 }, -- Fear Ward
		{ key = "enragedRegeneration", 55694 }, -- Enraged Regeneration
		{ key = "cheatingDeath", 45182 }, -- Cheating Death
		{ key = "berserkerRage", 18499 }, -- Berserker Rage
		{ key = "retaliation", 20230 }, -- Retaliation
		{ key = "layOnHands", event = "success", 633, 2800, 10310, 27154, 48788 }, -- Lay on Hands
		{ key = "groundingTotem", event = "success", 8177 }, -- Grounding Totem
		{ key = "antiMagicZone", event = "success", 51052 }, -- Anti-Magic Zone
		{ key = "roarOfSacrifice", 53480 }, -- Roar of Sacrifice
		{ key = "frenziedRegeneration", off = true, 22842 }, -- Frenzied Regeneration
		{ key = "vampiricBlood", off = true, 55233 }, -- Vampiric Blood
		{ key = "stoneform", off = true, hidden = true, 20594 }, -- Stoneform
	},
	offensive = {
		{ key = "avengingWrath", 31884 }, -- Avenging Wrath
		{ key = "arcanePower", 12042 }, -- Arcane Power
		{ key = "icyVeins", 12472 }, -- Icy Veins
		{ key = "combustion", 28682 }, -- Combustion
		{ key = "presenceOfMind", 12043 }, -- Presence of Mind
		{ key = "bestialWrath", 19574, 34471 }, -- Bestial Wrath, The Beast Within
		{ key = "recklessness", 1719 }, -- Recklessness
		{ key = "deathWish", 12292 }, -- Death Wish
		{ key = "bladestorm", 46924 }, -- Bladestorm
		{ key = "shadowDance", 51713 }, -- Shadow Dance
		{ key = "adrenalineRush", 13750 }, -- Adrenaline Rush
		{ key = "killingSpree", 51690 }, -- Killing Spree
		{ key = "berserk", 50334 }, -- Berserk
		{ key = "elementalMastery", 16166 }, -- Elemental Mastery
		{ key = "bloodlust", 2825 }, -- Bloodlust
		{ key = "heroism", 32182 }, -- Heroism
		{ key = "powerInfusion", 10060 }, -- Power Infusion
		{ key = "naturesSwiftness", 17116, 16188 }, -- Nature's Swiftness
		{ key = "metamorphosis", 47241 }, -- Metamorphosis
		{ key = "starfall", 48505, 53199, 53200, 53201 }, -- Starfall
		{ key = "summonGargoyle", event = "success", 49206 }, -- Summon Gargoyle
		{ key = "feralSpirit", event = "success", 51533 }, -- Feral Spirit
		{ key = "shadowfiend", event = "success", 34433 }, -- Shadowfiend
		{ key = "rapidFire", off = true, 3045 }, -- Rapid Fire
		{ key = "coldBlood", off = true, 14177 }, -- Cold Blood
		{ key = "hysteria", off = true, 49016 }, -- Hysteria
		{ key = "innerFocus", off = true, 14751 }, -- Inner Focus
		{ key = "berserking", off = true, 26297 }, -- Berserking
		{ key = "bloodFury", off = true, 20572, 33697, 33702 }, -- Blood Fury
		{ key = "dancingRuneWeapon", off = true, event = "success", 49028 }, -- Dancing Rune Weapon
		{ key = "mirrorImage", off = true, event = "success", 55342 }, -- Mirror Image
	},
	utility = {
		{ key = "trinket", priority = 2, class = true, 42292, 59752 }, -- PvP Trinket, Every Man for Himself
		{ key = "shatteringThrow", event = "start", priority = 2, 64382 }, -- Shattering Throw
		{ key = "willOfTheForsaken", 7744 }, -- Will of the Forsaken
		{ key = "coldSnap", 11958 }, -- Cold Snap
		{ key = "preparation", 14185 }, -- Preparation
		{ key = "readiness", 23989 }, -- Readiness
		{ key = "vanish", 1856, 1857, 26889 }, -- Vanish
		{ key = "shadowmeld", 58984 }, -- Shadowmeld
		{ key = "invisibility", 66 }, -- Invisibility
		{ key = "manaTideTotem", 16190 }, -- Mana Tide Totem
		{ key = "tremorTotem", 8143 }, -- Tremor Totem
		{ key = "deathGrip", 49576 }, -- Death Grip
		{ key = "mastersCall", 53271 }, -- Master's Call
		{ key = "evocation", 12051 }, -- Evocation
		{ key = "divineHymn", 64843 }, -- Divine Hymn
		{ key = "drinking", event = "aura", byName = true, arena = true, 57073 }, -- Drink
		{ key = "hymnOfHope", 64901 }, -- Hymn of Hope
		{ key = "innervate", 29166 }, -- Innervate
		{ key = "divinePlea", 54428 }, -- Divine Plea
		{ key = "stealth", 1784 }, -- Stealth
		{ key = "prowl", 5215 }, -- Prowl
		{ key = "demonicCircleTeleport", 48020 }, -- Demonic Circle: Teleport
		{ key = "feignDeath", off = true, hidden = true, 5384 }, -- Feign Death
		{ key = "shadowstep", off = true, 36554 }, -- Shadowstep
		{ key = "earthbindTotem", off = true, 2484 }, -- Earthbind Totem
	},
}

Data.CLASS_SOUNDS = {
	DEATHKNIGHT = "DeathKnight",
	DRUID = "Druid",
	HUNTER = "Hunter",
	MAGE = "Mage",
	PALADIN = "Paladin",
	PRIEST = "Priest",
	ROGUE = "Rogue",
	SHAMAN = "Shaman",
	WARLOCK = "Warlock",
	WARRIOR = "Warrior",
}

local CASTER_CLASSES = {
	DEATHKNIGHT = {
		"hungeringCold",
		"strangulate",
		"gnaw",
		"antiMagicShell",
		"iceboundFortitude",
		"lichborne",
		"antiMagicZone",
		"vampiricBlood",
		"summonGargoyle",
		"hysteria",
		"dancingRuneWeapon",
		"deathGrip",
	},
	DRUID = {
		"cyclone",
		"hibernate",
		"entanglingRoots",
		"bash",
		"maim",
		"barkskin",
		"survivalInstincts",
		"frenziedRegeneration",
		"berserk",
		"starfall",
		"innervate",
		"prowl",
	},
	HUNTER = {
		"scareBeast",
		"freezingTrap",
		"freezingArrow",
		"wyvernSting",
		"scatterShot",
		"silencingShot",
		"intimidation",
		"deterrence",
		"roarOfSacrifice",
		"bestialWrath",
		"rapidFire",
		"mastersCall",
		"readiness",
		"feignDeath",
	},
	MAGE = {
		"polymorph",
		"deepFreeze",
		"dragonsBreath",
		"iceBlock",
		"arcanePower",
		"icyVeins",
		"combustion",
		"presenceOfMind",
		"mirrorImage",
		"coldSnap",
		"invisibility",
		"evocation",
	},
	PALADIN = {
		"turnEvil",
		"repentance",
		"hammerOfJustice",
		"divineShield",
		"handOfProtection",
		"divineProtection",
		"handOfFreedom",
		"handOfSacrifice",
		"divineSacrifice",
		"auraMastery",
		"layOnHands",
		"avengingWrath",
		"divinePlea",
	},
	PRIEST = {
		"mindControl",
		"massDispel",
		"shackleUndead",
		"psychicScream",
		"psychicHorror",
		"silence",
		"painSuppression",
		"guardianSpirit",
		"dispersion",
		"fearWard",
		"powerInfusion",
		"shadowfiend",
		"innerFocus",
		"divineHymn",
		"hymnOfHope",
	},
	ROGUE = {
		"blind",
		"sap",
		"gouge",
		"kidneyShot",
		"dismantle",
		"cheapShot",
		"garroteSilence",
		"evasion",
		"cloakOfShadows",
		"cheatingDeath",
		"shadowDance",
		"adrenalineRush",
		"killingSpree",
		"coldBlood",
		"preparation",
		"vanish",
		"stealth",
		"shadowstep",
	},
	SHAMAN = {
		"hex",
		"groundingTotem",
		"shamanisticRage",
		"elementalMastery",
		"bloodlust",
		"heroism",
		"feralSpirit",
		"manaTideTotem",
		"tremorTotem",
		"earthbindTotem",
	},
	WARLOCK = {
		"fear",
		"howlOfTerror",
		"seduction",
		"banish",
		"deathCoil",
		"shadowfury",
		"metamorphosis",
		"demonicCircleTeleport",
	},
	WARRIOR = {
		"intimidatingShout",
		"disarm",
		"shockwave",
		"concussionBlow",
		"shieldWall",
		"spellReflection",
		"enragedRegeneration",
		"berserkerRage",
		"retaliation",
		"recklessness",
		"deathWish",
		"bladestorm",
		"shatteringThrow",
	},
}

local casterClass = {}
for class, keys in pairs(CASTER_CLASSES) do
	for _, key in ipairs(keys) do
		casterClass[key] = class
	end
end

local maps = {
	start = {},
	success = {},
	aura = {},
	control = {},
}
local auraNames, castNames, myControl, controlOnYou = {}, {}, {}, {}

for category, spells in pairs(Data.SPELLS) do
	local crowdControl = category == "cast" or category == "control"
	for _, spell in ipairs(spells) do
		spell.category = category
		spell.priority = spell.priority or PRIORITIES[category]
		spell.sound = spell.key
		spell.youSound = crowdControl and not spell.area and spell.key .. "You" or spell.key
		spell.downSound = spell.down and spell.key .. "Down"
		spell.casterClass = casterClass[spell.key]
		local map = maps[spell.event or EVENTS[category]]
		if spell.byName then
			local name = GetSpellInfo(spell[1])
			if name then
				auraNames[name] = spell
			end
		else
			for i = 1, #spell do
				map[spell[i]] = spell
				if crowdControl and spell.down then
					myControl[spell[i]] = spell
				end
				if category == "cast" and not spell.area then
					controlOnYou[spell[i]] = spell
				end
			end
		end
		if spell.hidden then
			local name = GetSpellInfo(spell[1])
			if name then
				castNames[name] = spell
			end
		end
	end
end

Data.START = maps.start
Data.SUCCESS = maps.success
Data.AURA = maps.aura
Data.AURA_NAMES = auraNames
Data.CONTROL = maps.control
Data.CAST_NAMES = castNames
Data.MY_CONTROL = myControl
Data.CONTROL_ON_YOU = controlOnYou
