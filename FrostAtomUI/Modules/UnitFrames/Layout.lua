local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local max = math.max

local MAX_PARTY_FRAMES = 3
local MAX_ARENA_OPPONENTS = 3
local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 4

local LOSE_CONTROL_FONT_SCALE = 0.32
local RESIZE_KEYS = { powerRatio = true, groupDebuffSize = true, partyBuffSize = true }

local ARENA_COOLDOWN_SKIP = {
	[42292] = true, -- PvP Trinket
	[59752] = true, -- Every Man for Himself
	[7744] = true, -- Will of the Forsaken
}

local player, castbar, pet, target, focus
local party, arena, bosses = {}, {}, {}
local partyPets, arenaPets = {}, {}

local function setGroupPoints(frames, path, spacing)
	for i = 1, #frames do
		ns.ApplyPoint(frames[i], path, (i - 1) * spacing)
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
	setGroupPoints(party, "unitFrames.party", config.groupSpacing)
	setGroupPoints(arena, "unitFrames.arena", config.groupSpacing)
	setGroupPoints(bosses, "unitFrames.boss", config.bossSpacing)
end

local function applySizes()
	local config = ns.Config.unitFrames
	for i = 1, #party do
		party[i].cooldowns:SetIconSize(config.partyCooldownSize)
	end
	local trinketConfig = ns.Config.arenaTrinket
	for i = 1, #arena do
		arena[i].cooldowns:SetIconSize(config.arenaCooldownSize)
		local trinket = arena[i].trinket
		trinket:SetIconSize(trinketConfig.size)
		if trinketConfig.enabled then
			trinket:Show()
		else
			trinket:Hide()
		end
	end
	castbar:SetSize(config.playerCastbarWidth, config.playerCastbarHeight)
	castbar.icon:SetSize(config.playerCastbarHeight, config.playerCastbarHeight)
	player.buffs:SetIconSize(config.playerAuraSize)
	player.debuffs:SetIconSize(config.playerAuraSize)
	player.debuffs:SetPoint("TOPRIGHT", player.buffs, "BOTTOMRIGHT", 0, -config.playerAuraSize * 0.2)
end

local function resizeGroupFrame(frame, groupPet, width, height)
	local config = ns.Config.unitFrames
	frame:SetFrameSize(width, height)
	frame.debuffs:SetLayout(width, config.groupDebuffSize)
	if frame.buffs then
		frame.buffs:SetLayout(width, config.partyBuffSize)
	end
	frame.castbar:SetSize(width * 0.8, height)
	frame.castbar.icon:SetSize(height, height)
	groupPet:SetFrameSize(height, height)
end

local function anchorGroupGrids(frame)
	local gap = ns.Config.unitFrames.gridGap
	local debuffs, cooldowns, buffs = frame.debuffs, frame.cooldowns, frame.buffs
	debuffs:ClearAllPoints()
	cooldowns:ClearAllPoints()
	if frame.iconSide == "LEFT" then
		debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -gap)
		cooldowns:SetPoint("TOPLEFT", debuffs, "TOPRIGHT", gap, 0)
	else
		debuffs:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -gap)
		cooldowns:SetPoint("TOPRIGHT", debuffs, "TOPLEFT", -gap, 0)
	end
	if buffs then
		buffs:ClearAllPoints()
		buffs:SetPoint("TOPLEFT", debuffs, "BOTTOMLEFT", 0, -gap)
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
		resizeGroupFrame(party[i], partyPets[i], config.partyWidth, config.partyHeight)
	end
	for i = 1, #arena do
		resizeGroupFrame(arena[i], arenaPets[i], config.arenaWidth, config.arenaHeight)
	end
	for i = 1, #bosses do
		local boss = bosses[i]
		boss:SetFrameSize(config.bossWidth, config.bossHeight)
		boss.castbar:SetSize(config.bossWidth - config.bossHeight * 0.5 - 2, config.bossHeight * 0.5)
		boss.castbar.icon:SetSize(config.bossHeight * 0.5, config.bossHeight * 0.5)
	end
end

local function setGroupWatched(frames, watched)
	for i = 1, #frames do
		frames[i]:SetWatched(watched)
	end
end

local function setGroupCooldowns(frames, shown)
	for i = 1, #frames do
		local cooldowns = frames[i].cooldowns
		if shown then
			cooldowns:Show()
		else
			cooldowns:Hide()
		end
	end
end

local function applyVisibility()
	local config = ns.Config.unitFrames
	pet:SetWatched(config.showPet)
	setGroupWatched(party, config.showParty)
	setGroupWatched(partyPets, config.showParty and config.showPet)
	setGroupWatched(arena, config.showArena)
	setGroupWatched(arenaPets, config.showArena and config.showPet)
	setGroupWatched(bosses, config.showBoss)
	setGroupCooldowns(party, config.showPartyCooldowns)
	setGroupCooldowns(arena, config.showArenaCooldowns)
end

local function setLoseControlSize(loseControl, size)
	loseControl:SetSize(size, size)
	ns.SetFont(loseControl.timer, size * LOSE_CONTROL_FONT_SCALE, "OUTLINE")
end

local function applyElements()
	local config = ns.Config.unitFrames
	setLoseControlSize(player.losecontrol, config.loseControlSize)
	ns.ApplyPoint(player.losecontrol, "unitFrames.loseControlPoint")
	target.combopoints:SetPointSize(config.comboPointSize)
	for i = 1, #party do
		anchorGroupGrids(party[i])
		party[i].debuffs:SetLimit(config.groupDebuffMax)
		party[i].buffs:SetLimit(config.partyBuffMax)
	end
	for i = 1, #arena do
		anchorGroupGrids(arena[i])
		arena[i].debuffs:SetLimit(config.groupDebuffMax)
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

local function createPlayer(self, config)
	player = self:CreateRectangle("player", config.playerWidth, config.playerHeight, "LEFT")
	ns.ApplyPoint(player, "unitFrames.player")

	local leader = self:AddElement(player, "leader")
	leader:SetPoint("TOPRIGHT", player.classicon, -1, -1)

	local auraOptions = { size = config.playerAuraSize, gap = 2, anchor = "TOPRIGHT" }
	local buffs = self:AddElement(player, "buffs", auraOptions)
	ns.ApplyPoint(buffs, "unitFrames.playerAuras")

	local debuffs = self:AddElement(player, "debuffs", auraOptions)
	debuffs:SetPoint("TOPRIGHT", buffs, "BOTTOMRIGHT", 0, -config.playerAuraSize * 0.2)

	castbar = self:AddElement(player, "castbar")
	castbar:SetSize(config.playerCastbarWidth, config.playerCastbarHeight)
	ns.ApplyPoint(castbar, "unitFrames.playerCastbar")
	castbar.icon:SetSize(config.playerCastbarHeight, config.playerCastbarHeight)

	local loseControl = self:AddElement(player, "losecontrol")
	setLoseControlSize(loseControl, config.loseControlSize)
	ns.ApplyPoint(loseControl, "unitFrames.loseControlPoint")

	local raidIcon = self:AddElement(player, "raidicon")
	raidIcon:SetPoint("BOTTOM", player, "TOP", 0, -4)

	local resting = self:AddElement(player, "resting")
	resting:SetPoint("CENTER", player, "TOPRIGHT", -8, 0)

	local pvp = self:AddElement(player, "pvp")
	pvp:SetPoint("CENTER", player, "BOTTOMRIGHT", -8, 0)

	self:AddElement(player, "dispel")

	pet = self:CreatePet("pet", config.playerHeight)
	ns.ApplyPoint(pet, "unitFrames.pet")

	return player
end

local function createTargets(self, player, config)
	local targetOfTarget
	target, targetOfTarget = self:CreateTarget("target", config.playerWidth, config.playerHeight)
	ns.ApplyPoint(target, "unitFrames.target")
	ns.ApplyPoint(targetOfTarget, "unitFrames.targetOfTarget")
	target:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")
	targetOfTarget:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")

	local combo = self:AddElement(target, "combopoints", { gap = 2 })
	combo:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 2, 2)

	local focusTarget
	focus, focusTarget = self:CreateTarget("focus", config.playerWidth, config.playerHeight)
	ns.ApplyPoint(focus, "unitFrames.focus")
	ns.ApplyPoint(focusTarget, "unitFrames.focusTarget")
	focus:RegisterEvent("PLAYER_FOCUS_CHANGED", "QueueUpdate")
	focusTarget:RegisterEvent("PLAYER_FOCUS_CHANGED", "QueueUpdate")

	local function addTargetElements(frame)
		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, -4)

		local pvp = self:AddElement(frame, "pvp")
		pvp:SetPoint("CENTER", frame, "BOTTOMRIGHT", -8, 0)

		self:AddElement(frame, "dispel")
	end
	addTargetElements(target)
	addTargetElements(focus)
end

local function createParty(self, config)
	local point, x, y = unpack(config.party)
	local width, height = config.partyWidth, config.partyHeight
	local debuffOptions = { size = config.groupDebuffSize, width = width, max = config.groupDebuffMax, minRows = 1 }
	local buffOptions = { size = config.partyBuffSize, width = width, max = config.partyBuffMax }

	for i = 1, MAX_PARTY_FRAMES do
		local unit = "party" .. i
		local frame = self:CreateRectangle(unit, width, height, "LEFT")
		party[i] = frame
		frame:SetPoint(point, x, y - (i - 1) * config.groupSpacing)
		frame:RegisterEvent("PARTY_MEMBERS_CHANGED", "QueueUpdate")

		local leader = self:AddElement(frame, "leader")
		leader:SetPoint("TOPRIGHT", frame.classicon, -1, -1)

		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, -4)

		self:AddElement(frame, "debuffs", debuffOptions)
		self:AddElement(frame, "cooldowns", { size = config.partyCooldownSize })
		self:AddElement(frame, "buffs", buffOptions)
		anchorGroupGrids(frame)

		self:CreateSideCastbar(frame, "RIGHT", width * 0.8, height)

		self:AddElement(frame, "losecontrol")

		self:AddElement(frame, "range")
		self:AddElement(frame, "dispel")
		self:AddElement(frame, "highlight")

		local pet = self:CreatePet("partypet" .. i, height)
		pet:SetPoint("RIGHT", frame, "LEFT", -2, 0)
		pet:RegisterEvent("PARTY_MEMBERS_CHANGED", "QueueUpdate")
		partyPets[i] = pet
	end
end

local function createArena(self, config)
	local point, x, y = unpack(config.arena)
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
		local frame = self:CreateRectangle("arena" .. i, width, height, "RIGHT")
		arena[i] = frame
		frame:SetPoint(point, x, y - (i - 1) * config.groupSpacing)

		self:AddElement(frame, "debuffs", debuffOptions)

		self:CreateSideCastbar(frame, "LEFT", width * 0.8, height)

		self:AddElement(frame, "losecontrol")

		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, -4)

		self:AddElement(frame, "range")
		self:AddElement(frame, "highlight")

		local pet = self:CreatePet("arenapet" .. i, height)
		pet:SetPoint("LEFT", frame, "RIGHT", 2, 0)
		arenaPets[i] = pet

		local trinket = self:AddElement(frame, "trinket", { size = trinketSize })
		trinket:SetPoint("LEFT", pet, "RIGHT", 2, 0)

		self:AddElement(
			frame,
			"cooldowns",
			{ size = config.arenaCooldownSize, skip = ARENA_COOLDOWN_SKIP, anchor = "TOPRIGHT" }
		)
		anchorGroupGrids(frame)
	end
end

local function createBosses(self, config)
	local point, x, y = unpack(config.boss)

	for i = 1, MAX_BOSS_FRAMES do
		local unit = "boss" .. i
		local frame = self:CreateRectangle(unit, config.bossWidth, config.bossHeight)
		bosses[i] = frame
		frame:SetPoint(point, x, y - (i - 1) * config.bossSpacing)
		frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "QueueUpdate")

		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("RIGHT", frame, "LEFT", -4, 0)

		local castbar = self:AddElement(frame, "castbar")
		castbar:SetSize(config.bossWidth - config.bossHeight * 0.5 - 2, config.bossHeight * 0.5)
		castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
		castbar.icon:SetSize(config.bossHeight * 0.5, config.bossHeight * 0.5)
	end
end

function UF:Initialize()
	local config = ns.Config.unitFrames

	self:HideBlizzard()
	createTargets(self, createPlayer(self, config), config)
	createParty(self, config)
	createArena(self, config)
	createBosses(self, config)
	applyVisibility()

	local playerResize = frameResize("playerWidth", "playerHeight", 80, 20)
	self:RegisterMover(player, "unitFrames.player", "Player", { secure = true, resize = playerResize })
	self:RegisterMover(target, "unitFrames.target", "Target", { secure = true, resize = playerResize })
	self:RegisterMover(focus, "unitFrames.focus", "Focus", { secure = true, resize = playerResize })
	self:RegisterMover(pet, "unitFrames.pet", "Pet", { secure = true })
	self:RegisterMover(target.targetOfTarget, "unitFrames.targetOfTarget", "Target of target", { secure = true })
	self:RegisterMover(focus.targetOfTarget, "unitFrames.focusTarget", "Target of focus", { secure = true })
	self:RegisterMover(castbar, "unitFrames.playerCastbar", "Player castbar", {
		resize = frameResize("playerCastbarWidth", "playerCastbarHeight", 60, 10),
	})
	self:RegisterMover(player.buffs, "unitFrames.playerAuras", "Player auras", {
		size = function()
			local buffs, debuffs = player.buffs, player.debuffs
			local size = ns.Config.unitFrames.playerAuraSize
			local rows = max(buffs.rows, 1) + max(debuffs.rows, 1)
			return buffs:GetWidth(), rows * (size + buffs.gap) - buffs.gap + size * 0.2
		end,
	})
	self:RegisterMover(party[1], "unitFrames.party", "Party", {
		secure = true,
		resize = frameResize("partyWidth", "partyHeight", 80, 20),
	})
	self:RegisterMover(arena[1], "unitFrames.arena", "Arena", {
		secure = true,
		resize = frameResize("arenaWidth", "arenaHeight", 80, 20),
	})
	self:RegisterMover(bosses[1], "unitFrames.boss", "Boss", {
		secure = true,
		resize = frameResize("bossWidth", "bossHeight", 80, 20),
	})
	self:RegisterMover(player.losecontrol, "unitFrames.loseControlPoint", "Lose control", {
		size = function()
			local size = ns.Config.unitFrames.loseControlSize
			return size, size
		end,
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
	self:WatchConfig("arenaTrinket", applySizes)
end
