local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

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

local cannotDispel = not FrostAtomUI.API.RunAction("canDispel")

local sounds = {}
Section(sounds, L["Event sounds"], "soundAlerts", {
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

Section(sounds, L["Interrupt sounds"], "soundAlerts", {
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

Section(sounds, L["Dispel sounds"], "soundAlerts", {
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

local queue = {}
Section(queue, L["Queue invite"], "queueInvite", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Helpers for a pending arena or battleground invite."],
	},
	{
		path = "style",
		new = "1.5.0",
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
		label = L["Flash opacity"],
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
	queue[#queue + 1] = entry
end

local battleground = {}
Section(battleground, L["Battleground"], "battleground", {
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

ns.AddTab("alerts", { key = "sounds", order = 2, name = L["Event sounds"], glyph = "volume-high", schema = sounds })
ns.AddTab("alerts", { key = "queue", order = 3, name = L["Queues"], glyph = "bell", schema = queue })
ns.AddTab(
	"alerts",
	{ key = "battleground", order = 4, name = L["Battleground"], glyph = "flag", schema = battleground }
)

ns.RegisterPage({
	key = "alerts",
	name = L["Alerts"],
	desc = L["Voice, sounds and a screen flash when a dungeon or battleground invite arrives."],
	glyph = "bullhorn",
	order = 36,
	group = "pvp",
	schema = {},
})
