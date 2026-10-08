local _, ns = ...
local L = ns.L

local sort = table.sort
local Store = ns.SettingsStore
local copy, prune, pruned = Store.copy, Store.prune, Store.pruned
local clearLayoutBase, rebuildFromSaved, replaceSaved =
	Store.clearLayoutBase, Store.rebuildFromSaved, Store.replaceSaved
local DEFAULT_PROFILE = Store.DEFAULT_PROFILE
local EXPORT_PREFIX = "FAUI2:"
local profilesSlot = ns.Storage.Slot("profiles")
local charSlot = ns.Storage.Claim("charProfile", "Settings", "settings")
local defaultSlot = ns.Storage.Claim("defaultProfile", "Settings", "settings")
local freshSlot = ns.Storage.Claim("freshInstall", "Settings", "state")
local legacySlot = ns.Storage.Claim("config", "Settings", "migrations")
local LEGACY_EXPORT_PREFIX = "FAUI1:"

local function charKey()
	return UnitName("player") .. " - " .. GetRealmName()
end

local function activate(name)
	local profiles = profilesSlot:Get()
	if type(profiles[name]) ~= "table" then
		profiles[name] = {}
	end
	Store.Bind(name, profiles[name])
	charSlot:Get()[charKey()] = name
	rebuildFromSaved()
end

function ns:GetProfileNames()
	local names = {}
	for name in pairs(profilesSlot:Get()) do
		names[#names + 1] = name
	end
	sort(names)
	return names
end

function ns:SetProfile(name)
	name = name and name:trim()
	if not name or name == "" or name == ns:GetActiveProfile() then
		return
	end
	activate(name)
	ns:Fire(ns.E.PROFILES_CHANGED)
	ns:Fire(ns.E.CONFIG_CHANGED)
end

function ns:CopyProfile(source)
	local profile = profilesSlot:Get()[source]
	if not profile or source == ns:GetActiveProfile() then
		return
	end
	replaceSaved(profile)
	ns:Fire(ns.E.CONFIG_CHANGED)
end

function ns:DeleteProfile(name)
	if name == ns:GetActiveProfile() or not profilesSlot:Get()[name] then
		return
	end
	profilesSlot:Get()[name] = nil
	clearLayoutBase(name)
	for char, profile in pairs(charSlot:Get()) do
		if profile == name then
			charSlot:Get()[char] = nil
		end
	end
	if defaultSlot:Get() == name then
		defaultSlot:Set(nil)
	end
	ns:Fire(ns.E.PROFILES_CHANGED)
end

function ns:NewProfile(name, empty, data)
	name = name and name:trim()
	if not name or name == "" or profilesSlot:Get()[name] then
		return false
	end
	profilesSlot:Get()[name] = data or empty and {} or copy(Store.Saved())
	local bases = ns.Storage.Slot("layoutBase"):Get()
	if not empty and not data and type(bases) == "table" then
		bases[name] = bases[ns:GetActiveProfile()]
	end
	ns:SetProfile(name)
	return true
end

function ns:RenameProfile(old, new)
	new = new and new:trim()
	local profiles, chars = profilesSlot:Get(), charSlot:Get()
	if not new or new == "" or profiles[new] or not profiles[old] then
		return false
	end
	profiles[new], profiles[old] = profiles[old], nil
	for char, profile in pairs(chars) do
		if profile == old then
			chars[char] = new
		end
	end
	if defaultSlot:Get() == old then
		defaultSlot:Set(new)
	end
	for _, key in ipairs({ "layoutBase", "snapshots" }) do
		local store = ns.Storage.Slot(key):Get()
		if type(store) == "table" then
			store[new], store[old] = store[old], nil
		end
	end
	if ns:GetActiveProfile() == old then
		Store.Bind(new, Store.Saved())
	end
	ns:Fire(ns.E.PROFILES_CHANGED)
	return true
end

function ns:GetDefaultProfile()
	local name = defaultSlot:Get()
	return name and profilesSlot:Get()[name] and name or DEFAULT_PROFILE
end

function ns:SetDefaultProfile(name)
	defaultSlot:Set(name ~= DEFAULT_PROFILE and profilesSlot:Get()[name] and name or nil)
	ns:Fire(ns.E.PROFILES_CHANGED)
end

local function upgradeLegacyImport(profile)
	Store.Migrate(profile)
	Store.Upgrade(profile, 1)
end

function ns:ExportProfile(mineOnly, name)
	local saved = name and profilesSlot:Get()[name] or Store.Saved()
	local profile = pruned(saved)
	if not mineOnly and type(saved.baseline) == "table" then
		profile.baseline = pruned(saved.baseline)
	end
	local payload = { schemaVersion = Store.SCHEMA_VERSION, profile = profile }
	return EXPORT_PREFIX .. ns.Encode(ns.Serialize(payload))
end

local function decodeProfile(text)
	local prefix = text:sub(1, #EXPORT_PREFIX)
	local legacy = prefix == LEGACY_EXPORT_PREFIX
	if prefix ~= EXPORT_PREFIX and not legacy then
		return nil, L["not a FrostAtom UI profile string"]
	end
	local body, err = ns.Decode(text:sub(#EXPORT_PREFIX + 1))
	if not body then
		return nil, err
	end
	local data = ns.Deserialize(body)
	if legacy and type(data) == "table" then
		return data, 0, true
	elseif type(data) == "table" and type(data.profile) == "table" then
		local version = data.schemaVersion
		if type(version) == "number" and version >= 0 and version % 1 == 0 then
			return data.profile, version
		end
	end
	return nil, L["malformed profile string"]
end

function ns:DecodeProfile(text)
	local profile, version, legacy = decodeProfile(text and text:trim() or "")
	if not profile then
		return nil, version
	end
	local ok
	if legacy then
		ok = ns.SafeCall(upgradeLegacyImport, profile)
	else
		ok = ns.SafeCall(Store.Upgrade, profile, version)
	end
	if not ok then
		return nil, L["malformed profile string"]
	end
	local baseline = profile.baseline
	prune(profile, ns.Defaults)
	if type(baseline) == "table" then
		prune(baseline, ns.Defaults)
		profile.baseline = baseline
	end
	if legacy then
		return profile, L["the string is from an older FrostAtom UI version: some settings may be reset to defaults"]
	elseif version > Store.SCHEMA_VERSION then
		return profile,
			L["the string is from a newer FrostAtom UI version: settings this version does not know are skipped"]
	end
	return profile
end

function ns:ReplaceProfile(profile)
	clearLayoutBase(ns:GetActiveProfile())
	replaceSaved(profile)
	ns:Fire(ns.E.CONFIG_CHANGED)
end

function ns:ImportProfile(text)
	local profile, message = ns:DecodeProfile(text)
	if not profile then
		return false, message
	end
	ns:ReplaceProfile(profile)
	return true, message
end

function ns:IsFreshInstall()
	return freshSlot:Get() == true
end

Store.module:RegisterEvent(ns.E.DB_LOADED, function()
	local profiles = profilesSlot:Table()
	charSlot:Table()
	local legacy = legacySlot:Get()
	if legacy then
		profiles[DEFAULT_PROFILE] = profiles[DEFAULT_PROFILE] or legacy
		legacySlot:Set(nil)
	end
	freshSlot:Set(next(profiles) == nil or nil)
	local setupSlot = ns.Storage.Slot("setup")
	if type(setupSlot:Get()) ~= "table" then
		setupSlot:Set({ state = freshSlot:Get() and "pending" or "legacy" })
	end
	local version = tonumber(ns:GetSchemaVersion()) or 0
	if version > Store.SCHEMA_VERSION then
		ns.Print(
			L["settings were saved by a newer FrostAtom UI version: update the addon, changes made now may be lost"]
		)
	elseif version < Store.SCHEMA_VERSION then
		Store.UpgradeSaved(version)
	end
	activate(charSlot:Get()[charKey()] or ns:GetDefaultProfile())
	ns.ApplyGeneralConfig()
	ns:Fire(ns.E.CONFIG_CHANGED)
end)

local specSlot = ns.Storage.Claim("specProfiles", "Settings", "settings")
local SPEC_LINK = "faprofile"
local pendingSpec = false

function ns:GetSpecProfile(group)
	local map = specSlot:Table()[charKey()]
	return map and map[group]
end

function ns:SetSpecProfile(group, name)
	local all = specSlot:Table()
	local map = all[charKey()] or {}
	map[group] = name ~= "" and name or nil
	all[charKey()] = next(map) and map or nil
	ns:Fire(ns.E.PROFILES_CHANGED)
end

local function applySpecProfile(announce)
	local group = GetActiveTalentGroup()
	local name = ns:GetSpecProfile(group)
	local current = ns:GetActiveProfile()
	if not name or name == current or not profilesSlot:Get()[name] then
		return
	end
	if InCombatLockdown() then
		pendingSpec = true
		return
	end
	pendingSpec = false
	ns:SetProfile(name)
	if announce then
		ns.Print(
			L['profile "%s" is on for talent set %d.'] .. " |cff3399ff|H%s:%s|h[%s]|h|r",
			name,
			group,
			SPEC_LINK,
			current,
			L['Back to "%s"']:format(current)
		)
	end
end

ns.RegisterLink(SPEC_LINK, function(name)
	if not InCombatLockdown() then
		ns:SetProfile(name)
	end
end)

local specWatcher = ns.Mixin({}, ns.EventMixin)
specWatcher:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", function()
	applySpecProfile(true)
end)
specWatcher:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if pendingSpec then
		applySpecProfile(true)
	end
end)
local function onFirstWorld()
	specWatcher:UnregisterEvent("PLAYER_ENTERING_WORLD", onFirstWorld)
	applySpecProfile(false)
end
specWatcher:RegisterEvent("PLAYER_ENTERING_WORLD", onFirstWorld)
