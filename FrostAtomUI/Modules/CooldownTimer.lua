local _, ns = ...

local L = ns.L

local ceil, min = math.ceil, math.min
local GetTime = GetTime

local Media = ns.Media
local CooldownTimer = ns:NewModule("CooldownTimer")

local UPDATE_INTERVAL = 0.1
local HIDDEN_INTERVAL = 0.25
local TICK_MARGIN = 0.01
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

local function untilTextChanges(remain)
	if remain <= decimalThreshold then
		return UPDATE_INTERVAL
	end
	local unit = remain <= 60 and 1 or remain <= 3600 and 60 or 3600
	local step = remain - (ceil(remain / unit) - 1) * unit + TICK_MARGIN
	return min(step, remain - decimalThreshold + TICK_MARGIN)
end

local active, activeCount = {}, 0
local activeIndex = {}

local ticker = CreateFrame("Frame")
ticker:Hide()

CooldownTimer:WatchConfig("cooldownTimer", function()
	for i = 1, activeCount do
		active[i].nextTick = 0
	end
end)

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
				local timer = cooldown.timer
				if timer:IsVisible() then
					cooldown.nextTick = now + untilTextChanges(remain)
					setTimerText(timer, remain)
				else
					cooldown.nextTick = now + HIDDEN_INTERVAL
				end
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
		cooldown.flashArmed = config.readyFlash and duration > FLASH_DURATION
	end
	local maxDuration = cooldown.timerMaxDuration
	if duration > (cooldown.timerMinDuration or minDuration) and not (maxDuration and duration > maxDuration) then
		local now = GetTime()
		if startTime + duration - now > duration + CLOCK_TOLERANCE then
			startTime = now
		end
		cooldown.endTime = startTime + duration
		local remain = cooldown.endTime - now
		cooldown.nextTick = now + untilTextChanges(remain)
		setTimerText(cooldown.timer, remain)
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

function CooldownTimer:CreateIcon(parent, options)
	local icon = CreateFrame("Frame", nil, parent)
	local texture = icon:CreateTexture(nil, "BORDER")
	texture:SetNonBlocking(true)
	icon.texture = texture
	local cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown = cooldown
	if options.reverse then
		cooldown:SetReverse(true)
	end
	local timerParent = options.timerOnIcon and icon or nil
	if options.borderAbove then
		local inset = options.inset
		if inset then
			texture:SetPoint("TOPLEFT", inset, -inset)
			texture:SetPoint("BOTTOMRIGHT", -inset, inset)
			texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		else
			texture:SetAllPoints()
		end
		cooldown:SetAllPoints(texture)
		local overlay = CreateFrame("Frame", nil, icon)
		overlay:SetAllPoints()
		overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
		icon.border = overlay:CreateTexture(nil, "ARTWORK")
		icon.border:SetTexture(Media.buttonNormal)
		icon.border:SetAllPoints()
		icon.overlay = overlay
		timerParent = overlay
	else
		ns.UIKit.SkinIcon(icon, texture)
		cooldown:SetAllPoints()
	end
	self:Attach(cooldown, options.fontSize, timerParent)
	if options.flash then
		self:AttachFlash(cooldown, texture)
	end
	return icon
end

function CooldownTimer:AttachFlash(cooldown, icon)
	local flash = icon:GetParent():CreateTexture(nil, "OVERLAY")
	flash:SetAllPoints(icon)
	flash:SetTexture(Media.blank)
	flash:SetBlendMode("ADD")
	flash:Hide()
	cooldown.flash = flash
end
