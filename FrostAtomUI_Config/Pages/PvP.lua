local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section
local Requires = ns.Requires

local LOSS_OF_CONTROL = "lossOfControl.enabled"
local EXTERNALS = "externalDefensives.enabled"

local function testModeToggle(moduleName)
	return function()
		local module = FrostAtomUI:GetModule(moduleName)
		module:SetTestMode(not module:IsTesting())
	end
end

ns.RegisterElement({
	path = "lossOfControl.point",
	page = "pvp",
	name = L["Loss of control"],
	glyph = "lock",
	enabledBy = LOSS_OF_CONTROL,
	schema = Requires(LOSS_OF_CONTROL, {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "lossOfControl.scale",
			label = L["Scale"],
			type = "number",
			min = 0.5,
			max = 2,
			step = 0.05,
			percent = true,
			desc = L["Size of the alert icon and text."],
		},
		{ header = L["Display"], glyph = "bars-staggered" },
		{
			path = "lossOfControl.background",
			new = "1.4.0",
			label = L["Background"],
			type = "toggle",
			advanced = true,
			desc = L["Dark backdrop and red lines around the icon and text."],
		},
		{ header = L["Test"], glyph = "flask" },
		{
			label = L["Test"],
			type = "execute",
			text = L["Toggle"],
			glyph = "flask",
			enabledBy = LOSS_OF_CONTROL,
			desc = L["Cycle through fake effects to preview the alert. /uftest toggles it too."],
			func = testModeToggle("LossOfControl"),
		},
	}),
})

ns.RegisterElement({
	path = "externalDefensives.point",
	page = "pvp",
	name = L["External defensives"],
	glyph = "shield-heart",
	enabledBy = EXTERNALS,
	schema = Requires(EXTERNALS, {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "externalDefensives.size",
			label = L["Icon size"],
			type = "number",
			min = 16,
			max = 64,
			step = 1,
		},
		{
			path = "externalDefensives.gap",
			label = L["Spacing"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			advanced = true,
		},
		{
			path = "externalDefensives.maxIcons",
			new = "1.4.0",
			label = L["Maximum icons"],
			type = "number",
			min = 1,
			max = 6,
			step = 1,
			advanced = true,
			desc = L["Buffs past this count are not shown; the longest remaining come first."],
		},
		{ header = L["Test"], glyph = "flask" },
		{
			label = L["Test"],
			type = "execute",
			text = L["Toggle"],
			glyph = "flask",
			enabledBy = EXTERNALS,
			desc = L["Show fake buffs to preview the layout. /uftest toggles it too."],
			func = testModeToggle("ExternalDefensives"),
		},
	}),
})

ns.RegisterElement({
	path = "deathRecap.point",
	page = "pvp",
	name = L["Death recap"],
	glyph = "skull",
	enabledBy = "deathRecap.enabled",
	schema = {},
})

ns.RegisterElement({
	path = "soloQueue.point",
	page = "pvp",
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

local schema = {
	{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
	{ type = "elements" },
}

Section(schema, L["Loss of control"], "lossOfControl", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Large alert in the middle of the screen while you are stunned, feared, silenced, disarmed or rooted."],
	},
	{
		path = "categories",
		new = "1.4.0",
		label = L["Also alert on"],
		type = "multiselect",
		values = { { "silence", L["Silences"] }, { "disarm", L["Disarms"] }, { "root", L["Roots"] } },
		desc = L["Stuns, fears, polymorphs and other full loss of control effects always show."],
	},
	{
		path = "lockouts",
		label = L["Spell school lockouts"],
		type = "toggle",
		advanced = true,
		desc = L["Also show the locked spell school and the time left when an enemy interrupts your cast."],
	},
	{
		path = "sound",
		label = L["Play sound"],
		type = "toggle",
		desc = L["Play a warning sound when a new effect starts."],
	},
}, nil, "1.4.0", "lock")

Section(schema, L["External defensives"], "externalDefensives", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Row of defensive buffs other players cast on you, such as Pain Suppression, Guardian Spirit and Hand spells, longest remaining first."],
	},
}, nil, "1.4.0", "shield-heart")

local SOUND_VALUES = {
	{ "RaidWarning", L["Raid warning"] },
	{ "RaidBossEmoteWarning", L["Boss emote"] },
	{ "ReadyCheck", L["Ready check"] },
	{ "TellMessage", L["Whisper"] },
	{ "MapPing", L["Map ping"] },
	{ "AlarmClockWarning2", L["Alarm clock"] },
	{ "AlarmClockWarning3", L["Alarm clock (loud)"] },
	{ "LFG_RoleCheck", L["Role check"] },
	{ "PVPENTERQUEUE", L["Queue joined"] },
	{ "igCreatureAggroSelect", L["Aggro click"] },
	{ "LOOTWINDOWCOINSOUND", L["Coins"] },
	{ "WriteQuest", L["Quest update"] },
}

local function soundSelect(path, label, enabledBy)
	return {
		path = path,
		label = label,
		type = "select",
		values = SOUND_VALUES,
		preview = "sound",
		advanced = true,
		enabledBy = enabledBy,
	}
end

local cannotDispel = not FrostAtomUI:GetModule("UnitFrames").canDispel

Section(schema, L["Sound alerts"], "soundAlerts", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Short sounds for important combat events. Play even with sound effects turned off."],
	},
	{
		path = "throttle",
		label = L["Minimum interval"],
		type = "number",
		min = 0,
		max = 5,
		step = 0.1,
		unit = "s",
		zeroText = L["Off"],
		advanced = true,
		desc = L["Shared by all alerts: no sound plays sooner than this after the previous one."],
	},
	{
		path = "targeted",
		label = L["Targeted by an enemy player"],
		type = "toggle",
		desc = L["When an arena opponent, or your hostile target or focus, switches its target to you. Each enemy is announced again only after it drops you."],
	},
	{
		path = "targetedArenaOnly",
		label = L["Only in arena"],
		type = "toggle",
		advanced = true,
		enabledBy = "soundAlerts.targeted",
		desc = L["Stay silent when targeted outside arenas."],
	},
	{
		path = "targetedText",
		label = L["Show the enemy's name"],
		type = "toggle",
		advanced = true,
		enabledBy = "soundAlerts.targeted",
		desc = L['Class colored "Targeted by" message in the error text area at the top of the screen.'],
	},
	soundSelect("targetedSound", L["Targeted sound"], "soundAlerts.targeted"),
}, nil, "1.4.0", "volume-high")

Section(schema, L["Interrupt sounds"], "soundAlerts", {
	{
		path = "interruptible",
		label = L["Interruptible cast on target"],
		type = "toggle",
		desc = L["When a hostile target starts a cast or channel that can be interrupted."],
	},
	{
		path = "interruptibleFocus",
		label = L["Also on focus"],
		type = "toggle",
		advanced = true,
		enabledBy = "soundAlerts.interruptible",
		desc = L["Also alert on interruptible casts of a hostile focus."],
	},
	soundSelect("interruptibleSound", L["Interruptible cast sound"], "soundAlerts.interruptible"),
	{
		path = "interruptSuccess",
		label = L["Your interrupt succeeded"],
		type = "toggle",
		desc = L["When you or your pet interrupt a cast."],
	},
	soundSelect("interruptSuccessSound", L["Interrupt sound"], "soundAlerts.interruptSuccess"),
}, nil, nil, "hand")

Section(schema, L["Dispel sounds"], "soundAlerts", {
	{
		path = "dispellable",
		label = L["Dispellable debuff on you"],
		type = "toggle",
		desc = L["When a new debuff lands on you that your class can remove."],
	},
	{
		path = "dispellableMinDuration",
		label = L["Minimum debuff duration"],
		type = "number",
		min = 0,
		max = 30,
		step = 1,
		unit = "s",
		zeroText = L["Off"],
		advanced = true,
		enabledBy = "soundAlerts.dispellable",
		desc = L["Shorter debuffs are ignored."],
	},
	soundSelect("dispellableSound", L["Dispellable debuff sound"], "soundAlerts.dispellable"),
}, cannotDispel, nil, "wand-magic-sparkles")

Section(schema, L["Queue invite"], "queueInvite", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Helpers for a pending arena or battleground invite."],
	},
	{
		path = "style",
		new = "1.4.1",
		label = L["Styled invite dialog"],
		type = "toggle",
		desc = L["Arena art, a large match title and a countdown bar in the Enter Battle dialog."],
	},
	{
		path = "sound",
		label = L["Invite sound"],
		type = "toggle",
		desc = L["Play the invite sound on the Master channel, so it is heard with sound effects muted."],
	},
}, nil, "1.4.0", "bell")

for _, entry in ipairs({
	{
		path = "queuePopFlash.enabled",
		label = L["Screen flash"],
		type = "toggle",
		desc = L["Flash the whole screen when an arena, battleground or dungeon invite appears."],
	},
	{
		path = "queuePopFlash.intensity",
		label = L["Flash alpha"],
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		percent = true,
		advanced = true,
		enabledBy = "queuePopFlash.enabled",
		desc = L["Peak opacity of the flash; it ramps up to this over the first 15 seconds."],
	},
	{
		path = "queuePopFlash.color",
		label = L["Flash color"],
		type = "color",
		advanced = true,
		enabledBy = "queuePopFlash.enabled",
	},
}) do
	ns.AddRequirement(entry, "queueInvite.enabled")
	schema[#schema + 1] = entry
end

Section(schema, L["Solo queue"], "soloQueue", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Join, leave and enter the solo queue from a button next to the queue eye."],
	},
}, not FrostAtomUI.IS_WOWCIRCLE, nil, "user-clock")

Section(schema, L["Battleground"], "battleground", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Battleground helpers."] },
	{
		path = "raidWarnings",
		label = L["System messages as raid warnings"],
		type = "toggle",
		desc = L["Show battleground and arena system messages in the raid warning frame."],
	},
	{
		path = "closeWarnings",
		new = "1.4.0",
		label = L["Closing warnings"],
		type = "toggle",
		desc = L["After the match ends, warn in the middle of the screen 10 and 5 minutes, 60 and 15 seconds before the instance closes."],
	},
}, nil, nil, "flag")

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
		path = "chatLink",
		label = L["Chat link on death"],
		type = "toggle",
		advanced = true,
		desc = L["Print a clickable link to the recap when you die."],
	},
	{
		path = "arenaDeaths",
		new = "1.4.1",
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
			SlashCmdList.FROSTATOMUI_DEATH_RECAP()
		end,
	},
}, nil, "1.4.0", "skull")

ns.RegisterPage({
	key = "pvp",
	name = L["PvP"],
	glyph = "hand-fist",
	order = 36,
	group = "pvp",
	schema = schema,
})
