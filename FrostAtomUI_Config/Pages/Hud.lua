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
		path = "fpsWorst",
		label = "FPS: red below",
		type = "number",
		min = 1,
		max = 120,
		step = 1,
		desc = "Framerate shown in red at or below this value.",
	},
	{
		path = "fpsBest",
		label = "FPS: white above",
		type = "number",
		min = 1,
		max = 200,
		step = 1,
		desc = "Framerate shown in white at or above this value.",
	},
	{
		path = "latencyBest",
		label = "Latency: white below",
		type = "number",
		min = 1,
		max = 500,
		step = 1,
		desc = "Latency shown in white at or below this value (ms).",
	},
	{
		path = "latencyWorst",
		label = "Latency: red above",
		type = "number",
		min = 1,
		max = 2000,
		step = 5,
		desc = "Latency shown in red at or above this value (ms).",
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
