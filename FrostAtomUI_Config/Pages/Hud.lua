local _, ns = ...

local Section = ns.Section

local schema = {}

Section(schema, "Combat alert", "combatAlert", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Flash a message when entering or leaving combat." },
	{ path = "point", label = "Position", type = "point" },
	{ path = "font", label = "Font", type = "font" },
	{ path = "duration", label = "Show for (seconds)", type = "number", min = 0.5, max = 5, step = 0.1 },
	{
		path = "fadeTime",
		label = "Fade out (seconds)",
		type = "number",
		min = 0.1,
		max = 3,
		step = 0.1,
		desc = "Fade duration after the message has been shown.",
	},
	{ path = "enterText", label = "Enter combat text", type = "string" },
	{ path = "enterColor", label = "Enter combat color", type = "color" },
	{ path = "leaveText", label = "Leave combat text", type = "string" },
	{ path = "leaveColor", label = "Leave combat color", type = "color" },
})

Section(schema, "FPS / latency", "performance", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		desc = "Framerate and world latency readout colored by tier.",
	},
	{ path = "point", label = "Position", type = "point" },
	{ path = "showFps", label = "Show FPS", type = "toggle" },
	{ path = "showLatency", label = "Show latency", type = "toggle" },
	{ path = "valueFont", label = "Value font", type = "font" },
	{ path = "unitFont", label = "Unit font", type = "font", desc = 'The "fps" and "ms" labels.' },
	{
		path = "fpsRed",
		label = "FPS: red below",
		type = "number",
		min = 1,
		max = 200,
		step = 1,
		enabledBy = "performance.showFps",
	},
	{
		path = "fpsOrange",
		label = "FPS: orange below",
		type = "number",
		min = 1,
		max = 200,
		step = 1,
		enabledBy = "performance.showFps",
	},
	{
		path = "fpsYellow",
		label = "FPS: yellow below",
		type = "number",
		min = 1,
		max = 300,
		step = 1,
		enabledBy = "performance.showFps",
		desc = "Green at or above this value.",
	},
	{
		path = "latencyYellow",
		label = "Latency: yellow from",
		type = "number",
		min = 1,
		max = 1000,
		step = 5,
		enabledBy = "performance.showLatency",
		desc = "Green below this value (ms).",
	},
	{
		path = "latencyOrange",
		label = "Latency: orange from",
		type = "number",
		min = 1,
		max = 1000,
		step = 5,
		enabledBy = "performance.showLatency",
	},
	{
		path = "latencyRed",
		label = "Latency: red from",
		type = "number",
		min = 1,
		max = 2000,
		step = 5,
		enabledBy = "performance.showLatency",
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
	{
		path = "pulseSpeed",
		label = "Pulse speed",
		type = "number",
		min = 0.2,
		max = 5,
		step = 0.1,
		desc = "Higher pulses faster; 1 fades fully in and out in two seconds.",
	},
})

Section(schema, "Cursor trail", "cursorTrail", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Lightning trail following the mouse cursor." },
	{ path = "hideInCombat", label = "Hide in combat", type = "toggle" },
	{ path = "scale", label = "Scale", type = "number", min = 0.5, max = 2, step = 0.1 },
	{
		path = "trailAlpha",
		label = "Trail alpha",
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		desc = "Lightning bolt trailing behind the cursor.",
	},
	{
		path = "shineAlpha",
		label = "Shine alpha",
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		desc = "Glow at the cursor tip.",
	},
})

ns.RegisterPage({
	key = "hud",
	name = "HUD",
	order = 33,
	schema = schema,
})
