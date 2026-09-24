local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local UnitGUID, UnitIsPlayer, UnitCanAttack = UnitGUID, UnitIsPlayer, UnitCanAttack
local GetTime = GetTime
local band = bit.band
local sort, tremove = table.sort, table.remove
local huge, max = math.huge, math.max

local Auras = ns.Auras
local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText
local DR = ns:GetModule("DiminishingReturns")
local DR_SPELLS = ns.DRData.SPELLS
local Data = NamePlates.AuraData
local ClassifyDebuff, ClassifyBuff, Duration = Data.ClassifyDebuff, Data.ClassifyBuff, Data.Duration
local KIND_OWN_CC, KIND_CC, KIND_DEFENSIVE = Data.KIND_OWN_CC, Data.KIND_CC, Data.KIND_DEFENSIVE
local KIND_OWN, KIND_PURGE, KIND_OTHER = Data.KIND_OWN, Data.KIND_PURGE, Data.KIND_OTHER

local config = ns.Config.namePlates
local plates = NamePlates.plates
local guidPlates = NamePlates.guidPlates
local EVENT_UNITS = NamePlates.EVENT_UNITS

local ICON_RATIO = 0.65
local DURATION_BAR_HEIGHT = 2
local TIMER_INTERVAL = 0.1
local EXACT_INTERVAL = 1
local SWEEP_INTERVAL = 10
local SAME_SCAN = 0.02
local DR_SETTLE = 0.05
local CROP_Y = (1 - ICON_RATIO) / 2
local COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE

local cache = {}
local setPool, entryPool = {}, {}
local dirty = {}
local learned = {}
local playerGUID, petGUID
local nextSweep = 0

local function getSet(guid)
	local set = cache[guid]
	if not set then
		local count = #setPool
		set = setPool[count] or { exactAt = 0 }
		setPool[count] = nil
		set.exactAt = 0
		cache[guid] = set
	end
	return set
end

local function clearSet(set)
	for i = #set, 1, -1 do
		entryPool[#entryPool + 1] = set[i]
		set[i] = nil
	end
end

local function releaseSet(guid)
	local set = cache[guid]
	if set then
		clearSet(set)
		cache[guid] = nil
		setPool[#setPool + 1] = set
	end
end

local function addEntry(set)
	local count = #entryPool
	local entry = entryPool[count] or {}
	entryPool[count] = nil
	set[#set + 1] = entry
	return entry
end

local function findEntry(set, spellId)
	for i = 1, #set do
		if set[i].spellId == spellId then
			return set[i], i
		end
	end
end

local function removeEntry(set, index)
	entryPool[#entryPool + 1] = tremove(set, index)
end

local function auraOrder(a, b)
	if a.kind ~= b.kind then
		return a.kind < b.kind
	end
	local aExpires, bExpires = a.expires, b.expires
	return (aExpires > 0 and aExpires or huge) < (bExpires > 0 and bExpires or huge)
end

local updatePlate

local function flush()
	for guid in pairs(dirty) do
		dirty[guid] = nil
		local plate = guidPlates[guid]
		if plate then
			updatePlate(plate)
		end
	end
end

local function markDirty(guid)
	dirty[guid] = true
	ns.Defer(dirty, flush)
end

local function isOwn(caster)
	return caster == "player" or caster == "pet" or caster == "vehicle"
end

local function learn(spellId, duration)
	if duration and duration > 0 and (learned[spellId] or 0) < duration then
		learned[spellId] = duration
	end
end

local function fill(entry, spellId, name, icon, count, duration, expires, kind)
	entry.spellId = spellId
	entry.name = name
	entry.icon = icon
	entry.count = count or 0
	entry.duration = duration or 0
	entry.expires = expires or 0
	entry.kind = kind
end

local function exactScan(unit, guid, now)
	local set = getSet(guid)
	if now - set.exactAt < SAME_SCAN then
		return
	end
	clearSet(set)
	if not EVENT_UNITS[unit] then
		Auras.Invalidate(unit)
	end
	local isPlayer = UnitIsPlayer(unit)

	local auras, count = Auras.Get(unit, "HARMFUL")
	for i = 1, count do
		local aura = auras[i]
		local kind = ClassifyDebuff(aura.spellId, aura.name, isOwn(aura.caster))
		if kind then
			fill(addEntry(set), aura.spellId, aura.name, aura.icon, aura.count, aura.duration, aura.expires, kind)
			if isPlayer then
				learn(aura.spellId, aura.duration)
			end
		end
	end

	if config.enemyBuffs and UnitCanAttack("player", unit) then
		auras, count = Auras.Get(unit, "HELPFUL")
		for i = 1, count do
			local aura = auras[i]
			local kind = ClassifyBuff(aura.spellId, aura.name, aura.debuffType, aura.duration)
			if kind then
				fill(addEntry(set), aura.spellId, aura.name, aura.icon, aura.count, aura.duration, aura.expires, kind)
				if isPlayer then
					learn(aura.spellId, aura.duration)
				end
			end
		end
	end

	set.exactAt = now
	sort(set, auraOrder)
	markDirty(guid)
end

local function drFactor(guid, category, now)
	local state = DR:Get(guid)
	local entry = state and state[category]
	if not entry or entry.stacks == 0 then
		return 1
	end
	local stacks = entry.stacks
	if now - entry.appliedAt > DR_SETTLE then
		stacks = stacks + 1
	end
	if stacks <= 1 then
		return 1
	elseif stacks == 2 then
		return 0.5
	end
	return 0.25
end

local function onAuraApplied(srcGUID, _, dstGUID, dstFlags, spellId, spellName, _, auraType)
	if band(dstFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == 0 then
		return
	end
	local isBuff = auraType == "BUFF"
	local kind
	if isBuff then
		if not config.enemyBuffs or band(dstFlags, REACTION_HOSTILE) == 0 then
			return
		end
		kind = ClassifyBuff(spellId, spellName)
	else
		kind = ClassifyDebuff(spellId, spellName, srcGUID == playerGUID or srcGUID == petGUID)
	end
	if not kind then
		return
	end
	local duration = Duration(spellId, spellName, learned)
	if not duration then
		return
	end
	local now = GetTime()
	local category = not isBuff and DR_SPELLS[spellId]
	if category and band(dstFlags, TYPE_PLAYER) > 0 then
		duration = duration * drFactor(dstGUID, category, now)
	end

	local set = getSet(dstGUID)
	local entry = findEntry(set, spellId)
	if not entry then
		entry = addEntry(set)
		fill(entry, spellId, spellName, ns.SpellTexture(spellId), 0, duration, now + duration, kind)
	else
		entry.duration = duration
		entry.expires = now + duration
		entry.kind = kind
	end
	sort(set, auraOrder)
	markDirty(dstGUID)
end

local function onAuraDose(_, _, dstGUID, _, spellId, _, _, _, amount)
	local set = cache[dstGUID]
	local entry = set and findEntry(set, spellId)
	if entry and amount then
		entry.count = amount
		markDirty(dstGUID)
	end
end

local function onAuraRemoved(_, _, dstGUID, _, spellId)
	local set = cache[dstGUID]
	if not set then
		return
	end
	local _, index = findEntry(set, spellId)
	if index then
		removeEntry(set, index)
		markDirty(dstGUID)
	end
end

local function onUnitDied(_, _, dstGUID)
	if cache[dstGUID] then
		releaseSet(dstGUID)
		markDirty(dstGUID)
	end
end

local rows = {}
local rowCount = 0
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker.nextTick = 0

local function createIcon(row, index)
	local texture = row:CreateTexture(nil, "BORDER")
	texture:SetNonBlocking(true)
	texture:SetTexCoord(0, 1, CROP_Y, 1 - CROP_Y)
	NamePlates.SkinIcon(row, texture)

	local timer = row:CreateFontString(nil, "OVERLAY")
	timer:SetPoint("CENTER", texture)
	texture.timer = timer

	local bar = row:CreateTexture(nil, "OVERLAY")
	bar:SetTexture(ns.Media.blank)
	bar:SetVertexColor(unpack(ns.Config.unitFrames.castbarColor))
	bar:SetHeight(DURATION_BAR_HEIGHT)
	bar:SetPoint("BOTTOMLEFT", texture, 1, 1)
	texture.bar = bar

	local count = row:CreateFontString(nil, "OVERLAY")
	count:SetPoint("BOTTOMRIGHT", texture, -1, 1)
	texture.count = count

	ns.SetFont(timer, config.auraFont.size, config.auraFont.outline)
	ns.SetFont(count, config.auraFont.size, config.auraFont.outline)
	row.icons[index] = texture
	return texture
end

local function setIconShown(icon, shown)
	if shown then
		icon:Show()
		icon.border:Show()
	else
		icon:Hide()
		icon.border:Hide()
		icon.timer:Hide()
		icon.bar:Hide()
		icon.count:Hide()
	end
end

local function createRow(plate)
	local row = CreateFrame("Frame", nil, plate.overlay)
	row:Hide()
	row.icons = {}
	row.count = 0
	row.plate = plate
	plate.auraRow = row
	if plate.stackLevel then
		plate:ApplyStackLevel()
	end
	return row
end

local function hideRow(row)
	row:Hide()
	row.count = 0
end

local function showRow(row)
	if not row.active then
		row.active = true
		rowCount = rowCount + 1
		rows[rowCount] = row
	end
	row:Show()
	ticker.nextTick = 0
	ticker:Show()
end

local function kindShown(kind)
	if kind == KIND_OWN_CC or kind == KIND_CC then
		return true
	elseif kind == KIND_DEFENSIVE or kind == KIND_PURGE then
		return config.enemyBuffs
	elseif kind == KIND_OWN then
		return config.ownDebuffs
	elseif kind == KIND_OTHER then
		return config.otherDebuffs
	end
end

local function placeIcon(icon, x, size)
	local height = size * ICON_RATIO
	if icon.size ~= size then
		icon.size = size
		icon:SetSize(size, height)
	end
	icon:SetPoint("BOTTOMLEFT", icon:GetParent(), "BOTTOMLEFT", x, 0)
	return height
end

function updatePlate(plate)
	local row = plate.auraRow
	local set = plate.guid and cache[plate.guid]
	if
		not (config.showAuras and set and set[1] and plate:IsShown())
		or plate.totem:IsShown()
		or not (config.aurasAllPlates or plate:IsTarget())
	then
		if row then
			hideRow(row)
		end
		return
	end
	row = row or createRow(plate)

	local now = GetTime()
	local maxIcons, gap = config.maxAuraIcons, config.auraGap
	local showTimer, showCount = config.showAuraTimer, config.showAuraCount
	local shown, x, height = 0, 0, 0
	for i = 1, #set do
		local entry = set[i]
		local expires = entry.expires
		if (expires == 0 or expires > now) and kindShown(entry.kind) then
			shown = shown + 1
			local icon = row.icons[shown] or createIcon(row, shown)
			local cc = entry.kind == KIND_OWN_CC or entry.kind == KIND_CC
			local size = cc and config.ccAuraSize or config.auraSize
			height = max(height, placeIcon(icon, x, size))
			x = x + size + gap
			icon:SetTexture(entry.icon)
			setIconShown(icon, true)
			local duration = entry.duration
			if duration > 0 and expires > 0 then
				icon.duration, icon.endTime = duration, expires
				ns.SetShown(icon.timer, showTimer)
				icon.bar:Show()
			else
				icon.endTime = nil
				icon.timer:Hide()
				icon.bar:Hide()
			end
			if showCount and entry.count > 1 then
				icon.count:SetFormattedText("%d", entry.count)
				icon.count:Show()
			else
				icon.count:Hide()
			end
			if shown == maxIcons then
				break
			end
		end
	end

	local icons = row.icons
	for i = shown + 1, #icons do
		setIconShown(icons[i], false)
	end

	row.count = shown
	if shown == 0 then
		hideRow(row)
		return
	end
	row:SetSize(x - gap, height)
	row:SetPoint("BOTTOM", plate.holder, "TOP", 0, config.auraRowGap)
	showRow(row)
end

local function updateTimers(row, now)
	local icons = row.icons
	for i = 1, row.count do
		local icon = icons[i]
		if icon.endTime then
			local remain = icon.endTime - now
			if remain > 0 then
				SetTimerText(icon.timer, remain)
				icon.bar:SetWidth(max((icon.size - 2) * remain / icon.duration, 0.1))
			else
				icon.endTime = nil
				local guid = row.plate.guid
				if guid then
					markDirty(guid)
				end
			end
		end
	end
end

ticker:SetScript("OnUpdate", function(self)
	local now = GetTime()
	if now < self.nextTick then
		return
	end
	self.nextTick = now + TIMER_INTERVAL
	local i = 1
	while i <= rowCount do
		local row = rows[i]
		if row:IsShown() and row.count > 0 then
			updateTimers(row, now)
			i = i + 1
		else
			row.active = false
			rows[i] = rows[rowCount]
			rows[rowCount] = nil
			rowCount = rowCount - 1
		end
	end
	if rowCount == 0 then
		self:Hide()
	end
end)

local function onUnitAura(_, unit)
	local guid = UnitGUID(unit)
	if guid and guidPlates[guid] then
		exactScan(unit, guid, GetTime())
	end
end

local function onIdentity(plate)
	local unit = NamePlates.GetPlateUnit(plate)
	if unit then
		exactScan(unit, plate.guid, GetTime())
	end
	updatePlate(plate)
end

local function sweep(now)
	for guid, set in pairs(cache) do
		for i = #set, 1, -1 do
			local expires = set[i].expires
			if expires > 0 and expires <= now then
				removeEntry(set, i)
			end
		end
		if not set[1] and not guidPlates[guid] then
			releaseSet(guid)
		end
	end
end

local function onPass(now)
	for i = 1, #plates do
		local plate = plates[i]
		local unit, guid = plate.unit, plate.guid
		if unit and guid and not EVENT_UNITS[unit] and plate:IsShown() then
			local set = cache[guid]
			if not set or now - set.exactAt >= EXACT_INTERVAL then
				if UnitGUID(unit) == guid then
					exactScan(unit, guid, now)
				end
			end
		end
	end
	if now >= nextSweep then
		nextSweep = now + SWEEP_INTERVAL
		sweep(now)
	end
end

local function onPlateHide(plate)
	if plate.auraRow then
		hideRow(plate.auraRow)
	end
end

local function onEnteringWorld()
	playerGUID = UnitGUID("player")
	petGUID = UnitGUID("pet")
	for guid in pairs(cache) do
		releaseSet(guid)
	end
end

local function onUnitPet(_, unit)
	if unit == "player" then
		petGUID = UnitGUID("pet")
	end
end

local function applyConfig()
	for i = 1, #plates do
		local plate = plates[i]
		local row = plate.auraRow
		if row then
			local icons = row.icons
			for j = 1, #icons do
				local icon = icons[j]
				ns.SetFont(icon.timer, config.auraFont.size, config.auraFont.outline)
				ns.SetFont(icon.count, config.auraFont.size, config.auraFont.outline)
				icon.size = nil
			end
		end
		updatePlate(plate)
	end
end

NamePlates:OnInitialize(function(self)
	if not config.enabled then
		return
	end
	local db = ns.db
	learned = db.namePlateAuraDurations or learned
	db.namePlateAuraDurations = learned
	playerGUID = UnitGUID("player")

	for unit in pairs(EVENT_UNITS) do
		self:RegisterUnitEvent("UNIT_AURA", unit, onUnitAura)
	end
	NamePlates.AddLogHandler("SPELL_AURA_APPLIED", onAuraApplied)
	NamePlates.AddLogHandler("SPELL_AURA_REFRESH", onAuraApplied)
	NamePlates.AddLogHandler("SPELL_AURA_APPLIED_DOSE", onAuraDose)
	NamePlates.AddLogHandler("SPELL_AURA_REMOVED_DOSE", onAuraDose)
	NamePlates.AddLogHandler("SPELL_AURA_REMOVED", onAuraRemoved)
	NamePlates.AddLogHandler("SPELL_AURA_BROKEN", onAuraRemoved)
	NamePlates.AddLogHandler("SPELL_AURA_BROKEN_SPELL", onAuraRemoved)
	NamePlates.AddLogHandler("UNIT_DIED", onUnitDied)
	NamePlates.onIdentity[#NamePlates.onIdentity + 1] = onIdentity
	NamePlates.onPass[#NamePlates.onPass + 1] = onPass
	NamePlates.onPlateHide[#NamePlates.onPlateHide + 1] = onPlateHide
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	self:RegisterUnitEvent("UNIT_PET", "player", onUnitPet)
	self:WatchConfig("namePlates", applyConfig)
end)
