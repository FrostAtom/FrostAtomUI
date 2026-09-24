local _, ns = ...

local UnitGUID = UnitGUID
local UnitBuff = UnitBuff
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local GetTime = GetTime
local time = time
local band = bit.band
local pairs, tonumber, sort, wipe, tremove = pairs, tonumber, table.sort, wipe, table.remove

local SpellTexture = ns.SpellTexture

local MIN_COOLDOWN = 10
local LAST_SLOT = 18
local TRINKET_SLOTS = { [13] = true, [14] = true }
local MAX_TRINKETS = 2
local MEMORY_TIME = 30 * 86400
local COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local KIND_ORDER = { i = 1, e = 2, g = 3, s = 4 }

local EVENT_TYPES = {
	SPELL_AURA_APPLIED = { buff = true, stack = true, debuff = true },
	SPELL_AURA_REFRESH = { buff = true, debuff = true },
	SPELL_AURA_APPLIED_DOSE = { stack = true },
	SPELL_DAMAGE = { damage = true },
	SPELL_MISSED = { damage = true },
	SPELL_HEAL = { heal = true },
	SPELL_ENERGIZE = { energize = true },
	SPELL_EXTRA_ATTACKS = { extra = true },
	SPELL_SUMMON = { summon = true },
}
local AURA_EVENTS = { buff = true, stack = true }
local MAX_AURAS = 40

ns.PROC_COOLDOWN_UPDATED = "FrostAtomUI_PROC_COOLDOWN_UPDATED"

local InternalCooldowns = ns:NewModule("InternalCooldowns")
InternalCooldowns.UNKNOWN = "?"

local sources = {}
local procs = {}

local function addSource(keys, kind, id, cd, spell)
	if not id or cd < MIN_COOLDOWN then
		return
	end
	local key = kind .. id
	local source = sources[key]
	if not source then
		source = { key = key, kind = kind, id = id, cd = cd, spell = spell }
		sources[key] = source
	elseif cd > source.cd then
		source.cd = cd
	end
	keys[#keys + 1] = key
end

local function bySourcePriority(a, b)
	local sa, sb = sources[a], sources[b]
	if sa.kind ~= sb.kind then
		return KIND_ORDER[sa.kind] < KIND_ORDER[sb.kind]
	end
	if sa.cd ~= sb.cd then
		return sa.cd > sb.cd
	end
	return sa.id > sb.id
end

for spell, entry in pairs(ns.ProcData) do
	local keys = {}
	if entry.items then
		for item, cd in pairs(entry.items) do
			addSource(keys, "i", item, cd, spell)
		end
	end
	local cd = entry.cd or 0
	addSource(keys, "e", entry.enchant, cd, spell)
	addSource(keys, "g", entry.gem, cd, spell)
	if entry.talent or entry.sets then
		addSource(keys, "s", spell, cd, spell)
	end
	if #keys > 0 then
		sort(keys, bySourcePriority)
		procs[spell] = {
			event = entry.event,
			keys = keys,
			aura = AURA_EVENTS[entry.event],
			duration = entry.duration,
		}
	end
end

local gear = {}
local learned = {}
local starts = {}
local auras = {}
local memory = {}
local playerGUID, testKeys

local function isTrinket(key)
	local source = sources[key]
	if not source or source.kind ~= "i" then
		return false
	end
	if source.trinket == nil then
		local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(source.id)
		if not equipLoc then
			return true
		end
		source.trinket = equipLoc == "INVTYPE_TRINKET"
	end
	return source.trinket
end

local function addGear(found, kind, id, slot)
	id = tonumber(id)
	if id and id > 0 then
		local key = kind .. id
		if sources[key] and not found[key] then
			found[key] = slot
		end
	end
end

local function readGear(unit)
	local found, any = {}, false
	for slot = 1, LAST_SLOT do
		local link = GetInventoryItemLink(unit, slot)
		local item, enchant, gem1, gem2, gem3
		if link then
			item, enchant, gem1, gem2, gem3 = link:match("item:(%d+):(%d*):(%d*):(%d*):(%d*)")
		else
			item = GetInventoryItemID(unit, slot)
		end
		if item then
			any = true
			addGear(found, "i", item, slot)
			addGear(found, "e", enchant, slot)
			addGear(found, "g", gem1, slot)
			addGear(found, "g", gem2, slot)
			addGear(found, "g", gem3, slot)
		end
	end
	return any and found or nil
end

local function sameGear(a, b)
	if not a then
		return false
	end
	for key, slot in pairs(a) do
		if b[key] ~= slot then
			return false
		end
	end
	for key in pairs(b) do
		if not a[key] then
			return false
		end
	end
	return true
end

local function setGear(guid, found, changedSlot)
	local old = gear[guid]
	if not changedSlot and sameGear(old, found) then
		return
	end
	local timers = starts[guid]
	if changedSlot and timers then
		for key in pairs(timers) do
			if (old and old[key] == changedSlot) or found[key] == changedSlot then
				timers[key] = nil
			end
		end
	end
	gear[guid] = found
	ns:Fire(ns.PROC_COOLDOWN_UPDATED, guid)
end

local function isLearned(list, key)
	for i = 1, list and #list or 0 do
		if list[i] == key then
			return true
		end
	end
	return false
end

local function learn(guid, key)
	local list = learned[guid]
	if not list then
		list = {}
		learned[guid] = list
	end
	if isLearned(list, key) then
		return
	end
	if isTrinket(key) then
		local count, oldest = 0, nil
		for i = 1, #list do
			if isTrinket(list[i]) then
				count = count + 1
				oldest = oldest or i
			end
		end
		if count >= MAX_TRINKETS then
			tremove(list, oldest)
		end
	end
	list[#list + 1] = key
	if guid ~= playerGUID then
		memory[guid] = { seen = time(), keys = list }
	end
end

local function pickSource(guid, keys, now)
	local owned = gear[guid]
	local known = learned[guid]
	local timers = starts[guid]
	local busy = false
	for i = 1, #keys do
		local key = keys[i]
		if (owned and owned[key]) or isLearned(known, key) then
			local start = timers and timers[key]
			if not start or now - start >= sources[key].cd then
				return key
			end
			busy = true
		end
	end
	if not busy then
		return keys[1]
	end
end

local function auraTiming(destGUID, spellId, proc, now)
	local unit = destGUID and ns.UnitByGUID(destGUID)
	if unit then
		for i = 1, MAX_AURAS do
			local name, _, _, _, _, duration, expires, _, _, _, id = UnitBuff(unit, i)
			if not name then
				break
			end
			if id == spellId and duration and duration > 0 then
				return expires - duration, duration
			end
		end
	end
	return now, proc.duration
end

local function findAura(guid, spellId)
	local list = auras[guid]
	if list then
		for key, aura in pairs(list) do
			if aura.spell == spellId then
				return key, aura
			end
		end
	end
end

local function setAura(guid, key, spellId, destGUID, proc, now)
	local list = auras[guid]
	if not list then
		list = {}
		auras[guid] = list
	end
	local aura = list[key] or {}
	aura.spell = spellId
	aura.start, aura.duration = auraTiming(destGUID, spellId, proc, now)
	list[key] = aura
end

local function onAuraRemoved(guid, spellId)
	local key = findAura(guid, spellId)
	if key then
		auras[guid][key] = nil
		ns:Fire(ns.PROC_COOLDOWN_UPDATED, guid)
	end
end

local function onCombatLogEvent(_, _, event, sourceGUID, _, sourceFlags, destGUID, _, _, spellId)
	local types = EVENT_TYPES[event]
	local proc = procs[spellId]
	if not proc or not sourceGUID then
		return
	end
	if event == "SPELL_AURA_REMOVED" then
		if proc.aura then
			onAuraRemoved(sourceGUID, spellId)
		end
		return
	end
	if not types or not types[proc.event] or band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then
		return
	end
	local now = GetTime()
	local key = pickSource(sourceGUID, proc.keys, now)
	if not key then
		local activeKey = proc.aura and findAura(sourceGUID, spellId)
		if activeKey then
			setAura(sourceGUID, activeKey, spellId, destGUID, proc, now)
			ns:Fire(ns.PROC_COOLDOWN_UPDATED, sourceGUID)
		end
		return
	end
	local timers = starts[sourceGUID]
	if not timers then
		timers = {}
		starts[sourceGUID] = timers
	end
	timers[key] = now
	if proc.aura then
		setAura(sourceGUID, key, spellId, destGUID, proc, now)
	end
	local owned = gear[sourceGUID]
	if not (owned and owned[key]) then
		learn(sourceGUID, key)
	end
	ns:Fire(ns.PROC_COOLDOWN_UPDATED, sourceGUID)
end

local function readPlayer(changedSlot)
	playerGUID = UnitGUID("player")
	local found = playerGUID and readGear("player")
	if found then
		setGear(playerGUID, found, changedSlot)
	end
end

local sortOwned

local function slotRank(slot)
	return TRINKET_SLOTS[slot] and slot - LAST_SLOT or slot
end

local function byGearSlot(a, b)
	local ra, rb = slotRank(sortOwned[a]), slotRank(sortOwned[b])
	if ra ~= rb then
		return ra < rb
	end
	return KIND_ORDER[sources[a].kind] < KIND_ORDER[sources[b].kind]
end

function InternalCooldowns:Collect(guid, list, unknownTrinkets)
	wipe(list)
	if not guid then
		return list
	end
	local owned = gear[guid]
	if owned then
		for key in pairs(owned) do
			list[#list + 1] = key
		end
		sortOwned = owned
		sort(list, byGearSlot)
		sortOwned = nil
	end
	local known = learned[guid]
	local trinkets = 0
	for i = 1, known and #known or 0 do
		local key = known[i]
		if not (owned and owned[key]) and isTrinket(key) then
			list[#list + 1] = key
			trinkets = trinkets + 1
		end
	end
	if unknownTrinkets and not owned then
		for _ = trinkets + 1, MAX_TRINKETS do
			list[#list + 1] = self.UNKNOWN
		end
	end
	for i = 1, known and #known or 0 do
		local key = known[i]
		if not (owned and owned[key]) and not isTrinket(key) then
			list[#list + 1] = key
		end
	end
	return list
end

function InternalCooldowns:HasGear(guid)
	return guid ~= nil and gear[guid] ~= nil
end

function InternalCooldowns:GetSource(key)
	return sources[key]
end

function InternalCooldowns:GetTexture(key)
	local source = sources[key]
	if not source then
		return QUESTION_MARK
	end
	if source.kind == "i" then
		return GetItemIcon(source.id) or SpellTexture(source.spell) or QUESTION_MARK
	end
	return SpellTexture(source.spell) or QUESTION_MARK
end

function InternalCooldowns:GetCooldown(guid, key)
	local timers = guid and starts[guid]
	local start = timers and timers[key]
	local source = sources[key]
	if start and source and start + source.cd > GetTime() then
		return start, source.cd
	end
end

function InternalCooldowns:GetAura(guid, key)
	local list = guid and auras[guid]
	local aura = list and list[key]
	if not aura then
		return
	end
	local limit = aura.duration or sources[key].cd
	if aura.start + limit > GetTime() then
		return aura.start, aura.duration
	end
	list[key] = nil
end

function InternalCooldowns:GetTestKeys()
	if not testKeys then
		testKeys = {}
		for key, source in pairs(sources) do
			if source.kind == "i" then
				testKeys[#testKeys + 1] = key
			end
		end
		sort(testKeys)
	end
	return testKeys
end

local function onGearReady(_, guid, unit)
	local found = readGear(unit)
	if found then
		setGear(guid, found)
	end
end

local function onEquipmentChanged(_, slot)
	readPlayer(slot)
end

local function onInventoryChanged(_, unit)
	if unit == "player" then
		readPlayer()
	end
end

local function onEnteringWorld()
	readPlayer()
end

local function loadMemory()
	local store = ns.db.procSources
	if not store then
		store = {}
		ns.db.procSources = store
	end
	memory = store
	local now = time()
	for guid, record in pairs(store) do
		local keys = type(record) == "table" and record.keys
		if not keys or not record.seen or now - record.seen > MEMORY_TIME then
			store[guid] = nil
		else
			for i = #keys, 1, -1 do
				if not sources[keys[i]] then
					tremove(keys, i)
				end
			end
			if #keys == 0 then
				store[guid] = nil
			else
				learned[guid] = keys
			end
		end
	end
end

local function applyEnabled(self)
	if ns.Config.internalCooldowns.enabled then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLogEvent)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
		self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", onEquipmentChanged)
		self:RegisterEvent("UNIT_INVENTORY_CHANGED", onInventoryChanged)
		self:RegisterEvent(ns.INSPECT_GEAR_READY, onGearReady)
		readPlayer()
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
		self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
		self:UnregisterEvent(ns.INSPECT_GEAR_READY)
		wipe(starts)
		wipe(auras)
		wipe(gear)
		ns:Fire(ns.PROC_COOLDOWN_UPDATED)
	end
end

function InternalCooldowns:Initialize()
	loadMemory()
	applyEnabled(self)
	self:WatchConfig("internalCooldowns.enabled", applyEnabled)
end
