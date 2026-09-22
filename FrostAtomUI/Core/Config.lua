local _, ns = ...

local InCombatLockdown, SetCVar = InCombatLockdown, SetCVar
local sort, concat, strchar = table.sort, table.concat, string.char

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

	actionBar = {
		enabled = true,
		gap = 2,
		bar1 = { point = { "BOTTOM", 0, 2 }, buttons = 12, columns = 12, buttonSize = 36 },
		bar2 = { enabled = true, point = { "BOTTOM", 0, 40 }, buttons = 12, columns = 12, buttonSize = 36 },
		bar3 = { enabled = true, point = { "BOTTOM", 0, 78 }, buttons = 12, columns = 12, buttonSize = 36 },
		bar4 = { enabled = true, point = { "BOTTOM", -316, 2 }, buttons = 12, columns = 4, buttonSize = 36 },
		bar5 = { enabled = true, point = { "BOTTOM", 316, 2 }, buttons = 12, columns = 4, buttonSize = 36 },
		stance = { point = { "BOTTOM", -150, 116 }, columns = 10, buttonSize = 30 },
		pet = { point = { "BOTTOM", 68, 116 }, columns = 10, buttonSize = 30 },
		microMenu = { "BOTTOMRIGHT", -2, 2 },
		microMenuScale = 1,
		microMenuMouseover = false,
		bagButton = { "BOTTOMRIGHT", -256, 5 },
		bagButtonMouseover = false,
		menuFadeAlpha = 0.1,
		showHotkeys = true,
		showShapeshiftHotkeys = false,
		showNames = true,
		clickAnimation = true,
		hotkeyFont = { size = 9, outline = "OUTLINE" },
		nameFont = { size = 9, outline = "OUTLINE" },
		rangeColor = { 1, 0, 0 },
		manaColor = { 0.5, 0.5, 1 },
		unusableColor = { 0.4, 0.4, 0.4 },
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
		groupSpacing = 160,
		boss = { "RIGHT", -150, 300 },
		bossSpacing = 60,
		outOfRangeAlpha = 0.75,
		showPartyCooldowns = true,
		showArenaCooldowns = true,
		partyCooldownSize = 24,
		arenaCooldownSize = 24,
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
		playerCastbarHeight = 34,
		playerAuraSize = 34,
		classColorHealth = true,
		textColor = { 1, 1, 1 },
		backdropColor = { 0, 0, 0, 0.6 },
		borderColor = { 1, 1, 1 },
		targetBorderColor = { 1, 0.8, 0 },
		focusBorderColor = { 0.3, 0.65, 1 },
		castbarColor = { 0.75, 0.4, 0 },
		castbarLockedColor = { 0.4, 0.4, 0.4 },
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
		showLoseControl = true,
		loseControlPoint = { "CENTER", 0, 0 },
		loseControlSize = 32,
		rightClick = "menu",
		hoverHighlight = true,
		hoverAlpha = 0.08,
		healthCutaway = true,
		healthCutawayColor = { 1, 0.9, 0.8, 0.6 },
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
		cooldownGlowColor = { 1, 0.85, 0.3 },
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
		lockFrames = true,
		stickyChannels = true,
		timestampFormat = "%H:%M",
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
		totemIconSize = 24,
		raidIconSize = 22,
		showTargetPercent = true,
		showName = true,
		showRaidIcon = true,
		classColorHealth = true,
		targetBorder = true,
		castbarGap = 3,
		nameFont = { size = 9, outline = "OUTLINE" },
		percentFont = { size = 9, outline = "OUTLINE" },
		castbarColor = { 0.75, 0.4, 0 },
		castbarLockedColor = { 0.4, 0.4, 0.4 },
		showAuras = true,
		showAuraTimer = true,
		showAuraCount = true,
		ownDebuffs = true,
		auraSize = 20,
		auraGap = 2,
		auraRowGap = 3,
		maxAuraIcons = 6,
		auraFont = { size = 10, outline = "OUTLINE" },
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
		showText = true,
		font = { size = 10, outline = "OUTLINE" },
		classColorHealth = true,
		healthColor = { 0, 0.8, 0 },
		alwaysShow = false,
		fadeTime = 0.5,
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

	auraTracker = {
		enabled = true,
		scale = 1,
		auras = {
			WARRIOR = {
				{ spell = 60503, unit = "player", point = { "CENTER", 18, -72 }, size = 36 }, -- Taste for Blood
				{ spell = 52437, unit = "player", point = { "CENTER", -18, -72 }, size = 36 }, -- Sudden Death
			},
			PALADIN = {
				{ spell = 54149, unit = "player", point = { "CENTER", 0, -72 }, size = 36 }, -- Infusion of Light
				{ spell = 54153, unit = "player", point = { "CENTER", 72, 36 }, size = 36 }, -- Judgements of the Pure
				{ spell = 53563, unit = "player", isMine = true, point = { "CENTER", -108, 36 }, size = 36 }, -- Beacon of Light
				{ spell = 53601, unit = "player", isMine = true, point = { "CENTER", -72, 36 }, size = 36 }, -- Sacred Shield
				{ spell = 58597, unit = "player", point = { "CENTER", 0, -36 }, size = 40 }, -- Sacred Shield proc
			},
			PRIEST = {
				{ spell = 48168, unit = "player", point = { "CENTER", 72, 36 }, size = 36 }, -- Inner Fire
			},
			DEATHKNIGHT = {
				{ spell = 55379, unit = "player", point = { "CENTER", 0, -72 }, size = 36 }, -- meta gem haste proc
				{
					spell = 55078,
					unit = "target",
					debuff = true,
					isMine = true,
					point = { "CENTER", -48, -42 },
					size = 30,
				}, -- Blood Plague
				{
					spell = 55095,
					unit = "target",
					debuff = true,
					isMine = true,
					point = { "CENTER", -16, -42 },
					size = 30,
				}, -- Frost Fever
				{
					spell = 51735,
					unit = "target",
					debuff = true,
					isMine = true,
					point = { "CENTER", 16, -42 },
					size = 30,
				}, -- Ebon Plague
				{
					spell = 50536,
					unit = "target",
					debuff = true,
					isMine = true,
					point = { "CENTER", 48, -42 },
					size = 30,
				}, -- Unholy Blight
			},
			SHAMAN = {
				{ spell = 57960, unit = "player", point = { "CENTER", 72, 36 }, size = 36 }, -- Water Shield
				{ spell = 70806, unit = "player", point = { "CENTER", 0, -72 }, size = 36 }, -- 2p T10 resto proc
				{ spell = 8178, unit = "player", isMine = true, point = { "CENTER", -108, 36 }, size = 36 }, -- Grounding Totem
			},
		},
	},

	temporaryEnchant = {
		enabled = true,
		point = { "TOPRIGHT", -155, -163 },
		size = 30,
		gap = 2,
	},

	lowHealthFlash = {
		enabled = true,
		threshold = 0.33,
		pulseSpeed = 1.2,
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
		shiftToSkip = true,
	},

	wheelPaging = {
		enabled = true,
	},

	modelControls = {
		enabled = true,
		rotateSpeed = 0.01,
		zoomStep = 0.4,
	},

	combatLogFix = {
		enabled = true,
	},

	tweaks = {
		enabled = true,
		hideErrors = true,
		scriptErrors = true,
		hideGroundClutter = true,
		cameraDistanceMax = 50,
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

	arenaTrinket = { enabled = true, size = 30 },

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
	},

	arenaHistory = {
		enabled = true,
		point = { "CENTER", 0, 40 },
		maxGames = 1000,
		listFont = { size = 12, outline = "" },
		winColor = { 0.3, 1, 0.3 },
		lossColor = { 1, 0.3, 0.3 },
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
		hideInCombat = true,
		showIds = true,
		showItemLevel = true,
		showItemCount = true,
		showTargetedBy = true,
		labelColor = { 0.2, 0.4, 1 },
	},

	minimap = {
		enabled = true,
		point = { "TOPRIGHT", -15, -15 },
		size = 140,
		mouseover = false,
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

function ns:SetConfig(path, value)
	local node, key = walk(ns.Config, path, true)
	assign(node, key, value)

	local listPath = path:match("^(.-)%.%d+%.") or path:match("^(.-)%.%d+$")
	if listPath then
		local listNode, listKey = walk(ns.Config, listPath)
		local store, storeKey = walk(saved, listPath, true)
		assign(store, storeKey, listNode[listKey])
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

	local listPath = path:match("^(.-)%.%d+%.") or path:match("^(.-)%.%d+$")
	if listPath then
		local listNode, listKey = walk(ns.Config, listPath)
		local store, storeKey = walk(saved, listPath, true)
		assign(store, storeKey, listNode[listKey])
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

local function prune(target, defaults)
	for key, value in pairs(target) do
		local default = defaults[key]
		if default == nil then
			target[key] = nil
		elseif type(value) == "table" and type(default) == "table" and default[1] == nil and value[1] == nil then
			prune(value, default)
		end
	end
end

local function charKey()
	return UnitName("player") .. " - " .. GetRealmName()
end

local function activate(name)
	local profiles = ns.db.profiles
	profiles[name] = profiles[name] or {}
	saved = profiles[name]
	prune(saved, ns.Defaults)
	activeProfile = name
	ns.db.charProfile[charKey()] = name
	reset(ns.Config, ns.Defaults)
	merge(ns.Config, saved)
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
	wipe(saved)
	merge(saved, profile)
	reset(ns.Config, ns.Defaults)
	merge(ns.Config, saved)
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
				local next = body:sub(i + 1, i + 1)
				out[#out + 1] = ESCAPES[next] or next
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

function ns:ExportProfile()
	local out = {}
	serialize(saved, out)
	return EXPORT_PREFIX .. ns.Encode(concat(out))
end

function ns:ImportProfile(text)
	text = text and text:trim()
	if not text or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return false, "not a FrostAtom UI profile string"
	end
	local body, err = ns.Decode(text:sub(#EXPORT_PREFIX + 1))
	if not body then
		return false, err
	end
	local data, pos = parseValue(body, 1)
	if type(data) ~= "table" or pos ~= #body + 1 then
		return false, "malformed profile string"
	end
	prune(data, ns.Defaults)
	wipe(saved)
	merge(saved, data)
	reset(ns.Config, ns.Defaults)
	merge(ns.Config, saved)
	ns:Fire(ns.CONFIG_CHANGED)
	return true
end

Config:RegisterEvent(ns.DB_LOADED, function(_, db)
	db.profiles = db.profiles or {}
	db.charProfile = db.charProfile or {}
	if db.config then
		db.profiles[DEFAULT_PROFILE] = db.profiles[DEFAULT_PROFILE] or db.config
		db.config = nil
	end
	activate(db.charProfile[charKey()] or DEFAULT_PROFILE)
	applyGeneral()
	ns:Fire(ns.CONFIG_CHANGED)
end)

local function matches(path, prefix)
	return not path or path == prefix or path:sub(1, #prefix + 1) == prefix .. "."
end

Config:RegisterEvent(ns.CONFIG_CHANGED, function(_, path)
	if matches(path, "general") then
		applyGeneral()
	end
end)

local pending = {}
local combatWatcher = ns.Mixin({}, ns.EventMixin)

combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	for handler, owner in pairs(pending) do
		handler(owner)
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
		pending[watcher.handler] = watcher.owner
	else
		watcher.handler(watcher.owner, path or nil)
	end
end

function ns.ModulePrototype:WatchConfig(prefix, handler, secure)
	local watcher = { owner = self, handler = handler, secure = secure }
	self:RegisterEvent(ns.CONFIG_CHANGED, function(_, path)
		if not matches(path, prefix) then
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
