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
	{ path = "maxGames", label = "Games to keep", type = "number", min = 50, max = 5000, step = 50 },
	{
		label = "History window",
		type = "execute",
		text = "Open",
		func = function()
			SlashCmdList.FROSTATOMUI_ARENA_HISTORY()
		end,
	},
})

schema[#schema + 1] = { header = "Equipment" }
schema[#schema + 1] = {
	path = "equipment.showItemLevels",
	label = "Item levels on character / inspect",
	type = "toggle",
	desc = "Per-slot item level and the average on the paper doll.",
}
schema[#schema + 1] = { path = "equipment.durabilityWarning", label = "Durability warning", type = "toggle" }
schema[#schema + 1] = {
	path = "equipment.durabilityThreshold",
	label = "Warn below",
	type = "number",
	min = 0.05,
	max = 0.9,
	step = 0.05,
	enabledBy = "equipment.durabilityWarning",
	desc = "Warn when any equipped item drops below this durability.",
}

schema[#schema + 1] = { header = "Merchant" }
schema[#schema + 1] = {
	path = "merchant.sellGreys",
	label = "Sell grey items",
	type = "toggle",
	desc = "Hold Shift while opening a merchant to skip.",
}
schema[#schema + 1] = {
	path = "merchant.autoRepair",
	label = "Auto repair",
	type = "toggle",
	desc = "Hold Shift while opening a merchant to skip.",
}

schema[#schema + 1] = { header = "Interface" }
schema[#schema + 1] = {
	path = "wheelPaging.enabled",
	label = "Mouse wheel paging",
	type = "toggle",
	desc = "Scroll pages in the merchant, spellbook, mailbox, auction house and calendar with the mouse wheel.",
}
schema[#schema + 1] = {
	path = "tweaks.hideErrors",
	label = "Hide red error messages",
	type = "toggle",
	desc = '"Not enough mana", "Out of range" and similar messages at the top of the screen.',
}

schema[#schema + 1] = { header = "Popups" }
schema[#schema + 1] = {
	path = "popups.autoAcceptInvites",
	label = "Auto accept invites from friends / guild",
	type = "toggle",
}
schema[#schema + 1] = {
	path = "popups.autoRelease",
	label = "Auto release in battlegrounds",
	type = "toggle",
}
schema[#schema + 1] = {
	path = "popups.declineTradeInCombat",
	label = "Decline trades in combat",
	type = "toggle",
}
schema[#schema + 1] = {
	path = "popups.declineDuels",
	label = "Decline duels",
	type = "toggle",
	desc = "Toggle with /noduel.",
}
schema[#schema + 1] = {
	path = "popups.declineInvites",
	label = "Decline party invites",
	type = "toggle",
	desc = "Toggle with /noparty.",
}
schema[#schema + 1] = {
	path = "popups.declineTrades",
	label = "Decline trades",
	type = "toggle",
	desc = "Toggle with /notrade.",
}
schema[#schema + 1] = {
	path = "popups.fillDeleteConfirm",
	label = 'Fill in "DELETE" confirmation',
	type = "toggle",
}

ns.RegisterPage({
	key = "general",
	name = "General",
	order = 10,
	schema = schema,
})
