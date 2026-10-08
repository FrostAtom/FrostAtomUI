local _, ns = ...

local Store = {}
ns.SettingsStore = Store

local copy

local function clone(value)
	return type(value) == "table" and copy(value) or value
end

function copy(source)
	local target = {}
	for key, value in pairs(source) do
		target[key] = clone(value)
	end
	return target
end

local merge

local function mergeValue(target, key, value)
	local current = target[key]
	if type(value) == "table" and type(current) == "table" then
		if value[1] ~= nil or current[1] ~= nil then
			wipe(current)
		end
		merge(current, value)
	else
		target[key] = clone(value)
	end
end

function merge(target, source)
	for key, value in pairs(source) do
		mergeValue(target, key, value)
	end
end

ns.Config = copy(ns.Defaults)

local DEFAULT_PROFILE = "Default"
Store.DEFAULT_PROFILE = DEFAULT_PROFILE

local Config = ns:NewModule("Config")
Store.module = Config
local saved = {}
local profilesSlot = ns.Storage.Claim("profiles", "Settings", "settings")
local layoutBaseSlot = ns.Storage.Slot("layoutBase")
local activeProfile = DEFAULT_PROFILE

local function walk(root, path, create)
	local node = root
	local last
	for key in path:gmatch("[^.]+") do
		key = tonumber(key) or key
		if last then
			local child = node[last]
			if child == nil then
				if not create then
					return nil
				end
				child = {}
				node[last] = child
			end
			node = child
		end
		last = key
	end
	return node, last
end

function ns:GetConfig(path)
	local node, key = walk(ns.Config, path)
	return node and node[key]
end

local function assign(node, key, value)
	if type(value) == "table" and type(node[key]) == "table" then
		wipe(node[key])
		merge(node[key], value)
	else
		node[key] = clone(value)
	end
end

local function listPathOf(path)
	return path:match("^(.-)%.%d+%.") or path:match("^(.-)%.%d+$")
end

local function saveWholeList(listPath)
	local listNode, listKey = walk(ns.Config, listPath)
	local store, storeKey = walk(saved, listPath, true)
	assign(store, storeKey, listNode[listKey])
end

function ns:SetConfig(path, value)
	local node, key = walk(ns.Config, path, true)
	assign(node, key, value)

	local listPath = listPathOf(path)
	if listPath then
		saveWholeList(listPath)
	else
		local store, storeKey = walk(saved, path, true)
		assign(store, storeKey, value)
	end
	ns:Fire(ns.E.CONFIG_CHANGED, path)
end

local function clearLayoutBase(profile)
	local bases = layoutBaseSlot:Get()
	if type(bases) == "table" then
		bases[profile] = nil
	end
end

local isSection, mergeKnown

local function factoryValue(path)
	local defaults, key = walk(ns.Defaults, path)
	return defaults and defaults[key]
end

local function baselineValue(path)
	local baseline = saved.baseline
	if type(baseline) == "table" and not listPathOf(path) then
		local node, key = walk(baseline, path)
		return node and node[key]
	end
end

local function startingValue(path)
	local value, base = factoryValue(path), baselineValue(path)
	if base == nil then
		return value
	elseif isSection(base, value) then
		local result = copy(value)
		mergeKnown(result, base, value)
		return result
	end
	return base
end

function ns:GetFactoryConfig(path)
	return factoryValue(path)
end

function ns:GetBaselineConfig(path)
	return baselineValue(path)
end

function ns:GetDefaultConfig(path)
	return startingValue(path)
end

local function reset(target, defaults)
	for key in pairs(target) do
		if defaults[key] == nil then
			target[key] = nil
		end
	end
	for key, value in pairs(defaults) do
		if type(value) == "table" and type(target[key]) == "table" then
			reset(target[key], value)
		else
			target[key] = clone(value)
		end
	end
end

function ns:ResetConfig(path, factory)
	if not path then
		wipe(saved)
		clearLayoutBase(activeProfile)
		reset(ns.Config, ns.Defaults)
		ns:Fire(ns.E.CONFIG_CHANGED)
		return
	end
	local listPath = listPathOf(path)
	if factory and not listPath and type(saved.baseline) == "table" then
		local base, baseKey = walk(saved.baseline, path)
		if base then
			base[baseKey] = nil
		end
	end
	local node, key = walk(ns.Config, path, true)
	assign(node, key, startingValue(path))

	if listPath then
		saveWholeList(listPath)
	else
		local store, storeKey = walk(saved, path)
		if store then
			store[storeKey] = nil
		end
	end
	ns:Fire(ns.E.CONFIG_CHANGED, path)
end

function ns:SetBaselineConfig(path, value)
	if listPathOf(path) then
		if value == nil then
			ns:ResetConfig(path)
		else
			ns:SetConfig(path, value)
		end
		return
	end
	if type(saved.baseline) ~= "table" then
		saved.baseline = {}
	end
	local store, key = walk(saved.baseline, path, true)
	assign(store, key, value)
	ns:ResetConfig(path)
end

function ns:KeepBaselineAsOwn(profileName, paths)
	local profile = profileName == activeProfile and saved or profilesSlot:Get()[profileName]
	local baseline = type(profile) == "table" and profile.baseline
	if type(baseline) ~= "table" then
		return
	end
	for _, path in ipairs(paths) do
		local node, key = walk(baseline, path)
		if node and node[key] ~= nil and not listPathOf(path) then
			local store, storeKey = walk(profile, path, true)
			if store[storeKey] == nil then
				store[storeKey] = node[key]
			end
			node[key] = nil
		end
	end
end

function ns:IsDefaultConfig(path)
	local store, key = walk(saved, path)
	if not store or store[key] == nil then
		return true
	end
	return type(store[key]) == "table" and next(store[key]) == nil
end

function isSection(value, default)
	return type(value) == "table"
		and type(default) == "table"
		and default[1] == nil
		and value[1] == nil
		and next(default) ~= nil
end

local function compatible(value, default)
	local valueType, defaultType = type(value), type(default)
	if valueType == defaultType then
		return true
	end
	if valueType == "table" or defaultType == "table" then
		return false
	end
	return valueType == "boolean" or defaultType == "boolean"
end

local function prune(target, defaults)
	for key, value in pairs(target) do
		local default = defaults[key]
		if default == nil or not compatible(value, default) then
			target[key] = nil
		elseif isSection(value, default) then
			prune(value, default)
		end
	end
end

function mergeKnown(target, source, defaults)
	for key, value in pairs(source) do
		local default = defaults[key]
		if default ~= nil and compatible(value, default) then
			local current = target[key]
			if isSection(value, default) and type(current) == "table" then
				mergeKnown(current, value, default)
			else
				mergeValue(target, key, value)
			end
		end
	end
end

local function pruned(profile)
	local result = copy(profile)
	prune(result, ns.Defaults)
	return result
end

local function rebuildFromSaved()
	reset(ns.Config, ns.Defaults)
	if type(saved.baseline) == "table" then
		mergeKnown(ns.Config, saved.baseline, ns.Defaults)
	end
	mergeKnown(ns.Config, saved, ns.Defaults)
end

local function replaceSaved(profile)
	wipe(saved)
	merge(saved, profile)
	rebuildFromSaved()
end

function ns:GetActiveProfile()
	return activeProfile
end

function Store.Saved()
	return saved
end

function Store.Bind(name, profile)
	saved, activeProfile = profile, name
end

Store.copy = copy
Store.clearLayoutBase = clearLayoutBase
Store.prune = prune
Store.pruned = pruned
Store.rebuildFromSaved = rebuildFromSaved
Store.replaceSaved = replaceSaved

ns.ConfigStore = {
	slot = function(path)
		return listPathOf(path) or path
	end,
	read = function(path)
		local node, key = walk(saved, path)
		local own, base = node and clone(node[key]), nil
		if type(saved.baseline) == "table" then
			node, key = walk(saved.baseline, path)
			base = node and clone(node[key])
		end
		return own, base
	end,
	write = function(path, own, base)
		local node, key = walk(saved, path, own ~= nil)
		if node then
			node[key] = clone(own)
		end
		if base ~= nil and type(saved.baseline) ~= "table" then
			saved.baseline = {}
		end
		if type(saved.baseline) == "table" then
			node, key = walk(saved.baseline, path, base ~= nil)
			if node then
				node[key] = clone(base)
			end
		end
	end,
	readAll = function()
		return copy(saved)
	end,
	writeAll = function(profile)
		wipe(saved)
		merge(saved, profile)
	end,
	rebuild = function()
		rebuildFromSaved()
	end,
	upgrade = function(profile, version)
		Store.Upgrade(profile, version)
	end,
	version = function()
		return Store.SCHEMA_VERSION
	end,
}
