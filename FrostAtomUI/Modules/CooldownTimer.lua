local _, ns = ...

local ceil = math.ceil
local GetTime = GetTime

local CooldownTimer = ns:NewModule("CooldownTimer")

local MIN_DURATION = 1.5
local UPDATE_INTERVAL = 0.1

local COLOR_URGENT, COLOR_SECONDS, COLOR_MINUTES, COLOR_HOURS = 1, 2, 3, 4

local function setTimerColor(timer, state, r, g, b)
	if timer.colorState ~= state then
		timer.colorState = state
		timer:SetTextColor(r, g, b)
	end
end

local function setTimerText(timer, remain)
	if remain <= 3 then
		setTimerColor(timer, COLOR_URGENT, 1, 0, 0)
		timer:SetFormattedText("%.1f", remain)
	elseif remain <= 60 then
		setTimerColor(timer, COLOR_SECONDS, 1, 1, 0)
		timer:SetFormattedText("%d", ceil(remain))
	elseif remain <= 3600 then
		setTimerColor(timer, COLOR_MINUTES, 1, 1, 1)
		timer:SetFormattedText("%dm", ceil(remain / 60))
	else
		setTimerColor(timer, COLOR_HOURS, 0.6, 0.6, 0.6)
		timer:SetFormattedText("%dh", ceil(remain / 3600))
	end
end

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
			i = i + 1
		else
			cooldown.endTime = nil
			cooldown.timer:Hide()
			deactivateAt(i)
		end
	end
	if activeCount == 0 then
		self:Hide()
	end
end)

local function onSetCooldown(cooldown, startTime, duration)
	if duration > MIN_DURATION then
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
