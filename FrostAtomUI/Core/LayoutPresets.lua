local _, ns = ...

ns.COMPACT_SCREEN_HEIGHT = 1000

ns.LayoutSettings = {
	"actionBar.bar1.columns",
	"actionBar.bar1.buttonSize",
	"actionBar.bar2.columns",
	"actionBar.bar2.buttonSize",
	"actionBar.bar3.columns",
	"actionBar.bar3.buttonSize",
	"actionBar.bar4.columns",
	"actionBar.bar4.buttonSize",
	"actionBar.bar5.columns",
	"actionBar.bar5.buttonSize",
	"actionBar.bar6.columns",
	"actionBar.bar6.buttonSize",
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
	"unitFrames.playerIconSide",
	"unitFrames.targetIconSide",
	"unitFrames.focusIconSide",
	"unitFrames.partyIconSide",
	"unitFrames.arenaIconSide",
	"raidFrames.width",
	"raidFrames.height",
	"raidFrames.unitsPerColumn",
	"raidFrames.orientation",
	"raidFrames.growthX",
	"raidFrames.growthY",
	"groupCooldowns.friendlyGrowth",
	"groupCooldowns.enemyGrowth",
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

local COMPACT_CHAT = {
	["chat.width"] = 300,
	["chat.height"] = 120,
}

local function settings(...)
	local result = {}
	for i = 1, select("#", ...) do
		for path, value in pairs((select(i, ...))) do
			result[path] = value
		end
	end
	return result
end

local fullHD = edgeBars({
	["groupCooldowns.friendlyPoint"] = { "BOTTOMRIGHT", -235, 2, nil, "BOTTOM" },
	["groupCooldowns.enemyPoint"] = { "BOTTOMLEFT", 235, 2, nil, "BOTTOM" },
})

local modern = sideBars({
	["actionBar.stance.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar3.point", "TOPLEFT" },
	["actionBar.totemBar.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar3.point", "TOPLEFT" },
	["actionBar.pet.point"] = { "BOTTOMRIGHT", 0, 4, "actionBar.bar3.point", "TOPRIGHT" },
	["actionBar.vehicleExit.point"] = { "BOTTOMLEFT", 4, 0, "actionBar.bar3.point", "BOTTOMRIGHT" },
	["unitFrames.player"] = { "BOTTOM", -300, 350 },
	["unitFrames.target"] = { "BOTTOM", 300, 350 },
	["unitFrames.focus"] = { "TOP", 0, -80 },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 190 },
	["groupCooldowns.friendlyPoint"] = { "BOTTOMRIGHT", -235, 2, nil, "BOTTOM" },
	["groupCooldowns.enemyPoint"] = { "BOTTOMLEFT", 235, 2, nil, "BOTTOM" },
	["tweaks.worldStatePoint"] = { "TOP", 0, -30 },
})
group(modern, "party", 4, { "TOPLEFT", 100, -180 }, { "LEFT", 0, -160, "LEFT" })
group(modern, "arena", 3, { "TOPRIGHT", -200, -200 }, { "RIGHT", 0, -160, "RIGHT" })

local castbarDefensives = { "BOTTOM", 0, 8, "unitFrames.playerCastbar", "TOP" }

local modernCompact = {
	["unitFrames.party"] = { "TOPLEFT", 100, -40 },
	["unitFrames.arena"] = { "TOPRIGHT", -150, -200 },
	["unitFrames.player"] = { "BOTTOM", -280, 320 },
	["unitFrames.target"] = { "BOTTOM", 280, 320 },
	["unitFrames.targetCastbar"] = { "BOTTOMLEFT", 27, 4, "unitFrames.target", "TOPLEFT" },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 160 },
	["externalDefensives.point"] = castbarDefensives,
	["tweaks.worldStatePoint"] = { "TOP", 0, -5 },
}

local classic = sideBars({
	["actionBar.bar1.point"] = { "BOTTOM", -230, 2 },
	["actionBar.bar2.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar1.point", "TOPLEFT" },
	["actionBar.bar3.point"] = { "BOTTOMLEFT", 6, 0, "actionBar.bar2.point", "BOTTOMRIGHT" },
	["actionBar.microMenu"] = { "BOTTOMLEFT", 6, 0, "actionBar.bar1.point", "BOTTOMRIGHT" },
	["actionBar.bagButton"] = { "LEFT", 6, 0, "actionBar.microMenu", "RIGHT" },
	["actionBar.stance.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar2.point", "TOPLEFT" },
	["actionBar.totemBar.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar2.point", "TOPLEFT" },
	["actionBar.pet.point"] = { "BOTTOMLEFT", 0, 4, "actionBar.bar3.point", "TOPLEFT" },
	["actionBar.vehicleExit.point"] = { "BOTTOMRIGHT", 0, 4, "actionBar.bar3.point", "TOPRIGHT" },
	["unitFrames.player"] = { "TOPLEFT", 100, -40 },
	["unitFrames.target"] = { "LEFT", 70, 0, "unitFrames.player", "RIGHT" },
	["unitFrames.focus"] = { "LEFT", 70, 0, "unitFrames.target", "RIGHT" },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 150 },
	["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, 0, "unitFrames.party", "TOPRIGHT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, 0, "unitFrames.arena", "TOPLEFT" },
	["tweaks.worldStatePoint"] = { "TOP", 0, -5 },
})
group(classic, "party", 4, { "TOPLEFT", 100, -260 }, { "LEFT", 0, -160, "LEFT" })
group(classic, "arena", 3, { "TOPRIGHT", -200, -250 }, { "RIGHT", 0, -160, "RIGHT" })

local classicCompact = {
	["actionBar.bar1.point"] = { "BOTTOM", -150, 2 },
	["unitFrames.player"] = { "TOPLEFT", 270, -40 },
	["unitFrames.party"] = { "TOPLEFT", 100, -135 },
	["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, -310, "unitFrames.party", "TOPRIGHT" },
	["externalDefensives.point"] = castbarDefensives,
}

local vehicleExitLeft = { "BOTTOMRIGHT", -4, 0, "actionBar.bar4.point", "BOTTOMLEFT" }

local arena = {
	["actionBar.vehicleExit.point"] = vehicleExitLeft,
	["unitFrames.player"] = { "BOTTOM", -250, 240 },
	["unitFrames.target"] = { "BOTTOM", 250, 240 },
	["unitFrames.targetCastbar"] = { "BOTTOMLEFT", 27, 4, "unitFrames.target", "TOPLEFT" },
	["unitFrames.focus"] = { "TOPRIGHT", 0, -100, "unitFrames.arena3", "BOTTOMRIGHT" },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 160 },
	["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, 0, "unitFrames.party", "TOPRIGHT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, 0, "unitFrames.arena", "TOPLEFT" },
	["tweaks.worldStatePoint"] = { "TOP", 0, -30 },
}
group(arena, "party", 4, { "TOP", -520, -170 }, { "LEFT", 0, -160, "LEFT" })
group(arena, "arena", 3, { "TOP", 520, -170 }, { "RIGHT", 0, -160, "RIGHT" })

local arenaCompact = {
	["unitFrames.party"] = { "TOP", -540, -150 },
	["unitFrames.arena"] = { "TOP", 500, -200 },
	["unitFrames.focus"] = { "TOP", 0, -60 },
	["groupCooldowns.friendlyPoint"] = { "TOPLEFT", 260, -120, "unitFrames.party", "TOPRIGHT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, -120, "unitFrames.arena", "TOPLEFT" },
	["externalDefensives.point"] = castbarDefensives,
	["tweaks.worldStatePoint"] = { "TOP", 0, -5 },
}

local healer = {
	["actionBar.vehicleExit.point"] = vehicleExitLeft,
	["unitFrames.player"] = { "BOTTOM", -280, 460 },
	["unitFrames.target"] = { "BOTTOM", 280, 460 },
	["unitFrames.targetCastbar"] = { "BOTTOMLEFT", 27, 4, "unitFrames.target", "TOPLEFT" },
	["unitFrames.focus"] = { "TOP", -200, -60 },
	["playerPlate.point"] = { "BOTTOM", 0, 360 },
	["unitFrames.playerCastbar"] = { "BOTTOM", 0, 4, "playerPlate.point", "TOP" },
	["shieldIndicator.point"] = { "RIGHT", -4, 0, "playerPlate.point", "LEFT" },
	["groupCooldowns.friendlyPoint"] = { "BOTTOMRIGHT", -55, 0, "unitFrames.party", "BOTTOMLEFT" },
	["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -260, 0, "unitFrames.arena", "TOPLEFT" },
	["externalDefensives.point"] = { "RIGHT", -8, 0, "unitFrames.pet", "LEFT" },
	["tweaks.worldStatePoint"] = { "TOP", 0, -5 },
}
group(healer, "party", 4, { "BOTTOM", -371, 270 }, { "LEFT", 95, 0, "RIGHT" })
group(healer, "arena", 3, { "TOPRIGHT", -200, -200 }, { "RIGHT", 0, -160, "RIGHT" })
each(healer, "party", 4, "Castbar", { "BOTTOMLEFT", 27, 4, "TOPLEFT" })

local healerCompact = {}
group(healerCompact, "party", 4, { "BOTTOM", -366, 270 }, { "LEFT", 60, 0, "RIGHT" })
group(healerCompact, "arena", 3, { "TOPRIGHT", -120, -230 }, { "RIGHT", 0, -160, "RIGHT" })
each(healerCompact, "arena", 3, "Castbar", { "BOTTOMRIGHT", 0, 4, "TOPRIGHT" })
healerCompact["groupCooldowns.enemyPoint"] = { "TOPRIGHT", -68, 0, "unitFrames.arena", "TOPLEFT" }

ns.LayoutPresets = {
	{
		key = "default",
		name = "Defaults",
		desc = "The positions and sizes the Defaults button sets: the default layout of FrostAtom UI.",
		points = {},
	},
	{
		key = "fullhd",
		name = "FullHD",
		desc = "Defaults fitted to a 1920x1080 screen: vertical bars on the left and right edges, cooldowns on both sides of the main bar, a smaller chat.",
		points = fullHD,
		settings = settings(SIDE_BAR_SETTINGS, COMPACT_CHAT, { ["chat.height"] = 100 }),
	},
	{
		key = "classic",
		name = "Classic",
		desc = "Like the default 3.3.5 interface: portraits in the top-left corner with party under them, the main bar next to the micro menu, vertical bars on the right edge.",
		points = classic,
		settings = settings(SIDE_BAR_SETTINGS, {
			["chat.width"] = 360,
			["chat.height"] = 120,
		}),
		compact = {
			points = classicCompact,
			settings = COMPACT_CHAT,
		},
	},
	{
		key = "modern",
		name = "Modern",
		desc = "Like the retail Edit Mode layout: player and target on both sides of the screen center above the bars, focus at the top, vertical bars on the right edge.",
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
		key = "healer",
		name = "Healer",
		desc = "Party frames in a row above the action bars with castbars on top, player and target above the party.",
		points = healer,
		settings = {
			["unitFrames.partyCastbarWidth"] = 173,
		},
		compact = {
			points = healerCompact,
			settings = COMPACT_CHAT,
		},
	},
}
