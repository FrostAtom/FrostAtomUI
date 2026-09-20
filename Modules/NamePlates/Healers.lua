local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local IsInInstance = IsInInstance
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local UnitFactionGroup = UnitFactionGroup
local match = string.match

local HEALING_CLASSES = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
local HEALER_ICON = "Interface\\Icons\\Spell_Holy_FlashHeal"
local ICON_SIZE = 16
local POLL_INTERVAL = 10

local plates = NamePlates.plates
local healers = {}
local plateIcons = setmetatable({}, { __mode = "k" })

local function updateIcon(icon, name)
	if healers[name] then
		icon:Show()
	else
		icon:Hide()
	end
end

local function updateHealers()
	local ownFaction = UnitFactionGroup("player") == "Horde" and 0 or 1
	wipe(healers)

	for i = 1, GetNumBattlefieldScores() do
		local name, _, _, _, _, faction, _, _, _, class, damage, healing = GetBattlefieldScore(i)
		if name and faction ~= ownFaction and HEALING_CLASSES[class] and healing > damage * 2 then
			healers[match(name, "^[^%-]+")] = true
		end
	end

	for i = 1, #plates do
		local plate = plates[i]
		local icon = plateIcons[plate]
		if icon and plate:IsShown() then
			updateIcon(icon, plate.blizzardName:GetText())
		end
	end
end

NamePlates.onPlateShow[#NamePlates.onPlateShow + 1] = function(plate, name)
	local icon = plateIcons[plate]
	if not icon then
		icon = plate:CreateTexture(nil, "OVERLAY")
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint("LEFT", plate.name, "RIGHT", 2, 0)
		icon:SetTexture(HEALER_ICON)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		plateIcons[plate] = icon
	end
	updateIcon(icon, name)
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

NamePlates:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", updateHealers)
NamePlates:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" then
		poller.timer = 0
		poller:Show()
	else
		poller:Hide()
		wipe(healers)
	end
end)
