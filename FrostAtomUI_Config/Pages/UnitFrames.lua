local _, ns = ...

local L = FrostAtomUI.L

local Requires = ns.Requires

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
	.. L["tag: name, curhp, maxhp, misshp, perhp, curpp, maxpp, perpp, druidmana, class, race, guild, level, afk, dnd, status"]
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

local VERTICAL_GROWTH_VALUES = {
	{ "DOWN", L["Down"] },
	{ "UP", L["Up"] },
}

local HORIZONTAL_GROWTH_VALUES = {
	{ "LEFT", L["To the left"] },
	{ "RIGHT", L["To the right"] },
}

local CAST_TIME_VALUES = {
	{ "remaining", L["Remaining"] },
	{ "total", L["Remaining / total"] },
}

local BUFF_SORT_VALUES = {
	{ "default", L["Default"] },
	{ "own", L["Yours first"] },
	{ "time", L["Shortest remaining first"] },
}

local function testFramesButton()
	return {
		label = L["Test frames"],
		type = "execute",
		text = L["Toggle"],
		desc = L["Show every frame with fake units to preview the layout."],
		func = function()
			SlashCmdList.FROSTATOMUI_UNITFRAME_TEST()
		end,
	}
end

local function testCooldownsButton()
	return {
		label = L["Test cooldowns"],
		type = "execute",
		text = L["Toggle"],
		desc = L["Start fake cooldowns on party and arena frames to preview the layout."],
		func = function()
			SlashCmdList.FROSTATOMUI_COOLDOWN_TEST()
		end,
	}
end

local function mainFrameSize()
	return {
		{ header = L["Size"] },
		size("unitFrames.playerWidth", L["Player / target width"], 120, 320, L["Also focus."]),
		size(
			"unitFrames.playerHeight",
			L["Player / target height"],
			30,
			80,
			L["Also focus, pet and target of target."]
		),
	}
end

local function targetAurasPerRow()
	return {
		path = "unitFrames.targetAuraPerRow",
		new = "1.4.0",
		label = L["Auras per row"],
		type = "number",
		min = 4,
		max = 12,
		step = 1,
		desc = L["Buffs and debuffs under the target and focus frames, up to two rows each. More per row means smaller icons."],
	}
end

local function ownAuraScale()
	return {
		path = "unitFrames.ownAuraScale",
		new = "1.4.1",
		label = L["Your auras size"],
		type = "number",
		min = 1,
		max = 2,
		step = 0.05,
		desc = L["Scale of the buffs and debuffs cast by you, your pet or vehicle under the target and focus frames. 1 keeps them the same size as the rest."],
	}
end

local function castbarToggle(path)
	return { path = path, new = "1.4.0", label = L["Show castbar"], type = "toggle" }
end

local function groupDebuffEntries()
	return {
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
			"unitFrames.gridGap",
			L["Party / arena icon gap"],
			0,
			20,
			L["Space between the frame, its debuffs, buffs and cooldown icons."]
		),
	}
end

local GROUP_GROWTH_VALUES = {
	{ "DOWN", L["Down"] },
	{ "UP", L["Up"] },
	{ "RIGHT", L["To the right"] },
	{ "LEFT", L["To the left"] },
}

local function groupLayout(prefix, spacingPath, growthPath, horizontal)
	local spacing = horizontal
			and size(
				spacingPath,
				L["Spacing"],
				40,
				800,
				L["Distance between the tops of consecutive frames, or between their left edges when they grow sideways."]
			)
		or size(spacingPath, L["Spacing"], 40, 300, L["Vertical distance between the tops of consecutive frames."])
	return {
		{ header = L["Layout"] },
		size("unitFrames." .. prefix .. "Width", L["Width"], 120, 320),
		size("unitFrames." .. prefix .. "Height", L["Height"], 30, 80),
		spacing,
		{
			path = growthPath,
			new = "1.4.0",
			label = L["Growth direction"],
			type = "select",
			values = horizontal and GROUP_GROWTH_VALUES or VERTICAL_GROWTH_VALUES,
		},
	}
end

local function concat(...)
	local list = {}
	for i = 1, select("#", ...) do
		for _, entry in ipairs((select(i, ...))) do
			list[#list + 1] = entry
		end
	end
	return list
end

ns.RegisterElement({
	path = "unitFrames.player",
	page = "unitframes",
	name = L["Player"],
	enabledBy = "unitFrames.enabled",
	schema = concat(mainFrameSize(), {
		{ header = L["Indicators"] },
		{ path = "unitFrames.showRestingIcon", label = L["Resting icon"], type = "toggle" },
		{
			path = "unitFrames.pvpTimer",
			new = "1.4.1",
			label = L["PvP flag timer"],
			type = "toggle",
			enabledBy = "unitFrames.showPvpIcon",
			desc = L["Time left until the PvP flag drops, under the PvP icon."],
		},
		{
			path = "unitFrames.druidMana",
			new = "1.4.1",
			label = L["Mana in shapeshift forms"],
			type = "toggle",
			hidden = ns.NotClass("DRUID"),
			desc = L["Mana value and percent on the left of the power bar while in bear or cat form."],
		},
		{
			path = "unitFrames.combatGlow",
			new = "1.4.1",
			label = L["Combat glow"],
			type = "toggle",
			desc = L["Pulsing glow around the player frame while in combat."],
		},
		{
			path = "unitFrames.combatGlowColor",
			new = "1.4.1",
			label = L["Combat glow color"],
			type = "color",
			enabledBy = "unitFrames.combatGlow",
		},
	}),
})

ns.RegisterElement({
	path = "unitFrames.target",
	page = "unitframes",
	name = L["Target"],
	enabledBy = "unitFrames.enabled",
	schema = concat(mainFrameSize(), {
		targetAurasPerRow(),
		ownAuraScale(),
		{ header = L["Castbar"] },
		castbarToggle("unitFrames.showTargetCastbar"),
		{ header = L["Combo points"] },
		size("unitFrames.comboPointSize", L["Combo point size"], 4, 20, L["Dots above the target frame."]),
		{ path = "unitFrames.comboPointColor", label = L["Combo points (full)"], type = "color" },
		{ path = "unitFrames.comboPointPartialColor", label = L["Combo points"], type = "color" },
	}),
})

ns.RegisterElement({
	path = "unitFrames.focus",
	page = "unitframes",
	name = L["Focus"],
	enabledBy = "unitFrames.enabled",
	schema = concat(mainFrameSize(), {
		targetAurasPerRow(),
		ownAuraScale(),
		{ header = L["Castbar"] },
		castbarToggle("unitFrames.showFocusCastbar"),
	}),
})

ns.RegisterElement({
	path = "unitFrames.pet",
	page = "unitframes",
	name = L["Pet"],
	enabledBy = { "unitFrames.enabled", "unitFrames.showPet" },
	schema = {
		{
			path = "unitFrames.showPet",
			label = L["Show pet frames"],
			type = "toggle",
			desc = L["Square pet frames next to the player, party and arena frames."],
		},
		{
			path = "unitFrames.petPower",
			new = "1.4.1",
			label = L["Show power bar"],
			type = "toggle",
			desc = L["Mana, focus or energy strip at the bottom of the pet frames."],
		},
		{
			path = "unitFrames.petHappiness",
			new = "1.4.1",
			label = L["Pet happiness"],
			type = "toggle",
			hidden = ns.NotClass("HUNTER"),
			desc = L["Happiness icon in the corner of your pet frame."],
		},
	},
})

ns.RegisterElement({
	path = "unitFrames.targetOfTarget",
	page = "unitframes",
	name = L["Target of target"],
	enabledBy = { "unitFrames.enabled", "unitFrames.showTargetOfTarget" },
	schema = {
		{ path = "unitFrames.showTargetOfTarget", new = "1.4.0", label = L["Show target of target"], type = "toggle" },
		{
			path = "unitFrames.hideTargetOfTargetSelf",
			new = "1.4.1",
			label = L["Hide when it is you"],
			type = "toggle",
			desc = L["Make the frame invisible while your target is targeting you. It still reacts to clicks, as secure frames cannot be hidden in combat."],
		},
	},
})

ns.RegisterElement({
	path = "unitFrames.focusTarget",
	page = "unitframes",
	name = L["Target of focus"],
	enabledBy = { "unitFrames.enabled", "unitFrames.showFocusTarget" },
	schema = {
		{ path = "unitFrames.showFocusTarget", new = "1.4.0", label = L["Show target of focus"], type = "toggle" },
	},
})

ns.RegisterElement({
	path = "unitFrames.playerCastbar",
	page = "unitframes",
	name = L["Player castbar"],
	enabledBy = "unitFrames.enabled",
	schema = {
		castbarToggle("unitFrames.showPlayerCastbar"),
		{ header = L["Size"] },
		size("unitFrames.playerCastbarWidth", L["Width"], 100, 500, nil, "unitFrames.showPlayerCastbar"),
		size("unitFrames.playerCastbarHeight", L["Height"], 10, 50, nil, "unitFrames.showPlayerCastbar"),
		{ header = L["Latency"] },
		{
			path = "unitFrames.castbarLatency",
			new = "1.4.1",
			label = L["Show latency"],
			type = "toggle",
			enabledBy = "unitFrames.showPlayerCastbar",
			desc = L["Shaded zone at the end of the cast as long as your latency: the next spell can be pressed once the bar enters it without cutting the current cast. Up to 40% of the bar, not shown for channels."],
		},
		{
			path = "unitFrames.castbarLatencyColor",
			new = "1.4.1",
			label = L["Latency color"],
			type = "color",
			alpha = true,
			enabledBy = { "unitFrames.showPlayerCastbar", "unitFrames.castbarLatency" },
		},
	},
})

ns.RegisterElement({
	path = "unitFrames.playerAuras",
	page = "unitframes",
	name = L["Player buffs / debuffs"],
	enabledBy = "unitFrames.enabled",
	schema = {
		{ header = L["Layout"] },
		{
			path = "unitFrames.playerAuraGrowth",
			new = "1.4.1",
			label = L["Growth direction"],
			type = "select",
			values = HORIZONTAL_GROWTH_VALUES,
			desc = L["Debuffs go below the buffs."],
		},
		{ header = L["Buffs"] },
		size("unitFrames.playerAuraSize", L["Icon size"], 16, 60),
		{
			path = "unitFrames.playerAuraPerRow",
			new = "1.4.0",
			label = L["Icons per row"],
			type = "number",
			min = 4,
			max = 20,
			step = 1,
		},
		{
			path = "unitFrames.playerBuffSort",
			new = "1.4.0",
			label = L["Buff order"],
			type = "select",
			values = BUFF_SORT_VALUES,
			desc = L["Right-click cancels a buff, in combat too. A sorted grid keeps the buff names it had when combat started, so after the order changes in combat a click may cancel a different buff."],
		},
		{ header = L["Debuffs"] },
		{
			path = "unitFrames.playerDebuffSize",
			new = "1.4.1",
			label = L["Icon size"],
			type = "number",
			min = 16,
			max = 60,
			step = 1,
		},
		{
			path = "unitFrames.playerDebuffPerRow",
			new = "1.4.1",
			label = L["Icons per row"],
			type = "number",
			min = 4,
			max = 20,
			step = 1,
		},
	},
})

ns.RegisterElement({
	path = "unitFrames.party",
	page = "unitframes",
	name = L["Party"],
	enabledBy = { "unitFrames.enabled", "unitFrames.showParty" },
	schema = Requires(
		"unitFrames.showParty",
		concat(
			groupLayout("party", "unitFrames.partySpacing", "unitFrames.partyGrowth", true),
			{
				{ header = L["Auras"] },
			},
			groupDebuffEntries(),
			{
				size(
					"unitFrames.partyBuffSize",
					L["Party buff size"],
					10,
					40,
					L["Rounded so a whole number of icons fits the frame width."]
				),
				size(
					"unitFrames.partyBuffMax",
					L["Party buff limit"],
					1,
					40,
					L["Most buffs shown per party frame; the rest are dropped."]
				),
				{ header = L["Cooldowns"] },
				{
					path = "unitFrames.showPartyCooldowns",
					label = L["Show party cooldowns"],
					type = "toggle",
					desc = L["Tracked cooldown icons to the right of party debuffs."],
				},
				size(
					"unitFrames.partyCooldownSize",
					L["Party cooldown size"],
					12,
					48,
					nil,
					"unitFrames.showPartyCooldowns"
				),
				{ header = L["Castbar"] },
				castbarToggle("unitFrames.showPartyCastbar"),
				{ header = L["Test"] },
				testFramesButton(),
				testCooldownsButton(),
			}
		)
	),
})

ns.RegisterElement({
	path = "unitFrames.arena",
	page = "unitframes",
	name = L["Arena"],
	enabledBy = { "unitFrames.enabled", "unitFrames.showArena" },
	schema = Requires(
		"unitFrames.showArena",
		concat(
			groupLayout("arena", "unitFrames.arenaSpacing", "unitFrames.arenaGrowth"),
			{
				{ header = L["Auras"] },
			},
			groupDebuffEntries(),
			{
				{ header = L["Cooldowns"] },
				{
					path = "unitFrames.showArenaCooldowns",
					label = L["Show arena cooldowns"],
					type = "toggle",
					desc = L["Tracked cooldown icons to the left of arena debuffs."],
				},
				size(
					"unitFrames.arenaCooldownSize",
					L["Arena cooldown size"],
					12,
					48,
					nil,
					"unitFrames.showArenaCooldowns"
				),
				{
					path = "arenaTrinket.enabled",
					label = L["Show arena trinkets"],
					type = "toggle",
					desc = L["PvP trinket cooldown icon next to each arena frame."],
				},
				size("arenaTrinket.size", L["Arena trinket size"], 16, 60, nil, "arenaTrinket.enabled"),
				{ header = L["Castbar"] },
				castbarToggle("unitFrames.showArenaCastbar"),
				{ header = L["Test"] },
				testFramesButton(),
				testCooldownsButton(),
			}
		)
	),
})

ns.RegisterElement({
	path = "unitFrames.boss",
	page = "unitframes",
	name = L["Boss"],
	enabledBy = { "unitFrames.enabled", "unitFrames.showBoss" },
	schema = Requires("unitFrames.showBoss", {
		{ header = L["Layout"] },
		size("unitFrames.bossWidth", L["Width"], 120, 320),
		size("unitFrames.bossHeight", L["Height"], 30, 80),
		size(
			"unitFrames.bossSpacing",
			L["Spacing"],
			40,
			200,
			L["Vertical distance between the tops of consecutive boss frames."]
		),
	}),
})

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
		{ path = "unitFrames.showTargetOfTarget", new = "1.4.0", label = L["Show target of target"], type = "toggle" },
		{ path = "unitFrames.showFocusTarget", new = "1.4.0", label = L["Show target of focus"], type = "toggle" },
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
		testFramesButton(),
		{ header = L["Frames"] },
		{ type = "elements" },
		{ header = L["Health bar"] },
		{
			path = "unitFrames.healthColorMode",
			label = L["Health bar color"],
			type = "select",
			values = HEALTH_COLOR_VALUES,
			desc = L["Class color for players (everything else keeps the health gradient), or a color mixed from the current health percent for every unit."],
		},
		{
			path = "unitFrames.healthCutaway",
			label = L["Health loss flash"],
			type = "toggle",
			desc = L["Fading strip over the part of the health bar that was just lost."],
		},
		{
			path = "unitFrames.healPrediction",
			new = "1.4.0",
			label = L["Incoming heals"],
			type = "toggle",
			desc = L["Segment after the health fill for heals being cast on the unit. Tracks your own casts and those of party members and arena opponents; amounts are learned from their landed heals."],
		},
		{
			path = "unitFrames.healPredictionSplit",
			new = "1.4.1",
			label = L["Split your heals"],
			type = "toggle",
			enabledByAny = { "unitFrames.healPrediction", "playerPlate.healPrediction" },
			desc = L["Show your own incoming heals first, in their own color, before the heals of others."],
		},
		{
			path = "unitFrames.absorbs",
			new = "1.4.0",
			label = L["Absorb shields"],
			type = "toggle",
			desc = L["Estimated remaining absorb from known shields (Power Word: Shield, Ice Barrier, Sacred Shield and others), reduced by the damage they absorb. A glow at the bar edge marks a shield that is up but larger than the missing health or of unknown size."],
		},
		{
			path = "unitFrames.powerRatio",
			label = L["Power bar height"],
			type = "number",
			min = 0.1,
			max = 0.5,
			step = 0.05,
			desc = L["Fraction of the frame height taken by the power bar."],
		},
		{ header = L["Arena"] },
		{
			path = "arenaUnseen.enabled",
			new = "1.4.0",
			label = L["Keep unseen arena opponents"],
			type = "toggle",
			enabledBy = "unitFrames.showArena",
			desc = L["Keep the arena frame of a stealthed or out-of-sight opponent, faded with greyed bars frozen at the last known values and a stealth icon next to it."],
		},
		{
			path = "arenaUnseen.alpha",
			new = "1.4.0",
			label = L["Unseen opponent alpha"],
			type = "number",
			min = 0.1,
			max = 1,
			step = 0.05,
			enabledBy = { "unitFrames.showArena", "arenaUnseen.enabled" },
		},
		{
			path = "arenaUnseen.prep",
			new = "1.4.0",
			label = L["Arena preparation frames"],
			type = "toggle",
			enabledBy = "unitFrames.showArena",
			desc = L["Placeholder frames for the expected opponents before the gates open, filled with class, spec and name as soon as an opponent is seen."],
		},
		{ header = L["Auras"] },
		{
			path = "unitFrames.auraTimers",
			new = "1.4.1",
			label = L["Show aura timers"],
			type = "toggle",
			desc = L["Remaining time on buff and debuff icons of the player, target, focus, party and arena frames."],
		},
		{
			path = "unitFrames.auraTimerMaxDuration",
			new = "1.4.1",
			label = L["Hide timers on auras longer than"],
			type = "number",
			min = 0,
			max = 3600,
			step = 30,
			enabledBy = "unitFrames.auraTimers",
			desc = L["In seconds, by the full aura duration; 0 shows the timer on every aura."],
		},
		{ header = L["Cooldowns"] },
		{
			path = "unitFrames.cooldownReadyFlash",
			new = "1.4.0",
			label = L["Cooldown ready flash"],
			type = "toggle",
			enabledByAny = { "unitFrames.showPartyCooldowns", "unitFrames.showArenaCooldowns" },
			desc = L["Short bright flash on a tracked cooldown icon as the ability becomes ready."],
		},
		{
			path = "unitFrames.cooldownGlowColor",
			label = L["Cooldown glow"],
			type = "color",
			enabledByAny = { "unitFrames.showPartyCooldowns", "unitFrames.showArenaCooldowns" },
			desc = L["Glow around a cooldown icon while the spell's effect is still active."],
		},
		testCooldownsButton(),
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
			desc = L["Icon and timer of the longest crowd control effect over the class icon of target, focus, party and arena frames."],
		},
		{ header = L["Castbar"] },
		{
			path = "unitFrames.castbarTargetName",
			new = "1.4.0",
			label = L["Show cast target"],
			type = "toggle",
			desc = L["Class-colored name of the caster's target on the right of the castbar."],
		},
		{
			path = "unitFrames.castbarTargetingYou",
			new = "1.4.0",
			label = L["Highlight casts on you"],
			type = "toggle",
			desc = L["Colored castbar border while an enemy casts at you."],
		},
		{
			path = "unitFrames.castbarImportant",
			new = "1.4.0",
			label = L["Pulse important casts"],
			type = "toggle",
			desc = L["Pulsing glow around the castbar for crowd control and heals."],
		},
		{
			path = "unitFrames.castbarInterrupter",
			new = "1.4.0",
			label = L["Show who interrupted"],
			type = "toggle",
			desc = L["Keep an interrupted castbar red for a second with the interrupter's name."],
		},
		{
			path = "unitFrames.castbarFinishFlash",
			new = "1.4.0",
			label = L["Flash on finished cast"],
			type = "toggle",
			desc = L["Short white flash when a cast completes."],
		},
		{
			path = "unitFrames.castbarTicks",
			new = "1.4.1",
			label = L["Channel ticks"],
			type = "toggle",
			desc = L["Marks on the castbar where the ticks of channeled spells (Drain Life, Mind Flay, Penance, Blizzard and others) land."],
		},
		{
			path = "unitFrames.castbarTimeFormat",
			new = "1.4.1",
			label = L["Cast time"],
			type = "select",
			values = CAST_TIME_VALUES,
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
		{ header = L["Colors"] },
		{ path = "unitFrames.textColor", label = L["Text"], type = "color" },
		{ path = "unitFrames.backdropColor", label = L["Backdrop"], type = "color", alpha = true },
		{ path = "unitFrames.borderColor", label = L["Border"], type = "color" },
		{
			path = "unitFrames.targetBorderColor",
			label = L["Border (target)"],
			type = "color",
			desc = L["Border of the party or arena frame of your current target."],
		},
		{
			path = "unitFrames.focusBorderColor",
			label = L["Border (focus)"],
			type = "color",
			desc = L["Border of the party or arena frame of your current focus."],
		},
		{ path = "unitFrames.castbarColor", label = L["Castbar"], type = "color" },
		{ path = "unitFrames.castbarLockedColor", label = L["Castbar (not interruptible)"], type = "color" },
		{
			path = "unitFrames.castbarTargetingYouColor",
			new = "1.4.0",
			label = L["Castbar border (targeting you)"],
			type = "color",
			enabledBy = "unitFrames.castbarTargetingYou",
			desc = L["Also used by nameplates."],
		},
		{
			path = "unitFrames.castbarImportantColor",
			new = "1.4.0",
			label = L["Castbar glow (important cast)"],
			type = "color",
			enabledBy = "unitFrames.castbarImportant",
			desc = L["Also used by nameplates."],
		},
		{
			path = "unitFrames.healthCutawayColor",
			label = L["Health loss flash"],
			type = "color",
			alpha = true,
			enabledBy = "unitFrames.healthCutaway",
		},
		{
			path = "unitFrames.healPredictionColor",
			new = "1.4.0",
			label = L["Incoming heals"],
			type = "color",
			alpha = true,
			enabledByAny = { "unitFrames.healPrediction", "playerPlate.healPrediction" },
		},
		{
			path = "unitFrames.healPredictionOwnColor",
			new = "1.4.1",
			label = L["Your incoming heals"],
			type = "color",
			alpha = true,
			enabledBy = "unitFrames.healPredictionSplit",
		},
		{
			path = "unitFrames.absorbColor",
			new = "1.4.0",
			label = L["Absorb shields"],
			type = "color",
			alpha = true,
			enabledByAny = { "unitFrames.absorbs", "playerPlate.absorbs" },
		},
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
