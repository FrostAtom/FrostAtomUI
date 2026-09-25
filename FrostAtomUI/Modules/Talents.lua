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

local max, min, floor, huge = math.max, math.min, math.floor, math.huge

local NUM_TREES = 3
local POINTS_PER_TIER = 5
local DEPTH_ODDS = { 1.2, 1.5, 2, 3, 5, 10, 40, 200, 1000 }
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
	local guess = observed[guid]
	if not guess then
		return
	end
	local main = guess.main
	local bestTree = 1
	for tree = 2, NUM_TREES do
		if main[tree] > main[bestTree] then
			bestTree = tree
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

local function newGuess()
	return {
		main = { 1 / NUM_TREES, 1 / NUM_TREES, 1 / NUM_TREES },
		proven = { 0, 0, 0 },
		cap = { MAX_TALENT_POINTS, MAX_TALENT_POINTS, MAX_TALENT_POINTS },
		seen = {},
	}
end

local UNSEEN = newGuess()

local function weigh(guess)
	local proven, cap, main = guess.proven, guess.cap, guess.main
	local total = proven[1] + proven[2] + proven[3]
	for tree = 1, NUM_TREES do
		cap[tree] = max(MAX_TALENT_POINTS - (total - proven[tree]), proven[tree])
	end
	local sum = 0
	for tree = 1, NUM_TREES do
		local points = proven[tree]
		if proven[tree % 3 + 1] > cap[tree] or proven[(tree + 1) % 3 + 1] > cap[tree] then
			main[tree] = 0
		elseif points > 0 then
			main[tree] = DEPTH_ODDS[min(floor((points - 1) / POINTS_PER_TIER) + 1, #DEPTH_ODDS)]
		else
			main[tree] = 1
		end
		sum = sum + main[tree]
	end
	for tree = 1, NUM_TREES do
		main[tree] = sum > 0 and main[tree] / sum or 1 / NUM_TREES
	end
end

function Talents:Observe(guid, hint)
	if classOf(guid) ~= hint.class then
		return
	end
	local guess = observed[guid]
	if not guess then
		guess = newGuess()
		observed[guid] = guess
	end
	if guess.seen[hint] then
		return
	end
	guess.seen[hint] = true
	local tree = hint.tree
	guess.proven[tree] = max(guess.proven[tree], hint.points + 1)
	weigh(guess)
	ns:Fire(ns.TALENTS_UPDATED, guid)
end

function Talents:GetProven(guid, tree)
	local guess = observed[guid]
	return guess and guess.proven[tree] or 0
end

function Talents:GetReachableRanks(guid, tree, points)
	local guess = observed[guid] or UNSEEN
	local proven = guess.proven[tree]
	if points < proven then
		return huge
	end
	return guess.cap[tree] - points
end

function Talents:IsExcluded(guid, hint)
	local guess = observed[guid]
	if guess and guess.seen[hint] then
		return false
	end
	return self:GetReachableRanks(guid, hint.tree, hint.points) < 1
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
