local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local random = math.random
local unpack = unpack

local FADE_SPEED = 1.4
local INTERRUPTED_TEXT = "|cff8B0000INTERRUPTED|r"
local FAILED_TEXT = "|cff808080FAILED|r"

local TEST_CASTS = {
	12826, -- Polymorph
	6215, -- Fear
	42842, -- Frostbolt
	49271, -- Chain Lightning
	48063, -- Greater Heal
	33786, -- Cyclone
	48181, -- Haunt
	47843, -- Unstable Affliction
	48782, -- Holy Light
	51505, -- Lava Burst
	48071, -- Flash Heal
	42833, -- Fireball
	48378, -- Healing Touch
	49238, -- Lightning Bolt
	48160, -- Vampiric Touch
}
local TEST_CHANNELS = {
	47855, -- Drain Life
	48156, -- Mind Flay
	42846, -- Arcane Missiles
	48467, -- Hurricane
	48447, -- Tranquility
}

local config = ns.Config.unitFrames
local BORDER_INSET = UF.BORDER_INSET

local function setInterruptible(castbar, interruptible)
	if interruptible or castbar.isPlayer then
		castbar.icon:SetDesaturated(nil)
		castbar.bar:SetStatusBarColor(unpack(config.castbarColor))
	else
		castbar.icon:SetDesaturated(1)
		castbar.bar:SetStatusBarColor(unpack(config.castbarLockedColor))
	end
end

local function setTimes(castbar, startTime, endTime)
	castbar.startTime = startTime
	castbar.endTime = endTime
	castbar.remain = endTime - GetTime()
	castbar.bar:SetMinMaxValues(startTime, endTime)
end

local function setProgress(castbar, remain)
	if castbar.isChannel then
		castbar.bar:SetValue(castbar.startTime + remain)
	else
		castbar.bar:SetValue(castbar.endTime - remain)
	end
	castbar.timer:SetFormattedText("%.1f", remain)
end

local function stopCast(castbar)
	castbar.casting = false
	castbar.bar:SetValue(castbar.isChannel and castbar.startTime or castbar.endTime)
	castbar.timer:SetText("")
end

local testCast

local function onUpdate(castbar, elapsed)
	if castbar.casting then
		local remain = castbar.remain - elapsed
		if remain > 0 then
			castbar.remain = remain
			setProgress(castbar, remain)
		elseif castbar.testing then
			testCast(castbar)
		else
			stopCast(castbar)
		end
		return
	end

	local alpha = castbar:GetAlpha() - elapsed * FADE_SPEED
	if alpha > 0 then
		castbar:SetAlpha(alpha)
	else
		castbar:Hide()
	end
end

local function startCast(castbar, name, texture, startTime, endTime, isChannel, castId, interruptible)
	castbar.name:SetText(name ~= "" and name or "unknown")
	castbar.icon:SetTexture(texture ~= "" and texture or ns.Media.questionMark)
	setInterruptible(castbar, interruptible)

	castbar.isChannel = isChannel
	castbar.castId = castId
	setTimes(castbar, startTime, endTime)
	setProgress(castbar, castbar.remain)

	castbar.casting = true
	castbar:SetAlpha(1)
	castbar:Show()
end

local function update(frame)
	local unit = frame.unit
	local castbar = frame.castbar
	castbar.testing = nil

	local isChannel = false
	local name, _, _, texture, startTime, endTime, _, castId, notInterruptible = UnitCastingInfo(unit)
	if not name then
		isChannel = true
		name, _, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
	end

	if not name then
		castbar:Hide()
		return
	end

	startCast(castbar, name, texture, startTime / 1e3, endTime / 1e3, isChannel, castId, not notInterruptible)
end

function testCast(castbar)
	local isChannel = random(3) == 1
	local spells = isChannel and TEST_CHANNELS or TEST_CASTS
	local name, _, texture = GetSpellInfo(spells[random(#spells)])
	local now = GetTime()
	local duration = random(15, 30) / 10
	startCast(castbar, name, texture, now, now + duration, isChannel, nil, random(4) ~= 1)
end

local function test(frame)
	local castbar = frame.castbar
	castbar.testing = true
	testCast(castbar)
end

local function onCastFailed(frame, _, _, castId)
	local castbar = frame.castbar
	if castbar.casting and castId == castbar.castId then
		castbar.name:SetText(FAILED_TEXT)
		stopCast(castbar)
	end
end

local function onCastInterrupted(frame, _, _, castId)
	local castbar = frame.castbar
	if castbar.casting and (castbar.isChannel or castId == castbar.castId) then
		castbar.name:SetText(INTERRUPTED_TEXT)
		stopCast(castbar)
	end
end

local function onCastStop(frame)
	local castbar = frame.castbar
	if castbar.casting then
		stopCast(castbar)
	end
end

local function refreshTimes(frame, getInfo)
	local castbar = frame.castbar
	if not castbar.casting then
		return
	end

	local name, _, _, _, startTime, endTime = getInfo(frame.unit)
	if name then
		setTimes(castbar, startTime / 1e3, endTime / 1e3)
		setProgress(castbar, castbar.remain)
	else
		stopCast(castbar)
	end
end

local function onCastDelayed(frame)
	refreshTimes(frame, UnitCastingInfo)
end

local function onChannelUpdate(frame)
	refreshTimes(frame, UnitChannelInfo)
end

local function onInterruptible(frame)
	setInterruptible(frame.castbar, true)
end

local function onNotInterruptible(frame)
	setInterruptible(frame.castbar, false)
end

local function create(frame, iconSide)
	local castbar = CreateFrame("Frame", nil, frame)
	castbar:Hide()
	castbar:SetFrameLevel(frame:GetFrameLevel())
	castbar:SetBackdrop(UF.backdrop)
	UF.SetBackdropColors(castbar)
	castbar.isPlayer = frame.unit == "player"
	castbar:SetScript("OnUpdate", onUpdate)

	local bar = CreateFrame("StatusBar", nil, castbar)
	bar:SetPoint("TOPLEFT", BORDER_INSET, -BORDER_INSET)
	bar:SetPoint("BOTTOMRIGHT", -BORDER_INSET, BORDER_INSET)
	bar:SetMinMaxValues(0, 1)
	bar:SetStatusBarTexture(ns.Media.blank)
	castbar.bar = bar

	castbar.icon = castbar:CreateTexture(nil, "BORDER")
	if iconSide == "RIGHT" then
		castbar.icon:SetPoint("LEFT", castbar, "RIGHT", 2, 0)
	else
		castbar.icon:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
	end
	castbar.iconBorder = castbar:CreateTexture(nil, "ARTWORK")
	castbar.iconBorder:SetTexture(ns.Media.buttonNormal)
	castbar.iconBorder:SetAllPoints(castbar.icon)

	castbar.timer = bar:CreateFontString(nil, "OVERLAY")
	castbar.timer:SetFont(ns.Media.font, config.castbarFont.size, config.castbarFont.outline)
	castbar.timer:SetPoint("RIGHT")
	castbar.timer:SetJustifyH("LEFT")

	castbar.name = bar:CreateFontString(nil, "OVERLAY")
	castbar.name:SetFont(ns.Media.font, config.castbarFont.size, config.castbarFont.outline)
	castbar.name:SetPoint("CENTER")

	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", update)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", update)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", onCastFailed)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", onCastStop)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", onCastInterrupted)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", onCastInterrupted)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", onCastStop)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", onCastDelayed)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", onChannelUpdate)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", onInterruptible)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", onNotInterruptible)

	return castbar
end

UF:RegisterElement("castbar", create, update, test)
