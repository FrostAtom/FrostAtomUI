local _, ns = ...
local L = ns.L

local Realm = {}
ns.Realm = Realm

local NAMES = { wowcircle = "WoW Circle", other = "Other server" }

local detected = (GetCVar("realmlist") or ""):lower():find("wowcircle") and "wowcircle" or "other"
local slot = ns.Storage.Claim("realm", "Realm", "settings")
local waiting = {}

ns.IS_WOWCIRCLE = detected == "wowcircle"

function Realm.Active()
	return slot:Get() or detected
end

function ns.OnRealm(realm, callback)
	waiting[#waiting + 1] = { realm, callback }
end

function ns.GetRealmOverride()
	return slot:Get() or ""
end

function ns.SetRealmOverride(value)
	slot:Set(NAMES[value] and value or nil)
end

function ns.GetRealmOptions()
	return {
		{ "", L["Auto (%s)"]:format(L[NAMES[detected]]) },
		{ "wowcircle", L[NAMES.wowcircle] },
		{ "other", L[NAMES.other] },
	}
end

local watcher = ns.Mixin({}, ns.EventMixin)
watcher:RegisterEvent(ns.E.DB_LOADED, function()
	local active = Realm.Active()
	ns.IS_WOWCIRCLE = active == "wowcircle"
	for i = 1, #waiting do
		if waiting[i][1] == active then
			ns.SafeCall(waiting[i][2])
		end
	end
	wipe(waiting)
end)
