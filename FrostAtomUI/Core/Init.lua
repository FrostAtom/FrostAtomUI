local ADDON_NAME, ns = ...

ns.PLAYER_CLASS = select(2, UnitClass("player"))

function ns.SetShown(region, shown)
	if shown then
		region:Show()
	else
		region:Hide()
	end
end

local MAX_RECENT_ERRORS = 20
local recentErrors = {}
ns.recentErrors = recentErrors

local function errorHandler(err)
	if #recentErrors == MAX_RECENT_ERRORS then
		table.remove(recentErrors, 1)
	end
	recentErrors[#recentErrors + 1] = { time = time(), message = tostring(err), stack = debugstack(2, 12, 0) }
	return geterrorhandler()(err)
end

local DISPATCHER = [[
local xpcall, errorHandler = ...
local func%s
local function call()
	return func(%s)
end
return function(f, ...)
	func%s = f, ...
	local ok = xpcall(call, errorHandler)
	func%s = nil
	return ok
end
]]

local dispatchers = setmetatable({}, {
	__index = function(self, count)
		local names = {}
		for i = 1, count do
			names[i] = "a" .. i
		end
		local list = table.concat(names, ", ")
		local tail = count > 0 and ", " .. list or ""
		local code = DISPATCHER:format(tail, list, tail, tail)
		local dispatcher = assert(loadstring(code, "SafeCall[" .. count .. "]"))(xpcall, errorHandler)
		self[count] = dispatcher
		return dispatcher
	end,
})

function ns.SafeCall(func, ...)
	return dispatchers[select("#", ...)](func, ...)
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
local orderedModules = {}

ns.ModulePrototype = {}
local moduleMeta = { __index = ns.ModulePrototype }

function ns:NewModule(name)
	assert(name, "module name is required")
	assert(not modules[name], ("module [%s] already exists"):format(name))

	local module = setmetatable({ name = name }, moduleMeta)
	modules[name] = module
	orderedModules[#orderedModules + 1] = module
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

local function nextModule(_, index)
	index = index + 1
	local module = orderedModules[index]
	if module then
		return index, module
	end
end

function ns:IterateModules()
	return nextModule, nil, 0
end

_G[ADDON_NAME] = ns
