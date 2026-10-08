local ADDON_NAME, ns = ...

local collectgarbage = collectgarbage
local InCombatLockdown = InCombatLockdown

local GC_PAUSE = 150
local COLLECT_GROWTH_KB = 2048
local COLLECT_STEP_KB = 256

local heapAfterCollect = 0

local function collect()
	collectgarbage("collect")
	heapAfterCollect = collectgarbage("count")
end

local function isEnabled(module)
	local key = module.configKey
	if not key then
		return true
	end
	local section = ns.Config[key]
	return type(section) == "table" and section.enabled
end

function ns.InitializeModules()
	for _, module in ns:IterateModules() do
		local enabled = isEnabled(module)
		module.initialized = enabled and true or false
		if module.Initialize then
			if enabled then
				ns.SafeCall(module.Initialize, module)
			end
			module.Initialize = nil
		end
		local initializers = module.initializers
		if initializers then
			if enabled then
				for i = 1, #initializers do
					ns.SafeCall(initializers[i], module)
				end
			end
			module.initializers = nil
		end
	end

	collectgarbage("setpause", GC_PAUSE)
	collect()
end

local loader = ns.Mixin({}, ns.EventMixin)
loader:RegisterEvent("ADDON_LOADED", function(self, addonName)
	if addonName ~= ADDON_NAME then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")
	ns.Storage.Load()
	ns.ApplyLocale(ns.Storage.Slot("locale"):Get(), ns.Media.font)
	ns:Fire(ns.E.DB_LOADED)
	ns.InitializeModules()
end)

local gcWatcher = ns.Mixin({}, ns.EventMixin)
local collectCycles = 0

local function collectStep(key)
	if InCombatLockdown() then
		ns.Scheduler.RemoveTicker(key)
	elseif collectgarbage("step", COLLECT_STEP_KB) then
		collectCycles = collectCycles + 1
		local heap = collectgarbage("count")
		if collectCycles == 2 or heap - heapAfterCollect <= COLLECT_GROWTH_KB then
			heapAfterCollect = heap
			ns.Scheduler.RemoveTicker(key)
		end
	end
end

gcWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if collectgarbage("count") - heapAfterCollect > COLLECT_GROWTH_KB then
		collectCycles = 0
		ns.Scheduler.AddTicker(gcWatcher, collectStep, 0)
	end
end)
