local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

ns.RegisterElement({
	path = "combatAlert.point",
	page = "hud",
	name = L["Combat alert"],
	glyph = "triangle-exclamation",
	enabledBy = "combatAlert.enabled",
	schema = {
		{ header = L["Text"], glyph = "font" },
		{ path = "combatAlert.font", label = L["Font"], type = "font", advanced = true },
		{ path = "combatAlert.enterText", label = L["Enter combat text"], type = "string" },
		{ path = "combatAlert.leaveText", label = L["Leave combat text"], type = "string" },
		{ header = L["Colors"], glyph = "palette", advanced = true },
		{ path = "combatAlert.enterColor", label = L["Enter combat color"], type = "color" },
		{ path = "combatAlert.leaveColor", label = L["Leave combat color"], type = "color" },
		{ header = L["Visibility"], glyph = "eye" },
		{
			path = "combatAlert.duration",
			label = L["Duration"],
			type = "number",
			min = 0.5,
			max = 5,
			step = 0.1,
			unit = "s",
			advanced = true,
			desc = L["Seconds the message stays fully visible before it fades."],
		},
		{
			path = "combatAlert.fadeTime",
			label = L["Fade time"],
			type = "number",
			min = 0.1,
			max = 3,
			step = 0.1,
			unit = "s",
			advanced = true,
			desc = L["Fade duration after the message has been shown."],
		},
		{
			label = L["Test"],
			type = "execute",
			text = L["Show"],
			glyph = "flask",
			desc = L["Show the enter combat message once."],
			func = function()
				FrostAtomUI:GetModule("Misc"):TestCombatAlert()
			end,
		},
	},
})

ns.RegisterElement({
	path = "performance.point",
	page = "hud",
	name = L["FPS / latency"],
	glyph = "gauge-high",
	enabledBy = "performance.enabled",
	schema = {
		{ header = L["Text"], glyph = "font", advanced = true },
		{ path = "performance.valueFont", label = L["Value font"], type = "font" },
		{
			path = "performance.unitFont",
			label = L["Unit font"],
			type = "font",
			desc = L['The "fps" and "ms" labels.'],
		},
	},
})

ns.RegisterElement({
	path = "experienceBar.point",
	page = "hud",
	name = L["Experience bar"],
	glyph = "chart-line",
	enabledBy = "experienceBar.enabled",
	schema = {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{ path = "experienceBar.width", label = L["Width"], type = "number", min = 100, max = 1200, step = 1 },
		{ path = "experienceBar.height", label = L["Height"], type = "number", min = 2, max = 30, step = 1 },
		{ header = L["Colors"], glyph = "palette", advanced = true },
		{ path = "experienceBar.xpColor", label = L["Experience"], type = "color" },
		{
			path = "experienceBar.restedColor",
			label = L["Rested"],
			type = "color",
			alpha = true,
			desc = L["Overlay showing how far the rested bonus reaches."],
		},
		{
			path = "experienceBar.backgroundAlpha",
			label = L["Background alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			percent = true,
		},
	},
})

local schema = {
	{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
	{ type = "elements" },
}

Section(schema, L["Combat alert"], "combatAlert", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Flash a message when entering or leaving combat."],
	},
}, nil, nil, "triangle-exclamation")

Section(schema, L["FPS / latency"], "performance", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Framerate and world latency readout colored by tier."],
	},
	{
		path = "fpsRed",
		label = L["FPS: red below"],
		type = "number",
		min = 10,
		max = 120,
		step = 1,
		advanced = true,
		enabledBy = "performance.showFps",
	},
	{
		path = "fpsOrange",
		label = L["FPS: orange below"],
		type = "number",
		min = 10,
		max = 150,
		step = 1,
		advanced = true,
		enabledBy = "performance.showFps",
	},
	{
		path = "fpsYellow",
		label = L["FPS: yellow below"],
		type = "number",
		min = 10,
		max = 300,
		step = 1,
		advanced = true,
		enabledBy = "performance.showFps",
		desc = L["Green at or above this value."],
	},
	{
		path = "latencyYellow",
		label = L["Latency: yellow from"],
		type = "number",
		min = 10,
		max = 500,
		step = 5,
		unit = "ms",
		advanced = true,
		enabledBy = "performance.showLatency",
		desc = L["Green below this value."],
	},
	{
		path = "latencyOrange",
		label = L["Latency: orange from"],
		type = "number",
		min = 10,
		max = 1000,
		step = 5,
		unit = "ms",
		advanced = true,
		enabledBy = "performance.showLatency",
	},
	{
		path = "latencyRed",
		label = L["Latency: red from"],
		type = "number",
		min = 10,
		max = 2000,
		step = 5,
		unit = "ms",
		advanced = true,
		enabledBy = "performance.showLatency",
	},
}, nil, nil, "gauge-high")

tinsert(schema, #schema - 5, {
	path = "performance",
	label = L["Show"],
	type = "multiselect",
	values = {
		{ "showFps", L["FPS"] },
		{ "showLatency", L["Latency"], L["World latency in milliseconds."] },
	},
	enabledBy = "performance.enabled",
})

Section(schema, L["Experience bar"], "experienceBar", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Thin experience bar; hidden at max level unless a reputation is watched."],
	},
	{
		path = "showReputation",
		label = L["Show watched reputation at max level"],
		type = "toggle",
		desc = L["Track the reputation selected in the Reputation window instead of experience."],
	},
}, nil, nil, "chart-line")

Section(schema, L["Low health flash"], "lowHealthFlash", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Pulse a red screen edge at low health."] },
	{
		path = "threshold",
		label = L["Health threshold"],
		type = "number",
		min = 0.05,
		max = 0.9,
		step = 0.01,
		percent = true,
		desc = L["Fraction of maximum health below which the flash shows."],
	},
	{
		path = "pulseSpeed",
		label = L["Pulse speed"],
		type = "number",
		min = 0.2,
		max = 5,
		step = 0.1,
		advanced = true,
		desc = L["Higher pulses faster; 1 fades fully in and out in two seconds."],
	},
}, nil, nil, "heart-crack")

Section(schema, L["Cursor trail"], "cursorTrail", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Lightning trail following the mouse cursor."],
	},
	{
		path = "scale",
		label = L["Scale"],
		type = "number",
		min = 0.5,
		max = 2,
		step = 0.1,
		percent = true,
		desc = L["Size of the lightning trail and the glow at the cursor tip."],
	},
	{
		path = "trailAlpha",
		label = L["Trail alpha"],
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		percent = true,
		advanced = true,
		desc = L["Lightning bolt trailing behind the cursor."],
	},
	{
		path = "shineAlpha",
		label = L["Shine alpha"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		percent = true,
		advanced = true,
		desc = L["Glow at the cursor tip."],
	},
	{ path = "hideInCombat", label = L["Hide in combat"], type = "toggle" },
}, nil, nil, "arrow-pointer")

for _, element in ipairs({
	{ "blizzardFrames.captureBarPoint", L["Capture bars"], "flag" },
	{ "blizzardFrames.vehicleSeatPoint", L["Vehicle seats"], "car-side" },
	{ "blizzardFrames.errorsPoint", L["Error messages"], "circle-exclamation" },
	{ "blizzardFrames.raidWarningPoint", L["Raid warnings"], "bullhorn" },
}) do
	ns.RegisterElement({
		path = element[1],
		page = "hud",
		name = element[2],
		glyph = element[3],
		enabledBy = "blizzardFrames.enabled",
	})
end

Section(schema, L["Blizzard frames"], "blizzardFrames", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Movable capture bars, vehicle seats, error messages and raid warnings; quest tracker hiding."],
	},
	{
		path = "questTracker",
		label = L["Hide quest tracker"],
		type = "multiselect",
		values = {
			{ "arena", L["Arena"] },
			{ "battleground", L["Battleground"] },
			{ "combat", L["In combat"] },
		},
		desc = L["The quest tracker comes back when you leave the arena or battleground and when combat ends."],
	},
}, nil, "1.4.0", "window-maximize")

ns.RegisterPage({
	key = "hud",
	name = L["HUD"],
	glyph = "gauge",
	order = 40,
	group = "interface",
	schema = schema,
})
