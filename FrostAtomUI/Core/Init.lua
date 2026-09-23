local ADDON_NAME, ns = ...

ns.PLAYER_CLASS = select(2, UnitClass("player"))
ns.IS_WOWCIRCLE = (GetCVar("realmlist") or ""):lower():find("wowcircle") ~= nil

function ns.SetShown(region, shown)
	if shown then
		region:Show()
	else
		region:Hide()
	end
end

function ns.Mixin(target, ...)
	for i = 1, select("#", ...) do
		local source = select(i, ...)
		for key, value in pairs(source) do
			target[key] = value
		end
	end
	return target
end

local modules = {}

ns.ModulePrototype = {}

function ns:NewModule(name)
	assert(name, "module name is required")
	assert(not modules[name], ("module [%s] already exists"):format(name))

	local module = ns.Mixin({ name = name }, ns.ModulePrototype)
	modules[name] = module
	return module
end

function ns.ModulePrototype:OnInitialize(handler)
	local handlers = self.initializers
	if not handlers then
		handlers = {}
		self.initializers = handlers
	end
	handlers[#handlers + 1] = handler
end

function ns:GetModule(name)
	return assert(modules[name], ("module [%s] is not loaded"):format(tostring(name)))
end

function ns:IterateModules()
	return pairs(modules)
end

_G[ADDON_NAME] = ns
