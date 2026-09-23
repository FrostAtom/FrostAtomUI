local _, ns = ...

local L = FrostAtomUI.L

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
		confirmRevert = true,
	},
	{ header = L["Cooldown timers"], new = "1.4.0" },
	{
		description = L["Countdown text on action buttons, bags, unit frame cooldowns, nameplate auras and totems."],
	},
	{
		path = "cooldownTimer.minDuration",
		new = "1.4.0",
		label = L["Hide timers up to (seconds)"],
		type = "number",
		min = 1.5,
		max = 10,
		step = 0.5,
		desc = L["Cooldowns this long or shorter get no countdown. 1.5 hides only the global cooldown."],
	},
	{
		path = "cooldownTimer.decimalThreshold",
		new = "1.4.0",
		label = L["Tenths below (seconds)"],
		type = "number",
		min = 0,
		max = 10,
		step = 0.5,
		desc = L["Remaining time under this value is shown with tenths of a second in the expiring color. 0 turns it off."],
	},
	{ path = "cooldownTimer.expiringColor", new = "1.4.0", label = L["Expiring color"], type = "color" },
	{
		path = "cooldownTimer.secondsColor",
		new = "1.4.0",
		label = L["Seconds color"],
		type = "color",
		desc = L["Under a minute left."],
	},
	{
		path = "cooldownTimer.minutesColor",
		new = "1.4.0",
		label = L["Minutes color"],
		type = "color",
		desc = L["A minute or more left."],
	},
	{ header = L["Frame movers"] },
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

ns.RegisterPage({
	key = "general",
	name = L["General"],
	order = 10,
	schema = schema,
})
