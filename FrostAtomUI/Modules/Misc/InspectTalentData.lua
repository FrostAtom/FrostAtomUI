local _, ns = ...

ns.InspectTalentData = {
	[125] = { { "arp", 0, { 3, 6, 9, 12, 15 }, weapon = 48 } }, -- Mace Specialization
	[130] = { { "parry", 0, { 1, 2, 3, 4, 5 } } }, -- Deflection
	[132] = { { "crit", 0, { 1, 2, 3, 4, 5 }, weapon = 67 } }, -- Poleaxe Specialization
	[138] = { { "dodge", 0, { 1, 2, 3, 4, 5 } } }, -- Anticipation
	[140] = { { "armor", 0, { 2, 4, 6, 8, 10 } } }, -- Toughness
	[157] = { { "crit", 0, { 1, 2, 3, 4, 5 }, weapon = 173555 } }, -- Cruelty
	[1601] = { { "block", 0, { 1, 2, 3, 4, 5 }, armor = 64 } }, -- Shield Specialization
	[1653] = { { "stat", 2, { 3, 6, 9 } }, { "stat", 0, { 2, 4, 6 } }, { "expertise", 0, { 2, 4, 6 } } }, -- Vitality
	[1654] = { { "blockValue", 0, { 15, 30 }, armor = 64 } }, -- Shield Mastery
	[1657] = { { "hit", 0, { 1, 2, 3 }, weapon = 173555 } }, -- Precision
	[1658] = { { "stat", 0, { 4, 8, 12, 16, 20 }, stances = 262144 } }, -- Improved Berserker Stance
	[1664] = { { "haste", 0, { 5, 10 } } }, -- Blood Frenzy
	[1862] = { { "stat", 0, { 2, 4 } }, { "stat", 2, { 2, 4 } }, { "expertise", 0, { 2, 4 } } }, -- Strength of Arms
	[2250] = { { "apFromArmor", 0, { 108, 54, 36 } } }, -- Armored to the Teeth
	[1403] = { { "parry", 0, { 1, 2, 3, 4, 5 } } }, -- Deflection
	[1411] = { { "crit", 0, { 1, 2, 3, 4, 5 } }, { "spellCrit", 0, { 1, 2, 3, 4, 5 } } }, -- Conviction
	[1421] = { { "blockValue", 0, { 10, 20, 30 }, armor = 64 } }, -- Redoubt
	[1423] = { { "armor", 0, { 2, 4, 6, 8, 10 } } }, -- Toughness
	[1449] = { { "stat", 3, { 2, 4, 6, 8, 10 } } }, -- Divine Intellect
	[1627] = { { "spellCrit", 2, { 1, 2, 3, 4, 5 } } }, -- Holy Power
	[1629] = { { "dodge", 0, { 1, 2, 3, 4, 5 } } }, -- Anticipation
	[1746] = { { "spFromStat", 3, { 4, 8, 12, 16, 20 } }, { "healFromStat", 3, { 4, 8, 12, 16, 20 } } }, -- Holy Guidance
	[1750] = { { "stat", 2, { 2, 4 } } }, -- Sacred Duty
	[1753] = { { "expertise", 0, { 2, 4, 6 } }, { "stat", 2, { 2, 4, 6 } }, { "allCrit", 0, { 2, 4, 6 } } }, -- Combat Expertise
	[1761] = { { "spellCrit", 0, { 1, 2, 3 } }, { "crit", 0, { 1, 2, 3 } } }, -- Sanctity of Battle
	[2179] = { { "spFromAp", 0, { 10, 20, 30 } }, { "healFromAp", 0, { 10, 20, 30 } } }, -- Sheath of Light
	[2185] = { { "stat", 0, { 3, 6, 9, 12, 15 } } }, -- Divine Strength
	[2191] = { { "hit", 0, { 2, 4 } }, { "spellHit", 0, { 2, 4 } } }, -- Enlightened Judgements
	[2195] = { { "spFromStat", 0, { 20, 40, 60 } }, { "healFromStat", 0, { 20, 40, 60 } } }, -- Touched by the Light
	[1303] = { { "stat", 1, { 3, 6, 9, 12, 15 } } }, -- Lightning Reflexes
	[1311] = { { "parry", 0, { 1, 2, 3 } } }, -- Deflection
	[1321] = { { "crit", 0, { 1, 2, 3 } } }, -- Killer Instinct
	[1344] = { { "crit", 0, { 1, 2, 3, 4, 5 }, weapon = 327692 } }, -- Lethal Shots
	[1395] = { { "armor", 0, { 4, 7, 10 } } }, -- Thick Hide
	[1622] = { { "stat", 2, { 2, 4, 6, 8, 10 } } }, -- Survivalist
	[1801] = { { "dodge", 0, { 1, 2, 3 } } }, -- Catlike Reflexes
	[1802] = { { "haste", 0, { 4, 8, 12, 16, 20 } } }, -- Serpent's Swiftness
	[1804] = { { "stat", 1, { 2, 4 } }, { "stat", 3, { 2, 4 } } }, -- Combat Experience
	[1806] = { { "rapFromStat", 3, { 33, 66, 100 } } }, -- Careful Aim
	[1807] = { { "crit", 0, { 1, 2, 3, 4, 5 } } }, -- Master Marksman
	[2144] = { { "stat", 1, { 1, 2, 3 } } }, -- Hunting Party
	[2197] = { { "hit", 0, { 1, 2, 3 } } }, -- Focused Aim
	[2228] = { { "apFromStat", 2, { 10, 20, 30 } }, { "rapFromStat", 2, { 10, 20, 30 } } }, -- Hunter vs. Wild
	[181] = { { "hit", 0, { 1, 2, 3, 4, 5 }, weapon = 368797 }, { "spellHit", 0, { 1, 2, 3, 4, 5 }, weapon = 368797 } }, -- Precision
	[182] = { { "crit", 0, { 1, 2, 3, 4, 5 }, weapon = 40960 } }, -- Close Quarters Combat
	[184] = { { "arp", 0, { 3, 6, 9, 12, 15 }, weapon = 16 } }, -- Mace Specialization
	[186] = { { "dodge", 0, { 2, 4, 6 } }, { "haste", 0, { 4, 7, 10 } } }, -- Lightning Reflexes
	[187] = { { "parry", 0, { 2, 4, 6 } } }, -- Deflection
	[204] = { { "stat", 2, { 2, 4 } } }, -- Endurance
	[270] = { { "crit", 0, { 1, 2, 3, 4, 5 } } }, -- Malice
	[1123] = { { "arp", 0, { 3, 6, 9 } } }, -- Serrated Blades
	[1700] = { { "meleeCritTaken", 0, { -1, -2 } }, { "rangedCritTaken", 0, { -1, -2 } } }, -- Sleight of Hand
	[1702] = { { "ap", 0, { 2, 4, 6, 8, 10 } } }, -- Deadliness
	[1703] = { { "expertise", 0, { 5, 10 } } }, -- Weapon Expertise
	[1712] = { { "stat", 1, { 3, 6, 9, 12, 15 } } }, -- Sinister Calling
	[2074] = { { "ap", 0, { 2, 4 } } }, -- Savage Combat
	[344] = { { "stat", 2, { 2, 4 } } }, -- Improved Power Word: Fortitude
	[401] = { { "spellCrit", 2, { 1, 2, 3, 4, 5 } } }, -- Holy Specialization
	[402] = { { "spFromStat", 4, { 5, 10, 15, 20, 25 } }, { "healFromStat", 4, { 5, 10, 15, 20, 25 } } }, -- Spiritual Guidance
	[1201] = { { "stat", 3, { 3, 6, 9, 12, 15 } } }, -- Mental Strength
	[1561] = { { "stat", 4, { 5 } } }, -- Spirit of Redemption
	[1772] = { { "stat", 4, { 2, 4, 6 } }, { "spellHaste", 0, { 2, 4, 6 } } }, -- Enlightenment
	[1858] = { { "spellCrit", 0, { 1, 2, 3 } } }, -- Focused Will
	[1907] = { { "spFromStat", 4, { 4, 8, 12, 16, 20 } }, { "healFromStat", 4, { 4, 8, 12, 16, 20 } } }, -- Twisted Faith
	[1932] = { { "spellHit", 0, { 1, 2, 3 } } }, -- Virulence
	[1934] = { { "stat", 0, { 1, 2, 3 } } }, -- Ravenous Dead
	[1938] = { { "apFromArmor", 0, { 180, 90, 60, 45, 36 } } }, -- Bladed Armor
	[1943] = { { "crit", 0, { 1, 2, 3, 4, 5 }, weapon = 173555 }, { "spellCrit", 0, { 1, 2, 3, 4, 5 }, weapon = 173555 } }, -- Dark Conviction
	[1950] = { { "stat", 0, { 2, 4, 6 } }, { "stat", 2, { 1, 2, 3 } }, { "expertise", 0, { 2, 4, 6 } } }, -- Veteran of the Third War
	[1968] = { { "armor", 0, { 2, 4, 6, 8, 10 } } }, -- Toughness
	[1971] = { { "stat", 0, { 2, 4 } } }, -- Endless Winter
	[1998] = { { "expertise", 0, { 1, 2, 3, 4, 5 } } }, -- Tundra Stalker
	[2022] = { { "hit", 0, { 1, 2, 3 }, weapon = 41105, dual = true } }, -- Nerves of Cold Steel
	[2036] = { { "expertise", 0, { 1, 2, 3, 4, 5 } } }, -- Rage of Rivendare
	[2043] = { { "crit", 0, { 1, 2, 3 } }, { "spellCrit", 0, { 1, 2, 3 } } }, -- Ebon Plaguebringer
	[2105] = { { "stat", 0, { 1, 2 } } }, -- Abomination's Might
	[2218] = { { "dodge", 0, { 1, 2, 3, 4, 5 } } }, -- Anticipation
	[2223] = { { "haste", 0, { 5 } } }, -- Improved Icy Talons
	[601] = { { "dodge", 0, { 1, 2, 3 } } }, -- Anticipation
	[613] = { { "crit", 0, { 1, 2, 3, 4, 5 } }, { "spellCrit", 0, { 1, 2, 3, 4, 5 } } }, -- Thundering Strikes
	[614] = { { "stat", 3, { 2, 4, 6, 8, 10 } } }, -- Ancestral Knowledge
	[615] = { { "stat", 2, { 2, 4, 6, 8, 10 } } }, -- Toughness
	[1685] = { { "spellHit", 0, { 1, 2, 3 } } }, -- Elemental Precision
	[1689] = { { "expertise", 0, { 3, 6, 9 } } }, -- Unleashed Rage
	[1691] = { { "spFromAp", 0, { 10, 20, 30 } }, { "healFromAp", 0, { 10, 20, 30 } } }, -- Mental Quickness
	[1692] = { { "hit", 0, { 2, 4, 6 }, dual = true } }, -- Dual Wield Specialization
	[1696] = { { "healFromStat", 3, { 5, 10, 15 } } }, -- Nature's Blessing
	[2060] = { { "spellCrit", 0, { 2, 4 } } }, -- Blessing of the Eternals
	[2083] = { { "apFromStat", 3, { 33, 66, 100 } } }, -- Mental Dexterity
	[33] = { { "spellCrit", 4, { 2, 4, 6 } } }, -- Critical Mass
	[77] = { { "stat", 3, { 3, 6, 9, 12, 15 } } }, -- Arcane Mind
	[421] = { { "spellCrit", 0, { 1, 2, 3 } } }, -- Arcane Instability
	[1649] = { { "spellHit", 0, { 1, 2, 3 } } }, -- Precision
	[1728] = { { "spFromStat", 3, { 3, 6, 9, 12, 15 } } }, -- Mind Mastery
	[1733] = { { "spellCrit", 0, { 1, 2, 3 } } }, -- Pyromaniac
	[1845] = { { "stat", 4, { 4, 7, 10 } } }, -- Student of the Mind
	[1846] = { { "spellHaste", 0, { 2, 4, 6 } } }, -- Netherwind Presence
	[1005] = { { "spellHit", 0, { 1, 2, 3 } } }, -- Suppression
	[1223] = { { "stat", 2, { 4, 7, 10 } } }, -- Demonic Embrace
	[1673] = { { "spellCrit", 0, { 2, 4, 6, 8, 10 } }, { "crit", 0, { 2, 4, 6, 8, 10 } } }, -- Demonic Tactics
	[1680] = { { "meleeCritTaken", 0, { -1, -2, -3 } }, { "spellCritTaken", 0, { -1, -2, -3 } } }, -- Demonic Resilience
	[1817] = { { "spellCrit", 0, { 1, 2, 3 } } }, -- Backlash
	[784] = { { "spellHaste", 0, { 1, 2, 3 } } }, -- Celestial Focus
	[794] = { { "armor", 0, { 4, 7, 10 } } }, -- Thick Hide
	[798] = { { "crit", 0, { 2, 4, 6 }, stances = 145 } }, -- Sharpened Claws
	[807] = { { "dodge", 0, { 2, 4 }, stances = 145 } }, -- Feral Swiftness
	[803] = { { "apLevel", 0, { 50, 100, 150 }, stances = 145 }, { "apWeapon", 0, { 7, 14, 20 }, stances = 145 } }, -- Predatory Strikes
	[808] = { -- Heart of the Wild
		{ "stat", 3, { 4, 8, 12, 16, 20 } },
		{ "stat", 2, { 2, 4, 6, 8, 10 }, stances = 144 },
		{ "ap", 0, { 2, 4, 6, 8, 10 }, stances = 1 },
	},
	[809] = { { "crit", 0, { 5 }, stances = 145 } }, -- Leader of the Pack
	[821] = { { "stat", -1, { 1, 2 } } }, -- Improved Mark of the Wild
	[1782] = { { "spFromStat", 3, { 4, 8, 12 } }, { "healFromStat", 3, { 4, 8, 12 } } }, -- Lunar Guidance
	[1783] = { { "spellHit", 0, { 2, 4 } } }, -- Balance of Power
	[1790] = { { "spellCrit", 0, { 1, 2, 3 } } }, -- Natural Perfection
	[1792] = { { "healFromStat", 1, { 35, 70 } } }, -- Nurturing Instinct
	[1794] = { -- Survival of the Fittest
		{ "stat", -1, { 2, 4, 6 } },
		{ "meleeCritTaken", 0, { -2, -4, -6 } },
		{ "armor", 0, { 11, 22, 33 }, stances = 144 },
	},
	[1797] = { { "stat", 4, { 5, 10, 15 } } }, -- Living Spirit
	[1912] = { { "spFromStat", 4, { 10, 20, 30 }, stances = 1073741824 } }, -- Improved Moonkin Form
	[1914] = { { "expertise", 0, { 5, 10 } } }, -- Primal Precision
	[1915] = { { "crit", 0, { 2, 4 }, stances = 1 } }, -- Master Shapeshifter
	[1930] = { { "armor", 0, { 67, 133, 200 }, stances = 2 }, { "healFromStat", 4, { 5, 10, 15 }, stances = 2 } }, -- Improved Tree of Life
	[2241] = { { "ap", 0, { 2, 4, 6 }, stances = 144 } }, -- Protector of the Pack
	[2242] = { { "dodge", 0, { 2, 4, 6 }, stances = 144 } }, -- Natural Reaction
	[1916] = { { "spellHaste", 0, { 2, 4, 6, 8, 10 } } }, -- Gift of the Earthmother
}
