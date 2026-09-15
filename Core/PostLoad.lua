local namespace = select(2,...)

for _,module in namespace:iterModules() do
	if module.Initialize then
		module:Initialize()

		module.Initialize = nil
	end
end


collectgarbage()