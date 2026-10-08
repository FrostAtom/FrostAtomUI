local _, ns = ...

local API = {}
ns.API = API

local SETTINGS_ADDON = "FrostAtomUI_Config"

for _, key in ipairs({
	"seenTabs",
	"navCollapsed",
	"lastPage",
	"showAll",
	"windowPoint",
	"windowScale",
	"expandedSettings",
	"settingsTabs",
	"showAdvancedSettings",
	"seenNew",
	"lastReset",
}) do
	ns.Storage.Claim(key, "Settings window", "ui")
end

function API.GetUIState(key)
	return ns.Storage.Slot(key):Get()
end

function API.SetUIState(key, value)
	ns.Storage.Slot(key):Set(value)
end

function API.UIStore(key)
	return ns.Storage.Slot(key):Table()
end

local CATALOGS = {
	cooldowns = "CooldownData",
	control = "LoseControlData",
	alerts = "SpellAlertData",
	diminishing = "DRData",
}

function API.Catalog(name)
	local key = assert(CATALOGS[name], ("unknown catalog [%s]"):format(tostring(name)))
	return ns[key]
end

function API.FactoryValue(path)
	local node, last = ns.Defaults, nil
	for key in path:gmatch("[^.]+") do
		if last ~= nil then
			node = node[last]
			if type(node) ~= "table" then
				return false
			end
		end
		last = tonumber(key) or key
	end
	return true, node[last]
end

local actions = {}

function API.RegisterAction(name, func)
	actions[name] = func
end

function API.RunAction(name, ...)
	local func = actions[name]
	if func then
		return func(...)
	end
end

function API.HasAction(name)
	return actions[name] ~= nil
end

local previews, previewOrder = {}, {}

function API.RegisterPreview(name, handlers)
	if not previews[name] then
		previewOrder[#previewOrder + 1] = name
	end
	previews[name] = handlers
end

function API.GetPreview(name)
	local preview = previews[name]
	if preview and (not preview.IsAvailable or preview.IsAvailable()) then
		return preview
	end
end

function API.IsPreviewActive(name)
	local preview = previews[name]
	return preview ~= nil and preview.IsActive() and true or false
end

function API.SetPreview(name, active)
	local preview = API.GetPreview(name)
	if preview then
		preview.Set(active and true or false)
	end
end

function API.PreviewChanged(name)
	ns:Fire(ns.E.PREVIEW_CHANGED, name, API.IsPreviewActive(name))
end

function API.IteratePreviews()
	local i = 0
	return function()
		while true do
			i = i + 1
			local name = previewOrder[i]
			if not name then
				return nil
			end
			local preview = API.GetPreview(name)
			if preview then
				return name, preview
			end
		end
	end
end

local host

function API.SetSettingsHost(value)
	host = value
end

function API.LoadSettings(quiet)
	if not host then
		local loaded, reason = LoadAddOn(SETTINGS_ADDON)
		if not loaded then
			if not quiet then
				ns.Print(ns.L["cannot load FrostAtomUI_Config: %s"], _G["ADDON_" .. reason] or reason)
			end
			return nil
		end
	end
	return host
end

function API.GetSettingsHost()
	return host
end
