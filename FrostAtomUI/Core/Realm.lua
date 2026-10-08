local _, ns = ...
local L = ns.L

local Realm = {}
ns.Realm = Realm

local NAMES = { wowcircle = "WoW Circle", warmane = "Warmane", other = "Other server" }

local function detect()
	local realmlist = (GetCVar("realmlist") or ""):lower()
	if realmlist:find("wowcircle") then
		return "wowcircle"
	elseif realmlist:find("warmane") then
		return "warmane"
	end
	return "other"
end

local detected = detect()
local slot = ns.Storage.Claim("realm", "Realm", "settings")
local waiting = {}

ns.IS_WOWCIRCLE = detected == "wowcircle"

function Realm.Active()
	return slot:Get() or detected
end

function ns.OnRealm(realms, callback)
	if type(realms) == "string" then
		realms = { realms }
	end
	waiting[#waiting + 1] = { realms, callback }
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
		{ "warmane", L[NAMES.warmane] },
		{ "other", L[NAMES.other] },
	}
end

local watcher = ns.Mixin({}, ns.EventMixin)
watcher:RegisterEvent(ns.E.DB_LOADED, function()
	local active = Realm.Active()
	ns.IS_WOWCIRCLE = active == "wowcircle"
	for i = 1, #waiting do
		for _, realm in ipairs(waiting[i][1]) do
			if realm == active then
				ns.SafeCall(waiting[i][2])
				break
			end
		end
	end
	wipe(waiting)
end)
