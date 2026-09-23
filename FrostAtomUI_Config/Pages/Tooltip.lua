local _, ns = ...

local L = FrostAtomUI.L

ns.RegisterElement({
	path = "tooltip.point",
	page = "tooltip",
	name = L["Tooltip"],
	enabledBy = "tooltip.enabled",
	schema = {
		{
			path = "tooltip.anchorCursor",
			new = "1.4.0",
			label = L["Follow the cursor"],
			type = "toggle",
			desc = L["Show tooltips at the mouse cursor instead of the fixed position."],
		},
		{
			path = "tooltip.showHealthText",
			new = "1.4.0",
			label = L["Show health values"],
			type = "toggle",
			desc = L["Current and maximum health on the tooltip health bar."],
		},
	},
})

ns.RegisterPage({
	key = "tooltip",
	name = L["Tooltip"],
	order = 38,
	enable = "tooltip.enabled",
	schema = {
		{
			path = "tooltip.enabled",
			label = L["Enable"],
			type = "toggle",
			desc = L["Anchor, icons, IDs, item level and unit info in tooltips."],
		},
		{ type = "elements" },
		{ header = L["General"] },
		{
			path = "tooltip.hideInCombat",
			label = L["Hide unit tooltips in combat"],
			type = "toggle",
			desc = L["Hold Shift to show them anyway."],
		},
		{ header = L["Extra info"] },
		{ path = "tooltip.showIds", label = L["Spell / item / NPC IDs"], type = "toggle" },
		{
			path = "tooltip.showItemLevel",
			label = L["Item level"],
			type = "toggle",
			desc = L["On gear and inspected players, next to the name."],
		},
		{
			path = "tooltip.showItemCount",
			label = L["Item count in bags / bank"],
			type = "toggle",
			desc = L["Consumables and other non-equippable items only."],
		},
		{
			path = "tooltip.showTarget",
			new = "1.4.0",
			label = L["Unit's target"],
			type = "toggle",
			desc = L["Line with the current target of the unit, <YOU> when it targets you."],
		},
		{
			path = "tooltip.showTargetedBy",
			label = L["Targeted by group members"],
			type = "toggle",
			desc = L["List party or raid members targeting the unit."],
		},
		{
			path = "tooltip.labelColor",
			label = L["Label color"],
			type = "color",
			desc = L["Color of the ID and bag count labels."],
			enabledByAny = { "tooltip.showIds", "tooltip.showItemCount" },
		},
	},
})
