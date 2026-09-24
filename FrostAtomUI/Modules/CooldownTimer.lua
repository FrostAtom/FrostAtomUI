local _, ns = ...

local L = ns.L

local ceil = math.ceil
local GetTime = GetTime

local Media = ns.Media
local CooldownTimer = ns:NewModule("CooldownTimer")

local UPDATE_INTERVAL = 0.1
local FLASH_DURATION = 0.75
local FLASH_PEAK = 0.3
local FLASH_ALPHA = 0.8
local HOURS_COLOR = { 0.6, 0.6, 0.6 }
local CLOCK_TOLERANCE = 2

local config = ns.Config.cooldownTimer
local minDuration, decimalThreshold = config.minDuration, config.decimalThreshold
local expiringColor, secondsColor, minutesColor = config.expiringColor, config.secondsColor, config.minutesColor
local colorGeneration = 0

local function setTimerColor(timer, color)
	if timer.color ~= color or timer.colorGeneration ~= colorGeneration then
		timer.color = color
		timer.colorGeneration = colorGeneration
		timer:SetTextColor(color[1], color[2], color[3])
	end
end

local function setTimerText(timer, remain)
	if remain <= decimalThreshold then
		setTimerColor(timer, expiringColor)
		timer:SetFormattedText("%.1f", remain)
	elseif remain <= 60 then
		setTimerColor(timer, secondsColor)
		timer:SetFormattedText("%d", ceil(remain))
	elseif remain <= 3600 then
		setTimerColor(timer, minutesColor)
		timer:SetFormattedText(L["%dm"], ceil(remain / 60))
	else
		setTimerColor(timer, HOURS_COLOR)
		timer:SetFormattedText(L["%dh"], ceil(remain / 3600))
	end
end

CooldownTimer:WatchConfig("cooldownTimer", function()
	minDuration, decimalThreshold = config.minDuration, config.decimalThreshold
	expiringColor, secondsColor, minutesColor = config.expiringColor, config.secondsColor, config.minutesColor
	colorGeneration = colorGeneration + 1
end)

CooldownTimer.SetTimerText = setTimerText

local active, activeCount = {}, 0
local activeIndex = {}

local ticker = CreateFrame("Frame")
ticker:Hide()

local function activate(cooldown)
	if activeIndex[cooldown] then
		return
	end
	activeCount = activeCount + 1
	active[activeCount] = cooldown
	activeIndex[cooldown] = activeCount
	ticker:Show()
end

local function deactivateAt(index)
	local cooldown = active[index]
	local last = active[activeCount]
	active[index] = last
	activeIndex[last] = index
	active[activeCount] = nil
	activeIndex[cooldown] = nil
	activeCount = activeCount - 1
end

local function updateFlash(flash, remain)
	local progress = 1 - remain / FLASH_DURATION
	if progress < FLASH_PEAK then
		flash:SetAlpha(FLASH_ALPHA * progress / FLASH_PEAK)
	else
		flash:SetAlpha(FLASH_ALPHA * (1 - progress) / (1 - FLASH_PEAK))
	end
	flash:Show()
end

ticker:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local i = 1
	while i <= activeCount do
		local cooldown = active[i]
		local remain = cooldown.endTime - now
		if remain > 0 then
			if now >= cooldown.nextTick then
				cooldown.nextTick = now + UPDATE_INTERVAL
				setTimerText(cooldown.timer, remain)
			end
			if remain < FLASH_DURATION and cooldown.flashArmed then
				updateFlash(cooldown.flash, remain)
			end
			i = i + 1
		else
			cooldown.endTime = nil
			cooldown.timer:Hide()
			if cooldown.flash then
				cooldown.flash:Hide()
			end
			deactivateAt(i)
		end
	end
	if activeCount == 0 then
		self:Hide()
	end
end)

local function onSetCooldown(cooldown, startTime, duration)
	local flash = cooldown.flash
	if flash then
		flash:Hide()
		cooldown.flashArmed = cooldown.flashConfig[cooldown.flashKey] and duration > FLASH_DURATION
	end
	local maxDuration = cooldown.timerMaxDuration
	if duration > (cooldown.timerMinDuration or minDuration) and not (maxDuration and duration > maxDuration) then
		local now = GetTime()
		if startTime + duration - now > duration + CLOCK_TOLERANCE then
			startTime = now
		end
		cooldown.endTime = startTime + duration
		cooldown.nextTick = 0
		cooldown.timer:Show()
		activate(cooldown)
	else
		cooldown.endTime = nil
		cooldown.timer:Hide()
		local index = activeIndex[cooldown]
		if index then
			deactivateAt(index)
		end
	end
end

function CooldownTimer:Attach(cooldown, fontSize, parent)
	local timer = (parent or cooldown):CreateFontString(nil, "ARTWORK")
	timer:SetPoint("CENTER")
	ns.SetFont(timer, fontSize or 12, "OUTLINE")
	timer:SetShadowOffset(1, -1)
	cooldown.timer = timer

	hooksecurefunc(cooldown, "SetCooldown", onSetCooldown)
end

function CooldownTimer:AttachFlash(cooldown, icon, config, key)
	local flash = icon:GetParent():CreateTexture(nil, "OVERLAY")
	flash:SetAllPoints(icon)
	flash:SetTexture(Media.blank)
	flash:SetBlendMode("ADD")
	flash:Hide()
	cooldown.flash = flash
	cooldown.flashConfig = config
	cooldown.flashKey = key
end
