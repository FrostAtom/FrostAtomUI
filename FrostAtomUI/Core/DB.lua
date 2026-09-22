local ADDON_NAME, ns = ...

local DB_NAME = ADDON_NAME .. "DB"

ns.DB_LOADED = "FrostAtomUI_DB_LOADED"

local DB = ns:NewModule("DB")

DB:RegisterEvent("ADDON_LOADED", function(self, addonName)
	if addonName ~= ADDON_NAME then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")

	ns.db = _G[DB_NAME] or {}
	_G[DB_NAME] = ns.db

	ns.ApplyLocale(ns.db.locale)
	ns:Fire(ns.DB_LOADED, ns.db)
	ns.InitializeModules()
end)

function ns:SaveVariable(key, value)
	assert(ns.db, "saved variables are not loaded yet")
	ns.db[key] = value
end
