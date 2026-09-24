local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local max, ceil = math.max, math.ceil

local MAX_PARTY_FRAMES = MAX_PARTY_MEMBERS or 4
local MAX_ARENA_OPPONENTS = 3
local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 4

local PLAYER_DEBUFF_GAP_SCALE = 0.2
local BOSS_CASTBAR_SCALE = 0.5
local BOSS_CASTBAR_ICON_GAP = 2
local RESIZE_KEYS = {
	powerRatio = true,
	groupDebuffSize = true,
	partyBuffSize = true,
	targetAuraPerRow = true,
	ownAuraScale = true,
}
local AURA_GROWTH_ANCHORS = { LEFT = "TOPRIGHT", RIGHT = "TOPLEFT" }

local player, castbar, pet, target, focus
local party, arena, bosses = {}, {}, {}
local partyPets, arenaPets = {}, {}

local function groupFramePath(prefix, index)
	return "unitFrames." .. (index == 1 and prefix or prefix .. index)
end

local function groupCastbarPath(prefix, index)
	return "unitFrames." .. prefix .. index .. "Castbar"
end

local function setGroupPoints(frames)
	for i = 1, #frames do
		local frame = frames[i]
		ns.ApplyPoint(frame, frame.moverPath)
		ns.ApplyPoint(frame.castbar, frame.castbar.moverPath)
	end
end

local function applyPositions()
	local config = ns.Config.unitFrames
	ns.ApplyPoint(player, "unitFrames.player")
	ns.ApplyPoint(target, "unitFrames.target")
	ns.ApplyPoint(focus, "unitFrames.focus")
	ns.ApplyPoint(pet, "unitFrames.pet")
	ns.ApplyPoint(target.targetOfTarget, "unitFrames.targetOfTarget")
	ns.ApplyPoint(focus.targetOfTarget, "unitFrames.focusTarget")
	ns.ApplyPoint(player.buffs, "unitFrames.playerAuras")
	ns.ApplyPoint(castbar, "unitFrames.playerCastbar")
	ns.ApplyPoint(target.castbar, "unitFrames.targetCastbar")
	ns.ApplyPoint(focus.castbar, "unitFrames.focusCastbar")
	setGroupPoints(party)
	setGroupPoints(arena)
	for i = 1, #bosses do
		ns.ApplyPoint(bosses[i], "unitFrames.boss", (i - 1) * config.bossSpacing)
	end
end

local function gridCapacity(grid)
	local rows = max(ceil(grid.limit / grid.perRow), grid.minRows)
	if rows == 0 then
		return 0
	end
	local size = grid.RowSize and grid:RowSize() or grid.size
	return rows * (size + grid.gap) - grid.gap
end

local function auraInsets(frame, fixedGap)
	return function()
		local gap = fixedGap or ns.Config.unitFrames.gridGap
		local height = 0
		for _, grid in ipairs({ frame.debuffs, frame.buffs }) do
			local capacity = gridCapacity(grid)
			if capacity > 0 then
				height = height + gap + capacity
			end
		end
		return 0, 0, 0, height
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

local function playerAuraAnchor(config)
	return AURA_GROWTH_ANCHORS[config.playerAuraGrowth] or "TOPRIGHT"
end

local function anchorPlayerDebuffs(config)
	local anchor = playerAuraAnchor(config)
	local debuffs = player.debuffs
	debuffs:ClearAllPoints()
	debuffs:SetPoint(
		anchor,
		player.buffs,
		anchor:gsub("^TOP", "BOTTOM"),
		0,
		-config.playerAuraSize * PLAYER_DEBUFF_GAP_SCALE
	)
end

local function sizePlayerCastbar(config)
	UF.SetCastbarSize(castbar, config.playerCastbarWidth, config.playerCastbarHeight)
end

local function sizeBossCastbar(boss, config)
	local height = config.bossHeight * BOSS_CASTBAR_SCALE
	UF.SetCastbarSize(boss.castbar, config.bossWidth - height - BOSS_CASTBAR_ICON_GAP, height)
end

local function applySizes()
	local config = ns.Config.unitFrames
	local trinketSize = ns.Config.arenaTrinket.size
	for _, frames in ipairs({ party, arena }) do
		for i = 1, #frames do
			local trinket = frames[i].trinket
			trinket:SetIconSize(trinketSize)
			trinket:Refresh()
		end
	end
	sizePlayerCastbar(config)
	local auraAnchor = playerAuraAnchor(config)
	player.buffs:SetShape(config.playerAuraPerRow, auraAnchor)
	player.debuffs:SetShape(config.playerDebuffPerRow, auraAnchor)
	player.buffs:SetIconSize(config.playerAuraSize)
	player.debuffs:SetIconSize(config.playerDebuffSize)
	anchorPlayerDebuffs(config)
end

local function resizeGroupFrame(frame, groupPet, prefix)
	local config = ns.Config.unitFrames
	local width, height = config[prefix .. "Width"], config[prefix .. "Height"]
	frame:SetFrameSize(width, height)
	frame.debuffs:SetLayout(width, config.groupDebuffSize)
	if frame.buffs then
		frame.buffs:SetLayout(width, config.partyBuffSize)
	end
	UF.SetCastbarSize(frame.castbar, config[prefix .. "CastbarWidth"], config[prefix .. "CastbarHeight"])
	groupPet:SetFrameSize(height, height)
end

local function anchorGroupGrids(frame, point)
	UF.StackAuraGrids(frame, point, ns.Config.unitFrames.gridGap)
end

local function setGroupIconSide(frames, side)
	for i = 1, #frames do
		frames[i]:SetIconSide(side)
	end
end

local function applyFrameSizes(self, path)
	if path and not (path:find("Width$") or path:find("Height$") or RESIZE_KEYS[path:match("[^.]+$")]) then
		return
	end
	local config = ns.Config.unitFrames
	player:SetFrameSize(config.playerWidth, config.playerHeight)
	pet:SetFrameSize(config.playerHeight, config.playerHeight)
	self:ResizeTarget(target, config.playerWidth, config.playerHeight)
	self:ResizeTarget(focus, config.playerWidth, config.playerHeight)
	for i = 1, #party do
		resizeGroupFrame(party[i], partyPets[i], "party")
	end
	for i = 1, #arena do
		resizeGroupFrame(arena[i], arenaPets[i], "arena")
	end
	for i = 1, #bosses do
		local boss = bosses[i]
		boss:SetFrameSize(config.bossWidth, config.bossHeight)
		sizeBossCastbar(boss, config)
	end
end

local function setGroupWatched(frames, watched)
	for i = 1, #frames do
		frames[i]:SetWatched(watched)
	end
end

local function applyVisibility()
	local config = ns.Config.unitFrames
	pet:SetWatched(config.showPet)
	target.targetOfTarget:SetWatched(config.showTargetOfTarget)
	focus.targetOfTarget:SetWatched(config.showFocusTarget)
	setGroupWatched(party, config.showParty)
	setGroupWatched(partyPets, config.showParty and config.showPet)
	setGroupWatched(arena, config.showArena)
	setGroupWatched(arenaPets, config.showArena and config.showPet)
	setGroupWatched(bosses, config.showBoss)
end

local function applyElements()
	local config = ns.Config.unitFrames
	target.combopoints:SetPointSize(config.comboPointSize)
	UF.SetCastbarShown(castbar, config.showPlayerCastbar)
	UF.SetCastbarShown(target.castbar, config.showTargetCastbar)
	UF.SetCastbarShown(focus.castbar, config.showFocusCastbar)
	UF.StackAuraGrids(target, "TOPLEFT", UF.CASTBAR_GAP)
	UF.StackAuraGrids(focus, "TOPLEFT", UF.CASTBAR_GAP)
	player:SetIconSide(config.playerIconSide)
	target:SetIconSide(config.targetIconSide)
	focus:SetIconSide(config.focusIconSide)
	setGroupIconSide(party, config.partyIconSide)
	setGroupIconSide(arena, config.arenaIconSide)
	UF.SetPetPowerShown(pet, config.petPower)
	for i = 1, #partyPets do
		UF.SetPetPowerShown(partyPets[i], config.petPower)
	end
	for i = 1, #arenaPets do
		UF.SetPetPowerShown(arenaPets[i], config.petPower)
	end
	for i = 1, #party do
		anchorGroupGrids(party[i], "TOPLEFT")
		party[i].debuffs:SetLimit(config.groupDebuffMax)
		party[i].buffs:SetLimit(config.partyBuffMax)
		UF.SetCastbarShown(party[i].castbar, config.showPartyCastbar)
	end
	for i = 1, #arena do
		anchorGroupGrids(arena[i], "TOPRIGHT")
		arena[i].debuffs:SetLimit(config.groupDebuffMax)
		UF.SetCastbarShown(arena[i].castbar, config.showArenaCastbar)
	end
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

local function createPlayer(self, config)
	player = self:CreateRectangle("player", config.playerWidth, config.playerHeight, config.playerIconSide)
	ns.ApplyPoint(player, "unitFrames.player")

	addLeader(self, player)

	local auraAnchor = playerAuraAnchor(config)
	local buffs = self:AddElement(player, "buffs", {
		size = config.playerAuraSize,
		gap = 2,
		perRow = config.playerAuraPerRow,
		anchor = auraAnchor,
	})
	ns.ApplyPoint(buffs, "unitFrames.playerAuras")

	self:AddElement(player, "debuffs", {
		size = config.playerDebuffSize,
		gap = 2,
		perRow = config.playerDebuffPerRow,
		anchor = auraAnchor,
	})
	anchorPlayerDebuffs(config)

	castbar = self:AddElement(player, "castbar")
	sizePlayerCastbar(config)
	ns.ApplyPoint(castbar, "unitFrames.playerCastbar")

	addRaidIconAbove(self, player)

	local resting = self:AddElement(player, "resting")
	resting:SetPoint("CENTER", player, "TOPRIGHT", -8, 0)

	addPvp(self, player)

	self:AddElement(player, "dispel")
	self:AddElement(player, "combatglow")
	if ns.PLAYER_CLASS == "DRUID" then
		self:AddElement(player, "druidmana")
	end
	self:AddElement(player, "procs")
	player:EnableVehicleSwap("player", "vehicle", { buffs = true, debuffs = true, pvp = true, procs = true })

	pet = self:CreatePet("pet", config.playerHeight)
	ns.ApplyPoint(pet, "unitFrames.pet")
	local happiness = self:AddElement(pet, "happiness")
	happiness:SetPoint("TOPLEFT", pet.health, 1, -1)
end

local function createTargets(self, config)
	local targetOfTarget
	target, targetOfTarget = self:CreateTarget("target", config.playerWidth, config.playerHeight)
	ns.ApplyPoint(target, "unitFrames.target")
	ns.ApplyPoint(targetOfTarget, "unitFrames.targetOfTarget")
	target:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")
	targetOfTarget:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")
	self:AddElement(targetOfTarget, "hideself")

	local combo = self:AddElement(target, "combopoints", { gap = 2 })
	combo:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 2, 2)

	local focusTarget
	focus, focusTarget = self:CreateTarget("focus", config.playerWidth, config.playerHeight)
	ns.ApplyPoint(focus, "unitFrames.focus")
	ns.ApplyPoint(focusTarget, "unitFrames.focusTarget")
	focus:RegisterEvent("PLAYER_FOCUS_CHANGED", "QueueUpdate")
	focusTarget:RegisterEvent("PLAYER_FOCUS_CHANGED", "QueueUpdate")

	for _, frame in ipairs({ target, focus }) do
		addRaidIconAbove(self, frame)
		addPvp(self, frame)
		self:AddElement(frame, "dispel")
		self:AddElement(frame, "diminish")
		self:AddElement(frame, "procs")
	end
end

local function createParty(self, config)
	local width, height = config.partyWidth, config.partyHeight
	local debuffOptions = { size = config.groupDebuffSize, width = width, max = config.groupDebuffMax, minRows = 1 }
	local buffOptions = { size = config.partyBuffSize, width = width, max = config.partyBuffMax }

	for i = 1, MAX_PARTY_FRAMES do
		local frame = self:CreateRectangle("party" .. i, width, height, config.partyIconSide)
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
		anchorGroupGrids(frame, "TOPLEFT")

		local partyCastbar = self:CreateSideCastbar(frame, "RIGHT", config.partyCastbarWidth, config.partyCastbarHeight)
		partyCastbar.moverPath = groupCastbarPath("party", i)
		self:AddElement(frame, "procs")

		self:AddElement(frame, "losecontrol")

		self:AddElement(frame, "range")
		self:AddElement(frame, "dispel")
		self:AddElement(frame, "highlight")

		local pet = self:CreatePet("partypet" .. i, height)
		pet:SetPoint("RIGHT", frame, "LEFT", -2, 0)
		pet:RegisterEvent("PARTY_MEMBERS_CHANGED", "QueueUpdate")
		partyPets[i] = pet

		local trinket = self:AddElement(frame, "trinket", { size = ns.Config.arenaTrinket.size, arenaOnly = true })
		trinket:SetPoint("RIGHT", pet, "LEFT", -2, 0)
	end
end

local function createArena(self, config)
	local trinketSize = ns.Config.arenaTrinket.size
	local width, height = config.arenaWidth, config.arenaHeight
	local debuffOptions = {
		size = config.groupDebuffSize,
		width = width,
		max = config.groupDebuffMax,
		minRows = 1,
		anchor = "TOPRIGHT",
	}

	for i = 1, MAX_ARENA_OPPONENTS do
		local frame = self:CreateRectangle("arena" .. i, width, height, config.arenaIconSide)
		arena[i] = frame
		frame.moverPath = groupFramePath("arena", i)

		self:AddElement(frame, "debuffs", debuffOptions)

		local arenaCastbar = self:CreateSideCastbar(frame, "LEFT", config.arenaCastbarWidth, config.arenaCastbarHeight)
		arenaCastbar.moverPath = groupCastbarPath("arena", i)

		self:AddElement(frame, "losecontrol")

		addRaidIconAbove(self, frame)

		self:AddElement(frame, "range")
		self:AddElement(frame, "highlight")

		local pet = self:CreatePet("arenapet" .. i, height)
		pet:SetPoint("LEFT", frame, "RIGHT", 2, 0)
		arenaPets[i] = pet

		local trinket = self:AddElement(frame, "trinket", { size = trinketSize })
		trinket:SetPoint("LEFT", pet, "RIGHT", 2, 0)

		self:AddElement(frame, "diminish")
		self:AddElement(frame, "procs")
		anchorGroupGrids(frame, "TOPRIGHT")
	end
end

local function createBosses(self, config)
	local point, x, y = unpack(config.boss)

	for i = 1, MAX_BOSS_FRAMES do
		local frame = self:CreateRectangle("boss" .. i, config.bossWidth, config.bossHeight)
		bosses[i] = frame
		frame:SetPoint(point, x, y - (i - 1) * config.bossSpacing)
		frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "QueueUpdate")

		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("RIGHT", frame, "LEFT", -4, 0)

		local bossCastbar = self:AddElement(frame, "castbar")
		sizeBossCastbar(frame, config)
		bossCastbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
	end
end

local function castbarResizer(prefix)
	return frameResize(prefix .. "CastbarWidth", prefix .. "CastbarHeight", 60, 10)
end

local function registerGroupMovers(self, frames, prefix, name)
	local shownPath = "unitFrames.show" .. name
	local castbarShownPath = "unitFrames.show" .. name .. "Castbar"
	local resize = frameResize(prefix .. "Width", prefix .. "Height", 80, 20)
	local castbarResize = castbarResizer(prefix)
	for i = 1, #frames do
		local frame = frames[i]
		self:RegisterMover(frame, frame.moverPath, name .. " " .. i, {
			secure = true,
			resize = resize,
			enabledPath = shownPath,
			insets = auraInsets(frame),
		})
		self:RegisterMover(frame.castbar, frame.castbar.moverPath, name .. " " .. i .. " castbar", {
			enabledPath = { shownPath, castbarShownPath },
			insets = castbarInsets(frame.castbar),
			resize = castbarResize,
		})
	end
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
	createBosses(self, config)
	applyVisibility()

	local playerResize = frameResize("playerWidth", "playerHeight", 80, 20)
	self:RegisterMover(player, "unitFrames.player", "Player", { secure = true, resize = playerResize })
	self:RegisterMover(target, "unitFrames.target", "Target", {
		secure = true,
		resize = playerResize,
		insets = auraInsets(target, UF.CASTBAR_GAP),
	})
	self:RegisterMover(focus, "unitFrames.focus", "Focus", {
		secure = true,
		resize = playerResize,
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
	self:RegisterMover(pet, "unitFrames.pet", "Pet", { secure = true })
	self:RegisterMover(target.targetOfTarget, "unitFrames.targetOfTarget", "Target of target", { secure = true })
	self:RegisterMover(focus.targetOfTarget, "unitFrames.focusTarget", "Target of focus", { secure = true })
	self:RegisterMover(castbar, "unitFrames.playerCastbar", "Player castbar", {
		resize = frameResize("playerCastbarWidth", "playerCastbarHeight", 60, 10),
	})
	self:RegisterMover(player.buffs, "unitFrames.playerAuras", "Player auras", {
		size = function()
			local buffs, debuffs = player.buffs, player.debuffs
			local size, gap = buffs.size, buffs.gap
			local height = max(buffs.rows, 1) * (size + gap) + max(debuffs.rows, 1) * (debuffs.size + debuffs.gap)
			return max(buffs:GetWidth(), debuffs:GetWidth()), height - debuffs.gap + size * PLAYER_DEBUFF_GAP_SCALE
		end,
	})
	registerGroupMovers(self, party, "party", "Party")
	registerGroupMovers(self, arena, "arena", "Arena")
	self:RegisterMover(bosses[1], "unitFrames.boss", "Boss", {
		secure = true,
		resize = frameResize("bossWidth", "bossHeight", 80, 20),
	})
	applyPositions()
	applyElements()

	self:WatchConfig("unitFrames", applyPositions, true)
	self:WatchConfig("unitFrames", applyVisibility, true)
	self:WatchConfig("unitFrames", applySizes)
	self:WatchConfig("unitFrames", applyFrameSizes, true)
	self:WatchConfig("unitFrames", applyElements)
	self:WatchConfig("unitFrames.rightClick", self.ApplyClicks, true)
	self:WatchConfig("unitFrames", self.ApplyColors)
	self:WatchConfig("unitFrames", refreshMovers)
	self:WatchConfig("arenaTrinket", applySizes)
end
