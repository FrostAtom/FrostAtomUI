local _, ns = ...

ns.RegisterPage({
	key = "experience",
	name = "Experience bar",
	order = 40,
	enable = "experienceBar.enabled",
	schema = {
		{
			path = "experienceBar.enabled",
			label = "Enable",
			type = "toggle",
			desc = "Thin experience bar; hidden at max level unless a reputation is watched.",
		},
		{
			path = "experienceBar.showReputation",
			label = "Show watched reputation at max level",
			type = "toggle",
			desc = "Track the reputation selected in the Reputation window instead of experience.",
		},
		{ header = "Layout" },
		{ path = "experienceBar.point", label = "Position", type = "point" },
		{ path = "experienceBar.width", label = "Width", type = "number", min = 100, max = 1200, step = 1 },
		{ path = "experienceBar.height", label = "Height", type = "number", min = 2, max = 30, step = 1 },
		{ header = "Colors" },
		{ path = "experienceBar.xpColor", label = "Experience", type = "color" },
		{
			path = "experienceBar.restedColor",
			label = "Rested",
			type = "color",
			alpha = true,
			desc = "Overlay showing how far the rested bonus reaches.",
		},
		{
			path = "experienceBar.backgroundAlpha",
			label = "Background alpha",
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
		},
	},
})
