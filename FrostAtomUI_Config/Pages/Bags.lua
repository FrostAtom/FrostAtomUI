local _, ns = ...

local L = FrostAtomUI.L

ns.RegisterElement({
	path = "bags.inventory",
	page = "bags",
	name = L["Inventory"],
	enabledBy = "bags.enabled",
	schema = {
		{
			path = "bags.inventoryColumns",
			label = L["Columns"],
			type = "number",
			min = 4,
			max = 24,
			step = 1,
		},
	},
})

ns.RegisterElement({
	path = "bags.bank",
	page = "bags",
	name = L["Bank"],
	enabledBy = "bags.enabled",
	schema = {
		{ path = "bags.bankColumns", label = L["Columns"], type = "number", min = 4, max = 24, step = 1 },
	},
})

ns.RegisterPage({
	key = "bags",
	name = L["Bags"],
	order = 50,
	enable = "bags.enabled",
	schema = {
		{
			path = "bags.enabled",
			label = L["Enable"],
			type = "toggle",
			reload = true,
			desc = L["Replace Blizzard bags."],
		},
		{ type = "elements" },
		{ header = L["General"] },
		{
			path = "bags.autoOpen",
			label = L["Open at merchant / mail / bank"],
			type = "toggle",
			desc = L["Open the inventory when a merchant, mailbox, auction house, trade or bank window opens."],
		},
		{ path = "bags.playSounds", label = L["Open / close sounds"], type = "toggle" },
		{ header = L["Layout"] },
		{ description = L["Shared by the inventory and the bank; columns are set for each window separately."] },
		{ path = "bags.buttonSize", label = L["Button size"], type = "number", min = 20, max = 50, step = 1 },
		{
			path = "bags.spacing",
			label = L["Spacing"],
			type = "number",
			min = 0,
			max = 12,
			step = 1,
			desc = L["Gap between item buttons."],
		},
		{
			path = "bags.padding",
			label = L["Padding"],
			type = "number",
			min = 2,
			max = 20,
			step = 1,
			desc = L["Space between the frame border and its contents."],
		},
		{
			path = "bags.backgroundAlpha",
			label = L["Background alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
		},
		{ header = L["Items"] },
		{
			path = "bags.showItemLevel",
			label = L["Show item level"],
			type = "toggle",
			desc = L["Item level in the top-left corner of equippable items."],
		},
		{
			path = "bags.highlightNewItems",
			label = L["Highlight new items"],
			type = "toggle",
			desc = L["Glow on items picked up since the bags were last closed."],
		},
		{
			path = "bags.searchFadeAlpha",
			label = L["Search fade alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			desc = L["Alpha of items that do not match the search text."],
		},
		{ header = L["Text"] },
		{ path = "bags.countFont", label = L["Stack count font"], type = "font" },
		{ path = "bags.levelFont", label = L["Item level font"], type = "font", enabledBy = "bags.showItemLevel" },
		{ header = L["Colors"] },
		{
			path = "bags.questItemColor",
			label = L["Quest item border"],
			type = "color",
			desc = L["Border color of quest items instead of the quality color."],
		},
	},
})
