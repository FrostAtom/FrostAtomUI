local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")
local UF = ns:GetModule("UnitFrames")

local UnitName, UnitClass, UnitCreatureFamily = UnitName, UnitClass, UnitCreatureFamily
local GetSpellInfo = GetSpellInfo
local IsInInstance = IsInInstance
local wipe = wipe

local PlateLayer = ns.PlateLayer
local config = ns.Config.namePlates
local plates = NamePlates.plates

local ArenaIcons = {}
NamePlates.ArenaIcons = ArenaIcons

local MAX_ARENA = 5
local MAX_PARTY = 4

local HUNTER_FAMILIES = {
	Ability_Hunter_Pet_Wolf = { "Wolf", "Волк" },
	Ability_Hunter_Pet_Cat = { "Cat", "Кошка" },
	Ability_Hunter_Pet_Spider = { "Spider", "Паук" },
	Ability_Hunter_Pet_Bear = { "Bear", "Медведь" },
	Ability_Hunter_Pet_Boar = { "Boar", "Вепрь" },
	Ability_Hunter_Pet_Crocolisk = { "Crocolisk", "Кроколиск" },
	Ability_Hunter_Pet_Vulture = { "Carrion Bird", "Падальщик" },
	Ability_Hunter_Pet_Crab = { "Crab", "Краб" },
	Ability_Hunter_Pet_Gorilla = { "Gorilla", "Горилла" },
	Ability_Hunter_Pet_Raptor = { "Raptor", "Ящер" },
	Ability_Hunter_Pet_TallStrider = { "Tallstrider", "Долгоног" },
	Ability_Hunter_Pet_Scorpid = { "Scorpid", "Скорпид" },
	Ability_Hunter_Pet_Turtle = { "Turtle", "Черепаха" },
	Ability_Hunter_Pet_Bat = { "Bat", "Летучая мышь" },
	Ability_Hunter_Pet_Hyena = { "Hyena", "Гиена" },
	Ability_Hunter_Pet_Owl = { "Bird of Prey", "Сова", "Хищная птица" },
	Ability_Hunter_Pet_WindSerpent = { "Wind Serpent", "Крылатый змей" },
	Ability_Hunter_Pet_DragonHawk = { "Dragonhawk", "Дракондор" },
	Ability_Hunter_Pet_Ravager = { "Ravager", "Опустошитель" },
	Ability_Hunter_Pet_WarpStalker = { "Warp Stalker", "Прыгуана" },
	Ability_Hunter_Pet_Sporebat = { "Sporebat", "Спороскат" },
	Ability_Hunter_Pet_NetherRay = { "Nether Ray", "Скат Пустоты" },
	Spell_Nature_GuardianWard = { "Serpent", "Змей" },
	Ability_Hunter_Pet_Moth = { "Moth", "Мотылек" },
	Ability_Hunter_Pet_Chimera = { "Chimaera", "Химера" },
	Ability_Hunter_Pet_Devilsaur = { "Devilsaur", "Дьявозавр" },
	Ability_Hunter_Pet_Silithid = { "Silithid", "Силитид" },
	Ability_Hunter_Pet_Worm = { "Worm", "Червь" },
	Ability_Hunter_Pet_Rhino = { "Rhino", "Люторог" },
	Ability_Hunter_Pet_Wasp = { "Wasp", "Оса" },
	Ability_Hunter_Pet_CoreHound = { "Core Hound", "Гончая Недр" },
	Ability_Druid_PrimalPrecision = { "Spirit Beast", "Дух зверя" },
}

local DEMONS = {
	[688] = { "Imp", "Бес" }, -- Summon Imp
	[697] = { "Voidwalker", "Демон Бездны" }, -- Summon Voidwalker
	[712] = { "Succubus", "Суккуб" }, -- Summon Succubus
	[691] = { "Felhunter", "Охотник Скверны" }, -- Summon Felhunter
	[30146] = { "Felguard", "Страж Скверны" }, -- Summon Felguard
}

local HUNTER_PET_ICON = select(3, GetSpellInfo(883)) -- Call Pet
local GHOUL_ICON = select(3, GetSpellInfo(46584)) -- Raise Dead
local WATER_ELEMENTAL_ICON = select(3, GetSpellInfo(31687)) -- Summon Water Elemental
local GARGOYLE_ICON = select(3, GetSpellInfo(49206)) -- Summon Gargoyle

local GUARDIANS = {
	["Ebon Gargoyle"] = GARGOYLE_ICON,
	["Вороная горгулья"] = GARGOYLE_ICON,
}

local familyIcons = {}
for icon, names in pairs(HUNTER_FAMILIES) do
	for i = 1, #names do
		familyIcons[names[i]] = "Interface\\Icons\\" .. icon
	end
end

local demonIcons = {}
for spellId, names in pairs(DEMONS) do
	local icon = select(3, GetSpellInfo(spellId))
	for i = 1, #names do
		demonIcons[names[i]] = icon
	end
end

local ARENA_UNITS, ARENA_PET_UNITS = NamePlates.ARENA_UNITS, NamePlates.ARENA_PET_UNITS
local PARTY_UNITS, PARTY_PET_UNITS = {}, {}
for i = 1, MAX_PARTY do
	PARTY_UNITS[i] = "party" .. i
	PARTY_PET_UNITS[i] = "partypet" .. i
end

local inArena = false
local classes = { friendly = {}, hostile = {} }
local pets = { friendly = {}, hostile = {} }
local changed = false

local function petIcon(unit, owner)
	local _, class = UnitClass(owner)
	if class == "HUNTER" then
		return familyIcons[UnitCreatureFamily(unit)] or HUNTER_PET_ICON
	elseif class == "WARLOCK" then
		return demonIcons[UnitCreatureFamily(unit)]
	elseif class == "DEATHKNIGHT" then
		return GHOUL_ICON
	elseif class == "MAGE" then
		return WATER_ELEMENTAL_ICON
	end
end

local function unitName(unit)
	local name = UnitName(unit)
	if name and name ~= UNKNOWN and name ~= "" then
		return name
	end
end

local function remember(map, name, value)
	if value and map[name] ~= value then
		map[name] = value
		changed = true
	end
end

local function scanPlayer(unit, side)
	local name = unitName(unit)
	if name then
		local _, class = UnitClass(unit)
		remember(classes[side], name, class)
	end
end

local function scanPet(unit, owner, side)
	local name = unitName(unit)
	if name then
		remember(pets[side], name, petIcon(unit, owner))
	end
end

local function refreshPlates()
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() then
			local icon, coords = ArenaIcons.Identify(plate)
			if icon ~= plate.unitIcon or coords ~= plate.unitIconCoords then
				plate:OnShow()
			end
		end
	end
end

local function scan()
	if not inArena then
		return
	end
	scanPet("pet", "player", "friendly")
	for i = 1, MAX_PARTY do
		scanPlayer(PARTY_UNITS[i], "friendly")
		scanPet(PARTY_PET_UNITS[i], PARTY_UNITS[i], "friendly")
	end
	for i = 1, MAX_ARENA do
		scanPlayer(ARENA_UNITS[i], "hostile")
		scanPet(ARENA_PET_UNITS[i], ARENA_UNITS[i], "hostile")
	end
	if changed then
		changed = false
		refreshPlates()
	end
end

local function requestScan()
	ns.Defer(scan, scan)
end

function ArenaIcons.Identify(plate)
	if not inArena then
		return
	end
	local settings = plate.settings
	local friendly = settings == config.friendlyPlayer or settings == config.friendlyNpc
	local player = settings == config.friendlyPlayer or settings == config.enemyPlayer
	local owner = friendly and config.friendlyPlayer or config.enemyPlayer
	if not (player and owner.arenaIcon or not player and owner.arenaPetIcon) then
		return
	end
	local info = plate.info
	local name = info.name
	if not name then
		return
	end
	local side = friendly and "friendly" or "hostile"
	if player then
		local class = classes[side][name] or not friendly and info.class
		local coords = class and UF.classCoords[class]
		if coords then
			return UF.CLASS_ICONS, coords
		end
		return
	end
	return pets[side][name] or GUARDIANS[name]
end

local function onEnteringWorld()
	local _, instanceType = IsInInstance()
	inArena = instanceType == "arena"
	wipe(classes.friendly)
	wipe(classes.hostile)
	wipe(pets.friendly)
	wipe(pets.hostile)
	changed = false
	requestScan()
	refreshPlates()
end

NamePlates:OnInitialize(function(self)
	if not config.enabled then
		return
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", requestScan)
	self:RegisterEvent("ARENA_OPPONENT_UPDATE", requestScan)
	self:RegisterEvent("UNIT_PET", requestScan)
	self:RegisterEvent("UNIT_NAME_UPDATE", requestScan)
end)
