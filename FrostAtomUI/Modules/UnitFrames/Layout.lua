local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local MAX_PARTY_FRAMES = 3
local MAX_ARENA_OPPONENTS = 3
local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 4

local GRID_GAP = 6
local GROUP_DEBUFF_SIZE = 32
local GROUP_BUFF_SIZE = 19

local ARENA_COOLDOWN_SKIP = {
	[42292] = true, -- PvP Trinket
	[59752] = true, -- Every Man for Himself
	[7744] = true, -- Will of the Forsaken
}

local player, castbar, pet, target, focus
local party, arena, bosses = {}, {}, {}
local partyPets, arenaPets = {}, {}

local function setPoint(frame, position, offset)
	local point, x, y = unpack(position)
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, point, x, y - (offset or 0))
end

local function setGroupPoints(frames, position, spacing)
	for i = 1, #frames do
		setPoint(frames[i], position, (i - 1) * spacing)
	end
end

local function setCastbarPoint(position)
	local point, x, y = unpack(position)
	castbar:ClearAllPoints()
	castbar:SetPoint(point, FrostAtomUIPlayerPlate, "BOTTOM", x, y)
end

local function applyPositions()
	local config = ns.Config.unitFrames
	setPoint(player, config.player)
	setPoint(target, config.target)
	setPoint(focus, config.focus)
	setPoint(player.buffs, config.playerAuras)
	setCastbarPoint(config.playerCastbar)
	setGroupPoints(party, config.party, config.groupSpacing)
	setGroupPoints(arena, config.arena, config.groupSpacing)
	setGroupPoints(bosses, config.boss, config.bossSpacing)
end

local function applySizes()
	local config = ns.Config.unitFrames
	for i = 1, #party do
		party[i].cooldowns:SetIconSize(config.partyCooldownSize)
	end
	for i = 1, #arena do
		arena[i].cooldowns:SetIconSize(config.arenaCooldownSize)
		arena[i].trinket:SetIconSize(ns.Config.arenaTrinket.size)
	end
	castbar:SetSize(config.playerCastbarWidth, config.playerCastbarHeight)
	castbar.icon:SetSize(config.playerCastbarHeight, config.playerCastbarHeight)
	player.buffs:SetIconSize(config.playerAuraSize)
	player.debuffs:SetIconSize(config.playerAuraSize)
	player.debuffs:SetPoint("TOPRIGHT", player.buffs, "BOTTOMRIGHT", 0, -config.playerAuraSize * 0.2)
end

local function resizeGroupFrame(frame, groupPet, width, height)
	frame:SetFrameSize(width, height)
	frame.debuffs:SetLayout(width, GROUP_DEBUFF_SIZE)
	if frame.buffs then
		frame.buffs:SetLayout(width, GROUP_BUFF_SIZE)
	end
	frame.castbar:SetSize(width * 0.8, height)
	frame.castbar.icon:SetSize(height, height)
	groupPet:SetFrameSize(height, height)
end

local function applyFrameSizes(self, path)
	if path and not (path:find("Width$") or path:find("Height$")) then
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
	setGroupWatched(party, config.showParty)
	setGroupWatched(partyPets, config.showParty)
	setGroupWatched(arena, config.showArena)
	setGroupWatched(arenaPets, config.showArena)
	setGroupWatched(bosses, config.showBoss)
	setGroupCooldowns(party, config.showPartyCooldowns)
	setGroupCooldowns(arena, config.showArenaCooldowns)
end

local function targetMoverOptions(frame)
	return {
		secure = true,
		extendTo = frame.targetOfTarget,
		size = function()
			return frame:GetWidth() + UF.TARGET_OF_TARGET_GAP + frame.targetOfTarget:GetWidth(), frame:GetHeight()
		end,
	}
end

local function createPlayer(self, config)
	player = self:CreateRectangle("player", config.playerWidth, config.playerHeight, "LEFT")
	player:SetPoint(unpack(config.player))

	local leader = self:AddElement(player, "leader")
	leader:SetPoint("TOPRIGHT", player.classicon, -1, -1)

	local auraOptions = { size = config.playerAuraSize, gap = 2, anchor = "TOPRIGHT" }
	local buffs = self:AddElement(player, "buffs", auraOptions)
	setPoint(buffs, config.playerAuras)

	local debuffs = self:AddElement(player, "debuffs", auraOptions)
	debuffs:SetPoint("TOPRIGHT", buffs, "BOTTOMRIGHT", 0, -config.playerAuraSize * 0.2)

	castbar = self:AddElement(player, "castbar")
	castbar:SetSize(config.playerCastbarWidth, config.playerCastbarHeight)
	setCastbarPoint(config.playerCastbar)
	castbar.icon:SetSize(config.playerCastbarHeight, config.playerCastbarHeight)

	local loseControl = self:AddElement(player, "losecontrol")
	loseControl:ClearAllPoints()
	loseControl:SetSize(32, 32)
	loseControl:SetPoint("CENTER", UIParent)

	local raidIcon = self:AddElement(player, "raidicon")
	raidIcon:SetPoint("BOTTOM", player, "TOP", 0, -4)

	local resting = self:AddElement(player, "resting")
	resting:SetPoint("CENTER", player, "TOPRIGHT", -8, 0)

	local pvp = self:AddElement(player, "pvp")
	pvp:SetPoint("CENTER", player, "BOTTOMRIGHT", -8, 0)

	self:AddElement(player, "dispel")

	pet = self:CreatePet("pet", config.playerHeight)
	pet:SetPoint("RIGHT", player, "LEFT", -2, 0)

	return player
end

local function createTargets(self, player, config)
	local targetOfTarget
	target, targetOfTarget = self:CreateTarget("target", config.playerWidth, config.playerHeight)
	target:SetPoint(unpack(config.target))
	target:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")
	targetOfTarget:RegisterEvent("PLAYER_TARGET_CHANGED", "QueueUpdate")

	local combo = self:AddElement(target, "combopoints", { size = 8, gap = 2 })
	combo:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 2, 2)

	local focusTarget
	focus, focusTarget = self:CreateTarget("focus", config.playerWidth, config.playerHeight)
	focus:SetPoint(unpack(config.focus))
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
	local debuffOptions = { size = GROUP_DEBUFF_SIZE, width = width, max = 12, minRows = 1 }
	local buffOptions = { size = GROUP_BUFF_SIZE, width = width, max = 18 }

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

		local debuffs = self:AddElement(frame, "debuffs", debuffOptions)
		debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -GRID_GAP)

		local cooldowns = self:AddElement(frame, "cooldowns", { size = config.partyCooldownSize })
		cooldowns:SetPoint("TOPLEFT", debuffs, "TOPRIGHT", GRID_GAP, 0)

		local buffs = self:AddElement(frame, "buffs", buffOptions)
		buffs:SetPoint("TOPLEFT", debuffs, "BOTTOMLEFT", 0, -GRID_GAP)

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
	local debuffOptions = { size = GROUP_DEBUFF_SIZE, width = width, max = 12, minRows = 1, anchor = "TOPRIGHT" }

	for i = 1, MAX_ARENA_OPPONENTS do
		local frame = self:CreateRectangle("arena" .. i, width, height, "RIGHT")
		arena[i] = frame
		frame:SetPoint(point, x, y - (i - 1) * config.groupSpacing)

		local debuffs = self:AddElement(frame, "debuffs", debuffOptions)
		debuffs:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -GRID_GAP)

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

		local cooldowns = self:AddElement(
			frame,
			"cooldowns",
			{ size = config.arenaCooldownSize, skip = ARENA_COOLDOWN_SKIP, anchor = "TOPRIGHT" }
		)
		cooldowns:SetPoint("TOPRIGHT", debuffs, "TOPLEFT", -GRID_GAP, 0)
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

	self:RegisterMover(player, "unitFrames.player", "Player", { secure = true })
	self:RegisterMover(target, "unitFrames.target", "Target", targetMoverOptions(target))
	self:RegisterMover(focus, "unitFrames.focus", "Focus", targetMoverOptions(focus))
	self:RegisterMover(castbar, "unitFrames.playerCastbar", "Player castbar", {
		relativeTo = FrostAtomUIPlayerPlate,
		relativePoint = "BOTTOM",
	})
	self:RegisterMover(player.buffs, "unitFrames.playerAuras", "Player auras", {
		size = function()
			return player.buffs:GetWidth(), ns.Config.unitFrames.playerAuraSize
		end,
	})
	self:RegisterMover(party[1], "unitFrames.party", "Party", { secure = true })
	self:RegisterMover(arena[1], "unitFrames.arena", "Arena", { secure = true })
	self:RegisterMover(bosses[1], "unitFrames.boss", "Boss", { secure = true })

	self:WatchConfig("unitFrames", applyPositions, true)
	self:WatchConfig("unitFrames", applyVisibility, true)
	self:WatchConfig("unitFrames", applySizes)
	self:WatchConfig("unitFrames", applyFrameSizes, true)
	self:WatchConfig("unitFrames", self.ApplyColors)
	self:WatchConfig("arenaTrinket", applySizes)
end
