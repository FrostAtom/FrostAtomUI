local _, ns = ...

ns.ProcData = {
	[75473] = { event = "buff", duration = 15, items = { [54588] = 50 } }, -- Twilight Flames (Charred Twilight Scale)
	[75456] = { event = "buff", duration = 15, items = { [54590] = 45 } }, -- Piercing Twilight (Sharpened Twilight Scale)
	[75480] = { event = "buff", duration = 10, items = { [54591] = 45 } }, -- Scaly Nimbleness (Petrified Twilight Scale)
	[71644] = { event = "buff", duration = 20, items = { [50348] = 45 } }, -- Surge of Power (Dislodged Foreign Object)
	[71643] = { event = "stack", items = { [50348] = 45 } }, -- Surging Power (Dislodged Foreign Object)
	[71639] = { event = "buff", duration = 10, items = { [50349] = 30 } }, -- Thick Skin (Corpse Tongue Coin)
	[71556] = { event = "buff", duration = 30, items = { [50363] = 105 } }, -- Agility of the Vrykul (Deathbringer's Will)
	[71558] = { event = "buff", duration = 30, items = { [50363] = 105 } }, -- Power of the Taunka (Deathbringer's Will)
	[71559] = { event = "buff", duration = 30, items = { [50363] = 105 } }, -- Aim of the Iron Dwarves (Deathbringer's Will)
	[71560] = { event = "buff", duration = 30, items = { [50363] = 105 } }, -- Speed of the Vrykul (Deathbringer's Will)
	[71561] = { event = "buff", duration = 30, items = { [50363] = 105 } }, -- Strength of the Taunka (Deathbringer's Will)
	[71636] = { event = "buff", duration = 20, items = { [50365] = 100 } }, -- Siphoned Power (Phylactery of the Nameless Lich)
	[71641] = { event = "heal", items = { [50366] = 45 } }, -- Echoes of Light (Althor's Abacus)
	[72416] = { event = "buff", duration = 10, items = { [50398] = 60, [50397] = 60 } }, -- Frostforged Sage (Ashen Band of Endless Destruction, Ashen Band of Unmatched Destruction)
	[72418] = { event = "buff", duration = 10, items = { [50400] = 60, [50399] = 60 } }, -- Chilling Knowledge (Ashen Band of Endless Wisdom, Ashen Band of Unmatched Wisdom)
	[72412] = { event = "buff", duration = 10, items = { [50402] = 60, [52572] = 60, [50401] = 60, [52571] = 60 } }, -- Frostforged Champion (Ashen Band of Endless Vengeance, Ashen Band of Endless Might, Ashen Band of Unmatched Vengeance, Ashen Band of Unmatched Might)
	[72414] = { event = "buff", duration = 10, items = { [50404] = 0, [50403] = 0 } }, -- Frostforged Defender (Ashen Band of Endless Courage, Ashen Band of Unmatched Courage)
	[71834] = { event = "damage", items = { [50638] = 0, [50034] = 0 } }, -- Quick Shot (Zod's Repeating Longbow)
	[71844] = { event = "summon", items = { [50648] = 0 } }, -- Summon Val'kyr (Nibelung)
	[71866] = { event = "buff", duration = 6, items = { [50685] = 0 } }, -- Fountain of Light (Trauma)
	[71877] = { event = "buff", duration = 10, items = { [50692] = 0 } }, -- Necrotic Touch (Black Bruise)
	[71432] = { event = "stack", stacks = 8, items = { [50706] = 0, [50351] = 0 } }, -- Mote of Anger (Tiny Abomination in a Jar)
	[71433] = { event = "damage", items = { [50706] = 0, [50351] = 0 } }, -- Manifest Anger (Tiny Abomination in a Jar)
	[71434] = { event = "damage", items = { [50706] = 0, [50351] = 0 } }, -- Manifest Anger (Tiny Abomination in a Jar)
	[71872] = { event = "buff", duration = 10, items = { [50708] = 0 } }, -- Blessing of Light (Last Word)
	[75458] = { event = "buff", duration = 15, items = { [54569] = 45 } }, -- Piercing Twilight (Sharpened Twilight Scale)
	[75477] = { event = "buff", duration = 10, items = { [54571] = 45 } }, -- Scaly Nimbleness (Petrified Twilight Scale)
	[75466] = { event = "buff", duration = 15, items = { [54572] = 50 } }, -- Twilight Flames (Charred Twilight Scale)
	[62458] = {
		event = "energize",
		items = { [51414] = 0, [40811] = 0, [40809] = 0, [40806] = 0, [40799] = 0, [40803] = 0, [42655] = 0 },
	}, -- Bonus Runic Power (Wrathful Gladiator's Dreadplate Gauntlets, Relentless Gladiator's Dreadplate Gauntlets, Furious Gladiator's Dreadplate Gauntlets, Deadly Gladiator's Dreadplate Gauntlets, Savage Gladiator's Dreadplate Gauntlets, Hateful Gladiator's Dreadplate Gauntlets)
	[60570] = { event = "buff", duration = 10, items = { [51437] = 0, [51513] = 0 } }, -- Intuition of the Gladiator (Wrathful Gladiator's Idol of Steadfastness, Wrathful Gladiator's Totem of Survival)
	[71169] = { event = "debuff", items = { [49888] = 0 } }, -- Shadow's Fate (Shadow's Edge)
	[71843] = { event = "summon", items = { [49992] = 0 } }, -- Summon Val'kyr (Nibelung)
	[71864] = { event = "buff", duration = 6, items = { [50028] = 0 } }, -- Fountain of Light (Trauma)
	[71875] = { event = "buff", duration = 10, items = { [50035] = 0 } }, -- Necrotic Touch (Black Bruise)
	[71870] = { event = "buff", duration = 10, items = { [50179] = 0 } }, -- Blessing of Light (Last Word)
	[71541] = { event = "buff", duration = 15, items = { [50343] = 45 } }, -- Icy Rage (Whispering Fanged Skull)
	[71577] = { event = "stack", duration = 10, items = { [50344] = 0 } }, -- Invigorated (Unidentifiable Organ)
	[71572] = { event = "stack", duration = 10, items = { [50345] = 0 } }, -- Cultivated Power (Muradin's Spyglass)
	[71633] = { event = "buff", duration = 10, items = { [50352] = 30 } }, -- Thick Skin (Corpse Tongue Coin)
	[71601] = { event = "buff", duration = 20, items = { [50353] = 45 } }, -- Surge of Power (Dislodged Foreign Object)
	[71600] = { event = "stack", items = { [50353] = 45 } }, -- Surging Power (Dislodged Foreign Object)
	[71396] = { event = "stack", duration = 10, items = { [50355] = 0 } }, -- Rage of the Fallen (Herkuml War Token)
	[71584] = { event = "buff", duration = 15, items = { [50358] = 50 } }, -- Revitalized (Purified Lunar Dust)
	[71610] = { event = "heal", items = { [50359] = 45 } }, -- Echoes of Light (Althor's Abacus)
	[71605] = { event = "buff", duration = 20, items = { [50360] = 100 } }, -- Siphoned Power (Phylactery of the Nameless Lich)
	[71484] = { event = "buff", duration = 30, items = { [50362] = 105 } }, -- Strength of the Taunka (Deathbringer's Will)
	[71485] = { event = "buff", duration = 30, items = { [50362] = 105 } }, -- Agility of the Vrykul (Deathbringer's Will)
	[71486] = { event = "buff", duration = 30, items = { [50362] = 105 } }, -- Power of the Taunka (Deathbringer's Will)
	[71491] = { event = "buff", duration = 30, items = { [50362] = 105 } }, -- Aim of the Iron Dwarves (Deathbringer's Will)
	[71492] = { event = "buff", duration = 30, items = { [50362] = 105 } }, -- Speed of the Vrykul (Deathbringer's Will)
	[71184] = { event = "stack", duration = 15, items = { [50454] = 0 } }, -- Soothing (Idol of the Black Willow)
	[71187] = { event = "stack", duration = 15, items = { [50455] = 0 } }, -- Formidable (Libram of Three Truths)
	[71175] = { event = "stack", duration = 15, items = { [50456] = 0 } }, -- Agile (Idol of the Crying Moon)
	[71177] = { event = "stack", duration = 15, items = { [50457] = 0 } }, -- Vicious (Idol of the Lunar Eclipse)
	[71199] = { event = "stack", duration = 30, items = { [50458] = 0 } }, -- Furious (Bizuri's Totem of Shattered Ice)
	[71227] = { event = "stack", duration = 15, items = { [50459] = 0 } }, -- Indomitable (Sigil of the Hanged Man)
	[71192] = { event = "stack", duration = 15, items = { [50460] = 0 } }, -- Blessed (Libram of Blinding Light)
	[71197] = { event = "stack", duration = 15, items = { [50461] = 0 } }, -- Evasive (Libram of the Eternal Tower)
	[71229] = { event = "stack", duration = 15, items = { [50462] = 0 } }, -- Precognition (Sigil of the Bone Gryphon)
	[71216] = { event = "stack", duration = 15, items = { [50463] = 0 } }, -- Enraged (Totem of the Avalanche)
	[71220] = { event = "stack", duration = 15, items = { [50464] = 0 } }, -- Energized (Totem of the Surging Sea)
	[67750] = { event = "stack", duration = 10, items = { [47059] = 0, [47432] = 0 } }, -- Energized (Solace of the Defeated, Solace of the Fallen)
	[67772] = { event = "buff", duration = 15, items = { [47131] = 45, [47464] = 45 } }, -- Paragon (Death's Verdict, Death's Choice)
	[67773] = { event = "buff", duration = 15, items = { [47131] = 45, [47464] = 45 } }, -- Paragon (Death's Verdict, Death's Choice)
	[67759] = { event = "stack", stacks = 3, items = { [47188] = 2, [47477] = 2 } }, -- Shard of Flame (Reign of the Unliving, Reign of the Dead)
	[67760] = { event = "damage", items = { [47188] = 0, [47477] = 0 } }, -- Pillar of Flame (Reign of the Unliving, Reign of the Dead)
	[60569] = { event = "buff", duration = 10, items = { [42585] = 0, [42604] = 0 } }, -- Relentless Survival (Relentless Gladiator's Idol of Steadfastness, Relentless Gladiator's Totem of Survival)
	[71570] = { event = "stack", duration = 10, items = { [50340] = 0 } }, -- Cultivated Power (Muradin's Spyglass)
	[71575] = { event = "stack", duration = 10, items = { [50341] = 0 } }, -- Invigorated (Unidentifiable Organ)
	[71401] = { event = "buff", duration = 15, items = { [50342] = 45 } }, -- Icy Rage (Whispering Fanged Skull)
	[64411] = { event = "buff", duration = 15, items = { [46017] = 45 } }, -- Blessing of Ancient Kings (Val'anyr, Hammer of Ancient Kings)
	[67696] = { event = "stack", duration = 10, items = { [47041] = 0, [47271] = 0 } }, -- Energized (Solace of the Defeated, Solace of the Fallen)
	[67703] = { event = "buff", duration = 15, items = { [47115] = 45, [47303] = 45 } }, -- Paragon (Death's Verdict, Death's Choice)
	[67708] = { event = "buff", duration = 15, items = { [47115] = 45, [47303] = 45 } }, -- Paragon (Death's Verdict, Death's Choice)
	[67713] = { event = "stack", stacks = 3, items = { [47182] = 2, [47316] = 2 } }, -- Mote of Flame (Reign of the Unliving, Reign of the Dead)
	[67714] = { event = "damage", items = { [47182] = 0, [47316] = 0 } }, -- Pillar of Flame (Reign of the Unliving, Reign of the Dead)
	[67371] = { event = "buff", duration = 16, items = { [47661] = 8 } }, -- Holy Strength (Libram of Valiance)
	[67364] = { event = "buff", duration = 15, items = { [47662] = 8 } }, -- Holy Judgement (Libram of Veracity)
	[67378] = { event = "buff", duration = 18, items = { [47664] = 9 } }, -- Evasion (Libram of Defiance)
	[67388] = { event = "buff", duration = 15, items = { [47665] = 8 } }, -- Spiritual Trance (Totem of Calming Tides)
	[67385] = { event = "buff", duration = 12, items = { [47666] = 6 } }, -- Energized (Totem of Electrifying Wind)
	[67391] = { event = "buff", duration = 18, items = { [47667] = 9 } }, -- Volcanic Fury (Totem of Quaking Earth)
	[67360] = { event = "buff", duration = 12, items = { [47670] = 6 } }, -- Blessing of the Moon Goddess (Idol of Lunar Fury)
	[67358] = { event = "buff", duration = 9, items = { [47671] = 5 } }, -- Rejuvenating (Idol of Flaring Growth)
	[67380] = { event = "buff", duration = 20, items = { [47672] = 10 } }, -- Evasion (Sigil of Insolence)
	[67383] = { event = "buff", duration = 20, items = { [47673] = 10 } }, -- Unholy Force (Sigil of Virulence)
	[64713] = { event = "buff", duration = 10, items = { [45518] = 45 } }, -- Flame of the Heavens (Flare of the Heavens)
	[64739] = { event = "buff", duration = 15, items = { [45535] = 50 } }, -- Show of Faith
	[64772] = { event = "buff", duration = 10, items = { [45609] = 45 } }, -- Comet's Trail
	[60568] = { event = "buff", duration = 10, items = { [42584] = 0, [42603] = 0 } }, -- Furious Gladiator's Idol of Steadfastness (Furious Gladiator's Totem of Survival)
	[71403] = { event = "buff", duration = 10, items = { [50198] = 50 } }, -- Fatal Flaws (Needle-Encrusted Scorpion)
	[71566] = { event = "energize", items = { [50260] = 0.25 } }, -- Replenished (Ephemeral Snowflake)
	[64963] = { event = "buff", duration = 5, items = { [45144] = 0 } }, -- Shadow of Death (Sigil of Deflection)
	[65182] = { event = "buff", duration = 20, items = { [45145] = 0 } }, -- Increased Block (Libram of the Sacred Shield)
	[64741] = { event = "buff", duration = 10, items = { [45490] = 45 } }, -- Pandora's Plea
	[64765] = { event = "buff", duration = 10, items = { [45507] = 0 } }, -- The General's Heart
	[64951] = { event = "buff", duration = 12, items = { [45509] = 0 } }, -- Primal Wrath (Idol of the Corruptor)
	[64790] = { event = "buff", duration = 10, items = { [45522] = 50 } }, -- Blood of the Old God
	[65003] = { event = "buff", duration = 15, items = { [45929] = 50 } }, -- Memories of Love (Sif's Remembrance)
	[65019] = { event = "buff", duration = 10, items = { [45931] = 45 } }, -- Mjolnir Runestone
	[65024] = { event = "buff", duration = 10, items = { [46038] = 45 } }, -- Implosion (Dark Matter)
	[65014] = { event = "buff", duration = 10, items = { [45286] = 50 } }, -- Pyrite Infusion (Pyrite Infuser)
	[65006] = { event = "stack", duration = 10, items = { [45308] = 0 } }, -- Eye of the Broodmother
	[65004] = { event = "buff", duration = 10, items = { [45866] = 45 } }, -- Alacrity of the Elements (Elemental Focus Stone)
	[60494] = { event = "buff", duration = 10, items = { [40255] = 45 } }, -- Dying Curse
	[60437] = { event = "buff", duration = 10, items = { [40256] = 45 } }, -- Grim Toll
	[60530] = { event = "buff", duration = 12, items = { [40258] = 45 } }, -- Forethought Talisman
	[60443] = { event = "damage", items = { [40371] = 45 } }, -- Bandit's Insignia
	[60488] = { event = "damage", items = { [40373] = 15 } }, -- Extract of Necromatic Power (Extract of Necromantic Power)
	[60538] = { event = "energize", items = { [40382] = 45 } }, -- Soul of the Dead
	[60314] = { event = "stack", duration = 10, items = { [40431] = 0 } }, -- Fury of the Five Flights
	[60486] = { event = "stack", duration = 10, items = { [40432] = 0 } }, -- Illustration of the Dragon Soul
	[60567] = { event = "buff", duration = 10, items = { [42583] = 0, [42602] = 0 } }, -- Deadly Magic (Deadly Gladiator's Idol of Steadfastness, Deadly Gladiator's Totem of Survival)
	[60218] = { event = "buff", duration = 10, items = { [37220] = 50 } }, -- Essence of Gossamer
	[60483] = { event = "damage", items = { [37264] = 45 } }, -- Pendulum of Telluric Currents
	[60302] = { event = "buff", duration = 10, items = { [37390] = 45 } }, -- Meteorite Whetstone
	[60520] = { event = "buff", duration = 15, items = { [37657] = 50 } }, -- Spark of Life
	[60479] = { event = "buff", duration = 10, items = { [37660] = 45 } }, -- Forge Ember
	[49623] = { event = "buff", duration = 15, items = { [37835] = 50 } }, -- Effervescence (Je'Tze's Bell)
	[60492] = { event = "buff", duration = 10, items = { [39229] = 45 } }, -- Embrace of the Spider
	[60525] = { event = "stack", duration = 10, items = { [40430] = 0 } }, -- Majestic Dragon Figurine
	[60064] = { event = "buff", duration = 10, items = { [40682] = 45, [44912] = 50, [49076] = 45 } }, -- Now is the time! (Sundial of the Exiled, Flow of Knowledge, Mithril Pocketwatch)
	[60065] = { event = "buff", duration = 10, items = { [40684] = 50, [44914] = 50, [49074] = 50 } }, -- Reflection of Torment (Mirror of Truth, Anvil of Titans, Coren's Chromium Coaster)
	[60062] = { event = "buff", duration = 10, items = { [40685] = 45, [49078] = 45 } }, -- Essence of Life (The Egg of Mortal Essence, Ancient Pickled Egg)
	[60819] = { event = "buff", duration = 10, items = { [40706] = 0 } }, -- Libram of Reciprocation
	[60771] = { event = "buff", duration = 10, items = { [40708] = 30 } }, -- Totem of the Elemental Plane
	[62146] = { event = "buff", duration = 30, items = { [40714] = 0 } }, -- Unflinching Valor (Sigil of the Unfaltering Knight)
	[60828] = { event = "buff", duration = 10, items = { [40715] = 45 } }, -- Sigil of Haunted Dreams
	[60565] = { event = "buff", duration = 6, items = { [42575] = 0, [42594] = 0 } }, -- Savage Magic (Savage Gladiator's Idol of Steadfastness, Savage Gladiator's Totem of Survival)
	[60566] = { event = "buff", duration = 6, items = { [42582] = 0, [42601] = 0 } }, -- Hateful Magic (Hateful Gladiator's Idol of Steadfastness, Hateful Gladiator's Totem of Survival)
	[60229] = { event = "buff", duration = 15, items = { [42987] = 45, [44253] = 45, [44254] = 45, [44255] = 45 } }, -- Greatness (Darkmoon Card: Greatness)
	[60233] = { event = "buff", duration = 15, items = { [42987] = 45, [44253] = 45, [44254] = 45, [44255] = 45 } }, -- Greatness (Darkmoon Card: Greatness)
	[60234] = { event = "buff", duration = 15, items = { [42987] = 45, [44253] = 45, [44254] = 45, [44255] = 45 } }, -- Greatness (Darkmoon Card: Greatness)
	[60235] = { event = "buff", duration = 15, items = { [42987] = 45, [44253] = 45, [44254] = 45, [44255] = 45 } }, -- Greatness (Darkmoon Card: Greatness)
	[60196] = { event = "stack", duration = 12, items = { [42989] = 0 } }, -- Berserker! (Darkmoon Card: Berserker!)
	[60203] = { event = "damage", items = { [42990] = 45 } }, -- Darkmoon Card: Death
	[58904] = { event = "buff", duration = 10, items = { [43573] = 50 } }, -- Tears of Anguish (Tears of Bitter Anguish)
	[59821] = { event = "stack", duration = 10, items = { [44073] = 0 } }, -- Frenzyheart Fury (Frenzyheart Insignia of Fury)
	[60318] = { event = "buff", duration = 13, items = { [44308] = 45 } }, -- Edward's Insight (Signet of Edward the Odd)
	[63250] = { event = "buff", duration = 10, items = { [45131] = 50, [45219] = 50 } }, -- Jouster's Fury
	[67669] = { event = "buff", duration = 10, items = { [47213] = 45 } }, -- Elusive Power (Abyssal Rune)
	[67671] = { event = "buff", duration = 10, items = { [47214] = 50 } }, -- Fury (Banner of Victory)
	[67666] = { event = "energize", items = { [47215] = 45 } }, -- Mana Mana (Tears of the Vanquished)
	[67631] = { event = "buff", duration = 10, items = { [47216] = 50 } }, -- Aegis (The Black Heart)
	[60307] = { event = "damage", items = { [37064] = 45 } }, -- Vestige of Haldor
	[60512] = { event = "buff", duration = 15, items = { [37111] = 0 } }, -- Healing Trance (Soul Preserver)
	[60513] = { event = "buff", duration = 15, items = { [37111] = 0 } }, -- Healing Trance (Soul Preserver)
	[60514] = { event = "buff", duration = 15, items = { [37111] = 0 } }, -- Healing Trance (Soul Preserver)
	[60515] = { event = "buff", duration = 15, items = { [37111] = 0 } }, -- Healing Trance (Soul Preserver)
	[61671] = { event = "buff", duration = 10, items = { [43829] = 45 } }, -- Crusader's Glory (Crusader's Locket)
	[61619] = { event = "buff", duration = 10, items = { [43838] = 45 } }, -- Tentacles (Chuchu's Tiny Box of Horrors)
	[55018] = { event = "buff", duration = 10, items = { [40767] = 50 } }, -- Sonic Awareness (Sonic Booster)
	[55019] = { event = "buff", duration = 12, items = { [40865] = 50 } }, -- Sonic Shield (Noise Machine)
	[55748] = { event = "damage", items = { [39889] = 45 } }, -- Argent Fury (Horn of Argent Fury)
	[45040] = { event = "buff", duration = 20, items = { [34427] = 45 } }, -- Battle Trance (Blackened Naaru Sliver)
	[35078] = { event = "buff", duration = 10, items = { [29297] = 60 } }, -- Band of the Eternal Defender
	[35081] = { event = "buff", duration = 10, items = { [29301] = 60 } }, -- Band of the Eternal Champion
	[35084] = { event = "buff", duration = 10, items = { [29305] = 60 } }, -- Band of the Eternal Sage
	[35087] = { event = "buff", duration = 10, items = { [29309] = 60 } }, -- Band of the Eternal Restorer
	[37656] = { event = "buff", duration = 15, items = { [32496] = 50 } }, -- Wisdom (Memento of Tyrande)
	[51353] = { event = "energize", items = { [38358] = 10 } }, -- Venture Company Beatdown! (Arcane Revitalizer)
	[51348] = { event = "heal", items = { [38359] = 10 } }, -- Venture Company Beatdown! (Goblin Repetition Reducer)
	[57909] = { event = "buff", duration = 10, items = { [38360] = 45 } }, -- Venture Might (Idol of Arcane Terror)
	[51360] = { event = "heal", items = { [38572] = 10 } }, -- Venture Company Beatdown (Bounty Procurement Enhancer)
	[51351] = { event = "energize", items = { [38572] = 10 } }, -- Venture Company Beatdown! (Bounty Procurement Enhancer)
	[54839] = { event = "buff", duration = 10, items = { [38071] = 45 } }, -- Purified Spirit (Valonforth's Remembrance)
	[54842] = { event = "stack", stacks = 4, items = { [38072] = 2.5 } }, -- Thunder Charge (Thunder Capacitor)
	[54843] = { event = "damage", items = { [38072] = 0 } }, -- Lightning Bolt (Thunder Capacitor)
	[52021] = { event = "buff", duration = 10, items = { [38295] = 10 } }, -- Snap and Snarl (Idol of the Wastes)
	[40459] = { event = "heal", items = { [32485] = 0 } }, -- Fire Blood (Ashtongue Talisman of Valor)
	[40487] = { event = "buff", duration = 8, items = { [32487] = 0 } }, -- Deadly Aim (Ashtongue Talisman of Swiftness)
	[40483] = { event = "buff", duration = 5, items = { [32488] = 0 } }, -- Insight of the Ashtongue (Ashtongue Talisman of Insight)
	[40480] = { event = "buff", duration = 5, items = { [32493] = 0 } }, -- Power of the Ashtongue (Ashtongue Talisman of Shadows)
	[40477] = { event = "buff", duration = 10, items = { [32505] = 0 } }, -- Forceful Strike (Madness of the Betrayer)
	[54739] = { event = "buff", duration = 10, items = { [37559] = 45 } }, -- Star of Light (Serrah's Star)
	[48834] = { event = "buff", duration = 10, items = { [37573] = 10 } }, -- Primal Fury (Idol of the Plainstalker)
	[48838] = { event = "buff", duration = 10, items = { [37575] = 10 } }, -- Elemental Tenacity (Totem of the Tundra)
	[54696] = { event = "buff", duration = 20, items = { [38212] = 45 } }, -- Wracking Pains (Death Knight's Anguish)
	[58157] = { event = "buff", duration = 120, items = { [30446] = 0 } }, -- Solarian's Grace (Solarian's Sapphire)
	[37198] = { event = "buff", duration = 15, items = { [30447] = 45 } }, -- Blessing of Righteousness (Tome of Fiery Redemption)
	[37174] = { event = "buff", duration = 15, items = { [30450] = 30 } }, -- Perceived Weakness (Warp-Spring Coil)
	[38324] = { event = "buff", duration = 12, items = { [30619] = 15 } }, -- Regeneration (Fel Reaver's Piston)
	[38348] = { event = "buff", duration = 15, items = { [30626] = 45 } }, -- Unstable Currents (Sextant of Unstable Currents)
	[42084] = { event = "buff", duration = 10, items = { [30627] = 45 } }, -- Fury of the Crashing Waves (Tsunami Talisman)
	[37243] = { event = "energize", items = { [30663] = 40 } }, -- Revitalize (Fathom-Brooch of the Tidewalker)
	[43751] = { event = "buff", duration = 10, items = { [33506] = 30 } }, -- Energized (Skycall Totem)
	[43749] = { event = "buff", duration = 10, items = { [33507] = 10 } }, -- Elemental Strength (Stonebreaker's Totem)
	[43738] = { event = "buff", duration = 10, items = { [33509] = 10 } }, -- Primal Instinct (Idol of Terror)
	[34747] = { event = "buff", duration = 10, items = { [28789] = 0 } }, -- Recurring Power (Eye of Magtheridon)
	[34775] = { event = "buff", duration = 10, items = { [28830] = 20 } }, -- Dragonspine Flurry (Dragonspine Trophy)
	[33370] = { event = "buff", duration = 6, items = { [27683] = 45, [28190] = 45 } }, -- Spell Haste (Quagmirran's Eye, Scarab of the Infinite Cycle)
	[33394] = { event = "energize", items = { [27896] = 0 } }, -- Replenish Mana (Alembic of Infernal Power)
	[38346] = { event = "buff", duration = 15, items = { [28370] = 50 } }, -- Meditation (Bangle of Endless Blessings)
	[34321] = { event = "buff", duration = 10, items = { [28418] = 45 } }, -- Call of the Nexus (Shiffar's Nexus-Horn)
	[34585] = { event = "buff", duration = 15, items = { [28578] = 50 } }, -- Love Struck (Masquerade Gown)
	[34587] = { event = "damage", items = { [28579] = 0 } }, -- Romulo's Poison (Romulo's Poison Vial)
	[34597] = { event = "buff", duration = 10, items = { [28602] = 50 } }, -- Power of Arcanagos (Robe of the Elder Scribes)
	[37658] = { event = "stack", stacks = 3, items = { [28785] = 2.5 } }, -- Electrical Charge (The Lightning Capacitor)
	[37661] = { event = "damage", items = { [28785] = 0 } }, -- Lightning Bolt (The Lightning Capacitor)
	[45055] = { event = "damage", items = { [34470] = 15 } }, -- Shadow Bolt (Timbal's Focusing Crystal)
	[45062] = { event = "stack", items = { [34471] = 0 } }, -- Holy Energy (Vial of the Sunwell)
	[45053] = { event = "buff", duration = 20, items = { [34472] = 45 } }, -- Disdain (Shard of Contempt)
	[45058] = { event = "buff", duration = 10, items = { [34473] = 30 } }, -- Evasive Maneuvers (Commendation of Kael'thas)
	[33649] = { event = "buff", duration = 10, items = { [28034] = 50 } }, -- Rage of the Unraveller (Hourglass of the Unraveller)
	[41261] = { event = "buff", duration = 30, items = { [32770] = 10 } }, -- Combat Valor (Skyguard Silver Cross)
	[41263] = { event = "buff", duration = 30, items = { [32771] = 10 } }, -- Combat Gallantry (Airman's Ribbon of Gallantry)
	[39439] = { event = "stack", duration = 10, items = { [31856] = 0 } }, -- Aura of the Crusader (Darkmoon Card: Crusade)
	[39441] = { event = "stack", duration = 10, items = { [31856] = 0 } }, -- Aura of the Crusader (Darkmoon Card: Crusade)
	[39443] = { event = "stack", duration = 10, items = { [31857] = 0 } }, -- Aura of Wrath (Darkmoon Card: Wrath)
	[39445] = { event = "damage", items = { [31858] = 0 } }, -- Vengeance (Darkmoon Card: Vengeance)
	[39511] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Sociopath (Darkmoon Card: Madness)
	[40997] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Delusional (Darkmoon Card: Madness)
	[40998] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Kleptomania (Darkmoon Card: Madness)
	[40999] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Megalomania (Darkmoon Card: Madness)
	[41002] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Paranoia (Darkmoon Card: Madness)
	[41005] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Manic (Darkmoon Card: Madness)
	[41009] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Narcissism (Darkmoon Card: Madness)
	[41011] = { event = "buff", duration = 60, items = { [31859] = 0 } }, -- Martyr Complex (Darkmoon Card: Madness)
	[33743] = { event = "energize", items = { [28108] = 10 } }, -- Power Infused Mushroom
	[33758] = { event = "heal", items = { [28109] = 10 } }, -- Essence Infused Mushroom
	[33504] = { event = "heal", items = { [27920] = 0, [27921] = 0 } }, -- Mark of Conquest
	[39599] = { event = "energize", items = { [27920] = 0, [27921] = 0 } }, -- Mark of Conquest
	[33513] = { event = "energize", items = { [27922] = 0, [27924] = 0 } }, -- Mark of Defiance
	[33523] = { event = "energize", items = { [27926] = 0, [27927] = 0 } }, -- Mark of Vindication
	[52419] = { event = "buff", duration = 10, items = { [38674] = 30 } }, -- Deflection (Soul Harvester's Charm)
	[52424] = { event = "buff", duration = 10, items = { [38675] = 45 } }, -- Retaliation (Signet of the Dark Brotherhood)
	[23682] = { event = "heal", items = { [19287] = 0 } }, -- Heroism (Darkmoon Card: Heroism)
	[23684] = { event = "buff", duration = 15, items = { [19288] = 0 } }, -- Aura of the Blue Dragon (Darkmoon Card: Blue Dragon)
	[23687] = { event = "damage", items = { [19289] = 0 } }, -- Lightning Strike (Darkmoon Card: Maelstrom)
	[18946] = { event = "debuff", items = { [14557] = 0 } }, -- The Lion Horn of Stormwind
	[27655] = { event = "damage", items = { [22321] = 0 } }, -- Flame Lash (Heart of Wyrmthalak)
	[15595] = { event = "buff", duration = 10, items = { [11810] = 0 } }, -- Force of Will
	[15601] = { event = "extra", items = { [11815] = 2 } }, -- Hand of Justice
	[10368] = { event = "buff", duration = 15, items = { [11302] = 0 } }, -- Uther's Light Effect (Uther's Strength)
	[10342] = { event = "buff", duration = 15, items = { [1490] = 0 } }, -- Guardian Effect (Guardian Talisman)
	[21970] = { event = "buff", duration = 60, items = { [17774] = 0 } }, -- Mark of the Chosen
	[59913] = { event = "heal", items = { [42991] = 0 } }, -- Swift Hand of Justice
	[59914] = { event = "energize", items = { [42992] = 0 } }, -- Discerning Eye of the Beast

	[42134] = { event = "buff", enchant = 2718, cd = 90 }, -- Lesser Rune of Warding
	[42137] = { event = "buff", enchant = 2791, cd = 90 }, -- Greater Rune of Warding
	[18803] = { event = "buff", duration = 4, gem = 2828, cd = 35 }, -- Focus (Mystical Skyfire Diamond)
	[32848] = { event = "energize", gem = 2835, cd = 15 }, -- Mana Restore (Insightful Earthstorm Diamond)
	[39959] = { event = "buff", duration = 6, gem = 3155, cd = 40 }, -- Skyfire Swiftness (Thundering Skyfire Diamond)
	[46579] = { event = "damage", enchant = 3273, cd = 25 }, -- Deathfrost
	[46629] = { event = "debuff", enchant = 3273, cd = 25 }, -- Deathfrost
	[55382] = { event = "energize", gem = 3627, cd = 15 }, -- Mana Restore (Insightful Earthsiege Diamond)
	[55341] = { event = "heal", gem = 3640, cd = 45 }, -- Invigorating Earthsiege Health Regen (Invigorating Earthsiege Diamond)
	[55379] = { event = "buff", duration = 6, gem = 3643, cd = 40 }, -- Skyflare Swiftness (Thundering Skyflare Diamond)
	[55637] = { event = "buff", duration = 15, enchant = 3722, cd = 60 }, -- Lightweave (Lightweave Embroidery)
	[55767] = { event = "energize", enchant = 3728, cd = 45 }, -- Darkglow (Darkglow Embroidery)
	[55775] = { event = "buff", duration = 15, enchant = 3730, cd = 55 }, -- Swordguard Embroidery
	[59626] = { event = "buff", duration = 10, enchant = 3790, cd = 35 }, -- Black Magic
	[64568] = { event = "stack", duration = 20, enchant = 3870, cd = 10 }, -- Blood Reserve (Blood Draining)

	[22649] = { event = "summon", sets = { [261] = 2 }, cd = 120 }, -- Summon Eskhandar (Spirit of Eskhandar)
	[46833] = { event = "buff", duration = 15, sets = { [585] = 4, [743] = 4, [774] = 4 }, cd = 15 }, -- Wrath of Elune (Gladiator's Wildhide, Wyrmhide Battlegear)
	[43837] = { event = "buff", duration = 10, sets = { [627] = 4 }, cd = 60 }, -- Enlightenment (Crystalforge Raiment)
	[39950] = { event = "buff", duration = 10, sets = { [634] = 4 }, cd = 60 }, -- Wave Trance (Cataclysm Raiment)
	[41435] = { event = "buff", duration = 10, sets = { [699] = 2 }, cd = 45 }, -- The Twin Blades of Azzinoth
	[64868] = { event = "buff", duration = 15, sets = { [836] = 2 }, cd = 45 }, -- Praxis (Kirin Tor Garb)
	[64861] = { event = "buff", duration = 15, sets = { [838] = 4 }, cd = 45 }, -- Precision Shots (Scourgestalker Battlegear)
	[67210] = { event = "buff", duration = 15, sets = { [857] = 2, [858] = 2 }, cd = 15 }, -- Clearcasting (VanCleef's Battlegear, Garona's Battlegear)
	[67117] = { event = "buff", duration = 15, sets = { [871] = 2, [872] = 2 }, cd = 45 }, -- Unholy Might (Thassarian's Battlegear, Koltira's Battlegear)
	[69733] = { event = "heal", sets = { [881] = 2 }, cd = 50 }, -- Cauterizing Heal (Purified Shard of the Gods)
	[69729] = { event = "debuff", sets = { [881] = 2 }, cd = 50 }, -- Searing Flames (Purified Shard of the Gods)
	[69734] = { event = "heal", sets = { [882] = 2 }, cd = 50 }, -- Cauterizing Heal (Shiny Shard of the Gods)
	[69730] = { event = "debuff", sets = { [882] = 2 }, cd = 50 }, -- Searing Flames (Shiny Shard of the Gods)

	[63944] = { event = "buff", duration = 60, talent = true, cd = 15 }, -- Renewed Hope
	[60503] = { event = "buff", duration = 9, talent = true, cd = 5.8 }, -- Taste for Blood
	[56453] = { event = "buff", duration = 12, talent = true, cd = 22 }, -- Lock and Load
	[51675] = { event = "buff", talent = true, cd = 1 }, -- Unfair Advantage
	[50452] = { event = "summon", talent = true, cd = 20 }, -- Bloodworm (Bloodworms)
	[54741] = { event = "buff", duration = 10, talent = true, cd = 1 }, -- Firestarter
	[34936] = { event = "buff", duration = 8, talent = true, cd = 8 }, -- Backlash
	[33151] = { event = "buff", duration = 10, talent = true, cd = 6 }, -- Surge of Light
	[31616] = { event = "buff", duration = 10, talent = true, cd = 30 }, -- Nature's Guardian
	[17941] = { event = "buff", duration = 10, talent = true, cd = 6 }, -- Shadow Trance (Nightfall)
	[15250] = { event = "buff", talent = true, cd = 1 }, -- Setup
	[16459] = { event = "buff", talent = true, cd = 6 }, -- Sword Specialization
	[52916] = { event = "buff", duration = 8, talent = true, cd = 1 }, -- Honor Among Thieves
	[66235] = { event = "heal", talent = true, cd = 120 }, -- Ardent Defender
	[45182] = { event = "buff", duration = 3, talent = true, cd = 60 }, -- Cheating Death (Cheat Death)
	[34299] = { event = "heal", talent = true, cd = 6 }, -- Improved Leader of the Pack
}
