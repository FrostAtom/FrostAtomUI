local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetTime = GetTime

local FADE_SPEED = 1.4 -- alpha per second after a cast ends
local INTERRUPTED_TEXT = "|cff8B0000INTERRUPTED|r"
local FAILED_TEXT = "|cff808080FAILED|r"

--------------------------------------------------
-- Bar state

local function setInterruptible(castbar, interruptible)
	-- Own casts are never interruptible by the player, so keep them colored.
	if interruptible or castbar:GetParent().unit == "player" then
		castbar.icon:SetDesaturated(nil)
		castbar:SetStatusBarColor(0.75, 0.4, 0)
	else
		castbar.icon:SetDesaturated(1)
		castbar:SetStatusBarColor(0.4, 0.4, 0.4)
	end
end

local function setTimes(castbar, startTime, endTime)
	castbar.startTime = startTime
	castbar.endTime = endTime
	castbar.remain = endTime - GetTime()
	castbar:SetMinMaxValues(startTime, endTime)
end

-- Casts fill up, channels drain.
local function setProgress(castbar, remain)
	if castbar.isChannel then
		castbar:SetValue(castbar.startTime + remain)
	else
		castbar:SetValue(castbar.endTime - remain)
	end
	castbar.timer:SetFormattedText("%.1f", remain)
end

local function stopCast(castbar)
	castbar.casting = false
	castbar:SetValue(castbar.isChannel and castbar.startTime or castbar.endTime)
	castbar.timer:SetText("")
end

local function onUpdate(castbar, elapsed)
	if castbar.casting then
		local remain = castbar.remain - elapsed
		if remain > 0 then
			castbar.remain = remain
			setProgress(castbar, remain)
		else
			stopCast(castbar)
		end
		return
	end

	-- Fade out once the cast is over.
	local alpha = castbar:GetAlpha() - elapsed * FADE_SPEED
	if alpha > 0 then
		castbar:SetAlpha(alpha)
	else
		castbar:Hide()
	end
end

--------------------------------------------------
-- Events

local function update(frame)
	local unit = frame.unit
	local castbar = frame.castbar

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

	castbar.name:SetText(name ~= "" and name or "unknown")
	castbar.icon:SetTexture(texture ~= "" and texture or ns.Media.questionMark)
	setInterruptible(castbar, not notInterruptible)

	castbar.isChannel = isChannel
	castbar.castId = castId
	setTimes(castbar, startTime / 1e3, endTime / 1e3)
	setProgress(castbar, castbar.remain)

	castbar.casting = true
	castbar:SetAlpha(1)
	castbar:Show()
end

-- Both events carry the cast id; ignore stale ones from an earlier cast.
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

local function onCastDelayed(frame)
	local castbar = frame.castbar
	if not castbar.casting then
		return
	end

	local name, _, _, _, startTime, endTime = UnitCastingInfo(frame.unit)
	if name then
		setTimes(castbar, startTime / 1e3, endTime / 1e3)
		setProgress(castbar, castbar.remain)
	else
		stopCast(castbar)
	end
end

local function onChannelUpdate(frame)
	local castbar = frame.castbar
	if not castbar.casting then
		return
	end

	local name, _, _, _, startTime, endTime = UnitChannelInfo(frame.unit)
	if name then
		setTimes(castbar, startTime / 1e3, endTime / 1e3)
		setProgress(castbar, castbar.remain)
	else
		stopCast(castbar)
	end
end

local function onInterruptible(frame)
	setInterruptible(frame.castbar, true)
end

local function onNotInterruptible(frame)
	setInterruptible(frame.castbar, false)
end

--------------------------------------------------

local function create(frame)
	local castbar = CreateFrame("StatusBar", nil, frame)
	castbar:Hide()
	castbar:SetFrameLevel(frame:GetFrameLevel())
	castbar:SetMinMaxValues(0, 1)
	castbar:SetStatusBarTexture(ns.Media.blank)
	castbar:SetScript("OnUpdate", onUpdate)

	local bg = CreateFrame("Frame", nil, castbar)
	bg:SetFrameLevel(castbar:GetFrameLevel())
	bg:SetPoint("TOPRIGHT", 3, 3)
	bg:SetPoint("BOTTOMLEFT", -3, -3)
	bg:SetBackdrop(ns.CreateBackdrop(8))
	bg:SetBackdropColor(0, 0, 0, 0.8)
	bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.95)

	castbar.icon = castbar:CreateTexture(nil, "BORDER")
	castbar.icon:SetPoint("RIGHT", castbar, "LEFT", -2, 0)

	castbar.timer = castbar:CreateFontString(nil, "ARTWORK")
	castbar.timer:SetFont(ns.Media.font, 12, "OUTLINE")
	castbar.timer:SetPoint("RIGHT")
	castbar.timer:SetJustifyH("LEFT")

	castbar.name = castbar:CreateFontString(nil, "ARTWORK")
	castbar.name:SetFont(ns.Media.font, 12, "OUTLINE")
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

UF:RegisterElement("castbar", create, update)
