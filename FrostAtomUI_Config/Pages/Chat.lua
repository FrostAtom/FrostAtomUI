local _, ns = ...

local Section = ns.Section

local schema = {
	{
		path = "chat.enabled",
		label = "Enable",
		type = "toggle",
		reload = true,
		desc = "Chat skin, message processing, filters, bubbles, history and whisper blocking.",
	},
	{
		path = "chat.skin",
		label = "Skin chat frames",
		type = "toggle",
		reload = true,
		desc = "Flat backdrop, hidden buttons, auto-hiding tabs. Message features below work either way.",
	},
	{ header = "Messages" },
	{ path = "chat.timestamps", label = "Timestamps", type = "toggle", desc = "Prefix every line with the time." },
	{
		path = "chat.timestampFormat",
		label = "Timestamp format",
		type = "select",
		width = 200,
		enabledBy = "chat.timestamps",
		values = {
			{ "%H:%M", "24h (18:05)" },
			{ "%H:%M:%S", "24h with seconds (18:05:42)" },
			{ "%I:%M %p", "12h (06:05 PM)" },
			{ "%I:%M:%S %p", "12h with seconds (06:05:42 PM)" },
		},
	},
	{
		path = "chat.stickyChannels",
		label = "Sticky channels",
		type = "toggle",
		desc = "The edit box keeps the last used channel (whisper, party, guild, ...) for the next message.",
	},
	{
		path = "chat.maxLines",
		label = "Lines kept per frame",
		type = "number",
		min = 100,
		max = 5000,
		step = 100,
		reload = true,
		desc = "Scrollback and /copy buffer size.",
	},
	{ path = "chat.urlLinks", label = "Clickable URLs", type = "toggle", desc = "Click a link to copy it." },
	{
		path = "chat.stripRealm",
		label = "Hide realm in names",
		type = "toggle",
		desc = "Show cross-realm players without the -Realm suffix.",
	},
	{
		path = "chat.shortChannelNames",
		label = "Short channel names",
		type = "toggle",
		desc = "[P], [R], [G] instead of full channel names.",
	},
	{
		path = "chat.classColorNames",
		label = "Class colored names",
		type = "toggle",
		desc = "Color player names by class in every chat type.",
	},
	{ header = "Filters" },
	{
		path = "chat.filterSystemSpam",
		label = "Filter server spam",
		type = "toggle",
		desc = "Hide queue announcer and website advertisements.",
	},
	{
		path = "chat.filterArenaSpam",
		label = "Filter arena system messages",
		type = "toggle",
		desc = "Hide loot method, raid join / leave and countdown messages inside arenas.",
	},
	{ header = "History" },
	{
		path = "chat.savedHistoryLines",
		label = "Restored lines",
		type = "number",
		min = 0,
		max = 500,
		step = 10,
		desc = "Lines of the main chat frame shown again after login or reload. 0 disables.",
	},
	{
		path = "chat.savedCommands",
		label = "Remembered commands",
		type = "number",
		min = 0,
		max = 100,
		step = 5,
		desc = "Edit box up / down arrow history kept between sessions. 0 disables.",
	},
	{ header = "Frame" },
	{
		path = "chat.lockFrames",
		label = "Lock frames",
		type = "toggle",
		reload = true,
		desc = "Tabs cannot be dragged and frames cannot be resized; the main frame uses the position below. "
			.. "Off leaves positions to Blizzard's chat settings.",
	},
	{ path = "chat.point", label = "Position", type = "point", enabledBy = "chat.lockFrames" },
	{
		path = "chat.width",
		label = "Width",
		type = "number",
		min = 200,
		max = 1000,
		step = 1,
		enabledBy = "chat.lockFrames",
	},
	{
		path = "chat.height",
		label = "Height",
		type = "number",
		min = 80,
		max = 800,
		step = 1,
		enabledBy = "chat.lockFrames",
	},
	{
		path = "chat.fadeTime",
		label = "Fade after (seconds)",
		type = "number",
		min = 5,
		max = 600,
		step = 5,
		desc = "Lines fade out after this many seconds of inactivity.",
	},
	{ path = "chat.backgroundAlpha", label = "Background alpha", type = "number", min = 0, max = 1, step = 0.05 },
	{
		path = "chat.copyWindowWidth",
		label = "Copy window width",
		type = "number",
		min = 300,
		max = 1200,
		step = 10,
		desc = "Size of the /copy window.",
	},
	{
		path = "chat.copyWindowHeight",
		label = "Copy window height",
		type = "number",
		min = 200,
		max = 900,
		step = 10,
		desc = "Size of the /copy window.",
	},
	{ header = "Chat bubbles" },
	{ path = "chat.bubbleFont", label = "Font", type = "font" },
	{ path = "chat.bubbleAlpha", label = "Background alpha", type = "number", min = 0, max = 1, step = 0.05 },
	{
		path = "chat.bubbleBorderAlpha",
		label = "Border alpha",
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		desc = "The border takes the color of the message type.",
	},
	{ path = "chat.bubbleMaxWidth", label = "Max width", type = "number", min = 100, max = 600, step = 10 },
	{
		path = "chat.bubblePadding",
		label = "Padding",
		type = "number",
		min = 0,
		max = 20,
		step = 1,
		desc = "Space between the text and the bubble edge.",
	},
}

Section(schema, "Whisper block", "chat.whisperBlock", {
	{
		path = "enabled",
		label = "Block incoming whispers",
		type = "toggle",
		desc = "Hide whispers and store them; they are printed when you turn the block off or whisper the sender. "
			.. "Toggle with /nodm.",
	},
	{
		path = "reply",
		label = "Auto reply",
		type = "string",
		width = 260,
		maxLetters = 120,
		desc = "Sent once to each blocked sender. Empty for no reply. Set with /nodm <message>.",
	},
	{
		path = "friendsBypass",
		label = "Let friends through",
		type = "toggle",
		desc = "Whispers from your friends list are never blocked.",
	},
})

Section(schema, "Announcements", "announce", {
	{ path = "enabled", label = "Enable", type = "toggle", desc = "Messages sent to group chat on your behalf." },
	{
		path = "interrupts",
		label = "Announce interrupts",
		type = "toggle",
		desc = "Report your interrupts to party, raid or battleground chat. Toggle with /ia.",
	},
	{
		path = "interruptMessage",
		label = "Interrupt message",
		type = "string",
		width = 260,
		maxLetters = 80,
		enabledBy = "announce.interrupts",
		desc = "First %s is the target, second %s is the interrupted spell.",
	},
	{
		path = "arenaResult",
		label = "Arena rating summary",
		type = "toggle",
		desc = "Print both teams' rating and change when an arena ends.",
	},
	{
		path = "arenaResultToParty",
		label = "Send summary to party",
		type = "toggle",
		enabledBy = "announce.arenaResult",
		desc = "Post the summary to party chat instead of only your own chat frame.",
	},
	{
		path = "auraMastery",
		label = "Announce Aura Mastery",
		type = "toggle",
		hidden = FrostAtomUI.PLAYER_CLASS ~= "PALADIN",
		desc = "Raid warning / party message when Aura Mastery is used with Concentration Aura.",
	},
	{
		path = "auraMasteryMessage",
		label = "Aura Mastery message",
		type = "string",
		width = 260,
		maxLetters = 80,
		hidden = FrostAtomUI.PLAYER_CLASS ~= "PALADIN",
		enabledBy = "announce.auraMastery",
		desc = "Sent twice to raid warning or party chat.",
	},
})

for _, entry in ipairs(schema) do
	local path = entry.path
	if path and path ~= "chat.enabled" and path:sub(1, 5) == "chat." then
		local enabledBy = entry.enabledBy
		if type(enabledBy) == "table" then
			enabledBy[#enabledBy + 1] = "chat.enabled"
		elseif enabledBy then
			entry.enabledBy = { enabledBy, "chat.enabled" }
		else
			entry.enabledBy = "chat.enabled"
		end
	end
end

ns.RegisterPage({
	key = "chat",
	name = "Chat",
	order = 35,
	schema = schema,
})
