local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section
local Requires = ns.Requires

local COUNTDOWN = { "arena.enabled", "arena.countdown" }

ns.RegisterElement({
	path = "arena.countdownPoint",
	page = "arena",
	name = L["Arena countdown"],
	glyph = "stopwatch",
	enabledBy = COUNTDOWN,
	schema = Requires(COUNTDOWN, {
		{ header = L["Text"], glyph = "font" },
		{ path = "arena.countdownFont", label = L["Countdown font"], type = "font" },
		{ header = L["Colors"], glyph = "palette" },
		{ path = "arena.countdownColor", label = L["Countdown color"], type = "color" },
		{
			path = "arena.countdownUrgentColor",
			label = L["Countdown final seconds color"],
			type = "color",
			advanced = true,
			desc = L["Used for the last 3 seconds, when tenths are shown."],
		},
	}),
})

ns.RegisterElement({
	path = "matchResults.point",
	page = "arena",
	name = L["Match results"],
	glyph = "ranking-star",
	enabledBy = "matchResults.enabled",
	schema = {},
})

local schema = {
	{
		label = L["Test frames"],
		type = "execute",
		text = L["Toggle"],
		glyph = "flask",
		enabledBy = "unitFrames.enabled",
		desc = L["Show every frame with fake units to preview the layout."],
		func = function()
			SlashCmdList.FROSTATOMUI_UNITFRAME_TEST()
		end,
	},
	{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
	{ type = "elements" },
}

Section(schema, L["Arena"], "arena", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Arena start countdown and pillar timer."] },
	{
		path = "countdown",
		label = L["Start countdown"],
		type = "toggle",
		desc = L["Large timer for the last 15 seconds before the gates open."],
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
		label = L["First pillar toggle"],
		type = "number",
		min = 10,
		max = 120,
		step = 1,
		enabledBy = "arena.pillars",
		desc = L["Seconds after the gates open until the pillars move for the first time. Depends on the server."],
	},
	{
		path = "pillarsPeriod",
		label = L["Pillar toggle period"],
		type = "number",
		min = 5,
		max = 120,
		step = 1,
		enabledBy = "arena.pillars",
		desc = L["Seconds between pillar toggles after the first one. Depends on the server."],
	},
}, nil, nil, "hand-fist")

local DR_ARENA_SIDES = {
	{ "RIGHT", L["Right of the trinket"] },
	{ "LEFT", L["Left of the castbar"] },
	{ "TOP", L["Above the frame"] },
	{ "BOTTOM", L["Below the frame"] },
}

local DR_TARGET_SIDES = {
	{ "RIGHT", L["Right of the frame"] },
	{ "LEFT", L["Left of the frame"] },
	{ "TOP", L["Above the frame"] },
	{ "BOTTOM", L["Below the frame"] },
}

local DR_TARGET_OR_FOCUS = { "diminishingReturns.target", "diminishingReturns.focus" }

local function offset(path, label, enabledBy, enabledByAny)
	return {
		path = path,
		label = label,
		type = "number",
		min = -200,
		max = 200,
		step = 1,
		advanced = true,
		enabledBy = enabledBy,
		enabledByAny = enabledByAny,
	}
end

Section(schema, L["Diminishing returns"], "diminishingReturns", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Crowd control categories recently used on enemy players, with the time until they reset. Border color shows the next duration: green half, orange quarter, red immune."],
	},
	{ path = "halfColor", label = L["Next: 50% duration"], type = "color" },
	{ path = "quarterColor", label = L["Next: 25% duration"], type = "color" },
	{ path = "immuneColor", label = L["Next: immune"], type = "color" },
}, nil, "1.4.0", "arrow-trend-down")

tinsert(schema, #schema - 2, {
	path = "diminishingReturns",
	label = L["Show on"],
	type = "multiselect",
	values = { { "arena", L["Arena"] }, { "target", L["Target"] }, { "focus", L["Focus"] } },
	enabledBy = "diminishingReturns.enabled",
	desc = L["Unit frames that show the diminishing returns icons."],
})

Section(schema, L["Diminishing returns layout"], "diminishingReturns", {
	{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 48, step = 1 },
	{ path = "spacing", label = L["Spacing"], type = "number", min = 0, max = 10, step = 1 },
	{
		path = "arenaSide",
		label = L["Arena position"],
		type = "select",
		values = DR_ARENA_SIDES,
		enabledBy = "diminishingReturns.arena",
	},
	offset("arenaOffsetX", L["Arena X offset"], "diminishingReturns.arena"),
	offset("arenaOffsetY", L["Arena Y offset"], "diminishingReturns.arena"),
	{
		path = "targetSide",
		label = L["Target / focus position"],
		type = "select",
		values = DR_TARGET_SIDES,
		enabledByAny = DR_TARGET_OR_FOCUS,
	},
	offset("targetOffsetX", L["Target / focus X offset"], nil, DR_TARGET_OR_FOCUS),
	offset("targetOffsetY", L["Target / focus Y offset"], nil, DR_TARGET_OR_FOCUS),
}, nil, nil, "up-down-left-right")

Section(schema, L["Internal cooldowns"], "internalCooldowns", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Internal cooldowns of proc trinkets, enchants and gems. Your own and inspected allies' items show right away, enemy trinkets show as question marks until their first proc and are remembered."],
	},
	{ path = "player", label = L["Show on player frame"], type = "toggle" },
	{ path = "party", label = L["Show on party frames"], type = "toggle" },
	{ path = "arena", label = L["Show on arena frames"], type = "toggle" },
	{ path = "target", label = L["Show on target frame"], type = "toggle" },
	{ path = "focus", label = L["Show on focus frame"], type = "toggle" },
	{
		path = "hideReady",
		label = L["Only while on cooldown"],
		type = "toggle",
		desc = L["Hide icons of procs that are ready."],
	},
	{
		path = "unknownTrinkets",
		label = L["Unknown enemy trinkets"],
		type = "toggle",
		desc = L["Question mark icons for enemy trinkets that have not proced yet."],
	},
	{
		path = "activeColor",
		label = L["Active buff color"],
		type = "color",
		desc = L["Border and glow while the proc buff is up. The timer shows the buff time left, then the internal cooldown."],
	},
}, nil, "1.4.0", "gem")

tinsert(schema, #schema, {
	path = "unitFrames.cooldownReadyFlash",
	label = L["Cooldown ready flash"],
	type = "toggle",
	enabledBy = { "internalCooldowns.enabled", "unitFrames.enabled" },
	desc = L["Short bright flash on a tracked cooldown icon as the ability becomes ready."],
})

Section(schema, L["Internal cooldowns layout"], "internalCooldowns", {
	{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 48, step = 1 },
	{ path = "spacing", label = L["Spacing"], type = "number", min = 0, max = 10, step = 1 },
	offset("offsetX", L["X offset from the top right corner"]),
	offset("offsetY", L["Y offset from the top right corner"]),
}, nil, nil, "up-down-left-right")

Section(schema, L["Match results"], "matchResults", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Result window with teams, rating change and a sortable scoreboard when an arena or battleground ends."],
	},
	{
		path = "battlegrounds",
		new = "1.4.0",
		label = L["Show after battlegrounds"],
		type = "toggle",
		desc = L["When off, the window opens only after arena matches."],
	},
	{
		path = "replaceScoreboard",
		label = L["Hide Blizzard scoreboard"],
		type = "toggle",
		desc = L["Keep the Blizzard scoreboard closed while the result window is open. The Scoreboard button still opens it."],
	},
}, nil, "1.4.0", "ranking-star")

Section(schema, L["Arena history"], "arenaHistory", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Save arena scoreboards. Open with /history."],
	},
	{
		path = "maxGames",
		label = L["Games to keep"],
		type = "number",
		min = 50,
		max = 5000,
		step = 50,
		desc = L["Oldest games are dropped past this count."],
	},
	{
		path = "winColor",
		label = L["Win color"],
		type = "color",
		desc = L["Result text of won games in the history window."],
	},
	{
		path = "lossColor",
		label = L["Loss color"],
		type = "color",
		desc = L["Result text of lost games in the history window."],
	},
	{
		label = L["History window"],
		type = "execute",
		text = L["Open"],
		glyph = "up-right-from-square",
		func = function()
			SlashCmdList.FROSTATOMUI_ARENA_HISTORY()
		end,
	},
}, nil, nil, "clock-rotate-left")

ns.RegisterPage({
	key = "arena",
	name = L["Arena"],
	glyph = "trophy",
	order = 30,
	group = "pvp",
	schema = schema,
})
