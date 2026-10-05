local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")
local UF = ns:GetModule("UnitFrames")

local UnitGUID, UnitName, UnitIsUnit, UnitCanAttack = UnitGUID, UnitName, UnitIsUnit, UnitCanAttack
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local band = bit.band

local config = ns.Config.namePlates
local frameConfig = ns.Config.unitFrames
local plates = NamePlates.plates
local guidPlates = NamePlates.guidPlates
local targetOf = NamePlates.targetOf
local EVENT_UNITS = NamePlates.EVENT_UNITS
local importantCasts = UF.importantCasts

local BORDER_INSET = NamePlates.BORDER_INSET
local ICON_GAP = NamePlates.ICON_GAP
local FINISH_WINDOW = NamePlates.CAST_FINISH_WINDOW
local LATE_INTERRUPT = NamePlates.CAST_LATE_INTERRUPT
local STOP_TIMEOUT = 0.5
local INSTANT_WINDOW = 0.2
local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local CANCELLED = {}

local INSTANT_PROCS = {
	[12043] = true, -- Presence of Mind
	[48108] = { 11366 }, -- Hot Streak (Pyroblast)
	[57761] = { 133, 44614 }, -- Fireball! (Fireball, Frostfire Bolt)
	[54741] = { 2120 }, -- Firestarter (Flamestrike)
	[59578] = { 879, 19750 }, -- The Art of War (Exorcism, Flash of Light)
	[54149] = { 19750 }, -- Infusion of Light (Flash of Light)
	[33151] = { 585, 2061 }, -- Surge of Light (Smite, Flash Heal)
	[16166] = { 403, 421, 51505 }, -- Elemental Mastery (Lightning Bolt, Chain Lightning, Lava Burst)
	[53817] = { 403, 421, 331, 8004, 1064, 51514 }, -- Maelstrom Weapon (Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, Chain Heal, Hex)
	[16188] = true, -- Nature's Swiftness
	[17116] = true, -- Nature's Swiftness
	[69369] = true, -- Predator's Swiftness
	[17941] = { 686 }, -- Shadow Trance (Shadow Bolt)
	[34936] = { 686, 29722 }, -- Backlash (Shadow Bolt, Incinerate)
}

local procSpells = {}
for auraId, spells in pairs(INSTANT_PROCS) do
	if spells == true then
		procSpells[auraId] = true
	else
		local names = {}
		for i = 1, #spells do
			local name = GetSpellInfo(spells[i])
			if name then
				names[name] = true
			end
		end
		procSpells[auraId] = names
	end
end

local casts = {}
local pool = {}
local castTimes = {}
local lastStop = {}
local lastTexture = {}

local updatePlate

local function acquire(guid)
	local entry = casts[guid]
	if not entry then
		local count = #pool
		entry = pool[count] or {}
		pool[count] = nil
		casts[guid] = entry
	end
	return entry
end

local function unitCast(unit)
	local guid = UnitGUID(unit)
	return guid, guid and casts[guid]
end

local function refreshGUID(guid)
	local plate = guidPlates[guid]
	if plate then
		updatePlate(plate)
	end
end

local function unitLocked(unit, notInterruptible)
	if notInterruptible then
		return true
	end
	if not ns.HasCastImmunity then
		return false
	end
	if not EVENT_UNITS[unit] then
		ns.Auras.Invalidate(unit)
	end
	return ns.HasCastImmunity(unit) or false
end

local function removeCast(guid, result)
	local entry = casts[guid]
	if not entry then
		return
	end
	casts[guid] = nil
	pool[#pool + 1] = entry

	local plate = guidPlates[guid]
	local bar = plate and plate.vcast
	if not (bar and bar:IsShown() and bar.entry == entry) then
		return
	end
	bar.entry = nil
	bar:Hide()
	lastStop[guid] = GetTime()
	lastTexture[guid] = entry.texture
	if result == true then
		NamePlates.ShowCastResult(plate, entry.texture, bar.icon:IsShown(), entry.locked)
	elseif result == CANCELLED then
		NamePlates.ShowCastResult(plate, entry.texture, bar.icon:IsShown(), entry.locked, nil, true)
	elseif result then
		NamePlates.ShowCastResult(plate, entry.texture, bar.icon:IsShown(), entry.locked, result)
	end
end

local function recordUnitCast(unit)
	local guid = UnitGUID(unit)
	if not guid then
		return
	end
	local isChannel = false
	local name, _, _, texture, startTime, endTime, _, castId, notInterruptible = UnitCastingInfo(unit)
	if not name then
		isChannel = true
		name, _, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
		castId = nil
	end
	if not name then
		if casts[guid] then
			removeCast(guid)
		end
		return
	end
	local entry = acquire(guid)
	entry.name = name
	entry.texture = texture
	entry.startTime = startTime / 1e3
	entry.endTime = endTime / 1e3
	entry.isChannel = isChannel
	entry.castId = castId
	if not EVENT_UNITS[unit] then
		notInterruptible = nil
	end
	entry.locked = unitLocked(unit, notInterruptible)
	entry.fromLog = false
	refreshGUID(guid)
end

local layoutBar = NamePlates.LayoutCastbar

local function updateBarTarget(bar, unit)
	local targetUnit = unit and targetOf[unit]
	local name = targetUnit
		and frameConfig.castbarTargetName
		and not UnitIsUnit(targetUnit, unit)
		and UnitName(targetUnit)
	if name then
		UF.SetCastTargetText(bar.targetText, targetUnit, name)
	else
		bar.targetText:SetText("")
	end
	local targetingYou = targetUnit
		and frameConfig.castbarTargetingYou
		and UnitIsUnit(targetUnit, "player")
		and UnitCanAttack("player", unit)
	local color = targetingYou and frameConfig.castbarTargetingYouColor or frameConfig.borderColor
	bar.holder:SetBackdropBorderColor(color[1], color[2], color[3])
end

local function isTracked(plate, entry)
	return entry.fromLog or NamePlates.GetPlateUnit(plate) ~= nil
end

local function onBarUpdate(bar, elapsed)
	local entry = bar.entry
	local now = GetTime()
	local plate = bar:GetParent()
	if now > entry.endTime + STOP_TIMEOUT or not isTracked(plate, entry) then
		if plate.guid and casts[plate.guid] == entry then
			removeCast(plate.guid)
		else
			bar.entry = nil
			bar:Hide()
		end
		return
	end
	if entry.isChannel then
		bar:SetValue(entry.startTime + entry.endTime - now)
	else
		bar:SetValue(now)
	end
	if bar.important then
		UF.PulseCastGlow(bar.glow, elapsed)
	end
end

local function applyLock(bar, locked)
	NamePlates.ApplyShield(bar, locked)
	local color = locked and config.castbarLockedColor or config.castbarColor
	bar:SetStatusBarColor(color[1], color[2], color[3])
end

local function createBar(plate)
	local level = plate:GetFrameLevel()
	local bar = CreateFrame("StatusBar", nil, plate)
	bar:Hide()
	bar:SetFrameLevel(level + 1)
	ns.SkinStatusBar(bar)

	local holder = NamePlates.CreateHolder(bar, level)
	holder:SetPoint("TOPLEFT", -BORDER_INSET, BORDER_INSET)
	holder:SetPoint("BOTTOMRIGHT", BORDER_INSET, -BORDER_INSET)
	bar.holder = holder

	local icon = bar:CreateTexture(nil, "BORDER")
	icon:SetPoint("RIGHT", holder, "LEFT", -ICON_GAP, 0)
	NamePlates.SkinIcon(bar, icon)
	bar.icon = icon

	NamePlates.CreateShield(bar)

	NamePlates.CreateCastTexts(bar)

	bar.glow = UF.CreateCastGlow(bar, holder, NamePlates.CAST_GLOW_SIZE)
	bar:SetScript("OnUpdate", onBarUpdate)
	plate.vcast = bar
	if plate.stackLevel then
		plate:ApplyStackLevel()
	end
	return bar
end

local function hideBar(plate)
	local bar = plate.vcast
	if bar then
		bar.entry = nil
		bar:Hide()
	end
end

function updatePlate(plate)
	local entry = plate.guid and casts[plate.guid]
	if
		not entry
		or not config.castbarsAllPlates
		or not plate.settings.showCastbar
		or not plate:IsShown()
		or plate.castbar:IsShown()
		or plate.totemSpell
		or plate.hiddenByName
		or GetTime() > entry.endTime
		or not isTracked(plate, entry)
	then
		hideBar(plate)
		return
	end

	local bar = plate.vcast or createBar(plate)
	if bar.entry ~= entry or not bar:IsShown() or bar.compact ~= (plate.unitIcon ~= nil) then
		layoutBar(bar)
		bar.icon:SetTexture(entry.texture)
		bar.spellText:SetText(config.castbarSpellName and entry.name or "")
		bar.important = frameConfig.castbarImportant and importantCasts[entry.name] or false
		if bar.important then
			UF.StartCastGlow(bar.glow, frameConfig.castbarImportantColor)
		else
			bar.glow:Hide()
		end
		plate.castbar.result:Hide()
	end
	bar.entry = entry
	bar:SetMinMaxValues(entry.startTime, entry.endTime)
	applyLock(bar, entry.locked)
	updateBarTarget(bar, NamePlates.GetPlateUnit(plate))
	bar:Show()
end
NamePlates.UpdateVirtualCast = updatePlate

local function onCastEvent(_, unit)
	recordUnitCast(unit)
end

local function onCastStop(_, unit)
	local guid, entry = unitCast(unit)
	if entry then
		removeCast(guid, GetTime() >= entry.endTime - FINISH_WINDOW)
	end
end

local function onCastFailed(_, unit, _, _, castId)
	local guid, entry = unitCast(unit)
	if entry and (entry.fromLog or entry.castId == castId) then
		removeCast(guid)
	end
end

local function onCastInterrupted(_, unit, _, _, castId)
	local guid, entry = unitCast(unit)
	if entry and (entry.isChannel or entry.fromLog or entry.castId == castId) then
		removeCast(guid, frameConfig.castbarInterrupter and (UF.RecentSilence(guid) or CANCELLED) or nil)
	end
end

local function setLocked(unit, locked)
	local guid, entry = unitCast(unit)
	if entry then
		entry.locked = locked or unitLocked(unit)
		refreshGUID(guid)
	end
end

local function onInterruptible(_, unit)
	setLocked(unit, false)
end

local function onNotInterruptible(_, unit)
	setLocked(unit, true)
end

local function onUnitAura(_, unit)
	local guid, entry = unitCast(unit)
	if entry and ns.HasCastImmunity then
		local locked = ns.HasCastImmunity(unit) or false
		if locked ~= entry.locked then
			entry.locked = locked
			refreshGUID(guid)
		end
	end
end

local function onInterrupter(_, guid, text)
	if not frameConfig.castbarInterrupter then
		return
	end
	local plate = guidPlates[guid]
	if not plate or plate.castbar:IsShown() then
		return
	end
	if casts[guid] then
		removeCast(guid, text)
		return
	end
	local result = plate.castbar.result
	if result:IsShown() and result.interrupted then
		result.text:SetText(text)
	elseif GetTime() - (lastStop[guid] or 0) < LATE_INTERRUPT then
		NamePlates.ShowCastResult(plate, lastTexture[guid], true, false, text)
	end
end

local function onSilenced(_, guid, text)
	if not frameConfig.castbarInterrupter or casts[guid] then
		return
	end
	local plate = guidPlates[guid]
	if not plate or plate.castbar:IsShown() then
		return
	end
	local result = plate.castbar.result
	if result:IsShown() and result.cancelled and GetTime() - (lastStop[guid] or 0) < LATE_INTERRUPT then
		NamePlates.ShowCastResult(plate, lastTexture[guid], result.icon:IsShown(), false, text)
	end
end

local function spellCastTime(spellId)
	local castTime = castTimes[spellId]
	if castTime == nil then
		local _, _, _, _, _, _, time = GetSpellInfo(spellId)
		castTime = time and time > 0 and time / 1e3 or false
		castTimes[spellId] = castTime
	end
	return castTime
end

local function isEnemyPlayer(flags)
	return band(flags, TYPE_PLAYER) > 0 and band(flags, REACTION_HOSTILE) > 0
end

local function guidUnit(guid)
	local plate = guidPlates[guid]
	return plate and NamePlates.GetPlateUnit(plate) or ns.UnitByGUID(guid)
end

local function onLogCastStart(srcGUID, srcFlags, _, _, spellId, spellName)
	if not config.castbarsCombatLog or not isEnemyPlayer(srcFlags) then
		return
	end
	local now = GetTime()
	local entry = casts[srcGUID]
	if entry and not entry.fromLog and entry.endTime > now then
		return
	end
	local unit = guidUnit(srcGUID)
	if unit then
		recordUnitCast(unit)
		return
	end
	local castTime = spellCastTime(spellId)
	if not castTime then
		return
	end
	entry = acquire(srcGUID)
	entry.name = spellName
	entry.texture = ns.SpellTexture(spellId)
	entry.startTime = now
	entry.endTime = now + castTime
	entry.isChannel = false
	entry.castId = nil
	entry.locked = false
	entry.fromLog = true
	refreshGUID(srcGUID)
end

local function isInstantCast(spellId)
	local _, _, _, cost, _, _, castTime = GetSpellInfo(spellId)
	return castTime == 0 and cost and cost > 0
end

local function onLogCastSuccess(srcGUID, _, _, _, spellId, spellName)
	local entry = casts[srcGUID]
	if not entry or entry.isChannel then
		return
	end
	if entry.name == spellName then
		removeCast(srcGUID, true)
	elseif entry.fromLog and isInstantCast(spellId) then
		removeCast(srcGUID)
	end
end

local function onLogProcRemoved(_, _, dstGUID, _, spellId)
	local spells = procSpells[spellId]
	local entry = spells and casts[dstGUID]
	if not entry or not entry.fromLog or spells ~= true and not spells[entry.name] then
		return
	end
	removeCast(dstGUID, GetTime() - entry.startTime > INSTANT_WINDOW)
end

local function onLogInterrupt(_, _, dstGUID)
	if casts[dstGUID] and not frameConfig.castbarInterrupter then
		removeCast(dstGUID)
	end
end

local function onLogDied(_, _, dstGUID)
	if casts[dstGUID] then
		removeCast(dstGUID)
	end
end

local function onUnitAdded(plate, unit)
	if UnitGUID(unit) == plate.guid then
		recordUnitCast(unit)
	end
	updatePlate(plate)
end

local function onUnitRemoved(plate)
	local guid = plate.guid
	local entry = guid and casts[guid]
	if entry and not entry.fromLog and not NamePlates.GetPlateUnit(plate) then
		removeCast(guid)
	end
end

local function onPass(now)
	for guid, entry in pairs(casts) do
		if now > entry.endTime + STOP_TIMEOUT then
			removeCast(guid)
		end
	end
	if not config.castbarsAllPlates then
		return
	end
	for i = 1, #plates do
		local plate = plates[i]
		local unit = plate:IsShown() and NamePlates.GetPlateUnit(plate)
		if unit then
			if not EVENT_UNITS[unit] then
				recordUnitCast(unit)
			end
			local bar = plate.vcast
			if bar and bar:IsShown() then
				updateBarTarget(bar, unit)
			end
		end
	end
end

local function onEnteringWorld()
	for guid in pairs(casts) do
		removeCast(guid)
	end
	wipe(lastStop)
	wipe(lastTexture)
end

local function relayout(plate)
	hideBar(plate)
	updatePlate(plate)
end

local function applyConfig()
	for i = 1, #plates do
		local plate = plates[i]
		local bar = plate.vcast
		if bar then
			NamePlates.StyleHolder(bar.holder)
			NamePlates.StyleCastTexts(bar)
		end
		relayout(plate)
	end
end

local UNIT_EVENTS = {
	UNIT_SPELLCAST_START = onCastEvent,
	UNIT_SPELLCAST_CHANNEL_START = onCastEvent,
	UNIT_SPELLCAST_DELAYED = onCastEvent,
	UNIT_SPELLCAST_CHANNEL_UPDATE = onCastEvent,
	UNIT_SPELLCAST_STOP = onCastStop,
	UNIT_SPELLCAST_CHANNEL_STOP = onCastStop,
	UNIT_SPELLCAST_FAILED = onCastFailed,
	UNIT_SPELLCAST_FAILED_QUIET = onCastFailed,
	UNIT_SPELLCAST_INTERRUPTED = onCastInterrupted,
	UNIT_AURA = onUnitAura,
}

local LOCK_EVENTS = {
	UNIT_SPELLCAST_INTERRUPTIBLE = onInterruptible,
	UNIT_SPELLCAST_NOT_INTERRUPTIBLE = onNotInterruptible,
}

local LOCK_UNITS = { "target", "focus" }

NamePlates:OnInitialize(function(self)
	if not config.enabled then
		return
	end
	for event, handler in pairs(UNIT_EVENTS) do
		for unit in pairs(EVENT_UNITS) do
			self:RegisterUnitEvent(event, unit, handler)
		end
	end
	for event, handler in pairs(LOCK_EVENTS) do
		for i = 1, #LOCK_UNITS do
			self:RegisterUnitEvent(event, LOCK_UNITS[i], handler)
		end
	end
	NamePlates.AddLogHandler("SPELL_CAST_START", onLogCastStart)
	NamePlates.AddLogHandler("SPELL_CAST_SUCCESS", onLogCastSuccess)
	NamePlates.AddLogHandler("SPELL_AURA_REMOVED", onLogProcRemoved)
	NamePlates.AddLogHandler("SPELL_INTERRUPT", onLogInterrupt)
	NamePlates.AddLogHandler("UNIT_DIED", onLogDied)
	NamePlates.onIdentity[#NamePlates.onIdentity + 1] = updatePlate
	NamePlates.onUnitAdded[#NamePlates.onUnitAdded + 1] = onUnitAdded
	NamePlates.onUnitRemoved[#NamePlates.onUnitRemoved + 1] = onUnitRemoved
	NamePlates.onPass[#NamePlates.onPass + 1] = onPass
	NamePlates.onPlateLayout[#NamePlates.onPlateLayout + 1] = relayout
	self:RegisterEvent(UF.CAST_INTERRUPTED, onInterrupter)
	self:RegisterEvent(UF.CAST_SILENCED, onSilenced)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	self:WatchConfig("namePlates", applyConfig)
	self:WatchConfig("unitFrames", applyConfig)
end)
