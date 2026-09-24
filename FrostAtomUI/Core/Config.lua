local _, ns = ...
local L = ns.L

local InCombatLockdown, SetCVar, geterrorhandler = InCombatLockdown, SetCVar, geterrorhandler
local sort, concat, strchar = table.sort, table.concat, string.char

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

local function actionBarDefaults(enabled, point, buttons, columns, buttonSize)
	return {
		enabled = enabled,
		point = point,
		buttons = buttons,
		columns = columns,
		buttonSize = buttonSize,
		spacing = 2,
		mouseover = false,
		combat = "any",
		fadeAlpha = 0.1,
	}
end

ns.Defaults = {
	general = {
		font = "Fonts\\ARIALN.ttf",
		fontBold = "Fonts\\FRIZQT__.ttf",
		statusbar = "Interface\\Buttons\\WHITE8x8",
		useUiScale = false,
		uiScale = 0.7,
		showGrid = true,
		gridSize = 32,
	},

	cooldownTimer = {
		minDuration = 1.5,
		decimalThreshold = 3,
		expiringColor = { 1, 0, 0 },
		secondsColor = { 1, 1, 0 },
		minutesColor = { 1, 1, 1 },
	},

	actionBar = {
		enabled = true,
		bar1 = actionBarDefaults(nil, { "BOTTOM", 0, 2 }, 12, 12, 36),
		bar2 = actionBarDefaults(true, { "BOTTOM", 0, 40 }, 12, 12, 36),
		bar3 = actionBarDefaults(true, { "BOTTOM", 0, 78 }, 12, 12, 36),
		bar4 = actionBarDefaults(true, { "BOTTOM", -316, 2 }, 12, 4, 36),
		bar5 = actionBarDefaults(true, { "BOTTOM", 316, 2 }, 12, 4, 36),
		bar6 = actionBarDefaults(false, { "RIGHT", -2, 0 }, 12, 1, 36),
		stance = actionBarDefaults(nil, { "BOTTOM", -150, 116 }, nil, 10, 30),
		pet = actionBarDefaults(nil, { "BOTTOM", 68, 116 }, nil, 10, 30),
		vehicleExit = { point = { "BOTTOM", 250, 116 }, buttonSize = 36 },
		totemBar = { "BOTTOM", -150, 154 },
		microMenu = { "BOTTOMRIGHT", -2, 2 },
		microMenuScale = 1,
		microMenuMouseover = false,
		microMenuCombat = "any",
		bagButton = { "BOTTOMRIGHT", -256, 5 },
		bagButtonMouseover = false,
		bagButtonCombat = "any",
		menuFadeAlpha = 0.1,
		showHotkeys = true,
		showShapeshiftHotkeys = false,
		showNames = true,
		showCounts = true,
		countFont = { size = 11, outline = "OUTLINE" },
		cooldownFont = { size = 12, outline = "OUTLINE" },
		clickAnimation = true,
		dragButton = "RightButton",
		dragModifier = "alt",
		hotkeyFont = { size = 9, outline = "OUTLINE" },
		nameFont = { size = 9, outline = "OUTLINE" },
		rangeColor = { 1, 0, 0 },
		manaColor = { 0.5, 0.5, 1 },
		unusableColor = { 0.4, 0.4, 0.4 },
		rangeIconTint = true,
		rangeHotkey = true,
		lossOfControl = true,
		interruptLockout = true,
		lossOfControlColor = { 0.5, 0, 0, 0.6 },
		desaturateOnCooldown = false,
	},

	unitFrames = {
		enabled = true,
		player = { "TOPLEFT", 320, -80 },
		target = { "TOPLEFT", 522, -80 },
		focus = { "TOPLEFT", 769, -80 },
		pet = { "RIGHT", -2, 0, "unitFrames.player", "LEFT" },
		targetOfTarget = { "LEFT", 0, 0, "unitFrames.target", "RIGHT" },
		focusTarget = { "LEFT", 0, 0, "unitFrames.focus", "RIGHT" },
		playerCastbar = { "TOP", 0, -4, "playerPlate.point", "BOTTOM" },
		playerAuras = { "TOPRIGHT", -168, -10 },
		party = { "LEFT", 150, 230 },
		arena = { "RIGHT", -150, 230 },
		partySpacing = 160,
		arenaSpacing = 160,
		partyGrowth = "DOWN",
		arenaGrowth = "DOWN",
		boss = { "RIGHT", -150, 300 },
		bossSpacing = 60,
		outOfRangeAlpha = 0.75,
		cooldownReadyFlash = true,
		showParty = true,
		showArena = true,
		showBoss = true,
		playerWidth = 200,
		playerHeight = 45,
		partyWidth = 200,
		partyHeight = 45,
		arenaWidth = 200,
		arenaHeight = 45,
		bossWidth = 180,
		bossHeight = 40,
		playerCastbarWidth = 240,
		playerCastbarHeight = 28,
		castbarHeight = 25,
		playerAuraSize = 34,
		playerAuraPerRow = 8,
		playerAuraGrowth = "LEFT",
		playerDebuffSize = 34,
		playerDebuffPerRow = 8,
		playerBuffSort = "default",
		auraTimers = true,
		auraTimerMaxDuration = 600,
		targetAuraPerRow = 8,
		ownAuraScale = 1,
		showPlayerCastbar = true,
		showTargetCastbar = true,
		showFocusCastbar = true,
		showPartyCastbar = true,
		showArenaCastbar = true,
		healthColorMode = "class",
		textColor = { 1, 1, 1 },
		backdropColor = { 0, 0, 0, 0.6 },
		borderColor = { 1, 1, 1 },
		targetBorderColor = { 1, 0.8, 0 },
		focusBorderColor = { 0.3, 0.65, 1 },
		castbarColor = { 1, 0.6, 0.05 },
		castbarChannelColor = { 0.3, 0.8, 0.35 },
		castbarLockedColor = { 0.5, 0.5, 0.5 },
		castbarTargetName = true,
		castbarTargetingYou = true,
		castbarTargetingYouColor = { 1, 0.2, 0.1 },
		castbarImportant = true,
		castbarImportantColor = { 1, 0.85, 0.3 },
		castbarInterrupter = true,
		castbarFinishFlash = true,
		textFont = { size = 10, outline = "OUTLINE" },
		castbarFont = { size = 12, outline = "OUTLINE" },
		leftText = "[name]",
		leftTextHover = "",
		rightText = "[curhp]",
		rightTextHover = "[curhp] / [maxhp]",
		powerText = "",
		powerTextHover = "[curpp] / [maxpp]",
		showClassIcon = true,
		showLeaderIcon = true,
		showCombatIcon = true,
		showRestingIcon = true,
		showPvpIcon = true,
		showRaidIcon = true,
		showPet = true,
		showTargetOfTarget = true,
		showFocusTarget = true,
		showLoseControl = true,
		rightClick = "menu",
		hoverHighlight = true,
		hoverAlpha = 0.08,
		healthCutaway = true,
		healthCutawayColor = { 1, 0.9, 0.8, 0.6 },
		healPrediction = true,
		healPredictionColor = { 0, 0.85, 0.55, 0.5 },
		absorbs = true,
		absorbColor = { 0.7, 0.9, 1, 0.45 },
		powerRatio = 0.2,
		gridGap = 6,
		groupDebuffSize = 32,
		groupDebuffMax = 12,
		partyBuffSize = 19,
		partyBuffMax = 18,
		raidIconSize = 16,
		comboPointSize = 8,
		comboPointColor = { 1, 0.2, 0.2 },
		comboPointPartialColor = { 1, 0.8, 0.2 },
		castbarTicks = true,
		castbarLatency = true,
		castbarLatencyColor = { 1, 0.1, 0.1, 0.5 },
		castbarTimeFormat = "remaining",
		healPredictionSplit = true,
		healPredictionOwnColor = { 0.45, 1, 0.3, 0.55 },
		druidMana = true,
		pvpTimer = true,
		combatGlow = false,
		combatGlowColor = { 1, 0.15, 0.1 },
		petPower = true,
		petHappiness = true,
		hideTargetOfTargetSelf = false,
	},

	chat = {
		enabled = true,
		skin = true,
		timestamps = true,
		urlLinks = true,
		stripRealm = true,
		shortChannelNames = true,
		classColorNames = true,
		filterSystemSpam = true,
		filterArenaSpam = true,
		filterAutoReplies = true,
		batchBattlegroundJoins = true,
		editBoxPosition = "below",
		scrollToBottomButton = true,
		whisperSoundThrottle = true,
		whisperSoundInterval = 60,
		lockFrames = true,
		stickyChannels = true,
		timestampFormat = "%H:%M",
		timestampColor = { 0.5, 0.5, 0.5 },
		maxLines = 1000,
		savedHistoryLines = 100,
		savedCommands = 50,
		point = { "BOTTOMLEFT", 12, 36 },
		width = 400,
		height = 153,
		mouseover = false,
		fadeAlpha = 0.1,
		fadeMessages = true,
		fadeTime = 30,
		backgroundAlpha = 0.6,
		copyWindowWidth = 520,
		copyWindowHeight = 380,
		bubbleFont = { size = 12, outline = "" },
		bubbleAlpha = 0.75,
		bubbleMaxWidth = 300,
		bubblePadding = 6,
		bubbleBorderAlpha = 0.9,
		whisperBlock = {
			enabled = false,
			reply = "",
			friendsBypass = true,
		},
	},

	namePlates = {
		enabled = true,
		barWidth = 110,
		barHeight = 12,
		castbarHeight = 12,
		castbarIconSize = 18,
		totemIcons = true,
		totemIconSize = 24,
		raidIconSize = 22,
		showTargetPercent = true,
		showName = true,
		showRaidIcon = true,
		healthColorMode = "class",
		targetBorder = true,
		castbarGap = 3,
		nameFont = { size = 9, outline = "OUTLINE" },
		percentFont = { size = 9, outline = "OUTLINE" },
		castbarColor = { 0.75, 0.4, 0 },
		castbarLockedColor = { 0.4, 0.4, 0.4 },
		castbarTargetName = true,
		castbarTargetingYou = true,
		castbarImportant = true,
		castbarInterrupter = true,
		castbarFinishFlash = true,
		castbarShield = true,
		showAuras = true,
		showAuraTimer = true,
		showAuraCount = true,
		ownDebuffs = true,
		auraSize = 30,
		auraGap = 2,
		auraRowGap = 3,
		maxAuraIcons = 6,
		auraFont = { size = 15, outline = "OUTLINE" },
		aurasAllPlates = true,
		enemyBuffs = true,
		otherDebuffs = false,
		ccAuraSize = 36,
		castbarsAllPlates = true,
		castbarsCombatLog = true,
		friendlyClassColors = true,
		healthTextAll = false,
		healthTextFormat = "percent",
		arenaNumbers = true,
		spreadPlates = false,
		hoverHighlight = true,
		showHealers = true,
		healerIconSize = 16,
		healerThreshold = 2,
		healerClasses = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true },
	},

	playerPlate = {
		enabled = true,
		point = { "CENTER", 0, -120 },
		width = 150,
		healthHeight = 14,
		powerHeight = 6,
		gap = 0,
		showPower = true,
		showText = true,
		healthText = "percent",
		font = { size = 10, outline = "OUTLINE" },
		healthColorMode = "class",
		healthColor = { 0, 0.8, 0 },
		alwaysShow = false,
		fadeTime = 0.5,
		healPrediction = true,
		absorbs = true,
		druidMana = true,
	},
	shieldIndicator = {
		enabled = true,
		point = { "CENTER", -98, -120 },
		size = 34,
	},

	runes = {
		enabled = true,
		point = { "CENTER", 0, -294 },
		width = 48,
		height = 16,
		gap = 2,
		bloodColor = { 1, 0, 0 },
		unholyColor = { 0, 0.5, 0 },
		frostColor = { 0, 1, 1 },
		deathColor = { 0.8, 0.1, 1 },
		emptyColor = { 0.2, 0.2, 0.2 },
	},

	totems = {
		enabled = true,
		point = { "CENTER", 0, -294 },
		size = 30,
		gap = 2,
		timerFont = { size = 11, outline = "OUTLINE" },
	},

	trackers = {
		enabled = true,
		groups = {
			trackerGroup("Warrior procs", "WARRIOR", { "CENTER", 0, -72 }, 36, 0, {
				auraIcon("52437"), -- Sudden Death
				auraIcon("60503"), -- Taste for Blood
			}),
			trackerGroup("Infusion of Light", "PALADIN", { "CENTER", 0, -72 }, 36, 2, {
				auraIcon("54149"), -- Infusion of Light
			}),
			trackerGroup("Judgements of the Pure", "PALADIN", { "CENTER", 72, 36 }, 36, 2, {
				auraIcon("54153"), -- Judgements of the Pure
			}),
			trackerGroup("Beacon / Sacred Shield", "PALADIN", { "CENTER", -90, 36 }, 36, 0, {
				auraIcon("53563", true), -- Beacon of Light
				auraIcon("53601", true), -- Sacred Shield
			}),
			trackerGroup("Sacred Shield proc", "PALADIN", { "CENTER", 0, -36 }, 40, 2, {
				auraIcon("58597"), -- Sacred Shield
			}),
			trackerGroup("Inner Fire", "PRIEST", { "CENTER", 72, 36 }, 36, 2, {
				auraIcon("48168"), -- Inner Fire
			}),
			trackerGroup("Haste proc", "DEATHKNIGHT", { "CENTER", 0, -72 }, 36, 2, {
				auraIcon("55379"), -- Skyflare Swiftness
			}),
			trackerGroup("Diseases", "DEATHKNIGHT", { "CENTER", 0, -42 }, 30, 2, {
				auraIcon("55078", true, "target"), -- Blood Plague
				auraIcon("55095", true, "target"), -- Frost Fever
				auraIcon("51735", true, "target"), -- Ebon Plague
				auraIcon("50536", true, "target"), -- Unholy Blight
			}),
			trackerGroup("Water Shield", "SHAMAN", { "CENTER", 72, 36 }, 36, 2, {
				auraIcon("57960"), -- Water Shield
			}),
			trackerGroup("Resto proc", "SHAMAN", { "CENTER", 0, -72 }, 36, 2, {
				auraIcon("70806"), -- Rapid Currents
			}),
			trackerGroup("Grounding Totem", "SHAMAN", { "CENTER", -108, 36 }, 36, 2, {
				auraIcon("8178", true), -- Grounding Totem Effect
			}),
		},
	},

	lossOfControl = {
		enabled = true,
		point = { "CENTER", 0, 0 },
		scale = 1,
		background = true,
		lockouts = true,
		categories = { silence = true, disarm = true, root = true },
		sound = false,
	},

	externalDefensives = {
		enabled = true,
		point = { "CENTER", 0, -200 },
		size = 36,
		gap = 3,
		maxIcons = 6,
	},

	temporaryEnchant = {
		enabled = true,
		point = { "TOPRIGHT", -155, -163 },
		size = 30,
		gap = 2,
		showTimer = true,
		timerFont = { size = 11, outline = "OUTLINE" },
	},

	lowHealthFlash = {
		enabled = true,
		threshold = 0.33,
		pulseSpeed = 1.2,
	},

	queuePopFlash = {
		enabled = true,
		color = { 0.1, 1, 0.2 },
		intensity = 0.7,
		pulseSpeed = 1.5,
	},

	soundAlerts = {
		enabled = true,
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
	},

	cursorTrail = {
		enabled = true,
		hideInCombat = false,
		scale = 1,
		trailAlpha = 0.6,
		shineAlpha = 0.5,
	},

	announce = {
		enabled = true,
		interrupts = true,
		interruptMessage = "Interrupted %s's %s",
		auraMastery = true,
		auraMasteryMessage = "<<< AURA MASTERY >>>",
		arenaResult = true,
		arenaResultToParty = true,
	},

	dispelHighlightAlpha = 0.5,

	equipment = {
		enabled = true,
		showItemLevels = true,
		durabilityWarning = true,
		durabilityThreshold = 0.2,
		slotFont = { size = 11, outline = "OUTLINE" },
		averageFont = { size = 14, outline = "OUTLINE" },
		qualityThresholds = { uncommon = 200, rare = 220, epic = 245, legendary = 264 },
	},

	merchant = {
		enabled = true,
		sellGreys = true,
		autoRepair = true,
		guildRepair = false,
		shiftToSkip = true,
		showItemLevel = true,
	},

	wheelPaging = {
		enabled = true,
	},

	modelControls = {
		enabled = true,
		rotateSpeed = 0.01,
		zoomStep = 0.15,
	},

	macros = {
		enabled = true,
	},

	spellBook = {
		enabled = true,
		hidePassive = false,
	},

	talentFrame = {
		enabled = true,
	},

	combatLogFix = {
		enabled = true,
	},

	tweaks = {
		enabled = true,
		hideErrors = true,
		dedupErrors = true,
		filterCooldownErrors = true,
		scriptErrors = true,
		hideGroundClutter = true,
		cameraDistanceMax = 50,
		cameraDistanceClose = 10,
		cameraDistanceMedium = 25,
		cameraDistanceFar = 50,
		cameraYawSpeed = 180,
		cameraPitchSpeed = 90,
		cameraZoomSpeed = 8.33,
		cameraFollowStyle = "",
		cameraFollowTime = 2,
		keepCameraPitch = false,
		instantCameraHeight = false,
		keepShapeshift = false,
		keepMount = false,
		keepSitting = false,
		hideSelectionCircle = false,
		hideUnitHighlight = false,
		allSpellMechanics = false,
		hideScreenEffects = false,
		hideInvisibilityEffect = false,
		fullViewDistance = false,
		characterAmbient = 0,
		hideSunGlare = false,
		mouseSpeedMode = "",
		mouseSpeed = 1,
		maxFPS = 200,
		maxFPSBackground = 30,
		assetLoadTime = 100,
		timingMethod = "",
		muteArmorFoley = false,
		soundAtHead = false,
		worldStatePoint = { "BOTTOMLEFT", 52, 289 },
	},

	popups = {
		enabled = true,
		declineDuels = false,
		declineInvites = false,
		declineTrades = false,
		autoRelease = true,
		declineTradeInCombat = true,
		fillDeleteConfirm = true,
		autoAcceptInvites = true,
	},

	experienceBar = {
		enabled = true,
		width = 456,
		height = 5,
		point = { "TOP", 0, 0 },
		showReputation = true,
		xpColor = { 0.58, 0, 0.55 },
		restedColor = { 0, 0.39, 0.88, 0.6 },
		backgroundAlpha = 0.6,
	},

	arenaTrinket = { enabled = true, party = true, size = 30 },

	groupCooldowns = {
		enabled = true,
		friendly = true,
		enemy = true,
		friendlyPoint = { "TOPLEFT", 420, -380, "unitFrames.party", "BOTTOMLEFT" },
		enemyPoint = { "TOPRIGHT", -420, -380, "unitFrames.arena", "BOTTOMRIGHT" },
		friendlyGrowth = "RIGHT",
		enemyGrowth = "LEFT",
		size = 24,
		spacing = 2,
		perRow = 6,
		rowSpacing = 3,
		labels = true,
		desaturate = true,
		readyFlash = true,
		glowColor = { 1, 0.85, 0.3 },
		friendlyCategories = {
			defensive = true,
			offensive = true,
			interrupt = true,
			cc = true,
			mobility = true,
			utility = true,
		},
		enemyCategories = {
			defensive = true,
			offensive = true,
			interrupt = true,
			cc = true,
			mobility = true,
			utility = true,
		},
		spells = {},
	},

	diminishingReturns = {
		enabled = true,
		arena = true,
		target = false,
		focus = false,
		size = 24,
		spacing = 2,
		arenaSide = "LEFT",
		arenaOffsetX = -4,
		arenaOffsetY = 0,
		targetSide = "TOP",
		targetOffsetX = 0,
		targetOffsetY = 4,
		halfColor = { 0.2, 1, 0.2 },
		quarterColor = { 1, 0.65, 0 },
		immuneColor = { 1, 0.1, 0.1 },
	},

	internalCooldowns = {
		enabled = true,
		player = true,
		party = true,
		arena = true,
		target = true,
		focus = true,
		size = 18,
		spacing = 1,
		hideReady = false,
		unknownTrinkets = true,
		activeColor = { 0.2, 1, 0.2 },
		offsetX = 0,
		offsetY = 2,
	},

	arenaUnseen = { enabled = true, alpha = 0.55, prep = true },

	arena = {
		enabled = true,
		countdown = true,
		countdownPoint = { "CENTER", 0, 180 },
		countdownFont = { size = 24, outline = "OUTLINE" },
		countdownColor = { 1, 1, 1 },
		countdownUrgentColor = { 1, 0, 0 },
		pillars = true,
		pillarsSize = 36,
		pillarsFirstToggle = 45,
		pillarsPeriod = 25,
	},

	battleground = {
		enabled = true,
		raidWarnings = true,
		closeWarnings = true,
	},

	matchResults = {
		enabled = true,
		replaceScoreboard = true,
		battlegrounds = true,
		point = { "TOP", 0, -120 },
	},

	queueInvite = {
		enabled = true,
		countdown = true,
		font = { size = 20, outline = "OUTLINE" },
		sound = true,
	},

	soloQueue = {
		enabled = true,
		point = { "RIGHT", -4, 0, "minimap.lfgPoint", "LEFT" },
		buttonSize = 32,
		queuedSize = 44,
		glowColor = { 0.3, 1, 0.3 },
		rangeFont = { size = 12, outline = "OUTLINE" },
		teamSearchColor = { 1, 1, 1 },
		opponentSearchColor = { 1, 0.85, 0.3 },
	},

	worldMap = {
		enabled = true,
		screenFraction = 0.8,
		showCoords = true,
		coordFont = { size = 12, outline = "OUTLINE" },
		arrowSize = 36,
		zoomStep = 0.2,
		maxZoom = 4,
		fadeWhenMoving = false,
		movingAlpha = 0.5,
	},

	blizzardFrames = {
		enabled = true,
		captureBarPoint = { "TOPRIGHT", 0, -44, "minimap.point", "BOTTOMRIGHT" },
		vehicleSeatPoint = { "TOPRIGHT", 0, -100, "minimap.point", "BOTTOMRIGHT" },
		errorsPoint = { "TOP", 0, -122 },
		raidWarningPoint = { "TOP", 0, 0, "blizzardFrames.errorsPoint", "BOTTOM" },
		questTracker = {
			arena = true,
			battleground = false,
			combat = false,
		},
	},

	arenaHistory = {
		enabled = true,
		maxGames = 1000,
		winColor = { 0.1, 1, 0.1 },
		lossColor = { 1, 0.1, 0.1 },
	},

	deathRecap = {
		enabled = true,
		point = { "CENTER", 420, 60 },
		entries = 5,
		chatLink = true,
		arenaDeaths = true,
		autoOpen = true,
	},

	combatAlert = {
		enabled = true,
		point = { "CENTER", 0, 150 },
		font = { size = 22, outline = "OUTLINE" },
		duration = 1,
		fadeTime = 0.5,
		enterText = "+ combat",
		leaveText = "- combat",
		enterColor = { 1, 0.3, 0.3 },
		leaveColor = { 0.3, 1, 0.3 },
	},

	performance = {
		enabled = true,
		point = { "TOPLEFT", 12, -10 },
		showFps = true,
		showLatency = true,
		valueFont = { size = 16, outline = "OUTLINE" },
		unitFont = { size = 11, outline = "OUTLINE" },
		fpsRed = 50,
		fpsOrange = 60,
		fpsYellow = 90,
		latencyYellow = 50,
		latencyOrange = 100,
		latencyRed = 200,
	},

	tooltip = {
		enabled = true,
		point = { "BOTTOMRIGHT", -13, 64 },
		scale = 1,
		hideInCombat = true,
		hideInCombatWorld = false,
		showIds = true,
		showAuraCaster = true,
		showItemLevel = true,
		showItemCount = true,
		showTargetedBy = true,
		showTarget = true,
		showSpec = true,
		showArenaTeams = true,
		showTitle = false,
		showStatus = true,
		showGuildRank = true,
		showRaidIcon = true,
		showClassIcon = false,
		hidePvPLines = true,
		labelColor = { 0.2, 0.4, 1 },
		anchorCursor = false,
		cursorOffsetX = 0,
		cursorOffsetY = 0,
		frameAnchor = "default",
		showHealthText = true,
		classColorHealth = true,
		colorBorder = true,
		auras = "all",
		auraSize = 20,
		auraRows = 1,
		skin = true,
		backdropColor = { 0.06, 0.06, 0.06, 0.9 },
		borderColor = { 0.35, 0.35, 0.35 },
		reactionBackground = true,
		gradient = true,
		fontSize = 12,
		healthBar = "inside",
		sideIcon = false,
	},

	minimap = {
		enabled = true,
		point = { "TOPRIGHT", -15, -15 },
		size = 140,
		mouseover = false,
		combat = "any",
		fadeAlpha = 0.1,
		lfgPoint = { "TOPRIGHT", -4, -6, "minimap.point", "BOTTOMRIGHT" },
		lfgSize = 32,
		showClock = true,
		clock24h = true,
		clockPoint = { "BOTTOM", 0, 4 },
		clockFont = { size = 12, outline = "OUTLINE" },
		showZoneText = false,
		zoneFont = { size = 11, outline = "OUTLINE" },
		showTracking = false,
		collectButtons = true,
		iconSize = 18,
		borderColor = { 1, 1, 1 },
	},

	bags = {
		enabled = true,
		buttonSize = 34,
		spacing = 4,
		padding = 8,
		inventoryColumns = 10,
		bankColumns = 16,
		inventory = { "BOTTOMRIGHT", -6, 42 },
		bank = { "LEFT", 60, 0 },
		backgroundAlpha = 0.6,
		showItemLevel = true,
		highlightNewItems = true,
		questItemColor = { 1, 0.8, 0 },
		autoOpen = true,
		playSounds = true,
		searchFadeAlpha = 0.25,
		tintUnusable = true,
		showBagFreeSlots = true,
		offlineBank = true,
		altGold = true,
		lockModifier = "ALT",
		sortReverse = false,
		sortMessages = false,
		countFont = { size = 12, outline = "OUTLINE" },
		levelFont = { size = 10, outline = "OUTLINE" },
	},
}

local function copy(source)
	local target = {}
	for key, value in pairs(source) do
		target[key] = type(value) == "table" and copy(value) or value
	end
	return target
end

local function merge(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			if value[1] ~= nil or target[key][1] ~= nil then
				wipe(target[key])
			end
			merge(target[key], value)
		else
			target[key] = type(value) == "table" and copy(value) or value
		end
	end
end

ns.Config = copy(ns.Defaults)
ns.CONFIG_CHANGED = "FrostAtomUI_CONFIG_CHANGED"
ns.PROFILES_CHANGED = "FrostAtomUI_PROFILES_CHANGED"

local DEFAULT_PROFILE = "Default"
local EXPORT_PREFIX = "FAUI1:"

local Config = ns:NewModule("Config")
local saved = {}
local activeProfile = DEFAULT_PROFILE

local function walk(root, path, create)
	local node = root
	local last
	for key in path:gmatch("[^.]+") do
		key = tonumber(key) or key
		if last then
			local child = node[last]
			if child == nil then
				if not create then
					return nil
				end
				child = {}
				node[last] = child
			end
			node = child
		end
		last = key
	end
	return node, last
end

function ns:GetConfig(path)
	local node, key = walk(ns.Config, path)
	return node and node[key]
end

local function assign(node, key, value)
	if type(value) == "table" and type(node[key]) == "table" then
		wipe(node[key])
		merge(node[key], value)
	elseif type(value) == "table" then
		node[key] = copy(value)
	else
		node[key] = value
	end
end

local function listPathOf(path)
	return path:match("^(.-)%.%d+%.") or path:match("^(.-)%.%d+$")
end

local function saveWholeList(listPath)
	local listNode, listKey = walk(ns.Config, listPath)
	local store, storeKey = walk(saved, listPath, true)
	assign(store, storeKey, listNode[listKey])
end

function ns:SetConfig(path, value)
	local node, key = walk(ns.Config, path, true)
	assign(node, key, value)

	local listPath = listPathOf(path)
	if listPath then
		saveWholeList(listPath)
	else
		local store, storeKey = walk(saved, path, true)
		assign(store, storeKey, value)
	end
	ns:Fire(ns.CONFIG_CHANGED, path)
end

local function reset(target, defaults)
	for key in pairs(target) do
		if defaults[key] == nil then
			target[key] = nil
		end
	end
	for key, value in pairs(defaults) do
		if type(value) == "table" and type(target[key]) == "table" then
			reset(target[key], value)
		else
			target[key] = type(value) == "table" and copy(value) or value
		end
	end
end

function ns:ResetConfig(path)
	if not path then
		wipe(saved)
		reset(ns.Config, ns.Defaults)
		ns:Fire(ns.CONFIG_CHANGED)
		return
	end
	local node, key = walk(ns.Config, path, true)
	local defaults, defaultKey = walk(ns.Defaults, path)
	assign(node, key, defaults and defaults[defaultKey])

	local listPath = listPathOf(path)
	if listPath then
		saveWholeList(listPath)
	else
		local store, storeKey = walk(saved, path)
		if store then
			store[storeKey] = nil
		end
	end
	ns:Fire(ns.CONFIG_CHANGED, path)
end

function ns:IsDefaultConfig(path)
	local store, key = walk(saved, path)
	if not store or store[key] == nil then
		return true
	end
	return type(store[key]) == "table" and next(store[key]) == nil
end

local function applyGeneral()
	local general = ns.Config.general
	ns.ApplyMedia(general)
	if general.useUiScale then
		SetCVar("useUiScale", 1)
		SetCVar("uiScale", general.uiScale)
	end
end

local function isSection(value, default)
	return type(value) == "table"
		and type(default) == "table"
		and default[1] == nil
		and value[1] == nil
		and next(default) ~= nil
end

local function prune(target, defaults)
	for key, value in pairs(target) do
		local default = defaults[key]
		if default == nil then
			target[key] = nil
		elseif isSection(value, default) then
			prune(value, default)
		end
	end
end

local function mergeKnown(target, source, defaults)
	for key, value in pairs(source) do
		local default = defaults[key]
		if default ~= nil then
			local current = target[key]
			if isSection(value, default) and type(current) == "table" then
				mergeKnown(current, value, default)
			elseif type(value) == "table" and type(current) == "table" then
				if value[1] ~= nil or current[1] ~= nil then
					wipe(current)
				end
				merge(current, value)
			else
				target[key] = type(value) == "table" and copy(value) or value
			end
		end
	end
end

local function pruned(profile)
	local result = copy(profile)
	prune(result, ns.Defaults)
	return result
end

local function charKey()
	return UnitName("player") .. " - " .. GetRealmName()
end

local function rebuildFromSaved()
	reset(ns.Config, ns.Defaults)
	mergeKnown(ns.Config, saved, ns.Defaults)
end

local function replaceSaved(profile)
	wipe(saved)
	merge(saved, profile)
	rebuildFromSaved()
end

local function activate(name)
	local profiles = ns.db.profiles
	profiles[name] = profiles[name] or {}
	saved = profiles[name]
	activeProfile = name
	ns.db.charProfile[charKey()] = name
	rebuildFromSaved()
end

function ns:GetActiveProfile()
	return activeProfile
end

function ns:GetProfileNames()
	local names = {}
	for name in pairs(ns.db.profiles) do
		names[#names + 1] = name
	end
	sort(names)
	return names
end

function ns:SetProfile(name)
	name = name and name:trim()
	if not name or name == "" or name == activeProfile then
		return
	end
	activate(name)
	ns:Fire(ns.PROFILES_CHANGED)
	ns:Fire(ns.CONFIG_CHANGED)
end

function ns:CopyProfile(source)
	local profile = ns.db.profiles[source]
	if not profile or source == activeProfile then
		return
	end
	replaceSaved(profile)
	ns:Fire(ns.CONFIG_CHANGED)
end

function ns:DeleteProfile(name)
	if name == activeProfile or not ns.db.profiles[name] then
		return
	end
	ns.db.profiles[name] = nil
	for char, profile in pairs(ns.db.charProfile) do
		if profile == name then
			ns.db.charProfile[char] = nil
		end
	end
	if ns.db.defaultProfile == name then
		ns.db.defaultProfile = nil
	end
	ns:Fire(ns.PROFILES_CHANGED)
end

function ns:GetDefaultProfile()
	local name = ns.db.defaultProfile
	return name and ns.db.profiles[name] and name or DEFAULT_PROFILE
end

function ns:SetDefaultProfile(name)
	ns.db.defaultProfile = name ~= DEFAULT_PROFILE and ns.db.profiles[name] and name or nil
	ns:Fire(ns.PROFILES_CHANGED)
end

local function serialize(value, out)
	local kind = type(value)
	if kind == "table" then
		out[#out + 1] = "{"
		local count = #value
		for i = 1, count do
			serialize(value[i], out)
			out[#out + 1] = ","
		end
		for key, item in pairs(value) do
			if not (type(key) == "number" and key >= 1 and key <= count and key % 1 == 0) then
				out[#out + 1] = "["
				serialize(key, out)
				out[#out + 1] = "]="
				serialize(item, out)
				out[#out + 1] = ","
			end
		end
		out[#out + 1] = "}"
	elseif kind == "string" then
		out[#out + 1] = ("%q"):format(value)
	elseif kind == "number" or kind == "boolean" then
		out[#out + 1] = tostring(value)
	else
		error("cannot serialize " .. kind)
	end
end

local ESCAPES = { n = "\n", r = "\r", t = "\t", ["\n"] = "\n" }

local function unescape(body)
	local out, i = {}, 1
	while i <= #body do
		local char = body:sub(i, i)
		if char == "\\" then
			local digits = body:match("^%d%d?%d?", i + 1)
			if digits then
				out[#out + 1] = strchar(tonumber(digits))
				i = i + 1 + #digits
			else
				local escaped = body:sub(i + 1, i + 1)
				out[#out + 1] = ESCAPES[escaped] or escaped
				i = i + 2
			end
		else
			out[#out + 1] = char
			i = i + 1
		end
	end
	return concat(out)
end

local parseValue

local function parseTable(text, pos)
	local result, index = {}, 1
	pos = pos + 1
	while true do
		local char = text:sub(pos, pos)
		if char == "}" then
			return result, pos + 1
		elseif char == "" then
			return nil
		end
		local key, value
		if char == "[" then
			key, pos = parseValue(text, pos + 1)
			if not key or text:sub(pos, pos) ~= "]" or text:sub(pos + 1, pos + 1) ~= "=" then
				return nil
			end
			pos = pos + 2
		else
			key, index = index, index + 1
		end
		value, pos = parseValue(text, pos)
		if value == nil then
			return nil
		end
		result[key] = value
		if text:sub(pos, pos) == "," then
			pos = pos + 1
		end
	end
end

function parseValue(text, pos)
	local char = text:sub(pos, pos)
	if char == "{" then
		return parseTable(text, pos)
	elseif char == '"' then
		local stop = pos
		repeat
			stop = text:find('"', stop + 1, true)
			if not stop then
				return nil
			end
			local backslashes = #text:sub(pos + 1, stop - 1):match("\\*$")
		until backslashes % 2 == 0
		return unescape(text:sub(pos + 1, stop - 1)), stop + 1
	elseif text:sub(pos, pos + 3) == "true" then
		return true, pos + 4
	elseif text:sub(pos, pos + 4) == "false" then
		return false, pos + 5
	end
	local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
	if number and number ~= "" and tonumber(number) then
		return tonumber(number), pos + #number
	end
	return nil
end

function ns.Serialize(value)
	local out = {}
	serialize(value, out)
	return concat(out)
end

function ns.Deserialize(text)
	local value, pos = parseValue(text, 1)
	if value == nil or pos ~= #text + 1 then
		return nil
	end
	return value
end

local migrate

function ns:ExportProfile()
	return EXPORT_PREFIX .. ns.Encode(ns.Serialize(pruned(saved)))
end

function ns:ImportProfile(text)
	text = text and text:trim()
	if not text or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return false, L["not a FrostAtom UI profile string"]
	end
	local body, err = ns.Decode(text:sub(#EXPORT_PREFIX + 1))
	if not body then
		return false, err
	end
	local data = ns.Deserialize(body)
	if type(data) ~= "table" then
		return false, L["malformed profile string"]
	end
	migrate(data)
	prune(data, ns.Defaults)
	replaceSaved(data)
	ns:Fire(ns.CONFIG_CHANGED)
	return true
end

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

local function migrateGroupSpacing(profile)
	local unitFrames = profile.unitFrames
	if unitFrames and unitFrames.groupSpacing ~= nil then
		unitFrames.partySpacing = unitFrames.partySpacing or unitFrames.groupSpacing
		unitFrames.arenaSpacing = unitFrames.arenaSpacing or unitFrames.groupSpacing
		unitFrames.groupSpacing = nil
	end
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

function migrate(profile)
	migrateAuraTracker(profile)
	migrateActionBarGap(profile)
	migrateGroupSpacing(profile)
	migrateClassColorHealth(profile)
end

Config:RegisterEvent(ns.DB_LOADED, function(_, db)
	db.profiles = db.profiles or {}
	db.charProfile = db.charProfile or {}
	if db.config then
		db.profiles[DEFAULT_PROFILE] = db.profiles[DEFAULT_PROFILE] or db.config
		db.config = nil
	end
	for _, profile in pairs(db.profiles) do
		migrate(profile)
	end
	activate(db.charProfile[charKey()] or ns:GetDefaultProfile())
	applyGeneral()
	ns:Fire(ns.CONFIG_CHANGED)
end)

local function changeAffects(path, prefix)
	return not path or path == prefix or path:sub(1, #prefix + 1) == prefix .. "."
end

Config:RegisterEvent(ns.CONFIG_CHANGED, function(_, path)
	if changeAffects(path, "general") then
		applyGeneral()
	end
end)

local pending = {}
local combatWatcher = ns.Mixin({}, ns.EventMixin)

combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if not next(pending) then
		return
	end
	local errorHandler = geterrorhandler()
	for handler, owners in pairs(pending) do
		for owner in pairs(owners) do
			local ok, err = pcall(handler, owner)
			if not ok then
				errorHandler(err)
			end
		end
	end
	wipe(pending)
end)

function ns.ModulePrototype:AnchorToConfig(frame, path, label, options)
	local function apply()
		ns.ApplyPoint(frame, path)
	end
	apply()
	self:WatchConfig(path, apply, options and options.secure)
	ns.Movers.Register(frame, path, label, options)
end

local function runWatcher(watcher)
	local path = watcher.path
	watcher.path = nil
	if watcher.secure and InCombatLockdown() then
		local owners = pending[watcher.handler]
		if not owners then
			owners = {}
			pending[watcher.handler] = owners
		end
		owners[watcher.owner] = true
	else
		watcher.handler(watcher.owner, path or nil)
	end
end

function ns.ModulePrototype:WatchConfig(prefix, handler, secure)
	local watcher = { owner = self, handler = handler, secure = secure }
	self:RegisterEvent(ns.CONFIG_CHANGED, function(_, path)
		if not changeAffects(path, prefix) then
			return
		end
		if watcher.path == nil then
			watcher.path = path or false
			ns.Defer(watcher, runWatcher)
		elseif watcher.path ~= path then
			watcher.path = false
		end
	end)
end
