local _, ns = ...

local L = FrostAtomUI.L

local function size(path, label, min, max, desc, enabledBy)
	return {
		path = path,
		label = label,
		type = "number",
		min = min,
		max = max,
		step = 1,
		desc = desc,
		enabledBy = enabledBy,
	}
end

local TAGS_DESC = L["Format [tag:color:8], where:"]
	.. "\n"
	.. L["tag: name, curhp, maxhp, misshp, perhp, curpp, maxpp, perpp, class, race, guild, level, afk, dnd, status"]
	.. "\n"
	.. L["color: class, reaction, hp, power, ffaaff"]
	.. "\n"
	.. L["8 - max letters"]

local function text(path, label, desc)
	return { path = path, label = label, type = "string", width = 260, maxLetters = 120, desc = desc }
end

local HEALTH_COLOR_VALUES = {
	{ "class", L["Class color"] },
	{ "health", L["Health percent"] },
}

local RIGHT_CLICK_VALUES = {
	{ "menu", L["Unit menu"] },
	{ "focus", L["Set focus"] },
	{ "none", L["Nothing"] },
}

ns.RegisterPage({
	key = "unitframes",
	name = L["Unit frames"],
	order = 20,
	enable = "unitFrames.enabled",
	schema = {
		{
			path = "unitFrames.enabled",
			label = L["Enable"],
			type = "toggle",
			reload = true,
			desc = L["Replace Blizzard unit frames."],
		},
		{ path = "unitFrames.showParty", label = L["Show party frames"], type = "toggle" },
		{ path = "unitFrames.showArena", label = L["Show arena frames"], type = "toggle" },
		{ path = "unitFrames.showBoss", label = L["Show boss frames"], type = "toggle" },
		{
			path = "unitFrames.showPet",
			label = L["Show pet frames"],
			type = "toggle",
			desc = L["Square pet frames next to the player, party and arena frames."],
		},
		{
			path = "unitFrames.showPartyCooldowns",
			label = L["Show party cooldowns"],
			type = "toggle",
			enabledBy = "unitFrames.showParty",
			desc = L["Tracked cooldown icons to the right of party debuffs."],
		},
		{
			path = "unitFrames.showArenaCooldowns",
			label = L["Show arena cooldowns"],
			type = "toggle",
			enabledBy = "unitFrames.showArena",
			desc = L["Tracked cooldown icons to the left of arena debuffs."],
		},
		{
			path = "unitFrames.rightClick",
			label = L["Right click"],
			type = "select",
			values = RIGHT_CLICK_VALUES,
			desc = L["Action on right-clicking a frame. Arena frames always set focus."],
		},
		{
			path = "unitFrames.hoverHighlight",
			label = L["Highlight on mouseover"],
			type = "toggle",
			desc = L["Light overlay on the frame under the cursor."],
		},
		{
			path = "unitFrames.hoverAlpha",
			label = L["Mouseover highlight alpha"],
			type = "number",
			min = 0.02,
			max = 0.5,
			step = 0.02,
			enabledBy = "unitFrames.hoverHighlight",
		},
		{
			path = "unitFrames.healthCutaway",
			label = L["Health loss flash"],
			type = "toggle",
			desc = L["Fading strip over the part of the health bar that was just lost."],
		},
		{
			label = L["Test frames"],
			type = "execute",
			text = L["Toggle"],
			desc = L["Show every frame with fake units to preview the layout."],
			func = function()
				SlashCmdList.FROSTATOMUI_UNITFRAME_TEST()
			end,
		},
		{
			label = L["Test cooldowns"],
			type = "execute",
			text = L["Toggle"],
			desc = L["Start fake cooldowns on party and arena frames to preview the layout."],
			func = function()
				SlashCmdList.FROSTATOMUI_COOLDOWN_TEST()
			end,
		},
		{ header = L["Indicators"] },
		{
			path = "unitFrames.showClassIcon",
			label = L["Class / spec icon"],
			type = "toggle",
			desc = L["Square icon on the side of the frame. Portrait for non-player units."],
		},
		{
			path = "unitFrames.showLeaderIcon",
			label = L["Leader icon"],
			type = "toggle",
			desc = L["Crown in the corner of the party leader's frame."],
		},
		{ path = "unitFrames.showCombatIcon", label = L["Combat icon"], type = "toggle" },
		{
			path = "unitFrames.showRestingIcon",
			label = L["Resting icon"],
			type = "toggle",
			desc = L["Player frame only."],
		},
		{
			path = "unitFrames.showPvpIcon",
			label = L["PvP flag icon"],
			type = "toggle",
			desc = L["Faction icon on the player, target and focus frames when PvP flagged."],
		},
		{ path = "unitFrames.showRaidIcon", label = L["Raid target icon"], type = "toggle" },
		size("unitFrames.raidIconSize", L["Raid target icon size"], 10, 40, nil, "unitFrames.showRaidIcon"),
		{
			path = "unitFrames.showLoseControl",
			label = L["Crowd control icon"],
			type = "toggle",
			desc = L["Icon and timer of the longest crowd control effect over the class icon; a separate large icon for the player."],
		},
		{
			path = "unitFrames.loseControlPoint",
			label = L["Player crowd control position"],
			type = "point",
			enabledBy = "unitFrames.showLoseControl",
		},
		size("unitFrames.loseControlSize", L["Player crowd control size"], 20, 100, nil, "unitFrames.showLoseControl"),
		{ header = L["Positions"] },
		{ path = "unitFrames.player", label = L["Player"], type = "point" },
		{ path = "unitFrames.target", label = L["Target"], type = "point" },
		{ path = "unitFrames.focus", label = L["Focus"], type = "point" },
		{
			path = "unitFrames.pet",
			label = L["Pet"],
			type = "point",
			enabledBy = "unitFrames.showPet",
			desc = L["Attached to the player frame by default."],
		},
		{
			path = "unitFrames.targetOfTarget",
			label = L["Target of target"],
			type = "point",
			desc = L["Attached to the target frame by default."],
		},
		{
			path = "unitFrames.focusTarget",
			label = L["Target of focus"],
			type = "point",
			desc = L["Attached to the focus frame by default."],
		},
		{
			path = "unitFrames.playerCastbar",
			label = L["Player castbar"],
			type = "point",
			desc = L["Relative to the bottom of the player plate."],
		},
		{
			path = "unitFrames.playerAuras",
			label = L["Player buffs / debuffs"],
			type = "point",
			desc = L["Buffs grow to the left from this point, debuffs go below the buffs."],
		},
		{ path = "unitFrames.party", label = L["Party"], type = "point", enabledBy = "unitFrames.showParty" },
		{ path = "unitFrames.arena", label = L["Arena"], type = "point", enabledBy = "unitFrames.showArena" },
		{
			path = "unitFrames.groupSpacing",
			label = L["Party / arena spacing"],
			type = "number",
			min = 40,
			max = 300,
			step = 1,
			desc = L["Vertical distance between the tops of consecutive party or arena frames."],
		},
		{ path = "unitFrames.boss", label = L["Boss"], type = "point", enabledBy = "unitFrames.showBoss" },
		{
			path = "unitFrames.bossSpacing",
			label = L["Boss spacing"],
			type = "number",
			min = 40,
			max = 200,
			step = 1,
			desc = L["Vertical distance between the tops of consecutive boss frames."],
			enabledBy = "unitFrames.showBoss",
		},
		{ header = L["Frame sizes"] },
		size("unitFrames.playerWidth", L["Player / target width"], 120, 320, L["Also focus."]),
		size(
			"unitFrames.playerHeight",
			L["Player / target height"],
			30,
			80,
			L["Also focus, pet and target of target."]
		),
		size("unitFrames.partyWidth", L["Party width"], 120, 320, nil, "unitFrames.showParty"),
		size("unitFrames.partyHeight", L["Party height"], 30, 80, nil, "unitFrames.showParty"),
		size("unitFrames.arenaWidth", L["Arena width"], 120, 320, nil, "unitFrames.showArena"),
		size("unitFrames.arenaHeight", L["Arena height"], 30, 80, nil, "unitFrames.showArena"),
		size("unitFrames.bossWidth", L["Boss width"], 120, 320, nil, "unitFrames.showBoss"),
		size("unitFrames.bossHeight", L["Boss height"], 30, 80, nil, "unitFrames.showBoss"),
		{
			path = "unitFrames.powerRatio",
			label = L["Power bar height"],
			type = "number",
			min = 0.1,
			max = 0.5,
			step = 0.05,
			desc = L["Fraction of the frame height taken by the power bar."],
		},
		{ header = L["Element sizes"] },
		{
			path = "unitFrames.playerCastbarWidth",
			label = L["Player castbar width"],
			type = "number",
			min = 100,
			max = 500,
			step = 1,
		},
		{
			path = "unitFrames.playerCastbarHeight",
			label = L["Player castbar height"],
			type = "number",
			min = 10,
			max = 50,
			step = 1,
		},
		{
			path = "unitFrames.playerAuraSize",
			label = L["Player aura size"],
			type = "number",
			min = 16,
			max = 60,
			step = 1,
		},
		size("unitFrames.comboPointSize", L["Combo point size"], 4, 20, L["Dots above the target frame."]),
		size(
			"unitFrames.groupDebuffSize",
			L["Party / arena debuff size"],
			16,
			60,
			L["Rounded so a whole number of icons fits the frame width."]
		),
		size(
			"unitFrames.groupDebuffMax",
			L["Party / arena debuff limit"],
			1,
			40,
			L["Most debuffs shown per frame; the rest are dropped."]
		),
		size(
			"unitFrames.partyBuffSize",
			L["Party buff size"],
			10,
			40,
			L["Rounded so a whole number of icons fits the frame width."],
			"unitFrames.showParty"
		),
		size(
			"unitFrames.partyBuffMax",
			L["Party buff limit"],
			1,
			40,
			L["Most buffs shown per party frame; the rest are dropped."],
			"unitFrames.showParty"
		),
		size(
			"unitFrames.gridGap",
			L["Party / arena icon gap"],
			0,
			20,
			L["Space between the frame, its debuffs, buffs and cooldown icons."]
		),
		{
			path = "unitFrames.partyCooldownSize",
			label = L["Party cooldown size"],
			type = "number",
			min = 12,
			max = 48,
			step = 1,
			enabledBy = "unitFrames.showPartyCooldowns",
		},
		{
			path = "unitFrames.arenaCooldownSize",
			label = L["Arena cooldown size"],
			type = "number",
			min = 12,
			max = 48,
			step = 1,
			enabledBy = "unitFrames.showArenaCooldowns",
		},
		{
			path = "arenaTrinket.enabled",
			label = L["Show arena trinkets"],
			type = "toggle",
			enabledBy = "unitFrames.showArena",
			desc = L["PvP trinket cooldown icon next to each arena frame."],
		},
		{
			path = "arenaTrinket.size",
			label = L["Arena trinket size"],
			type = "number",
			min = 16,
			max = 60,
			step = 1,
			enabledBy = { "unitFrames.showArena", "arenaTrinket.enabled" },
		},
		{ header = L["Colors"] },
		{
			path = "unitFrames.healthColorMode",
			label = L["Health bar color"],
			type = "select",
			values = HEALTH_COLOR_VALUES,
			desc = L["Class color for players (everything else keeps the health gradient), or a color mixed from the current health percent for every unit."],
		},
		{ path = "unitFrames.textColor", label = L["Text"], type = "color" },
		{ path = "unitFrames.backdropColor", label = L["Backdrop"], type = "color", alpha = true },
		{ path = "unitFrames.borderColor", label = L["Border"], type = "color" },
		{ path = "unitFrames.targetBorderColor", label = L["Border (target)"], type = "color" },
		{ path = "unitFrames.focusBorderColor", label = L["Border (focus)"], type = "color" },
		{ path = "unitFrames.castbarColor", label = L["Castbar"], type = "color" },
		{ path = "unitFrames.castbarLockedColor", label = L["Castbar (not interruptible)"], type = "color" },
		{
			path = "unitFrames.healthCutawayColor",
			label = L["Health loss flash"],
			type = "color",
			alpha = true,
			enabledBy = "unitFrames.healthCutaway",
		},
		{ path = "unitFrames.comboPointColor", label = L["Combo points (full)"], type = "color" },
		{ path = "unitFrames.comboPointPartialColor", label = L["Combo points"], type = "color" },
		{
			path = "unitFrames.cooldownGlowColor",
			label = L["Cooldown glow"],
			type = "color",
			desc = L["Glow around a cooldown icon while the spell's effect is still active."],
		},
		{ header = L["Text"] },
		{ description = TAGS_DESC },
		{
			path = "unitFrames.textFont",
			label = L["Text font"],
			type = "font",
			desc = L["Name, health and power text."],
		},
		{ path = "unitFrames.castbarFont", label = L["Castbar font"], type = "font" },
		text("unitFrames.leftText", L["Left text"], L["Bottom-left of the health bar."]),
		text("unitFrames.leftTextHover", L["Left text (mouseover)"], L["Empty to keep the left text on mouseover."]),
		text("unitFrames.rightText", L["Right text"], L["Bottom-right of the health bar."]),
		text("unitFrames.rightTextHover", L["Right text (mouseover)"], L["Empty to keep the right text on mouseover."]),
		text("unitFrames.powerText", L["Power text"], L["Right side of the power bar."]),
		text("unitFrames.powerTextHover", L["Power text (mouseover)"], L["Empty to keep the power text on mouseover."]),
		{ header = L["Visibility"] },
		{
			path = "unitFrames.outOfRangeAlpha",
			label = L["Out of range alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			desc = L["Party and arena frames fade to this alpha when the unit is out of range."],
		},
	},
})
