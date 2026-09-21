local _, ns = ...

local type, pairs, wipe, unpack, tonumber = type, pairs, wipe, unpack, tonumber
local InCombatLockdown = InCombatLockdown

ns.Defaults = {
	actionBar = {
		enabled = true,
		buttonSize = 36,
		smallButtonSize = 30,
		gap = 2,
		bottomOffset = 2,
		showBar2 = true,
		showBar3 = true,
		showBar4 = true,
		showBar5 = true,
		showHotkeys = true,
		showNames = true,
		hotkeyFont = { size = 9, outline = "OUTLINE" },
		nameFont = { size = 9, outline = "OUTLINE" },
		rangeColor = { 1, 0, 0 },
		manaColor = { 0.5, 0.5, 1 },
		unusableColor = { 0.4, 0.4, 0.4 },
	},

	unitFrames = {
		enabled = true,
		player = { "TOPLEFT", 320, -80 },
		playerCastbar = { "TOP", 0, -4 },
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
	},

	chat = {
		skin = true,
		timestamps = true,
		urlLinks = true,
		stripRealm = true,
		shortChannelNames = true,
		classColorNames = true,
		filterSystemSpam = true,
		filterArenaSpam = true,
		point = { "BOTTOMLEFT", 12, 36 },
		width = 400,
		height = 153,
		fadeTime = 30,
		backgroundAlpha = 0.6,
		bubbleFont = { size = 12, outline = "" },
		bubbleAlpha = 0.75,
		bubbleMaxWidth = 300,
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
		nameFont = { size = 9, outline = "OUTLINE" },
		percentFont = { size = 9, outline = "OUTLINE" },
		castbarColor = { 0.75, 0.4, 0 },
		castbarLockedColor = { 0.4, 0.4, 0.4 },
		showAuras = true,
		auraSize = 20,
		auraFont = { size = 10, outline = "OUTLINE" },
		showHealers = true,
		healerIconSize = 16,
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
	},
	shieldIndicator = {
		enabled = true,
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
	},

	cursorTrail = {
		enabled = true,
	},

	announce = {
		interrupts = true,
		interruptMessage = "Interrupted %s's %s",
		auraMastery = true,
		arenaResult = true,
		arenaResultToParty = true,
	},

	dispelHighlightAlpha = 0.5,

	equipment = {
		showItemLevels = true,
		durabilityWarning = true,
		durabilityThreshold = 0.2,
	},

	merchant = {
		sellGreys = true,
		autoRepair = true,
	},

	wheelPaging = {
		enabled = true,
	},

	tweaks = {
		hideErrors = true,
	},

	popups = {
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

	arenaTrinket = { size = 30 },

	arena = {
		countdown = true,
		countdownPoint = { "CENTER", 0, 180 },
		countdownFont = { size = 24, outline = "OUTLINE" },
		pillars = true,
		pillarsSize = 36,
	},

	battleground = {
		raidWarnings = true,
	},

	soloQueue = {
		enabled = true,
		rangeFont = { size = 12, outline = "OUTLINE" },
	},

	worldMap = {
		screenFraction = 0.8,
		showCoords = true,
		coordFont = { size = 12, outline = "OUTLINE" },
		arrowSize = 36,
	},

	arenaHistory = {
		enabled = true,
		point = { "CENTER", 0, 40 },
		maxGames = 1000,
	},

	combatAlert = {
		enabled = true,
		point = { "CENTER", 0, 150 },
		font = { size = 22, outline = "OUTLINE" },
		duration = 1,
		enterText = "+ combat",
		leaveText = "- combat",
		enterColor = { 1, 0.3, 0.3 },
		leaveColor = { 0.3, 1, 0.3 },
	},

	performance = {
		enabled = true,
		point = { "TOPLEFT", 12, -10 },
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
	},

	minimap = {
		enabled = true,
		point = { "TOPRIGHT", -15, -15 },
		size = 140,
		showClock = true,
		clockFont = { size = 12, outline = "OUTLINE" },
		borderColor = { 1, 1, 1 },
	},

	bags = {
		enabled = true,
		buttonSize = 34,
		spacing = 4,
		inventoryColumns = 10,
		bankColumns = 16,
		inventory = { "BOTTOMRIGHT", -6, 42 },
		bank = { "LEFT", 60, 0 },
		backgroundAlpha = 0.6,
		showItemLevel = true,
		highlightNewItems = true,
		autoOpen = true,
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

local Config = ns:NewModule("Config")

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
		local saved, savedKey = walk(ns.db.config, listPath, true)
		assign(saved, savedKey, listNode[listKey])
	else
		local saved, savedKey = walk(ns.db.config, path, true)
		assign(saved, savedKey, value)
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
		wipe(ns.db.config)
		reset(ns.Config, ns.Defaults)
		ns:Fire(ns.CONFIG_CHANGED)
		return
	end
	local node, key = walk(ns.Config, path, true)
	local defaults, defaultKey = walk(ns.Defaults, path)
	local saved, savedKey = walk(ns.db.config, path)
	if saved then
		saved[savedKey] = nil
	end
	assign(node, key, defaults and defaults[defaultKey])
	ns:Fire(ns.CONFIG_CHANGED, path)
end

function ns:IsDefaultConfig(path)
	local saved, key = walk(ns.db.config, path)
	return not saved or saved[key] == nil
end

Config:RegisterEvent(ns.DB_LOADED, function(_, db)
	db.config = db.config or {}
	merge(ns.Config, db.config)
	ns:Fire(ns.CONFIG_CHANGED)
end)

local function matches(path, prefix)
	return not path or path == prefix or path:sub(1, #prefix + 1) == prefix .. "."
end

local pending = {}
local combatWatcher = ns.Mixin({}, ns.EventMixin)

combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	for handler, owner in pairs(pending) do
		handler(owner)
	end
	wipe(pending)
end)

function ns.ModulePrototype:AnchorToConfig(frame, path, secure)
	local function apply()
		frame:ClearAllPoints()
		frame:SetPoint(unpack(ns:GetConfig(path)))
	end
	apply()
	self:WatchConfig(path, apply, secure)
end

function ns.ModulePrototype:WatchConfig(prefix, handler, secure)
	self:RegisterEvent(ns.CONFIG_CHANGED, function(owner, path)
		if not matches(path, prefix) then
			return
		end
		if secure and InCombatLockdown() then
			pending[handler] = owner
		else
			handler(owner)
		end
	end)
end
