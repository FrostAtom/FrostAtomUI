local _, ns = ...

local geterrorhandler = geterrorhandler

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

	collectgarbage()
end
