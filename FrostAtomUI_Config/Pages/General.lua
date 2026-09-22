local _, ns = ...

local Section = ns.Section

local ui = FrostAtomUI

local schema = {
	{ header = "Appearance" },
	{ path = "general.font", label = "Font", type = "select", values = ui.Media.fonts },
	{ path = "general.fontBold", label = "Bold font", type = "select", values = ui.Media.fonts },
	{ path = "general.statusbar", label = "Status bar texture", type = "select", values = ui.Media.statusbars },
	{
		path = "general.useUiScale",
		label = "Override UI scale",
		type = "toggle",
		desc = "Apply the scale below instead of the game's own setting. Turning it off keeps the last applied value.",
	},
	{
		path = "general.uiScale",
		label = "UI scale",
		type = "number",
		min = 0.64,
		max = 1,
		step = 0.01,
		enabledBy = "general.useUiScale",
	},
	{ header = "Unit frames" },
	{
		path = "dispelHighlightAlpha",
		label = "Dispel highlight alpha",
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		desc = "Border alpha on unit frames with a debuff you can dispel.",
	},
}

Section(schema, "Arena history", "arenaHistory", {
	{ path = "enabled", label = "Record games", type = "toggle", desc = "Save arena scoreboards. Open with /history." },
	{ path = "point", label = "Window position", type = "point" },
	{
		path = "maxGames",
		label = "Games to keep",
		type = "number",
		min = 50,
		max = 5000,
		step = 50,
		desc = "Oldest games are dropped past this count.",
	},
	{ path = "listFont", label = "List font", type = "font", desc = "Rows of the game list and match details." },
	{ path = "winColor", label = "Win color", type = "color" },
	{ path = "lossColor", label = "Loss color", type = "color" },
	{
		label = "History window",
		type = "execute",
		text = "Open",
		func = function()
			SlashCmdList.FROSTATOMUI_ARENA_HISTORY()
		end,
	},
})

Section(schema, "Equipment", "equipment", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Item level display and durability warnings." },
	{
		path = "showItemLevels",
		label = "Item levels on character / inspect",
		type = "toggle",
		desc = "Per-slot item level and the average on the paper doll.",
	},
	{ path = "slotFont", label = "Slot item level font", type = "font", enabledBy = "equipment.showItemLevels" },
	{ path = "averageFont", label = "Average item level font", type = "font", enabledBy = "equipment.showItemLevels" },
	{
		path = "qualityThresholds.uncommon",
		label = "Average: green from",
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
		desc = "Average item level colored by quality tier. Grey below this value.",
	},
	{
		path = "qualityThresholds.rare",
		label = "Average: blue from",
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
	},
	{
		path = "qualityThresholds.epic",
		label = "Average: purple from",
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
	},
	{
		path = "qualityThresholds.legendary",
		label = "Average: orange from",
		type = "number",
		min = 1,
		max = 400,
		step = 1,
		enabledBy = "equipment.showItemLevels",
	},
	{
		path = "durabilityWarning",
		label = "Durability warning",
		type = "toggle",
		desc = "Print a chat warning when gear durability gets low.",
	},
	{
		path = "durabilityThreshold",
		label = "Warn below",
		type = "number",
		min = 0.05,
		max = 0.9,
		step = 0.05,
		enabledBy = "equipment.durabilityWarning",
		desc = "Warn when any equipped item drops below this durability.",
	},
})

Section(schema, "Merchant", "merchant", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Automatic actions when a merchant window opens." },
	{
		path = "sellGreys",
		label = "Sell grey items",
		type = "toggle",
		desc = "Sell every poor quality item in your bags.",
	},
	{ path = "autoRepair", label = "Auto repair", type = "toggle", desc = "Repair all gear when you can afford it." },
	{
		path = "shiftToSkip",
		label = "Hold Shift to skip",
		type = "toggle",
		desc = "Do nothing when the merchant window is opened with Shift held.",
	},
})

schema[#schema + 1] = { header = "Interface" }
schema[#schema + 1] = {
	path = "wheelPaging.enabled",
	label = "Mouse wheel paging",
	type = "toggle",
	desc = "Scroll pages in the merchant, spellbook, mailbox, auction house and calendar with the mouse wheel.",
}

Section(schema, "Tweaks", "tweaks", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		reload = true,
		desc = "Pinned CVars (no tutorials, ground clutter, camera distance, script errors), "
			.. "world state frame position and the Spectate entry in friend menus.",
	},
	{
		path = "hideErrors",
		label = "Hide red error messages",
		type = "toggle",
		desc = '"Not enough mana", "Out of range" and similar messages at the top of the screen.',
	},
	{
		path = "scriptErrors",
		label = "Show Lua errors",
		type = "toggle",
		desc = "Pop up addon script errors instead of silently ignoring them.",
	},
	{
		path = "hideGroundClutter",
		label = "Hide ground clutter",
		type = "toggle",
		desc = "Grass and other ground decorations. Turning it off restores the game default.",
	},
	{
		path = "cameraDistanceMax",
		label = "Max camera distance",
		type = "number",
		min = 10,
		max = 50,
		step = 1,
		desc = "How far the camera can zoom out.",
	},
	{
		path = "worldStatePoint",
		label = "World state position",
		type = "point",
		desc = "Battleground score / flag status frame.",
	},
})

Section(schema, "Character model", "modelControls", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		reload = true,
		desc = "Drag to rotate, right-drag to pan and mouse wheel to zoom the character, inspect and dressing room models. "
			.. "Removes the rotate buttons.",
	},
	{
		path = "rotateSpeed",
		label = "Rotate speed",
		type = "number",
		min = 0.002,
		max = 0.05,
		step = 0.002,
		desc = "Radians per pixel of mouse movement.",
	},
	{
		path = "zoomStep",
		label = "Zoom step",
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		desc = "Distance change per mouse wheel notch.",
	},
})

Section(schema, "Combat log", "combatLogFix", {
	{
		path = "enabled",
		label = "Fix stalled combat log",
		type = "toggle",
		desc = "Clear the combat log when it stops delivering events inside instances. WoW Circle only.",
	},
}, not GetCVar("realmlist"):lower():find("circle"))

Section(schema, "Popups", "popups", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Automatic handling of popup dialogs." },
	{
		path = "autoAcceptInvites",
		label = "Auto accept invites from friends / guild",
		type = "toggle",
		desc = "Only while not already in a group.",
	},
	{
		path = "autoRelease",
		label = "Auto release in battlegrounds",
		type = "toggle",
		desc = "Release spirit immediately on death in a battleground.",
	},
	{
		path = "declineTradeInCombat",
		label = "Decline trades in combat",
		type = "toggle",
		desc = "Close incoming trade windows while in combat.",
	},
	{
		path = "declineDuels",
		label = "Decline duels",
		type = "toggle",
		desc = "Toggle with /noduel.",
	},
	{
		path = "declineInvites",
		label = "Decline party invites",
		type = "toggle",
		desc = "Toggle with /noparty.",
	},
	{
		path = "declineTrades",
		label = "Decline trades",
		type = "toggle",
		desc = "Toggle with /notrade.",
	},
	{
		path = "fillDeleteConfirm",
		label = 'Fill in "DELETE" confirmation',
		type = "toggle",
		desc = "Pre-type the confirmation word when deleting good items.",
	},
})

ns.RegisterPage({
	key = "general",
	name = "General",
	order = 10,
	schema = schema,
})
