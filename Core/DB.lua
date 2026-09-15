local ADDON_NAME, ns = ...

-- Saved variables. Once loaded they live in `ns.db`; modules that need to
-- react to loading subscribe to the `ns.DB_LOADED` event and receive the table.

local DB_NAME = ADDON_NAME .. "DB"

ns.DB_LOADED = "FrostAtomUI_DB_LOADED"

local DB = ns:NewModule("DB")

function DB:ADDON_LOADED(addonName)
	if addonName ~= ADDON_NAME then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")

	ns.db = _G[DB_NAME] or {}
	_G[DB_NAME] = ns.db

	ns:Fire(ns.DB_LOADED, ns.db)
end

function ns:SaveVariable(key, value)
	assert(ns.db, "saved variables are not loaded yet")
	ns.db[key] = value
end

function DB:Initialize()
	self:RegisterEvent("ADDON_LOADED")
end
