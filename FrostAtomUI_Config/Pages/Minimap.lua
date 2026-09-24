local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section

ns.RegisterElement({
	path = "minimap.point",
	page = "minimap",
	name = L["Minimap"],
	glyph = "map",
	enabledBy = "minimap.enabled",
	schema = {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{ path = "minimap.size", label = L["Size"], type = "number", min = 100, max = 400, step = 1 },
		{ path = "minimap.borderColor", label = L["Border color"], type = "color" },
		{
			path = "minimap.iconSize",
			label = L["Icon size"],
			type = "number",
			min = 12,
			max = 32,
			step = 1,
			desc = L["Mail, battleground and tracking icons on the minimap."],
		},
		{
			path = "minimap.showTracking",
			label = L["Show tracking icon"],
			type = "toggle",
			desc = L["Tracking button in the bottom-right corner. Right-click the minimap opens the same menu."],
		},
		{
			path = "minimap.collectButtons",
			new = "1.4.1",
			label = L["Collect addon buttons"],
			type = "toggle",
			desc = L["Gather addon buttons from the minimap edge into a panel opened by the + button on the left side of the minimap."],
		},
		{ header = L["Clock"], glyph = "clock" },
		{ path = "minimap.showClock", label = L["Show clock"], type = "toggle" },
		{
			path = "minimap.clock24h",
			label = L["24-hour clock"],
			type = "toggle",
			enabledBy = "minimap.showClock",
			desc = L["Off shows 12-hour time with AM / PM."],
		},
		{
			path = "minimap.clockPoint",
			label = L["Clock position"],
			type = "point",
			enabledBy = "minimap.showClock",
			desc = L["Relative to the minimap."],
		},
		{ path = "minimap.clockFont", label = L["Clock font"], type = "font", enabledBy = "minimap.showClock" },
		{ header = L["Zone text"], glyph = "location-dot" },
		{
			path = "minimap.showZoneText",
			label = L["Show zone name"],
			type = "toggle",
			desc = L["Current zone at the top of the minimap, colored by PvP status."],
		},
		{ path = "minimap.zoneFont", label = L["Zone font"], type = "font", enabledBy = "minimap.showZoneText" },
		{ header = L["Visibility"], glyph = "eye" },
		{
			path = "minimap.mouseover",
			label = L["Show on mouseover"],
			type = "toggle",
			desc = L["Keep the minimap faded until the cursor is over it."],
		},
		{
			path = "minimap.combat",
			new = "1.4.1",
			label = L["Visible"],
			type = "select",
			values = ns.COMBAT_VISIBILITY_VALUES,
			desc = L["Fade out of combat or in combat. With mouseover the cursor still reveals it."],
		},
		{
			path = "minimap.fadeAlpha",
			label = L["Faded alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			disabled = function()
				return not FrostAtomUI:GetConfig("minimap.mouseover")
					and FrostAtomUI:GetConfig("minimap.combat") == "any"
			end,
		},
	},
})

ns.RegisterElement({
	path = "minimap.lfgPoint",
	page = "minimap",
	name = L["Queue eye"],
	glyph = "eye",
	enabledBy = "minimap.enabled",
	schema = {
		{
			path = "minimap.lfgSize",
			label = L["Size"],
			type = "number",
			min = 16,
			max = 96,
			step = 1,
			desc = L["Dungeon and arena queue eye, detached from the minimap."],
		},
	},
})

local schema = {}

Section(schema, L["Minimap"], "minimap", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Square minimap, clock, hidden buttons."],
	},
	{ type = "elements" },
}, nil, nil, "map")

Section(schema, L["World map"], "worldMap", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Zoomable, pannable map without the black background, with coordinates and class colored group icons."],
	},
	{
		path = "screenFraction",
		label = L["Full map screen height"],
		type = "number",
		min = 0.5,
		max = 1,
		step = 0.05,
		desc = L["Fraction of the screen height the full-size map takes."],
	},
	{ path = "arrowSize", label = L["Player arrow size"], type = "number", min = 16, max = 64, step = 1 },
	{
		path = "showCoords",
		label = L["Show coordinates"],
		type = "toggle",
		desc = L["Cursor and player coordinates."],
	},
	{ path = "coordFont", label = L["Coordinates font"], type = "font", enabledBy = "worldMap.showCoords" },
	{
		path = "zoomStep",
		label = L["Zoom step"],
		type = "number",
		min = 0.05,
		max = 0.5,
		step = 0.05,
		desc = L["Zoom change per mouse wheel notch, as a fraction of the current zoom."],
	},
	{
		path = "maxZoom",
		label = L["Maximum zoom"],
		type = "number",
		min = 1.5,
		max = 8,
		step = 0.5,
		desc = L["Magnification limit for mouse wheel zoom."],
	},
	{
		path = "fadeWhenMoving",
		new = "1.4.1",
		label = L["Fade while moving"],
		type = "toggle",
		desc = L["Make the map transparent while you move, unless the cursor is over it."],
	},
	{
		path = "movingAlpha",
		new = "1.4.1",
		label = L["Alpha while moving"],
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		enabledBy = "worldMap.fadeWhenMoving",
	},
}, nil, nil, "map-location-dot")

ns.RegisterPage({
	key = "minimap",
	name = L["Minimap & map"],
	glyph = "map",
	order = 37,
	schema = schema,
})
