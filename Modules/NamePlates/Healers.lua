local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local IsInInstance = IsInInstance
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local UnitFactionGroup = UnitFactionGroup

local HEALING_CLASSES = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
local HEALER_ICON = "Interface\\Icons\\Spell_Holy_FlashHeal"
local ICON_SIZE = 16
local POLL_INTERVAL = 10

local healers = {}
local plateIcons = setmetatable({}, { __mode = "k" })

local function playerFaction()
	local faction = UnitFactionGroup("player")
	return faction == "Horde" and 0 or 1
end

local function updateHealers()
	local ownFaction = playerFaction()
	wipe(healers)

	for i = 1, GetNumBattlefieldScores() do
		local name, _, _, _, _, faction, _, _, _, class, damage, healing = GetBattlefieldScore(i)
		if name and faction ~= ownFaction and HEALING_CLASSES[class] and healing > damage * 2 then
			healers[name:match("^[^%-]+")] = true
		end
	end

	for _, plate in ipairs(NamePlates.plates) do
		local icon = plateIcons[plate]
		if icon and plate:IsShown() then
			if healers[plate.blizzardName:GetText()] then
				icon:Show()
			else
				icon:Hide()
			end
		end
	end
end

local function getIcon(plate)
	local icon = plateIcons[plate]
	if not icon then
		icon = plate:CreateTexture(nil, "OVERLAY")
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint("LEFT", plate.name, "RIGHT", 2, 0)
		icon:SetTexture(HEALER_ICON)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		plateIcons[plate] = icon
	end
	return icon
end

NamePlates.onPlateShow[#NamePlates.onPlateShow + 1] = function(plate, name)
	local icon = getIcon(plate)
	if healers[name] then
		icon:Show()
	else
		icon:Hide()
	end
end

local poller = CreateFrame("Frame")
poller:Hide()
poller.timer = 0
poller:SetScript("OnUpdate", function(self, elapsed)
	self.timer = self.timer - elapsed
	if self.timer <= 0 then
		self.timer = POLL_INTERVAL
		RequestBattlefieldScoreData()
	end
end)

function NamePlates:UPDATE_BATTLEFIELD_SCORE()
	updateHealers()
end

function NamePlates:PLAYER_ENTERING_WORLD()
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" then
		poller.timer = 0
		poller:Show()
	else
		poller:Hide()
		wipe(healers)
	end
end

NamePlates:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
NamePlates:RegisterEvent("PLAYER_ENTERING_WORLD")
