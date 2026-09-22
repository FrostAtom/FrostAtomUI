local _, ns = ...

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

local TAGS_DESC = "Format [tag:color:8], where:\n"
	.. "tag: name, curhp, maxhp, misshp, perhp, curpp, maxpp, perpp, class, race, guild, level, afk, dnd, status\n"
	.. "color: class, reaction, hp, power, ffaaff\n"
	.. "8 - max letters"

local function text(path, label, desc)
	return { path = path, label = label, type = "string", width = 260, maxLetters = 120, desc = desc }
end

local HEALTH_COLOR_VALUES = {
	{ "class", "Class color" },
	{ "health", "Health percent" },
}

local RIGHT_CLICK_VALUES = {
	{ "menu", "Unit menu" },
	{ "focus", "Set focus" },
	{ "none", "Nothing" },
}

ns.RegisterPage({
	key = "unitframes",
	name = "Unit frames",
	order = 20,
	enable = "unitFrames.enabled",
	schema = {
		{
			path = "unitFrames.enabled",
			label = "Enable",
			type = "toggle",
			reload = true,
			desc = "Replace Blizzard unit frames.",
		},
		{ path = "unitFrames.showParty", label = "Show party frames", type = "toggle" },
		{ path = "unitFrames.showArena", label = "Show arena frames", type = "toggle" },
		{ path = "unitFrames.showBoss", label = "Show boss frames", type = "toggle" },
		{
			path = "unitFrames.showPet",
			label = "Show pet frames",
			type = "toggle",
			desc = "Square pet frames next to the player, party and arena frames.",
		},
		{
			path = "unitFrames.showPartyCooldowns",
			label = "Show party cooldowns",
			type = "toggle",
			enabledBy = "unitFrames.showParty",
			desc = "Tracked cooldown icons to the right of party debuffs.",
		},
		{
			path = "unitFrames.showArenaCooldowns",
			label = "Show arena cooldowns",
			type = "toggle",
			enabledBy = "unitFrames.showArena",
			desc = "Tracked cooldown icons to the left of arena debuffs.",
		},
		{
			path = "unitFrames.rightClick",
			label = "Right click",
			type = "select",
			values = RIGHT_CLICK_VALUES,
			desc = "Action on right-clicking a frame. Arena frames always set focus.",
		},
		{
			path = "unitFrames.hoverHighlight",
			label = "Highlight on mouseover",
			type = "toggle",
			desc = "Light overlay on the frame under the cursor.",
		},
		{
			path = "unitFrames.hoverAlpha",
			label = "Mouseover highlight alpha",
			type = "number",
			min = 0.02,
			max = 0.5,
			step = 0.02,
			enabledBy = "unitFrames.hoverHighlight",
		},
		{
			path = "unitFrames.healthCutaway",
			label = "Health loss flash",
			type = "toggle",
			desc = "Fading strip over the part of the health bar that was just lost.",
		},
		{
			label = "Test frames",
			type = "execute",
			text = "Toggle",
			desc = "Show every frame with fake units to preview the layout.",
			func = function()
				SlashCmdList.FROSTATOMUI_UNITFRAME_TEST()
			end,
		},
		{
			label = "Test cooldowns",
			type = "execute",
			text = "Toggle",
			desc = "Start fake cooldowns on party and arena frames to preview the layout.",
			func = function()
				SlashCmdList.FROSTATOMUI_COOLDOWN_TEST()
			end,
		},
		{ header = "Indicators" },
		{
			path = "unitFrames.showClassIcon",
			label = "Class / spec icon",
			type = "toggle",
			desc = "Square icon on the side of the frame. Portrait for non-player units.",
		},
		{
			path = "unitFrames.showLeaderIcon",
			label = "Leader icon",
			type = "toggle",
			desc = "Crown in the corner of the party leader's frame.",
		},
		{ path = "unitFrames.showCombatIcon", label = "Combat icon", type = "toggle" },
		{
			path = "unitFrames.showRestingIcon",
			label = "Resting icon",
			type = "toggle",
			desc = "Player frame only.",
		},
		{
			path = "unitFrames.showPvpIcon",
			label = "PvP flag icon",
			type = "toggle",
			desc = "Faction icon on the player, target and focus frames when PvP flagged.",
		},
		{ path = "unitFrames.showRaidIcon", label = "Raid target icon", type = "toggle" },
		size("unitFrames.raidIconSize", "Raid target icon size", 10, 40, nil, "unitFrames.showRaidIcon"),
		{
			path = "unitFrames.showLoseControl",
			label = "Crowd control icon",
			type = "toggle",
			desc = "Icon and timer of the longest crowd control effect over the class icon; "
				.. "a separate large icon for the player.",
		},
		{
			path = "unitFrames.loseControlPoint",
			label = "Player crowd control position",
			type = "point",
			enabledBy = "unitFrames.showLoseControl",
		},
		size("unitFrames.loseControlSize", "Player crowd control size", 20, 100, nil, "unitFrames.showLoseControl"),
		{ header = "Positions" },
		{ path = "unitFrames.player", label = "Player", type = "point" },
		{ path = "unitFrames.target", label = "Target", type = "point" },
		{ path = "unitFrames.focus", label = "Focus", type = "point" },
		{
			path = "unitFrames.pet",
			label = "Pet",
			type = "point",
			enabledBy = "unitFrames.showPet",
			desc = "Attached to the player frame by default.",
		},
		{
			path = "unitFrames.targetOfTarget",
			label = "Target of target",
			type = "point",
			desc = "Attached to the target frame by default.",
		},
		{
			path = "unitFrames.focusTarget",
			label = "Target of focus",
			type = "point",
			desc = "Attached to the focus frame by default.",
		},
		{
			path = "unitFrames.playerCastbar",
			label = "Player castbar",
			type = "point",
			desc = "Relative to the bottom of the player plate.",
		},
		{
			path = "unitFrames.playerAuras",
			label = "Player buffs / debuffs",
			type = "point",
			desc = "Buffs grow to the left from this point, debuffs go below the buffs.",
		},
		{ path = "unitFrames.party", label = "Party", type = "point", enabledBy = "unitFrames.showParty" },
		{ path = "unitFrames.arena", label = "Arena", type = "point", enabledBy = "unitFrames.showArena" },
		{
			path = "unitFrames.groupSpacing",
			label = "Party / arena spacing",
			type = "number",
			min = 40,
			max = 300,
			step = 1,
			desc = "Vertical distance between the tops of consecutive party or arena frames.",
		},
		{ path = "unitFrames.boss", label = "Boss", type = "point", enabledBy = "unitFrames.showBoss" },
		{
			path = "unitFrames.bossSpacing",
			label = "Boss spacing",
			type = "number",
			min = 40,
			max = 200,
			step = 1,
			desc = "Vertical distance between the tops of consecutive boss frames.",
			enabledBy = "unitFrames.showBoss",
		},
		{ header = "Frame sizes" },
		size("unitFrames.playerWidth", "Player / target width", 120, 320, "Also focus."),
		size("unitFrames.playerHeight", "Player / target height", 30, 80, "Also focus, pet and target of target."),
		size("unitFrames.partyWidth", "Party width", 120, 320, nil, "unitFrames.showParty"),
		size("unitFrames.partyHeight", "Party height", 30, 80, nil, "unitFrames.showParty"),
		size("unitFrames.arenaWidth", "Arena width", 120, 320, nil, "unitFrames.showArena"),
		size("unitFrames.arenaHeight", "Arena height", 30, 80, nil, "unitFrames.showArena"),
		size("unitFrames.bossWidth", "Boss width", 120, 320, nil, "unitFrames.showBoss"),
		size("unitFrames.bossHeight", "Boss height", 30, 80, nil, "unitFrames.showBoss"),
		{
			path = "unitFrames.powerRatio",
			label = "Power bar height",
			type = "number",
			min = 0.1,
			max = 0.5,
			step = 0.05,
			desc = "Fraction of the frame height taken by the power bar.",
		},
		{ header = "Element sizes" },
		{
			path = "unitFrames.playerCastbarWidth",
			label = "Player castbar width",
			type = "number",
			min = 100,
			max = 500,
			step = 1,
		},
		{
			path = "unitFrames.playerCastbarHeight",
			label = "Player castbar height",
			type = "number",
			min = 10,
			max = 50,
			step = 1,
		},
		{
			path = "unitFrames.playerAuraSize",
			label = "Player aura size",
			type = "number",
			min = 16,
			max = 60,
			step = 1,
		},
		size("unitFrames.comboPointSize", "Combo point size", 4, 20, "Dots above the target frame."),
		size(
			"unitFrames.groupDebuffSize",
			"Party / arena debuff size",
			16,
			60,
			"Rounded so a whole number of icons fits the frame width."
		),
		size(
			"unitFrames.groupDebuffMax",
			"Party / arena debuff limit",
			1,
			40,
			"Most debuffs shown per frame; the rest are dropped."
		),
		size(
			"unitFrames.partyBuffSize",
			"Party buff size",
			10,
			40,
			"Rounded so a whole number of icons fits the frame width.",
			"unitFrames.showParty"
		),
		size(
			"unitFrames.partyBuffMax",
			"Party buff limit",
			1,
			40,
			"Most buffs shown per party frame; the rest are dropped.",
			"unitFrames.showParty"
		),
		size(
			"unitFrames.gridGap",
			"Party / arena icon gap",
			0,
			20,
			"Space between the frame, its debuffs, buffs and cooldown icons."
		),
		{
			path = "unitFrames.partyCooldownSize",
			label = "Party cooldown size",
			type = "number",
			min = 12,
			max = 48,
			step = 1,
			enabledBy = "unitFrames.showPartyCooldowns",
		},
		{
			path = "unitFrames.arenaCooldownSize",
			label = "Arena cooldown size",
			type = "number",
			min = 12,
			max = 48,
			step = 1,
			enabledBy = "unitFrames.showArenaCooldowns",
		},
		{
			path = "arenaTrinket.enabled",
			label = "Show arena trinkets",
			type = "toggle",
			enabledBy = "unitFrames.showArena",
			desc = "PvP trinket cooldown icon next to each arena frame.",
		},
		{
			path = "arenaTrinket.size",
			label = "Arena trinket size",
			type = "number",
			min = 16,
			max = 60,
			step = 1,
			enabledBy = { "unitFrames.showArena", "arenaTrinket.enabled" },
		},
		{ header = "Colors" },
		{
			path = "unitFrames.healthColorMode",
			label = "Health bar color",
			type = "select",
			values = HEALTH_COLOR_VALUES,
			desc = "Class color for players (everything else keeps the health gradient), or a color mixed "
				.. "from the current health percent for every unit.",
		},
		{ path = "unitFrames.textColor", label = "Text", type = "color" },
		{ path = "unitFrames.backdropColor", label = "Backdrop", type = "color", alpha = true },
		{ path = "unitFrames.borderColor", label = "Border", type = "color" },
		{ path = "unitFrames.targetBorderColor", label = "Border (target)", type = "color" },
		{ path = "unitFrames.focusBorderColor", label = "Border (focus)", type = "color" },
		{ path = "unitFrames.castbarColor", label = "Castbar", type = "color" },
		{ path = "unitFrames.castbarLockedColor", label = "Castbar (not interruptible)", type = "color" },
		{
			path = "unitFrames.healthCutawayColor",
			label = "Health loss flash",
			type = "color",
			alpha = true,
			enabledBy = "unitFrames.healthCutaway",
		},
		{ path = "unitFrames.comboPointColor", label = "Combo points (full)", type = "color" },
		{ path = "unitFrames.comboPointPartialColor", label = "Combo points", type = "color" },
		{
			path = "unitFrames.cooldownGlowColor",
			label = "Cooldown glow",
			type = "color",
			desc = "Glow around a cooldown icon while the spell's effect is still active.",
		},
		{ header = "Text" },
		{ description = TAGS_DESC },
		{ path = "unitFrames.textFont", label = "Text font", type = "font", desc = "Name, health and power text." },
		{ path = "unitFrames.castbarFont", label = "Castbar font", type = "font" },
		text("unitFrames.leftText", "Left text", "Bottom-left of the health bar."),
		text("unitFrames.leftTextHover", "Left text (mouseover)", "Empty to keep the left text on mouseover."),
		text("unitFrames.rightText", "Right text", "Bottom-right of the health bar."),
		text("unitFrames.rightTextHover", "Right text (mouseover)", "Empty to keep the right text on mouseover."),
		text("unitFrames.powerText", "Power text", "Right side of the power bar."),
		text("unitFrames.powerTextHover", "Power text (mouseover)", "Empty to keep the power text on mouseover."),
		{ header = "Visibility" },
		{
			path = "unitFrames.outOfRangeAlpha",
			label = "Out of range alpha",
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			desc = "Party and arena frames fade to this alpha when the unit is out of range.",
		},
	},
})
