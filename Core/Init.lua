local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.PLAYER_CLASS = select(2, UnitClass("player"))

-- Copies every field of the given mixins into `target` (like Blizzard's Mixin).
function ns.Mixin(target, ...)
	for i = 1, select("#", ...) do
		for key, value in pairs((select(i, ...))) do
			target[key] = value
		end
	end
	return target
end

--------------------------------------------------
-- Module registry
--
-- A module is a plain table that can subscribe to game events (see Events.lua).
-- If it defines `Initialize`, Bootstrap.lua calls it once every file is loaded.

local modules = {}

-- Base methods shared by every module; Events.lua adds the event API here.
ns.ModulePrototype = {}

function ns:NewModule(name)
	assert(name, "module name is required")
	assert(not modules[name], ("module [%s] already exists"):format(name))

	local module = ns.Mixin({ name = name }, ns.ModulePrototype)
	modules[name] = module
	return module
end

function ns:GetModule(name)
	return assert(modules[name], ("module [%s] is not loaded"):format(tostring(name)))
end

function ns:IterateModules()
	return pairs(modules)
end

-- Expose the namespace for /run debugging.
_G[ADDON_NAME] = ns
