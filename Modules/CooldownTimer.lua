local _, ns = ...

local ceil = math.ceil
local GetTime = GetTime

local CooldownTimer = ns:NewModule("CooldownTimer")

local MIN_DURATION = 1.5

local function setTimerText(timer, remain)
	if remain <= 3 then
		timer:SetTextColor(1, 0, 0)
		timer:SetFormattedText("%.1f", remain)
	elseif remain <= 60 then
		timer:SetTextColor(1, 1, 0)
		timer:SetText(ceil(remain))
	elseif remain <= 3600 then
		timer:SetTextColor(1, 1, 1)
		timer:SetText(ceil(remain / 60) .. "m")
	else
		timer:SetTextColor(0.6, 0.6, 0.6)
		timer:SetText(ceil(remain / 3600) .. "h")
	end
end

CooldownTimer.SetTimerText = setTimerText

local UPDATE_INTERVAL = 0.1

local function onUpdate(cooldown, elapsed)
	if not cooldown.endTime then
		return
	end

	cooldown.untilTick = cooldown.untilTick - elapsed
	if cooldown.untilTick > 0 then
		return
	end

	local remain = cooldown.endTime - GetTime()
	if remain > 0 then
		setTimerText(cooldown.timer, remain)
		cooldown.untilTick = remain <= 3 and 0 or UPDATE_INTERVAL
	else
		cooldown.endTime = nil
		cooldown.timer:Hide()
	end
end

local function onSetCooldown(cooldown, startTime, duration)
	if duration > MIN_DURATION then
		cooldown.endTime = startTime + duration
		cooldown.untilTick = 0
		cooldown.timer:Show()
	else
		cooldown.endTime = nil
		cooldown.timer:Hide()
	end
end

function CooldownTimer:Attach(cooldown, fontSize, parent)
	local timer = (parent or cooldown):CreateFontString(nil, "ARTWORK")
	timer:SetPoint("CENTER")
	timer:SetFont(ns.Media.font, fontSize or 12, "OUTLINE")
	timer:SetShadowOffset(1, -1)
	cooldown.timer = timer

	cooldown:SetScript("OnUpdate", onUpdate)
	hooksecurefunc(cooldown, "SetCooldown", onSetCooldown)
end
