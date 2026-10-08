local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section
local NotClass = ns.NotClass

local MAX_MESSAGE_ARGUMENTS = 2

local function validateInterruptMessage(text)
	local count = 0
	for spec in text:gmatch("%%(.?)") do
		if spec == "s" then
			count = count + 1
		elseif spec ~= "%" then
			return false, L["Only %s placeholders are allowed; write %% for a percent sign."]
		end
	end
	if count > MAX_MESSAGE_ARGUMENTS then
		return false, L["At most two %s placeholders: the target and the spell."]
	end
	return true
end

local schema = {}

Section(schema, L["Messages on your behalf"], "announce", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Messages sent to group chat on your behalf."] },
	{
		path = "interrupts",
		label = L["Post my interrupts to group chat"],
		type = "toggle",
		desc = L["Report your interrupts to party, raid or battleground chat. Toggle with /ia."],
	},
	{
		path = "interruptMessage",
		advanced = true,
		label = L["Interrupt message"],
		type = "string",
		width = 240,
		maxLetters = 80,
		enabledBy = "announce.interrupts",
		validate = validateInterruptMessage,
		desc = L["First %s is the target, second %s is the interrupted spell."],
	},
	{
		path = "arenaResultToParty",
		label = L["Post arena rating results to the party"],
		type = "toggle",
		desc = L["Post both teams' rating and change to party chat when an arena ends."],
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
		advanced = true,
		label = L["Aura Mastery message"],
		type = "string",
		width = 240,
		maxLetters = 80,
		hidden = NotClass("PALADIN"),
		enabledBy = "announce.auraMastery",
		desc = L["Sent twice to raid warning or party chat."],
	},
}, nil, nil, "bullhorn")

Section(schema, L["Popups"], "popups", {
	{ path = "enabled", label = L["Enable"], type = "toggle", desc = L["Automatic handling of popup dialogs."] },
}, nil, nil, "window-restore")

Section(schema, L["Group and invites"], "popups", {
	{
		path = "autoAcceptInvites",
		label = L["Auto accept invites from friends / guild"],
		type = "toggle",
		desc = L["Only while not already in a group."],
	},
	{
		path = "declineInvites",
		label = L["Decline party invites"],
		type = "toggle",
		desc = L["Toggle with /noparty."],
	},
}, nil, nil, "user-plus")

Section(schema, L["Death"], "popups", {
	{
		path = "autoRelease",
		label = L["Auto release in battlegrounds"],
		type = "toggle",
		desc = L["Release spirit 1.5 s after death in a battleground. Hold Shift to stay dead, e.g. for a battle resurrection."],
	},
}, nil, nil, "skull")

Section(schema, L["Trades and duels"], "popups", {
	{
		path = "declineTradeInCombat",
		label = L["Decline trades in combat"],
		type = "toggle",
		desc = L["Close incoming trade windows while in combat."],
	},
	{
		path = "declineTrades",
		label = L["Decline trades"],
		type = "toggle",
		desc = L["Toggle with /notrade."],
	},
	{
		path = "declineDuels",
		label = L["Decline duels"],
		type = "toggle",
		desc = L["Toggle with /noduel."],
	},
}, nil, nil, "handshake")

Section(schema, L["Items"], "popups", {
	{
		path = "fillDeleteConfirm",
		label = L["Type the delete word for me"],
		type = "toggle",
		desc = L["Rare and epic items are deleted with a single click on Yes. Quest items are not affected. Deleted items cannot be restored."],
	},
}, nil, nil, "trash-can")

Section(schema, L["Merchant"], "merchant", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Automatic actions when a merchant window opens. Hold Shift while opening it to skip them."],
	},
	{
		path = "sellGreys",
		label = L["Sell grey items"],
		type = "toggle",
		desc = L["Sell every poor quality item in your bags."],
	},
	{
		path = "autoRepair",
		label = L["Auto repair"],
		type = "toggle",
		desc = L["Repair all gear when you can afford it."],
	},
	{
		path = "guildRepair",
		advanced = true,
		new = "1.4.0",
		label = L["Use guild bank funds"],
		type = "toggle",
		enabledBy = "merchant.autoRepair",
		desc = L["Repair from the guild bank when your rank allows it and the guild can pay; otherwise from your own money."],
	},
}, nil, nil, "coins")

ns.RegisterPage({
	key = "automation",
	name = L["Automation"],
	desc = L["What the addon does for you: messages, popups, merchant."],
	glyph = "robot",
	order = 60,
	group = "system",
	schema = schema,
})
