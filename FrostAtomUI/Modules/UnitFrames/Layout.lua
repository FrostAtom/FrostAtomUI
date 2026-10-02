local ADDON_NAME, ns = ...
local UF = ns:GetModule("UnitFrames")
local max, ceil = math.max, math.ceil

local PARTY_HOLDER_NAME = ADDON_NAME .. "PartyFrames"
local MAX_PARTY_FRAMES = MAX_PARTY_MEMBERS or 4
local MAX_ARENA_OPPONENTS = 3

local SQUARE_AURA_GAP = 2
local AURA_GROWTH_ANCHORS = { LEFT = "TOPRIGHT", RIGHT = "TOPLEFT" }

local player, castbar, pet, target, focus
local party, arena = {}, {}
UF.groupFrames = { party = party, arena = arena }
local partyPets, arenaPets = {}, {}
local partyTargets, arenaTargets = {}, {}
local squares = {}
local polledSquares = {}

local function groupFramePath(prefix, index)
	return "unitFrames." .. (index == 1 and prefix or prefix .. index)
end

local function groupChildPath(prefix, index, suffix)
	return "unitFrames." .. prefix .. index .. suffix
end

local function setGroupPoints(frames)
	for i = 1, #frames do
		local frame = frames[i]
		ns.ApplyPoint(frame, frame.moverPath)
		ns.ApplyPoint(frame.castbar, frame.castbar.moverPath)
		ns.ApplyPoint(frame.pet, frame.pet.moverPath)
		ns.ApplyPoint(frame.unitTarget, frame.unitTarget.moverPath)
		ns.ApplyPoint(frame.pet.castbar, frame.pet.castbar.moverPath)
		ns.ApplyPoint(frame.unitTarget.castbar, frame.unitTarget.castbar.moverPath)
	end
end

local function applyPositions()
	ns.ApplyPoint(player, "unitFrames.player")
	ns.ApplyPoint(target, "unitFrames.target")
	ns.ApplyPoint(focus, "unitFrames.focus")
	ns.ApplyPoint(pet, "unitFrames.pet")
	ns.ApplyPoint(target.targetOfTarget, "unitFrames.targetOfTarget")
	ns.ApplyPoint(focus.targetOfTarget, "unitFrames.focusTarget")
	ns.ApplyPoint(player.buffs, "unitFrames.playerAuras")
	ns.ApplyPoint(player.debuffs, "unitFrames.playerDebuffs")
	ns.ApplyPoint(castbar, "unitFrames.playerCastbar")
	ns.ApplyPoint(target.castbar, "unitFrames.targetCastbar")
	ns.ApplyPoint(focus.castbar, "unitFrames.focusCastbar")
	ns.ApplyPoint(pet.castbar, "unitFrames.petCastbar")
	ns.ApplyPoint(target.targetOfTarget.castbar, "unitFrames.targetOfTargetCastbar")
	ns.ApplyPoint(focus.targetOfTarget.castbar, "unitFrames.focusTargetCastbar")
	setGroupPoints(party)
	setGroupPoints(arena)
end

local function gridCapacity(grid)
	local rows = max(ceil(grid.limit / grid.perRow), grid.minRows)
	if rows == 0 then
		return 0
	end
	local size = grid.RowSize and grid:RowSize() or grid.size
	return rows * (size + grid.gap) - grid.gap
end

local function auraInsets(frame, fixedGap, gapKey)
	return function()
		local gap = fixedGap or ns.Config.unitFrames[gapKey]
		local left, right, top, bottom, leftHeight, rightHeight = 0, 0, 0, 0, -gap, -gap
		for _, grid in ipairs({ frame.debuffs, frame.buffs }) do
			local capacity = gridCapacity(grid)
			if capacity > 0 then
				local position = grid.position
				if position == "LEFT" then
					left = max(left, gap + grid:GetWidth())
					leftHeight = leftHeight + gap + capacity
				elseif position == "RIGHT" then
					right = max(right, gap + grid:GetWidth())
					rightHeight = rightHeight + gap + capacity
				elseif position == "TOP" then
					top = top + gap + capacity
				else
					bottom = bottom + gap + capacity
				end
			end
		end
		return left, right, top, max(bottom, max(leftHeight, rightHeight) - frame:GetHeight())
	end
end

local function castbarInsets(bar)
	return function()
		local icon = bar:GetHeight() + UF.CASTBAR_ICON_GAP
		if bar.iconSide == "RIGHT" then
			return 0, icon, 0, 0
		end
		return icon, 0, 0, 0
	end
end

local function growthAnchor(growth)
	return AURA_GROWTH_ANCHORS[growth] or "TOPRIGHT"
end

local function sizePlayerCastbar(config)
	UF.SetCastbarSize(castbar, config.playerCastbarWidth, config.playerCastbarHeight)
end

local function applyTrinkets()
	local trinketSize = ns.Config.arenaTrinket.size
	for _, frames in ipairs({ party, arena }) do
		for i = 1, #frames do
			local trinket = frames[i].trinket
			trinket:SetIconSize(trinketSize)
			trinket:Refresh()
		end
	end
end

local function applySizes()
	local config = ns.Config.unitFrames
	applyTrinkets()
	sizePlayerCastbar(config)
	player.buffs:SetShape(config.playerAuraPerRow, growthAnchor(config.playerAuraGrowth))
	player.debuffs:SetShape(config.playerDebuffPerRow, growthAnchor(config.playerDebuffGrowth))
	player.buffs:SetIconSize(config.playerAuraSize)
	player.debuffs:SetIconSize(config.playerDebuffSize)
end

local function resizeGroupFrame(frame, keys)
	local config = ns.Config.unitFrames
	local width = config[keys.width]
	frame:SetFrameSize(width, config[keys.height])
	frame.debuffs:SetLayout(width, config[keys.debuffSize])
	frame.buffs:SetLayout(width, config[keys.buffSize])
	UF.SetCastbarSize(frame.castbar, config[keys.castbarWidth], config[keys.castbarHeight])
end

local function affectsSize(path)
	local key = path:match("[^.]+$")
	return key:find("Width$")
		or key:find("Height$")
		or key:find("Aura")
		or key:find("Debuff")
		or key:find("Buff")
		or key == "powerRatio"
end

local function applyFrameSizes(self, path)
	if path and not affectsSize(path) then
		return
	end
	local config = ns.Config.unitFrames
	player:SetFrameSize(config.playerWidth, config.playerHeight)
	self:ResizeTarget(target, config.targetWidth, config.targetHeight)
	self:ResizeTarget(focus, config.focusWidth, config.focusHeight)
	local partyKeys, arenaKeys = UF.CategoryKeys("party"), UF.CategoryKeys("arena")
	for i = 1, #party do
		resizeGroupFrame(party[i], partyKeys)
	end
	for i = 1, #arena do
		resizeGroupFrame(arena[i], arenaKeys)
	end
	for i = 1, #squares do
		local square = squares[i]
		local keys, frames = square.keys, square.frames
		local width, height = config[keys.width], config[keys.height]
		for j = 1, #frames do
			frames[j]:SetFrameSize(width, height)
		end
	end
end

local function setGroupWatched(frames, watched)
	for i = 1, #frames do
		frames[i]:SetWatched(watched)
	end
end

function UF.GroupChainEnd(frame)
	local config = ns.Config.unitFrames
	local anchor, chainPath = frame, frame.moverPath
	for _, child in ipairs({ frame.pet, frame.unitTarget }) do
		if ns:GetConfig(child.moverPath)[4] ~= chainPath then
			break
		end
		chainPath = child.moverPath
		if config[child.shownKey] then
			anchor = child
		end
	end
	return anchor
end

local function anchorGroupTrinkets(frames, side)
	local point = side == "LEFT" and "RIGHT" or "LEFT"
	local x = side == "LEFT" and -2 or 2
	for i = 1, #frames do
		local frame = frames[i]
		frame.trinket:ClearAllPoints()
		frame.trinket:SetPoint(point, UF.GroupChainEnd(frame), side, x, 0)
	end
end

local function applyVisibility()
	local config = ns.Config.unitFrames
	pet:SetWatched(config.showPet)
	target.targetOfTarget:SetWatched(config.showTargetOfTarget)
	focus.targetOfTarget:SetWatched(config.showFocusTarget)
	local showParty = config.showParty
	setGroupWatched(party, showParty)
	setGroupWatched(partyPets, showParty and config.showPartyPet)
	setGroupWatched(partyTargets, showParty and config.showPartyTarget)
	setGroupWatched(arena, config.showArena)
	setGroupWatched(arenaPets, config.showArena and config.showArenaPet)
	setGroupWatched(arenaTargets, config.showArena and config.showArenaTarget)
end

local function applyGroupAnchors()
	anchorGroupTrinkets(party, "LEFT")
	anchorGroupTrinkets(arena, "RIGHT")
end

local function applyGroupElements(frames, keys, config)
	local debuffLimit = config[keys.debuffs] and config[keys.debuffMax] or 0
	local buffLimit = config[keys.buffs] and config[keys.buffMax] or 0
	local castbarShown = config[keys.castbar]
	local side = config[keys.iconSide]
	local gap = config[keys.auraSpacing]
	for i = 1, #frames do
		local frame = frames[i]
		frame:SetIconSide(side)
		frame.debuffs.minRows = debuffLimit > 0 and 1 or 0
		frame.debuffs:SetLimit(debuffLimit)
		frame.buffs:SetLimit(buffLimit)
		UF.PlaceAuraGrids(frame, keys, gap)
		UF.SetCastbarShown(frame.castbar, castbarShown)
	end
end

local function applySquareElements(square, config)
	local keys, frames = square.keys, square.frames
	local castbarShown = config[keys.castbar]
	local perRow, size = config[keys.auraPerRow], config[keys.auraSize]
	local limit = perRow * config[keys.auraRows]
	local debuffLimit = config[keys.debuffs] and limit or 0
	local buffLimit = config[keys.buffs] and limit or 0
	local anchor = AURA_GROWTH_ANCHORS[config[keys.auraGrowth]] or "TOPLEFT"
	local castbarWidth, castbarHeight = config[keys.castbarWidth], config[keys.castbarHeight]
	for i = 1, #frames do
		local frame = frames[i]
		UF.SetCastbarSize(frame.castbar, castbarWidth, castbarHeight)
		UF.SetCastbarShown(frame.castbar, castbarShown)
		local debuffs, buffs = frame.debuffs, frame.buffs
		debuffs:SetShape(perRow, anchor)
		debuffs:SetIconSize(size)
		debuffs:SetLimit(debuffLimit)
		buffs:SetShape(perRow, anchor)
		buffs:SetIconSize(size)
		buffs:SetLimit(buffLimit)
		UF.StackAuraGrids(frame, anchor, SQUARE_AURA_GAP, "debuffs")
		if square.power then
			UF.SetPetPowerShown(frame, config[keys.power])
		end
	end
	return castbarShown or debuffLimit > 0 or buffLimit > 0
end

local function applyElements()
	local config = ns.Config.unitFrames
	target.combopoints:SetPointSize(config.comboPointSize)
	UF.SetCastbarShown(castbar, config.showPlayerCastbar)
	UF.SetCastbarShown(target.castbar, config.showTargetCastbar)
	UF.SetCastbarShown(focus.castbar, config.showFocusCastbar)
	UF.PlaceAuraGrids(target, UF.CategoryKeys("target"), UF.CASTBAR_GAP)
	UF.PlaceAuraGrids(focus, UF.CategoryKeys("focus"), UF.CASTBAR_GAP)
	player:SetIconSide(config.playerIconSide)
	target:SetIconSide(config.targetIconSide)
	focus:SetIconSide(config.focusIconSide)
	applyGroupElements(party, UF.CategoryKeys("party"), config)
	applyGroupElements(arena, UF.CategoryKeys("arena"), config)
	local polling = false
	for i = 1, #squares do
		local square = squares[i]
		local active = applySquareElements(square, config)
		polling = polling or active and polledSquares[square] or false
	end
	UF.SetPollingActive(polling)
end

local function frameResize(widthKey, heightKey, minWidth, minHeight)
	return {
		minWidth = minWidth,
		maxWidth = 500,
		minHeight = minHeight,
		maxHeight = 200,
		get = function()
			local config = ns.Config.unitFrames
			return config[widthKey], config[heightKey]
		end,
		set = function(width, height)
			ns:SetConfig("unitFrames." .. widthKey, width)
			ns:SetConfig("unitFrames." .. heightKey, height)
		end,
	}
end

local function addLeader(self, frame)
	local leader = self:AddElement(frame, "leader")
	leader:SetPoint("TOPRIGHT", frame.classicon, -1, -1)
end

local function addRaidIconAbove(self, frame)
	local raidIcon = self:AddElement(frame, "raidicon")
	raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, -4)
end

local function addPvp(self, frame)
	local pvp = self:AddElement(frame, "pvp")
	pvp:SetPoint("CENTER", frame, "BOTTOMRIGHT", -8, 0)
end

local function squareCategory(key, power, polled)
	local square = { keys = UF.CategoryKeys(key), frames = {}, power = power }
	squares[#squares + 1] = square
	if polled then
		polledSquares[square] = true
	end
	return square
end

local function addSquareParts(self, frame, square, moverPath)
	local config = ns.Config.unitFrames
	local keys = square.keys
	frame.moverPath = moverPath
	local squareCastbar = self:CreateSideCastbar(frame, "LEFT", config[keys.castbarWidth], config[keys.castbarHeight])
	squareCastbar.moverPath = moverPath .. "Castbar"
	local options = { size = config[keys.auraSize], perRow = config[keys.auraPerRow], max = 0 }
	self:AddElement(frame, "debuffs", options)
	self:AddElement(frame, "buffs", options)
	square.frames[#square.frames + 1] = frame
	if polledSquares[square] then
		UF.EnablePolling(frame)
	end
end

local function createPlayer(self, config)
	player = self:CreateRectangle("player", config.playerWidth, config.playerHeight, config.playerIconSide)
	ns.ApplyPoint(player, "unitFrames.player")

	addLeader(self, player)

	local buffs = self:AddElement(player, "buffs", {
		size = config.playerAuraSize,
		gap = 2,
		perRow = config.playerAuraPerRow,
		anchor = growthAnchor(config.playerAuraGrowth),
	})
	ns.ApplyPoint(buffs, "unitFrames.playerAuras")

	self:AddElement(player, "debuffs", {
		size = config.playerDebuffSize,
		gap = 2,
		perRow = config.playerDebuffPerRow,
		anchor = growthAnchor(config.playerDebuffGrowth),
	})

	castbar = self:AddElement(player, "castbar")
	sizePlayerCastbar(config)
	ns.ApplyPoint(castbar, "unitFrames.playerCastbar")

	addRaidIconAbove(self, player)

	addPvp(self, player)

	self:AddElement(player, "dispel")
	self:AddElement(player, "combatglow")
	if ns.PLAYER_CLASS == "DRUID" then
		self:AddElement(player, "druidmana")
	end
	self:AddElement(player, "procs")
	player:EnableVehicleSwap("player", "vehicle", { buffs = true, debuffs = true, pvp = true, procs = true })

	pet = self:CreatePet("pet", config.petHeight)
	pet:SetFrameSize(config.petWidth, config.petHeight)
	ns.ApplyPoint(pet, "unitFrames.pet")
	local happiness = self:AddElement(pet, "happiness")
	happiness:SetPoint("TOPLEFT", pet.health, 1, -1)
	addSquareParts(self, pet, squareCategory("pet", true), "unitFrames.pet")
end

local function createTargets(self, config)
	local targetOfTarget
	target, targetOfTarget = self:CreateTarget("target", config.targetWidth, config.targetHeight)
	ns.ApplyPoint(target, "unitFrames.target")
	targetOfTarget:SetFrameSize(config.targetOfTargetWidth, config.targetOfTargetHeight)
	ns.ApplyPoint(targetOfTarget, "unitFrames.targetOfTarget")
	target:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")
	targetOfTarget:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")
	self:AddElement(targetOfTarget, "hideself")
	addSquareParts(self, targetOfTarget, squareCategory("targetOfTarget", false, true), "unitFrames.targetOfTarget")

	local combo = self:AddElement(target, "combopoints", { gap = 2 })
	combo:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 2, 2)

	local focusTarget
	focus, focusTarget = self:CreateTarget("focus", config.focusWidth, config.focusHeight)
	ns.ApplyPoint(focus, "unitFrames.focus")
	focusTarget:SetFrameSize(config.focusTargetWidth, config.focusTargetHeight)
	ns.ApplyPoint(focusTarget, "unitFrames.focusTarget")
	focus:RegisterEvent("PLAYER_FOCUS_CHANGED", "QueueUpdate")
	focusTarget:RegisterEvent("PLAYER_FOCUS_CHANGED", "QueueUpdate")
	addSquareParts(self, focusTarget, squareCategory("focusTarget", false, true), "unitFrames.focusTarget")

	for _, frame in ipairs({ target, focus }) do
		addRaidIconAbove(self, frame)
		addPvp(self, frame)
		self:AddElement(frame, "dispel")
		self:AddElement(frame, "diminish")
		self:AddElement(frame, "procs")
	end
end

local function createGroupSquares(self, frame, prefix, name, index, petSquare, targetSquare, parent)
	local config = ns.Config.unitFrames
	local pet = self:CreatePet(prefix .. "pet" .. index, 1, parent)
	pet.moverPath = groupChildPath(prefix, index, "Pet")
	pet.shownKey = "show" .. name .. "Pet"
	pet:SetFrameSize(config[petSquare.keys.width], config[petSquare.keys.height])
	frame.pet = pet

	local unitTarget = self:CreateTargetOfTarget(prefix .. index .. "target", 1, parent)
	unitTarget.moverPath = groupChildPath(prefix, index, "Target")
	unitTarget.shownKey = "show" .. name .. "Target"
	unitTarget:SetFrameSize(config[targetSquare.keys.width], config[targetSquare.keys.height])
	frame.unitTarget = unitTarget

	addSquareParts(self, pet, petSquare, pet.moverPath)
	addSquareParts(self, unitTarget, targetSquare, unitTarget.moverPath)

	return pet, unitTarget
end

local function groupAuraOptions(config, keys, width)
	return {
		size = config[keys.debuffSize],
		width = width,
		max = 0,
	}, {
		size = config[keys.buffSize],
		width = width,
		max = 0,
	}
end

local function createParty(self, config)
	local width, height = config.partyWidth, config.partyHeight
	local debuffOptions, buffOptions = groupAuraOptions(config, UF.CategoryKeys("party"), width)
	local petSquare = squareCategory("partyPet", true)
	local targetSquare = squareCategory("partyTarget", false, true)
	local holder = CreateFrame("Frame", PARTY_HOLDER_NAME, UIParent)
	UF.partyHolder = holder

	for i = 1, MAX_PARTY_FRAMES do
		local frame = self:CreateRectangle("party" .. i, width, height, config.partyIconSide, holder)
		party[i] = frame
		frame.moverPath = groupFramePath("party", i)
		frame:RegisterEvent("PARTY_MEMBERS_CHANGED", "QueueUpdate")
		frame:RegisterEvent("PARTY_MEMBER_ENABLE", "QueueUpdate")
		frame:RegisterEvent("PARTY_MEMBER_DISABLE", "QueueUpdate")
		frame:EnableVehicleSwap("party" .. i, "partypet" .. i, { procs = true })

		addLeader(self, frame)
		addRaidIconAbove(self, frame)

		self:AddElement(frame, "debuffs", debuffOptions)
		self:AddElement(frame, "buffs", buffOptions)

		local partyCastbar = self:CreateSideCastbar(frame, "RIGHT", config.partyCastbarWidth, config.partyCastbarHeight)
		partyCastbar.moverPath = groupChildPath("party", i, "Castbar")
		self:AddElement(frame, "procs")

		self:AddElement(frame, "losecontrol")

		self:AddElement(frame, "range")
		self:AddElement(frame, "dispel")
		self:AddElement(frame, "highlight")

		local pet, unitTarget = createGroupSquares(self, frame, "party", "Party", i, petSquare, targetSquare, holder)
		pet:RegisterEvent("PARTY_MEMBERS_CHANGED", "QueueUpdate")
		unitTarget:RegisterEvent("PARTY_MEMBERS_CHANGED", "QueueUpdate")
		partyPets[i], partyTargets[i] = pet, unitTarget

		self:AddElement(frame, "trinket", { size = ns.Config.arenaTrinket.size, arenaOnly = true })
	end
end

local function createArena(self, config)
	local trinketSize = ns.Config.arenaTrinket.size
	local width, height = config.arenaWidth, config.arenaHeight
	local debuffOptions, buffOptions = groupAuraOptions(config, UF.CategoryKeys("arena"), width)
	local petSquare = squareCategory("arenaPet", true)
	local targetSquare = squareCategory("arenaTarget", false, true)

	for i = 1, MAX_ARENA_OPPONENTS do
		local frame = self:CreateRectangle("arena" .. i, width, height, config.arenaIconSide)
		arena[i] = frame
		frame.moverPath = groupFramePath("arena", i)

		self:AddElement(frame, "debuffs", debuffOptions)
		self:AddElement(frame, "buffs", buffOptions)

		local arenaCastbar = self:CreateSideCastbar(frame, "LEFT", config.arenaCastbarWidth, config.arenaCastbarHeight)
		arenaCastbar.moverPath = groupChildPath("arena", i, "Castbar")

		self:AddElement(frame, "losecontrol")

		addRaidIconAbove(self, frame)

		self:AddElement(frame, "range")
		self:AddElement(frame, "highlight")

		local pet, unitTarget = createGroupSquares(self, frame, "arena", "Arena", i, petSquare, targetSquare)
		unitTarget:RegisterEvent("ARENA_OPPONENT_UPDATE", "QueueUpdate")
		arenaPets[i], arenaTargets[i] = pet, unitTarget

		self:AddElement(frame, "trinket", { size = trinketSize })

		self:AddElement(frame, "diminish")
		self:AddElement(frame, "procs")
	end
end

local function castbarResizer(prefix)
	return frameResize(prefix .. "CastbarWidth", prefix .. "CastbarHeight", 60, 10)
end

local function squareResizer(key)
	return frameResize(key .. "Width", key .. "Height", 20, 20)
end

local function registerSquareMovers(self, frame, key, label, shownPaths, context)
	local castbarEnabledPath = { unpack(shownPaths) }
	castbarEnabledPath[#castbarEnabledPath + 1] = "unitFrames." .. UF.CategoryKeys(key).castbar
	self:RegisterMover(frame, frame.moverPath, label, {
		secure = true,
		enabledPath = shownPaths,
		resize = squareResizer(key),
		insets = auraInsets(frame, SQUARE_AURA_GAP),
		context = context,
	})
	self:RegisterMover(frame.castbar, frame.castbar.moverPath, label .. " castbar", {
		enabledPath = castbarEnabledPath,
		insets = castbarInsets(frame.castbar),
		resize = castbarResizer(key),
		context = context,
	})
end

local function registerGroupMovers(self, frames, prefix, name, context)
	local shownPath = "unitFrames.show" .. name
	local castbarShownPath = "unitFrames.show" .. name .. "Castbar"
	local resize = frameResize(prefix .. "Width", prefix .. "Height", 80, 20)
	local castbarResize = castbarResizer(prefix)
	local keys = UF.CategoryKeys(prefix)
	for i = 1, #frames do
		local frame = frames[i]
		self:RegisterMover(frame, frame.moverPath, name .. " " .. i, {
			secure = true,
			resize = resize,
			enabledPath = shownPath,
			insets = auraInsets(frame, nil, keys.auraSpacing),
			context = context,
		})
		self:RegisterMover(frame.castbar, frame.castbar.moverPath, name .. " " .. i .. " castbar", {
			enabledPath = { shownPath, castbarShownPath },
			insets = castbarInsets(frame.castbar),
			resize = castbarResize,
			context = context,
		})
		registerSquareMovers(
			self,
			frame.pet,
			prefix .. "Pet",
			name .. " " .. i .. " pet",
			{ shownPath, "unitFrames." .. frame.pet.shownKey },
			context
		)
		registerSquareMovers(
			self,
			frame.unitTarget,
			prefix .. "Target",
			name .. " " .. i .. " target",
			{ shownPath, "unitFrames." .. frame.unitTarget.shownKey },
			context
		)
	end
end

local function playerAuraHeight(grid)
	local rows = max(ceil(grid.limit / grid.perRow), 1)
	return rows * (grid.size + grid.gap) - grid.gap
end

local function playerAuraSize(grid)
	return function()
		return grid:GetWidth(), playerAuraHeight(grid)
	end
end

local function playerDebuffInsets()
	local _, _, _, anchorPath, anchorPoint = unpack(ns:GetConfig("unitFrames.playerDebuffs"))
	if anchorPath ~= "unitFrames.playerAuras" or not (anchorPoint and anchorPoint:find("^BOTTOM")) then
		return 0, 0, 0, 0
	end
	local buffs = player.buffs
	local shift = playerAuraHeight(buffs) - buffs:GetHeight()
	return 0, 0, -shift, shift
end

local function refreshMovers()
	ns.Movers.Refresh()
end

function UF:Initialize()
	local config = ns.Config.unitFrames

	self:HideBlizzard()
	createPlayer(self, config)
	createTargets(self, config)
	createParty(self, config)
	createArena(self, config)
	applyVisibility()

	self:RegisterMover(player, "unitFrames.player", "Player", {
		secure = true,
		resize = frameResize("playerWidth", "playerHeight", 80, 20),
	})
	self:RegisterMover(target, "unitFrames.target", "Target", {
		secure = true,
		resize = frameResize("targetWidth", "targetHeight", 80, 20),
		insets = auraInsets(target, UF.CASTBAR_GAP),
	})
	self:RegisterMover(focus, "unitFrames.focus", "Focus", {
		secure = true,
		resize = frameResize("focusWidth", "focusHeight", 80, 20),
		insets = auraInsets(focus, UF.CASTBAR_GAP),
	})
	self:RegisterMover(target.castbar, "unitFrames.targetCastbar", "Target castbar", {
		enabledPath = "unitFrames.showTargetCastbar",
		insets = castbarInsets(target.castbar),
		resize = castbarResizer("target"),
	})
	self:RegisterMover(focus.castbar, "unitFrames.focusCastbar", "Focus castbar", {
		enabledPath = "unitFrames.showFocusCastbar",
		insets = castbarInsets(focus.castbar),
		resize = castbarResizer("focus"),
	})
	registerSquareMovers(self, pet, "pet", "Pet", { "unitFrames.showPet" })
	registerSquareMovers(
		self,
		target.targetOfTarget,
		"targetOfTarget",
		"Target of target",
		{ "unitFrames.showTargetOfTarget" }
	)
	registerSquareMovers(self, focus.targetOfTarget, "focusTarget", "Target of focus", { "unitFrames.showFocusTarget" })
	self:RegisterMover(castbar, "unitFrames.playerCastbar", "Player castbar", {
		resize = frameResize("playerCastbarWidth", "playerCastbarHeight", 60, 10),
	})
	self:RegisterMover(player.buffs, "unitFrames.playerAuras", "Player buffs", { size = playerAuraSize(player.buffs) })
	self:RegisterMover(player.debuffs, "unitFrames.playerDebuffs", "Player debuffs", {
		size = playerAuraSize(player.debuffs),
		insets = playerDebuffInsets,
	})
	registerGroupMovers(self, party, "party", "Party")
	registerGroupMovers(self, arena, "arena", "Arena", "arena")
	applyPositions()
	applyGroupAnchors()
	applyFrameSizes(self)
	applyElements()

	self:WatchConfig("unitFrames", applyPositions, true)
	self:WatchConfig("unitFrames", applyGroupAnchors)
	self:WatchConfig("unitFrames", applyVisibility, true)
	self:WatchConfig("unitFrames", applySizes)
	self:WatchConfig("unitFrames", applyFrameSizes, true)
	self:WatchConfig("unitFrames", applyElements)
	self:WatchConfig("unitFrames.rightClick", self.ApplyClicks, true)
	self:WatchConfig("unitFrames.middleClick", self.ApplyClicks, true)
	self:WatchConfig("unitFrames", self.ApplyColors)
	self:WatchConfig("unitFrames", refreshMovers)
	self:WatchConfig("arenaTrinket", applyTrinkets)
	self:WatchConfig("groupCooldowns", applyTrinkets)
end
