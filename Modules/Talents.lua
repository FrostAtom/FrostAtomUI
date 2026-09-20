local _, ns = ...

local GetSpellInfo = GetSpellInfo
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local GetNumTalents = GetNumTalents
local GetNumTalentTabs = GetNumTalentTabs
local GetActiveTalentGroup = GetActiveTalentGroup
local GetGlyphSocketInfo = GetGlyphSocketInfo
local CanInspect = CanInspect
local CheckInteractDistance = CheckInteractDistance
local InCombatLockdown = InCombatLockdown
local UnitGUID = UnitGUID
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitIsVisible = UnitIsVisible
local UnitIsConnected = UnitIsConnected
local UnitCanAttack = UnitCanAttack
local UnitLevel = UnitLevel
local IsInInstance = IsInInstance
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetTime = GetTime

local Data = ns.CooldownData
local MAX_TALENT_POINTS = Data.MAX_TALENT_POINTS
local SPEC_HINTS = Data.SPEC_HINTS

local NUM_GLYPH_SOCKETS = 6
local MAX_AURAS = 40
local INSPECT_INTERVAL = 1.5
local INSPECT_TIMEOUT = 5
local INSPECT_RETRIES = 4
local CACHE_TIME = 900
local ARENA_REINSPECT_INTERVAL = 12
local ARENA_REINSPECT_COUNT = 6
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }
local INSPECT_UNITS = { "party1", "party2", "party3", "party4", "target", "focus", "mouseover" }
local HOSTILE_SCAN_UNITS = { arena1 = true, arena2 = true, arena3 = true, target = true, focus = true }

local TREE1_TALENTS = {
	DEATHKNIGHT = 48979, -- Butchery
	DRUID = 16814, -- Starlight Wrath
	HUNTER = 19552, -- Improved Aspect of the Hawk
	MAGE = 11210, -- Arcane Subtlety
	PALADIN = 20205, -- Spiritual Focus
	PRIEST = 14522, -- Unbreakable Will
	ROGUE = 14162, -- Improved Eviscerate
	SHAMAN = 16039, -- Convection
	WARLOCK = 18827, -- Improved Curse of Agony
	WARRIOR = 12282, -- Improved Heroic Strike
}

ns.TALENTS_UPDATED = "FrostAtomUI_TALENTS_UPDATED"

local Talents = ns:NewModule("Talents")

local talentRanks = {}

local function registerRank(name, rank, id)
	local ranks = talentRanks[name]
	if not ranks then
		ranks = {}
		talentRanks[name] = ranks
	end
	local ids = ranks[rank]
	if not ids then
		ids = {}
		ranks[rank] = ids
	end
	if not ns.tContains(ids, id) then
		ids[#ids + 1] = id
	end
end

local function registerRow(row)
	local previous, rank
	for i = 1, #row, 2 do
		local id = row[i]
		local name = GetSpellInfo(id)
		if name then
			rank = name == previous and rank + 1 or 1
			previous = name
			registerRank(name, rank, id)
		end
	end
end

for _, spells in pairs(Data.SPELLS) do
	for i = 1, #spells do
		local entry = spells[i]
		local talent = entry.talent
		if talent then
			local id = talent == true and entry[1] or talent
			local name = GetSpellInfo(id)
			if name then
				registerRank(name, 1, id)
			end
		end
	end
end
for _, row in pairs(Data.CDMOD) do
	registerRow(row)
end
for _, row in pairs(Data.CDMOD_MULT) do
	registerRow(row)
end

local data = {}
local dataTime = {}
local observed = {}
local specs = {}
local pending = {}
local retries = {}
local lastRequestGUID, lastRequestTime, lastRequestClass = nil, 0, nil

local function tree1Matches(class)
	local id = class and TREE1_TALENTS[class]
	local expected = id and GetSpellInfo(id)
	if not expected then
		return true
	end
	for i = 1, GetNumTalents(1, true) do
		if GetTalentInfo(1, i, true) == expected then
			return true
		end
	end
	return false
end

local function readTalents(isInspect, into)
	local group = GetActiveTalentGroup(isInspect)
	local spent, bestTab, bestPoints = 0, nil, 0
	for tab = 1, GetNumTalentTabs(isInspect) do
		local _, _, tabPoints = GetTalentTabInfo(tab, isInspect, nil, group)
		tabPoints = tabPoints or 0
		for i = 1, GetNumTalents(tab, isInspect) do
			local name, _, _, _, rank = GetTalentInfo(tab, i, isInspect, nil, group)
			if rank and rank > 0 then
				local ranks = talentRanks[name]
				local ids = ranks and ranks[rank]
				if ids then
					for j = 1, #ids do
						into[ids[j]] = true
					end
				end
			end
		end
		spent = spent + tabPoints
		if tabPoints > bestPoints then
			bestTab, bestPoints = tab, tabPoints
		elseif tabPoints == bestPoints then
			bestTab = nil
		end
	end
	return spent, group, bestTab
end

local function store(guid, talents, spec)
	data[guid] = talents
	dataTime[guid] = GetTime()
	specs[guid] = spec
	retries[guid] = nil
	pending[guid] = nil
	ns:Fire(ns.TALENTS_UPDATED, guid)
end

local function readPlayer()
	local guid = UnitGUID("player")
	if not guid then
		return
	end
	local talents = {}
	local spent, group, spec = readTalents(nil, talents)
	if spent == 0 then
		return
	end
	for i = 1, NUM_GLYPH_SOCKETS do
		local enabled, _, glyphSpell = GetGlyphSocketInfo(i, group)
		if enabled and glyphSpell then
			talents[glyphSpell] = true
		end
	end
	store(guid, talents, spec)
end

function Talents:Get(guid)
	return data[guid]
end

function Talents:GetSpec(guid)
	local spec = specs[guid]
	if spec then
		return spec
	end
	local trees = observed[guid]
	if not trees then
		return
	end
	local bestTree, bestPoints = nil, 0
	for tree, points in pairs(trees) do
		if points > bestPoints then
			bestTree, bestPoints = tree, points
		end
	end
	return bestTree
end

function Talents:Has(guid, id)
	local talents = data[guid]
	return talents and talents[id]
end

local guidClass = {}

local function classOf(guid)
	local class = guidClass[guid]
	if class == nil then
		local _, playerClass = GetPlayerInfoByGUID(guid)
		class = playerClass or false
		guidClass[guid] = class
	end
	return class
end

function Talents:Observe(guid, hint)
	if classOf(guid) ~= hint.class then
		return
	end
	local trees = observed[guid]
	if not trees then
		trees = {}
		observed[guid] = trees
	end
	local tree, points = hint.tree, hint.points
	if (trees[tree] or 0) < points then
		trees[tree] = points
		ns:Fire(ns.TALENTS_UPDATED, guid)
	end
end

function Talents:IsExcluded(guid, tree, points)
	local trees = observed[guid]
	if not trees then
		return false
	end
	for otherTree, otherPoints in pairs(trees) do
		if otherTree ~= tree and otherPoints + points > MAX_TALENT_POINTS then
			return true
		end
	end
	return false
end

local queue = CreateFrame("Frame")
queue:Hide()
queue.sinceRequest = 0
queue.sinceArenaTick = 0
queue.arenaTicks = 0

local function guidToUnit(guid)
	for i = 1, #INSPECT_UNITS do
		local unit = INSPECT_UNITS[i]
		if UnitGUID(unit) == guid then
			return unit
		end
	end
	for i = 1, #INSPECT_UNITS do
		local unit = INSPECT_UNITS[i] .. "target"
		if UnitGUID(unit) == guid then
			return unit
		end
	end
end

local function inspectable(unit)
	return UnitExists(unit) and UnitIsPlayer(unit) and UnitLevel(unit) >= 10 and not UnitCanAttack("player", unit)
end

local function enqueue(unit, force)
	local guid = UnitGUID(unit)
	if not guid or guid == UnitGUID("player") or not inspectable(unit) then
		return
	end
	if force or not data[guid] or GetTime() - dataTime[guid] > CACHE_TIME then
		pending[guid] = true
		queue:Show()
	end
end

function Talents:Invalidate(guid)
	data[guid] = nil
	dataTime[guid] = nil
	observed[guid] = nil
	specs[guid] = nil
	retries[guid] = nil
	local unit = guidToUnit(guid)
	if unit then
		enqueue(unit, true)
	end
	ns:Fire(ns.TALENTS_UPDATED, guid)
end

local function requestInspect()
	if InCombatLockdown() or (InspectFrame and InspectFrame:IsShown()) then
		return
	end
	if lastRequestGUID and GetTime() - lastRequestTime < INSPECT_TIMEOUT then
		return
	end
	for guid in pairs(pending) do
		local unit = guidToUnit(guid)
		if not unit then
			pending[guid] = nil
		elseif
			UnitIsVisible(unit)
			and UnitIsConnected(unit)
			and CanInspect(unit)
			and CheckInteractDistance(unit, 1)
		then
			NotifyInspect(unit)
			return
		end
	end
end

queue:SetScript("OnUpdate", function(self, elapsed)
	self.sinceRequest = self.sinceRequest + elapsed
	if self.sinceRequest >= INSPECT_INTERVAL then
		self.sinceRequest = 0
		requestInspect()
	end

	if self.arenaTicks > 0 then
		self.sinceArenaTick = self.sinceArenaTick + elapsed
		if self.sinceArenaTick >= ARENA_REINSPECT_INTERVAL then
			self.sinceArenaTick = 0
			self.arenaTicks = self.arenaTicks - 1
			for i = 1, #PARTY_UNITS do
				enqueue(PARTY_UNITS[i], true)
			end
		end
	end

	if not next(pending) and self.arenaTicks == 0 then
		self:Hide()
	end
end)

hooksecurefunc("NotifyInspect", function(unit)
	local _, class = UnitClass(unit)
	lastRequestGUID, lastRequestTime, lastRequestClass = UnitGUID(unit), GetTime(), class
end)

local function retry(guid)
	local count = (retries[guid] or 0) + 1
	retries[guid] = count
	if count > INSPECT_RETRIES then
		pending[guid] = nil
		retries[guid] = nil
	else
		pending[guid] = true
		queue:Show()
	end
end

function Talents:INSPECT_TALENT_READY()
	local guid = lastRequestGUID
	if not guid then
		return
	end
	lastRequestGUID = nil
	if guid == UnitGUID("player") then
		return
	end
	local talents = {}
	local spent, _, spec = readTalents(true, talents)
	if spent == 0 or not tree1Matches(lastRequestClass) then
		retry(guid)
		return
	end
	store(guid, talents, spec)
end

local function scanAuras(unit)
	if not UnitGUID(unit) or not UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
		return
	end
	for i = 1, MAX_AURAS do
		local name, _, _, _, _, _, _, caster, _, _, spellId = UnitBuff(unit, i)
		if not name then
			return
		end
		local hint = SPEC_HINTS[spellId]
		if hint and caster and UnitIsPlayer(caster) then
			local guid = UnitGUID(caster)
			if guid then
				Talents:Observe(guid, hint)
			end
		end
	end
end

function Talents:UNIT_AURA(unit)
	if HOSTILE_SCAN_UNITS[unit] then
		scanAuras(unit)
	end
end

Talents.ARENA_OPPONENT_UPDATE = Talents.UNIT_AURA

local function onUnitChanged(unit)
	if UnitCanAttack("player", unit) then
		scanAuras(unit)
	else
		enqueue(unit)
	end
end

function Talents:PLAYER_TARGET_CHANGED()
	onUnitChanged("target")
end

function Talents:PLAYER_FOCUS_CHANGED()
	onUnitChanged("focus")
end

function Talents:UPDATE_MOUSEOVER_UNIT()
	onUnitChanged("mouseover")
end

function Talents:PARTY_MEMBERS_CHANGED()
	for i = 1, #PARTY_UNITS do
		enqueue(PARTY_UNITS[i])
	end
end

function Talents:PLAYER_ENTERING_WORLD()
	wipe(observed)
	wipe(pending)
	wipe(retries)
	lastRequestGUID = nil
	readPlayer()
	self:PARTY_MEMBERS_CHANGED()
	self:PLAYER_TARGET_CHANGED()
	self:PLAYER_FOCUS_CHANGED()
	if select(2, IsInInstance()) == "arena" then
		queue.arenaTicks = ARENA_REINSPECT_COUNT
		queue.sinceArenaTick = 0
		queue:Show()
	else
		queue.arenaTicks = 0
	end
end

function Talents:Initialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	self:RegisterEvent("INSPECT_TALENT_READY")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("ARENA_OPPONENT_UPDATE")
	self:RegisterEvent("PLAYER_TALENT_UPDATE", readPlayer)
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", readPlayer)
	self:RegisterEvent("GLYPH_ADDED", readPlayer)
	self:RegisterEvent("GLYPH_REMOVED", readPlayer)
	self:RegisterEvent("GLYPH_UPDATED", readPlayer)
end
