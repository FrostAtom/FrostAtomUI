local _, ns = ...

ns.RegisterPage({
	key = "tooltip",
	name = "Tooltip",
	order = 38,
	enable = "tooltip.enabled",
	schema = {
		{
			path = "tooltip.enabled",
			label = "Enable",
			type = "toggle",
			desc = "Anchor, icons, IDs, item level and unit info in tooltips.",
		},
		{ path = "tooltip.point", label = "Position", type = "point" },
		{
			path = "tooltip.hideInCombat",
			label = "Hide unit tooltips in combat",
			type = "toggle",
			desc = "Hold Shift to show them anyway.",
		},
		{ header = "Extra info" },
		{ path = "tooltip.showIds", label = "Spell / item / NPC IDs", type = "toggle" },
		{
			path = "tooltip.showItemLevel",
			label = "Item level",
			type = "toggle",
			desc = "On items and inspected players.",
		},
		{ path = "tooltip.showItemCount", label = "Item count in bags / bank", type = "toggle" },
		{ path = "tooltip.showTargetedBy", label = "Targeted by group members", type = "toggle" },
	},
})
