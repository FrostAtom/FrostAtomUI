local _, ns = ...

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

ns:RegisterDefaults("general", {
	font = "Fonts\\ARIALN.ttf",
	fontBold = "Fonts\\FRIZQT__.ttf",
	statusbar = "Interface\\Buttons\\WHITE8x8",
	uiScaleMode = "game",
	uiScale = 0.7,
	showGrid = true,
	gridSize = 32,
	snapGap = 4,
	snapDistance = 10,
})

ns:RegisterDefaults("cooldownTimer", {
	minDuration = 1.5,
	decimalThreshold = 3,
	expiringColor = { 1, 0, 0 },
	secondsColor = { 1, 1, 0 },
	minutesColor = { 1, 1, 1 },
	readyFlash = true,
})

ns:RegisterDefaults("actionBar", {
	enabled = true,
	bar1 = ns.Mixin(actionBarDefaults(nil, { "BOTTOM", 0, 2 }, 12, 12, 36), { visibility = "", paging = "" }),
	bar2 = ns.Mixin(actionBarDefaults(true, { "BOTTOM", 0, 40 }, 12, 12, 36), { visibility = "" }),
	bar3 = ns.Mixin(actionBarDefaults(true, { "BOTTOM", 0, 78 }, 12, 12, 36), { visibility = "" }),
	bar4 = ns.Mixin(actionBarDefaults(true, { "BOTTOM", -316, 2 }, 12, 4, 36), { visibility = "" }),
	bar5 = ns.Mixin(actionBarDefaults(true, { "BOTTOM", 316, 2 }, 12, 4, 36), { visibility = "" }),
	bar6 = ns.Mixin(actionBarDefaults(false, { "RIGHT", -2, 0 }, 12, 1, 36), { visibility = "" }),
	extraBars = {},
	stance = actionBarDefaults(nil, { "BOTTOMLEFT", 22, 2, "actionBar.bar3.point", "TOPLEFT" }, nil, 10, 30),
	pet = actionBarDefaults(nil, { "BOTTOM", 68, 116 }, nil, 10, 30),
	vehicleExit = { point = { "BOTTOM", 250, 116 }, buttonSize = 36 },
	totemBar = ns.Mixin(actionBarDefaults(true, { "BOTTOM", -150, 154 }, nil, 6, 30), {
		flyoutButtonSize = 24,
		flyoutSpacing = 2,
		flyoutRows = 10,
	}),
	microMenu = { "BOTTOMRIGHT", -2, 2 },
	microMenuScale = 1,
	microMenuMouseover = false,
	microMenuCombat = "any",
	bagButton = { "BOTTOMRIGHT", -256, 5 },
	bagButtonMouseover = false,
	bagButtonCombat = "any",
	menuFadeAlpha = 0.1,
	hideEmptyButtons = false,
	showHotkeys = true,
	showShapeshiftHotkeys = false,
	showNames = true,
	showCounts = true,
	countFont = { size = 11, outline = "OUTLINE" },
	cooldownFont = { size = 12, outline = "OUTLINE" },
	clickAnimation = true,
	dragButton = "LeftButton",
	dragModifier = "shift",
	hotkeyFont = { size = 9, outline = "OUTLINE" },
	nameFont = { size = 9, outline = "OUTLINE" },
	rangeColor = { 1, 0, 0 },
	manaColor = { 0.5, 0.5, 1 },
	unusableColor = { 0.4, 0.4, 0.4 },
	rangeIconTint = true,
	rangeHotkey = true,
	lossOfControl = true,
	lossOfControlColor = { 0.5, 0, 0, 0.6 },
	desaturateOnCooldown = false,
})

ns:RegisterDefaults("chat", {
	enabled = true,
	skin = true,
	timestamps = true,
	urlLinks = true,
	stripRealm = true,
	shortChannelNames = true,
	classColorNames = true,
	filterSystemSpam = true,
	filterArenaSpam = true,
	batchBattlegroundJoins = true,
	editBoxPosition = "below",
	scrollToBottomButton = true,
	whisperSoundThrottle = true,
	whisperSoundInterval = 60,
	lockFrames = true,
	hideCombatLog = false,
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
	fadeTime = 30,
	backgroundAlpha = 0.6,
	bubbleFont = { size = 12, outline = "" },
	bubbleMaxWidth = 300,
	bubbleShowSender = true,
	bubbleTypeBorder = false,
	whisperBlock = {
		enabled = false,
		reply = "",
		friendsBypass = true,
	},
})

ns:RegisterDefaults("cursorTrail", {
	enabled = false,
	hideInCombat = false,
	scale = 1,
	trailAlpha = 0.6,
	shineAlpha = 0.5,
})

ns:RegisterDefaults("equipment", {
	enabled = true,
	showItemLevels = true,
	durabilityThreshold = 0.2,
	slotFont = { size = 11, outline = "OUTLINE" },
	averageFont = { size = 14, outline = "OUTLINE" },
})

ns:RegisterDefaults("merchant", {
	enabled = true,
	sellGreys = true,
	autoRepair = true,
	guildRepair = false,
	showItemLevel = true,
	searchBox = true,
	filterMenu = true,
	hideUnusable = false,
	hideSoldOut = false,
	hideUnaffordable = false,
	hideKnown = false,
	sort = "default",
	sortReverse = false,
	wideFrame = true,
})

ns:RegisterDefaults("mail", {
	collectAll = true,
})

ns:RegisterDefaults("wheelPaging", {
	enabled = true,
})

ns:RegisterDefaults("modelControls", {
	enabled = true,
})

ns:RegisterDefaults("macros", {
	enabled = true,
})

ns:RegisterDefaults("spellBook", {
	enabled = true,
	hidePassive = false,
	hideAuras = false,
})

ns:RegisterDefaults("talentFrame", {
	enabled = true,
})

ns:RegisterDefaults("inspectFrame", {
	enabled = true,
})

ns:RegisterDefaults("combatLogFix", {
	enabled = true,
})

ns:RegisterDefaults("tweaks", {
	enabled = true,
	errorMessages = "hidden",
	scriptErrors = false,
	hideGroundClutter = false,
	disableTutorials = false,
	cameraDistanceMax = 50,
	cameraDistanceClose = 10,
	cameraDistanceMedium = 25,
	cameraDistanceFar = 50,
	instantCameraCollision = false,
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
	worldStatePoint = { "TOP", 0, -24 },
})

ns:RegisterDefaults("popups", {
	enabled = true,
	declineDuels = false,
	declineInvites = false,
	declineTrades = false,
	autoRelease = true,
	declineTradeInCombat = true,
	fillDeleteConfirm = false,
	autoAcceptInvites = false,
})

ns:RegisterDefaults("experienceBar", {
	enabled = true,
	width = 456,
	height = 5,
	point = { "TOP", 0, 0 },
	showReputation = true,
	xpColor = { 0.58, 0, 0.55 },
	restedColor = { 0, 0.39, 0.88, 0.6 },
	backgroundAlpha = 0.6,
})

ns:RegisterDefaults("worldMap", {
	enabled = true,
	screenFraction = 0.8,
	showCoords = true,
	coordFont = { size = 12, outline = "OUTLINE" },
	fadeWhenMoving = false,
	movingAlpha = 0.5,
})

ns:RegisterDefaults("hideBlizzard", {
	actionBars = true,
	unitFrames = true,
	castBar = true,
	buffs = true,
	weaponEnchants = true,
	runes = true,
})

ns:RegisterDefaults("classNames", {
	enabled = true,
	friends = true,
	guild = true,
	who = true,
	scoreboard = true,
	other = true,
	levels = true,
})

ns:RegisterDefaults("blizzardFrames", {
	enabled = true,
	captureBarPoint = { "TOPRIGHT", 0, -76, "minimap.point", "BOTTOMRIGHT" },
	vehicleSeatPoint = { "TOPRIGHT", 0, -100, "minimap.point", "BOTTOMRIGHT" },
	errorsPoint = { "TOP", 0, -122 },
	raidWarningPoint = { "TOP", 0, 0, "blizzardFrames.errorsPoint", "BOTTOM" },
	questTracker = {
		arena = true,
		battleground = false,
		combat = false,
	},
})

ns:RegisterDefaults("performance", {
	enabled = true,
	point = { "TOPLEFT", 12, -10 },
	showFps = true,
	showLatency = true,
	valueFont = { size = 16, outline = "OUTLINE" },
	unitFont = { size = 11, outline = "OUTLINE" },
})

ns:RegisterDefaults("tooltip", {
	enabled = true,
	point = { "BOTTOMRIGHT", -13, 64 },
	scale = 1,
	hideInCombat = true,
	hideInCombatWorld = false,
	showIds = false,
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
})

ns:RegisterDefaults("minimap", {
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
	showZoneText = true,
	zoneFont = { size = 11, outline = "OUTLINE" },
	showTracking = false,
	collectButtons = true,
	iconSize = 18,
	borderColor = { 1, 1, 1 },
})

ns:RegisterDefaults("bags", {
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
	movable = true,
	tintUnusable = true,
	showBagFreeSlots = true,
	offlineBank = true,
	altGold = true,
	lockModifier = "ALT",
	sortReverse = false,
	sortMessages = false,
	countFont = { size = 12, outline = "OUTLINE" },
	levelFont = { size = 10, outline = "OUTLINE" },
})
