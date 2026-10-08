local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local Section = ns.Section

local NEW = "1.5.0"
local PAGE = "blizzard"
local ACTION_BARS = "hideBlizzard.actionBars"

ns.RegisterElement({
	path = "actionBar.microMenu",
	page = PAGE,
	tab = "elements",
	name = L["Micro menu"],
	glyph = "bars",
	enabledBy = ACTION_BARS,
	schema = {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "actionBar.microMenuScale",
			label = L["Scale"],
			type = "number",
			min = 0.5,
			max = 2,
			step = 0.05,
			percent = true,
		},
		ns.MenuVisibility("actionBar.microMenu", L["Keep the micro menu faded until the cursor is over it."]),
	},
})

ns.RegisterElement({
	path = "actionBar.bagButton",
	page = PAGE,
	tab = "elements",
	name = L["Bag button"],
	glyph = "bag-shopping",
	enabledBy = ACTION_BARS,
	schema = {
		ns.MenuVisibility("actionBar.bagButton", L["Keep the bag button faded until the cursor is over it."]),
	},
})

local SWAP_POPUP = "FROSTATOMUI_BLIZZARD_SWAP"
local swap

local function applySwap(hideBlizzard)
	local entry, value = swap.entry, swap.value
	swap = nil
	ui:SetConfig(entry.path, value)
	if hideBlizzard ~= nil then
		for _, path in ipairs(entry.blizzard.paths) do
			ui:SetConfig(path, hideBlizzard)
		end
	end
	if ui.InArenaPreparation() then
		ui.Print(L["some changes take effect after a UI reload; reload after the match"])
	else
		ReloadUI()
	end
end

StaticPopupDialogs[SWAP_POPUP] = {
	text = "%s",
	button1 = "",
	button2 = CANCEL,
	button3 = "",
	OnAccept = function()
		applySwap(swap.value)
	end,
	OnAlt = function()
		applySwap(nil)
	end,
	OnHide = function()
		swap = nil
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local function confirmBlizzardSwap(entry, value)
	local blizzard = entry.blizzard
	local mismatch = false
	for _, path in ipairs(blizzard.paths) do
		if ui:GetConfig(path) ~= value then
			mismatch = true
		end
	end
	if not mismatch then
		return false
	end
	local dialog = StaticPopupDialogs[SWAP_POPUP]
	dialog.button1 = value and L["Hide them"] or L["Bring them back"]
	dialog.button3 = value and L["Keep both"] or L["Leave hidden"]
	local text = value and blizzard.onText or blizzard.offText
	StaticPopup_Hide(SWAP_POPUP)
	swap = { entry = entry, value = value }
	local note = ui.InArenaPreparation() and L["Applies after the match."]
		or L["The UI reloads (5-10 s, your character stays in place)."]
	StaticPopup_Show(SWAP_POPUP, text .. "\n\n" .. note)
	return true
end
ns.SetBlizzardSwap(confirmBlizzardSwap)

local toggles = {}

local function hideToggle(key, label, desc, hidden)
	local entry = {
		path = "hideBlizzard." .. key,
		label = label,
		type = "toggle",
		hidden = hidden,
		desc = desc,
	}
	if not hidden then
		toggles[#toggles + 1] = entry
	end
	return entry
end

local schema = {
	{
		description = L["Each Blizzard frame is hidden on its own, with or without its FrostAtom UI replacement."],
	},
	{
		header = L["Hidden frames"],
		glyph = "eye-slash",
		toggles = toggles,
		toggleDesc = L["Hide or show every frame on this list."],
	},
	hideToggle(
		"actionBars",
		L["Hide action bars"],
		L["Main and side bars with the stance, pet, possess and vehicle bars, bag slots and the experience and reputation bars. The micro menu and the bag button stay as separate movable frames."]
	),
	hideToggle(
		"unitFrames",
		L["Hide unit frames"],
		L["Player, target, focus, party and arena frames and the combo points next to the target."]
	),
	hideToggle("castBar", L["Hide player castbar"], L["The castbar at the bottom of the screen."]),
	hideToggle("buffs", L["Hide buffs and debuffs"], L["Your buffs and debuffs in the top right corner."]),
	hideToggle("weaponEnchants", L["Hide weapon enchants"], L["Poison, oil and weapon imbue icons next to the buffs."]),
	hideToggle("runes", L["Hide runes"], L["The rune bar under the player frame."], ns.NotClass("DEATHKNIGHT")),
}

local windows = {
	{ header = L["Replacement windows"], glyph = "window-maximize" },
}
for _, entry in ipairs({
	{
		path = "macros.enabled",
		new = "1.5.0",
		label = L["Macro editor"],
		type = "toggle",
		desc = L["Replaces the /macro window: unlimited macros of any length, syntax and error highlighting, key bindings right in the window. /macro opens it."],
	},
	{
		path = "spellBook.enabled",
		new = "1.5.0",
		label = L["Spellbook"],
		type = "toggle",
		desc = L["Replaces the spellbook: every tab and the pet book in one wide window, four columns, search and a switch to hide passive abilities."],
	},
	{
		path = "talentFrame.enabled",
		new = "1.5.0",
		label = L["Talents"],
		type = "toggle",
		desc = L["Replaces the talent window: all three trees side by side with glyphs next to them, dual spec, pet talents and preview."],
	},
	{
		path = "inspectFrame.enabled",
		new = "1.5.0",
		label = L["Inspect"],
		type = "toggle",
		desc = L["Replaces the inspect window: gear with enchants, gems and missing ones, stats from gear, set bonuses, both talent specs, arena teams, honor, arena statistics and PvP achievements."],
	},
	{
		path = "wheelPaging.enabled",
		label = L["Mouse wheel paging"],
		type = "toggle",
		desc = L["Scroll pages in the merchant, spellbook, mailbox, auction house and calendar with the mouse wheel."],
	},
}) do
	windows[#windows + 1] = entry
end

windows[#windows + 1] = { header = L["Merchant window"], glyph = "coins" }
for _, entry in ipairs({
	{
		path = "merchant.showItemLevel",
		new = "1.5.0",
		label = L["Show item level"],
		type = "toggle",
		desc = L["Item level on merchant and buyback item icons."],
	},
	{
		path = "merchant.searchBox",
		new = "1.5.0",
		label = L["Search box"],
		type = "toggle",
		desc = L["Filter merchant items by name, type, quality, item level and tooltip text, same syntax as the bag search."],
	},
	{
		path = "merchant.filterMenu",
		new = "1.5.0",
		label = L["Filters and sorting"],
		type = "toggle",
		desc = L["Button next to the search box: hide unusable, sold out, unaffordable or already known items, show one quality, type or slot, sort by name, price, item level or quality."],
	},
	{
		path = "merchant.wideFrame",
		new = "1.5.0",
		label = L["Four columns"],
		type = "toggle",
		desc = L["Wider merchant window with four columns of items, 20 items per page."],
	},
}) do
	windows[#windows + 1] = entry
end

Section(windows, L["Equipment"], "equipment", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Item level display and durability warnings."],
	},
	{
		path = "showItemLevels",
		label = L["Item levels on character / inspect"],
		type = "toggle",
		desc = L["Per-slot item level and the average on the paper doll."],
	},
	{
		path = "slotFont",
		advanced = true,
		label = L["Slot item level font"],
		type = "font",
		enabledBy = "equipment.showItemLevels",
		desc = L["Item level on each equipment slot."],
	},
	{
		path = "averageFont",
		advanced = true,
		label = L["Average item level font"],
		type = "font",
		enabledBy = "equipment.showItemLevels",
		desc = L["Average item level of the equipped gear on the character and inspect windows."],
	},
	{
		path = "durabilityThreshold",
		label = L["Durability warning"],
		type = "number",
		min = 0,
		max = 0.9,
		step = 0.05,
		percent = true,
		zeroText = L["Off"],
		desc = L["Print a chat warning when any equipped item drops below this durability."],
	},
}, nil, nil, "shirt")

Section(windows, L["Character model"], "modelControls", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Drag to rotate, right-drag to pan, mouse wheel to zoom and middle-click to reset the character, inspect and dressing room models. Removes the rotate buttons."],
	},
}, nil, nil, "street-view")

local elements = {}
for _, element in ipairs({
	{ "blizzardFrames.captureBarPoint", L["Capture bars"], "flag" },
	{ "blizzardFrames.vehicleSeatPoint", L["Vehicle seats"], "car-side" },
	{ "blizzardFrames.raidWarningPoint", L["Raid warnings"], "bullhorn" },
}) do
	ns.RegisterElement({
		path = element[1],
		page = "blizzard",
		tab = "elements",
		name = element[2],
		glyph = element[3],
		enabledBy = "blizzardFrames.enabled",
	})
end

Section(elements, L["Blizzard elements"], "blizzardFrames", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Movable capture bars, vehicle seats, error messages and raid warnings; quest tracker hiding."],
	},
	{
		path = "questTracker",
		label = L["Hide quest tracker"],
		type = "multiselect",
		values = {
			{ "arena", L["Arena"] },
			{ "battleground", L["Battleground"] },
			{ "combat", L["In combat"] },
		},
		desc = L["The quest tracker comes back when you leave the arena or battleground and when combat ends."],
	},
}, nil, "1.4.0", "window-maximize")

Section(elements, L["Class colored names"], "classNames", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Player names in Blizzard windows in class colors. Offline players stay grey."],
	},
	{ path = "friends", label = L["Friends list"], type = "toggle" },
	{
		path = "guild",
		label = L["Guild roster"],
		type = "toggle",
		desc = L["Both roster views and the member details."],
	},
	{ path = "who", label = L["Who list"], type = "toggle", desc = L["Names and the class column."] },
	{
		path = "scoreboard",
		label = L["Battleground scoreboard"],
		type = "toggle",
		desc = L["Names in class colors instead of faction colors."],
	},
	{
		path = "other",
		label = L["Other lists"],
		type = "toggle",
		desc = L["Chat channel members, arena team roster and the raid browser."],
	},
	{
		path = "levels",
		label = L["Level colors"],
		type = "toggle",
		desc = L["Levels colored by difficulty compared to your level, in the lists above."],
	},
}, nil, NEW, "palette")

elements[#elements + 1] = { header = L["Frames"], glyph = "arrows-up-down-left-right" }
elements[#elements + 1] = { type = "elements" }

ns.RegisterElement({
	path = "tweaks.worldStatePoint",
	page = PAGE,
	tab = "elements",
	name = L["World state"],
	glyph = "globe",
	enabledBy = "tweaks.enabled",
	schema = {},
})

local RESTORE_WIDTH, RESTORE_PADDING, RESTORE_LINE = 600, 20, 24
local function restoreRows()
	return {
		{
			label = L["Action bars: the Blizzard bars come back; mouseover, show conditions and extra bars are gone."],
			off = { "actionBar.enabled", "hideBlizzard.actionBars" },
			core = true,
		},
		{
			label = L["Unit frames: Blizzard portraits, castbar and buffs come back; DR, trinkets and cooldowns on frames are gone."],
			off = {
				"unitFrames.enabled",
				"hideBlizzard.unitFrames",
				"hideBlizzard.castBar",
				"hideBlizzard.buffs",
				"hideBlizzard.weaponEnchants",
			},
			core = true,
		},
		{
			label = L["Runes: the Blizzard rune bar comes back."],
			off = { "runes.enabled", "hideBlizzard.runes" },
			core = true,
			hidden = ui.PLAYER_CLASS ~= "DEATHKNIGHT",
		},
		{
			label = L["Nameplates: the standard nameplates; healer marks, totems and auras on them are gone."],
			off = { "namePlates.enabled" },
		},
		{
			label = L["Chat: the standard chat windows; history and short channel names are gone."],
			off = { "chat.enabled" },
		},
		{
			label = L["Bags: separate Blizzard bags; search, sorting and the offline bank are gone."],
			off = { "bags.enabled" },
		},
		{ label = L["Minimap: the standard minimap and its buttons."], off = { "minimap.enabled" } },
		{
			label = L["Tooltips: the standard tooltips without item levels and spell IDs."],
			off = { "tooltip.enabled" },
		},
		{
			label = L["Windows: the standard spellbook, talents, inspect and macro windows."],
			off = { "spellBook.enabled", "talentFrame.enabled", "inspectFrame.enabled", "macros.enabled" },
		},
	}
end

local restoreDialog

local function setRestoreChecks(onlyCore)
	for _, check in ipairs(restoreDialog.checks) do
		check:SetChecked(not onlyCore or check.row.core)
	end
end

local function applyRestore()
	local paths = {}
	for _, check in ipairs(restoreDialog.checks) do
		if check:IsShown() and check:GetChecked() then
			for _, path in ipairs(check.row.off) do
				paths[#paths + 1] = path
			end
		end
	end
	if #paths == 0 then
		restoreDialog:Hide()
		return
	end
	ui.Undo.Snapshot("blizzardUI")
	ui.Undo.Run(L["Bring back the Blizzard interface"], function()
		for _, path in ipairs(paths) do
			ui:SetConfig(path, false)
		end
	end)
	ReloadUI()
end

local function createRestoreDialog()
	restoreDialog = ns.CreateWindow(nil, {
		width = RESTORE_WIDTH,
		height = 200,
		header = true,
		strata = "FULLSCREEN_DIALOG",
		noClose = true,
		movable = false,
	})
	restoreDialog:SetPoint("CENTER")
	restoreDialog.heading:SetText(L["Bring back the Blizzard interface"])
	local shade = restoreDialog:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(0, 0, 0, 0.92)
	shade:SetPoint("TOPLEFT", 4, -4)
	shade:SetPoint("BOTTOMRIGHT", -4, 4)
	local text = restoreDialog:CreateFontString(nil, "ARTWORK")
	text:SetFontObject(ns.Font("GameFontHighlight"))
	text:SetPoint("TOPLEFT", RESTORE_PADDING, -42)
	text:SetWidth(RESTORE_WIDTH - RESTORE_PADDING * 2)
	text:SetJustifyH("LEFT")
	text:SetText(
		L["Checked parts are turned off and their Blizzard frames come back after a UI reload. Arena and battleground helpers (DR, cooldowns, voice) stay unless you turn them off. A backup is saved first."]
	)
	local all = ns.CreateButton(restoreDialog, L["All"], 90)
	all:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)
	all:SetScript("OnClick", function()
		setRestoreChecks(false)
	end)
	local core = ns.CreateButton(restoreDialog, L["Only bars and portraits"], 180)
	core:SetPoint("LEFT", all, "RIGHT", 4, 0)
	core:SetScript("OnClick", function()
		setRestoreChecks(true)
	end)
	restoreDialog.text = text
	restoreDialog.checks = {}
	for _, row in ipairs(restoreRows()) do
		if not row.hidden then
			local check = ui.CreateCheckButton(restoreDialog, row.label, nil, true)
			check.row = row
			restoreDialog.checks[#restoreDialog.checks + 1] = check
		end
	end
	local cancel = ns.CreateButton(restoreDialog, CANCEL, 96)
	cancel:SetPoint("BOTTOMRIGHT", -RESTORE_PADDING, 16)
	cancel:SetScript("OnClick", function()
		restoreDialog:Hide()
	end)
	local accept = ns.CreateButton(restoreDialog, L["Turn off and reload"], 160)
	accept:SetPoint("RIGHT", cancel, "LEFT", -4, 0)
	accept:SetScript("OnClick", applyRestore)
end

local function placeRestoreChecks()
	local top = 42 + restoreDialog.text:GetStringHeight() + 10 + 30
	for index, check in ipairs(restoreDialog.checks) do
		check:SetPoint("TOPLEFT", RESTORE_PADDING - 4, -top - (index - 1) * RESTORE_LINE)
	end
	restoreDialog:SetHeight(top + #restoreDialog.checks * RESTORE_LINE + 60)
end

local function showRestoreDialog()
	if InCombatLockdown() then
		ui.Print(ERR_NOT_IN_COMBAT)
		return
	end
	if not restoreDialog then
		createRestoreDialog()
	end
	setRestoreChecks(true)
	restoreDialog:Show()
	placeRestoreChecks()
end

schema[#schema + 1] = { header = L["Back to Blizzard"], glyph = "rotate-left" }
schema[#schema + 1] = {
	label = L["Bring back the Blizzard interface"],
	type = "execute",
	text = L["Choose..."],
	glyph = "rotate-left",
	func = showRestoreDialog,
	desc = L["Turn off chosen FrostAtom UI parts at once and get the Blizzard frames back: bars, portraits, nameplates, chat, bags, minimap, tooltips, windows."],
}

ns.RegisterPage({
	key = PAGE,
	name = L["Blizzard UI"],
	desc = L["Hide Blizzard frames, replace their windows and move their elements."],
	glyph = "eye-slash",
	new = NEW,
	order = 62,
	group = "system",
	schema = {},
	tabs = {
		{ key = "hidden", order = 1, name = L["Hidden frames"], glyph = "eye-slash", schema = schema },
		{ key = "windows", order = 2, name = L["Replacement windows"], glyph = "window-maximize", schema = windows },
		{ key = "elements", order = 3, name = L["Blizzard elements"], glyph = "window-restore", schema = elements },
	},
})
