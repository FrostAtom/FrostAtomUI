local _, ns = ...

local GetTime = GetTime

local Scheduler = {}
ns.Scheduler = Scheduler

local frame = CreateFrame("Frame")
frame:Hide()

local tickers, tickerCount = {}, 0
local tickerIndex = {}

local timers, timerCount = {}, 0

local deferred, deferredCount = {}, 0
local deferredIndex = {}

local function wake()
	frame:Show()
end

function Scheduler.AddTicker(key, callback, interval)
	local entry = tickerIndex[key]
	if not entry then
		tickerCount = tickerCount + 1
		entry = { key = key }
		tickers[tickerCount] = entry
		tickerIndex[key] = entry
	end
	entry.callback = callback
	entry.interval = interval
	entry.nextTick = 0
	wake()
end

function Scheduler.RemoveTicker(key)
	local entry = tickerIndex[key]
	if entry then
		entry.removed = true
		tickerIndex[key] = nil
	end
end

function Scheduler.HasTicker(key)
	return tickerIndex[key] ~= nil
end

function Scheduler.After(delay, callback, arg)
	timerCount = timerCount + 1
	timers[timerCount] = { at = GetTime() + delay, callback = callback, arg = arg }
	wake()
end

function Scheduler.Defer(key, callback)
	if deferredIndex[key] then
		return
	end
	deferredCount = deferredCount + 1
	deferred[deferredCount] = key
	deferredIndex[key] = callback
	wake()
end

function Scheduler.Cancel(key)
	deferredIndex[key] = nil
end

local function runTickers(now)
	local i = 1
	while i <= tickerCount do
		local entry = tickers[i]
		if entry.removed then
			tickers[i] = tickers[tickerCount]
			tickers[tickerCount] = nil
			tickerCount = tickerCount - 1
		else
			if now >= entry.nextTick then
				entry.nextTick = now + entry.interval
				entry.callback(entry.key, now)
			end
			i = i + 1
		end
	end
end

local function runTimers(now)
	local i = 1
	while i <= timerCount do
		local timer = timers[i]
		if now >= timer.at then
			timers[i] = timers[timerCount]
			timers[timerCount] = nil
			timerCount = timerCount - 1
			timer.callback(timer.arg)
		else
			i = i + 1
		end
	end
end

local running = {}

local function runDeferred()
	local queue, count = deferred, deferredCount
	deferred, deferredCount = running, 0
	running = queue
	for i = 1, count do
		local key = queue[i]
		queue[i] = nil
		local callback = deferredIndex[key]
		if callback then
			deferredIndex[key] = nil
			callback(key)
		end
	end
end

frame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	if deferredCount > 0 then
		runDeferred()
	end
	if timerCount > 0 then
		runTimers(now)
	end
	if tickerCount > 0 then
		runTickers(now)
	end
	if deferredCount == 0 and timerCount == 0 and tickerCount == 0 then
		self:Hide()
	end
end)

ns.After = Scheduler.After
ns.Defer = Scheduler.Defer
