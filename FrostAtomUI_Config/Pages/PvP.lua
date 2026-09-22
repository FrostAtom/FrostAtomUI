local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

local schema = {}

Section(schema, L["Arena"], "arena", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Arena start countdown and pillar timer."] },
	{
		path = "countdown",
		label = L["Start countdown"],
		type = "toggle",
		desc = L["Large timer for the last 15 seconds before the gates open."],
	},
	{ path = "countdownPoint", label = L["Countdown position"], type = "point", enabledBy = "arena.countdown" },
	{ path = "countdownFont", label = L["Countdown font"], type = "font", enabledBy = "arena.countdown" },
	{ path = "countdownColor", label = L["Countdown color"], type = "color", enabledBy = "arena.countdown" },
	{
		path = "countdownUrgentColor",
		label = L["Countdown final seconds color"],
		type = "color",
		enabledBy = "arena.countdown",
		desc = L["Used for the last 3 seconds, when tenths are shown."],
	},
	{
		path = "pillars",
		label = L["Ring of Valor pillar timer"],
		type = "toggle",
		desc = L["Icon above the chat frame counting down to the next pillar toggle."],
	},
	{
		path = "pillarsSize",
		label = L["Pillar timer size"],
		type = "number",
		min = 20,
		max = 64,
		step = 1,
		enabledBy = "arena.pillars",
	},
	{
		path = "pillarsFirstToggle",
		label = L["First pillar toggle (seconds)"],
		type = "number",
		min = 10,
		max = 120,
		step = 1,
		enabledBy = "arena.pillars",
		desc = L["Seconds after the gates open until the pillars move for the first time. Depends on the server."],
	},
	{
		path = "pillarsPeriod",
		label = L["Pillar toggle period (seconds)"],
		type = "number",
		min = 5,
		max = 120,
		step = 1,
		enabledBy = "arena.pillars",
		desc = L["Seconds between pillar toggles after the first one. Depends on the server."],
	},
})

Section(schema, L["Battleground"], "battleground", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Battleground helpers."] },
	{
		path = "raidWarnings",
		label = L["System messages as raid warnings"],
		type = "toggle",
		desc = L["Show battleground and arena system messages in the raid warning frame."],
	},
})

Section(schema, L["Solo queue"], "soloQueue", {
	{
		path = "enabled",
		label = L["Queue button"],
		type = "toggle",
		desc = L["Join, leave and enter the solo queue from a button next to the queue eye."],
	},
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "buttonSize", label = L["Button size"], type = "number", min = 12, max = 40, step = 1 },
	{
		path = "queuedSize",
		label = L["Button size in queue"],
		type = "number",
		min = 12,
		max = 60,
		step = 1,
		desc = L["Button size while waiting in the queue or ready to enter."],
	},
	{
		path = "glowColor",
		label = L["Ready glow color"],
		type = "color",
		desc = L["Glow around the button when the arena is ready to enter."],
	},
	{
		path = "rangeFont",
		label = L["Search range font"],
		type = "font",
		desc = L["Rating range shown under the button while searching."],
	},
	{
		path = "teamSearchColor",
		label = L["Team search color"],
		type = "color",
		desc = L["Range text while the queue is looking for teammates."],
	},
	{
		path = "opponentSearchColor",
		label = L["Opponent search color"],
		type = "color",
		desc = L["Range text once a team is formed and the queue is looking for opponents."],
	},
})

Section(schema, L["World map"], "worldMap", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Zoomable, pannable map without the black background, with coordinates and class colored group icons."],
	},
	{
		path = "screenFraction",
		label = L["Full map screen height"],
		type = "number",
		min = 0.5,
		max = 1,
		step = 0.05,
		desc = L["Fraction of the screen height the full-size map takes."],
	},
	{
		path = "showCoords",
		label = L["Show coordinates"],
		type = "toggle",
		desc = L["Cursor and player coordinates."],
	},
	{ path = "coordFont", label = L["Coordinates font"], type = "font", enabledBy = "worldMap.showCoords" },
	{ path = "arrowSize", label = L["Player arrow size"], type = "number", min = 16, max = 64, step = 1 },
	{
		path = "zoomStep",
		label = L["Zoom step"],
		type = "number",
		min = 0.05,
		max = 0.5,
		step = 0.05,
		desc = L["Zoom change per mouse wheel notch, as a fraction of the current zoom."],
	},
	{
		path = "maxZoom",
		label = L["Maximum zoom"],
		type = "number",
		min = 1.5,
		max = 8,
		step = 0.5,
		desc = L["Magnification limit for mouse wheel zoom."],
	},
})

ns.RegisterPage({
	key = "pvp",
	name = L["PvP"],
	order = 34,
	schema = schema,
})
