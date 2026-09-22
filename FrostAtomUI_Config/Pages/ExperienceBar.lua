local _, ns = ...

local L = FrostAtomUI.L

ns.RegisterPage({
	key = "experience",
	name = L["Experience bar"],
	order = 40,
	enable = "experienceBar.enabled",
	schema = {
		{
			path = "experienceBar.enabled",
			label = L["Enable"],
			type = "toggle",
			desc = L["Thin experience bar; hidden at max level unless a reputation is watched."],
		},
		{
			path = "experienceBar.showReputation",
			label = L["Show watched reputation at max level"],
			type = "toggle",
			desc = L["Track the reputation selected in the Reputation window instead of experience."],
		},
		{ header = L["Layout"] },
		{ path = "experienceBar.point", label = L["Position"], type = "point" },
		{ path = "experienceBar.width", label = L["Width"], type = "number", min = 100, max = 1200, step = 1 },
		{ path = "experienceBar.height", label = L["Height"], type = "number", min = 2, max = 30, step = 1 },
		{ header = L["Colors"] },
		{ path = "experienceBar.xpColor", label = L["Experience"], type = "color" },
		{
			path = "experienceBar.restedColor",
			label = L["Rested"],
			type = "color",
			alpha = true,
			desc = L["Overlay showing how far the rested bonus reaches."],
		},
		{
			path = "experienceBar.backgroundAlpha",
			label = L["Background alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
		},
	},
})
