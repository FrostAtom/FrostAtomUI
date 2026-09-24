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

local HORIZONTAL_GROWTH_VALUES = {
	{ "LEFT", L["To the left"] },
	{ "RIGHT", L["To the right"] },
}

local CLASS_ICON_STYLE_VALUES = {
	{ "spec", L["Spec icon"] },
	{ "class", L["Class icon"] },
	{ "portrait", L["2D portrait"] },
	{ "model", L["3D portrait"] },
}

local ICON_SIDE_VALUES = {
	{ "LEFT", L["On the left"] },
	{ "RIGHT", L["On the right"] },
}

local function iconSide(unit)
	return {
		path = "unitFrames." .. unit .. "IconSide",
		new = "1.4.1",
		label = L["Class icon side"],
		type = "select",
		values = ICON_SIDE_VALUES,
		enabledBy = "unitFrames.showClassIcon",
	}
end

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
		glyph = "flask",
		desc = L["Show every frame with fake units to preview the layout."],
		func = function()
			SlashCmdList.FROSTATOMUI_UNITFRAME_TEST()
		end,
	}
end

local function showToggle(path, new)
	return { path = path, new = new, label = L["Show"], type = "toggle" }
end

local function layoutHeader()
	return { header = L["Layout"], glyph = "up-down-left-right" }
end

local function mainFrameLayout(unit)
	return {
		layoutHeader(),
		size("unitFrames.playerWidth", L["Width (player, target, focus)"], 120, 320),
		size("unitFrames.playerHeight", L["Height (player, target, focus)"], 30, 80),
		iconSide(unit),
	}
end

local function auraOrder(label)
	return {
		path = "unitFrames.auraOrder",
		new = "1.4.1",
		label = label,
		type = "select",
		values = {
			{ "debuffs", L["Debuffs on top"] },
			{ "buffs", L["Buffs on top"] },
		},
		desc = L["Which block comes first under the target, focus and party frames."],
	}
end

local function targetAuras()
	return {
		{ header = L["Auras"], glyph = "wand-magic-sparkles" },
		{
			path = "unitFrames.targetAuraPerRow",
			new = "1.4.0",
			label = L["Auras per row (target, focus)"],
			type = "number",
			min = 4,
			max = 12,
			step = 1,
			desc = L["Buffs and debuffs under the target and focus frames, up to two rows each. More per row means smaller icons."],
		},
		{
			path = "unitFrames.ownAuraScale",
			new = "1.4.1",
			label = L["Your auras scale (target, focus)"],
			type = "number",
			min = 1,
			max = 2,
			step = 0.05,
			percent = true,
			desc = L["Scale of the buffs and debuffs cast by you, your pet or vehicle under the target and focus frames. 100% keeps them the same size as the rest."],
		},
		auraOrder(L["Aura order (target, focus, party)"]),
	}
end

local function squareSizes(shownPath, sizeKey)
	return {
		size("unitFrames." .. sizeKey .. "Width", L["Width"], 20, 120, nil, shownPath),
		size("unitFrames." .. sizeKey .. "Height", L["Height"], 20, 120, nil, shownPath),
	}
end

local function squarePanel(shownPath, sizeKey, new)
	local list = { showToggle(shownPath, new), layoutHeader() }
	for _, entry in ipairs(squareSizes(shownPath, sizeKey)) do
		list[#list + 1] = entry
	end
	return list
end

local function castbarToggle(path)
	return { path = path, new = "1.4.0", label = L["Castbar"], type = "toggle" }
end

local function groupDebuffEntries()
	return {
		size(
			"unitFrames.groupDebuffSize",
			L["Debuff size (party, arena)"],
			16,
			60,
			L["Rounded so a whole number of icons fits the frame width."]
		),
		size(
			"unitFrames.groupDebuffMax",
			L["Debuff limit (party, arena)"],
			1,
			40,
			L["Most debuffs shown per frame; the rest are dropped."]
		),
		{
			path = "unitFrames.gridGap",
			label = L["Aura spacing (party, arena)"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			advanced = true,
			desc = L["Space between the frame, its debuffs and buffs."],
		},
	}
end

local function groupLayout(shownPath, prefix)
	return {
		showToggle(shownPath),
		layoutHeader(),
		size("unitFrames." .. prefix .. "Width", L["Width"], 120, 320),
		size("unitFrames." .. prefix .. "Height", L["Height"], 30, 80),
		{
			description = L["Each frame moves on its own; by default it is attached to the previous one, so dragging the first frame moves the whole group."],
		},
		iconSide(prefix),
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

local GROUP_SQUARES = {
	Pet = {
		header = L["Pet"],
		desc = L["Each pet frame moves on its own; by default it is attached to its owner's frame."],
	},
	Target = {
		header = L["Target"],
		desc = L["Square frame with the unit's target. Each one moves on its own; by default it is attached to the pet frame."],
	},
}

local function groupSquareEntries(prefix, name, kind, label)
	local shownPath = "unitFrames.show" .. name .. kind
	return concat({
		{ path = shownPath, new = "1.4.1", label = label, type = "toggle", desc = GROUP_SQUARES[kind].desc },
	}, squareSizes(shownPath, prefix .. kind))
end

local function groupSquareSections(prefix, name, petLabel, targetLabel)
	return concat(
		{ { header = GROUP_SQUARES.Pet.header, glyph = "paw" } },
		groupSquareEntries(prefix, name, "Pet", petLabel),
		{ { header = GROUP_SQUARES.Target.header, glyph = "bullseye" } },
		groupSquareEntries(prefix, name, "Target", targetLabel)
	)
end

local function castbarSection(path)
	return {
		{ header = L["Castbar"], glyph = "bars-progress" },
		castbarToggle(path),
	}
end

local function trinketSize()
	return size("arenaTrinket.size", L["Trinket size (arena, party)"], 16, 60, nil, "arenaTrinket.enabled")
end

local function arenaTrinketToggle(desc)
	return { path = "arenaTrinket.enabled", label = L["Arena trinkets"], type = "toggle", desc = desc }
end

ns.RegisterElement({
	path = "unitFrames.player",
	page = "unitframes",
	name = L["Player"],
	glyph = "user",
	enabledBy = "unitFrames.enabled",
	schema = concat(mainFrameLayout("player"), {
		{ header = L["Indicators"], glyph = "icons" },
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
	glyph = "bullseye",
	enabledBy = "unitFrames.enabled",
	schema = concat(mainFrameLayout("target"), targetAuras(), castbarSection("unitFrames.showTargetCastbar"), {
		{ header = L["Combo points"], glyph = "circle-dot" },
		size("unitFrames.comboPointSize", L["Combo point size"], 4, 20, L["Dots above the target frame."]),
		{ path = "unitFrames.comboPointColor", label = L["Combo points (full)"], type = "color" },
		{ path = "unitFrames.comboPointPartialColor", label = L["Combo points (partial)"], type = "color" },
	}),
})

ns.RegisterElement({
	path = "unitFrames.focus",
	page = "unitframes",
	name = L["Focus"],
	glyph = "eye",
	enabledBy = "unitFrames.enabled",
	schema = concat(mainFrameLayout("focus"), targetAuras(), castbarSection("unitFrames.showFocusCastbar")),
})

ns.RegisterElement({
	path = "unitFrames.pet",
	page = "unitframes",
	name = L["Pet"],
	glyph = "paw",
	enabledBy = "unitFrames.enabled",
	schema = concat(squarePanel("unitFrames.showPet", "pet"), {
		{ header = L["Display"], glyph = "icons" },
		{
			path = "unitFrames.petHappiness",
			new = "1.4.1",
			label = L["Pet happiness"],
			type = "toggle",
			hidden = ns.NotClass("HUNTER"),
			enabledBy = "unitFrames.showPet",
			desc = L["Happiness icon in the corner of your pet frame."],
		},
		{
			path = "unitFrames.petPower",
			new = "1.4.1",
			label = L["Power bar (all pets)"],
			type = "toggle",
			desc = L["Mana, focus or energy strip at the bottom of the pet frames of the player, party members and arena opponents."],
		},
	}),
})

ns.RegisterElement({
	path = "unitFrames.targetOfTarget",
	page = "unitframes",
	name = L["Target of target"],
	glyph = "bullseye",
	enabledBy = "unitFrames.enabled",
	schema = concat(squarePanel("unitFrames.showTargetOfTarget", "targetOfTarget", "1.4.0"), {
		{ header = L["Visibility"], glyph = "eye" },
		{
			path = "unitFrames.hideTargetOfTargetSelf",
			new = "1.4.1",
			label = L["Hide when it is you"],
			type = "toggle",
			enabledBy = "unitFrames.showTargetOfTarget",
			desc = L["Make the frame invisible while your target is targeting you. It still reacts to clicks, as secure frames cannot be hidden in combat."],
		},
	}),
})

ns.RegisterElement({
	path = "unitFrames.focusTarget",
	page = "unitframes",
	name = L["Target of focus"],
	glyph = "bullseye",
	enabledBy = "unitFrames.enabled",
	schema = squarePanel("unitFrames.showFocusTarget", "focusTarget", "1.4.0"),
})

ns.RegisterElement({
	path = "unitFrames.playerCastbar",
	page = "unitframes",
	name = L["Player castbar"],
	glyph = "bars-progress",
	enabledBy = "unitFrames.enabled",
	schema = {
		showToggle("unitFrames.showPlayerCastbar", "1.4.0"),
		layoutHeader(),
		size("unitFrames.playerCastbarWidth", L["Width"], 100, 500, nil, "unitFrames.showPlayerCastbar"),
		size("unitFrames.playerCastbarHeight", L["Height"], 10, 50, nil, "unitFrames.showPlayerCastbar"),
		{ header = L["Latency"], glyph = "signal" },
		{
			path = "unitFrames.castbarLatency",
			new = "1.4.1",
			label = L["Latency zone"],
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
			enabledBy = "unitFrames.castbarLatency",
		},
	},
})

ns.RegisterElement({
	path = "unitFrames.playerAuras",
	page = "unitframes",
	name = L["Player buffs / debuffs"],
	glyph = "wand-magic-sparkles",
	enabledBy = "unitFrames.enabled",
	schema = {
		layoutHeader(),
		{
			path = "unitFrames.playerAuraGrowth",
			new = "1.4.1",
			label = L["Growth direction"],
			type = "select",
			values = HORIZONTAL_GROWTH_VALUES,
			desc = L["Debuffs go below the buffs."],
		},
		{ header = L["Buffs"], glyph = "wand-magic-sparkles" },
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
		{ header = L["Debuffs"], glyph = "skull-crossbones" },
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

local function partySchema()
	return concat(
		groupLayout("unitFrames.showParty", "party"),
		{
			{ header = L["Auras"], glyph = "wand-magic-sparkles" },
			auraOrder(L["Aura order (target, focus, party)"]),
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
		},
		groupSquareSections("party", "Party", L["Party pets"], L["Party member targets"]),
		{
			{ header = L["Trinket"], glyph = "medal" },
			arenaTrinketToggle(L["PvP trinket cooldown icon next to each arena frame. Party trinkets need it too."]),
			{
				path = "arenaTrinket.party",
				label = L["Party trinkets"],
				type = "toggle",
				enabledBy = "arenaTrinket.enabled",
				desc = L["PvP trinket cooldown icon left of each party pet, only inside arenas. Size is shared with arena trinkets."],
			},
			trinketSize(),
		},
		castbarSection("unitFrames.showPartyCastbar"),
		{
			{ header = L["Test"], glyph = "flask" },
			testFramesButton(),
		}
	)
end

local function arenaSchema()
	return concat(
		groupLayout("unitFrames.showArena", "arena"),
		{
			{ header = L["Auras"], glyph = "wand-magic-sparkles" },
		},
		groupDebuffEntries(),
		groupSquareSections("arena", "Arena", L["Arena pets"], L["Arena opponent targets"]),
		{
			{ header = L["Trinket"], glyph = "medal" },
			arenaTrinketToggle(L["PvP trinket cooldown icon next to each arena frame. Party trinkets need it too."]),
			trinketSize(),
		},
		castbarSection("unitFrames.showArenaCastbar"),
		{
			{ header = L["Test"], glyph = "flask" },
			testFramesButton(),
		}
	)
end

local function castbarElement(prefix, path, name, enabledBy, hidden, desc)
	local shownPath = "unitFrames.show" .. prefix:gsub("^%l", string.upper) .. "Castbar"
	local sizePrefix = "unitFrames." .. prefix .. "Castbar"
	ns.RegisterElement({
		path = path,
		page = "unitframes",
		new = "1.4.1",
		name = name,
		glyph = "bars-progress",
		hidden = hidden,
		enabledBy = enabledBy,
		schema = {
			showToggle(shownPath, "1.4.0"),
			layoutHeader(),
			size(sizePrefix .. "Width", L["Width"], 60, 400, desc, shownPath),
			size(sizePrefix .. "Height", L["Height"], 10, 50, L["The spell icon follows the height."], shownPath),
		},
	})
end

local function registerGroup(group)
	local enabledBy = { "unitFrames.enabled", group.shownPath }
	for i = 1, #group.frames do
		ns.RegisterElement({
			path = "unitFrames." .. (i == 1 and group.prefix or group.prefix .. i),
			page = "unitframes",
			name = i == 1 and group.name or group.frames[i],
			glyph = group.glyph,
			hidden = i > 1,
			enabledBy = enabledBy,
			schema = group.schema(),
		})
		castbarElement(
			group.prefix,
			"unitFrames." .. group.prefix .. i .. "Castbar",
			group.castbars[i],
			enabledBy,
			true,
			group.castbarSizeDesc
		)
		for kind, names in pairs({ Pet = group.pets, Target = group.targets }) do
			ns.RegisterElement({
				path = "unitFrames." .. group.prefix .. i .. kind,
				page = "unitframes",
				new = "1.4.1",
				name = names[i],
				glyph = kind == "Pet" and "paw" or "bullseye",
				hidden = true,
				enabledBy = enabledBy,
				schema = squarePanel("unitFrames.show" .. group.key .. kind, group.prefix .. kind, "1.4.1"),
			})
		end
	end
end

registerGroup({
	prefix = "party",
	name = L["Party"],
	glyph = "users",
	shownPath = "unitFrames.showParty",
	castbarSizeDesc = L["Shared by all party castbars."],
	frames = { L["Party 1"], L["Party 2"], L["Party 3"], L["Party 4"] },
	castbars = { L["Party 1 castbar"], L["Party 2 castbar"], L["Party 3 castbar"], L["Party 4 castbar"] },
	key = "Party",
	pets = { L["Party 1 pet"], L["Party 2 pet"], L["Party 3 pet"], L["Party 4 pet"] },
	targets = { L["Party 1 target"], L["Party 2 target"], L["Party 3 target"], L["Party 4 target"] },
	schema = partySchema,
})

registerGroup({
	prefix = "arena",
	name = L["Arena"],
	glyph = "crosshairs",
	shownPath = "unitFrames.showArena",
	castbarSizeDesc = L["Shared by all arena castbars."],
	frames = { L["Arena 1"], L["Arena 2"], L["Arena 3"] },
	castbars = { L["Arena 1 castbar"], L["Arena 2 castbar"], L["Arena 3 castbar"] },
	key = "Arena",
	pets = { L["Arena 1 pet"], L["Arena 2 pet"], L["Arena 3 pet"] },
	targets = { L["Arena 1 target"], L["Arena 2 target"], L["Arena 3 target"] },
	schema = arenaSchema,
})

castbarElement("target", "unitFrames.targetCastbar", L["Target castbar"], "unitFrames.enabled")
castbarElement("focus", "unitFrames.focusCastbar", L["Focus castbar"], "unitFrames.enabled")

ns.RegisterElement({
	path = "unitFrames.boss",
	page = "unitframes",
	name = L["Boss"],
	glyph = "skull",
	enabledBy = { "unitFrames.enabled", "unitFrames.showBoss" },
	schema = {
		showToggle("unitFrames.showBoss"),
		layoutHeader(),
		size("unitFrames.bossWidth", L["Width"], 120, 320),
		size("unitFrames.bossHeight", L["Height"], 30, 80),
		size(
			"unitFrames.bossSpacing",
			L["Spacing"],
			40,
			200,
			L["Vertical distance between the tops of consecutive boss frames."]
		),
	},
})

ns.RegisterPage({
	key = "unitframes",
	name = L["Unit frames"],
	glyph = "id-badge",
	order = 20,
	group = "frames",
	enable = "unitFrames.enabled",
	schema = {
		{
			path = "unitFrames.enabled",
			label = L["Enable"],
			type = "toggle",
			reload = true,
			desc = L["Replace Blizzard unit frames."],
		},
		testFramesButton(),
		{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
		{ type = "elements" },
		{ header = L["Shown frames"], glyph = "eye" },
		{ path = "unitFrames.showParty", label = L["Party frames"], type = "toggle" },
		{
			path = "unitFrames.showPartyPet",
			new = "1.4.1",
			label = L["Party pets"],
			type = "toggle",
			enabledBy = "unitFrames.showParty",
		},
		{
			path = "unitFrames.showPartyTarget",
			new = "1.4.1",
			label = L["Party member targets"],
			type = "toggle",
			enabledBy = "unitFrames.showParty",
		},
		{ path = "unitFrames.showArena", label = L["Arena frames"], type = "toggle" },
		{
			path = "unitFrames.showArenaPet",
			new = "1.4.1",
			label = L["Arena pets"],
			type = "toggle",
			enabledBy = "unitFrames.showArena",
		},
		{
			path = "unitFrames.showArenaTarget",
			new = "1.4.1",
			label = L["Arena opponent targets"],
			type = "toggle",
			enabledBy = "unitFrames.showArena",
		},
		{ path = "unitFrames.showBoss", label = L["Boss frames"], type = "toggle" },
		{ path = "unitFrames.showPet", label = L["Player pet"], type = "toggle" },
		{ path = "unitFrames.showTargetOfTarget", new = "1.4.0", label = L["Target of target"], type = "toggle" },
		{ path = "unitFrames.showFocusTarget", new = "1.4.0", label = L["Target of focus"], type = "toggle" },
		{ header = L["General"], glyph = "gear" },
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
			percent = true,
			advanced = true,
			enabledBy = "unitFrames.hoverHighlight",
		},
		{
			path = "unitFrames.outOfRangeAlpha",
			label = L["Out of range alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			percent = true,
			desc = L["Party and arena frames fade to this alpha when the unit is out of range."],
		},
		{ header = L["Health bar"], glyph = "heart" },
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
			percent = true,
			advanced = true,
			desc = L["Fraction of the frame height taken by the power bar."],
		},
		{ header = L["Castbar"], glyph = "bars-progress" },
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
		{ header = L["Auras"], glyph = "wand-magic-sparkles" },
		auraOrder(L["Aura order"]),
		{
			path = "unitFrames.auraTimers",
			new = "1.4.1",
			label = L["Aura timers"],
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
		{ header = L["Indicators"], glyph = "icons" },
		{
			path = "unitFrames.showClassIcon",
			label = L["Class / spec icon"],
			type = "toggle",
			desc = L["Square icon on the side of the frame. Portrait for non-player units."],
		},
		{
			path = "unitFrames.classIconStyle",
			new = "1.4.1",
			label = L["Icon style"],
			type = "select",
			values = CLASS_ICON_STYLE_VALUES,
			enabledBy = "unitFrames.showClassIcon",
			desc = L["3D model falls back to the class / spec icon while the unit is out of sight."],
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
		{
			path = "unitFrames.raidIconSize",
			label = L["Raid target icon size"],
			type = "number",
			min = 10,
			max = 40,
			step = 1,
			advanced = true,
			enabledBy = "unitFrames.showRaidIcon",
		},
		{
			path = "unitFrames.showLoseControl",
			label = L["Crowd control icon"],
			type = "toggle",
			desc = L["Icon and timer of the longest crowd control effect over the class icon of target, focus, party and arena frames."],
		},
		{ header = L["Arena"], glyph = "crosshairs" },
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
			percent = true,
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
		{ header = L["Text"], glyph = "font" },
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
		{ header = L["Colors"], glyph = "palette" },
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
		{
			path = "dispelHighlightAlpha",
			label = L["Dispel highlight alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			percent = true,
			desc = L["Border alpha on unit frames with a debuff you can dispel."],
		},
		{
			path = "unitFrames.healthCutawayColor",
			label = L["Health loss flash color"],
			type = "color",
			alpha = true,
			enabledBy = "unitFrames.healthCutaway",
		},
		{
			path = "unitFrames.healPredictionColor",
			new = "1.4.0",
			label = L["Incoming heals color"],
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
			enabledByAny = { "unitFrames.healPrediction", "playerPlate.healPrediction" },
		},
		{
			path = "unitFrames.absorbColor",
			new = "1.4.0",
			label = L["Absorb shields color"],
			type = "color",
			alpha = true,
			enabledByAny = { "unitFrames.absorbs", "playerPlate.absorbs" },
		},
		{ header = L["Castbar colors"], glyph = "palette" },
		{ path = "unitFrames.castbarColor", label = L["Castbar"], type = "color" },
		{ path = "unitFrames.castbarChannelColor", label = L["Castbar (channel)"], type = "color" },
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
	},
})
