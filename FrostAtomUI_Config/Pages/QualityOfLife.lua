local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

local ui = FrostAtomUI

local function errorsHidden()
	return ui:GetConfig("tweaks.hideErrors")
end

local schema = {}

Section(schema, L["Tweaks"], "tweaks", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Pinned CVars (no tutorials, ground clutter, camera distance, script errors), world state frame position and the Spectate entry in friend menus."],
	},
	{ type = "elements" },
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
})

Section(schema, L["Error messages"], "tweaks", {
	{
		path = "hideErrors",
		label = L["Hide red error messages"],
		type = "toggle",
		desc = L['"Not enough mana", "Out of range" and similar messages at the top of the screen.'],
	},
	{
		path = "dedupErrors",
		new = "1.4.0",
		label = L["Merge repeated error messages"],
		type = "toggle",
		disabled = errorsHidden,
		desc = L["A repeated error flashes the line already on screen instead of adding another one."],
	},
	{
		path = "filterCooldownErrors",
		new = "1.4.0",
		label = L["Hide cooldown and resource errors"],
		type = "toggle",
		disabled = errorsHidden,
		desc = L['"Spell is not ready yet", "Another action is in progress", "Not enough mana / rage / energy / runic power" and similar.'],
	},
})

Section(schema, L["Camera"], "tweaks", {
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
		description = L["Key bindings in Key Bindings > FrostAtomUI snap the camera to these distances."],
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
})

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
		path = "fillDeleteConfirm",
		label = L['Fill in "DELETE" confirmation'],
		type = "toggle",
		desc = L["Pre-type the confirmation word when deleting good items."],
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
		path = "guildRepair",
		new = "1.4.0",
		label = L["Use guild bank funds"],
		type = "toggle",
		enabledBy = "merchant.autoRepair",
		desc = L["Repair from the guild bank when your rank allows it and the guild can pay; otherwise from your own money."],
	},
	{
		path = "shiftToSkip",
		label = L["Hold Shift to skip"],
		type = "toggle",
		desc = L["Do nothing when the merchant window is opened with Shift held."],
	},
	{
		path = "showItemLevel",
		new = "1.4.1",
		label = L["Show item level"],
		type = "toggle",
		desc = L["Item level on merchant and buyback item icons."],
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

Section(schema, L["Character model"], "modelControls", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Drag to rotate, right-drag to pan, mouse wheel to zoom and middle-click to reset the character, inspect and dressing room models. Removes the rotate buttons."],
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
		min = 0.05,
		max = 0.5,
		step = 0.05,
		desc = L["Size change per mouse wheel notch, as a fraction of the current zoom."],
	},
})

Section(schema, L["Character stats"], "characterStats", {
	{
		path = "enabled",
		new = "1.4.1",
		label = L["Stats panel"],
		type = "toggle",
		desc = L["A panel next to the character window with defenses (including resilience), melee, spell, ranged and base stats at once."],
	},
	{
		path = "classCategories",
		new = "1.4.1",
		label = L["Only categories for your class"],
		type = "toggle",
		enabledBy = "characterStats.enabled",
		desc = L["Skip categories your class does not use, such as spell stats for a warrior. Off shows all five."],
	},
})

Section(schema, L["Macros"], "macros", {
	{
		path = "enabled",
		new = "1.4.1",
		label = L["Macro editor"],
		type = "toggle",
		reload = true,
		desc = L["Replaces the /macro window: unlimited macros of any length, syntax and error highlighting, key bindings right in the window. /macro opens it."],
	},
})

Section(schema, L["Spellbook"], "spellBook", {
	{
		path = "enabled",
		new = "1.4.1",
		label = L["Spellbook window"],
		type = "toggle",
		reload = true,
		desc = L["Replaces the spellbook: every tab and the pet book in one wide window, four columns, search and a switch to hide passive abilities."],
	},
})

Section(schema, L["Talents"], "talentFrame", {
	{
		path = "enabled",
		new = "1.4.1",
		label = L["Talents window"],
		type = "toggle",
		reload = true,
		desc = L["Replaces the talent window: all three trees side by side with glyphs next to them, dual spec, pet talents and preview."],
	},
})

schema[#schema + 1] = { header = L["Interface"] }
schema[#schema + 1] = {
	path = "wheelPaging.enabled",
	label = L["Mouse wheel paging"],
	type = "toggle",
	desc = L["Scroll pages in the merchant, spellbook, mailbox, auction house and calendar with the mouse wheel."],
}

Section(schema, L["Combat log"], "combatLogFix", {
	{
		path = "enabled",
		label = L["Fix stalled combat log"],
		type = "toggle",
		desc = L["Clear the combat log when it stops delivering events inside instances."],
	},
}, not FrostAtomUI.IS_WOWCIRCLE)

ns.RegisterPage({
	key = "qol",
	name = L["Quality of life"],
	order = 45,
	schema = schema,
})

ns.RegisterElement({
	path = "tweaks.worldStatePoint",
	page = "qol",
	name = L["World state"],
	enabledBy = "tweaks.enabled",
	schema = {},
})
