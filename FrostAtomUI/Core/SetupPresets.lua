local _, ns = ...

local L = ns.L

local FULLHD_HEIGHT = 1080
local START_DELAY = 5
local POLL_INTERVAL = 1
local TICKER = "setupStart"

local Presets = {}
ns.SetupPresets = Presets

local Storage = ns.Storage
local setupSlot = Storage.Claim("setup", "Setup", "state")
local stylesSlot = Storage.Claim("setupStyles", "Setup", "settings")
local explainedSlot = Storage.Claim("explained", "Setup", "state")
local explainedCharsSlot = Storage.Claim("explainedChars", "Setup", "state")
local whatsNewSlot = Storage.Claim("whatsNewSeen", "Setup", "ui")
local focusDefaultedSlot = Storage.Claim("focusKeyDefaulted", "Focus key", "state")
local focusAnnouncedSlot = Storage.Claim("focusKeyAnnounced", "Focus key", "state")

local FOCUS_LEGACY_KEY = "BUTTON5"
local FOCUS_COMMAND = "CLICK FrostAtomUIFocusButton:LeftButton"
ns.FOCUS_BUTTON_NAME = "FrostAtomUIFocusButton"
ns.FOCUS_BINDING = FOCUS_COMMAND
ns.FOCUS_MOUSE_KEY = FOCUS_LEGACY_KEY

function ns.IsFocusMouseKeyFree()
	local action = GetBindingAction(FOCUS_LEGACY_KEY)
	return action == "" or action == FOCUS_COMMAND
end

function ns.SetFocusMouseKey(bound)
	if InCombatLockdown() then
		return false
	end
	if bound and ns.IsFocusMouseKeyFree() then
		SetBinding(FOCUS_LEGACY_KEY, FOCUS_COMMAND)
		focusDefaultedSlot:Set(true)
		focusAnnouncedSlot:Set(true)
	elseif not bound and GetBindingAction(FOCUS_LEGACY_KEY) == FOCUS_COMMAND then
		SetBinding(FOCUS_LEGACY_KEY)
		focusDefaultedSlot:Set(nil)
	else
		return false
	end
	SaveBindings(GetCurrentBindingSet())
	return true
end

local function pvpLayout()
	local height = tonumber((GetCVar("gxResolution") or ""):match("%d+x(%d+)"))
	return height and height <= FULLHD_HEIGHT and "fullhd" or "default"
end

Presets.STYLES = {
	{
		key = "arena",
		name = "Arena",
		glyph = "trophy",
		desc = "Enemy frames near the center, DR on target and focus, the enemy trinket as a separate icon",
		layout = "arena",
		values = {
			["diminishingReturns.target"] = true,
			["diminishingReturns.focus"] = true,
			["diminishingReturns.arenaAnchor"] = "RIGHT",
			["diminishingReturns.arenaGrowth"] = "RIGHT",
			["groupCooldowns.enemySeparateTrinket"] = true,
			["namePlates.totemFilter"] = "important",
			["unitFrames.arenaDebuffMax"] = 6,
			["groupCooldowns.zones.battleground"] = false,
			["namePlates.nonTargetAlpha"] = 1,
			["namePlates.friendlyPlayer.healthColorMode"] = "class",
			["namePlates.enemyPlayer.arenaIcon"] = true,
			["tweaks.assetLoadTime"] = 25,
			["queuePopFlash.enabled"] = true,
		},
	},
	{
		key = "pvp",
		name = "Battlegrounds & arena",
		glyph = "flag",
		desc = "Voice on battlegrounds too (English), DR on target and focus, class colors on friendly nameplates",
		layout = pvpLayout,
		values = {
			["spellAlerts.zones.battleground"] = true,
			["diminishingReturns.target"] = true,
			["diminishingReturns.focus"] = true,
			["namePlates.friendlyPlayer.healthColorMode"] = "class",
			["namePlates.enemyPlayer.arenaIcon"] = true,
			["tweaks.assetLoadTime"] = 25,
			["queuePopFlash.enabled"] = true,
		},
	},
	{
		key = "classic",
		name = "Classic",
		glyph = "chess-rook",
		desc = "Portraits and bars where the default interface keeps them; full channel names, fewer PvP helpers",
		layout = "classic",
		values = {
			["spellAlerts.enabled"] = false,
			["groupCooldowns.zones.battleground"] = false,
			["diminishingReturns.player"] = false,
			["dispelHighlightMode"] = "all",
			["popups.autoRelease"] = false,
			["performance.enabled"] = false,
			["minimap.showTracking"] = true,
			["experienceBar.height"] = 9,
			["tooltip.hideInCombat"] = false,
			["tooltip.hidePvPLines"] = false,
			["namePlates.hideByName"] = false,
			["shieldIndicator.enabled"] = false,
			["unitFrames.outOfRangeAlpha"] = 0.45,
			["chat.shortChannelNames"] = false,
		},
	},
	{
		key = "none",
		name = "No preset",
		glyph = "sliders",
		desc = "Only FrostAtom UI's safe settings; the rest is up to you",
		values = {},
	},
}

Presets.EXPERIENCE = {
	{ key = "new", values = {} },
	{ key = "returning", values = {} },
	{ key = "expert", values = { ["tooltip.showIds"] = true, ["general.snapGap"] = 1 } },
}

Presets.ROLES = {
	{
		key = "healer",
		name = "Healer",
		glyph = "heart-pulse",
		desc = "Party frames above the bars, diminishing returns of crowd control on them, highlight of every debuff you can dispel",
		layout = "healer",
		values = {
			["diminishingReturns.party"] = true,
			["dispelHighlightMode"] = "all",
		},
	},
	{
		key = "damage",
		name = "Damage",
		glyph = "crosshairs",
		desc = "Your target, focus and enemy frames come first",
		values = {},
	},
}

local HEALER_TREES = {
	PRIEST = { [1] = true, [2] = true },
	DRUID = { [3] = true },
	SHAMAN = { [3] = true },
	PALADIN = { [1] = true },
}

Presets.LABELS = {
	["diminishingReturns.target"] = "DR on the target frame",
	["diminishingReturns.focus"] = "DR on the focus frame",
	["diminishingReturns.player"] = "DR on your character",
	["diminishingReturns.arenaAnchor"] = "DR point on arena frames",
	["diminishingReturns.arenaGrowth"] = "DR growth on arena frames",
	["diminishingReturns.party"] = "DR on party frames",
	["groupCooldowns.zones.battleground"] = "Group cooldowns on battlegrounds",
	["namePlates.nonTargetAlpha"] = "Opacity of nameplates that are not your target",
	["namePlates.friendlyPlayer.healthColorMode"] = "Friendly player nameplate color",
	["namePlates.enemyPlayer.arenaIcon"] = "Class icon on enemy nameplates",
	["namePlates.hideByName"] = "Hide nameplates of pets and summons",
	["tweaks.assetLoadTime"] = "Model loading time",
	["queuePopFlash.enabled"] = "Screen flash when the queue pops",
	["spellAlerts.enabled"] = "Voice for dangerous enemy spells",
	["spellAlerts.zones.arena"] = "Voice in arenas",
	["spellAlerts.zones.battleground"] = "Voice on battlegrounds",
	["dispelHighlightMode"] = "Dispel highlight on frames",
	["popups.autoRelease"] = "Release on battlegrounds automatically",
	["popups.autoAcceptInvites"] = "Accept group invites from friends and guild",
	["performance.enabled"] = "FPS and latency",
	["minimap.showTracking"] = "Tracking button on the minimap",
	["experienceBar.height"] = "Experience bar height",
	["tooltip.hideInCombat"] = "Hide tooltips in combat",
	["tooltip.hidePvPLines"] = "Hide PvP lines in tooltips",
	["tooltip.showIds"] = "Spell and item IDs in tooltips",
	["shieldIndicator.enabled"] = "Shield indicator",
	["unitFrames.outOfRangeAlpha"] = "Opacity of frames out of range",
	["chat.shortChannelNames"] = "Short channel names",
	["announce.interrupts"] = "Message about your interrupts",
	["announce.arenaResultToParty"] = "Arena rating results to the party",
	["tweaks.errorMessages"] = "Red messages at the top of the screen",
	["merchant.sellGreys"] = "Sell grey items",
	["merchant.autoRepair"] = "Repair equipment",
	["actionBar.dragModifier"] = "Key to take a spell off a bar",
	["actionBar.dragButton"] = "Mouse button to take a spell off a bar",
	["tweaks.hideGroundClutter"] = "Hide grass",
	["tweaks.disableTutorials"] = "Turn off Blizzard tips for new players",
	["general.uiScaleMode"] = "UI scale",
	["general.uiScale"] = "Custom scale",
	["announce.auraMastery"] = "Aura Mastery message",
	["tweaks.scriptErrors"] = "Lua error windows",
	["popups.fillDeleteConfirm"] = "Type DELETE for you",
	["combatAlert.enabled"] = "Combat alert",
	["minimap.showZoneText"] = "Zone name on the minimap",
	["groupCooldowns.zones.world"] = "Group cooldowns outside arenas and battlegrounds",
	["dispelHighlightAlpha"] = "Dispel highlight fill",
	["unitFrames.classIconStyle"] = "Class icon on unit frames",
	["groupCooldowns.enemySeparateTrinket"] = "Separate trinket icon of opponents",
	["namePlates.totemFilter"] = "Totems shown",
	["unitFrames.arenaDebuffMax"] = "Debuffs on an arena frame",
	["general.snapGap"] = "Gap when snapping",
}

local VALUE_TEXTS = {
	class = "Class",
	reaction = "Reaction",
	RIGHT = "Right",
	LEFT = "Left",
	all = "All",
	control = "Control and dangerous",
	filtered = "No spam",
	hidden = "Hide all",
	shift = "Shift",
	alt = "Alt",
	ctrl = "Ctrl",
	none = "No modifier",
	LeftButton = "Left button",
	RightButton = "Right button",
	MiddleButton = "Middle button",
	game = "As in game",
	pixel = "Sharp frames",
	custom = "Custom size",
	spec = "Spec icon",
	badge = "Class icon with spec badge",
	important = "Important",
}

function Presets.Label(path)
	local label = Presets.LABELS[path]
	return label and L[label] or ns.Movers.GetLabel(path)
end

function Presets.ValueText(path, value)
	if type(value) == "boolean" then
		return value and L["on"] or L["off"]
	elseif type(value) == "number" then
		if path:find("[Aa]lpha$") or path == "general.uiScale" then
			return ("%d%%"):format(math.floor(value * 100 + 0.5))
		end
		return (("%.2f"):format(value):gsub("%.?0+$", ""))
	elseif type(value) == "string" then
		return VALUE_TEXTS[value] and L[VALUE_TEXTS[value]] or value
	end
	return tostring(value)
end

local function find(list, key)
	for _, item in ipairs(list) do
		if item.key == key then
			return item
		end
	end
end

function Presets.GetStyle(key)
	return find(Presets.STYLES, key)
end

function Presets.GetExperience(key)
	return find(Presets.EXPERIENCE, key)
end

function Presets.GetRole(key)
	return find(Presets.ROLES, key)
end

function Presets.DetectRole()
	local group = GetActiveTalentGroup(false, false)
	local best, bestPoints, bestName = nil, 0, nil
	for tab = 1, GetNumTalentTabs(false, false) do
		local name, _, points = GetTalentTabInfo(tab, false, false, group)
		if (points or 0) > bestPoints then
			best, bestPoints, bestName = tab, points, name
		end
	end
	if not best then
		return nil
	end
	local _, class = UnitClass("player")
	local trees = HEALER_TREES[class]
	return trees and trees[best] and "healer" or "damage", bestName
end

function Presets.LayoutFor(styleKey)
	local style = Presets.GetStyle(styleKey)
	local layout = style and style.layout
	if type(layout) == "function" then
		return layout()
	end
	return layout
end

function Presets.RecommendedLayout(styleKey, roleKey)
	local role = Presets.GetRole(roleKey)
	return role and role.layout or Presets.LayoutFor(styleKey)
end

local function same(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-6
	end
	return a == b
end

local function addValues(target, values)
	for path, value in pairs(values or {}) do
		target[path] = value
	end
end

function Presets.Plan(styleKey, experienceKey, extra, roleKey)
	local values = {}
	local style = Presets.GetStyle(styleKey)
	local experience = Presets.GetExperience(experienceKey)
	local role = Presets.GetRole(roleKey)
	addValues(values, style and style.values)
	addValues(values, experience and experience.values)
	addValues(values, role and role.values)
	addValues(values, extra)
	local plan = { style = styleKey, experience = experienceKey, role = roleKey }
	for path, value in pairs(values) do
		local current = ns:GetConfig(path)
		if not same(current, value) then
			local mine = not ns:IsDefaultConfig(path)
			plan[#plan + 1] = { path = path, value = value, current = current, mine = mine, checked = not mine }
		end
	end
	table.sort(plan, function(a, b)
		return a.path < b.path
	end)
	local layout = Presets.RecommendedLayout(styleKey, roleKey)
	if layout and ns.Movers.GetActivePreset() ~= layout then
		plan.layout = layout
		plan.layoutChecked = true
	end
	return plan
end

local SCALE_PATHS = { ["general.uiScale"] = true, ["general.uiScaleMode"] = true }

function Presets.CountChecked(plan)
	local count = 0
	for _, item in ipairs(plan) do
		if item.checked then
			count = count + 1
		end
	end
	return count
end

function Presets.Apply(plan, label)
	local applied = {}
	local function apply(scale)
		for _, item in ipairs(plan) do
			if SCALE_PATHS[item.path] == scale and item.checked and not same(ns:GetConfig(item.path), item.value) then
				ns:SetBaselineConfig(item.path, item.value)
				applied[#applied + 1] = item
			end
		end
	end
	ns.Undo.Begin(label or L["Apply a style"])
	apply(true)
	if plan.layout and plan.layoutChecked and ns.Movers.ApplyPreset(plan.layout) then
		applied.layout = plan.layout
	end
	apply(nil)
	ns.Undo.End()
	if plan.style then
		local styles = stylesSlot:Table()
		styles[ns:GetActiveProfile()] = plan.style
	end
	return applied
end

function Presets.GetActiveStyle()
	local styles = stylesSlot:Get()
	return styles and styles[ns:GetActiveProfile()]
end

ns.WHATS_NEW_VERSION = "1.5.0"

function ns:GetLegacyRecommendations()
	local list = {}
	local style = Presets.GetStyle(Presets.GetActiveStyle()) or { values = {} }
	local setup = setupSlot:Get()
	local experience = Presets.GetExperience(setup and setup.experience) or { values = {} }
	local role = Presets.GetRole(setup and setup.role) or { values = {} }
	local same = ns.SameLegacyValue
	for _, values in ipairs(ns.LegacyDefaults) do
		for path, legacy in pairs(values) do
			local base = ns:GetBaselineConfig(path)
			local factory = ns:GetFactoryConfig(path)
			if
				base ~= nil
				and style.values[path] == nil
				and experience.values[path] == nil
				and role.values[path] == nil
				and ns:IsDefaultConfig(path)
				and same(base, legacy)
				and not same(factory, legacy)
			then
				list[#list + 1] = { path = path, current = base, value = factory, point = type(legacy) == "table" }
			end
		end
	end
	table.sort(list, function(a, b)
		return a.path < b.path
	end)
	return list
end

function ns.ApplyRecommendations(list)
	ns.Undo.Snapshot("whatsNew")
	ns.Undo.Run(L["Apply the recommended values"], function()
		for _, item in ipairs(list) do
			ns:ResetConfig(item.path, "factory")
		end
	end)
end

local EXPLAIN_LINK = "fasettings"

local EXPLAIN = {
	voice = { "That was a FrostAtom UI voice alert (English voice).", true, "alerts:voice" },
	queueFlash = {
		'The screen flashes: you are invited to a battleground or arena, press "Enter".',
		nil,
		"alerts:queue",
	},
	combatAlert = { "The text in the middle of the screen: you entered combat.", nil, "hud" },
	healer = { "A cross above an enemy marks a healer.", nil, "nameplates" },
}

function ns.ExplainOnce(key)
	local explain = EXPLAIN[key]
	local setup = setupSlot:Get()
	if not setup or (setup.experience ~= "new" and setup.experience ~= "returning") then
		return
	end
	local store
	if explain[2] then
		store = explainedSlot:Table()
	else
		local chars = explainedCharsSlot:Table()
		local char = UnitName("player") .. " - " .. GetRealmName()
		store = chars[char] or {}
		chars[char] = store
	end
	if not store[key] then
		store[key] = true
		ns.Print("%s |cff3399ff|H%s:%s|h[%s]|h|r", L[explain[1]], EXPLAIN_LINK, explain[3], L["Settings"])
	end
end

ns.RegisterLink(EXPLAIN_LINK, function(target)
	local page, tab = strsplit(":", target)
	local host = ns.API.LoadSettings()
	if host then
		host.Toggle(page, tab)
	end
end)

function ns.SetupState()
	local setup = setupSlot:Get()
	return setup and setup.state
end

function ns.SetSetupState(state)
	setupSlot:Table().state = state
end

local function blocked()
	local _, kind = IsInInstance()
	return InCombatLockdown()
		or kind ~= "none"
		or InCinematic()
		or UnitIsDeadOrGhost("player")
		or (TutorialFrame and TutorialFrame:IsShown())
		or (GossipFrame and GossipFrame:IsShown())
		or (QuestFrame and QuestFrame:IsShown())
end

local function runSetup()
	local host = ns.API.LoadSettings()
	if host then
		host.RunSetup()
	end
end

function ns.RunSetup()
	if InCombatLockdown() then
		ns.Print(L["the setup opens after combat"])
		return
	end
	runSetup()
end

local quiet = 0

local function poll()
	if ns.SetupState() ~= "pending" then
		ns.Scheduler.RemoveTicker(TICKER)
		return
	end
	if blocked() then
		quiet = 0
		return
	end
	quiet = quiet + POLL_INTERVAL
	if quiet >= START_DELAY then
		ns.Scheduler.RemoveTicker(TICKER)
		runSetup()
	end
end

local function findSnapshot(undo)
	local snapshots = Storage.Slot("snapshots"):Get()
	local list = snapshots and snapshots[undo.profile]
	for _, item in ipairs(type(list) == "table" and list or {}) do
		if item.time == undo.time then
			return item
		end
	end
end

function ns.CanUndoSetup()
	local setup = setupSlot:Get()
	local undo = setup and setup.undo
	return undo ~= nil and undo.profile == ns:GetActiveProfile() and findSnapshot(undo) ~= nil
end

function ns.UndoSetup()
	local setup = setupSlot:Get()
	local undo = setup and setup.undo
	if not ns.CanUndoSetup() or InCombatLockdown() then
		return false
	end
	ns.Undo.RestoreSnapshot(findSnapshot(undo))
	for _, addon in ipairs(undo.addons or {}) do
		EnableAddOn(addon)
	end
	local conflicts = Storage.Slot("conflicts"):Get()
	for _, addon in ipairs(undo.conflicts or {}) do
		if conflicts then
			conflicts[addon] = nil
		end
	end
	if undo.focusKey then
		ns.SetFocusMouseKey(false)
	end
	setup.undo = nil
	setup.state = "undone"
	ReloadUI()
	return true
end

StaticPopupDialogs.FROSTATOMUI_UNDO_SETUP = {
	text = "",
	button2 = CANCEL,
	OnAccept = function()
		ns.UndoSetup()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

function ns.ConfirmUndoSetup()
	local dialog = StaticPopupDialogs.FROSTATOMUI_UNDO_SETUP
	dialog.text = L["Undo the setup? The settings from before it come back and the UI reloads."]
	dialog.button1 = L["Undo setup"]
	StaticPopup_Show("FROSTATOMUI_UNDO_SETUP")
end

local TOAST_TIME = 60
local toast

local function hideToast()
	if toast then
		toast:Hide()
	end
end

local function createToast()
	toast = ns.CreateWindow("FrostAtomUISetupToast", { width = 500, height = 92, strata = "DIALOG", special = false })
	toast:SetPoint("TOP", 0, -110)
	local shade = toast:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(0, 0, 0, 0.85)
	shade:SetPoint("TOPLEFT", 4, -4)
	shade:SetPoint("BOTTOMRIGHT", -4, 4)
	toast.title:SetText(L["FrostAtom UI is set up"])
	local open = ns.CreateButton(toast, L["Open settings"], 130)
	open:SetScript("OnClick", function()
		hideToast()
		SlashCmdList.FROSTATOMUI_CONFIG("")
	end)
	toast.open = open
	local undo = ns.CreateButton(toast, L["Undo setup"], 130, nil, nil, true)
	undo:SetScript("OnClick", function()
		hideToast()
		ns.ConfirmUndoSetup()
	end)
	toast.undo = undo
	local learn = ns.CreateButton(toast, " ", 130, nil, nil, true)
	learn:SetScript("OnClick", function()
		hideToast()
		local host = ns.API.LoadSettings()
		local setup = setupSlot:Get()
		if host and setup and setup.experience == "expert" then
			host.StartTour()
		elseif host then
			host.ShowTips()
		end
	end)
	toast.learn = learn
	toast.buttons = { open, undo, learn }
end

function ns.ShowSetupToast()
	local setup = setupSlot:Get()
	if setup then
		setup.toast = nil
	end
	if not toast then
		createToast()
	end
	toast:Show()
	ns.SetShown(toast.undo, ns.CanUndoSetup())
	local expert = setup and setup.experience == "expert"
	toast.learn:SetText(expert and L["How to move frames"] or L["Three tips"])
	for _, button in ipairs(toast.buttons) do
		ns.FitButton(button, 24, 130)
	end
	ns.UIKit.CenterRow(toast, toast.buttons, 6, 16)
	ns.After(TOAST_TIME, hideToast)
end

local watcher = ns.Mixin({}, ns.EventMixin)

local function onEnteringWorld(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	if ns.SetupState() == "pending" then
		quiet = 0
		ns.Scheduler.AddTicker(TICKER, poll, POLL_INTERVAL)
	elseif setupSlot:Get() and setupSlot:Get().toast then
		ns.After(2, ns.ShowSetupToast)
	end
end

watcher:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
watcher:RegisterEvent(ns.E.DB_LOADED, function()
	if ns.SetupState() == "pending" then
		whatsNewSlot:Set(ns.WHATS_NEW_VERSION)
	end
end)
