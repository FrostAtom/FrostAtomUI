local _, ns = ...

ns.RegisterPage({
	key = "minimap",
	name = "Minimap",
	order = 37,
	enable = "minimap.enabled",
	schema = {
		{
			path = "minimap.enabled",
			label = "Enable",
			type = "toggle",
			reload = true,
			desc = "Square minimap, clock, hidden buttons.",
		},
		{ path = "minimap.point", label = "Position", type = "point" },
		{ path = "minimap.size", label = "Size", type = "number", min = 100, max = 300, step = 1 },
		{ path = "minimap.borderColor", label = "Border color", type = "color" },
		{ header = "Clock" },
		{ path = "minimap.showClock", label = "Show clock", type = "toggle" },
		{ path = "minimap.clockFont", label = "Clock font", type = "font", enabledBy = "minimap.showClock" },
	},
})
