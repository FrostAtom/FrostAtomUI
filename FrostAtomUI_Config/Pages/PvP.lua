local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section
local Requires = ns.Requires

local LOSS_OF_CONTROL = "lossOfControl.enabled"
local EXTERNALS = "externalDefensives.enabled"

local function toggleTestMode(moduleName)
	return function()
		local module = FrostAtomUI:GetModule(moduleName)
		module:SetTestMode(not module:IsTesting())
	end
end

ns.RegisterElement({
	path = "lossOfControl.point",
	page = "pvp",
	name = L["Loss of control"],
	enabledBy = LOSS_OF_CONTROL,
	schema = Requires(LOSS_OF_CONTROL, {
		{ header = L["Size"] },
		{
			path = "lossOfControl.scale",
			label = L["Scale"],
			type = "number",
			min = 0.5,
			max = 2,
			step = 0.05,
		},
		{ header = L["Visibility"] },
		{
			path = "lossOfControl.background",
			new = "1.4.0",
			label = L["Show background"],
			type = "toggle",
			desc = L["Dark backdrop and red lines around the icon and text."],
		},
		{
			label = L["Test"],
			type = "execute",
			text = L["Toggle"],
			enabledBy = LOSS_OF_CONTROL,
			desc = L["Cycle through fake effects to preview the alert. /uftest toggles it too."],
			func = toggleTestMode("LossOfControl"),
		},
	}),
})

ns.RegisterElement({
	path = "externalDefensives.point",
	page = "pvp",
	name = L["External defensives"],
	enabledBy = EXTERNALS,
	schema = Requires(EXTERNALS, {
		{ header = L["Size"] },
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
		},
		{
			path = "externalDefensives.maxIcons",
			new = "1.4.0",
			label = L["Maximum icons"],
			type = "number",
			min = 1,
			max = 6,
			step = 1,
			desc = L["Buffs past this count are not shown; the longest remaining come first."],
		},
		{
			label = L["Test"],
			type = "execute",
			text = L["Toggle"],
			enabledBy = EXTERNALS,
			desc = L["Show fake buffs to preview the layout. /uftest toggles it too."],
			func = toggleTestMode("ExternalDefensives"),
		},
	}),
})

ns.RegisterElement({
	path = "deathRecap.point",
	page = "pvp",
	name = L["Death recap"],
	enabledBy = "deathRecap.enabled",
	schema = {},
})

local schema = {
	{ header = L["Frames"] },
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
		desc = L["Also show the locked spell school and the time left when an enemy interrupts your cast."],
	},
	{
		path = "sound",
		label = L["Play sound"],
		type = "toggle",
		desc = L["Play a warning sound when a new effect starts."],
	},
}, nil, "1.4.0")

Section(schema, L["External defensives"], "externalDefensives", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Row of defensive buffs other players cast on you, such as Pain Suppression, Guardian Spirit and Hand spells, longest remaining first."],
	},
}, nil, "1.4.0")

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

local function sound(path, label, enabledBy, hidden)
	return {
		path = path,
		label = label,
		type = "select",
		values = SOUND_VALUES,
		enabledBy = enabledBy,
		hidden = hidden,
		desc = L["Plays once when selected."],
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
		label = L["Minimum interval (seconds)"],
		type = "number",
		min = 0,
		max = 5,
		step = 0.1,
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
		enabledBy = "soundAlerts.targeted",
	},
	{
		path = "targetedText",
		label = L["Show the enemy's name"],
		type = "toggle",
		enabledBy = "soundAlerts.targeted",
		desc = L['Class colored "Targeted by" message in the error text area at the top of the screen.'],
	},
	sound("targetedSound", L["Targeted sound"], "soundAlerts.targeted"),
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
		enabledBy = "soundAlerts.interruptible",
	},
	sound("interruptibleSound", L["Interruptible cast sound"], "soundAlerts.interruptible"),
	{
		path = "dispellable",
		label = L["Dispellable debuff on you"],
		type = "toggle",
		desc = L["When a new debuff lands on you that your class can remove."],
		hidden = cannotDispel,
	},
	{
		path = "dispellableMinDuration",
		label = L["Minimum debuff duration"],
		type = "number",
		min = 0,
		max = 30,
		step = 1,
		enabledBy = "soundAlerts.dispellable",
		desc = L["Shorter debuffs are ignored."],
		hidden = cannotDispel,
	},
	sound("dispellableSound", L["Dispellable debuff sound"], "soundAlerts.dispellable", cannotDispel),
	{
		path = "interruptSuccess",
		label = L["Your interrupt succeeded"],
		type = "toggle",
		desc = L["When you or your pet interrupt a cast."],
	},
	sound("interruptSuccessSound", L["Interrupt sound"], "soundAlerts.interruptSuccess"),
}, nil, "1.4.0")

Section(schema, L["Queue invite"], "queueInvite", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Helpers for a pending arena or battleground invite."],
	},
	{
		path = "countdown",
		label = L["Invite countdown"],
		type = "toggle",
		desc = L["Seconds left to enter, shown above the invite dialog."],
	},
	{ path = "font", label = L["Countdown font"], type = "font", enabledBy = "queueInvite.countdown" },
	{
		path = "sound",
		label = L["Invite sound"],
		type = "toggle",
		desc = L["Play the invite sound on the Master channel, so it is heard with sound effects muted."],
	},
}, nil, "1.4.0")

Section(schema, L["Queue pop flash"], "queuePopFlash", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Flash the whole screen when an arena, battleground or dungeon invite appears."],
	},
	{
		path = "intensity",
		label = L["Brightness"],
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		desc = L["Peak opacity of the flash; it ramps up to this over the first 15 seconds."],
	},
	{
		path = "pulseSpeed",
		label = L["Pulse speed"],
		type = "number",
		min = 0.2,
		max = 5,
		step = 0.1,
		desc = L["Flashes per second."],
	},
	{ path = "color", label = L["Color"], type = "color" },
})

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
		desc = L["Last hits from the final 10 seconds kept in the recap."],
	},
	{
		path = "chatLink",
		label = L["Chat link on death"],
		type = "toggle",
		desc = L["Print a clickable link to the recap when you die."],
	},
	{
		path = "autoOpen",
		label = L["Open in arenas and battlegrounds"],
		type = "toggle",
		desc = L["Show the recap window right away when you die in PvP."],
	},
	{
		label = L["Recap window"],
		type = "execute",
		text = L["Open"],
		func = function()
			SlashCmdList.FROSTATOMUI_DEATH_RECAP()
		end,
	},
}, nil, "1.4.0")

ns.RegisterPage({
	key = "pvp",
	name = L["PvP"],
	order = 34,
	schema = schema,
})
