local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local GetTime = GetTime
local band = bit.band
local sub = string.sub
local max, tonumber = math.max, tonumber

local PlateLayer = ns.PlateLayer
local snap = ns.WorldChildren.Snap
local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText

local config = ns.Config.namePlates
local frameConfig = ns.Config.unitFrames

local Totems = {}
NamePlates.Totems = Totems

local REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local ICON_CROP = 0.08
local HOVER_ALPHA = 0.15
local DURATION_BAR_HEIGHT = 2
local TIMER_INTERVAL = 0.1
local REACTION_COLORS = {
	hostile = { 1, 0.15, 0.15 },
	neutral = { 1, 0.85, 0.1 },
	friendly = { 0.15, 1, 0.15 },
}

local TotemData = ns.TotemData
local TICK_EVENTS = TotemData.TICK_EVENTS
local spells = TotemData.spells
local byEntry = TotemData.byEntry
local byName = TotemData.byName
local tickSpells = TotemData.tickSpells
local learned = {}

local summons = {}
local ownerSlots = {}
local claimed = {}
local timed = {}

local function entryOf(guid)
	if guid and not PlateLayer.IsPlayerGUID(guid) then
		return tonumber(sub(guid, 7, 12), 16)
	end
end

function Totems.Identify(plate)
	local info = plate.info
	if info.isPlayer then
		return
	end
	local entry = entryOf(plate.guid)
	if entry then
		return byEntry[entry]
	end
	local name = info.name
	return name and (learned[name] or byName[name])
end

local function release(plate)
	local guid = plate.totemSummon
	if guid then
		plate.totemSummon = nil
		if claimed[guid] == plate then
			claimed[guid] = nil
		end
	end
	timed[plate] = nil
	local totem = plate.totem
	totem.timer:Hide()
	totem.bar:Hide()
	totem.pulse:Hide()
end

local ticker = CreateFrame("Frame")
ticker:Hide()
ticker.nextTick = 0

local function findSummon(plate, spellId, now)
	local guid = plate.guid
	if guid then
		local record = summons[guid]
		return record and record.expires > now and guid or nil
	end
	local name, hostile = plate.info.name, plate.info.isEnemy
	local found
	for other, record in pairs(summons) do
		if
			record.spellId == spellId
			and record.name == name
			and record.hostile == hostile
			and record.expires > now
			and not claimed[other]
		then
			if found then
				return
			end
			found = other
		end
	end
	return found
end

local function bind(plate)
	local spellId = plate.totemSpell
	if not spellId then
		return
	end
	local now = GetTime()
	local guid = (config.totemTimer or config.totemPulse) and findSummon(plate, spellId, now)
	if guid == plate.totemSummon then
		return
	end
	release(plate)
	if not guid then
		return
	end
	local record = summons[guid]
	local showTimer = config.totemTimer and record.summoned
	local showPulse = config.totemPulse and record.pulse ~= nil
	if not showTimer and not showPulse then
		return
	end
	local owner = claimed[guid]
	if owner and owner ~= plate then
		release(owner)
	end
	claimed[guid] = plate
	plate.totemSummon = guid
	timed[plate] = true
	local totem = plate.totem
	ns.SetShown(totem.timer, showTimer)
	ns.SetShown(totem.bar, showTimer)
	ns.SetShown(totem.pulse, showPulse)
	ticker.nextTick = 0
	ticker:Show()
end

local function updateTimer(plate, now, textDue)
	local record = summons[plate.totemSummon]
	local remain = record and record.expires - now
	if not remain or remain <= 0 then
		release(plate)
		return
	end
	local totem = plate.totem
	if textDue and totem.timer:IsShown() then
		SetTimerText(totem.timer, remain)
		totem.bar:SetWidth(max(totem.iconSize * remain / record.duration, 0.1))
	end
	local pulse = record.pulse
	if pulse and totem.pulse:IsShown() then
		totem.pulse.bar:SetValue((now - record.lastTick) % pulse.period / pulse.period)
	end
end

ticker:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local textDue = now >= self.nextTick
	if textDue then
		self.nextTick = now + TIMER_INTERVAL
	end
	for plate in pairs(timed) do
		updateTimer(plate, now, textDue)
	end
	if not next(timed) then
		self:Hide()
	end
end)

local function dismiss(guid)
	local record = summons[guid]
	if not record then
		return
	end
	summons[guid] = nil
	local slots = record.owner and ownerSlots[record.owner]
	if slots and slots[record.slot] == guid then
		slots[record.slot] = nil
	end
	local plate = claimed[guid]
	if plate then
		release(plate)
	end
end

local function prune(now)
	for guid, record in pairs(summons) do
		if record.expires <= now then
			dismiss(guid)
		end
	end
end

local function refreshNamed(name)
	local plates = NamePlates.plates
	for i = 1, #plates do
		local plate = plates[i]
		if plate:IsShown() and plate.plateName == name then
			if plate.totemSpell then
				bind(plate)
			else
				plate:OnShow()
			end
		end
	end
end

local function onSummon(srcGUID, dstGUID, dstName, dstFlags, spellId)
	local data = spells[spellId]
	if not data then
		return
	end
	local now = GetTime()
	prune(now)
	local slots = ownerSlots[srcGUID]
	if not slots then
		slots = {}
		ownerSlots[srcGUID] = slots
	end
	local previous = slots[data.slot]
	if previous then
		dismiss(previous)
	end
	slots[data.slot] = dstGUID
	summons[dstGUID] = {
		spellId = spellId,
		name = dstName,
		owner = srcGUID,
		slot = data.slot,
		duration = data.duration,
		expires = now + data.duration,
		hostile = band(dstFlags, REACTION_HOSTILE) ~= 0,
		summoned = true,
		pulse = data.pulse,
		lastTick = now,
	}
	if dstName then
		learned[dstName] = spellId
		refreshNamed(dstName)
	end
end

local function ownerTotem(owner, spellId)
	local slots = ownerSlots[owner]
	if not slots then
		return
	end
	for _, guid in pairs(slots) do
		local record = summons[guid]
		local pulse = record and record.pulse
		if pulse and pulse.ticks[spellId] then
			return record
		end
	end
end

local function onTick(srcGUID, srcName, srcFlags, spellId)
	local now = GetTime()
	local record = summons[srcGUID] or ownerTotem(srcGUID, spellId)
	if record then
		local pulse = record.pulse
		if pulse and pulse.ticks[spellId] then
			record.lastTick = now
		end
		return
	end
	local entry = entryOf(srcGUID)
	local summonSpell = entry and byEntry[entry]
	local data = summonSpell and spells[summonSpell]
	local pulse = data and data.pulse
	if not pulse or not pulse.ticks[spellId] or not srcName then
		return
	end
	summons[srcGUID] = {
		spellId = summonSpell,
		name = srcName,
		slot = data.slot,
		duration = data.duration,
		expires = now + data.duration,
		hostile = band(srcFlags, REACTION_HOSTILE) ~= 0,
		pulse = pulse,
		lastTick = now,
	}
	learned[srcName] = summonSpell
	refreshNamed(srcName)
end

local function onCombatLog(_, _, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId)
	if TICK_EVENTS[event] then
		if tickSpells[spellId] then
			onTick(srcGUID, srcName, srcFlags, spellId)
		end
	elseif event == "SPELL_SUMMON" then
		onSummon(srcGUID, dstGUID, dstName, dstFlags, spellId)
	elseif (event == "UNIT_DIED" or event == "UNIT_DESTROYED") and summons[dstGUID] then
		dismiss(dstGUID)
	end
end

local function onEnteringWorld()
	for guid in pairs(summons) do
		dismiss(guid)
	end
	wipe(ownerSlots)
end

function Totems.Setup(plate)
	local totem = NamePlates.CreateHolder(plate.overlay, plate:GetFrameLevel())
	totem:SetPoint("TOPLEFT")
	totem:Hide()

	local inset = NamePlates.BORDER_INSET
	local icon = totem:CreateTexture(nil, "ARTWORK")
	icon:SetNonBlocking(true)
	icon:SetPoint("TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", -inset, inset)
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	totem.icon = icon

	local hover = totem:CreateTexture(nil, "OVERLAY")
	hover:SetAllPoints(icon)
	hover:SetTexture(ns.Media.blank)
	hover:SetBlendMode("ADD")
	hover:SetVertexColor(1, 1, 1, HOVER_ALPHA)
	hover:Hide()
	totem.hover = hover

	local bar = totem:CreateTexture(nil, "OVERLAY")
	bar:SetTexture(ns.Media.blank)
	bar:SetHeight(DURATION_BAR_HEIGHT)
	bar:SetPoint("BOTTOMLEFT", icon)
	bar:Hide()
	totem.bar = bar

	local timer = totem:CreateFontString(nil, "OVERLAY")
	timer:SetPoint("CENTER", icon)
	timer:Hide()
	totem.timer = timer

	local pulse = NamePlates.CreateHolder(totem, totem:GetFrameLevel())
	pulse:Hide()
	local pulseBar = CreateFrame("StatusBar", nil, pulse)
	pulseBar:SetFrameLevel(totem:GetFrameLevel() + 1)
	pulseBar:SetPoint("TOPLEFT", inset, -inset)
	pulseBar:SetPoint("BOTTOMRIGHT", -inset, inset)
	pulseBar:SetMinMaxValues(0, 1)
	ns.SkinStatusBar(pulseBar)
	pulse.bar = pulseBar
	totem.pulse = pulse

	totem.reactionColor = REACTION_COLORS.hostile
	plate.totem = totem
	Totems.ApplyStyle(plate)
end

function Totems.ApplyStyle(plate)
	local totem = plate.totem
	NamePlates.StyleHolder(totem)
	ns.SetFont(totem.timer, config.auraFont.size, config.auraFont.outline)
	local color = frameConfig.castbarColor
	totem.bar:SetVertexColor(color[1], color[2], color[3])
	totem.borderColor = nil
	NamePlates.StyleHolder(totem.pulse)
	local pulseColor = config.totemPulseColor
	totem.pulse.bar:SetStatusBarColor(pulseColor[1], pulseColor[2], pulseColor[3])
	if plate.totemSpell then
		release(plate)
		Totems.Show(plate, plate.totemSpell)
	end
end

function Totems.SetReaction(plate, reaction)
	local totem = plate.totem
	totem.reactionColor = REACTION_COLORS[reaction] or REACTION_COLORS.hostile
	totem.borderColor = nil
end

function Totems.Show(plate, spellId)
	local totem = plate.totem
	totem.icon:SetTexture(spells[spellId].icon)
	local inset = NamePlates.BORDER_INSET
	local size = snap(config.totemIconSize + inset * 2)
	totem:SetSize(size, size)
	totem.iconSize = size - inset * 2
	local pulse = totem.pulse
	local gap = snap(config.castbarGap)
	pulse:SetHeight(snap(config.totemPulseHeight + inset * 2))
	pulse:SetPoint("BOTTOMLEFT", totem, "TOPLEFT", 0, gap)
	pulse:SetPoint("BOTTOMRIGHT", totem, "TOPRIGHT", 0, gap)
	totem.snapX = nil
	totem.borderColor = nil
	if plate.totemSpell ~= spellId then
		release(plate)
		plate.totemSpell = spellId
	end
	totem:Show()
	bind(plate)
end

function Totems.Hide(plate)
	release(plate)
	plate.totemSpell = nil
	plate.totem:Hide()
end

local function snapTotem(plate, totem)
	local left, top = plate:GetLeft(), plate:GetTop()
	if not left then
		return
	end
	local x = snap(left + (plate:GetWidth() - totem:GetWidth()) / 2) - left
	local y = snap(top) - top
	if x ~= totem.snapX or y ~= totem.snapY then
		totem.snapX, totem.snapY = x, y
		totem:SetPoint("TOPLEFT", plate, "TOPLEFT", x, y)
	end
end

function Totems.Update(plate, isTarget)
	local totem = plate.totem
	snapTotem(plate, totem)
	local color = isTarget and config.targetBorder and frameConfig.targetBorderColor or totem.reactionColor
	if color ~= totem.borderColor then
		totem.borderColor = color
		totem:SetBackdropBorderColor(color[1], color[2], color[3])
	end
	local hovered = config.hoverHighlight and plate.info.isMouseover or false
	if hovered ~= totem.hovered then
		totem.hovered = hovered
		ns.SetShown(totem.hover, hovered)
	end
end

NamePlates:OnInitialize(function(self)
	if not config.enabled then
		return
	end
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", onCombatLog)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
end)
