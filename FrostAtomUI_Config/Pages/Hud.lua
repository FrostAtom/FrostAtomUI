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
		{ header = L["Test"], glyph = "flask" },
		{
			label = L["Test"],
			type = "execute",
			text = L["Show"],
			glyph = "flask",
			desc = L["Show the enter combat message once."],
			func = function()
				FrostAtomUI.API.RunAction("combatAlertTest")
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
			label = L["Background opacity"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			percent = true,
		},
	},
})

ns.RegisterElement({
	path = "deathRecap.point",
	page = "hud",
	name = L["Death recap"],
	glyph = "skull",
	enabledBy = "deathRecap.enabled",
	schema = {},
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
}, nil, nil, "gauge-high")

tinsert(schema, {
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
		label = L["Trail opacity"],
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
		label = L["Shine opacity"],
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

schema[#schema + 1] = { header = L["Error messages"], glyph = "triangle-exclamation" }
for _, entry in ipairs({
	{
		path = "errorMessages",
		label = L["Red error messages"],
		type = "select",
		values = {
			{ "all", L["All"] },
			{
				"filtered",
				L["No spam"],
				L['Hides "not ready yet", "another action is in progress" and "not enough mana / rage / energy". "Out of range", "not in line of sight" and "facing" stay visible.'],
			},
			{ "hidden", L["Hide all"] },
		},
		desc = L['"Not enough mana", "Out of range" and similar messages at the top of the screen.'],
	},
}) do
	entry.path = "tweaks." .. entry.path
	schema[#schema + 1] = entry
end

ns.RegisterElement({
	path = "blizzardFrames.errorsPoint",
	page = "hud",
	name = L["Error messages"],
	glyph = "circle-exclamation",
	enabledBy = "blizzardFrames.enabled",
})

Section(schema, L["Death recap"], "deathRecap", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Record the damage you take and list the last hits before your death. Open with /recap."],
	},
	{
		path = "entries",
		label = L["Hits shown"],
		type = "number",
		min = 1,
		max = 10,
		step = 1,
		advanced = true,
		desc = L["Hits visible in the recap window at once, scroll to see the rest of the final 10 seconds."],
	},
	{
		path = "heals",
		label = L["Incoming heals"],
		type = "toggle",
		advanced = true,
		desc = L["Also list the heals you received, with the healed amount without overhealing, in green."],
	},
	{
		path = "control",
		label = L["Crowd control"],
		type = "toggle",
		advanced = true,
		desc = L["Also list the crowd control put on you, so the chain before the death is visible."],
	},
	{
		path = "chatLink",
		label = L["Chat link on death"],
		type = "toggle",
		advanced = true,
		desc = L["Print a clickable link to the recap when you die."],
	},
	{
		path = "arenaDeaths",
		new = "1.5.0",
		label = L["Every death in arena"],
		type = "toggle",
		desc = L["Record the damage taken by every player in an arena and print a link to the recap when anyone dies."],
	},
	{
		path = "autoOpen",
		label = L["Open in arenas and battlegrounds"],
		type = "toggle",
		advanced = true,
		desc = L["Show the recap window right away when you die in PvP."],
	},
	{
		label = L["Recap window"],
		type = "execute",
		text = L["Open"],
		glyph = "up-right-from-square",
		func = function()
			FrostAtomUI.API.RunAction("deathRecap")
		end,
	},
}, nil, "1.4.0", "skull")

ns.RegisterPage({
	key = "hud",
	name = L["HUD"],
	desc = L["Combat alert, FPS and latency, experience bar, error messages and the death recap."],
	glyph = "gauge",
	order = 40,
	group = "interface",
	schema = schema,
})
