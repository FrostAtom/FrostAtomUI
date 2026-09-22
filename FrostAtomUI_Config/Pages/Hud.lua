local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

local schema = {}

Section(schema, L["Combat alert"], "combatAlert", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Flash a message when entering or leaving combat."],
	},
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "font", label = L["Font"], type = "font" },
	{ path = "duration", label = L["Show for (seconds)"], type = "number", min = 0.5, max = 5, step = 0.1 },
	{
		path = "fadeTime",
		label = L["Fade out (seconds)"],
		type = "number",
		min = 0.1,
		max = 3,
		step = 0.1,
		desc = L["Fade duration after the message has been shown."],
	},
	{ path = "enterText", label = L["Enter combat text"], type = "string" },
	{ path = "enterColor", label = L["Enter combat color"], type = "color" },
	{ path = "leaveText", label = L["Leave combat text"], type = "string" },
	{ path = "leaveColor", label = L["Leave combat color"], type = "color" },
})

Section(schema, L["FPS / latency"], "performance", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Framerate and world latency readout colored by tier."],
	},
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "showFps", label = L["Show FPS"], type = "toggle" },
	{ path = "showLatency", label = L["Show latency"], type = "toggle" },
	{ path = "valueFont", label = L["Value font"], type = "font" },
	{ path = "unitFont", label = L["Unit font"], type = "font", desc = L['The "fps" and "ms" labels.'] },
	{
		path = "fpsRed",
		label = L["FPS: red below"],
		type = "number",
		min = 1,
		max = 200,
		step = 1,
		enabledBy = "performance.showFps",
	},
	{
		path = "fpsOrange",
		label = L["FPS: orange below"],
		type = "number",
		min = 1,
		max = 200,
		step = 1,
		enabledBy = "performance.showFps",
	},
	{
		path = "fpsYellow",
		label = L["FPS: yellow below"],
		type = "number",
		min = 1,
		max = 300,
		step = 1,
		enabledBy = "performance.showFps",
		desc = L["Green at or above this value."],
	},
	{
		path = "latencyYellow",
		label = L["Latency: yellow from"],
		type = "number",
		min = 1,
		max = 1000,
		step = 5,
		enabledBy = "performance.showLatency",
		desc = L["Green below this value (ms)."],
	},
	{
		path = "latencyOrange",
		label = L["Latency: orange from"],
		type = "number",
		min = 1,
		max = 1000,
		step = 5,
		enabledBy = "performance.showLatency",
	},
	{
		path = "latencyRed",
		label = L["Latency: red from"],
		type = "number",
		min = 1,
		max = 2000,
		step = 5,
		enabledBy = "performance.showLatency",
	},
})

Section(schema, L["Low health flash"], "lowHealthFlash", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Pulse a red screen edge at low health."] },
	{
		path = "threshold",
		label = L["Health threshold"],
		type = "number",
		min = 0.05,
		max = 0.9,
		step = 0.01,
		desc = L["Fraction of maximum health below which the flash shows."],
	},
	{
		path = "pulseSpeed",
		label = L["Pulse speed"],
		type = "number",
		min = 0.2,
		max = 5,
		step = 0.1,
		desc = L["Higher pulses faster; 1 fades fully in and out in two seconds."],
	},
})

Section(schema, L["Cursor trail"], "cursorTrail", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Lightning trail following the mouse cursor."],
	},
	{ path = "hideInCombat", label = L["Hide in combat"], type = "toggle" },
	{ path = "scale", label = L["Scale"], type = "number", min = 0.5, max = 2, step = 0.1 },
	{
		path = "trailAlpha",
		label = L["Trail alpha"],
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		desc = L["Lightning bolt trailing behind the cursor."],
	},
	{
		path = "shineAlpha",
		label = L["Shine alpha"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		desc = L["Glow at the cursor tip."],
	},
})

ns.RegisterPage({
	key = "hud",
	name = L["HUD"],
	order = 33,
	schema = schema,
})
