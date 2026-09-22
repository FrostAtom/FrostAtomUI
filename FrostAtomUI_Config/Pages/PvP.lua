local _, ns = ...

local Section = ns.Section

local schema = {}

Section(schema, "Arena", "arena", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Arena start countdown and pillar timer." },
	{
		path = "countdown",
		label = "Start countdown",
		type = "toggle",
		desc = "Large timer for the last 15 seconds before the gates open.",
	},
	{ path = "countdownPoint", label = "Countdown position", type = "point", enabledBy = "arena.countdown" },
	{ path = "countdownFont", label = "Countdown font", type = "font", enabledBy = "arena.countdown" },
	{ path = "countdownColor", label = "Countdown color", type = "color", enabledBy = "arena.countdown" },
	{
		path = "countdownUrgentColor",
		label = "Countdown final seconds color",
		type = "color",
		enabledBy = "arena.countdown",
		desc = "Used for the last 3 seconds, when tenths are shown.",
	},
	{
		path = "pillars",
		label = "Ring of Valor pillar timer",
		type = "toggle",
		desc = "Icon above the chat frame counting down to the next pillar toggle.",
	},
	{
		path = "pillarsSize",
		label = "Pillar timer size",
		type = "number",
		min = 20,
		max = 64,
		step = 1,
		enabledBy = "arena.pillars",
	},
	{
		path = "pillarsFirstToggle",
		label = "First pillar toggle (seconds)",
		type = "number",
		min = 10,
		max = 120,
		step = 1,
		enabledBy = "arena.pillars",
		desc = "Seconds after the gates open until the pillars move for the first time. Depends on the server.",
	},
	{
		path = "pillarsPeriod",
		label = "Pillar toggle period (seconds)",
		type = "number",
		min = 5,
		max = 120,
		step = 1,
		enabledBy = "arena.pillars",
		desc = "Seconds between pillar toggles after the first one. Depends on the server.",
	},
})

Section(schema, "Battleground", "battleground", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Battleground helpers." },
	{
		path = "raidWarnings",
		label = "System messages as raid warnings",
		type = "toggle",
		desc = "Show battleground and arena system messages in the raid warning frame.",
	},
})

Section(schema, "Solo queue", "soloQueue", {
	{
		path = "enabled",
		label = "Queue button",
		type = "toggle",
		desc = "Join, leave and enter the solo queue from a button next to the queue eye.",
	},
	{ path = "point", label = "Position", type = "point" },
	{ path = "buttonSize", label = "Button size", type = "number", min = 12, max = 40, step = 1 },
	{
		path = "queuedSize",
		label = "Button size in queue",
		type = "number",
		min = 12,
		max = 60,
		step = 1,
		desc = "Button size while waiting in the queue or ready to enter.",
	},
	{
		path = "glowColor",
		label = "Ready glow color",
		type = "color",
		desc = "Glow around the button when the arena is ready to enter.",
	},
	{
		path = "rangeFont",
		label = "Search range font",
		type = "font",
		desc = "Rating range shown under the button while searching.",
	},
	{
		path = "teamSearchColor",
		label = "Team search color",
		type = "color",
		desc = "Range text while the queue is looking for teammates.",
	},
	{
		path = "opponentSearchColor",
		label = "Opponent search color",
		type = "color",
		desc = "Range text once a team is formed and the queue is looking for opponents.",
	},
})

Section(schema, "World map", "worldMap", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		reload = true,
		desc = "Zoomable, pannable map without the black background, with coordinates and class colored group icons.",
	},
	{
		path = "screenFraction",
		label = "Full map screen height",
		type = "number",
		min = 0.5,
		max = 1,
		step = 0.05,
		desc = "Fraction of the screen height the full-size map takes.",
	},
	{ path = "showCoords", label = "Show coordinates", type = "toggle", desc = "Cursor and player coordinates." },
	{ path = "coordFont", label = "Coordinates font", type = "font", enabledBy = "worldMap.showCoords" },
	{ path = "arrowSize", label = "Player arrow size", type = "number", min = 16, max = 64, step = 1 },
	{
		path = "zoomStep",
		label = "Zoom step",
		type = "number",
		min = 0.05,
		max = 0.5,
		step = 0.05,
		desc = "Zoom change per mouse wheel notch, as a fraction of the current zoom.",
	},
	{
		path = "maxZoom",
		label = "Maximum zoom",
		type = "number",
		min = 1.5,
		max = 8,
		step = 0.5,
		desc = "Magnification limit for mouse wheel zoom.",
	},
})

ns.RegisterPage({
	key = "pvp",
	name = "PvP",
	order = 34,
	schema = schema,
})
