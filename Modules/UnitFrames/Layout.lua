local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- Where every unit frame goes and which elements it gets.

local PLAYER_AURA = { size = 34, gap = 2, anchor = "TOPRIGHT" }

local function createPlayer(self)
	local player = self:CreateRectangle("player", 200, 45)
	player:SetPoint("TOPLEFT", 150, -40)

	local leader = self:AddElement(player, "leader")
	leader:SetPoint("TOPLEFT", player.health, 24, 8)

	-- Auras sit next to the minimap, growing left.
	local buffs = self:AddElement(player, "buffs", PLAYER_AURA)
	buffs:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -15, 0)

	local debuffs = self:AddElement(player, "debuffs", PLAYER_AURA)
	debuffs:SetPoint("TOPRIGHT", buffs, "BOTTOMRIGHT")

	local castbar = self:AddElement(player, "castbar")
	castbar:SetSize(240, 22)
	castbar:SetPoint("CENTER", UIParent, 0, -270)
	castbar.icon:SetSize(24, 24)

	local loseControl = self:AddElement(player, "losecontrol")
	loseControl:SetSize(32, 32)
	loseControl:SetPoint("CENTER", UIParent)

	local pet = self:CreatePet("pet", 45)
	pet:SetPoint("RIGHT", player, "LEFT", -2, 0)

	return player
end

local function createParty(self)
	for i = 1, MAX_PARTY_MEMBERS do
		local unit = "party" .. i
		local frame = self:CreateRectangle(unit, 180, 40)
		frame:SetPoint("TOPLEFT", 50, -150 - (i - 1) * (40 + 72))
		frame:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateAll")

		local leader = self:AddElement(frame, "leader")
		leader:SetPoint("TOPLEFT", frame.health, 24, 8)

		local buffs = self:AddElement(frame, "buffs", { size = 180 / 8, max = 16 })
		buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT")

		local debuffs = self:AddElement(frame, "debuffs", { size = 180 / 8, max = 16 })
		debuffs:SetPoint("LEFT", frame, "RIGHT")

		local castbar = self:AddElement(frame, "castbar")
		castbar:SetSize(176, 20)
		castbar:SetPoint("BOTTOM", frame, "TOP")
		castbar.icon:SetSize(22, 22)

		local loseControl = self:AddElement(frame, "losecontrol")
		loseControl:SetSize(30, 30)
		loseControl:SetPoint("CENTER")

		local pet = self:CreatePet("partypet" .. i, 40)
		pet:SetPoint("RIGHT", frame, "LEFT", -2, 0)
		pet:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateAll")
	end
end

local function createArena(self)
	for i = 1, 3 do
		local frame = self:CreateRectangle("arena" .. i, 200, 50)
		frame:SetPoint("RIGHT", -150, (3 - i) * (50 + 54))

		local debuffs = self:AddElement(frame, "debuffs", { size = 200 / 8, max = 16 })
		debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT")

		local castbar = self:AddElement(frame, "castbar")
		castbar:SetSize(160, 35)
		castbar:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, -2)
		castbar.icon:SetSize(37, 37)

		local loseControl = self:AddElement(frame, "losecontrol")
		loseControl:SetSize(32, 32)
		loseControl:SetPoint("CENTER")

		local pet = self:CreatePet("arenapet" .. i, 50)
		pet:SetPoint("LEFT", frame, "RIGHT", 2, 0)
	end
end

function UF:Initialize()
	local player = createPlayer(self)

	local target, targetOfTarget = self:CreateTarget("target", 200, 45)
	target:SetPoint("LEFT", player, "RIGHT", 2, 0)
	target:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateAll")
	targetOfTarget:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateAll")

	local focus, focusTarget = self:CreateTarget("focus", 200, 45)
	focus:SetPoint("LEFT", targetOfTarget, "RIGHT", 2, 0)
	focus:RegisterEvent("PLAYER_FOCUS_CHANGED", "UpdateAll")
	focusTarget:RegisterEvent("PLAYER_FOCUS_CHANGED", "UpdateAll")

	createParty(self)
	createArena(self)
end
