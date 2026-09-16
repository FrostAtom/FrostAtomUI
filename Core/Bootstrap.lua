local _, ns = ...

local geterrorhandler = geterrorhandler

for name, module in ns:IterateModules() do
	if module.Initialize then
		local ok, err = pcall(module.Initialize, module)
		if not ok then
			geterrorhandler()(("[%s] Initialize failed: %s"):format(name, tostring(err)))
		end
		module.Initialize = nil
	end
end

collectgarbage()
