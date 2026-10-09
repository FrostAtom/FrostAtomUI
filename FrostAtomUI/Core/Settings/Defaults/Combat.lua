local _, ns = ...

local function auraIcon(spells, mine, unit)
	return {
		type = "aura",
		spells = spells,
		unit = unit or "player",
		debuff = unit ~= nil and unit ~= "player",
		mine = mine or false,
		show = "present",
		minStacks = 0,
		range = false,
		usable = true,
		duration = 45,
		category = "stun",
	}
end

local function trackerGroup(name, class, point, size, spacing, icons)
	return {
		enabled = true,
		name = name,
		class = class,
		point = point,
		size = size,
		spacing = spacing,
		columns = 8,
		collapse = false,
		combat = "any",
		zone = "any",
		talentGroup = 0,
		inactiveAlpha = 0.35,
		timer = true,
		icons = icons,
	}
end

ns.DefaultsKit.auraIcon = auraIcon
ns.DefaultsKit.trackerGroup = trackerGroup

ns:RegisterDefaults("trackers", {
	enabled = true,
	groups = {
		trackerGroup("Warrior procs", "WARRIOR", { "CENTER", 0, -62 }, 36, 0, {
			auraIcon("52437"), -- Sudden Death
			auraIcon("60503"), -- Taste for Blood
		}),
		trackerGroup("Infusion of Light", "PALADIN", { "CENTER", 0, -62 }, 36, 2, {
			auraIcon("54149"), -- Infusion of Light
		}),
		trackerGroup("Judgements of the Pure", "PALADIN", { "CENTER", 72, 36 }, 36, 2, {
			auraIcon("54153"), -- Judgements of the Pure
		}),
		trackerGroup("Beacon / Sacred Shield", "PALADIN", { "CENTER", -90, 36 }, 36, 0, {
			auraIcon("53563", true), -- Beacon of Light
			auraIcon("53601", true), -- Sacred Shield
		}),
		trackerGroup("Sacred Shield proc", "PALADIN", { "CENTER", 0, -26 }, 40, 2, {
			auraIcon("58597"), -- Sacred Shield
		}),
		trackerGroup("Inner Fire", "PRIEST", { "CENTER", 72, 36 }, 36, 2, {
			auraIcon("48168"), -- Inner Fire
		}),
		trackerGroup("Haste proc", "DEATHKNIGHT", { "CENTER", 0, -62 }, 36, 2, {
			auraIcon("55379"), -- Skyflare Swiftness
		}),
		trackerGroup("Diseases", "DEATHKNIGHT", { "CENTER", 0, -32 }, 30, 2, {
			auraIcon("55078", true, "target"), -- Blood Plague
			auraIcon("55095", true, "target"), -- Frost Fever
			auraIcon("51735", true, "target"), -- Ebon Plague
			auraIcon("50536", true, "target"), -- Unholy Blight
		}),
		trackerGroup("Water Shield", "SHAMAN", { "CENTER", 72, 36 }, 36, 2, {
			auraIcon("57960"), -- Water Shield
		}),
		trackerGroup("Resto proc", "SHAMAN", { "CENTER", 0, -62 }, 36, 2, {
			auraIcon("70806"), -- Rapid Currents
		}),
		trackerGroup("Grounding Totem", "SHAMAN", { "CENTER", -108, 36 }, 36, 2, {
			auraIcon("8178", true), -- Grounding Totem Effect
		}),
	},
})

ns:RegisterDefaults("loseControl", {
	enabled = true,
	frames = { target = true, focus = true, party = true, arena = true },
	lockouts = true,
	spells = {},
})

ns:RegisterDefaults("lossOfControl", {
	enabled = true,
	point = { "CENTER", 0, 90 },
	scale = 1,
	background = true,
	lockouts = true,
	categories = { silence = true, disarm = true, root = true },
	sound = false,
})

ns:RegisterDefaults("externalDefensives", {
	enabled = true,
	point = { "CENTER", 0, -200 },
	size = 36,
	gap = 3,
	maxIcons = 6,
})

ns:RegisterDefaults("temporaryEnchant", {
	enabled = true,
	point = { "TOP", 0, -6, "minimap.point", "BOTTOM" },
	showInAuras = false,
	size = 30,
	gap = 2,
	showTimer = true,
	timerFont = { size = 11, outline = "OUTLINE" },
	clickThrough = false,
})

ns:RegisterDefaults("lowHealthFlash", {
	enabled = true,
	threshold = 0.33,
})

ns:RegisterDefaults("queuePopFlash", {
	enabled = false,
	color = { 0.1, 1, 0.2 },
	intensity = 0.7,
})

ns:RegisterDefaults("soundAlerts", {
	enabled = false,
	throttle = 1.5,
	targeted = false,
	targetedArenaOnly = true,
	targetedText = true,
	targetedSound = "RaidBossEmoteWarning",
	interruptible = false,
	interruptibleFocus = true,
	interruptibleSound = "TellMessage",
	dispellable = true,
	dispellableMinDuration = 3,
	dispellableSound = "MapPing",
	interruptSuccess = false,
	interruptSuccessSound = "LOOTWINDOWCOINSOUND",
})

ns:RegisterDefaults("spellAlerts", {
	enabled = true,
	channel = "Master",
	zones = { arena = true, battleground = false, world = false },
	targetOnly = true,
	controlOnYou = false,
	urgentWhenTargeted = false,
	defensiveEnd = true,
	controlEnd = true,
	interrupted = true,
	spells = {},
})

ns:RegisterDefaults("announce", {
	enabled = true,
	interrupts = false,
	interruptMessage = "Interrupted %s's %s",
	auraMastery = false,
	auraMasteryMessage = "<<< AURA MASTERY >>>",
	arenaResultToParty = false,
})

ns:RegisterDefaults("arenaTrinket", { size = 30 })

ns:RegisterDefaults("groupCooldowns", {
	enabled = true,
	zones = { arena = true, battleground = true, world = false },
	friendly = true,
	enemy = true,
	friendlyPoint = { "BOTTOMLEFT", -370, 190, nil, "BOTTOM" },
	enemyPoint = { "BOTTOMRIGHT", 370, 190, nil, "BOTTOM" },
	friendlyInterruptPoint = { "BOTTOMLEFT", 0, 8, "groupCooldowns.friendlyPoint", "TOPLEFT" },
	enemyInterruptPoint = { "BOTTOMRIGHT", 0, 8, "groupCooldowns.enemyPoint", "TOPRIGHT" },
	friendlyGrowth = "RIGHT",
	enemyGrowth = "LEFT",
	friendlyInterruptGrowth = "RIGHT",
	enemyInterruptGrowth = "LEFT",
	friendlyLayout = "frames",
	enemyLayout = "frames",
	friendlySeparateInterrupts = false,
	enemySeparateInterrupts = false,
	friendlySeparateTrinket = false,
	enemySeparateTrinket = false,
	party1Point = { "TOPLEFT", 4, 0, "unitFrames.party", "BOTTOMRIGHT" },
	party2Point = { "TOPLEFT", 4, 0, "unitFrames.party2", "BOTTOMRIGHT" },
	party3Point = { "TOPLEFT", 4, 0, "unitFrames.party3", "BOTTOMRIGHT" },
	party4Point = { "TOPLEFT", 4, 0, "unitFrames.party4", "BOTTOMRIGHT" },
	arena1Point = { "TOPRIGHT", -4, 0, "unitFrames.arena", "BOTTOMLEFT" },
	arena2Point = { "TOPRIGHT", -4, 0, "unitFrames.arena2", "BOTTOMLEFT" },
	arena3Point = { "TOPRIGHT", -4, 0, "unitFrames.arena3", "BOTTOMLEFT" },
	friendlySize = 24,
	friendlySpacing = 2,
	friendlyPerRow = 6,
	friendlyFramePerRow = 8,
	friendlyRowSpacing = 3,
	enemySize = 24,
	enemySpacing = 2,
	enemyPerRow = 6,
	enemyFramePerRow = 8,
	enemyRowSpacing = 3,
	friendlyInterruptSize = 24,
	friendlyInterruptSpacing = 2,
	friendlyInterruptPerRow = 6,
	friendlyInterruptRowSpacing = 3,
	enemyInterruptSize = 24,
	enemyInterruptSpacing = 2,
	enemyInterruptPerRow = 6,
	enemyInterruptRowSpacing = 3,
	labels = true,
	desaturate = true,
	glowColor = { 1, 0.85, 0.3 },
	clickThrough = true,
	friendlyCategories = {
		trinket = true,
		defensive = true,
		offensive = true,
		interrupt = true,
		cc = true,
		mobility = true,
		utility = true,
	},
	enemyCategories = {
		trinket = true,
		defensive = true,
		offensive = true,
		interrupt = true,
		cc = true,
		mobility = true,
		utility = true,
	},
	spells = {},
})

ns:RegisterDefaults("diminishingReturns", {
	enabled = true,
	arena = true,
	target = false,
	focus = false,
	player = true,
	size = 28,
	arenaSize = 36,
	playerSize = 41,
	spacing = 2,
	playerPoint = { "CENTER", 0, 160 },
	arenaAnchor = "LEFT",
	arenaGrowth = "LEFT",
	party = false,
	partyAnchor = "RIGHT",
	partyGrowth = "RIGHT",
	partyOffsetX = 4,
	partyOffsetY = 0,
	arenaOffsetX = -4,
	arenaOffsetY = 0,
	targetAnchor = "TOPRIGHT",
	targetGrowth = "LEFT",
	targetOffsetX = 0,
	targetOffsetY = 4,
	halfColor = { 0.2, 1, 0.2 },
	quarterColor = { 1, 0.65, 0 },
	immuneColor = { 1, 0.1, 0.1 },
	clickThrough = false,
	severityText = false,
	categories = {
		stuns = true,
		incapacitates = true,
		fears = true,
		silences = true,
		disarms = true,
		roots = true,
	},
})

ns:RegisterDefaults("internalCooldowns", {
	enabled = true,
	player = true,
	party = true,
	arena = true,
	target = true,
	focus = true,
	slots = {
		trinket = true,
		ring = true,
		weapon = true,
		armor = true,
		enchant = true,
		gem = true,
		set = true,
		talent = true,
	},
	size = 18,
	spacing = 1,
	playerDetached = false,
	playerSize = 36,
	playerPoint = { "BOTTOM", 0, 192 },
	hideReady = false,
	unknownTrinkets = true,
	activeColor = { 0.2, 1, 0.2 },
	offsetX = 0,
	offsetY = 2,
	clickThrough = false,
})

ns:RegisterDefaults("arenaUnseen", { enabled = true, alpha = 0.55, prep = true })

ns:RegisterDefaults("arena", {
	enabled = true,
	countdown = true,
	countdownPoint = { "CENTER", 0, 180 },
	countdownFont = { size = 24, outline = "OUTLINE" },
	countdownColor = { 1, 0.82, 0 },
	countdownUrgentColor = { 1, 0, 0 },
	pillars = true,
	pillarsSize = 45,
	pillarsPoint = { "BOTTOMRIGHT", 2, 10, "chat.point", "TOPRIGHT" },
	pillarsFirstToggle = 45.133,
	pillarsPeriod = 25,
})

ns:RegisterDefaults("battleground", {
	enabled = true,
	raidWarnings = true,
	closeWarnings = true,
})

ns:RegisterDefaults("matchResults", {
	enabled = true,
	replaceScoreboard = true,
	battlegrounds = true,
	point = { "TOP", 0, -120 },
})

ns:RegisterDefaults("queueInvite", {
	enabled = true,
	style = true,
	sound = true,
})

ns:RegisterDefaults("soloQueue", {
	enabled = true,
	point = { "TOPLEFT", -1, -5, "minimap.point", "BOTTOMLEFT" },
	buttonSize = 26,
	queuedSize = 34,
	mouseover = true,
})

ns:RegisterDefaults("arenaHistory", {
	enabled = true,
	maxGames = 1000,
})

ns:RegisterDefaults("deathRecap", {
	enabled = true,
	point = { "CENTER", 420, 60 },
	entries = 5,
	chatLink = true,
	arenaDeaths = true,
	autoOpen = true,
	heals = true,
	control = true,
})

ns:RegisterDefaults("combatAlert", {
	enabled = false,
	point = { "CENTER", 0, 200 },
	font = { size = 22, outline = "OUTLINE" },
	enterText = "+ combat",
	leaveText = "- combat",
	enterColor = { 1, 0.3, 0.3 },
	leaveColor = { 0.3, 1, 0.3 },
})
