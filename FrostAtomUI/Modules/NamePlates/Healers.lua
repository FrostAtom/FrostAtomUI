local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local IsInInstance = IsInInstance
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local UnitFactionGroup = UnitFactionGroup
local match = string.match

local POLL_INTERVAL = 10
local CROSS_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local CROSS_GAP = 2
local floor = math.floor
local config = ns.Config.namePlates

local plates = NamePlates.plates
local healers = {}
local plateCrosses = setmetatable({}, { __mode = "k" })

local function createCross(plate)
	local cross = plate.overlay:CreateTexture(nil, "ARTWORK")
	cross:SetTexture(CROSS_TEXTURE)
	cross:SetTexCoord(GetTexCoordsForRole("HEALER"))
	cross:Hide()
	return cross
end

local function sizeCross(cross)
	local size = floor(config.healerCrossSize + 0.5)
	cross:SetSize(size, size)
end

local function placeCross(plate)
	local cross = plateCrosses[plate]
	if not cross then
		return
	end
	local row = plate.auraRow
	cross:ClearAllPoints()
	if row and row:IsShown() then
		cross:SetPoint("BOTTOM", row, "TOP", 0, CROSS_GAP)
	else
		cross:SetPoint("BOTTOM", plate.holder, "TOP", 0, CROSS_GAP)
	end
end
NamePlates.PlaceHealerCross = placeCross

local function updateCross(plate, name)
	local cross = plateCrosses[plate]
	if config.showHealers and healers[name] then
		if not cross then
			cross = createCross(plate)
			plateCrosses[plate] = cross
		end
		sizeCross(cross)
		placeCross(plate)
		cross:Show()
	elseif cross then
		cross:Hide()
	end
end

local function refreshCrosses()
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() then
			updateCross(plate, plate.blizzardName:GetText())
		end
	end
end

local function updateHealers()
	local ownFaction = UnitFactionGroup("player") == "Horde" and 0 or 1
	local threshold = config.healerThreshold
	local classes = config.healerClasses
	wipe(healers)

	for i = 1, GetNumBattlefieldScores() do
		local name, _, _, _, _, faction, _, _, _, class, damage, healing = GetBattlefieldScore(i)
		if name and faction ~= ownFaction and classes[class] and healing > damage * threshold then
			healers[match(name, "^[^%-]+")] = true
		end
	end
	refreshCrosses()
end

NamePlates.onPlateShow[#NamePlates.onPlateShow + 1] = updateCross

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

NamePlates:WatchConfig("namePlates", updateHealers)
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
