local _, ns = ...

-- Loaded last (see the .toc): every module is defined by now.

for _, module in ns:IterateModules() do
	if module.Initialize then
		module:Initialize()
		module.Initialize = nil
	end
end

collectgarbage()
