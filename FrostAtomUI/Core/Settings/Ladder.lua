local ADDON_NAME, ns = ...
local L = ns.L

local Store = ns.SettingsStore
local migrateLegacy, ONE_TIME_MIGRATIONS = Store.MigrateLegacy, Store.ONE_TIME_MIGRATIONS
local migrateHealthTags = Store.MigrateHealthTags

local LEGACY_DEFAULTS = {
	["actionBar.dragButton"] = "RightButton",
	["actionBar.dragModifier"] = "alt",
	["chat.shortChannelNames"] = true,
	["spellAlerts.zones.battleground"] = true,
	["announce.interrupts"] = true,
	["announce.auraMastery"] = true,
	["announce.arenaResultToParty"] = true,
	["tweaks.scriptErrors"] = true,
	["tweaks.hideGroundClutter"] = true,
	["tweaks.disableTutorials"] = true,
	["popups.fillDeleteConfirm"] = true,
	["popups.autoAcceptInvites"] = true,
	["combatAlert.enabled"] = true,
	["tooltip.showIds"] = true,
	["minimap.showZoneText"] = false,
	["groupCooldowns.zones.world"] = true,
	["dispelHighlightAlpha"] = 0,
	["dispelHighlightMode"] = "all",
	["unitFrames.classIconStyle"] = "spec",
}

local LEGACY_POINTS = {
	["lossOfControl.point"] = { "CENTER", 0, 0 },
	["tweaks.worldStatePoint"] = { "BOTTOMLEFT", -6, 30, "chat.point", "TOPLEFT" },
	["combatAlert.point"] = { "CENTER", 0, 150 },
}

local function preserveDefaults(profile, values)
	for path, value in pairs(values) do
		local node = profile
		local parent, key = path:match("^(.*)%.([^.]+)$")
		if not parent then
			parent, key = "", path
		end
		for segment in parent:gmatch("[^.]+") do
			if node[segment] == nil then
				node[segment] = {}
			end
			node = node[segment]
			if type(node) ~= "table" then
				break
			end
		end
		if type(node) == "table" and node[key] == nil then
			node[key] = type(value) == "table" and CopyTable(value) or value
		end
	end
end

local function mergeChoiceToggles(profile)
	local general = profile.general
	if type(general) == "table" then
		if general.useUiScale then
			general.uiScaleMode = general.pixelPerfectScale and "pixel" or "custom"
		end
		general.useUiScale, general.pixelPerfectScale = nil, nil
	end
	local tweaks = profile.tweaks
	if type(tweaks) == "table" then
		if tweaks.hideErrors == false then
			tweaks.errorMessages = tweaks.filterCooldownErrors == false and "all" or "filtered"
		end
		tweaks.hideErrors, tweaks.filterCooldownErrors = nil, nil
	end
end

local function sameLegacyValue(value, legacy)
	if type(value) == "table" and type(legacy) == "table" then
		for i = 1, 5 do
			if value[i] ~= legacy[i] then
				return false
			end
		end
		return true
	end
	return value == legacy
end

local function moveToBaseline(profile, values)
	for path, value in pairs(values) do
		local parent, key = path:match("^(.*)%.([^.]+)$")
		local node = profile
		for segment in (parent or ""):gmatch("[^.]+") do
			node = type(node) == "table" and node[segment] or nil
		end
		key = key or path
		if type(node) == "table" and sameLegacyValue(node[key], value) then
			node[key] = nil
			if type(profile.baseline) ~= "table" then
				profile.baseline = {}
			end
			preserveDefaults(profile.baseline, { [path] = value })
		end
	end
end

local SHARED_STYLE = {
	textColor = "theme.textColor",
	backdropColor = "theme.backdropColor",
	borderColor = "theme.borderColor",
	comboPointColor = "theme.comboPointColor",
	comboPointPartialColor = "theme.comboPointPartialColor",
	healPredictionColor = "theme.healPredictionColor",
	healPredictionOwnColor = "theme.healPredictionOwnColor",
	absorbColor = "theme.absorbColor",
	castbarColor = "castbar.color",
	castbarChannelColor = "castbar.channelColor",
	castbarLockedColor = "castbar.lockedColor",
	castbarTargetName = "castbar.targetName",
	castbarTargetingYou = "castbar.targetingYou",
	castbarTargetingYouColor = "castbar.targetingYouColor",
	castbarImportant = "castbar.important",
	castbarImportantColor = "castbar.importantColor",
	castbarInterrupter = "castbar.interrupter",
}

local function moveSharedStyle(profile)
	local unitFrames = type(profile) == "table" and profile.unitFrames
	if type(unitFrames) ~= "table" then
		return
	end
	for old, path in pairs(SHARED_STYLE) do
		local value = unitFrames[old]
		if value ~= nil then
			unitFrames[old] = nil
			local section, key = path:match("^(%w+)%.(%w+)$")
			if type(profile[section]) ~= "table" then
				profile[section] = {}
			end
			if profile[section][key] == nil then
				profile[section][key] = value
			end
		end
	end
end

local MERCHANT_WINDOW_OFF = {
	["merchant.showItemLevel"] = false,
	["merchant.searchBox"] = false,
	["merchant.filterMenu"] = false,
	["merchant.wideFrame"] = false,
}

local DIMINISH_SIDES = {
	LEFT = { "LEFT", "LEFT" },
	RIGHT = { "RIGHT", "RIGHT" },
	TOP = { "TOPRIGHT", "LEFT" },
	BOTTOM = { "BOTTOMRIGHT", "LEFT" },
}

local function migrateDiminishSides(profile)
	local config = type(profile) == "table" and profile.diminishingReturns
	if type(config) ~= "table" then
		return
	end
	for _, kind in ipairs({ "arena", "party", "target" }) do
		local side = DIMINISH_SIDES[config[kind .. "Side"]]
		config[kind .. "Side"] = nil
		if side then
			config[kind .. "Anchor"], config[kind .. "Growth"] = side[1], side[2]
		end
	end
end

local TRACKER_ROW_SHIFTS = { [-72] = -62, [-42] = -32, [-36] = -26 }

local function shiftTrackerRows(profile)
	local trackers = type(profile) == "table" and profile.trackers
	local groups = type(trackers) == "table" and trackers.groups
	if type(groups) ~= "table" then
		return
	end
	for _, group in ipairs(groups) do
		local point = type(group) == "table" and group.point
		if type(point) == "table" and point[1] == "CENTER" and point[2] == 0 and point[4] == nil then
			point[3] = TRACKER_ROW_SHIFTS[point[3]] or point[3]
		end
	end
end

ns.LegacyDefaults = { LEGACY_DEFAULTS, LEGACY_POINTS }
ns.SameLegacyValue = sameLegacyValue

local MIGRATIONS = {
	migrateLegacy,
	function(profile)
		preserveDefaults(profile, LEGACY_DEFAULTS)
	end,
	function(profile)
		mergeChoiceToggles(profile)
		preserveDefaults(profile, LEGACY_POINTS)
	end,
	function(profile)
		moveToBaseline(profile, LEGACY_DEFAULTS)
		moveToBaseline(profile, LEGACY_POINTS)
	end,
	function(profile)
		if type(profile.baseline) ~= "table" then
			profile.baseline = {}
		end
		preserveDefaults(profile.baseline, { ["unitFrames.classIconStyle"] = "spec" })
	end,
	function(profile)
		moveSharedStyle(profile)
		moveSharedStyle(profile.baseline)
	end,
	function(profile)
		if type(profile.baseline) ~= "table" then
			profile.baseline = {}
		end
		preserveDefaults(profile.baseline, { ["namePlates.totemFilter"] = "all" })
	end,
	function(profile)
		local merchant = profile.merchant
		if type(merchant) == "table" and merchant.enabled == false then
			preserveDefaults(profile, MERCHANT_WINDOW_OFF)
		end
	end,
	function(profile)
		migrateHealthTags(profile)
		migrateHealthTags(profile.baseline)
	end,
	function(profile)
		migrateDiminishSides(profile)
		migrateDiminishSides(profile.baseline)
	end,
	shiftTrackerRows,
}
local SCHEMA_VERSION = #MIGRATIONS

local function upgrade(profile, from, flags)
	for version = from + 1, SCHEMA_VERSION do
		MIGRATIONS[version](profile, flags)
	end
end

local Storage = ns.Storage
local profilesSlot = Storage.Slot("profiles")
local schemaSlot = Storage.Claim("schemaVersion", "Settings", "migrations")
local backupSlot = Storage.Claim("backup", "Settings", "migrations")
local flagSlots = {}
for _, migration in ipairs(ONE_TIME_MIGRATIONS) do
	flagSlots[migration[1]] = Storage.Claim(migration[1], "Settings", "migrations")
end

local function migratedFlags()
	local flags = {}
	for key, slot in pairs(flagSlots) do
		flags[key] = slot:Get()
	end
	return flags
end

local function backupProfiles(version)
	backupSlot:Set({
		schemaVersion = version,
		version = GetAddOnMetadata(ADDON_NAME, "Version"),
		time = time(),
		migrated = migratedFlags(),
		profiles = CopyTable(profilesSlot:Get()),
	})
end

local function upgradeSaved(version)
	local profiles = profilesSlot:Get()
	if next(profiles) then
		backupProfiles(version)
	end
	local flags = migratedFlags()
	for name, profile in pairs(profiles) do
		if type(profile) == "table" and not ns.SafeCall(upgrade, profile, version, flags) then
			profiles[name] = CopyTable(backupSlot:Get().profiles[name])
		end
	end
	for _, slot in pairs(flagSlots) do
		slot:Set(true)
	end
	schemaSlot:Set(SCHEMA_VERSION)
end

function ns:GetSchemaVersion()
	return schemaSlot:Get()
end

function ns:GetBackupTime()
	local backup = backupSlot:Get()
	return type(backup) == "table" and type(backup.profiles) == "table" and backup.time or nil
end

function ns:RestoreBackup()
	local backup = backupSlot:Get()
	if not ns:GetBackupTime() then
		return false
	end
	profilesSlot:Set(backup.profiles)
	schemaSlot:Set(backup.schemaVersion)
	for key, slot in pairs(flagSlots) do
		slot:Set(backup.migrated and backup.migrated[key])
	end
	backupSlot:Set(nil)
	return true
end

StaticPopupDialogs.FROSTATOMUI_RESTORE_BACKUP = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		if ns:RestoreBackup() then
			ReloadUI()
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

function ns.ConfirmRestoreBackup()
	local backupTime = ns:GetBackupTime()
	if not backupTime then
		ns.Print(L["no settings backup"])
		return
	end
	local text =
		L["Restore all profiles from the backup made before the settings upgrade (%s)? Changes made since then are lost and the UI reloads."]
	StaticPopup_Show("FROSTATOMUI_RESTORE_BACKUP", text:format(date("%Y-%m-%d %H:%M", backupTime)))
end

Store.SCHEMA_VERSION = SCHEMA_VERSION
Store.Upgrade = upgrade
Store.UpgradeSaved = upgradeSaved
