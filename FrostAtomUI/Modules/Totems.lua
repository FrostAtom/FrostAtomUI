local _, ns = ...

local GetTotemInfo = GetTotemInfo
local DestroyTotem = DestroyTotem
local GetTime = GetTime
local UnitGUID = UnitGUID
local abs = math.abs

local Totems = ns:NewModule("Totems")
local CooldownTimer = ns:GetModule("CooldownTimer")

local MAX_TOTEMS = MAX_TOTEMS or 4
local SLOT_ORDER = TOTEM_PRIORITIES or { 2, 1, 3, 4 }
local PULSE_BACKDROP = ns.CreateBackdrop(8, 2)
local PULSE_INSET = 3
local SUMMON_TOLERANCE = 1

local TotemData = ns.TotemData
local TICK_EVENTS = TotemData.TICK_EVENTS
local spells = TotemData.spells
local tickSpells = TotemData.tickSpells

local buttons = {}
local pulses = {}
local holder
local playerGUID

local ticker = CreateFrame("Frame")
ticker:Hide()

ticker:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local any
	for slot, record in pairs(pulses) do
		local bar = buttons[slot].pulse
		if bar:IsShown() then
			local period = record.pulse.period
			bar.bar:SetValue((now - record.lastTick) % period / period)
			any = true
		end
	end
	if not any then
		self:Hide()
	end
end)

local function updatePulse(button, active, startTime)
	local record = pulses[button:GetID()]
	local show = ns.Config.totems.pulse and active and record and abs(startTime - record.start) < SUMMON_TOLERANCE
	ns.SetShown(button.pulse, show)
	if show then
		ticker:Show()
	end
end

local function updateButton(button)
	local haveTotem, _, startTime, duration, icon = GetTotemInfo(button:GetID())
	local active = haveTotem and duration > 0
	if active then
		button.icon:SetTexture(icon)
		button.cooldown:SetCooldown(startTime, duration)
		button:SetAlpha(1)
	else
		button.cooldown:SetCooldown(0, 0)
		button:SetAlpha(0)
	end
	button:EnableMouse(active and not ns.Config.totems.clickThrough)
	updatePulse(button, active, startTime)
end

function Totems:PLAYER_TOTEM_UPDATE(slot)
	local button = buttons[slot]
	if button then
		updateButton(button)
	end
end

function Totems:UpdateAll()
	for i = 1, #buttons do
		updateButton(buttons[i])
	end
end

local function onSummon(dstGUID, spellId)
	local data = spells[spellId]
	if not data then
		return
	end
	local slot = data.slot
	if data.pulse then
		local now = GetTime()
		pulses[slot] = { guid = dstGUID, pulse = data.pulse, start = now, lastTick = now }
	else
		pulses[slot] = nil
	end
	local button = buttons[slot]
	if button then
		updateButton(button)
	end
end

local function onTick(srcGUID, spellId)
	for _, record in pairs(pulses) do
		if (srcGUID == record.guid or srcGUID == playerGUID) and record.pulse.ticks[spellId] then
			record.lastTick = GetTime()
		end
	end
end

local function onDestroyed(dstGUID)
	for slot, record in pairs(pulses) do
		if record.guid == dstGUID then
			pulses[slot] = nil
			ns.SetShown(buttons[slot].pulse, false)
		end
	end
end

function Totems:COMBAT_LOG_EVENT_UNFILTERED(_, event, srcGUID, _, _, dstGUID, _, _, spellId)
	playerGUID = playerGUID or UnitGUID("player")
	if TICK_EVENTS[event] then
		if tickSpells[spellId] then
			onTick(srcGUID, spellId)
		end
	elseif event == "SPELL_SUMMON" then
		if srcGUID == playerGUID then
			onSummon(dstGUID, spellId)
		end
	elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
		onDestroyed(dstGUID)
	end
end

local function onClick(self)
	DestroyTotem(self:GetID())
end

local function createButton(slot, parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetID(slot)
	button:SetAlpha(0)
	button:RegisterForClicks("RightButtonUp")
	button:SetScript("OnClick", onClick)

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints()

	button.border = button:CreateTexture(nil, "ARTWORK")
	button.border:SetTexture(ns.Media.buttonNormal)
	button.border:SetAllPoints()

	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	button.cooldown:SetReverse(true)
	button.cooldown:SetDrawEdge(true)
	button.cooldown:SetFrameLevel(button:GetFrameLevel())

	local text = CreateFrame("Frame", nil, button)
	text:SetAllPoints()
	text:SetFrameLevel(button:GetFrameLevel() + 1)
	CooldownTimer:Attach(button.cooldown, nil, text)

	local pulse = CreateFrame("Frame", nil, button)
	pulse:SetBackdrop(PULSE_BACKDROP)
	pulse:Hide()
	local pulseBar = CreateFrame("StatusBar", nil, pulse)
	pulseBar:SetPoint("TOPLEFT", PULSE_INSET, -PULSE_INSET)
	pulseBar:SetPoint("BOTTOMRIGHT", -PULSE_INSET, PULSE_INSET)
	pulseBar:SetMinMaxValues(0, 1)
	ns.SkinStatusBar(pulseBar)
	pulse.bar = pulseBar
	button.pulse = pulse

	buttons[slot] = button
end

local function applyConfig()
	local config = ns.Config.totems
	local frameConfig = ns.Config.unitFrames
	local size, gap, font = config.size, config.gap, config.timerFont
	local pulseColor = config.pulseColor
	holder:SetSize(MAX_TOTEMS * (size + gap) - gap, size)
	for index, slot in ipairs(SLOT_ORDER) do
		local button = buttons[slot]
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("LEFT", (index - 1) * (size + gap), 0)
		ns.SetFont(button.cooldown.timer, font.size, font.outline)
		local pulse = button.pulse
		pulse:SetHeight(config.pulseHeight + PULSE_INSET * 2)
		pulse:ClearAllPoints()
		pulse:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, gap)
		pulse:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, gap)
		pulse:SetBackdropColor(unpack(frameConfig.backdropColor))
		pulse:SetBackdropBorderColor(unpack(frameConfig.borderColor))
		pulse.bar:SetStatusBarColor(pulseColor[1], pulseColor[2], pulseColor[3])
		updateButton(button)
	end
	if config.enabled then
		holder:Show()
	else
		holder:Hide()
	end
end

function Totems:Initialize()
	if ns.PLAYER_CLASS ~= "SHAMAN" then
		return
	end

	holder = CreateFrame("Frame", nil, UIParent)
	self:AnchorToConfig(holder, "totems.point", "Totems", { secure = true })

	for slot = 1, MAX_TOTEMS do
		createButton(slot, holder)
	end

	applyConfig()
	self:WatchConfig("totems", applyConfig, true)
	self:WatchConfig("unitFrames", applyConfig, true)

	self:RegisterEvent("PLAYER_TOTEM_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
