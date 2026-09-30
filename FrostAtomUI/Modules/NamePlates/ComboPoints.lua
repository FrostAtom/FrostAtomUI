local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")
local Talents = ns:GetModule("Talents")

local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local IsInInstance = IsInInstance
local GetTime = GetTime
local band = bit.band
local min, max, floor = math.min, math.max, math.floor
local select = select
local wipe = wipe

local config = ns.Config.namePlates
local frameConfig = ns.Config.unitFrames
local plates = NamePlates.plates
local guidPlates = NamePlates.guidPlates
local WorldChildren = ns.WorldChildren

local MAX_POINTS = 5
local POINT_GAP = 2
local MISS_WINDOW = 0.5
local EMPTY_COLOR = { 0.2, 0.2, 0.2 }
local FERAL_TREE = 2
local SUBTLETY_TREE = 3
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local PREMEDITATION = 14183 -- Premeditation
local HONOR_AMONG_THIEVES = 51699 -- Honor Among Thieves
local SHIV = 5940 -- Shiv

local GENERATORS = {}
local INITIATIVE = {}
local FINISHERS = {}

local function register(map, value, ...)
	for i = 1, select("#", ...) do
		map[select(i, ...)] = value
	end
end

-- Openers gain an extra point for Subtlety rogues (Initiative).
local function registerOpener(gain, ...)
	register(GENERATORS, gain, ...)
	register(INITIATIVE, true, ...)
end

register(GENERATORS, 1, 1752, 1757, 1758, 1759, 1760, 8621, 11293, 11294, 26861, 26862, 48637, 48638) -- Sinister Strike
register(GENERATORS, 1, 53, 2589, 2590, 2591, 8721, 11279, 11280, 11281, 25300, 26863, 48656, 48657) -- Backstab
register(GENERATORS, 1, 16511, 17347, 17348, 26864, 48660) -- Hemorrhage
register(GENERATORS, 1, 14278) -- Ghostly Strike
register(GENERATORS, 1, 1776, 1777, 8629, 11285, 11286, 38764) -- Gouge
register(GENERATORS, 1, 14251) -- Riposte
registerOpener(2, 8676, 8724, 8725, 11267, 11268, 11269, 27441, 48689, 48690, 48691) -- Ambush
registerOpener(1, 703, 8631, 8632, 8633, 11289, 11290, 26839, 26884, 48675, 48676) -- Garrote
registerOpener(2, 1833) -- Cheap Shot
register(GENERATORS, 2, 1329, 34411, 34412, 34413, 48663, 48666) -- Mutilate
register(GENERATORS, 1, 1082, 3029, 5201, 9849, 9850, 27000, 48569, 48570) -- Claw
register(GENERATORS, 1, 1822, 1823, 1824, 9904, 27003, 48573, 48574) -- Rake
register(GENERATORS, 1, 5221, 6800, 8992, 9829, 9830, 27001, 27002, 48571, 48572) -- Shred
register(GENERATORS, 1, 33876, 33982, 33983, 48565, 48566) -- Mangle (Cat)
register(GENERATORS, 1, 6785, 6787, 9866, 9867, 27005, 48578, 48579) -- Ravage
register(GENERATORS, 1, 9005, 9823, 9827, 27006, 49803) -- Pounce
register(GENERATORS, 1, 14189) -- Seal Fate
register(GENERATORS, 1, 16953) -- Primal Fury

register(FINISHERS, "target", 2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 31016, 26865, 48667, 48668) -- Eviscerate
register(FINISHERS, "target", 32645, 32684, 57992, 57993) -- Envenom
register(FINISHERS, "target", 1943, 8639, 8640, 11273, 11274, 11275, 26867, 48671, 48672) -- Rupture
register(FINISHERS, "target", 408, 8643) -- Kidney Shot
register(FINISHERS, "self", 5171, 6774) -- Slice and Dice
register(FINISHERS, "target", 8647, 8649, 8650, 11197, 11198, 26866, 48669) -- Expose Armor
register(FINISHERS, "target", 26679, 48673, 48674) -- Deadly Throw
register(FINISHERS, "target", 22568, 22827, 22828, 22829, 31018, 24248, 48576, 48577) -- Ferocious Bite
register(FINISHERS, "target", 1079, 9492, 9493, 9752, 9894, 9896, 27008, 49799, 49800) -- Rip
register(FINISHERS, "target", 22570, 49802) -- Maim
register(FINISHERS, "self", 52610) -- Savage Roar

local states = {}
local rows = setmetatable({}, { __mode = "k" })
local inArena = false

local function isEnemyPlayer(flags)
	return band(flags, TYPE_PLAYER) > 0 and band(flags, REACTION_HOSTILE) > 0
end

local function stateOf(guid)
	local state = states[guid]
	if not state then
		state = { points = 0 }
		states[guid] = state
	end
	return state
end

local function pointsFor(plate)
	if not inArena or not config.comboPoints or plate.hiddenByName or plate.totemSpell or not plate:IsShown() then
		return 0
	end
	local guid = plate.guid
	local state = guid and states[guid]
	if not state or state.points == 0 then
		return 0
	end
	local _, class = GetPlayerInfoByGUID(guid)
	if class == "DRUID" then
		local spec = Talents:GetSpec(guid)
		if spec and spec ~= FERAL_TREE then
			return 0
		end
	end
	return state.points
end

local function createRow(plate)
	local row = CreateFrame("Frame", nil, plate.overlay)
	for i = 1, MAX_POINTS do
		local border = row:CreateTexture(nil, "BORDER")
		border:SetTexture(0, 0, 0)
		local point = row:CreateTexture(nil, "ARTWORK")
		point.border = border
		row[i] = point
	end
	rows[plate] = row
	return row
end

local function layoutRow(row, anchor)
	local size = floor(config.comboPointSize + 0.5)
	local pixel = WorldChildren.Pixel()
	row:SetSize(MAX_POINTS * size + (MAX_POINTS - 1) * POINT_GAP, size)
	row:ClearAllPoints()
	row:SetPoint("TOP", anchor, "BOTTOM", 0, -config.castbarGap)
	for i = 1, MAX_POINTS do
		local point = row[i]
		local border = point.border
		border:SetSize(size, size)
		border:ClearAllPoints()
		border:SetPoint("LEFT", (i - 1) * (size + POINT_GAP), 0)
		point:ClearAllPoints()
		point:SetPoint("TOPLEFT", border, pixel, -pixel)
		point:SetPoint("BOTTOMRIGHT", border, -pixel, pixel)
	end
end

local function colorRow(row, points)
	local color = points == MAX_POINTS and frameConfig.comboPointColor or frameConfig.comboPointPartialColor
	for i = 1, MAX_POINTS do
		local c = i <= points and color or EMPTY_COLOR
		row[i]:SetTexture(c[1], c[2], c[3])
	end
end

local function setOffset(plate, offset)
	if plate.comboOffset == offset then
		return
	end
	plate.comboOffset = offset
	local castbar = plate.castbar
	if castbar:IsShown() then
		castbar:Layout()
	end
	local vcast = plate.vcast
	if vcast and vcast:IsShown() then
		NamePlates.LayoutCastbar(vcast)
	end
end

local function updatePlate(plate)
	local points = pointsFor(plate)
	local row = rows[plate]
	if points == 0 then
		if row then
			row:Hide()
		end
		setOffset(plate, nil)
		return
	end
	row = row or createRow(plate)
	layoutRow(row, (NamePlates.CastAnchor(plate)))
	colorRow(row, points)
	row:Show()
	setOffset(plate, floor(config.comboPointSize + 0.5) + config.castbarGap)
end

local function refresh(guid)
	local plate = guidPlates[guid]
	if plate then
		updatePlate(plate)
	end
end

local function refreshAll()
	for i = 1, #plates do
		updatePlate(plates[i])
	end
end

local function addPoints(state, dst, amount)
	if state.target ~= dst then
		state.target = dst
		state.points = min(amount, MAX_POINTS)
	else
		state.points = min(state.points + amount, MAX_POINTS)
	end
	state.premeditation = false
end

local function clearPoints(state)
	state.target = nil
	state.points = 0
	state.premeditation = false
end

local function saveUndo(state, spellId, dst, now)
	state.undoId, state.undoDst, state.undoTime = spellId, dst, now
	state.undoTarget, state.undoPoints, state.undoPremeditation = state.target, state.points, state.premeditation
end

local function undo(state, spellId, dst, now)
	if state.undoId ~= spellId or state.undoDst ~= dst or now - state.undoTime > MISS_WINDOW then
		return false
	end
	state.undoId = nil
	state.target, state.points, state.premeditation = state.undoTarget, state.undoPoints, state.undoPremeditation
	return true
end

local function tracking()
	return inArena and config.comboPoints
end

local function onCastSuccess(srcGUID, srcFlags, dstGUID, _, spellId)
	if not tracking() or not isEnemyPlayer(srcFlags) then
		return
	end
	local gain = GENERATORS[spellId]
	local finisher = FINISHERS[spellId]
	if not gain and not finisher and spellId ~= PREMEDITATION then
		return
	end
	local state = stateOf(srcGUID)
	local now = GetTime()
	if state.missId == spellId and state.missDst == dstGUID and now - state.missTime <= MISS_WINDOW then
		state.missId = nil
		return
	end
	saveUndo(state, spellId, dstGUID, now)
	if finisher then
		clearPoints(state)
	elseif spellId == PREMEDITATION then
		addPoints(state, dstGUID, 2)
		state.premeditation = true
	else
		if INITIATIVE[spellId] and Talents:GetSpec(srcGUID) == SUBTLETY_TREE then
			gain = gain + 1
		end
		addPoints(state, dstGUID, gain)
	end
	refresh(srcGUID)
end

local function onMissed(srcGUID, srcFlags, dstGUID, _, spellId)
	if not tracking() or not isEnemyPlayer(srcFlags) then
		return
	end
	if not GENERATORS[spellId] and not FINISHERS[spellId] and spellId ~= PREMEDITATION then
		return
	end
	local state = stateOf(srcGUID)
	local now = GetTime()
	if undo(state, spellId, dstGUID, now) then
		refresh(srcGUID)
	else
		state.missId, state.missDst, state.missTime = spellId, dstGUID, now
	end
end

local function onDamage(srcGUID, srcFlags, dstGUID, _, spellId, _, _, _, _, _, _, blocked)
	if not tracking() or not isEnemyPlayer(srcFlags) then
		return
	end
	if spellId == SHIV then
		addPoints(stateOf(srcGUID), dstGUID, 1)
		refresh(srcGUID)
	elseif FINISHERS[spellId] and blocked and blocked > 0 then
		local state = states[srcGUID]
		if state and undo(state, spellId, dstGUID, GetTime()) then
			refresh(srcGUID)
		end
	end
end

local function onAuraApplied(srcGUID, srcFlags, dstGUID, _, spellId)
	if spellId ~= HONOR_AMONG_THIEVES or srcGUID ~= dstGUID or not tracking() or not isEnemyPlayer(srcFlags) then
		return
	end
	local state = states[srcGUID]
	if state and state.target then
		addPoints(state, state.target, 1)
		refresh(srcGUID)
	end
end

local function onAuraRemoved(_, _, dstGUID, _, spellId)
	if spellId ~= PREMEDITATION then
		return
	end
	local state = states[dstGUID]
	if state and state.premeditation then
		state.premeditation = false
		state.points = max(state.points - 2, 0)
		refresh(dstGUID)
	end
end

local function onDied(_, _, dstGUID)
	local own = states[dstGUID]
	if own and own.points > 0 then
		clearPoints(own)
		refresh(dstGUID)
	end
	for guid, state in pairs(states) do
		if state.target == dstGUID then
			clearPoints(state)
			refresh(guid)
		end
	end
end

local function onEnteringWorld()
	local _, instanceType = IsInInstance()
	inArena = instanceType == "arena"
	wipe(states)
	refreshAll()
end

local function onPlateHide(plate)
	local row = rows[plate]
	if row then
		row:Hide()
	end
	plate.comboOffset = nil
end

NamePlates:OnInitialize(function(self)
	if not config.enabled then
		return
	end
	NamePlates.onPlateShow[#NamePlates.onPlateShow + 1] = updatePlate
	NamePlates.onPlateHide[#NamePlates.onPlateHide + 1] = onPlateHide
	NamePlates.onIdentity[#NamePlates.onIdentity + 1] = updatePlate
	NamePlates.AddLogHandler("SPELL_CAST_SUCCESS", onCastSuccess)
	NamePlates.AddLogHandler("SPELL_MISSED", onMissed)
	NamePlates.AddLogHandler("SPELL_DAMAGE", onDamage)
	NamePlates.AddLogHandler("SPELL_AURA_APPLIED", onAuraApplied)
	NamePlates.AddLogHandler("SPELL_AURA_REMOVED", onAuraRemoved)
	NamePlates.AddLogHandler("UNIT_DIED", onDied)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	self:RegisterEvent(ns.TALENTS_UPDATED, function(_, guid)
		refresh(guid)
	end)
	self:WatchConfig("namePlates", refreshAll)
	self:WatchConfig("unitFrames", refreshAll)
end)
