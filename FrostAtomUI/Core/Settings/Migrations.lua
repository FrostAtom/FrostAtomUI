local _, ns = ...

local Store = ns.SettingsStore
local copy = Store.copy
local auraIcon, trackerGroup = ns.DefaultsKit.auraIcon, ns.DefaultsKit.trackerGroup

local HEALTH_COLOR_SECTIONS = { unitFrames = "health", namePlates = "health", playerPlate = "custom" }

local function migrateAuraTracker(profile)
	local old = profile.auraTracker
	if not old then
		return
	end
	profile.auraTracker = nil
	local trackers = profile.trackers or {}
	profile.trackers = trackers
	if old.enabled == false then
		trackers.enabled = false
	end
	if not old.auras or trackers.groups then
		return
	end
	local groups = {}
	for _, group in ipairs(ns.Defaults.trackers.groups) do
		if not old.auras[group.class] then
			groups[#groups + 1] = copy(group)
		end
	end
	for class, auras in pairs(old.auras) do
		for _, aura in ipairs(auras) do
			local spell = tostring(aura.spell)
			local icon = auraIcon(spell, aura.isMine, aura.unit)
			icon.debuff = aura.debuff and true or false
			local group =
				trackerGroup(GetSpellInfo(aura.spell) or spell, class, aura.point, aura.size or 36, 2, { icon })
			group.enabled = aura.enabled ~= false
			groups[#groups + 1] = group
		end
	end
	trackers.groups = groups
end

local ACTION_BAR_KEYS = { "bar1", "bar2", "bar3", "bar4", "bar5", "stance", "pet" }

local function migrateActionBarGap(profile)
	local actionBar = profile.actionBar
	local gap = actionBar and actionBar.gap
	if gap == nil then
		return
	end
	actionBar.gap = nil
	for _, key in ipairs(ACTION_BAR_KEYS) do
		local bar = actionBar[key] or {}
		actionBar[key] = bar
		if bar.spacing == nil then
			bar.spacing = gap
		end
	end
end

local TOTEM_BAR_PATH = "actionBar.totemBar"

local function renameAnchor(value, from, to)
	for _, child in pairs(value) do
		if type(child) == "table" then
			if child[4] == from and type(child[1]) == "string" then
				child[4] = to
			end
			renameAnchor(child, from, to)
		end
	end
end

local function migrateTotemBar(profile)
	local actionBar = profile.actionBar
	local totemBar = actionBar and actionBar.totemBar
	if not totemBar or totemBar[1] == nil then
		return
	end
	actionBar.totemBar = { point = totemBar }
	renameAnchor(profile, TOTEM_BAR_PATH, TOTEM_BAR_PATH .. ".point")
end

local GROUP_GROWTH_OFFSETS = {
	DOWN = { 0, -1 },
	UP = { 0, 1 },
	RIGHT = { 1, 0 },
	LEFT = { -1, 0 },
}

local function migrateGroupPoints(unitFrames, prefix, count)
	local spacingKey, growthKey = prefix .. "Spacing", prefix .. "Growth"
	local spacing = unitFrames[spacingKey] or unitFrames.groupSpacing
	local growth = unitFrames[growthKey]
	unitFrames[spacingKey], unitFrames[growthKey] = nil, nil
	if spacing == nil and growth == nil then
		return
	end
	local defaults = ns.Defaults.unitFrames
	local first = unitFrames[prefix] or defaults[prefix]
	local point = first[1]
	local step = GROUP_GROWTH_OFFSETS[growth] or GROUP_GROWTH_OFFSETS.DOWN
	spacing = spacing or -defaults[prefix .. "2"][3]
	for i = 2, count do
		local key = prefix .. i
		if unitFrames[key] == nil then
			local anchor = "unitFrames." .. (i == 2 and prefix or prefix .. (i - 1))
			unitFrames[key] = { point, step[1] * spacing, step[2] * spacing, anchor, point }
		end
	end
end

local TARGET_AURA_ROWS = 2
local TARGET_CASTBAR_GAP = 4
local CASTBAR_ICON_GAP = 2
local LEGACY_CASTBAR_HEIGHT = 25
local LEGACY_GROUP_CASTBAR_SCALE = 0.8

local function targetCastbarPoint(unitFrames, unit)
	local defaults = ns.Defaults.unitFrames
	local width = unitFrames.playerWidth or defaults.playerWidth
	local perRow = unitFrames.targetAuraPerRow or defaults.targetAuraPerRow
	local scale = unitFrames.ownAuraScale or defaults.targetOwnAuraScale
	local castbarHeight = unitFrames.castbarHeight or LEGACY_CASTBAR_HEIGHT
	local auraSize = width / perRow - 1
	local fitted = math.max(math.floor((width + 1) / (auraSize + 1)), 1)
	local size = (width + 1) / fitted - 1
	if scale > 1 then
		size = math.floor(size * scale + 0.5)
	end
	local gridHeight = TARGET_AURA_ROWS * (size + 1) - 1
	local offset = TARGET_CASTBAR_GAP * 3 + gridHeight * 2
	return {
		"TOPLEFT",
		castbarHeight + CASTBAR_ICON_GAP,
		-math.floor(offset + 0.5),
		"unitFrames." .. unit,
		"BOTTOMLEFT",
	}
end

local function migrateGroupSpacing(profile)
	local unitFrames = profile.unitFrames
	if unitFrames then
		migrateGroupPoints(unitFrames, "party", 4)
		migrateGroupPoints(unitFrames, "arena", 3)
		unitFrames.groupSpacing = nil
	end
end

local function setChanged(unitFrames, key, value)
	if unitFrames[key] == nil and value ~= ns.Defaults.unitFrames[key] then
		unitFrames[key] = value
	end
end

local function migrateCastbarLayout(profile)
	local unitFrames = profile.unitFrames
	if not unitFrames then
		return
	end
	local defaults = ns.Defaults.unitFrames
	local castbarHeight = unitFrames.castbarHeight or LEGACY_CASTBAR_HEIGHT
	local castbarWidth = (unitFrames.playerWidth or defaults.playerWidth) - castbarHeight - CASTBAR_ICON_GAP
	for _, unit in ipairs({ "target", "focus" }) do
		local key = unit .. "Castbar"
		if unitFrames[key] == nil then
			local point = targetCastbarPoint(unitFrames, unit)
			local default = defaults[key]
			if point[2] ~= default[2] or point[3] ~= default[3] then
				unitFrames[key] = point
			end
		end
		setChanged(unitFrames, key .. "Width", castbarWidth)
	end
	for _, prefix in ipairs({ "party", "arena" }) do
		local width = unitFrames[prefix .. "Width"] or defaults[prefix .. "Width"]
		setChanged(unitFrames, prefix .. "CastbarWidth", math.floor(width * LEGACY_GROUP_CASTBAR_SCALE + 0.5))
	end
end

local SQUARE_SIZE_SOURCES = {
	pet = "playerHeight",
	targetOfTarget = "playerHeight",
	focusTarget = "playerHeight",
	partyPet = "partyHeight",
	partyTarget = "partyHeight",
	arenaPet = "arenaHeight",
	arenaTarget = "arenaHeight",
}

local function migrateSquareFrames(profile)
	local unitFrames = profile.unitFrames
	if not unitFrames then
		return
	end
	if unitFrames.showPet == false then
		setChanged(unitFrames, "showPartyPet", false)
		setChanged(unitFrames, "showArenaPet", false)
	end
	for key, source in pairs(SQUARE_SIZE_SOURCES) do
		local height = unitFrames[source]
		if height then
			setChanged(unitFrames, key .. "Width", height)
			setChanged(unitFrames, key .. "Height", height)
		end
	end
end

local LEGACY_PLAYER_DEBUFF_GAP_SCALE = 0.2

local function migratePlayerDebuffs(profile)
	local unitFrames = profile.unitFrames
	if not unitFrames or unitFrames.playerDebuffs ~= nil then
		return
	end
	local defaults = ns.Defaults.unitFrames
	local growth = unitFrames.playerAuraGrowth or defaults.playerAuraGrowth
	local size = unitFrames.playerAuraSize or defaults.playerAuraSize
	setChanged(unitFrames, "playerDebuffGrowth", growth)
	local gap = math.floor(size * LEGACY_PLAYER_DEBUFF_GAP_SCALE + 0.5)
	local default = defaults.playerDebuffs
	if growth ~= defaults.playerAuraGrowth or gap ~= -default[3] then
		local point = growth == "RIGHT" and "TOPLEFT" or "TOPRIGHT"
		unitFrames.playerDebuffs = { point, 0, -gap, default[4], (point:gsub("^TOP", "BOTTOM")) }
	end
end

local function migrateDiminishArenaSize(profile)
	local config = profile.diminishingReturns
	if config and config.size ~= nil and config.arenaSize == nil then
		config.arenaSize = config.size
	end
end

local function migrateCastbarHeight(profile)
	local unitFrames = profile.unitFrames
	local height = unitFrames and unitFrames.castbarHeight
	if height == nil then
		return
	end
	for _, prefix in ipairs({ "target", "focus", "party", "arena" }) do
		setChanged(unitFrames, prefix .. "CastbarHeight", height)
	end
	unitFrames.castbarHeight = nil
end

local function migrateClassColorHealth(profile)
	for name, fallback in pairs(HEALTH_COLOR_SECTIONS) do
		local section = profile[name]
		if section and section.classColorHealth ~= nil then
			section.healthColorMode = section.healthColorMode or (section.classColorHealth and "class" or fallback)
			section.classColorHealth = nil
		end
	end
end

local NAME_PLATE_CATEGORIES = { "enemyPlayer", "friendlyPlayer", "enemyNpc", "friendlyNpc" }
local NAME_PLATE_KEYS = {
	barWidth = "width",
	barHeight = "height",
	castbarHeight = "castbarHeight",
	showName = "showName",
	showAuras = "showAuras",
}
local NAME_PLATE_OBSOLETE = {
	"barWidth",
	"barHeight",
	"castbarHeight",
	"showName",
	"showAuras",
	"showTargetPercent",
	"healthTextAll",
	"healthColorMode",
	"friendlyClassColors",
}

local function setIfChanged(target, defaults, key, value)
	if value ~= nil and target[key] == nil and value ~= defaults[key] then
		target[key] = value
	end
end

local function migrateNamePlateCategories(profile)
	local namePlates = profile.namePlates
	if not namePlates then
		return
	end
	local healthText
	if namePlates.showTargetPercent == false then
		healthText = "none"
	elseif namePlates.healthTextAll then
		healthText = "all"
	end
	local colorMode = namePlates.healthColorMode == "health" and "health" or nil
	local groupClassColors = namePlates.friendlyClassColors ~= false
	for _, key in ipairs(NAME_PLATE_CATEGORIES) do
		local defaults = ns.Defaults.namePlates[key]
		local category = namePlates[key] or {}
		for old, new in pairs(NAME_PLATE_KEYS) do
			setIfChanged(category, defaults, new, namePlates[old])
		end
		setIfChanged(category, defaults, "healthText", healthText)
		setIfChanged(category, defaults, "healthColorMode", colorMode)
		if key == "friendlyPlayer" and not groupClassColors then
			setIfChanged(category, defaults, "nameColorMode", "white")
		end
		if next(category) then
			namePlates[key] = category
		end
	end
	for _, key in ipairs(NAME_PLATE_OBSOLETE) do
		namePlates[key] = nil
	end
	local friendly = namePlates.friendlyPlayer
	if friendly then
		if friendly.healthColorMode == "class" then
			friendly.healthColorMode = nil
		end
		if friendly.nameColorMode == "class" then
			friendly.nameColorMode = nil
		end
	end
end

local UNIT_FRAME_SPLIT_KEYS = {
	ownAuraScale = { "targetOwnAuraScale", "focusOwnAuraScale" },
	auraOrder = { "targetAuraOrder", "focusAuraOrder", "partyAuraOrder" },
	gridGap = { "partyAuraSpacing", "arenaAuraSpacing" },
	groupDebuffSize = { "partyDebuffSize", "arenaDebuffSize" },
	groupDebuffMax = { "partyDebuffMax", "arenaDebuffMax" },
}
local UNIT_FRAME_SEED_KEYS = {
	playerWidth = { "targetWidth", "focusWidth" },
	playerHeight = { "targetHeight", "focusHeight" },
	targetAuraPerRow = { "focusAuraPerRow" },
	petPower = { "partyPetPower", "arenaPetPower" },
}

local function seedUnitFrameKeys(unitFrames, keys)
	for old, targets in pairs(keys) do
		local value = unitFrames[old]
		if value ~= nil then
			for _, key in ipairs(targets) do
				setChanged(unitFrames, key, value)
			end
		end
	end
end

local function migrateUnitFrameCategories(profile, seed)
	local unitFrames = profile.unitFrames
	if not unitFrames then
		return
	end
	for old in pairs(UNIT_FRAME_SPLIT_KEYS) do
		if unitFrames[old] ~= nil then
			seed = true
		end
	end
	if seed then
		seedUnitFrameKeys(unitFrames, UNIT_FRAME_SEED_KEYS)
	end
	seedUnitFrameKeys(unitFrames, UNIT_FRAME_SPLIT_KEYS)
	for old in pairs(UNIT_FRAME_SPLIT_KEYS) do
		unitFrames[old] = nil
	end
end

local GROUP_COOLDOWN_SPLIT_KEYS = {
	size = { "friendlySize", "enemySize", "friendlyInterruptSize", "enemyInterruptSize" },
	spacing = { "friendlySpacing", "enemySpacing", "friendlyInterruptSpacing", "enemyInterruptSpacing" },
	perRow = { "friendlyPerRow", "enemyPerRow", "friendlyInterruptPerRow", "enemyInterruptPerRow" },
	rowSpacing = { "friendlyRowSpacing", "enemyRowSpacing", "friendlyInterruptRowSpacing", "enemyInterruptRowSpacing" },
	framePerRow = { "friendlyFramePerRow", "enemyFramePerRow" },
}

local function migrateGroupCooldownLayout(profile)
	local config = profile.groupCooldowns
	if not config then
		return
	end
	local defaults = ns.Defaults.groupCooldowns
	for old, targets in pairs(GROUP_COOLDOWN_SPLIT_KEYS) do
		for _, key in ipairs(targets) do
			setIfChanged(config, defaults, key, config[old])
		end
		config[old] = nil
	end
end

local function migrateGroupCooldownInterruptGrowth(profile)
	local config = profile.groupCooldowns
	if not config then
		return
	end
	local defaults = ns.Defaults.groupCooldowns
	for _, side in ipairs({ "friendly", "enemy" }) do
		setIfChanged(config, defaults, side .. "InterruptGrowth", config[side .. "Growth"])
	end
end

local function migrateLoseControl(profile)
	local unitFrames = profile.unitFrames
	local shown = unitFrames and unitFrames.showLoseControl
	if shown == nil then
		return
	end
	unitFrames.showLoseControl = nil
	local config = profile.loseControl or {}
	setIfChanged(config, ns.Defaults.loseControl, "enabled", shown)
	if next(config) then
		profile.loseControl = config
	end
end

local UNIT_FRAME_TEXT_KEYS = {
	leftText = { "healthTexts", "BOTTOMLEFT", "text" },
	leftTextHover = { "healthTexts", "BOTTOMLEFT", "hover" },
	rightText = { "healthTexts", "BOTTOMRIGHT", "text" },
	rightTextHover = { "healthTexts", "BOTTOMRIGHT", "hover" },
	powerText = { "powerTexts", "RIGHT", "text" },
	powerTextHover = { "powerTexts", "RIGHT", "hover" },
}

local function migrateUnitFrameTexts(profile)
	local unitFrames = profile.unitFrames
	if not unitFrames then
		return
	end
	for old, target in pairs(UNIT_FRAME_TEXT_KEYS) do
		local value = unitFrames[old]
		if value ~= nil then
			unitFrames[old] = nil
			local group, point, field = target[1], target[2], target[3]
			local texts = unitFrames[group] or {}
			local slot = texts[point] or {}
			setIfChanged(slot, ns.Defaults.unitFrames[group][point], field, value)
			if next(slot) then
				texts[point] = slot
				unitFrames[group] = texts
			end
		end
	end
end

local MERGED_TOGGLES = {
	{ "unitFrames", "cooldownReadyFlash", "cooldownTimer", "readyFlash", false },
	{ "groupCooldowns", "readyFlash", "cooldownTimer", "readyFlash", false },
	{ "unitFrames", "hoverHighlight", "unitFrames", "hoverAlpha", 0 },
	{ "equipment", "durabilityWarning", "equipment", "durabilityThreshold", 0 },
	{ "chat", "fadeMessages", "chat", "fadeTime", 0 },
	{ "announce", "arenaResult", "announce", "arenaResultToParty", false },
}

local function migrateMergedToggles(profile)
	for _, entry in ipairs(MERGED_TOGGLES) do
		local source = profile[entry[1]]
		local value = source and source[entry[2]]
		if source then
			source[entry[2]] = nil
		end
		if value == false then
			local target = profile[entry[3]] or {}
			target[entry[4]] = entry[5]
			profile[entry[3]] = target
		end
	end
end

local HIDE_BLIZZARD_MODULES = {
	actionBars = "actionBar",
	unitFrames = "unitFrames",
	castBar = "unitFrames",
	buffs = "unitFrames",
	weaponEnchants = "temporaryEnchant",
	runes = "runes",
}

local function migrateHideBlizzard(profile)
	for key, module in pairs(HIDE_BLIZZARD_MODULES) do
		local source = profile[module]
		if source and source.enabled == false then
			local target = profile.hideBlizzard or {}
			target[key] = false
			profile.hideBlizzard = target
		end
	end
end

local ARENA_NUMBER_FONT_GROWTH = 3

local function migrateNamePlateFonts(profile)
	local namePlates = profile.namePlates
	if not namePlates then
		return
	end
	local name, aura = namePlates.nameFont, namePlates.auraFont
	if name and namePlates.castbarFont == nil then
		namePlates.castbarFont = CopyTable(name)
	end
	if name and namePlates.arenaNumberFont == nil then
		namePlates.arenaNumberFont = {
			size = name.size and name.size + ARENA_NUMBER_FONT_GROWTH,
			outline = name.outline,
		}
	end
	if aura and namePlates.totemTimerFont == nil then
		namePlates.totemTimerFont = CopyTable(aura)
	end
end

local RAID_HEALTH_TAGS = { none = "", percent = "[perhp]%", deficit = "[misshp:neg]" }
local PLATE_HEALTH_TAGS = { percent = "[perhp:floor]%", value = "[curhp]", both = "[curhp] | [perhp:floor]%" }
local PLAYER_HEALTH_TAGS = { percent = "[perhp:floor]%", value = "[curhp]" }
local HEALTH_TEXT_TAGS = {
	{ "raidFrames", "healthText", RAID_HEALTH_TAGS },
	{ "namePlates", "healthTextFormat", PLATE_HEALTH_TAGS },
	{ "playerPlate", "healthText", PLAYER_HEALTH_TAGS },
}

local function migrateHealthTags(profile)
	if type(profile) ~= "table" then
		return
	end
	for _, entry in ipairs(HEALTH_TEXT_TAGS) do
		local section = profile[entry[1]]
		if type(section) == "table" then
			local old = section[entry[2]]
			section[entry[2]] = nil
			local tag = entry[3][old]
			if tag and section.healthTag == nil and tag ~= ns.Defaults[entry[1]].healthTag then
				section.healthTag = tag
			end
		end
	end
end

local function migrate(profile)
	migrateAuraTracker(profile)
	migrateActionBarGap(profile)
	migrateTotemBar(profile)
	migrateGroupSpacing(profile)
	migrateCastbarHeight(profile)
	migrateClassColorHealth(profile)
	migrateNamePlateCategories(profile)
	migrateUnitFrameCategories(profile)
	migrateGroupCooldownLayout(profile)
	migrateLoseControl(profile)
	migrateUnitFrameTexts(profile)
	migrateMergedToggles(profile)
end

local function seedUnitFrameCategories(profile)
	migrateUnitFrameCategories(profile, true)
end

local ONE_TIME_MIGRATIONS = {
	{ "castbarLayoutMigrated", migrateCastbarLayout },
	{ "squareFramesMigrated", migrateSquareFrames },
	{ "unitFrameCategoriesMigrated", seedUnitFrameCategories },
	{ "playerDebuffsMigrated", migratePlayerDebuffs },
	{ "diminishArenaSizeMigrated", migrateDiminishArenaSize },
	{ "interruptGrowthMigrated", migrateGroupCooldownInterruptGrowth },
	{ "hideBlizzardMigrated", migrateHideBlizzard },
	{ "namePlateFontsMigrated", migrateNamePlateFonts },
}

local function migrateLegacy(profile, flags)
	if flags then
		for _, migration in ipairs(ONE_TIME_MIGRATIONS) do
			if not flags[migration[1]] then
				migration[2](profile)
			end
		end
	end
	migrate(profile)
end

Store.Migrate = migrate
Store.MigrateLegacy = migrateLegacy
Store.MigrateHealthTags = migrateHealthTags
Store.ONE_TIME_MIGRATIONS = ONE_TIME_MIGRATIONS
