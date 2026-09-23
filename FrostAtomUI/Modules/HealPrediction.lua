local _, ns = ...

local UnitGUID, UnitName = UnitGUID, UnitName
local UnitExists, UnitCanAssist = UnitExists, UnitCanAssist
local UnitCastingInfo, UnitHealthMax = UnitCastingInfo, UnitHealthMax
local GetSpellInfo, GetTime = GetSpellInfo, GetTime
local pairs, next, wipe, select = pairs, next, wipe, select

local HealComm = LibStub("LibHealComm-4.0", true)

local Prediction = ns:NewModule("HealPrediction")
ns.HealPrediction = Prediction
Prediction.CHANGED = "FrostAtomUI_PREDICTION_CHANGED"

local HEALCOMM_WINDOW = 3
local HEALCOMM_CALLBACKS = {
	"HealComm_HealStarted",
	"HealComm_HealUpdated",
	"HealComm_HealDelayed",
	"HealComm_HealStopped",
}
local CAST_GRACE = 0.3
local FALLBACK_CAST_TIME = 3
local TICK_INTERVAL = 0.25
local BREAK_WINDOW = 0.5
local CHAIN_JUMP_RATIO = 0.6
local DIVINE_AEGIS_RATIO = 0.3
local GLOW_WIDTH = 6
local MIN_WIDTH = 1

local HEAL_SPELLS = {
	[48071] = 2050, -- Flash Heal
	[48063] = 4300, -- Greater Heal
	[48120] = 2240, -- Binding Heal
	[48782] = 5170, -- Holy Light
	[48785] = 830, -- Flash of Light
	[49273] = 3250, -- Healing Wave
	[49276] = 1740, -- Lesser Healing Wave
	[55459] = 1130, -- Chain Heal
	[48378] = 4090, -- Healing Touch
	[50464] = 2040, -- Nourish
	[48443] = 2360, -- Regrowth
}

local DIVINE_AEGIS = 47753 -- Divine Aegis

local SHIELDS = {}

local function addShield(amount, duration, fraction, ...)
	local info = { amount = amount, duration = duration, fraction = fraction }
	for i = 1, select("#", ...) do
		SHIELDS[select(i, ...)] = info
	end
end

addShield(4000, 30, nil, 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218, 48065, 48066) -- Power Word: Shield
addShield(1500, 12, nil, DIVINE_AEGIS)
addShield(1500, 6, nil, 58597) -- Sacred Shield
addShield(5000, 60, nil, 11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039) -- Ice Barrier
addShield(3000, 60, nil, 1463, 8494, 8495, 10191, 10192, 10193, 27131, 43019, 43020) -- Mana Shield
addShield(2500, 30, nil, 543, 8457, 8458, 10223, 10225, 27128, 43010) -- Fire Ward
addShield(2500, 30, nil, 6143, 8461, 8462, 10177, 28609, 32796, 43012) -- Frost Ward
addShield(3500, 30, nil, 6229, 11739, 11740, 28610, 47890, 47891) -- Shadow Ward
addShield(8000, 7, 0.5, 48707) -- Anti-Magic Shell
addShield(10000, 10, nil, 50461) -- Anti-Magic Zone
addShield(8000, 30, nil, 7812, 19438, 19440, 19441, 19442, 19443, 27273, 47985, 47986) -- Sacrifice
addShield(1500, 10, nil, 62606) -- Savage Defense

local healBase = {}
for spellId, amount in pairs(HEAL_SPELLS) do
	local name = GetSpellInfo(spellId)
	if name then
		healBase[name] = amount
	end
end

local casterTargets = { player = "target", target = "targettarget", focus = "focustarget" }
for i = 1, 4 do
	casterTargets["party" .. i] = "party" .. i .. "target"
end
for i = 1, 5 do
	casterTargets["arena" .. i] = "arena" .. i .. "target"
end

local LOOKUP_UNITS = { "player", "target", "focus", "mouseover", "pet" }
for i = 1, 4 do
	LOOKUP_UNITS[#LOOKUP_UNITS + 1] = "party" .. i
end
for i = 1, 5 do
	LOOKUP_UNITS[#LOOKUP_UNITS + 1] = "arena" .. i
end

local casts = {}
local shields = {}
local learnedHeals = {}
local learnedShields = {}
local lastCrit = {}
local sentSpell, sentTarget
local enabled = false
local events = ns.Mixin({}, ns.EventMixin)

local ticker = CreateFrame("Frame")
ticker:Hide()

local function changed(guid)
	if guid then
		ns:Fire(Prediction.CHANGED, guid)
	end
end

local function getOrCreate(parent, key)
	local child = parent[key]
	if not child then
		child = {}
		parent[key] = child
	end
	return child
end

local function startTicker()
	ticker.untilTick = TICK_INTERVAL
	ticker:Show()
end

local function unitByName(name)
	if not name or name == "" then
		return
	end
	for i = 1, #LOOKUP_UNITS do
		local unit = LOOKUP_UNITS[i]
		if UnitName(unit) == name then
			return unit
		end
	end
end

local function unitByGUID(guid)
	for i = 1, #LOOKUP_UNITS do
		local unit = LOOKUP_UNITS[i]
		if UnitGUID(unit) == guid then
			return unit
		end
	end
end

local function castDest(unit, caster, spell)
	if unit == "player" and sentSpell == spell then
		local target = unitByName(sentTarget)
		if target then
			return UnitGUID(target)
		end
	end
	local target = casterTargets[unit]
	if UnitExists(target) and UnitCanAssist(unit, target) then
		return UnitGUID(target)
	end
	return caster
end

local function castExpires(unit)
	local _, _, _, _, _, endTime = UnitCastingInfo(unit)
	return endTime and endTime / 1000 + CAST_GRACE or GetTime() + FALLBACK_CAST_TIME
end

local function onCastSent(_, unit, spell, _, target)
	if unit == "player" then
		sentSpell, sentTarget = spell, target
	end
end

local function onCastStart(_, unit, spell)
	local base = healBase[spell]
	if not base or not casterTargets[unit] then
		return
	end
	local caster = UnitGUID(unit)
	if not caster then
		return
	end

	local cast = getOrCreate(casts, caster)
	local previous = cast.dest
	local learned = learnedHeals[caster]
	cast.spell = spell
	cast.amount = learned and learned[spell] or base
	cast.dest = castDest(unit, caster, spell)
	cast.expires = castExpires(unit)
	if previous ~= cast.dest then
		changed(previous)
	end
	changed(cast.dest)
	startTicker()
end

local function onCastDelayed(_, unit, spell)
	if not healBase[spell] or not casterTargets[unit] then
		return
	end
	local caster = UnitGUID(unit)
	local cast = caster and casts[caster]
	if cast and cast.dest and cast.spell == spell then
		cast.expires = castExpires(unit)
	end
end

local function onCastStop(_, unit, spell)
	if not healBase[spell] or not casterTargets[unit] then
		return
	end
	local caster = UnitGUID(unit)
	local cast = caster and casts[caster]
	if not cast or not cast.dest or cast.spell ~= spell or UnitCastingInfo(unit) == spell then
		return
	end
	local dest = cast.dest
	cast.dest = nil
	changed(dest)
end

local function learnHeal(sourceGUID, spellName, amount)
	local learned = getOrCreate(learnedHeals, sourceGUID)
	local previous = learned[spellName]
	if not previous then
		learned[spellName] = amount
	elseif amount >= previous * CHAIN_JUMP_RATIO then
		learned[spellName] = (previous + amount) * 0.5
	end
end

local function onHeal(sourceGUID, destGUID, _, spellName, _, amount, _, _, critical)
	if not amount then
		return
	end
	if critical then
		lastCrit[destGUID] = amount
	elseif healBase[spellName] and sourceGUID then
		learnHeal(sourceGUID, spellName, amount)
	end
end

local function shieldAmount(sourceGUID, destGUID, spellId, info)
	local learned = learnedShields[sourceGUID]
	local amount = learned and learned[spellId]
	if amount then
		return amount
	end
	if spellId == DIVINE_AEGIS then
		local crit = lastCrit[destGUID]
		if crit then
			return crit * DIVINE_AEGIS_RATIO
		end
	elseif info.fraction then
		local unit = unitByGUID(destGUID)
		if unit then
			return UnitHealthMax(unit) * info.fraction
		end
	end
	return info.amount
end

local function onAuraApplied(sourceGUID, destGUID, spellId)
	local info = SHIELDS[spellId]
	if not info or not destGUID then
		return
	end
	local shield = getOrCreate(getOrCreate(shields, destGUID), spellId)
	shield.source = sourceGUID
	shield.amount = shieldAmount(sourceGUID, destGUID, spellId, info)
	shield.absorbed = 0
	shield.lastAbsorb = 0
	shield.expires = GetTime() + info.duration
	changed(destGUID)
	startTicker()
end

local function removeShield(set, destGUID, spellId)
	set[spellId] = nil
	if not next(set) then
		shields[destGUID] = nil
	end
end

local function onAuraRemoved(_, destGUID, spellId)
	local set = shields[destGUID]
	local shield = set and set[spellId]
	if not shield then
		return
	end
	local info = SHIELDS[spellId]
	local source = shield.source
	if
		source
		and not info.fraction
		and spellId ~= DIVINE_AEGIS
		and shield.absorbed > 0
		and GetTime() - shield.lastAbsorb < BREAK_WINDOW
	then
		getOrCreate(learnedShields, source)[spellId] = shield.absorbed
	end
	removeShield(set, destGUID, spellId)
	changed(destGUID)
end

local function absorb(destGUID, amount)
	local set = shields[destGUID]
	if not set or not amount or amount <= 0 then
		return
	end
	local now = GetTime()
	local last
	for _, shield in pairs(set) do
		shield.lastAbsorb = now
		last = shield
		local left = shield.amount - shield.absorbed
		if amount > 0 and left > 0 then
			local taken = amount < left and amount or left
			shield.absorbed = shield.absorbed + taken
			amount = amount - taken
		end
	end
	if amount > 0 then
		last.absorbed = last.absorbed + amount
	end
	changed(destGUID)
end

local function onUnitDied(_, destGUID)
	if shields[destGUID] then
		shields[destGUID] = nil
		changed(destGUID)
	end
end

local cleuHandlers = {
	SPELL_HEAL = onHeal,
	SPELL_AURA_APPLIED = onAuraApplied,
	SPELL_AURA_REFRESH = onAuraApplied,
	SPELL_AURA_REMOVED = onAuraRemoved,
	UNIT_DIED = onUnitDied,
	UNIT_DESTROYED = onUnitDied,
	SWING_DAMAGE = function(_, destGUID, _, _, _, _, _, absorbed)
		absorb(destGUID, absorbed)
	end,
	ENVIRONMENTAL_DAMAGE = function(_, destGUID, _, _, _, _, _, _, absorbed)
		absorb(destGUID, absorbed)
	end,
	SWING_MISSED = function(_, destGUID, missType, amount)
		if missType == "ABSORB" then
			absorb(destGUID, amount)
		end
	end,
}

local function onSpellDamage(_, destGUID, _, _, _, _, _, _, _, _, absorbed)
	absorb(destGUID, absorbed)
end

local function onSpellMissed(_, destGUID, _, _, _, missType, amount)
	if missType == "ABSORB" then
		absorb(destGUID, amount)
	end
end

for _, event in ipairs({
	"SPELL_DAMAGE",
	"SPELL_PERIODIC_DAMAGE",
	"RANGE_DAMAGE",
	"DAMAGE_SHIELD",
	"DAMAGE_SPLIT",
	"SPELL_BUILDING_DAMAGE",
}) do
	cleuHandlers[event] = onSpellDamage
end
for _, event in ipairs({ "SPELL_MISSED", "SPELL_PERIODIC_MISSED", "RANGE_MISSED", "DAMAGE_SHIELD_MISSED" }) do
	cleuHandlers[event] = onSpellMissed
end

local function onCombatLog(_, _, event, sourceGUID, _, _, destGUID, _, _, a1, a2, a3, a4, a5, a6, a7, a8, a9)
	local handler = cleuHandlers[event]
	if handler then
		handler(sourceGUID, destGUID, a1, a2, a3, a4, a5, a6, a7, a8, a9)
	end
end

ticker:SetScript("OnUpdate", function(self, elapsed)
	local untilTick = self.untilTick - elapsed
	if untilTick > 0 then
		self.untilTick = untilTick
		return
	end
	self.untilTick = TICK_INTERVAL

	local now = GetTime()
	local active = false
	for _, cast in pairs(casts) do
		local dest = cast.dest
		if dest then
			if cast.expires < now then
				cast.dest = nil
				changed(dest)
			else
				active = true
			end
		end
	end
	for guid, set in pairs(shields) do
		local removed = false
		for spellId, shield in pairs(set) do
			if shield.expires < now then
				set[spellId] = nil
				removed = true
			end
		end
		if removed then
			if not next(set) then
				shields[guid] = nil
			end
			changed(guid)
		end
	end
	if not active and not next(shields) then
		self:Hide()
	end
end)

local function keepOnlyKey(t, keptKey)
	for key in pairs(t) do
		if key ~= keptKey then
			t[key] = nil
		end
	end
end

local function reset()
	local playerGUID = UnitGUID("player")
	wipe(casts)
	wipe(shields)
	wipe(lastCrit)
	keepOnlyKey(learnedHeals, playerGUID)
	keepOnlyKey(learnedShields, playerGUID)
	sentSpell, sentTarget = nil, nil
	ticker:Hide()
end

local CAST_EVENTS = {
	UNIT_SPELLCAST_SENT = onCastSent,
	UNIT_SPELLCAST_START = onCastStart,
	UNIT_SPELLCAST_DELAYED = onCastDelayed,
	UNIT_SPELLCAST_STOP = onCastStop,
	UNIT_SPELLCAST_FAILED = onCastStop,
	UNIT_SPELLCAST_INTERRUPTED = onCastStop,
}

local function onHealCommHeal(_, _, _, _, _, ...)
	for i = 1, select("#", ...) do
		changed((select(i, ...)))
	end
end

local function onHealCommGUID(_, guid)
	changed(guid)
end

local function setHealComm(value)
	if not HealComm then
		return
	end
	if value then
		for i = 1, #HEALCOMM_CALLBACKS do
			HealComm.RegisterCallback(Prediction, HEALCOMM_CALLBACKS[i], onHealCommHeal)
		end
		HealComm.RegisterCallback(Prediction, "HealComm_ModifierChanged", onHealCommGUID)
		HealComm.RegisterCallback(Prediction, "HealComm_GUIDDisappeared", onHealCommGUID)
	else
		HealComm.UnregisterAllCallbacks(Prediction)
	end
end

local function setEnabled(value)
	if value == enabled then
		return
	end
	enabled = value
	if value then
		for event, handler in pairs(CAST_EVENTS) do
			events:RegisterEvent(event, handler)
		end
		events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
		events:RegisterEvent("PLAYER_ENTERING_WORLD", reset)
	else
		events:UnregisterAllEvents()
		reset()
	end
	setHealComm(value)
end

local function coveredByHealComm(caster)
	return HealComm and HealComm:GetCasterHealAmount(caster, HealComm.CASTED_HEALS) ~= nil
end

function Prediction.GetIncoming(guid)
	if not enabled or not guid then
		return 0
	end
	local now = GetTime()
	local total = 0
	if HealComm then
		local amount = HealComm:GetHealAmount(guid, HealComm.ALL_HEALS, now + HEALCOMM_WINDOW)
		if amount then
			total = amount * HealComm:GetHealModifier(guid)
		end
	end
	for caster, cast in pairs(casts) do
		if cast.dest == guid and cast.expires > now and not coveredByHealComm(caster) then
			total = total + cast.amount
		end
	end
	return total
end

function Prediction.GetAbsorb(guid)
	local set = enabled and guid and shields[guid]
	if not set then
		return 0, false
	end
	local now = GetTime()
	local total, shielded = 0, false
	for _, shield in pairs(set) do
		if shield.expires > now then
			shielded = true
			local left = shield.amount - shield.absorbed
			if left > 0 then
				total = total + left
			end
		end
	end
	return total, shielded
end

local bars = {}

local function setWidth(texture, width)
	if texture.width ~= width then
		texture.width = width
		texture:SetWidth(width)
	end
end

local function layout(bar)
	local p = bar.prediction
	local value = bar:GetValue()
	p.value = value
	local _, max = bar:GetMinMaxValues()
	local width = bar:GetWidth()
	if not p.active or max <= 0 or width <= 0 then
		p.heal:Hide()
		p.absorb:Hide()
		p.glow:Hide()
		return
	end

	local fill = bar:GetStatusBarTexture()
	local missing = max - value
	if missing < 0 then
		missing = 0
	end

	local incoming = p.incoming
	local heal = incoming < missing and incoming or missing
	local healWidth = heal * width / max
	if healWidth >= MIN_WIDTH then
		p.heal:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		p.heal:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
		setWidth(p.heal, healWidth)
		p.heal:Show()
	else
		healWidth = 0
		p.heal:Hide()
	end

	local room = missing - heal
	local amount = p.absorbAmount
	local shield = amount < room and amount or room
	local absorbWidth = shield * width / max
	if absorbWidth >= MIN_WIDTH then
		p.absorb:SetPoint("TOPLEFT", fill, "TOPRIGHT", healWidth, 0)
		p.absorb:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", healWidth, 0)
		setWidth(p.absorb, absorbWidth)
		p.absorb:Show()
	else
		p.absorb:Hide()
	end

	if p.shielded and (amount > room or amount <= 0) then
		p.glow:Show()
	else
		p.glow:Hide()
	end
end

local function applyColors(bar)
	local config = ns.Config.unitFrames
	local p = bar.prediction
	p.heal:SetVertexColor(unpack(config.healPredictionColor))
	local r, g, b = unpack(config.absorbColor)
	p.absorb:SetVertexColor(r, g, b)
	p.glow:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, 1)
end

local function onSizeChanged(bar)
	if bar.prediction.active then
		layout(bar)
	end
end

function Prediction.CreateBars(bar)
	local heal = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	heal:SetTexture(ns.Media.blank)
	heal:Hide()

	local absorbTexture = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	absorbTexture:SetTexture(ns.Media.blank)
	absorbTexture:Hide()

	local glow = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	glow:SetTexture(ns.Media.blank)
	glow:SetBlendMode("ADD")
	glow:SetWidth(GLOW_WIDTH)
	glow:SetPoint("TOPRIGHT")
	glow:SetPoint("BOTTOMRIGHT")
	glow:Hide()

	bar.prediction = {
		heal = heal,
		absorb = absorbTexture,
		glow = glow,
		incoming = 0,
		absorbAmount = 0,
		shielded = false,
		active = false,
	}
	applyColors(bar)
	bar:HookScript("OnSizeChanged", onSizeChanged)
	bars[#bars + 1] = bar
end

function Prediction.SetValues(bar, incoming, absorbAmount, shielded)
	local p = bar.prediction
	p.incoming = incoming
	p.absorbAmount = absorbAmount
	p.shielded = shielded
	p.active = incoming > 0 or shielded
	layout(bar)
end

function Prediction.Refresh(bar, guid, _, showHeal, showAbsorb)
	local incoming = showHeal and Prediction.GetIncoming(guid) or 0
	local absorbAmount, shielded = 0, false
	if showAbsorb then
		absorbAmount, shielded = Prediction.GetAbsorb(guid)
	end
	Prediction.SetValues(bar, incoming, absorbAmount, shielded)
end

function Prediction.Follow(bar)
	local p = bar.prediction
	if p.active and bar:GetValue() ~= p.value then
		layout(bar)
	end
end

local function applyConfig()
	local frames, plate = ns.Config.unitFrames, ns.Config.playerPlate
	setEnabled(
		frames.enabled and (frames.healPrediction or frames.absorbs)
			or plate.enabled and (plate.healPrediction or plate.absorbs)
			or false
	)
	for i = 1, #bars do
		applyColors(bars[i])
	end
end

Prediction:WatchConfig("unitFrames", applyConfig)
Prediction:WatchConfig("playerPlate", applyConfig)
