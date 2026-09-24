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
		{
			path = "minimap.iconSize",
			label = L["Icon size"],
			type = "number",
			min = 12,
			max = 32,
			step = 1,
			desc = L["Mail, battleground and tracking icons on the minimap."],
		},
		{ header = L["Display"], glyph = "bars-staggered" },
		{
			path = "minimap.showTracking",
			label = L["Tracking icon"],
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
		{
			path = "minimap.showZoneText",
			label = L["Zone name"],
			type = "toggle",
			desc = L["Current zone at the top of the minimap, colored by PvP status."],
		},
		{
			path = "minimap.showClock",
			label = L["Clock"],
			type = "toggle",
			desc = L["Local time at the bottom of the minimap."],
		},
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
		{ header = L["Text"], glyph = "font" },
		{ path = "minimap.zoneFont", label = L["Zone font"], type = "font", enabledBy = "minimap.showZoneText" },
		{ path = "minimap.clockFont", label = L["Clock font"], type = "font", enabledBy = "minimap.showClock" },
		{ header = L["Colors"], glyph = "palette" },
		{
			path = "minimap.borderColor",
			label = L["Border color"],
			type = "color",
			desc = L["Thin border around the minimap."],
		},
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
			percent = true,
			disabled = function()
				return not FrostAtomUI:GetConfig("minimap.mouseover")
					and FrostAtomUI:GetConfig("minimap.combat") == "any"
			end,
			disabledDesc = L["Used only with Show on mouseover or when Visible is not Always."],
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

local schema = {
	{
		path = "minimap.enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Square minimap, clock, hidden buttons. The world map has its own switch below."],
	},
	{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
	{ type = "elements", enabledBy = "minimap.enabled" },
}

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
		percent = true,
		desc = L["Fraction of the screen height the full-size map takes."],
	},
	{
		path = "arrowSize",
		label = L["Player arrow size"],
		type = "number",
		min = 16,
		max = 64,
		step = 1,
		desc = L["Your own arrow on the map."],
	},
	{
		path = "showCoords",
		label = L["Coordinates"],
		type = "toggle",
		desc = L["Cursor and player coordinates."],
	},
	{ path = "coordFont", label = L["Coordinates font"], type = "font", enabledBy = "worldMap.showCoords" },
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
		percent = true,
		enabledBy = "worldMap.fadeWhenMoving",
	},
	{
		path = "zoomStep",
		label = L["Zoom step"],
		type = "number",
		min = 0.05,
		max = 0.5,
		step = 0.05,
		percent = true,
		advanced = true,
		desc = L["Zoom change per mouse wheel notch, as a fraction of the current zoom."],
	},
	{
		path = "maxZoom",
		label = L["Maximum zoom"],
		type = "number",
		min = 1.5,
		max = 8,
		step = 0.5,
		advanced = true,
		desc = L["Magnification limit for mouse wheel zoom."],
	},
}, nil, nil, "map-location-dot")

ns.RegisterPage({
	key = "minimap",
	name = L["Minimap & map"],
	glyph = "map",
	order = 44,
	group = "interface",
	schema = schema,
})
