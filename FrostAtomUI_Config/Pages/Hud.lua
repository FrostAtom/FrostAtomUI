local _, ns = ...

local Section = ns.Section

local schema = {}

Section(schema, "Combat alert", "combatAlert", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Flash a message when entering or leaving combat." },
	{ path = "point", label = "Position", type = "point" },
	{ path = "font", label = "Font", type = "font" },
	{ path = "duration", label = "Show for (seconds)", type = "number", min = 0.5, max = 5, step = 0.1 },
	{ path = "enterText", label = "Enter combat text", type = "string" },
	{ path = "enterColor", label = "Enter combat color", type = "color" },
	{ path = "leaveText", label = "Leave combat text", type = "string" },
	{ path = "leaveColor", label = "Leave combat color", type = "color" },
})

Section(schema, "FPS / latency", "performance", {
	{ path = "enabled", label = "Enable", type = "toggle" },
	{ path = "point", label = "Position", type = "point" },
	{ path = "valueFont", label = "Value font", type = "font" },
	{ path = "unitFont", label = "Unit font", type = "font" },
	{
		path = "fpsRed",
		label = "FPS: red below",
		type = "number",
		min = 1,
		max = 200,
		step = 1,
	},
	{
		path = "fpsOrange",
		label = "FPS: orange below",
		type = "number",
		min = 1,
		max = 200,
		step = 1,
	},
	{
		path = "fpsYellow",
		label = "FPS: yellow below",
		type = "number",
		min = 1,
		max = 300,
		step = 1,
		desc = "Green at or above this value.",
	},
	{
		path = "latencyYellow",
		label = "Latency: yellow from",
		type = "number",
		min = 1,
		max = 1000,
		step = 5,
		desc = "Green below this value (ms).",
	},
	{
		path = "latencyOrange",
		label = "Latency: orange from",
		type = "number",
		min = 1,
		max = 1000,
		step = 5,
	},
	{
		path = "latencyRed",
		label = "Latency: red from",
		type = "number",
		min = 1,
		max = 2000,
		step = 5,
	},
})

Section(schema, "Low health flash", "lowHealthFlash", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Pulse a red screen edge at low health." },
	{
		path = "threshold",
		label = "Health threshold",
		type = "number",
		min = 0.05,
		max = 0.9,
		step = 0.01,
		desc = "Fraction of maximum health below which the flash shows.",
	},
})

Section(schema, "Cursor trail", "cursorTrail", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Lightning trail following the mouse cursor." },
})

ns.RegisterPage({
	key = "hud",
	name = "HUD",
	order = 33,
	schema = schema,
})
