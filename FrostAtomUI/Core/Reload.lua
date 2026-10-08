local _, ns = ...

local exact, prefixes = {}, {}
local loaded
local extras = {}
local announced = ""

function ns:RegisterReloadPaths(...)
	for i = 1, select("#", ...) do
		local path = select(i, ...)
		if path:sub(-1) == "." then
			prefixes[#prefixes + 1] = path
		else
			exact[path] = true
		end
	end
end

local function moduleKeys()
	local keys = {}
	for _, module in ns:IterateModules() do
		if module.configKey then
			keys[module.configKey .. ".enabled"] = true
		end
	end
	return keys
end

local moduleCache

function ns.RequiresReload(path)
	if not path then
		return false
	end
	if exact[path] then
		return true
	end
	moduleCache = moduleCache or moduleKeys()
	if moduleCache[path] then
		return true
	end
	for i = 1, #prefixes do
		if path:sub(1, #prefixes[i]) == prefixes[i] then
			return true
		end
	end
	return false
end

local function copy(value)
	return type(value) == "table" and CopyTable(value) or value
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function reloadPaths()
	local paths = {}
	moduleCache = moduleCache or moduleKeys()
	for path in pairs(exact) do
		paths[#paths + 1] = path
	end
	for path in pairs(moduleCache) do
		if not exact[path] then
			paths[#paths + 1] = path
		end
	end
	for _, prefix in ipairs(prefixes) do
		local section = ns:GetConfig(prefix:sub(1, -2))
		if type(section) == "table" then
			for key in pairs(section) do
				paths[#paths + 1] = prefix .. key
			end
		end
	end
	return paths
end

local function capture()
	loaded = {}
	for _, path in ipairs(reloadPaths()) do
		loaded[path] = copy(ns:GetConfig(path))
	end
end

function ns.PendingReload()
	local list = {}
	if not loaded then
		return list
	end
	for path, value in pairs(loaded) do
		if not same(ns:GetConfig(path), value) then
			list[#list + 1] = path
		end
	end
	table.sort(list)
	return list, extras
end

function ns.RequireReload(label)
	extras[label] = true
	ns:Fire(ns.E.RELOAD_REQUIRED, ns.PendingReload())
end

local function reconcile()
	local list = ns.PendingReload()
	local key = table.concat(list, ",")
	if key ~= announced then
		announced = key
		if #list > 0 then
			ns:Fire(ns.E.RELOAD_REQUIRED, list)
		end
	end
end

StaticPopupDialogs.FROSTATOMUI_RELOAD_REQUIRED = {
	text = "%s",
	button2 = CANCEL,
	OnAccept = function()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local function offerReload(_, list)
	local host = ns.API.GetSettingsHost()
	if #list == 0 or host and host.IsWindowShown() then
		return
	end
	if ns.InArenaPreparation and ns.InArenaPreparation() then
		ns.Print(ns.L["some changes take effect after a UI reload; reload after the match"])
		return
	end
	StaticPopupDialogs.FROSTATOMUI_RELOAD_REQUIRED.button1 = ns.L["Reload now"]
	StaticPopup_Show(
		"FROSTATOMUI_RELOAD_REQUIRED",
		ns.L["Some settings of this profile take effect after a UI reload (5-10 s, your character stays in place). Reload now?"]
	)
end

local watcher = ns.Mixin({}, ns.EventMixin)
watcher:RegisterEvent(ns.E.RELOAD_REQUIRED, offerReload)
watcher:RegisterEvent(ns.E.DB_LOADED, function()
	moduleCache = nil
	capture()
end)
watcher:RegisterEvent(ns.E.CONFIG_CHANGED, function(_, path)
	if loaded and not path then
		reconcile()
	end
end)
