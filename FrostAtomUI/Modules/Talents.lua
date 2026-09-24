local _, ns = ...

local GetSpellInfo = GetSpellInfo
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local GetNumTalents = GetNumTalents
local GetNumTalentTabs = GetNumTalentTabs
local GetActiveTalentGroup = GetActiveTalentGroup
local GetGlyphSocketInfo = GetGlyphSocketInfo
local UnitGUID = UnitGUID
local UnitBuff = UnitBuff
local UnitIsPlayer = UnitIsPlayer
local UnitCanAttack = UnitCanAttack
local GetPlayerInfoByGUID = GetPlayerInfoByGUID

local Data = ns.CooldownData
local MAX_TALENT_POINTS = Data.MAX_TALENT_POINTS
local SPEC_HINTS = Data.SPEC_HINTS

local NUM_GLYPH_SOCKETS = 6
local MAX_AURAS = 40
local HOSTILE_SCAN_UNITS =
	{ arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true, target = true, focus = true }

ns.TALENTS_UPDATED = "FrostAtomUI_TALENTS_UPDATED"

local Inspect = ns:GetModule("Inspect")
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
local observed = {}
local specs = {}
local points = {}

local treePoints = {}

local function readTalents(isInspect, into)
	local group = GetActiveTalentGroup(isInspect)
	local spent, bestTab, bestPoints = 0, nil, 0
	local numTabs = GetNumTalentTabs(isInspect)
	for tab = 1, numTabs do
		local _, _, tabPoints = GetTalentTabInfo(tab, isInspect, nil, group)
		tabPoints = tabPoints or 0
		treePoints[tab] = tabPoints
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
	for tab = numTabs + 1, #treePoints do
		treePoints[tab] = nil
	end
	return spent, group, bestTab
end

local function storeTalents(guid, talents, spec)
	data[guid] = talents
	specs[guid] = spec
	points[guid] = table.concat(treePoints, "/")
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
	storeTalents(guid, talents, spec)
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

function Talents:GetPoints(guid)
	return points[guid]
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

function Talents:GetObserved(guid, tree)
	local trees = observed[guid]
	return trees and trees[tree] or 0
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

function Talents:Invalidate(guid)
	data[guid] = nil
	observed[guid] = nil
	specs[guid] = nil
	points[guid] = nil
	local unit = Inspect:UnitByGUID(guid)
	if unit then
		Inspect:Request(unit)
	end
	ns:Fire(ns.TALENTS_UPDATED, guid)
end

local function onTalentsReady(_, guid)
	local talents = {}
	local spent, _, spec = readTalents(true, talents)
	if spent > 0 then
		storeTalents(guid, talents, spec)
	end
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

function Talents:PLAYER_TARGET_CHANGED()
	scanAuras("target")
end

function Talents:PLAYER_FOCUS_CHANGED()
	scanAuras("focus")
end

function Talents:PLAYER_ENTERING_WORLD()
	wipe(observed)
	readPlayer()
	self:PLAYER_TARGET_CHANGED()
	self:PLAYER_FOCUS_CHANGED()
end

function Talents:Initialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterEvent(ns.INSPECT_TALENTS_READY, onTalentsReady)
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("ARENA_OPPONENT_UPDATE")
	for _, event in ipairs({
		"PLAYER_TALENT_UPDATE",
		"ACTIVE_TALENT_GROUP_CHANGED",
		"GLYPH_ADDED",
		"GLYPH_REMOVED",
		"GLYPH_UPDATED",
	}) do
		self:RegisterEvent(event, readPlayer)
	end
end
