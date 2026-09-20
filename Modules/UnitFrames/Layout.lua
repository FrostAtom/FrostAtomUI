local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local MAX_ARENA_OPPONENTS = 3
local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 4

local PLAYER_AURA = { size = 34, gap = 2, anchor = "TOPRIGHT" }
local PARTY_WIDTH, ARENA_WIDTH = 180, 200
local PARTY_DEBUFFS = { size = 29, width = PARTY_WIDTH, max = 12, minRows = 1 }
local PARTY_BUFFS = { size = 19, width = PARTY_WIDTH, max = 18 }
local ARENA_DEBUFFS = { size = 32, width = ARENA_WIDTH, max = 12, minRows = 1, anchor = "TOPRIGHT" }
local GRID_GAP = 6

-- PvP Trinket, Every Man for Himself, Will of the Forsaken
local ARENA_COOLDOWN_SKIP = { [42292] = true, [59752] = true, [7744] = true }

local function createPlayer(self, config)
	local player = self:CreateRectangle("player", 200, 45, "LEFT")
	player:SetPoint(unpack(config.player))

	local leader = self:AddElement(player, "leader")
	leader:SetPoint("TOPLEFT", player.health, 24, 8)

	local buffs = self:AddElement(player, "buffs", PLAYER_AURA)
	buffs:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -15, 0)

	local debuffs = self:AddElement(player, "debuffs", PLAYER_AURA)
	debuffs:SetPoint("TOPRIGHT", buffs, "BOTTOMRIGHT", 0, -PLAYER_AURA.size * 0.2)

	local castbar = self:AddElement(player, "castbar")
	castbar:SetSize(240, 22)
	local point, x, y = unpack(config.playerCastbar)
	castbar:SetPoint(point, UIParent, point, x, y)
	castbar.icon:SetSize(24, 24)

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

	local pet = self:CreatePet("pet", 45)
	pet:SetPoint("RIGHT", player, "LEFT", -2, 0)

	return player
end

local function createTargets(self, player)
	local target, targetOfTarget = self:CreateTarget("target", 200, 45)
	target:SetPoint("LEFT", player, "RIGHT", 2, 0)
	target:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateAll")
	targetOfTarget:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateAll")

	local combo = self:AddElement(target, "combopoints", { size = 8, gap = 2 })
	combo:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 2, 2)

	local focus, focusTarget = self:CreateTarget("focus", 200, 45)
	focus:SetPoint("LEFT", targetOfTarget, "RIGHT", 2, 0)
	focus:RegisterEvent("PLAYER_FOCUS_CHANGED", "UpdateAll")
	focusTarget:RegisterEvent("PLAYER_FOCUS_CHANGED", "UpdateAll")

	for _, frame in ipairs({ target, focus }) do
		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, -4)

		local pvp = self:AddElement(frame, "pvp")
		pvp:SetPoint("CENTER", frame, "BOTTOMRIGHT", -8, 0)

		self:AddElement(frame, "dispel")
	end
end

local function createParty(self, config)
	local point, x, y = unpack(config.party)

	for i = 1, MAX_PARTY_MEMBERS do
		local unit = "party" .. i
		local frame = self:CreateRectangle(unit, PARTY_WIDTH, 40, "LEFT")
		frame:SetPoint(point, x, y - (i - 1) * config.groupSpacing)
		frame:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateAll")

		local leader = self:AddElement(frame, "leader")
		leader:SetPoint("TOPLEFT", frame.health, 24, 8)

		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, -4)

		local debuffs = self:AddElement(frame, "debuffs", PARTY_DEBUFFS)
		debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -GRID_GAP)

		local cooldowns = self:AddElement(frame, "cooldowns", { size = config.partyCooldownSize })
		cooldowns:SetPoint("TOPLEFT", debuffs, "TOPRIGHT", GRID_GAP, 0)

		local buffs = self:AddElement(frame, "buffs", PARTY_BUFFS)
		buffs:SetPoint("TOPLEFT", debuffs, "BOTTOMLEFT", 0, -GRID_GAP)

		local castbar = self:AddElement(frame, "castbar")
		castbar:SetSize(176, 20)
		castbar:SetPoint("BOTTOM", frame, "TOP")
		castbar.icon:SetSize(22, 22)

		self:AddElement(frame, "losecontrol")

		self:AddElement(frame, "range")
		self:AddElement(frame, "dispel")

		local pet = self:CreatePet("partypet" .. i, 40)
		pet:SetPoint("RIGHT", frame, "LEFT", -2, 0)
		pet:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateAll")
	end
end

local function createArena(self, config)
	local point, x, y = unpack(config.arena)
	local trinketSize = ns.Config.arenaTrinket.size

	for i = 1, MAX_ARENA_OPPONENTS do
		local frame = self:CreateRectangle("arena" .. i, ARENA_WIDTH, 50, "RIGHT")
		frame:SetPoint(point, x, y - (i - 1) * config.groupSpacing)

		local debuffs = self:AddElement(frame, "debuffs", ARENA_DEBUFFS)
		debuffs:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -GRID_GAP)

		local castbar = self:AddElement(frame, "castbar")
		castbar:SetSize(160, 35)
		castbar:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, -2)
		castbar.icon:SetSize(37, 37)

		self:AddElement(frame, "losecontrol")

		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, -4)

		self:AddElement(frame, "range")

		local pet = self:CreatePet("arenapet" .. i, 50)
		pet:SetPoint("LEFT", frame, "RIGHT", 2, 0)

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
		local frame = self:CreateRectangle(unit, 180, 40)
		frame:SetPoint(point, x, y - (i - 1) * config.bossSpacing)
		frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UpdateAll")

		local raidIcon = self:AddElement(frame, "raidicon")
		raidIcon:SetPoint("RIGHT", frame, "LEFT", -4, 0)

		local castbar = self:AddElement(frame, "castbar")
		castbar:SetSize(176, 16)
		castbar:SetPoint("TOP", frame, "BOTTOM", 0, -2)
		castbar.icon:SetSize(18, 18)
	end
end

function UF:Initialize()
	local config = ns.Config.unitFrames

	local player = createPlayer(self, config)
	createTargets(self, player)
	createParty(self, config)
	createArena(self, config)
	createBosses(self, config)
end
