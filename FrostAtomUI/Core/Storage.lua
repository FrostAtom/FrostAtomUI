local ADDON_NAME, ns = ...

local DB_NAME = ADDON_NAME .. "DB"
local SPACES = { settings = true, state = true, ui = true, migrations = true }

local Storage = {}
ns.Storage = Storage

local root
local claims = {}
local slots = {}

local Slot = {}
Slot.__index = Slot

function Slot:Get()
	return root and root[self.key]
end

function Slot:Set(value)
	assert(root, "saved variables are not loaded yet")
	root[self.key] = value
end

function Slot:Table()
	assert(root, "saved variables are not loaded yet")
	local value = root[self.key]
	if type(value) ~= "table" then
		value = {}
		root[self.key] = value
	end
	return value
end

function Storage.Slot(key)
	local slot = slots[key]
	if not slot then
		slot = setmetatable({ key = key }, Slot)
		slots[key] = slot
	end
	return slot
end

function Storage.Claim(key, owner, space)
	assert(SPACES[space], ("unknown storage space [%s]"):format(tostring(space)))
	local claim = claims[key]
	assert(
		not claim or claim.owner == owner,
		("saved key [%s] already belongs to %s"):format(key, tostring(claim and claim.owner))
	)
	claims[key] = { owner = owner, space = space }
	return Storage.Slot(key)
end

function Storage.Load(data)
	root = data or _G[DB_NAME] or {}
	_G[DB_NAME] = root
end

function Storage.IsLoaded()
	return root ~= nil
end

function Storage.Unclaimed()
	local list = {}
	for key in pairs(slots) do
		if not claims[key] then
			list[#list + 1] = key
		end
	end
	for key in pairs(root or {}) do
		if not claims[key] and not slots[key] then
			list[#list + 1] = key
		end
	end
	table.sort(list)
	return list
end

local localeSlot = Storage.Claim("locale", "Locale", "settings")

function ns.GetLocaleOverride()
	return localeSlot:Get() or ""
end

function ns.SetLocaleOverride(locale)
	localeSlot:Set(locale ~= "" and locale or nil)
end

function ns.GetLocaleOptions()
	return ns.LocaleOptions(ns.GetLocaleOverride(), ns.Media and ns.Media.font)
end
