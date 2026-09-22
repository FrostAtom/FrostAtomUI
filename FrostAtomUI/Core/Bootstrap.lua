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

function ns.InitializeModules()
	for name, module in ns:IterateModules() do
		if module.Initialize then
			if module.configKey and not ns.Config[module.configKey].enabled then
				module.Initialize = nil
			else
				local ok, err = pcall(module.Initialize, module)
				if not ok then
					geterrorhandler()(("[%s] Initialize failed: %s"):format(name, tostring(err)))
				end
				module.Initialize = nil
			end
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
