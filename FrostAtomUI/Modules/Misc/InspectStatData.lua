local _, ns = ...

local Data = {}
ns.InspectStatData = Data

Data.LEVEL = 80

Data.BASE_STATS = {
	WARRIOR = {
		Human = { 174, 113, 159, 36, 59 },
		Orc = { 177, 110, 160, 33, 61 },
		Dwarf = { 179, 109, 160, 35, 58 },
		NightElf = { 170, 117, 159, 36, 59 },
		Scourge = { 173, 111, 159, 34, 64 },
		Tauren = { 179, 109, 160, 32, 61 },
		Gnome = { 169, 115, 159, 39, 59 },
		Troll = { 175, 115, 159, 32, 60 },
		Draenei = { 175, 110, 159, 36, 61 },
	},
	PALADIN = {
		Human = { 151, 90, 143, 98, 105 },
		Dwarf = { 156, 86, 144, 97, 104 },
		BloodElf = { 148, 92, 143, 101, 103 },
		Draenei = { 152, 87, 143, 98, 107 },
	},
	HUNTER = {
		Orc = { 77, 178, 129, 87, 99 },
		Dwarf = { 79, 177, 129, 89, 96 },
		NightElf = { 70, 185, 128, 90, 97 },
		Tauren = { 79, 177, 129, 86, 99 },
		Troll = { 75, 183, 128, 86, 98 },
		BloodElf = { 71, 183, 128, 93, 95 },
		Draenei = { 75, 178, 128, 90, 99 },
	},
	ROGUE = {
		Human = { 113, 189, 105, 43, 67 },
		Orc = { 116, 186, 106, 40, 69 },
		Dwarf = { 118, 185, 106, 42, 66 },
		NightElf = { 109, 193, 105, 43, 67 },
		Scourge = { 112, 187, 105, 41, 72 },
		Gnome = { 108, 191, 105, 46, 67 },
		Troll = { 114, 191, 105, 39, 68 },
		BloodElf = { 110, 191, 105, 46, 65 },
	},
	PRIEST = {
		Human = { 43, 51, 67, 174, 181 },
		Dwarf = { 48, 47, 68, 173, 180 },
		NightElf = { 39, 55, 67, 174, 181 },
		Scourge = { 42, 49, 67, 172, 186 },
		Troll = { 44, 53, 67, 170, 182 },
		BloodElf = { 40, 53, 67, 177, 179 },
		Draenei = { 44, 48, 67, 174, 183 },
	},
	DEATHKNIGHT = {
		Human = { 175, 112, 160, 35, 59 },
		Orc = { 178, 109, 161, 32, 61 },
		Dwarf = { 180, 108, 161, 34, 58 },
		NightElf = { 171, 116, 160, 35, 59 },
		Scourge = { 174, 110, 160, 33, 64 },
		Tauren = { 180, 108, 161, 31, 61 },
		Gnome = { 170, 114, 160, 38, 59 },
		Troll = { 176, 114, 160, 31, 60 },
		BloodElf = { 172, 114, 160, 38, 57 },
		Draenei = { 176, 109, 160, 35, 61 },
	},
	SHAMAN = {
		Orc = { 123, 71, 137, 125, 145 },
		Tauren = { 125, 70, 137, 124, 145 },
		Troll = { 121, 76, 136, 124, 144 },
		Draenei = { 121, 71, 136, 128, 145 },
	},
	MAGE = {
		Human = { 36, 43, 59, 181, 174 },
		Scourge = { 35, 41, 59, 179, 179 },
		Gnome = { 31, 45, 59, 184, 174 },
		Troll = { 37, 45, 59, 177, 175 },
		BloodElf = { 33, 45, 59, 184, 172 },
		Draenei = { 37, 40, 59, 181, 176 },
	},
	WARLOCK = {
		Human = { 59, 67, 89, 159, 166 },
		Orc = { 62, 64, 90, 156, 168 },
		Scourge = { 58, 65, 89, 157, 171 },
		Gnome = { 54, 69, 89, 162, 166 },
		BloodElf = { 56, 69, 89, 162, 164 },
	},
	DRUID = {
		NightElf = { 85, 86, 98, 143, 159 },
		Tauren = { 94, 78, 99, 139, 161 },
	},
}

Data.CLASS = {
	WARRIOR = {
		meleeCrit = { 0.031891, 0.00016 },
		dodge = { 0.036640, 0.85 / 1.15, 88.129021 },
		parryCap = 47.003525,
		k = 0.956,
		melee = "warrior",
	},
	PALADIN = {
		meleeCrit = { 0.032685, 0.000192 },
		spellCrit = { 0.033355, 0.00006 },
		dodge = { 0.034943, 1.00 / 1.15, 88.129021 },
		parryCap = 47.003525,
		k = 0.956,
		hasteScalar = 1.3,
		melee = "warrior",
	},
	HUNTER = {
		meleeCrit = { -0.01532, 0.00012 },
		spellCrit = { 0.03602, 0.00006 },
		dodge = { -0.040873, 1.11 / 1.15, 145.560408 },
		parryCap = 145.560408,
		k = 0.988,
		melee = "agile",
	},
	ROGUE = {
		meleeCrit = { -0.00295, 0.00012 },
		dodge = { 0.020957, 2.00 / 1.15, 145.560408 },
		parryCap = 145.560408,
		k = 0.988,
		melee = "agile",
	},
	PRIEST = {
		meleeCrit = { 0.031765, 0.000192 },
		spellCrit = { 0.012375, 0.00006 },
		dodge = { 0.034178, 1.00 / 1.15, 150.375940 },
		k = 0.983,
		melee = "caster",
	},
	DEATHKNIGHT = {
		meleeCrit = { 0.031891, 0.00016 },
		dodge = { 0.036640, 0.85 / 1.15, 88.129021 },
		parryCap = 47.003525,
		k = 0.956,
		hasteScalar = 1.3,
		melee = "warrior",
	},
	SHAMAN = {
		meleeCrit = { 0.02922, 0.00012 },
		spellCrit = { 0.02201, 0.00006 },
		dodge = { 0.021080, 1.60 / 1.15, 145.560408 },
		k = 0.988,
		hasteScalar = 1.3,
		melee = "agile",
	},
	MAGE = {
		meleeCrit = { 0.03454, 0.000196 },
		spellCrit = { 0.009075, 0.00006 },
		dodge = { 0.036587, 1.00 / 1.15, 150.375940 },
		k = 0.983,
		melee = "caster",
	},
	WARLOCK = {
		meleeCrit = { 0.02622, 0.000198 },
		spellCrit = { 0.017, 0.00006 },
		dodge = { 0.024211, 0.97 / 1.15, 150.375940 },
		k = 0.983,
		melee = "caster",
	},
	DRUID = {
		meleeCrit = { 0.074755, 0.00012 },
		spellCrit = { 0.018515, 0.00006 },
		dodge = { 0.056097, 2.00 / 1.15, 116.890707 },
		k = 0.972,
		hasteScalar = 1.3,
		melee = "druid",
	},
}

Data.RACIALS = {
	Human = {
		{ spell = 20597, "expertise", 0, 3, weapon = 384 }, -- Sword Specialization
		{ spell = 20864, "expertise", 0, 3, weapon = 48 }, -- Mace Specialization
		{ spell = 20598, "stat", 4, 3 }, -- The Human Spirit
	},
	Orc = {
		{ spell = 20574, "expertise", 0, 5, weapon = 8195 }, -- Axe Specialization
	},
	Dwarf = {
		{ spell = 59224, "expertise", 0, 5, weapon = 48 }, -- Mace Specialization
		{ spell = 20595, "crit", 0, 1, weapon = 8 }, -- Gun Specialization
	},
	Gnome = {
		{ spell = 20591, "stat", 3, 5 }, -- Expansive Mind
	},
	Troll = {
		{ spell = 26290, "crit", 0, 1, weapon = 4 }, -- Bow Specialization
		{ spell = 20558, "crit", 0, 1, weapon = 65536 }, -- Throwing Specialization
	},
	Draenei = {
		{ spell = 28878, "hit", 0, 1 }, -- Heroic Presence
		{ spell = 28878, "spellHit", 0, 1 }, -- Heroic Presence
	},
}

Data.FORMS = {
	WARRIOR = {
		{ id = 17, spell = 2457, effects = { { "arp", 0, 10 } } }, -- Battle Stance
		{ id = 18, spell = 71, effects = {} }, -- Defensive Stance
		{ id = 19, spell = 2458, effects = { { "crit", 0, 3 } } }, -- Berserker Stance
	},
	DRUID = {
		{ id = 0, effects = {} },
		{ id = 1, spell = 768, feral = true, effects = { { "apFlat", 0, 160 } } }, -- Cat Form
		{
			id = 8,
			spell = 9634, -- Dire Bear Form
			feral = true,
			effects = { { "armor", 0, 370 }, { "stat", 2, 25 }, { "apFlat", 0, 240 } },
		},
		{
			id = 31,
			spell = 24858, -- Moonkin Form
			caster = true,
			effects = { { "armor", 0, 370 }, { "spellCrit", 0, 5 } },
			talent = 793, -- Moonkin Form
		},
		{ id = 2, spell = 33891, caster = true, effects = {}, talent = 1791 }, -- Tree of Life
	},
	DEATHKNIGHT = {
		{ id = 101, spell = 48266, effects = {} }, -- Blood Presence
		{ id = 102, spell = 48263, effects = { { "armor", 0, 60 } } }, -- Frost Presence
		{ id = 103, spell = 48265, effects = { { "haste", 0, 15 } } }, -- Unholy Presence
	},
	HUNTER = {
		{ id = 0, effects = {} },
		{ id = 201, spell = 61847, effects = { { "apFlat", 0, 300 } } }, -- Aspect of the Dragonhawk
		{ id = 202, spell = 13163, effects = { { "dodge", 0, 18 } } }, -- Aspect of the Monkey
	},
}

Data.FORM_AURAS = {
	[2457] = 17, -- Battle Stance
	[71] = 18, -- Defensive Stance
	[2458] = 19, -- Berserker Stance
	[768] = 1, -- Cat Form
	[5487] = 8, -- Bear Form
	[9634] = 8, -- Dire Bear Form
	[24858] = 31, -- Moonkin Form
	[33891] = 2, -- Tree of Life
	[48266] = 101, -- Blood Presence
	[48263] = 102, -- Frost Presence
	[48265] = 103, -- Unholy Presence
	[61846] = 201, -- Aspect of the Dragonhawk
	[61847] = 201, -- Aspect of the Dragonhawk
	[13163] = 202, -- Aspect of the Monkey
}

Data.BONUS_ARMOR = {
	[39225] = 336, -- Cloak of Armed Strife
	[40252] = 336, -- Cloak of the Shadowed Sun
	[40385] = 21.5, -- Envoy of Mortality
	[42486] = 25.4, -- Furious Gladiator's Rifle
	[42487] = 34.5, -- Relentless Gladiator's Rifle
	[42491] = 25.4, -- Furious Gladiator's Longbow
	[42492] = 34.5, -- Relentless Gladiator's Longbow
	[42496] = 25.4, -- Furious Gladiator's Heavy Crossbow
	[42498] = 34.5, -- Relentless Gladiator's Heavy Crossbow
	[45137] = 25.4, -- Veranus' Bane
	[45261] = 25.4, -- Giant's Bane
	[45267] = 826, -- Saronite Plated Legguards
	[45327] = 25.4, -- Siren's Cry
	[45570] = 30.2, -- Skyforge Crossbow
	[45870] = 25.4, -- Magnetized Projectile Emitter
	[45937] = 30.2, -- Furious Gladiator's Shotgun
	[45938] = 30.2, -- Furious Gladiator's Recurve
	[45939] = 30.2, -- Furious Gladiator's Repeater
	[46994] = 34.5, -- Talonstrike
	[46995] = 45, -- Talonstrike
	[47267] = 34.5, -- Death's Head Crossbow
	[47428] = 45, -- Death's Head Crossbow
	[47521] = 45, -- BRK-1000
	[47523] = 45, -- Fezzik's Autocannon
	[47740] = 25.5, -- The Diplomat
	[47741] = 25.5, -- Baelgun's Heavy Crossbow
	[47883] = 25.5, -- Widebarrel Flintlock
	[47907] = 25.5, -- Darkmaw Crossbow
	[47950] = 34.5, -- The Diplomat
	[47975] = 34.5, -- Baelgun's Heavy Crossbow
	[48022] = 34.5, -- Widebarrel Flintlock
	[48052] = 34.5, -- Darkmaw Crossbow
	[48420] = 45, -- Relentless Gladiator's Recurve
	[48422] = 45, -- Relentless Gladiator's Repeater
	[48424] = 45, -- Relentless Gladiator's Shotgun
	[48697] = 34.5, -- Frenzystrike Longbow
	[48711] = 34.5, -- Rhok'shalla, the Shadow's Bane
	[49305] = 25.5, -- Snub-Nose Blastershot Launcher
	[49493] = 34.5, -- Rifled Blastershot Launcher
	[49904] = 1190, -- Pillars of Might
	[49981] = 56.69, -- Fal'inrush, Defender of Quel'thalas
	[50034] = 50.19, -- Zod's Repeating Longbow
	[50262] = 25.5, -- Felglacier Bolter
	[50444] = 50.19, -- Rowan's Rifle of Silver Bullets
	[50466] = 560, -- Sentinel's Winter Cloak
	[50638] = 62.6, -- Zod's Repeating Longbow
	[50733] = 69.93, -- Fal'inrush, Defender of Quel'thalas
	[50776] = 39.2, -- Njorndar Bone Bow
	[50802] = 630, -- Gargoyle Spit Bracers
	[50849] = 882, -- Ymirjar Lord's Handguards
	[50850] = 1064, -- Ymirjar Lord's Breastplate
	[50856] = 882, -- Scourgelord Handguards
	[50857] = 1064, -- Scourgelord Chestguard
	[50863] = 882, -- Lightsworn Handguards
	[50864] = 1064, -- Lightsworn Chestguard
	[50968] = 1176, -- Cataclysmic Chestguard
	[50978] = 1008, -- Gauntlets of the Kraken
	[50991] = 658, -- Verdigris Chain Belt
	[51132] = 1008, -- Sanctified Scourgelord Handguards
	[51134] = 1190, -- Sanctified Scourgelord Chestguard
	[51172] = 1008, -- Sanctified Lightsworn Handguards
	[51174] = 1190, -- Sanctified Lightsworn Chestguard
	[51217] = 1008, -- Sanctified Ymirjar Lord's Handguards
	[51219] = 1190, -- Sanctified Ymirjar Lord's Breastplate
	[51220] = 1344, -- Sanctified Ymirjar Lord's Breastplate
	[51222] = 1148, -- Sanctified Ymirjar Lord's Handguards
	[51265] = 1344, -- Sanctified Lightsworn Chestguard
	[51267] = 1148, -- Sanctified Lightsworn Handguards
	[51305] = 1344, -- Sanctified Scourgelord Chestguard
	[51307] = 1148, -- Sanctified Scourgelord Handguards
	[51385] = 36.9, -- Stakethrower
	[51394] = 50.19, -- Wrathful Gladiator's Longbow
	[51395] = 62.6, -- Wrathful Gladiator's Recurve
	[51411] = 50.19, -- Wrathful Gladiator's Heavy Crossbow
	[51412] = 62.6, -- Wrathful Gladiator's Repeater
	[51449] = 50.19, -- Wrathful Gladiator's Rifle
	[51450] = 62.6, -- Wrathful Gladiator's Shotgun
	[51561] = 36.9, -- Dreamhunter's Carbine
	[51802] = 44.96, -- Windrunner's Heartseeker
	[51834] = 48.41, -- Dreamhunter's Carbine
	[51845] = 48.41, -- Stakethrower
	[51901] = 714, -- Gargoyle Spit Bracers
	[51927] = 48.4, -- Njorndar Bone Bow
	[51940] = 54.79, -- Windrunner's Heartseeker
	[54801] = 490, -- Icebound Cloak
}
