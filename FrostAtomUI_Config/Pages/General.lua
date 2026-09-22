local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

local ui = FrostAtomUI

local schema = {
	{ header = L["Language"] },
	{
		label = L["Interface language"],
		type = "select",
		width = 180,
		values = ui.GetLocaleOptions,
		get = ui.GetLocaleOverride,
		set = function(value)
			ui.SetLocaleOverride(value)
			ns.Confirm(L["The language changes after a UI reload. Reload now?"], ReloadUI)
		end,
		desc = L["Language of FrostAtom UI text. Auto follows the game client."],
	},
	{ header = L["Appearance"] },
	{ path = "general.font", label = L["Font"], type = "select", values = ui.Media.fonts },
	{ path = "general.fontBold", label = L["Bold font"], type = "select", values = ui.Media.fonts },
	{ path = "general.statusbar", label = L["Status bar texture"], type = "select", values = ui.Media.statusbars },
	{
		path = "general.useUiScale",
		label = L["Override UI scale"],
		type = "toggle",
		desc = L["Apply the scale below instead of the game's own setting. Turning it off keeps the last applied value."],
	},
	{
		path = "general.uiScale",
		label = L["UI scale"],
		type = "number",
		min = 0.64,
		max = 1,
		step = 0.01,
		enabledBy = "general.useUiScale",
	},
	{ header = L["Frame movers"] },
	{
		path = "general.showGrid",
		label = L["Alignment grid"],
		type = "toggle",
		desc = L["Grid over the screen while frames are unlocked. Screen center lines are always drawn."],
	},
	{
		path = "general.gridSize",
		label = L["Grid step"],
		type = "number",
		min = 8,
		max = 128,
		step = 4,
		enabledBy = "general.showGrid",
	},
	{
		label = L["Move frames"],
		type = "execute",
		text = L["Unlock"],
		desc = L["Drag frames to move them, drag the bottom-right corner of a frame to resize it. Frames snap to each other, to screen edges and to screen center lines, and stay attached to the frame they snapped to. Hold Shift to drop snapping and detach."],
		func = function()
			ui.Movers.Unlock()
			if ui.Movers.IsUnlocked() then
				ns.Toggle()
			end
		end,
	},
	{ header = L["Unit frames"] },
	{
		path = "dispelHighlightAlpha",
		label = L["Dispel highlight alpha"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		desc = L["Border alpha on unit frames with a debuff you can dispel."],
	},
}

Section(schema, L["Arena history"], "arenaHistory", {
	{
		path = "enabled",
		label = L["Record games"],
		type = "toggle",
		desc = L["Save arena scoreboards. Open with /history."],
	},
	{ path = "point", label = L["Window position"], type = "point" },
	{
		path = "maxGames",
		label = L["Games to keep"],
		type = "number",
		min = 50,
		max = 5000,
		step = 50,
		desc = L["Oldest games are dropped past this count."],
	},
	{ path = "listFont", label = L["List font"], type = "font", desc = L["Rows of the game list and match details."] },
	{ path = "winColor", label = L["Win color"], type = "color" },
	{ path = "lossColor", label = L["Loss color"], type = "color" },
	{
		label = L["History window"],
		type = "execute",
		text = L["Open"],
		func = function()
			SlashCmdList.FROSTATOMUI_ARENA_HISTORY()
		end,
	},
})

Section(schema, L["Equipment"], "equipment", {
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
	{ path = "slotFont", label = L["Slot item level font"], type = "font", enabledBy = "equipment.showItemLevels" },
	{
		path = "averageFont",
		label = L["Average item level font"],
		type = "font",
		enabledBy = "equipment.showItemLevels",
	},
	{
		path = "qualityThresholds.uncommon",
		label = L["Average: green from"],
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
		desc = L["Average item level colored by quality tier. Grey below this value."],
	},
	{
		path = "qualityThresholds.rare",
		label = L["Average: blue from"],
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
	},
	{
		path = "qualityThresholds.epic",
		label = L["Average: purple from"],
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
	},
	{
		path = "qualityThresholds.legendary",
		label = L["Average: orange from"],
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
	},
	{
		path = "durabilityWarning",
		label = L["Durability warning"],
		type = "toggle",
		desc = L["Print a chat warning when gear durability gets low."],
	},
	{
		path = "durabilityThreshold",
		label = L["Warn below"],
		type = "number",
		min = 0.05,
		max = 0.9,
		step = 0.05,
		enabledBy = "equipment.durabilityWarning",
		desc = L["Warn when any equipped item drops below this durability."],
	},
})

Section(schema, L["Merchant"], "merchant", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Automatic actions when a merchant window opens."],
	},
	{
		path = "sellGreys",
		label = L["Sell grey items"],
		type = "toggle",
		desc = L["Sell every poor quality item in your bags."],
	},
	{
		path = "autoRepair",
		label = L["Auto repair"],
		type = "toggle",
		desc = L["Repair all gear when you can afford it."],
	},
	{
		path = "shiftToSkip",
		label = L["Hold Shift to skip"],
		type = "toggle",
		desc = L["Do nothing when the merchant window is opened with Shift held."],
	},
})

schema[#schema + 1] = { header = L["Interface"] }
schema[#schema + 1] = {
	path = "wheelPaging.enabled",
	label = L["Mouse wheel paging"],
	type = "toggle",
	desc = L["Scroll pages in the merchant, spellbook, mailbox, auction house and calendar with the mouse wheel."],
}

Section(schema, L["Tweaks"], "tweaks", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Pinned CVars (no tutorials, ground clutter, camera distance, script errors), world state frame position and the Spectate entry in friend menus."],
	},
	{
		path = "hideErrors",
		label = L["Hide red error messages"],
		type = "toggle",
		desc = L['"Not enough mana", "Out of range" and similar messages at the top of the screen.'],
	},
	{
		path = "scriptErrors",
		label = L["Show Lua errors"],
		type = "toggle",
		desc = L["Pop up addon script errors instead of silently ignoring them."],
	},
	{
		path = "hideGroundClutter",
		label = L["Hide ground clutter"],
		type = "toggle",
		desc = L["Grass and other ground decorations. Turning it off restores the game default."],
	},
	{
		path = "cameraDistanceMax",
		label = L["Max camera distance"],
		type = "number",
		min = 10,
		max = 50,
		step = 1,
		desc = L["How far the camera can zoom out."],
	},
	{
		path = "cameraDistanceClose",
		label = L["Close camera distance"],
		type = "number",
		min = 0,
		max = 50,
		step = 1,
		desc = L["Distance the Close camera distance key binding snaps to."],
	},
	{
		path = "cameraDistanceMedium",
		label = L["Medium camera distance"],
		type = "number",
		min = 0,
		max = 50,
		step = 1,
		desc = L["Distance the Medium camera distance key binding snaps to."],
	},
	{
		path = "cameraDistanceFar",
		label = L["Far camera distance"],
		type = "number",
		min = 0,
		max = 50,
		step = 1,
		desc = L["Distance the Far camera distance key binding snaps to."],
	},
	{
		path = "worldStatePoint",
		label = L["World state position"],
		type = "point",
		desc = L["Battleground score / flag status frame."],
	},
})

Section(schema, L["Character model"], "modelControls", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Drag to rotate, right-drag to pan and mouse wheel to zoom the character, inspect and dressing room models. Removes the rotate buttons."],
	},
	{
		path = "rotateSpeed",
		label = L["Rotate speed"],
		type = "number",
		min = 0.002,
		max = 0.05,
		step = 0.002,
		desc = L["Radians per pixel of mouse movement."],
	},
	{
		path = "zoomStep",
		label = L["Zoom step"],
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		desc = L["Distance change per mouse wheel notch."],
	},
})

Section(schema, L["Combat log"], "combatLogFix", {
	{
		path = "enabled",
		label = L["Fix stalled combat log"],
		type = "toggle",
		desc = L["Clear the combat log when it stops delivering events inside instances. WoW Circle only."],
	},
}, not GetCVar("realmlist"):lower():find("circle"))

Section(schema, L["Popups"], "popups", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Automatic handling of popup dialogs."] },
	{
		path = "autoAcceptInvites",
		label = L["Auto accept invites from friends / guild"],
		type = "toggle",
		desc = L["Only while not already in a group."],
	},
	{
		path = "autoRelease",
		label = L["Auto release in battlegrounds"],
		type = "toggle",
		desc = L["Release spirit immediately on death in a battleground."],
	},
	{
		path = "declineTradeInCombat",
		label = L["Decline trades in combat"],
		type = "toggle",
		desc = L["Close incoming trade windows while in combat."],
	},
	{
		path = "declineDuels",
		label = L["Decline duels"],
		type = "toggle",
		desc = L["Toggle with /noduel."],
	},
	{
		path = "declineInvites",
		label = L["Decline party invites"],
		type = "toggle",
		desc = L["Toggle with /noparty."],
	},
	{
		path = "declineTrades",
		label = L["Decline trades"],
		type = "toggle",
		desc = L["Toggle with /notrade."],
	},
	{
		path = "fillDeleteConfirm",
		label = L['Fill in "DELETE" confirmation'],
		type = "toggle",
		desc = L["Pre-type the confirmation word when deleting good items."],
	},
})

ns.RegisterPage({
	key = "general",
	name = L["General"],
	order = 10,
	schema = schema,
})
