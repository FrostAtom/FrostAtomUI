local _, ns = ...

local geterrorhandler = geterrorhandler
local collectgarbage = collectgarbage

local GC_PAUSE = 150
local COLLECT_GROWTH_KB = 2048

local heapAfterCollect = 0

local function collect()
	collectgarbage("collect")
	heapAfterCollect = collectgarbage("count")
end

local function runInitializer(name, module, handler)
	local ok, err = pcall(handler, module)
	if not ok then
		geterrorhandler()(("[%s] Initialize failed: %s"):format(name, tostring(err)))
	end
end

function ns.InitializeModules()
	for name, module in ns:IterateModules() do
		local enabled = not module.configKey or ns.Config[module.configKey].enabled
		if module.Initialize then
			if enabled then
				runInitializer(name, module, module.Initialize)
			end
			module.Initialize = nil
		end
		local initializers = module.initializers
		if initializers then
			if enabled then
				for i = 1, #initializers do
					runInitializer(name, module, initializers[i])
				end
			end
			module.initializers = nil
		end
	end

	collectgarbage("setpause", GC_PAUSE)
	collect()
end

local gcWatcher = ns.Mixin({}, ns.EventMixin)

gcWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if collectgarbage("count") - heapAfterCollect > COLLECT_GROWTH_KB then
		collect()
	end
end)
