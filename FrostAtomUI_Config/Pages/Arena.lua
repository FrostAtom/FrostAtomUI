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
		{ path = "arena.countdownFont", label = L["Countdown font"], type = "font", advanced = true },
		{ header = L["Colors"], glyph = "palette" },
		{ path = "arena.countdownColor", label = L["Countdown color"], type = "color", advanced = true },
		{
			path = "arena.countdownUrgentColor",
			label = L["Countdown final seconds color"],
			type = "color",
			advanced = true,
			desc = L["Used for the last 3 seconds."],
		},
	}),
})

ns.RegisterElement({
	path = "diminishingReturns.playerPoint",
	page = "arena",
	name = L["Player diminishing returns"],
	glyph = "arrow-trend-down",
	enabledBy = { "unitFrames.enabled", "diminishingReturns.enabled", "diminishingReturns.player" },
	schema = {},
})

ns.RegisterElement({
	path = "internalCooldowns.playerPoint",
	page = "arena",
	name = L["Player internal cooldowns"],
	glyph = "gem",
	enabledBy = {
		"unitFrames.enabled",
		"internalCooldowns.enabled",
		"internalCooldowns.player",
		"internalCooldowns.playerDetached",
	},
	schema = {},
})

ns.RegisterElement({
	path = "matchResults.point",
	page = "arena",
	name = L["Match results"],
	glyph = "ranking-star",
	enabledBy = "matchResults.enabled",
	schema = {},
})

ns.RegisterElement({
	path = "soloQueue.point",
	page = "arena",
	name = L["Solo queue"],
	glyph = "user-clock",
	enabledBy = "soloQueue.enabled",
	hidden = not FrostAtomUI.IS_WOWCIRCLE,
	schema = Requires("soloQueue.enabled", {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "soloQueue.buttonSize",
			label = L["Button size"],
			type = "number",
			min = 12,
			max = 40,
			step = 1,
		},
		{
			path = "soloQueue.queuedSize",
			label = L["Button size in queue"],
			type = "number",
			min = 12,
			max = 60,
			step = 1,
			advanced = true,
			desc = L["Button size while waiting in the queue or ready to enter."],
		},
		{ header = L["Display"], glyph = "bars-staggered" },
		{
			path = "soloQueue.mouseover",
			new = "1.4.0",
			label = L["Show on mouseover"],
			type = "toggle",
			desc = L["Hide the button until the cursor is over it. It stays visible in the queue, after the arena match ends and once an ally dies or leaves."],
		},
	}),
})

ns.RegisterElement({
	path = "arena.pillarsPoint",
	page = "arena",
	name = L["Ring of Valor pillars"],
	glyph = "stopwatch",
	new = "1.5.0",
	enabledBy = { "arena.enabled", "arena.pillars" },
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
			FrostAtomUI.API.RunAction("unitFrameTest")
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
		desc = L["Timer for the last 30 seconds before the gates open, set to 15 seconds by the server's 15 seconds message."],
	},
	{
		label = L["Preview countdown"],
		type = "execute",
		text = L["Test"],
		glyph = "flask",
		enabledBy = "arena.countdown",
		func = function()
			FrostAtomUI.API.RunAction("arenaCountdownTest")
		end,
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
		advanced = true,
		enabledBy = "arena.pillars",
	},
	{
		path = "pillarsFirstToggle",
		label = L["First pillar toggle"],
		type = "number",
		min = 10,
		max = 120,
		step = 1,
		unit = "s",
		advanced = true,
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
		unit = "s",
		advanced = true,
		enabledBy = "arena.pillars",
		desc = L["Seconds between pillar toggles after the first one. Depends on the server."],
	},
}, nil, nil, "hand-fist")

local DR_ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local DR_GROWTH = {
	{ "RIGHT", L["To the right"], glyph = "arrow-right" },
	{ "LEFT", L["To the left"], glyph = "arrow-left" },
	{ "UP", L["Up"], glyph = "arrow-up" },
	{ "DOWN", L["Down"], glyph = "arrow-down" },
}

local DR_TARGET_OR_FOCUS = { "diminishingReturns.target", "diminishingReturns.focus" }

local function drAnchor(prefix, label, desc, enabledBy, enabledByAny)
	return {
		path = prefix .. "Anchor",
		new = "1.5.0",
		label = label,
		type = "anchor",
		points = DR_ANCHORS,
		enabledBy = enabledBy,
		enabledByAny = enabledByAny,
		desc = desc,
	}
end

local function drGrowth(prefix, label, enabledBy, enabledByAny)
	return {
		path = prefix .. "Growth",
		new = "1.5.0",
		label = label,
		type = "select",
		values = DR_GROWTH,
		advanced = true,
		enabledBy = enabledBy,
		enabledByAny = enabledByAny,
	}
end

local function offset(path, label, enabledBy, enabledByAny)
	return {
		path = path .. "X",
		pathY = path .. "Y",
		label = label,
		type = "offset",
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
		desc = L["Crowd control categories recently used on enemy players and on you, with the time until they reset. Border color shows the next duration: green half, orange quarter, red immune."],
	},
	{
		path = "categories",
		new = "1.5.0",
		label = L["Categories"],
		type = "multiselect",
		values = {
			{ "stuns", L["Stuns"] },
			{
				"incapacitates",
				L["Incapacitates"],
				L["Also sleeps, Cyclone, Banish, Scatter Shot and Dragon's Breath."],
			},
			{ "fears", L["Fears"], L["Also horrors and Mind Control."] },
			{ "silences", L["Silences"] },
			{ "disarms", L["Disarms"] },
			{ "roots", L["Roots"] },
		},
		desc = L["Control types shown on the frames. Icons always go in the same order: stuns, incapacitates, fears, silences, disarms, roots."],
	},
	{
		path = "severityText",
		new = "1.5.0",
		label = L["Next duration as text"],
		type = "toggle",
		advanced = true,
		desc = L["½ or ¼ in the corner of the icon: how long the next control of this type lasts. Immune is the red cross."],
	},
	{ path = "halfColor", label = L["Next: 50% duration"], type = "color", advanced = true },
	{ path = "quarterColor", label = L["Next: 25% duration"], type = "color", advanced = true },
	{ path = "immuneColor", label = L["Next: immune"], type = "color", advanced = true },
	ns.ClickThrough("clickThrough"),
}, nil, "1.4.0", "arrow-trend-down")

tinsert(schema, #schema - 3, {
	path = "diminishingReturns",
	label = L["Show on"],
	type = "multiselect",
	values = {
		{ "player", L["Player"] },
		{ "arena", L["Arena"] },
		{ "party", L["Party"], L["Control on your teammates, for example a fear on your healer."] },
		{ "target", L["Target"] },
		{ "focus", L["Focus"] },
	},
	enabledBy = "diminishingReturns.enabled",
	desc = L["Where the diminishing returns icons are shown. Your own are a separate block in the middle of the screen, moved with the other frames."],
})

Section(schema, L["Diminishing returns layout"], "diminishingReturns", {
	{
		path = "playerSize",
		label = L["Player icon size"],
		type = "number",
		min = 12,
		max = 64,
		step = 1,
		enabledBy = "diminishingReturns.player",
	},
	{
		path = "arenaSize",
		label = L["Arena icon size"],
		type = "number",
		min = 12,
		max = 64,
		step = 1,
		enabledBy = "diminishingReturns.arena",
	},
	{
		path = "size",
		advanced = true,
		label = L["Target / focus icon size"],
		type = "number",
		min = 12,
		max = 48,
		step = 1,
		enabledByAny = DR_TARGET_OR_FOCUS,
	},
	{ path = "spacing", label = L["Spacing"], type = "number", min = 0, max = 10, step = 1, advanced = true },
	drAnchor(
		"arena",
		L["Point at arena frames"],
		L["Point of the arena frame the icons are attached to. On the right they go after the trinket and pets, on the left before an attached castbar."],
		"diminishingReturns.arena"
	),
	drGrowth("arena", L["Arena growth direction"], "diminishingReturns.arena"),
	offset("arenaOffset", L["Arena offset"], "diminishingReturns.arena"),
	drAnchor(
		"party",
		L["Point at party frames"],
		L["Point of the party frame the icons are attached to. On the right they go after pets and targets of the party."],
		"diminishingReturns.party"
	),
	drGrowth("party", L["Party growth direction"], "diminishingReturns.party"),
	offset("partyOffset", L["Party offset"], "diminishingReturns.party"),
	drAnchor(
		"target",
		L["Point at target / focus"],
		L["Point of the target and focus frames the icons are attached to. Above or below the frame they go past a castbar attached on that side."],
		nil,
		DR_TARGET_OR_FOCUS
	),
	drGrowth("target", L["Target / focus growth direction"], nil, DR_TARGET_OR_FOCUS),
	offset("targetOffset", L["Target / focus offset"], nil, DR_TARGET_OR_FOCUS),
}, nil, nil, "up-down-left-right")

Section(schema, L["Internal cooldowns"], "internalCooldowns", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Internal cooldowns of proc trinkets, enchants and gems. Your own and inspected allies' items show right away, enemy trinkets show as question marks until their first proc and are remembered."],
	},
	{
		path = "hideReady",
		label = L["Only while on cooldown"],
		type = "toggle",
		advanced = true,
		desc = L["Hide icons of procs that are ready."],
	},
	{
		path = "unknownTrinkets",
		label = L["Unknown enemy trinkets"],
		type = "toggle",
		advanced = true,
		enabledBy = "internalCooldowns.slots.trinket",
		desc = L["Question mark icons for enemy trinkets that have not proced yet."],
	},
	{
		path = "activeColor",
		label = L["Active buff color"],
		type = "color",
		advanced = true,
		desc = L["Border and glow while the proc buff is up. The timer shows the buff time left, then the internal cooldown."],
	},
	ns.ClickThrough("clickThrough"),
}, nil, "1.4.0", "gem")

tinsert(schema, #schema - 3, {
	path = "internalCooldowns",
	label = L["Show on"],
	type = "multiselect",
	values = {
		{ "player", L["Player"] },
		{ "party", L["Party"] },
		{ "arena", L["Arena"] },
		{ "party", L["Party"], L["Control on your teammates, for example a fear on your healer."] },
		{ "target", L["Target"] },
		{ "focus", L["Focus"] },
	},
	enabledBy = "internalCooldowns.enabled",
	desc = L["Unit frames that show the internal cooldown icons."],
})

tinsert(schema, #schema - 3, {
	path = "internalCooldowns.slots",
	new = "1.5.0",
	label = L["Sources"],
	type = "multiselect",
	values = {
		{ "trinket", L["Trinkets"] },
		{ "ring", L["Rings"] },
		{ "weapon", L["Weapons and relics"] },
		{ "armor", L["Other items"] },
		{ "enchant", L["Enchants"] },
		{ "gem", L["Gems"] },
		{ "set", L["Set bonuses"] },
		{ "talent", L["Talents"] },
	},
	enabledBy = "internalCooldowns.enabled",
	desc = L["Which procs get an icon. Enchants are weapon enchants and cloak embroideries, gems are meta gems."],
})

Section(schema, L["Internal cooldowns layout"], "internalCooldowns", {
	{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 48, step = 1 },
	{ path = "spacing", label = L["Spacing"], type = "number", min = 0, max = 10, step = 1, advanced = true },
	offset("offset", L["Offset from the top right corner"]),
	{
		path = "playerDetached",
		new = "1.5.0",
		label = L["Player icons separately"],
		type = "toggle",
		enabledBy = "internalCooldowns.player",
		desc = L["Your own icons are a separate larger block above the action bars instead of above the player frame, moved with the other frames."],
	},
	{
		path = "playerSize",
		advanced = true,
		new = "1.5.0",
		label = L["Player icon size"],
		type = "number",
		min = 12,
		max = 64,
		step = 1,
		enabledBy = { "internalCooldowns.player", "internalCooldowns.playerDetached" },
	},
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
		advanced = true,
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
		advanced = true,
		desc = L["Oldest games are dropped past this count."],
	},
	{
		label = L["History window"],
		type = "execute",
		text = L["Open"],
		glyph = "up-right-from-square",
		func = function()
			FrostAtomUI.API.RunAction("arenaHistory")
		end,
	},
}, nil, nil, "clock-rotate-left")

Section(schema, L["Solo queue"], "soloQueue", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Join, leave and enter the solo queue from a button next to the queue eye."],
	},
}, not FrostAtomUI.IS_WOWCIRCLE, nil, "user-clock")

schema[#schema + 1] = { header = L["Everything for arena"], glyph = "list-check" }
schema[#schema + 1] = {
	description = L["The arena settings from other pages in one place, with their current values."],
}
for _, alias in ipairs({
	{ "diminishingReturns", L["Diminishing returns on"] },
	{ "groupCooldowns.enemySeparateTrinket" },
	{ "loseControl.enabled", L["CC on frames"] },
	{ "unitFrames.arenaDebuffFilter", L["Arena debuffs to show"] },
	{ "castbar.important" },
	{ "namePlates.totemFilter" },
	{ "namePlates.showHealers", L["Enemy healer mark"] },
	{ "spellAlerts.enabled", L["Voice alerts"] },
	{ "soundAlerts.targeted" },
}) do
	schema[#schema + 1] = { alias = alias[1], label = alias[2] }
end

ns.RegisterPage({
	key = "arena",
	name = L["Arena"],
	desc = L["Everything for arenas: enemy trinkets and crowd control, countdown, match results."],
	glyph = "trophy",
	order = 30,
	group = "pvp",
	schema = schema,
})
