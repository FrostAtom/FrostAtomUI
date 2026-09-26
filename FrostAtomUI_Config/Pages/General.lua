local _, ns = ...

local L = FrostAtomUI.L

local ui = FrostAtomUI

local schema = {
	{ header = L["Language"], glyph = "language" },
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
	{ header = L["Appearance"], glyph = "palette" },
	{ path = "general.font", label = L["Font"], type = "select", values = ui.Media.fonts, preview = "font" },
	{
		path = "general.fontBold",
		label = L["Bold font"],
		type = "select",
		values = ui.Media.fonts,
		preview = "font",
		advanced = true,
	},
	{
		path = "general.statusbar",
		label = L["Status bar texture"],
		type = "select",
		values = ui.Media.statusbars,
		preview = "statusbar",
	},
	{
		path = "general.useUiScale",
		label = L["Override UI scale"],
		type = "toggle",
		desc = L["Apply the scale below instead of the game's own setting. Turning it off keeps the last applied value."],
	},
	{
		path = "general.pixelPerfectScale",
		label = L["Pixel-perfect scale"],
		type = "toggle",
		enabledBy = "general.useUiScale",
		confirmRevert = true,
		desc = L["One interface unit becomes one screen pixel: 768 / screen height (%.2f here). Borders stay sharp, on large screens this goes below the game's 0.64 limit and leaves more room for frames."]:format(
			ui.PixelPerfectScale()
		),
	},
	{
		path = "general.uiScale",
		label = L["UI scale"],
		type = "number",
		min = 0.4,
		max = 1,
		step = 0.01,
		enabledBy = "general.useUiScale",
		disabled = function()
			return ui:GetConfig("general.pixelPerfectScale")
		end,
		disabledDesc = L["Pixel-perfect scale picks the scale."],
		confirmRevert = true,
		desc = L["Below 0.64 the scale is applied by FrostAtom UI itself, the game's own setting stops at 0.64."],
	},
	{ header = L["Cooldown timers"], new = "1.4.0", glyph = "stopwatch" },
	{
		description = L["Countdown text on action buttons, bags, unit frame cooldowns, nameplate auras and totems."],
	},
	{
		path = "cooldownTimer.minDuration",
		new = "1.4.0",
		label = L["Hide timers up to"],
		type = "number",
		min = 1.5,
		max = 10,
		step = 0.5,
		unit = "s",
		desc = L["Cooldowns this long or shorter get no countdown. 1.5 hides only the global cooldown."],
	},
	{
		path = "cooldownTimer.decimalThreshold",
		advanced = true,
		new = "1.4.0",
		label = L["Tenths below"],
		type = "number",
		min = 0,
		max = 10,
		step = 0.5,
		unit = "s",
		zeroText = L["Off"],
		desc = L["Remaining time under this value is shown with tenths of a second in the expiring color."],
	},
	{
		path = "cooldownTimer.expiringColor",
		new = "1.4.0",
		label = L["Expiring color"],
		type = "color",
		advanced = true,
	},
	{
		path = "cooldownTimer.secondsColor",
		advanced = true,
		new = "1.4.0",
		label = L["Seconds color"],
		type = "color",
		desc = L["Under a minute left."],
	},
	{
		path = "cooldownTimer.minutesColor",
		advanced = true,
		new = "1.4.0",
		label = L["Minutes color"],
		type = "color",
		desc = L["A minute or more left."],
	},
	{ header = L["Other addons"], new = "1.4.1", glyph = "puzzle-piece" },
	{
		label = L["Conflicting addons"],
		new = "1.4.1",
		type = "execute",
		text = L["Ask again"],
		glyph = "arrows-rotate",
		advanced = true,
		func = function()
			ui.ResetConflictChoices()
		end,
		desc = L["Forget the answers given when another addon was found doing the same job as a FrostAtom UI module, and check the loaded addons again."],
	},
}

ns.RegisterPage({
	key = "general",
	name = L["General"],
	glyph = "gear",
	order = 10,
	group = "core",
	schema = schema,
})
