local _, ns = ...

ns.COMPACT_SCREEN_HEIGHT = 1000

ns.Limits = {
	frame = { width = { 80, 500 }, height = { 20, 120 } },
	square = { width = { 20, 200 }, height = { 20, 200 } },
	castbar = { width = { 60, 500 }, height = { 10, 60 } },
}

ns.LayoutSettings = {
	"actionBar.bar1.columns",
	"actionBar.bar1.buttonSize",
	"actionBar.bar1.buttons",
	"actionBar.bar1.spacing",
	"actionBar.bar2.columns",
	"actionBar.bar2.buttonSize",
	"actionBar.bar2.buttons",
	"actionBar.bar2.spacing",
	"actionBar.bar3.columns",
	"actionBar.bar3.buttonSize",
	"actionBar.bar3.buttons",
	"actionBar.bar3.spacing",
	"actionBar.bar4.columns",
	"actionBar.bar4.buttonSize",
	"actionBar.bar4.buttons",
	"actionBar.bar4.spacing",
	"actionBar.bar5.columns",
	"actionBar.bar5.buttonSize",
	"actionBar.bar5.buttons",
	"actionBar.bar5.spacing",
	"actionBar.bar6.columns",
	"actionBar.bar6.buttonSize",
	"actionBar.bar6.buttons",
	"actionBar.bar6.spacing",
	"actionBar.stance.columns",
	"actionBar.pet.columns",
	"actionBar.totemBar.columns",
	"unitFrames.playerWidth",
	"unitFrames.playerHeight",
	"unitFrames.targetWidth",
	"unitFrames.targetHeight",
	"unitFrames.focusWidth",
	"unitFrames.focusHeight",
	"unitFrames.partyWidth",
	"unitFrames.partyHeight",
	"unitFrames.arenaWidth",
	"unitFrames.arenaHeight",
	"unitFrames.playerCastbarWidth",
	"unitFrames.playerCastbarHeight",
	"unitFrames.targetCastbarWidth",
	"unitFrames.focusCastbarWidth",
	"unitFrames.partyCastbarWidth",
	"unitFrames.arenaCastbarWidth",
	"unitFrames.targetCastbarHeight",
	"unitFrames.focusCastbarHeight",
	"unitFrames.partyCastbarHeight",
	"unitFrames.arenaCastbarHeight",
	"unitFrames.playerIconSide",
	"unitFrames.targetIconSide",
	"unitFrames.focusIconSide",
	"unitFrames.partyIconSide",
	"unitFrames.arenaIconSide",
	"unitFrames.arenaDebuffPosition",
	"unitFrames.arenaBuffPosition",
	"unitFrames.partyTextSize",
	"unitFrames.arenaTextSize",
	"raidFrames.width",
	"raidFrames.height",
	"raidFrames.unitsPerColumn",
	"raidFrames.orientation",
	"raidFrames.growthX",
	"raidFrames.growthY",
	"groupCooldowns.friendlyGrowth",
	"groupCooldowns.enemyGrowth",
	"groupCooldowns.friendlyInterruptGrowth",
	"groupCooldowns.enemyInterruptGrowth",
	"groupCooldowns.enemyFramePerRow",
	"chat.width",
	"chat.height",
	"minimap.size",
}

local function group(points, prefix, count, first, step)
	points["unitFrames." .. prefix] = first
	for i = 2, count do
		local previous = i == 2 and prefix or prefix .. (i - 1)
		points["unitFrames." .. prefix .. i] = { step[1], step[2], step[3], "unitFrames." .. previous, step[4] }
	end
	return points
end

local function each(points, prefix, count, suffix, point)
	for i = 1, count do
		local frame = i == 1 and prefix or prefix .. i
		points["unitFrames." .. prefix .. i .. suffix] =
			{ point[1], point[2], point[3], "unitFrames." .. frame, point[4] }
	end
	return points
end

local function sideBars(points)
	points["actionBar.bar4.point"] = { "RIGHT", -2, -70 }
	points["actionBar.bar5.point"] = { "RIGHT", -2, 0, "actionBar.bar4.point", "LEFT" }
	points["bags.inventory"] = { "BOTTOMRIGHT", -84, 42 }
	points["tooltip.point"] = { "BOTTOMRIGHT", -91, 64 }
	return points
end

local function edgeBars(points)
	points["actionBar.bar4.point"] = { "LEFT", 2, 30 }
	points["actionBar.bar5.point"] = { "RIGHT", -2, -70 }
	points["bags.inventory"] = { "BOTTOMRIGHT", -44, 42 }
	points["tooltip.point"] = { "BOTTOMRIGHT", -51, 64 }
	return points
end

local SIDE_BAR_SETTINGS = {
	["actionBar.bar4.columns"] = 1,
	["actionBar.bar5.columns"] = 1,
}

local FULLHD_CHAT = {
	["chat.width"] = 300,
	["chat.height"] = 100,
}

local COMPACT_CHAT = {
	["chat.width"] = 270,
	["chat.height"] = 120,
}

local function merge(...)
	local result = {}
	for i = 1, select("#", ...) do
		for path, value in pairs((select(i, ...))) do
			result[path] = value
		end
	end
	return result
end

local castbarDefensives = { "BOTTOM", 0, 8, "unitFrames.playerCastbar", "TOP" }
local totemBarOverBars = { "BOTTOMLEFT", 0, 4, "actionBar.bar3.point", "TOPLEFT" }

local function plateRunes(points)
	points["runes.point"] = { "TOP", 0, -6, "playerPlate.point", "BOTTOM" }
	points["totems.point"] = { "TOP", 0, -6, "playerPlate.point", "BOTTOM" }
	return points
end

local function runesAbovePlate(points)
	points["runes.point"] = { "BOTTOM", 0, 4, "playerPlate.point", "TOP" }
	points["totems.point"] = { "BOTTOM", 0, 4, "playerPlate.point", "TOP" }
	return points
end

local function centerStack(points)
	points["playerPlate.point"] = { "BOTTOM", 0, 250 }
	points["unitFrames.playerCastbar"] = { "BOTTOM", 0, 4, "playerPlate.point", "TOP" }
	points["externalDefensives.point"] = castbarDefensives
	points["internalCooldowns.playerPoint"] = { "BOTTOM", 0, 178 }
	return plateRunes(points)
end

local function flankCenter(points)
	points["actionBar.totemBar.point"] = totemBarOverBars
	points["unitFrames.player"] = { "BOTTOM", -250, 246 }
	points["unitFrames.target"] = { "BOTTOM", 250, 246 }
	return centerStack(points)
end

local function castbarsOnTop(points, ...)
	for i = 1, select("#", ...) do
		local unit = select(i, ...)
		points["unitFrames." .. unit .. "Castbar"] = { "BOTTOMLEFT", 27, 4, "unitFrames." .. unit, "TOPLEFT" }
	end
	return points
end

local fullHD = edgeBars(runesAbovePlate({
	["unitFrames.party"] = { "TOPLEFT", 110, -200 },
	["groupCooldowns.friendlyPoint"] = { "BOTTOMRIGHT", -235, 2, nil, "BOTTOM" },
	["groupCooldowns.enemyPoint"] = { "BOTTOMLEFT", 235, 2, nil, "BOTTOM" },
}))

local fullHDCompact = castbarsOnTop(
	centerStack({
		["actionBar.totemBar.point"] = totemBarOverBars,
		["unitFrames.player"] = { "TOPLEFT", 150, -50 },
		["unitFrames.target"] = { "LEFT", 2, 0, "unitFrames.player", "RIGHT" },
		["unitFrames.focus"] = { "LEFT", 47, 0, "unitFrames.target", "RIGHT" },
		["unitFrames.arena"] = { "TOPRIGHT", -140, -200 },
	}),
	"target",
	"focus"
)
group(fullHDCompact, "party", 4, { "TOPLEFT", 130, -195 }, { "LEFT", 0, -110, "LEFT" })

local modern = sideBars(plateRunes({
	["actionBar.stance.point"] = { "BOTTOMLEFT", 22, 4, "actionBar.bar3.point", "TOPLEFT" },
	["actionBar.totemBar.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar3.point", "TOPLEFT" },
	["actionBar.pet.point"] = { "BOTTOMRIGHT", 0, 4, "actionBar.bar3.point", "TOPRIGHT" },
	["actionBar.vehicleExit.point"] = { "BOTTOMLEFT", 4, 0, "actionBar.bar3.point", "BOTTOMRIGHT" },
	["unitFrames.player"] = { "BOTTOM", -300, 350 },
	["unitFrames.target"] = { "BOTTOM", 300, 350 },
	["unitFrames.focus"] = { "TOP", 0, -80 },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 160 },
	["groupCooldowns.friendlyPoint"] = { "BOTTOMRIGHT", -235, 2, nil, "BOTTOM" },
	["groupCooldowns.enemyPoint"] = { "BOTTOMLEFT", 235, 2, nil, "BOTTOM" },
}))
group(modern, "party", 4, { "TOPLEFT", 100, -180 }, { "LEFT", 0, -160, "LEFT" })
group(modern, "arena", 3, { "TOPRIGHT", -200, -235 }, { "RIGHT", 0, -150, "RIGHT" })

local modernCompact = castbarsOnTop(
	flankCenter({
		["unitFrames.focus"] = { "TOP", 0, -40 },
	}),
	"target",
	"focus"
)
group(modernCompact, "party", 4, { "TOPLEFT", 70, -40 }, { "LEFT", 0, -160, "LEFT" })
group(modernCompact, "arena", 3, { "TOPRIGHT", -130, -200 }, { "RIGHT", 0, -160, "RIGHT" })

local classic = plateRunes({
	["actionBar.bar1.point"] = { "BOTTOM", -230, 2 },
	["actionBar.bar2.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar1.point", "TOPLEFT" },
	["actionBar.bar3.point"] = { "BOTTOMLEFT", 6, 0, "actionBar.bar2.point", "BOTTOMRIGHT" },
	["actionBar.bar4.point"] = { "BOTTOMLEFT", 6, 0, "actionBar.bar1.point", "BOTTOMRIGHT" },
	["actionBar.bar5.point"] = { "RIGHT", -2, -70 },
	["bags.inventory"] = { "BOTTOMRIGHT", -44, 42 },
	["tooltip.point"] = { "BOTTOMRIGHT", -51, 64 },
	["actionBar.stance.point"] = { "BOTTOMLEFT", 22, 4, "actionBar.bar2.point", "TOPLEFT" },
	["actionBar.totemBar.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar2.point", "TOPLEFT" },
	["actionBar.pet.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar3.point", "TOPLEFT" },
	["actionBar.vehicleExit.point"] = { "BOTTOMRIGHT", 0, 4, "actionBar.bar3.point", "TOPRIGHT" },
	["unitFrames.player"] = { "TOPLEFT", 100, -40 },
	["unitFrames.target"] = { "LEFT", 70, 0, "unitFrames.player", "RIGHT" },
	["unitFrames.focus"] = { "LEFT", 70, 0, "unitFrames.target", "RIGHT" },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 150 },
	["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, 0, "unitFrames.party", "TOPRIGHT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, 0, "unitFrames.arena", "TOPLEFT" },
})
group(classic, "party", 4, { "TOPLEFT", 100, -260 }, { "LEFT", 0, -160, "LEFT" })
group(classic, "arena", 3, { "TOPRIGHT", -200, -250 }, { "RIGHT", 0, -160, "RIGHT" })

local classicCompact = castbarsOnTop(
	centerStack({
		["actionBar.bar1.point"] = { "BOTTOM", -194, 2 },
		["unitFrames.player"] = { "TOPLEFT", 100, -50 },
		["unitFrames.arena"] = { "TOPRIGHT", -140, -250 },
		["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, -310, "unitFrames.party", "TOPRIGHT" },
	}),
	"target",
	"focus"
)
group(classicCompact, "party", 4, { "TOPLEFT", 100, -180 }, { "LEFT", 0, -110, "LEFT" })

local CLASSIC_COMPACT_BARS = {
	["actionBar.bar1.buttonSize"] = 30,
	["actionBar.bar2.buttonSize"] = 30,
	["actionBar.bar3.buttonSize"] = 30,
	["actionBar.bar4.buttonSize"] = 30,
}

local vehicleExitLeft = { "BOTTOMRIGHT", -4, 0, "actionBar.bar4.point", "BOTTOMLEFT" }

local arena = plateRunes({
	["actionBar.vehicleExit.point"] = vehicleExitLeft,
	["unitFrames.player"] = { "BOTTOM", -260, 240 },
	["unitFrames.target"] = { "BOTTOM", 260, 240 },
	["unitFrames.targetCastbar"] = { "BOTTOMLEFT", 27, 4, "unitFrames.target", "TOPLEFT" },
	["unitFrames.focus"] = { "TOPRIGHT", 0, -100, "unitFrames.arena3", "BOTTOMRIGHT" },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 160 },
	["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, 0, "unitFrames.party", "TOPRIGHT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, 0, "unitFrames.arena", "TOPLEFT" },
})
group(arena, "party", 4, { "TOP", -520, -170 }, { "LEFT", 0, -166, "LEFT" })
group(arena, "arena", 3, { "TOP", 520, -235 }, { "RIGHT", 0, -160, "RIGHT" })

local arenaCompact = castbarsOnTop(
	flankCenter({
		["unitFrames.arena"] = { "TOPRIGHT", -100, -200 },
		["unitFrames.focus"] = { "TOP", 0, -40 },
		["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, -120, "unitFrames.party", "TOPRIGHT" },
		["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, -120, "unitFrames.arena", "TOPLEFT" },
	}),
	"focus"
)
group(arenaCompact, "party", 4, { "TOPLEFT", 50, -60 }, { "LEFT", 0, -153, "LEFT" })

local gladius = plateRunes({
	["actionBar.vehicleExit.point"] = vehicleExitLeft,
	["unitFrames.player"] = { "BOTTOM", -260, 240 },
	["unitFrames.target"] = { "BOTTOM", 260, 240 },
	["unitFrames.targetCastbar"] = { "BOTTOMLEFT", 27, 4, "unitFrames.target", "TOPLEFT" },
	["unitFrames.focus"] = { "TOPRIGHT", 0, -84, "unitFrames.arena3", "BOTTOMRIGHT" },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 160 },
	["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, 0, "unitFrames.party", "TOPRIGHT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, 0, "unitFrames.arena", "TOPLEFT" },
})
group(gladius, "party", 4, { "TOP", -520, -170 }, { "LEFT", 0, -166, "LEFT" })
group(gladius, "arena", 3, { "TOP", 480, -235 }, { "TOP", 0, -80, "BOTTOM" })
each(gladius, "arena", 3, "Castbar", { "TOPRIGHT", 0, -4, "BOTTOMRIGHT" })
for i = 1, 3 do
	gladius["groupCooldowns.arena" .. i .. "Point"] =
		{ "TOPRIGHT", 0, -4, "unitFrames.arena" .. i .. "Castbar", "BOTTOMRIGHT" }
end

local gladiusCompact = flankCenter({
	["unitFrames.arena"] = { "TOPRIGHT", -80, -200 },
})
group(gladiusCompact, "party", 4, { "TOPLEFT", 50, -60 }, { "LEFT", 0, -153, "LEFT" })

local GLADIUS_SETTINGS = {
	["unitFrames.arenaWidth"] = 180,
	["unitFrames.arenaHeight"] = 40,
	["unitFrames.arenaCastbarWidth"] = 162,
	["unitFrames.arenaCastbarHeight"] = 16,
	["unitFrames.arenaDebuffPosition"] = "LEFT",
	["unitFrames.arenaBuffPosition"] = "LEFT",
	["groupCooldowns.enemyFramePerRow"] = 7,
}

local healer = castbarsOnTop({
	["actionBar.vehicleExit.point"] = vehicleExitLeft,
	["actionBar.totemBar.point"] = totemBarOverBars,
	["unitFrames.player"] = { "BOTTOM", -280, 510 },
	["unitFrames.target"] = { "BOTTOM", 280, 510 },
	["unitFrames.focus"] = { "TOP", -200, -60 },
	["playerPlate.point"] = { "BOTTOM", 0, 440 },
	["unitFrames.playerCastbar"] = { "TOP", 0, -4, "playerPlate.point", "BOTTOM" },
	["internalCooldowns.playerPoint"] = { "RIGHT", -34, 0, "unitFrames.playerCastbar", "LEFT" },
	["runes.point"] = { "TOP", 0, -4, "unitFrames.playerCastbar", "BOTTOM" },
	["totems.point"] = { "TOP", 0, -4, "unitFrames.playerCastbar", "BOTTOM" },
	["shieldIndicator.point"] = { "RIGHT", -4, 0, "playerPlate.point", "LEFT" },
	["groupCooldowns.friendlyPoint"] = { "BOTTOMRIGHT", -55, 0, "unitFrames.party", "BOTTOMLEFT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, 0, "unitFrames.arena", "TOPLEFT" },
	["externalDefensives.point"] = { "RIGHT", -8, 0, "unitFrames.pet", "LEFT" },
	["raidFrames.point"] = { "BOTTOM", 0, 250 },
}, "target")
group(healer, "party", 4, { "BOTTOM", -419, 262 }, { "LEFT", 95, 0, "RIGHT" })
group(healer, "arena", 3, { "TOPRIGHT", -140, -235 }, { "RIGHT", 0, -160, "RIGHT" })
each(healer, "party", 4, "Castbar", { "BOTTOMLEFT", 27, 4, "TOPLEFT" })
for i = 1, 4 do
	healer["groupCooldowns.party" .. i .. "Point"] =
		{ "BOTTOMLEFT", -27, 4, "unitFrames.party" .. i .. "Castbar", "TOPLEFT" }
end

local healerCompact = {
	["unitFrames.player"] = { "TOP", -102, -50 },
	["unitFrames.target"] = { "TOP", 102, -50 },
	["unitFrames.focus"] = { "TOPLEFT", 100, -50 },
	["playerPlate.point"] = { "BOTTOM", 0, 380 },
	["internalCooldowns.playerPoint"] = { "RIGHT", -4, 0, "unitFrames.playerCastbar", "LEFT" },
	["externalDefensives.point"] = { "TOPRIGHT", 0, -4, "unitFrames.player", "BOTTOMRIGHT" },
}
group(healerCompact, "party", 4, { "BOTTOM", -302, 215 }, { "LEFT", 57, 0, "RIGHT" })
group(healerCompact, "arena", 3, { "TOPRIGHT", -50, -198 }, { "RIGHT", 0, -90, "RIGHT" })

local boxes = runesAbovePlate({})
group(boxes, "party", 4, { "TOPLEFT", 70, -135 }, { "LEFT", 0, -187, "LEFT" })
group(boxes, "arena", 3, { "TOPRIGHT", -150, -235 }, { "RIGHT", 0, -170, "RIGHT" })

local boxesCompact = merge(fullHD, fullHDCompact)
group(boxesCompact, "party", 4, { "TOPLEFT", 90, -175 }, { "LEFT", 0, -112, "LEFT" })
group(boxesCompact, "arena", 3, { "TOPRIGHT", -100, -200 }, { "RIGHT", 0, -170, "RIGHT" })

ns.LayoutPresets = {
	{
		key = "default",
		name = "Standard",
		desc = "FrostAtom UI's starting frame positions and sizes.",
		points = {},
	},
	{
		key = "fullhd",
		name = "FullHD",
		desc = "The standard layout fitted to a 1920x1080 screen: vertical bars on the left and right edges, cooldowns on both sides of the main bar, a smaller chat.",
		points = fullHD,
		settings = merge(SIDE_BAR_SETTINGS, FULLHD_CHAT),
		compact = {
			points = fullHDCompact,
		},
	},
	{
		key = "classic",
		name = "Classic",
		desc = "Like the default 3.3.5 interface: portraits in the top-left corner with party under them, the main bar next to the micro menu, vertical bars on the right edge.",
		points = classic,
		settings = merge({
			["actionBar.bar4.columns"] = 12,
			["actionBar.bar5.columns"] = 1,
			["chat.width"] = 360,
			["chat.height"] = 120,
		}),
		compact = {
			points = classicCompact,
			settings = merge(COMPACT_CHAT, CLASSIC_COMPACT_BARS),
		},
	},
	{
		key = "modern",
		name = "Modern",
		desc = "Player and target on both sides of the screen center above the bars, focus at the top, vertical bars on the right edge.",
		points = modern,
		settings = SIDE_BAR_SETTINGS,
		compact = {
			points = modernCompact,
			settings = COMPACT_CHAT,
		},
	},
	{
		key = "arena",
		name = "Arena",
		desc = "Everything close to the center: party and arena frames flank the character with castbars facing inward, cooldowns next to them, focus under the arena frames.",
		points = arena,
		compact = {
			points = arenaCompact,
			settings = COMPACT_CHAT,
		},
	},
	{
		key = "gladius",
		name = "Compact arena",
		desc = "Arena frames in the Gladius style: 180x40, castbar and cooldowns under each frame, auras on the left.",
		points = gladius,
		settings = GLADIUS_SETTINGS,
		compact = {
			points = gladiusCompact,
			settings = COMPACT_CHAT,
		},
	},
	{
		key = "boxes",
		name = "Large group frames",
		desc = "Party and arena frames as large rectangles without class icons, easy to click: 240x64 with larger text, crowd control in the middle of the frame. The rest is as in Standard, on a smaller screen as in FullHD.",
		points = boxes,
		settings = {
			["unitFrames.partyWidth"] = 240,
			["unitFrames.partyHeight"] = 64,
			["unitFrames.arenaWidth"] = 240,
			["unitFrames.arenaHeight"] = 64,
			["unitFrames.partyIconSide"] = "NONE",
			["unitFrames.arenaIconSide"] = "NONE",
			["unitFrames.partyTextSize"] = 13,
			["unitFrames.arenaTextSize"] = 13,
		},
		compact = {
			points = boxesCompact,
			settings = merge(SIDE_BAR_SETTINGS, FULLHD_CHAT),
		},
	},
	{
		key = "healer",
		name = "Healer",
		desc = "Party frames in a row above the action bars with castbars and cooldowns on top, player and target above the party.",
		points = healer,
		settings = {
			["unitFrames.partyCastbarWidth"] = 173,
		},
		compact = {
			points = healerCompact,
			settings = merge(COMPACT_CHAT, {
				["unitFrames.partyWidth"] = 160,
				["unitFrames.partyCastbarWidth"] = 133,
			}),
		},
	},
}
