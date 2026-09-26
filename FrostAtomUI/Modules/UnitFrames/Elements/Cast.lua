local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitName = UnitName
local UnitClass = UnitClass
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitCanAttack = UnitCanAttack
local UnitGUID = UnitGUID
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetSpellInfo = GetSpellInfo
local GetNetStats = GetNetStats
local GetTime = GetTime
local band = bit.band
local random, floor, min = math.random, math.floor, math.min
local format = string.format

local FADE_SPEED = 1.4
local STOP_TIMEOUT = 0.5
local FINISH_WINDOW = 0.5
local FLASH_TIME = 0.5
local FLASH_ALPHA = 0.5
local FINISH_FADE_SPEED = 1 / 0.3
local INTERRUPT_HOLD = 1
local INTERRUPT_FADE_SPEED = 1 / 0.3
local INTERRUPT_COLOR = { 0.8, 0.1, 0.1 }
local LATE_INTERRUPT = 0.3
local PULSE_PERIOD = 2
local GLOW_SIZE = 6
local TEXT_INSET = 3
local FAILED_TEXT = "|cff808080" .. FAILED .. "|r"
local INTERRUPTED_TEXT = "|cff8B0000" .. INTERRUPTED .. "|r"
local CANCELLED_TEXT = "|cff808080" .. L["Cancelled"] .. "|r"
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local TICK_WIDTH = 2
local TICK_COLOR = { 0, 0, 0, 0.75 }
local MAX_LATENCY_SHARE = 0.4
local LATENCY_TIMEOUT = 2
local SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SPARK_WIDTH = 16
local START_FLASH_TIME = 0.3
local START_FLASH_ALPHA = 0.7

UF.CAST_INTERRUPTED = "FrostAtomUI_CAST_INTERRUPTED"
UF.CAST_SILENCED = "FrostAtomUI_CAST_SILENCED"
UF.INTERRUPTED_TEXT = INTERRUPTED_TEXT
UF.CANCELLED_TEXT = CANCELLED_TEXT

ns.OnLocaleReady(function()
	CANCELLED_TEXT = "|cff808080" .. L["Cancelled"] .. "|r"
	UF.CANCELLED_TEXT = CANCELLED_TEXT
end)

local DR_SPELLS = ns.DRData.SPELLS

local IMPORTANT_CASTS = {
	118, -- Polymorph
	5782, -- Fear
	5484, -- Howl of Terror
	6358, -- Seduction
	33786, -- Cyclone
	51514, -- Hex
	605, -- Mind Control
	2637, -- Hibernate
	339, -- Entangling Roots
	1513, -- Scare Beast
	10326, -- Turn Evil
	8129, -- Mana Burn
	2060, -- Greater Heal
	2061, -- Flash Heal
	32546, -- Binding Heal
	596, -- Prayer of Healing
	47540, -- Penance
	64843, -- Divine Hymn
	635, -- Holy Light
	19750, -- Flash of Light
	5185, -- Healing Touch
	8936, -- Regrowth
	50464, -- Nourish
	740, -- Tranquility
	331, -- Healing Wave
	8004, -- Lesser Healing Wave
	1064, -- Chain Heal
}

local importantCasts = {}
for i = 1, #IMPORTANT_CASTS do
	local name = GetSpellInfo(IMPORTANT_CASTS[i])
	if name then
		importantCasts[name] = true
	end
end
UF.importantCasts = importantCasts

local CHANNEL_TICKS = {
	[689] = 5, -- Drain Life
	[1120] = 5, -- Drain Soul
	[5138] = 5, -- Drain Mana
	[5740] = 4, -- Rain of Fire
	[1949] = 15, -- Hellfire
	[15407] = 3, -- Mind Flay
	[48045] = 5, -- Mind Sear
	[47540] = 2, -- Penance
	[64843] = 4, -- Divine Hymn
	[64901] = 4, -- Hymn of Hope
	[5143] = 5, -- Arcane Missiles
	[10] = 8, -- Blizzard
	[12051] = 4, -- Evocation
	[740] = 4, -- Tranquility
	[16914] = 10, -- Hurricane
	[1510] = 6, -- Volley
}

local channelTicks = {}
for spellId, ticks in pairs(CHANNEL_TICKS) do
	local name = GetSpellInfo(spellId)
	if name then
		channelTicks[name] = ticks
	end
end
UF.channelTicks = channelTicks

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
local TEST_NAMES = { "Frostatom", "Nightshade", "Zephyra", "Thoralf", "Mirelle", "Kaelith", "Dravok", "Sylvara" }

local config = ns.Config.unitFrames
local BORDER_INSET = UF.BORDER_INSET
local ICON_GAP = UF.CASTBAR_ICON_GAP

function UF.CreateCastGlow(parent, anchor, size)
	local glow = CreateFrame("Frame", nil, parent)
	glow:SetFrameLevel(parent:GetFrameLevel())
	glow:Hide()

	local function edge()
		local texture = glow:CreateTexture(nil, "BACKGROUND")
		texture:SetTexture(ns.Media.blank)
		texture:SetBlendMode("ADD")
		return texture
	end

	local top = edge()
	top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -size, 0)
	top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", size, 0)
	top:SetHeight(size)
	local bottom = edge()
	bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -size, 0)
	bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", size, 0)
	bottom:SetHeight(size)
	local left = edge()
	left:SetPoint("TOPRIGHT", anchor, "TOPLEFT")
	left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT")
	left:SetWidth(size)
	local right = edge()
	right:SetPoint("TOPLEFT", anchor, "TOPRIGHT")
	right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT")
	right:SetWidth(size)

	glow.top, glow.bottom, glow.left, glow.right = top, bottom, left, right
	return glow
end

function UF.StartCastGlow(glow, color)
	local r, g, b = color[1], color[2], color[3]
	if r ~= glow.r or g ~= glow.g or b ~= glow.b then
		glow.r, glow.g, glow.b = r, g, b
		glow.top:SetGradientAlpha("VERTICAL", r, g, b, 1, r, g, b, 0)
		glow.bottom:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
		glow.left:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, 1)
		glow.right:SetGradientAlpha("HORIZONTAL", r, g, b, 1, r, g, b, 0)
	end
	glow.elapsed = 0
	glow:SetAlpha(0)
	glow:Show()
end

local function pulseCastGlow(glow, elapsed)
	local t = (glow.elapsed + elapsed) % PULSE_PERIOD
	glow.elapsed = t
	glow:SetAlpha(t < 1 and t or PULSE_PERIOD - t)
end
UF.PulseCastGlow = pulseCastGlow

local function interruptedByText(color, name)
	return format(
		L["Interrupted by %s"],
		format("|cff%02x%02x%02x%s|r", floor(color[1] * 255), floor(color[2] * 255), floor(color[3] * 255), name)
	)
end

local function interrupterText(sourceGUID, sourceName, sourceFlags)
	if not sourceName then
		return INTERRUPTED_TEXT
	end
	local color
	if sourceFlags and band(sourceFlags, PLAYER_FLAG) > 0 then
		local _, class = GetPlayerInfoByGUID(sourceGUID)
		color = class and UF.classColors[class]
	end
	return interruptedByText(color or config.textColor, sourceName)
end

local function setUnitNameText(text, unit, name)
	text:SetText(name)
	local _, class = UnitClass(unit)
	local color = UnitIsPlayer(unit) and class and UF.classColors[class] or config.textColor
	text:SetTextColor(color[1], color[2], color[3])
end
UF.SetCastTargetText = setUnitNameText

local function showInterruptible(castbar)
	local interruptible = castbar.interruptible
	if interruptible and not castbar.isPlayer and not castbar.testing and ns.HasCastImmunity(castbar.unit) then
		interruptible = false
	end
	local color
	if interruptible or castbar.isPlayer or not castbar.testing and not UnitCanAttack("player", castbar.unit) then
		castbar.icon:SetDesaturated(nil)
		color = castbar.isChannel and config.castbarChannelColor or config.castbarColor
	else
		castbar.icon:SetDesaturated(1)
		color = config.castbarLockedColor
	end
	UF.SetBarColor(castbar.bar, color[1], color[2], color[3])
end

local function setInterruptible(castbar, interruptible)
	castbar.interruptible = interruptible
	showInterruptible(castbar)
end

local function setTargetingYou(castbar, targetingYou)
	local color = targetingYou and config.castbarTargetingYouColor or config.borderColor
	castbar:SetBackdropBorderColor(color[1], color[2], color[3])
end

local function layoutText(castbar)
	local split = config.castbarTargetName
	if castbar.split == split then
		return
	end
	castbar.split = split
	local name, target = castbar.name, castbar.target
	name:ClearAllPoints()
	if split then
		target:Show()
		name:SetPoint("LEFT", TEXT_INSET, 0)
		name:SetPoint("RIGHT", target, "LEFT", -TEXT_INSET, 0)
		name:SetJustifyH("LEFT")
	else
		target:Hide()
		name:SetPoint("CENTER")
		name:SetJustifyH("CENTER")
	end
end

local function updateCastTarget(castbar)
	if not castbar.casting then
		return
	end
	local unit, targetUnit = castbar.unit, castbar.targetUnit
	local name = config.castbarTargetName and not UnitIsUnit(targetUnit, unit) and UnitName(targetUnit)
	if name then
		setUnitNameText(castbar.target, targetUnit, name)
	else
		castbar.target:SetText("")
	end
	setTargetingYou(
		castbar,
		config.castbarTargetingYou
			and not castbar.isPlayer
			and UnitIsUnit(targetUnit, "player")
			and UnitCanAttack("player", unit)
	)
end

local function setTimes(castbar, startTime, endTime)
	castbar.startTime = startTime
	castbar.endTime = endTime
	castbar.duration = endTime - startTime
	castbar.remain = endTime - GetTime()
	castbar.bar:SetMinMaxValues(startTime, endTime)
end

local function setProgress(castbar, remain)
	local bar, duration = castbar.bar, castbar.duration
	local elapsed = duration - remain
	if castbar.isChannel then
		bar:SetValue(castbar.startTime + remain)
	else
		bar:SetValue(castbar.endTime - remain)
	end
	local spark = castbar.spark
	if duration > 0 and remain > 0 and elapsed > 0 then
		local fill = (castbar.isChannel and remain or elapsed) / duration
		spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * fill, 0)
		spark:Show()
	else
		spark:Hide()
	end
	if castbar.showTotal then
		castbar.timer:SetFormattedText("%.1f / %.1f", remain, castbar.duration)
	else
		castbar.timer:SetFormattedText("%.1f", remain)
	end
end

local function hideTicks(castbar)
	local ticks = castbar.ticks
	for i = 1, ticks.shown do
		ticks[i]:Hide()
	end
	ticks.shown = 0
end

local function showTicks(castbar, name)
	hideTicks(castbar)
	local count = castbar.isChannel and config.castbarTicks and channelTicks[name]
	local bar = castbar.bar
	local width = bar:GetWidth()
	if not count or width <= 0 then
		return
	end
	local ticks = castbar.ticks
	for i = 1, count - 1 do
		local tick = ticks[i]
		if not tick then
			tick = bar:CreateTexture(nil, "ARTWORK", nil, 3)
			tick:SetTexture(ns.Media.blank)
			tick:SetVertexColor(TICK_COLOR[1], TICK_COLOR[2], TICK_COLOR[3], TICK_COLOR[4])
			tick:SetWidth(TICK_WIDTH)
			ticks[i] = tick
		end
		local x = width * i / count
		tick:ClearAllPoints()
		tick:SetPoint("TOP", bar, "TOPLEFT", x, 0)
		tick:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x, 0)
		tick:Show()
	end
	ticks.shown = count - 1
end

local function setLatency(castbar, seconds)
	local zone = castbar.latency
	if not zone then
		return
	end
	local duration = castbar.duration
	if castbar.isChannel or not config.castbarLatency or not seconds or seconds <= 0 or duration <= 0 then
		zone:Hide()
		return
	end
	local width = castbar.bar:GetWidth() * min(seconds / duration, MAX_LATENCY_SHARE)
	if width < 1 then
		zone:Hide()
		return
	end
	zone:SetWidth(width)
	zone:SetVertexColor(unpack(config.castbarLatencyColor))
	zone:Show()
end

local sentAt

local function takeLatency()
	local latency = sentAt and GetTime() - sentAt
	sentAt = nil
	if latency and latency < LATENCY_TIMEOUT then
		return latency
	end
	local _, _, home = GetNetStats()
	return home / 1000
end

local function onCastSent(_, unit)
	if unit == "player" then
		sentAt = GetTime()
	end
end

local function stopCast(castbar, hold, fadeSpeed)
	castbar.casting = false
	castbar.cancelled = false
	castbar.stoppedAt = GetTime()
	castbar.hold = hold or 0
	castbar.fadeSpeed = fadeSpeed or FADE_SPEED
	castbar.bar:SetValue(castbar.isChannel and castbar.startTime or castbar.endTime)
	castbar.timer:SetText("")
	castbar.target:SetText("")
	castbar.glow:Hide()
	castbar.spark:Hide()
	castbar.startFlash = 0
	castbar.flash:Hide()
	hideTicks(castbar)
	if castbar.latency then
		castbar.latency:Hide()
	end
	setTargetingYou(castbar, false)
end

local function finishCast(castbar)
	if config.castbarFinishFlash then
		stopCast(castbar, FLASH_TIME, FINISH_FADE_SPEED)
		castbar.flash:SetAlpha(FLASH_ALPHA)
		castbar.flash:Show()
		castbar.flashing = true
	else
		stopCast(castbar)
	end
end

local function showInterrupted(castbar, text)
	if not config.castbarInterrupter then
		castbar.name:SetText(INTERRUPTED_TEXT)
		stopCast(castbar)
		return
	end
	stopCast(castbar, INTERRUPT_HOLD, INTERRUPT_FADE_SPEED)
	castbar.interrupted = true
	castbar.name:SetText(text or INTERRUPTED_TEXT)
	local bar = castbar.bar
	local _, max = bar:GetMinMaxValues()
	bar:SetValue(max)
	UF.SetBarColor(bar, INTERRUPT_COLOR[1], INTERRUPT_COLOR[2], INTERRUPT_COLOR[3])
	castbar:SetAlpha(1)
end

local function showCancelled(castbar)
	if config.castbarInterrupter then
		stopCast(castbar, INTERRUPT_HOLD, INTERRUPT_FADE_SPEED)
	else
		stopCast(castbar)
	end
	castbar.cancelled = true
	castbar.name:SetText(CANCELLED_TEXT)
end

local testCast, finishTest

local function randomClassColor()
	return UF.classColors[UF.classList[random(#UF.classList)]]
end

local function randomTestName()
	return TEST_NAMES[random(#TEST_NAMES)]
end

local function onUpdate(castbar, elapsed)
	if castbar.casting then
		local remain = castbar.remain - elapsed
		castbar.remain = remain
		if remain > 0 then
			setProgress(castbar, remain)
		elseif castbar.testing then
			finishTest(castbar)
			return
		elseif remain < -STOP_TIMEOUT then
			stopCast(castbar)
			return
		else
			setProgress(castbar, 0)
		end
		local startFlash = castbar.startFlash
		if startFlash > 0 then
			startFlash = startFlash - elapsed
			castbar.startFlash = startFlash
			if startFlash > 0 then
				castbar.flash:SetAlpha(START_FLASH_ALPHA * startFlash / START_FLASH_TIME)
			else
				castbar.flash:Hide()
			end
		end
		if castbar.important then
			pulseCastGlow(castbar.glow, elapsed)
		end
		return
	end

	local hold = castbar.hold
	if hold > 0 then
		hold = hold - elapsed
		castbar.hold = hold
		if castbar.flashing then
			if hold > 0 then
				castbar.flash:SetAlpha(FLASH_ALPHA * hold / FLASH_TIME)
			else
				castbar.flash:Hide()
				castbar.flashing = false
			end
		end
		return
	end

	local alpha = castbar:GetAlpha() - elapsed * castbar.fadeSpeed
	if alpha > 0 then
		castbar:SetAlpha(alpha)
	elseif castbar.testing then
		testCast(castbar)
	else
		castbar:Hide()
	end
end

local function startCast(castbar, name, texture, startTime, endTime, isChannel, castId, interruptible)
	if castbar.disabled then
		return
	end
	layoutText(castbar)
	castbar.spellName = name
	castbar.name:SetText(name ~= "" and name or UNKNOWN)
	castbar.icon:SetTexture(texture ~= "" and texture or ns.Media.questionMark)
	castbar.isChannel = isChannel
	setInterruptible(castbar, interruptible)

	castbar.castId = castId
	castbar.interrupted = false
	castbar.flashing = false
	if castbar.casting then
		castbar.startFlash = 0
		castbar.flash:Hide()
	else
		castbar.startFlash = START_FLASH_TIME
		castbar.flash:SetAlpha(START_FLASH_ALPHA)
		castbar.flash:Show()
	end
	castbar.showTotal = config.castbarTimeFormat == "total"
	setTimes(castbar, startTime, endTime)
	setProgress(castbar, castbar.remain)
	showTicks(castbar, name)
	if castbar.latency then
		castbar.latency:Hide()
	end

	castbar.important = config.castbarImportant and importantCasts[name] or false
	if castbar.important then
		UF.StartCastGlow(castbar.glow, config.castbarImportantColor)
	else
		castbar.glow:Hide()
	end

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
		castbar.casting = false
		castbar:Hide()
		return
	end

	startCast(castbar, name, texture, startTime / 1e3, endTime / 1e3, isChannel, castId, not notInterruptible)
	castbar.guid = UnitGUID(unit)
	if castbar.latency and castbar.casting then
		setLatency(castbar, takeLatency())
	end
	updateCastTarget(castbar)
end

function testCast(castbar)
	local isChannel = random(3) == 1
	local spells = isChannel and TEST_CHANNELS or TEST_CASTS
	local name, _, texture = GetSpellInfo(spells[random(#spells)])
	local now = GetTime()
	local duration = random(15, 30) / 10
	startCast(castbar, name, texture, now, now + duration, isChannel, nil, random(4) ~= 1)
	setLatency(castbar, random(5, 30) / 100)

	local target = castbar.target
	if config.castbarTargetName and random(4) ~= 1 then
		local color = randomClassColor()
		target:SetText(randomTestName())
		target:SetTextColor(color[1], color[2], color[3])
	else
		target:SetText("")
	end
	setTargetingYou(castbar, config.castbarTargetingYou and not castbar.isPlayer and random(4) == 1)
end

function finishTest(castbar)
	if random(4) == 1 then
		showInterrupted(castbar, interruptedByText(randomClassColor(), randomTestName()))
	else
		finishCast(castbar)
	end
end

local function test(frame)
	local castbar = frame.castbar
	castbar.testing = true
	testCast(castbar)
end

function UF.SetCastbarShown(castbar, shown)
	local disabled = not shown
	if (castbar.disabled or false) == disabled then
		return
	end
	castbar.disabled = disabled
	local frame = castbar:GetParent()
	if disabled then
		castbar.casting = false
		castbar.testing = nil
		castbar:Hide()
	elseif frame.test then
		test(frame)
	elseif frame:IsShown() and not UF.testing then
		update(frame)
	end
end

local silencedAt, silenceTexts = {}, {}

local function recentSilence(guid)
	local at = guid and silencedAt[guid]
	if at and GetTime() - at < LATE_INTERRUPT then
		return silenceTexts[guid]
	end
end
UF.RecentSilence = recentSilence

local function onCastFailed(frame, _, _, castId)
	local castbar = frame.castbar
	if castbar.casting and not castbar.isChannel and castId and castId == castbar.castId then
		castbar.name:SetText(FAILED_TEXT)
		stopCast(castbar)
	end
end

local function onCastInterrupted(frame, _, _, castId)
	local castbar = frame.castbar
	if castbar.casting and (castbar.isChannel or castId == castbar.castId) then
		local text = recentSilence(castbar.guid)
		if text then
			showInterrupted(castbar, text)
		else
			showCancelled(castbar)
		end
	end
end

local function onCastStop(frame)
	local castbar = frame.castbar
	if castbar.casting then
		if castbar.remain < FINISH_WINDOW then
			finishCast(castbar)
		else
			stopCast(castbar)
		end
	end
end

local function poll(frame)
	local castbar = frame.castbar
	if castbar.disabled then
		return
	end
	local unit = frame.unit
	local name, _, _, _, startTime, endTime, _, castId = UnitCastingInfo(unit)
	if not name then
		name, _, _, _, startTime, endTime = UnitChannelInfo(unit)
		castId = nil
	end
	if not name then
		if castbar.casting then
			onCastStop(frame)
		end
	elseif
		not castbar.casting
		or name ~= castbar.spellName
		or castId ~= castbar.castId
		or UnitGUID(unit) ~= castbar.guid
	then
		update(frame)
	elseif endTime / 1e3 ~= castbar.endTime then
		setTimes(castbar, startTime / 1e3, endTime / 1e3)
		setProgress(castbar, castbar.remain)
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

local function onCastAura(frame)
	local castbar = frame.castbar
	if castbar.casting and not castbar.testing then
		showInterruptible(castbar)
	end
end

local function onUnitTarget(frame)
	local castbar = frame.castbar
	if castbar.casting then
		ns.Defer(castbar, updateCastTarget)
	end
end

local function onInterrupter(frame, guid, text)
	local castbar = frame.castbar
	if castbar.guid ~= guid or not castbar:IsShown() then
		return
	end
	if castbar.casting or not castbar.interrupted and GetTime() - castbar.stoppedAt < LATE_INTERRUPT then
		showInterrupted(castbar, text)
	elseif castbar.interrupted and castbar.hold > 0 then
		castbar.name:SetText(text)
	end
end

local function onSilenced(frame, guid, text)
	local castbar = frame.castbar
	if castbar.guid ~= guid or not castbar:IsShown() then
		return
	end
	if castbar.cancelled and not castbar.casting and GetTime() - castbar.stoppedAt < LATE_INTERRUPT then
		showInterrupted(castbar, text)
	end
end

local interruptWatcher = ns.Mixin({}, ns.EventMixin)
interruptWatcher:RegisterEvent(
	"COMBAT_LOG_EVENT_UNFILTERED",
	function(_, _, event, sourceGUID, sourceName, sourceFlags, destGUID, _, _, spellId)
		if event == "SPELL_INTERRUPT" then
			ns:Fire(UF.CAST_INTERRUPTED, destGUID, interrupterText(sourceGUID, sourceName, sourceFlags))
		elseif event == "SPELL_AURA_APPLIED" and DR_SPELLS[spellId] == "silence" then
			local text = interrupterText(sourceGUID, sourceName, sourceFlags)
			silencedAt[destGUID] = GetTime()
			silenceTexts[destGUID] = text
			ns:Fire(UF.CAST_SILENCED, destGUID, text)
		end
	end
)
interruptWatcher:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	wipe(silencedAt)
	wipe(silenceTexts)
end)

local function createText(bar)
	local text = bar:CreateFontString(nil, "OVERLAY")
	ns.SetFont(text, config.castbarFont.size, config.castbarFont.outline)
	return text
end

local function create(frame, iconSide)
	local castbar = CreateFrame("Frame", nil, frame)
	castbar:Hide()
	castbar:SetFrameLevel(frame:GetFrameLevel())
	castbar:SetBackdrop(UF.backdrop)
	UF.SetBackdropColors(castbar)
	castbar.unit = frame.unit
	castbar.targetUnit = frame.unit .. "target"
	castbar.isPlayer = frame.unit == "player"
	castbar.hold = 0
	castbar.stoppedAt = 0
	castbar.fadeSpeed = FADE_SPEED
	castbar:SetScript("OnUpdate", onUpdate)

	local bar = CreateFrame("StatusBar", nil, castbar)
	bar:SetPoint("TOPLEFT", BORDER_INSET, -BORDER_INSET)
	bar:SetPoint("BOTTOMRIGHT", -BORDER_INSET, BORDER_INSET)
	bar:SetMinMaxValues(0, 1)
	ns.SkinStatusBar(bar)
	castbar.bar = bar

	bar.bg = bar:CreateTexture(nil, "BORDER")
	bar.bg:SetAllPoints()
	bar.bg:SetTexture(ns.Media.blank)

	castbar.spark = bar:CreateTexture(nil, "ARTWORK", nil, 7)
	castbar.spark:SetTexture(SPARK_TEXTURE)
	castbar.spark:SetBlendMode("ADD")
	castbar.spark:SetWidth(SPARK_WIDTH)
	castbar.spark:Hide()
	castbar.startFlash = 0

	castbar.flash = bar:CreateTexture(nil, "OVERLAY")
	castbar.flash:SetAllPoints()
	castbar.flash:SetTexture(ns.Media.blank)
	castbar.flash:SetBlendMode("ADD")
	castbar.flash:Hide()

	castbar.ticks = { shown = 0 }
	if castbar.isPlayer then
		local latency = bar:CreateTexture(nil, "ARTWORK", nil, 2)
		latency:SetTexture(ns.Media.blank)
		latency:SetPoint("TOPRIGHT")
		latency:SetPoint("BOTTOMRIGHT")
		latency:Hide()
		castbar.latency = latency
	end

	castbar.glow = UF.CreateCastGlow(castbar, castbar, GLOW_SIZE)

	castbar.icon = castbar:CreateTexture(nil, "BORDER")
	castbar.icon:SetNonBlocking(true)
	if iconSide == "RIGHT" then
		castbar.icon:SetPoint("LEFT", castbar, "RIGHT", ICON_GAP, 0)
	else
		castbar.icon:SetPoint("RIGHT", castbar, "LEFT", -ICON_GAP, 0)
	end
	castbar.iconBorder = castbar:CreateTexture(nil, "ARTWORK")
	castbar.iconBorder:SetTexture(ns.Media.buttonNormal)
	castbar.iconBorder:SetAllPoints(castbar.icon)

	castbar.timer = createText(bar)
	castbar.timer:SetPoint("RIGHT")
	castbar.timer:SetJustifyH("LEFT")

	castbar.target = createText(bar)
	castbar.target:SetPoint("RIGHT", castbar.timer, "LEFT", -TEXT_INSET, 0)
	castbar.target:SetJustifyH("RIGHT")
	castbar.target:SetWordWrap(false)

	castbar.name = createText(bar)
	castbar.name:SetWordWrap(false)
	layoutText(castbar)

	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", update)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", update)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", onCastFailed)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", onCastFailed)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", onCastStop)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", onCastInterrupted)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", onCastStop)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", onCastDelayed)
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", onChannelUpdate)
	if frame.unit == "target" or frame.unit == "focus" then
		frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", onInterruptible)
		frame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", onNotInterruptible)
	end
	frame:RegisterUnitEvent("UNIT_TARGET", onUnitTarget)
	frame:RegisterEvent(UF.CAST_INTERRUPTED, onInterrupter)
	frame:RegisterEvent(UF.CAST_SILENCED, onSilenced)
	if castbar.isPlayer then
		frame:RegisterEvent("UNIT_SPELLCAST_SENT", onCastSent)
	else
		frame:RegisterUnitEvent("UNIT_AURA", onCastAura)
	end

	return castbar
end

UF:RegisterElement("castbar", create, update, test, poll)
