local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section
local NotClass = ns.NotClass

local schema = {
	{
		path = "chat.enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Chat skin, message processing, filters, bubbles, history and whisper blocking."],
	},
	{
		path = "chat.skin",
		label = L["Skin chat frames"],
		type = "toggle",
		reload = true,
		desc = L["Flat backdrop, hidden buttons, auto-hiding tabs. Message features below work either way."],
	},
	{
		path = "chat.lockFrames",
		label = L["Lock frames"],
		type = "toggle",
		reload = true,
		desc = L["Tabs cannot be dragged and frames cannot be resized; the main frame uses the position and size set in its frame settings. Off leaves positions to Blizzard's chat settings."],
	},
	{ type = "elements" },
	{ header = L["Messages"], glyph = "message" },
	{
		path = "chat.timestamps",
		label = L["Timestamps"],
		type = "toggle",
		desc = L["Prefix every line with the time."],
	},
	{
		path = "chat.timestampFormat",
		label = L["Timestamp format"],
		type = "select",
		width = 200,
		enabledBy = "chat.timestamps",
		values = {
			{ "%H:%M", L["24h (18:05)"] },
			{ "%H:%M:%S", L["24h with seconds (18:05:42)"] },
			{ "%I:%M %p", L["12h (06:05 PM)"] },
			{ "%I:%M:%S %p", L["12h with seconds (06:05:42 PM)"] },
		},
	},
	{
		path = "chat.timestampColor",
		new = "1.4.0",
		label = L["Timestamp color"],
		type = "color",
		enabledBy = "chat.timestamps",
		desc = L["Applies to new lines."],
	},
	{
		path = "chat.shortChannelNames",
		label = L["Short channel names"],
		type = "toggle",
		desc = L["[P], [R], [G] instead of full channel names."],
	},
	{
		path = "chat.classColorNames",
		label = L["Class colored names"],
		type = "toggle",
		desc = L["Color player names by class in every chat type."],
	},
	{
		path = "chat.stripRealm",
		label = L["Hide realm in names"],
		type = "toggle",
		desc = L["Show cross-realm players without the -Realm suffix."],
	},
	{ path = "chat.urlLinks", label = L["Clickable URLs"], type = "toggle", desc = L["Click a link to copy it."] },
	{
		path = "chat.stickyChannels",
		label = L["Sticky channels"],
		type = "toggle",
		desc = L["The edit box keeps the last used channel (whisper, party, guild, ...) for the next message."],
	},
	{
		path = "chat.whisperSoundThrottle",
		new = "1.4.0",
		label = L["Limit whisper sound per sender"],
		type = "toggle",
		desc = L["Play the whisper sound at most once per interval for each sender instead of Blizzard's global 5 minute silence."],
	},
	{
		path = "chat.whisperSoundInterval",
		new = "1.4.0",
		label = L["Whisper sound interval (seconds)"],
		type = "number",
		min = 0,
		max = 600,
		step = 10,
		enabledBy = "chat.whisperSoundThrottle",
		desc = L["0 plays the sound for every whisper."],
	},
	{ header = L["Filters"], glyph = "filter" },
	{
		path = "chat.filterSystemSpam",
		label = L["Filter server spam"],
		type = "toggle",
		hidden = not FrostAtomUI.IS_WOWCIRCLE,
		desc = L["Hide queue announcer and website advertisements."],
	},
	{
		path = "chat.filterArenaSpam",
		label = L["Filter arena system messages"],
		type = "toggle",
		desc = L["Hide loot method, raid join / leave and countdown messages inside arenas."],
	},
	{
		path = "chat.filterAutoReplies",
		new = "1.4.1",
		label = L["Filter repeated AFK / DND replies"],
		type = "toggle",
		desc = L["Show an away or busy auto reply only once per sender until its text changes."],
	},
	{
		path = "chat.batchBattlegroundJoins",
		new = "1.4.0",
		label = L["Group battleground join / leave messages"],
		type = "toggle",
		desc = L["During the first minute of a battleground, print one summary line every 5 seconds instead of a line per player. Leave messages are hidden after the match ends."],
	},
	{ header = L["History"], glyph = "clock-rotate-left" },
	{
		path = "chat.maxLines",
		label = L["Lines kept per frame"],
		type = "number",
		min = 100,
		max = 5000,
		step = 100,
		reload = true,
		desc = L["Scrollback and /copy buffer size."],
	},
	{
		path = "chat.savedHistoryLines",
		label = L["Restored lines"],
		type = "number",
		min = 0,
		max = 500,
		step = 10,
		desc = L["Lines of the main chat frame shown again after login or reload. 0 disables."],
	},
	{
		path = "chat.savedCommands",
		label = L["Remembered commands"],
		type = "number",
		min = 0,
		max = 100,
		step = 5,
		desc = L["Edit box up / down arrow history kept between sessions. 0 disables."],
	},
	{
		path = "chat.copyWindowWidth",
		label = L["Copy window width"],
		type = "number",
		min = 300,
		max = 1200,
		step = 10,
		desc = L["Size of the /copy window."],
	},
	{
		path = "chat.copyWindowHeight",
		label = L["Copy window height"],
		type = "number",
		min = 200,
		max = 900,
		step = 10,
		desc = L["Size of the /copy window."],
	},
	{ header = L["Chat bubbles"], glyph = "comment-dots" },
	{ path = "chat.bubbleFont", label = L["Font"], type = "font" },
	{ path = "chat.bubbleAlpha", label = L["Background alpha"], type = "number", min = 0, max = 1, step = 0.05 },
	{
		path = "chat.bubbleBorderAlpha",
		label = L["Border alpha"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		desc = L["The border takes the color of the message type."],
	},
	{ path = "chat.bubbleMaxWidth", label = L["Max width"], type = "number", min = 100, max = 600, step = 10 },
	{
		path = "chat.bubblePadding",
		label = L["Padding"],
		type = "number",
		min = 0,
		max = 20,
		step = 1,
		desc = L["Space between the text and the bubble edge."],
	},
}

Section(schema, L["Whisper block"], "chat.whisperBlock", {
	{
		path = "enabled",
		label = L["Block incoming whispers"],
		type = "toggle",
		desc = L["Hide whispers and store them; they are printed when you turn the block off or whisper the sender. " .. "Toggle with /nodm."],
	},
	{
		path = "reply",
		label = L["Auto reply"],
		type = "string",
		width = 260,
		maxLetters = 120,
		desc = L["Sent once to each blocked sender. Empty for no reply. Set with /nodm <message>."],
	},
	{
		path = "friendsBypass",
		label = L["Let friends through"],
		type = "toggle",
		desc = L["Whispers from your friends list are never blocked."],
	},
}, nil, nil, "comment-slash")

Section(schema, L["Announcements"], "announce", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Messages sent to group chat on your behalf."] },
	{
		path = "interrupts",
		label = L["Announce interrupts"],
		type = "toggle",
		desc = L["Report your interrupts to party, raid or battleground chat. Toggle with /ia."],
	},
	{
		path = "interruptMessage",
		label = L["Interrupt message"],
		type = "string",
		width = 260,
		maxLetters = 80,
		enabledBy = "announce.interrupts",
		desc = L["First %s is the target, second %s is the interrupted spell."],
	},
	{
		path = "arenaResult",
		label = L["Arena rating summary"],
		type = "toggle",
		desc = L["Print both teams' rating and change when an arena ends."],
	},
	{
		path = "arenaResultToParty",
		label = L["Send summary to party"],
		type = "toggle",
		enabledBy = "announce.arenaResult",
		desc = L["Post the summary to party chat instead of only your own chat frame."],
	},
	{
		path = "auraMastery",
		label = L["Announce Aura Mastery"],
		type = "toggle",
		hidden = NotClass("PALADIN"),
		desc = L["Raid warning / party message when Aura Mastery is used with Concentration Aura."],
	},
	{
		path = "auraMasteryMessage",
		label = L["Aura Mastery message"],
		type = "string",
		width = 260,
		maxLetters = 80,
		hidden = NotClass("PALADIN"),
		enabledBy = "announce.auraMastery",
		desc = L["Sent twice to raid warning or party chat."],
	},
}, nil, nil, "bullhorn")

local chatFrame = {
	{ header = L["Size"], glyph = "up-down-left-right" },
	{
		path = "chat.width",
		label = L["Width"],
		type = "number",
		min = 200,
		max = 1200,
		step = 1,
		enabledBy = "chat.lockFrames",
	},
	{
		path = "chat.height",
		label = L["Height"],
		type = "number",
		min = 60,
		max = 800,
		step = 1,
		enabledBy = "chat.lockFrames",
	},
	{ header = L["Appearance"], glyph = "palette" },
	{ path = "chat.backgroundAlpha", label = L["Background alpha"], type = "number", min = 0, max = 1, step = 0.05 },
	{
		path = "chat.scrollToBottomButton",
		new = "1.4.0",
		label = L["Jump to bottom button"],
		type = "toggle",
		enabledBy = "chat.skin",
		desc = L["Show an arrow while the chat is scrolled up; it flashes on new messages and scrolls down on click."],
	},
	{
		path = "chat.editBoxPosition",
		new = "1.4.1",
		label = L["Edit box position"],
		type = "select",
		enabledBy = "chat.skin",
		values = {
			{ "below", L["Below the chat"] },
			{ "above", L["Above the tabs"] },
		},
	},
	{ header = L["Visibility"], glyph = "eye" },
	{
		path = "chat.fadeMessages",
		label = L["Fade out messages"],
		type = "toggle",
		desc = L["Off keeps every line visible until it scrolls out of the window."],
	},
	{
		path = "chat.fadeTime",
		label = L["Fade after (seconds)"],
		type = "number",
		min = 5,
		max = 600,
		step = 5,
		desc = L["Lines fade out after this many seconds of inactivity."],
		enabledBy = "chat.fadeMessages",
	},
	{
		path = "chat.mouseover",
		label = L["Show on mouseover"],
		type = "toggle",
		desc = L["Keep the chat faded until the cursor is over it or the edit box is open."],
	},
	{
		path = "chat.fadeAlpha",
		label = L["Faded alpha"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		enabledBy = "chat.mouseover",
	},
}

local function requireChat(entries)
	for _, entry in ipairs(entries) do
		local path = entry.path
		if path and path ~= "chat.enabled" and path:sub(1, 5) == "chat." then
			ns.AddRequirement(entry, "chat.enabled")
		end
	end
end

requireChat(schema)
requireChat(chatFrame)

ns.RegisterPage({
	key = "chat",
	name = L["Chat"],
	glyph = "comments",
	order = 35,
	schema = schema,
})

ns.RegisterElement({
	path = "chat.point",
	page = "chat",
	name = L["Chat frame"],
	glyph = "comments",
	enabledBy = "chat.enabled",
	schema = chatFrame,
})
