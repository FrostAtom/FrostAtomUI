local _, ns = ...

local SPELLS = {
	DEATHKNIGHT = {
		{ 47528, 10 }, -- Mind Freeze
		{ 47476, 120 }, -- Strangulate
		{ 49203, 60 }, -- Hungering Cold
		{ 48707, 45 }, -- Anti-Magic Shell
		{ 48792, 120 }, -- Icebound Fortitude
		{ 49039, 120 }, -- Lichborne
		{ 51052, 120 }, -- Anti-Magic Zone
		{ 48743, 120 }, -- Death Pact
		{ 55233, 60 }, -- Vampiric Blood
		{ 49222, 60 }, -- Bone Shield
		{ 51271, 60 }, -- Unbreakable Armor
		{ 49005, 180 }, -- Mark of Blood
		{ 49576, 35 }, -- Death Grip
		{ 49028, 90 }, -- Dancing Rune Weapon
		{ 49016, 180 }, -- Hysteria
		{ 49206, 180 }, -- Summon Gargoyle
		{ 47568, 300 }, -- Empower Rune Weapon
		{ 46584, 180 }, -- Raise Dead
		{ 42650, 600 }, -- Army of the Dead
		{ 45529, 60 }, -- Blood Tap
		{ 43265, 30, ranks = { 49936, 49937, 49938 } }, -- Death and Decay
	},
	DRUID = {
		{ 16979, 15 }, -- Feral Charge - Bear
		{ 49376, 30 }, -- Feral Charge - Cat
		{ 5211, 60, ranks = { 6798, 8983 } }, -- Bash
		{ 22570, 10, ranks = { 49802 } }, -- Maim
		{ 50516, 20, ranks = { 53223, 53225, 53226, 53227, 61384, 61387, 61388, 61390, 61391 } }, -- Typhoon
		{ 22812, 60 }, -- Barkskin
		{ 61336, 180 }, -- Survival Instincts
		{ 22842, 180 }, -- Frenzied Regeneration
		{ 17116, 180 }, -- Nature's Swiftness
		{ 18562, 15 }, -- Swiftmend
		{ 16689, 60, ranks = { 16810, 16811, 16812, 16813, 17329, 27009, 53312 } }, -- Nature's Grasp
		{ 29166, 180 }, -- Innervate
		{ 50334, 180 }, -- Berserk
		{ 33831, 180 }, -- Force of Nature
		{ 48505, 90, ranks = { 53199, 53200, 53201 } }, -- Starfall
		{ 1850, 180, ranks = { 9821, 33357 } }, -- Dash
		{ 20484, 600, ranks = { 20739, 20742, 20747, 20748, 26994, 48477 } }, -- Rebirth
	},
	HUNTER = {
		{ 34490, 20 }, -- Silencing Shot
		{ 19503, 30 }, -- Scatter Shot
		{ 19386, 60, ranks = { 24132, 24133, 27068, 49011, 49012 } }, -- Wyvern Sting
		{ 1499, 30, ranks = { 14310, 14311 } }, -- Freezing Trap
		{ 60192, 30 }, -- Freezing Arrow
		{ 13809, 30 }, -- Frost Trap
		{ 34600, 30 }, -- Snake Trap
		{ 19577, 60 }, -- Intimidation
		{ 19263, 90 }, -- Deterrence
		{ 5384, 30 }, -- Feign Death
		{ 53271, 60 }, -- Master's Call
		{ 781, 25 }, -- Disengage
		{ 23989, 180 }, -- Readiness
		{ 19574, 120 }, -- Bestial Wrath
		{ 3045, 300 }, -- Rapid Fire
		{ 53480, 60, pet = true }, -- Roar of Sacrifice
		{ 1543, 20 }, -- Flare
	},
	MAGE = {
		{ 2139, 24 }, -- Counterspell
		{ 44572, 30 }, -- Deep Freeze
		{ 31661, 20, ranks = { 33041, 33042, 33043, 42949, 42950 } }, -- Dragon's Breath
		{ 11113, 30, ranks = { 13018, 13019, 13020, 13021, 27133, 33933, 42944, 42945 } }, -- Blast Wave
		{ 122, 25, ranks = { 865, 6131, 10230, 27088, 42917 } }, -- Frost Nova
		{ 45438, 300 }, -- Ice Block
		{ 11958, 480 }, -- Cold Snap
		{ 11426, 30, ranks = { 13031, 13032, 13033, 27134, 33405, 43038, 43039 } }, -- Ice Barrier
		{ 66, 180 }, -- Invisibility
		{ 1953, 15 }, -- Blink
		{ 12472, 180 }, -- Icy Veins
		{ 12042, 120 }, -- Arcane Power
		{ 12043, 120 }, -- Presence of Mind
		{ 11129, 120 }, -- Combustion
		{ 55342, 180 }, -- Mirror Image
		{ 31687, 180 }, -- Summon Water Elemental
		{ 12051, 240 }, -- Evocation
	},
	PALADIN = {
		{ 853, 60, ranks = { 5588, 5589, 10308 } }, -- Hammer of Justice
		{ 20066, 60 }, -- Repentance
		{ 31935, 30, ranks = { 32699, 32700, 48826, 48827 } }, -- Avenger's Shield
		{ 642, 300 }, -- Divine Shield
		{ 498, 180 }, -- Divine Protection
		{ 1022, 300, ranks = { 5599, 10278 } }, -- Hand of Protection
		{ 6940, 120 }, -- Hand of Sacrifice
		{ 64205, 120 }, -- Divine Sacrifice
		{ 1044, 25 }, -- Hand of Freedom
		{ 31821, 120 }, -- Aura Mastery
		{ 633, 1200, ranks = { 2799, 10310, 27154, 48788 } }, -- Lay on Hands
		{ 19752, 600 }, -- Divine Intervention
		{ 31884, 180 }, -- Avenging Wrath
		{ 20216, 120 }, -- Divine Favor
		{ 31842, 180 }, -- Divine Illumination
		{ 54428, 60 }, -- Divine Plea
	},
	PRIEST = {
		{ 15487, 45 }, -- Silence
		{ 64044, 120 }, -- Psychic Horror
		{ 8122, 30, ranks = { 8124, 10888, 10890 } }, -- Psychic Scream
		{ 33206, 180 }, -- Pain Suppression
		{ 47788, 180 }, -- Guardian Spirit
		{ 47585, 120 }, -- Dispersion
		{ 19236, 120, ranks = { 19238, 19240, 19241, 19242, 19243, 25437, 48172, 48173 } }, -- Desperate Prayer
		{ 6346, 180 }, -- Fear Ward
		{ 14751, 180 }, -- Inner Focus
		{ 10060, 120 }, -- Power Infusion
		{ 34433, 300 }, -- Shadowfiend
	},
	ROGUE = {
		{ 1766, 10, ranks = { 1767, 1768, 1769, 38768 } }, -- Kick
		{ 2094, 180 }, -- Blind
		{ 408, 20, ranks = { 8643 } }, -- Kidney Shot
		{ 1776, 10, ranks = { 1777, 8629, 11285, 11286, 38764 } }, -- Gouge
		{ 51722, 60 }, -- Dismantle
		{ 31224, 90 }, -- Cloak of Shadows
		{ 5277, 180, ranks = { 26669 } }, -- Evasion
		{ 1856, 180, ranks = { 1857, 26889 } }, -- Vanish
		{ 14185, 480 }, -- Preparation
		{ 36554, 30 }, -- Shadowstep
		{ 2983, 180, ranks = { 8696, 11305 } }, -- Sprint
		{ 51713, 60 }, -- Shadow Dance
		{ 14177, 180 }, -- Cold Blood
		{ 13750, 180 }, -- Adrenaline Rush
		{ 51690, 120 }, -- Killing Spree
		{ 13877, 120 }, -- Blade Flurry
		{ 14183, 20 }, -- Premeditation
	},
	SHAMAN = {
		{ 57994, 6 }, -- Wind Shear
		{ 51514, 45 }, -- Hex
		{ 8177, 15 }, -- Grounding Totem
		{ 51490, 45, ranks = { 59156, 59158, 59159 } }, -- Thunderstorm
		{ 30823, 60 }, -- Shamanistic Rage
		{ 16188, 120 }, -- Nature's Swiftness
		{ 16190, 300 }, -- Mana Tide Totem
		{ 2825, 300, ranks = { 32182 } }, -- Bloodlust / Heroism
		{ 16166, 180 }, -- Elemental Mastery
		{ 51533, 180 }, -- Feral Spirit
		{ 55198, 180 }, -- Tidal Force
	},
	WARLOCK = {
		{ 19244, 24, ranks = { 19647 }, pet = true }, -- Spell Lock
		{ 6789, 120, ranks = { 17925, 17926, 27223, 47859, 47860 } }, -- Death Coil
		{ 5484, 40, ranks = { 17928 } }, -- Howl of Terror
		{ 30283, 20, ranks = { 30413, 30414, 47846, 47847 } }, -- Shadowfury
		{ 54785, 45 }, -- Demon Charge
		{ 48020, 30 }, -- Demonic Circle: Teleport
		{ 47241, 180 }, -- Metamorphosis
		{ 47193, 60 }, -- Demonic Empowerment
		{ 18708, 180 }, -- Fel Domination
	},
	WARRIOR = {
		{ 6552, 10, ranks = { 6554 } }, -- Pummel
		{ 72, 12, ranks = { 1671, 1672, 29704 } }, -- Shield Bash
		{ 100, 15, ranks = { 6178, 11578 } }, -- Charge
		{ 20252, 30, ranks = { 20616, 20617, 25272, 25275 } }, -- Intercept
		{ 5246, 120 }, -- Intimidating Shout
		{ 12809, 30 }, -- Concussion Blow
		{ 46968, 20 }, -- Shockwave
		{ 676, 60 }, -- Disarm
		{ 23920, 10 }, -- Spell Reflection
		{ 3411, 30 }, -- Intervene
		{ 871, 300 }, -- Shield Wall
		{ 12975, 180 }, -- Last Stand
		{ 55694, 180 }, -- Enraged Regeneration
		{ 2565, 60 }, -- Shield Block
		{ 18499, 30 }, -- Berserker Rage
		{ 46924, 90 }, -- Bladestorm
		{ 12292, 180 }, -- Death Wish
		{ 1719, 300 }, -- Recklessness
		{ 20230, 300 }, -- Retaliation
		{ 60970, 45 }, -- Heroic Fury
		{ 64382, 300 }, -- Shattering Throw
	},
	COMMON = {
		{ 42292, 120 }, -- PvP Trinket
		{ 59752, 120 }, -- Every Man for Himself
		{ 7744, 120 }, -- Will of the Forsaken
		{ 20549, 120 }, -- War Stomp
		{ 20589, 105 }, -- Escape Artist
		{ 28730, 120, ranks = { 25046, 50613 } }, -- Arcane Torrent
		{ 20572, 120, ranks = { 33697, 33702 } }, -- Blood Fury
		{ 26297, 180 }, -- Berserking
		{ 20594, 120 }, -- Stoneform
		{ 58984, 120 }, -- Shadowmeld
		{ 28880, 180, ranks = { 59542, 59543, 59544, 59545, 59547, 59548 } }, -- Gift of the Naaru
	},
}

local SHARED_COOLDOWNS = {
	[42292] = { 59752, 120, 7744, 45 },
	[59752] = { 42292, 120 },
	[7744] = { 42292, 45 },
	[16979] = { 49376, 15 },
	[49376] = { 16979, 15 },
	[31884] = { 642, 30, 498, 30 }, -- forbearance
	[871] = { 1719, 12, 20230, 12 },
	[1719] = { 871, 12, 20230, 12 },
	[20230] = { 871, 12, 1719, 12 },
}

local RESETS = {
	[23989] = "*", -- Readiness
	[11958] = { 45438, 122, 44572, 12472, 11426, 31687 }, -- Cold Snap
	[14185] = { 5277, 2983, 1856, 14177, 36554, 14183 }, -- Preparation
}

local DUPLICATE_WINDOW = 2

local bit_band = bit.band
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitRace = UnitRace
local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET

ns.COOLDOWN_UPDATED = "FrostAtomUI_COOLDOWN_UPDATED"

local CooldownTracker = ns:NewModule("CooldownTracker")

local spellInfo = {}
local baseSpell = {}

do
	local order = 0
	for _, spells in pairs(SPELLS) do
		for _, entry in ipairs(spells) do
			local id = entry[1]
			order = order + 1
			spellInfo[id] = { id = id, cooldown = entry[2], order = order, pet = entry.pet }
			baseSpell[id] = id
			for _, rank in ipairs(entry.ranks or {}) do
				baseSpell[rank] = id
			end
		end
	end
end

CooldownTracker.spellInfo = spellInfo

local RACIALS = {
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
}
local PVP_TRINKET = 42292

local trackedList = {}
function CooldownTracker:GetTracked(unit)
	local _, class = UnitClass(unit)
	local spells = class and SPELLS[class]
	if not spells then
		return
	end

	wipe(trackedList)
	for _, entry in ipairs(spells) do
		trackedList[#trackedList + 1] = entry[1]
	end
	trackedList[#trackedList + 1] = PVP_TRINKET
	local racial = RACIALS[select(2, UnitRace(unit))]
	if racial then
		trackedList[#trackedList + 1] = racial
	end
	return trackedList
end

function CooldownTracker:GetCooldown(guid, id)
	local entries = guid and self.cooldowns[guid]
	local entry = entries and entries[id]
	if entry and entry.start + entry.duration > GetTime() then
		return entry.start, entry.duration
	end
end

local cooldowns = {}
CooldownTracker.cooldowns = cooldowns

local PET_OWNERS = {
	pet = "player",
	partypet1 = "party1",
	partypet2 = "party2",
	partypet3 = "party3",
	partypet4 = "party4",
	arenapet1 = "arena1",
	arenapet2 = "arena2",
	arenapet3 = "arena3",
}

local function petOwnerGUID(petGUID)
	for petUnit, owner in pairs(PET_OWNERS) do
		if UnitGUID(petUnit) == petGUID then
			return UnitGUID(owner)
		end
	end
end

local function sortByOrder(a, b)
	return spellInfo[a.id].order < spellInfo[b.id].order
end

local activeList = {}
function CooldownTracker:GetActive(guid)
	wipe(activeList)

	local entries = guid and cooldowns[guid]
	if not entries then
		return activeList
	end

	local now = GetTime()
	for id, entry in pairs(entries) do
		if entry.start + entry.duration <= now then
			entries[id] = nil
		else
			entry.id = id
			activeList[#activeList + 1] = entry
		end
	end

	table.sort(activeList, sortByOrder)
	return activeList
end

local function getEntries(guid)
	local entries = cooldowns[guid]
	if not entries then
		entries = {}
		cooldowns[guid] = entries
	end
	return entries
end

local function startCooldown(guid, id, duration, now)
	local entries = getEntries(guid)
	local entry = entries[id]
	if not entry then
		entry = {}
		entries[id] = entry
	end
	entry.start = now
	entry.duration = duration
end

function CooldownTracker:OnCast(guid, id, isDuplicateEvent)
	id = baseSpell[id]
	local info = id and spellInfo[id]
	if not info then
		return
	end

	local now = GetTime()
	local entries = getEntries(guid)

	local current = entries[id]
	if isDuplicateEvent and current and now - current.start < DUPLICATE_WINDOW then
		return
	end

	startCooldown(guid, id, info.cooldown, now)

	local shared = SHARED_COOLDOWNS[id]
	if shared then
		for i = 1, #shared, 2 do
			local other, duration = shared[i], shared[i + 1]
			local entry = entries[other]
			if not entry or entry.start + entry.duration < now + duration then
				startCooldown(guid, other, duration, now)
			end
		end
	end

	local resets = RESETS[id]
	if resets == "*" then
		for other in pairs(entries) do
			if other ~= id then
				entries[other] = nil
			end
		end
	elseif resets then
		for _, other in ipairs(resets) do
			entries[other] = nil
		end
	end

	ns:Fire(ns.COOLDOWN_UPDATED, guid)
	return true
end

function CooldownTracker:Reset(guid)
	if guid then
		cooldowns[guid] = nil
	else
		wipe(cooldowns)
	end
	ns:Fire(ns.COOLDOWN_UPDATED, guid)
end

local function onCombatLogEvent(self, _, event, sourceGUID, _, sourceFlags, _, _, _, spellId)
	local isDuplicateEvent
	if event == "SPELL_CAST_SUCCESS" then
		isDuplicateEvent = false
	elseif event == "SPELL_AURA_APPLIED" or event == "SPELL_MISSED" then
		isDuplicateEvent = true
	else
		return
	end

	local id = baseSpell[spellId]
	if not id then
		return
	end

	if bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET) ~= 0 then
		if not spellInfo[id].pet then
			return
		end
		sourceGUID = petOwnerGUID(sourceGUID)
	elseif bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then
		return
	end

	if sourceGUID then
		self:OnCast(sourceGUID, id, isDuplicateEvent)
	end
end

function CooldownTracker:PLAYER_ENTERING_WORLD()
	self:Reset()
end

function CooldownTracker:Initialize()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local TEST_UNITS = { "party1", "party2", "party3", "party4", "arena1", "arena2", "arena3" }
local TEST_SPELLS = 4
local testing = false

SlashCmdList.FROSTATOMUI_COOLDOWN_TEST = function()
	testing = not testing
	if not testing then
		CooldownTracker:Reset()
		return
	end

	for _, unit in ipairs(TEST_UNITS) do
		local guid = UnitGUID(unit)
		local spells = guid and SPELLS[select(2, UnitClass(unit))]
		if spells then
			for i = 1, math.min(TEST_SPELLS, #spells) do
				CooldownTracker:OnCast(guid, spells[i][1])
			end
			CooldownTracker:OnCast(guid, 42292)
		end
	end
end
SLASH_FROSTATOMUI_COOLDOWN_TEST1 = "/cdtest"
