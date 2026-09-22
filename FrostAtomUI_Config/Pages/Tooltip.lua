local _, ns = ...

local L = FrostAtomUI.L

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
		{ path = "tooltip.point", label = L["Position"], type = "point" },
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
