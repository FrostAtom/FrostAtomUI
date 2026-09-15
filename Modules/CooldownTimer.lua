local _, ns = ...

-- Adds a remaining-time text to any Cooldown frame.

local ceil = math.ceil
local GetTime = GetTime

local CooldownTimer = ns:NewModule("CooldownTimer")

-- Cooldowns shorter than this (global cooldown) do not get a timer.
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

local function onUpdate(cooldown, elapsed)
	if not cooldown.remain then
		return
	end

	local remain = cooldown.remain - elapsed
	if remain > 0 then
		setTimerText(cooldown.timer, remain)
		cooldown.remain = remain
	else
		cooldown.remain = nil
		cooldown.timer:Hide()
	end
end

local function onSetCooldown(cooldown, startTime, duration)
	if duration > MIN_DURATION then
		cooldown.remain = startTime + duration - GetTime()
		cooldown.timer:Show()
	else
		cooldown.remain = nil
		cooldown.timer:Hide()
	end
end

function CooldownTimer:Attach(cooldown, fontSize)
	local timer = cooldown:CreateFontString(nil, "ARTWORK")
	timer:SetPoint("CENTER")
	timer:SetFont(ns.Media.font, fontSize or 12, "OUTLINE")
	timer:SetShadowOffset(1, -1)
	cooldown.timer = timer

	cooldown:SetScript("OnUpdate", onUpdate)
	hooksecurefunc(cooldown, "SetCooldown", onSetCooldown)
end
