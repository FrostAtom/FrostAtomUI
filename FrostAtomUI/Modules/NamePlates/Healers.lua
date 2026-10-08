local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local IsInInstance = IsInInstance
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetBattlefieldScore = GetBattlefieldScore
local UnitFactionGroup = UnitFactionGroup
local UnitGUID, UnitClass, UnitName = UnitGUID, UnitClass, UnitName
local match = string.match
local floor = math.floor

local POLL_INTERVAL = 10
local CROSS_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local CROSS_GAP = 2
local HEALER_CLASSES = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
local HEALER_TREES = { PRIEST = { true, true }, PALADIN = { true }, SHAMAN = { [3] = true }, DRUID = { [3] = true } }
local MAX_ARENA = 5
local Talents = ns:GetModule("Talents")
local config = ns.Config.namePlates

local plates = NamePlates.plates
local healers = {}
local arenaHealers = {}
local inArena = false
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
	if config.showHealers and name and (healers[name] or arenaHealers[name]) then
		if not cross then
			cross = createCross(plate)
			plateCrosses[plate] = cross
		end
		sizeCross(cross)
		placeCross(plate)
		cross:Show()
		ns.ExplainOnce("healer")
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
	wipe(healers)

	for i = 1, GetNumBattlefieldScores() do
		local name, _, _, _, _, faction, _, _, _, class, damage, healing = GetBattlefieldScore(i)
		if name and faction ~= ownFaction and HEALER_CLASSES[class] and healing > damage * threshold then
			healers[match(name, "^[^%-]+")] = true
		end
	end
	refreshCrosses()
end

local found = {}

local function updateArenaHealers()
	wipe(found)
	if inArena then
		for i = 1, MAX_ARENA do
			local unit = "arena" .. i
			local guid = UnitGUID(unit)
			local _, class = UnitClass(unit)
			local trees = guid and class and HEALER_TREES[class]
			local spec = trees and Talents:GetSpec(guid)
			if spec and trees[spec] then
				local name = UnitName(unit)
				if name then
					found[name] = true
				end
			end
		end
	end
	local changed = false
	for name in pairs(found) do
		changed = changed or not arenaHealers[name]
	end
	for name in pairs(arenaHealers) do
		changed = changed or not found[name]
	end
	if changed then
		arenaHealers, found = found, arenaHealers
		refreshCrosses()
	end
end

NamePlates.RegisterPlugin({
	name = "healers",
	Show = updateCross,
})

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
NamePlates:RegisterEvent(ns.E.TALENTS_UPDATED, updateArenaHealers)
NamePlates:RegisterEvent("ARENA_OPPONENT_UPDATE", updateArenaHealers)
NamePlates:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local _, instanceType = IsInInstance()
	inArena = instanceType == "arena"
	updateArenaHealers()
	if instanceType == "pvp" then
		poller.timer = 0
		poller:Show()
	else
		poller:Hide()
		wipe(healers)
	end
end)
