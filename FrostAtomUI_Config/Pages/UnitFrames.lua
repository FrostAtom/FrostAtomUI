local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

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

local function advanced(entry)
	entry.advanced = true
	return entry
end

local function new(entry)
	entry.new = "1.4.1"
	return entry
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

local function capitalize(text)
	return (text:gsub("^%l", string.upper))
end

local function uf(key)
	return "unitFrames." .. key
end

local TAGS = {
	{ "name", L["Unit name"] },
	{ "level", L["Level"] },
	{ "class", L["Class"] },
	{ "race", L["Race"] },
	{ "guild", L["Guild"] },
	{ "curhp", L["Current health"] },
	{ "maxhp", L["Maximum health"] },
	{ "misshp", L["Missing health"] },
	{ "perhp", L["Health percent"] },
	{ "curpp", L["Current power"] },
	{ "maxpp", L["Maximum power"] },
	{ "perpp", L["Power percent"] },
	{ "druidmana", L["Mana in a druid form"] },
	{ "status", L["Offline, dead, AFK or DND"] },
	{ "afk", L["AFK mark"] },
	{ "dnd", L["DND mark"] },
}

local TAG_MODIFIERS = {
	{ "class", L["Class color"] },
	{ "reaction", L["Reaction color"] },
	{ "hp", L["Color by health"] },
	{ "power", L["Power type color"] },
	{ "ffaaff", L["Any hex color"] },
	{ "8", L["Maximum letters"] },
	{ "raw", L["Full numbers, not shortened"] },
}

local function renderTags(template)
	return FrostAtomUI:GetModule("UnitFrames").RenderTags(template, "player")
end

local function validateTags(template)
	local check = FrostAtomUI:GetModule("UnitFrames").CheckTag
	for body in template:gmatch("%[([^%[%]]*)%]") do
		local token, option = check(body)
		if token then
			local tag = "[" .. body .. "]"
			if option then
				return true, L["Unknown option %s in %s."]:format(token, tag)
			end
			return true, L["Unknown tag %s."]:format(tag)
		end
	end
	return true
end

local TEXT_POINTS = {
	health = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
	power = { "LEFT", "RIGHT" },
}
local selectedTextPoints = {}

local function textSlots(bar)
	return ui.Config.unitFrames[bar .. "Texts"]
end

local function defaultTextSlots(bar)
	return ui.Defaults.unitFrames[bar .. "Texts"]
end

local function hasText(slot)
	return slot.text ~= "" or slot.hover ~= ""
end

local function selectedTextPoint(bar)
	local point = selectedTextPoints[bar]
	if point then
		return point
	end
	local points, slots = TEXT_POINTS[bar], textSlots(bar)
	point = points[1]
	for _, candidate in ipairs(points) do
		if hasText(slots[candidate]) then
			point = candidate
			break
		end
	end
	selectedTextPoints[bar] = point
	return point
end

local function describeTextPoint(bar, point)
	local slot = textSlots(bar)[point]
	if not hasText(slot) then
		return L["No text"]
	end
	local lines = {}
	if slot.text ~= "" then
		lines[#lines + 1] = slot.text
	end
	if slot.hover ~= "" then
		lines[#lines + 1] = L["Mouseover: %s"]:format(slot.hover)
	end
	return table.concat(lines, "\n")
end

local function isDefaultTexts(bar)
	local slots, defaults = textSlots(bar), defaultTextSlots(bar)
	for _, point in ipairs(TEXT_POINTS[bar]) do
		local slot, default = slots[point], defaults[point]
		if slot.text ~= default.text or slot.hover ~= default.hover then
			return false
		end
	end
	return true
end

local function textPoint(bar, label, desc)
	return {
		label = label,
		type = "anchor",
		desc = desc,
		points = TEXT_POINTS[bar],
		get = function()
			return selectedTextPoint(bar)
		end,
		set = function(point)
			local focus = GetCurrentKeyBoardFocus()
			if focus and focus.editing then
				focus:ClearFocus()
			end
			selectedTextPoints[bar] = point
			ns.RefreshPage()
		end,
		marked = function(point)
			return hasText(textSlots(bar)[point])
		end,
		describe = function(point)
			return describeTextPoint(bar, point)
		end,
		isDefault = function()
			return isDefaultTexts(bar)
		end,
		reset = function()
			ui:ResetConfig(uf(bar .. "Texts"))
		end,
	}
end

local function textField(bar, field, label, desc)
	local function path()
		return uf(("%sTexts.%s.%s"):format(bar, selectedTextPoint(bar), field))
	end
	local function default()
		return defaultTextSlots(bar)[selectedTextPoint(bar)][field]
	end
	return {
		label = label,
		type = "string",
		indent = true,
		width = 220,
		maxLetters = 120,
		desc = desc,
		tags = TAGS,
		modifiers = TAG_MODIFIERS,
		render = renderTags,
		validate = validateTags,
		get = function()
			return ui:GetConfig(path())
		end,
		set = function(value)
			ui:SetConfig(path(), value)
		end,
		isDefault = function()
			return ui:GetConfig(path()) == default()
		end,
		reset = function()
			ui:ResetConfig(path())
		end,
		defaultText = function()
			local value = default()
			return value == "" and L["(empty)"] or ('"%s"'):format(value)
		end,
	}
end

local function textEntries(bar, label, desc)
	return {
		textPoint(bar, label, desc),
		textField(bar, "text", L["Text"], L["Empty: no text at this point."]),
		textField(bar, "hover", L["Text (mouseover)"], L["Empty to keep the text on mouseover."]),
	}
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
	{ "LEFT", L["To the left"], glyph = "arrow-left" },
	{ "RIGHT", L["To the right"], glyph = "arrow-right" },
}

local CLASS_ICON_STYLE_VALUES = {
	{ "spec", L["Spec icon"] },
	{ "badge", L["Class icon with spec badge"] },
	{ "class", L["Class icon"] },
	{ "portrait", L["2D portrait"] },
	{ "model", L["3D portrait"] },
}

local ICON_SIDE_VALUES = {
	{ "LEFT", L["On the left"], glyph = "arrow-left" },
	{ "RIGHT", L["On the right"], glyph = "arrow-right" },
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

local AURA_ORDER_VALUES = {
	{ "debuffs", L["Debuffs first"] },
	{ "buffs", L["Buffs first"] },
}

local AURA_POSITION_VALUES = {
	{ "BOTTOM", L["Below"], glyph = "arrow-down" },
	{ "TOP", L["Above"], glyph = "arrow-up" },
	{ "LEFT", L["On the left"], glyph = "arrow-left" },
	{ "RIGHT", L["On the right"], glyph = "arrow-right" },
}

local AURA_ORDER_DESC = L["Which block is closer to the frame when debuffs and buffs are on the same side."]

local FIT_DESC = L["Rounded so a whole number of icons fits the frame width."]

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

local function showToggle(path, isNew)
	return { path = path, new = isNew and "1.4.1" or nil, label = L["Show"], type = "toggle" }
end

local function layoutHeader()
	return { header = L["Layout"], glyph = "up-down-left-right" }
end

local function framesSection()
	return {
		{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
		{ type = "elements" },
	}
end

local function iconSide(key, enabledBy)
	local requires = "unitFrames.showClassIcon"
	return {
		path = uf(key .. "IconSide"),
		new = "1.4.1",
		label = L["Class icon side"],
		type = "select",
		values = ICON_SIDE_VALUES,
		enabledBy = enabledBy and { requires, enabledBy } or requires,
		advanced = true,
	}
end

local function frameLayout(key, shownPath, shownLabel)
	local list = { layoutHeader() }
	if shownPath then
		list[#list + 1] = { path = shownPath, label = shownLabel, type = "toggle" }
	end
	list[#list + 1] = size(uf(key .. "Width"), L["Width"], 120, 320, nil, shownPath)
	list[#list + 1] = size(uf(key .. "Height"), L["Height"], 30, 80, nil, shownPath)
	list[#list + 1] = iconSide(key, shownPath)
	return list
end

local function castbarShownPath(key)
	return uf("show" .. capitalize(key) .. "Castbar")
end

local function castbarEntries(key, minWidth, maxWidth, desc, enabledBy, isNew)
	local shownPath = castbarShownPath(key)
	local toggle = { path = shownPath, label = L["Castbar"], type = "toggle", enabledBy = enabledBy }
	if isNew then
		new(toggle)
		toggle.desc = L["Castbar of this unit, moved on its own in move mode."]
	end
	return {
		toggle,
		size(uf(key .. "CastbarWidth"), L["Castbar width"], minWidth, maxWidth, desc, shownPath),
		size(
			uf(key .. "CastbarHeight"),
			L["Castbar height"],
			10,
			50,
			L["The spell icon follows the height."],
			shownPath
		),
	}
end

local function castbarSection(key, minWidth, maxWidth, desc, enabledBy, isNew)
	return concat(
		{ { header = L["Castbar"], glyph = "bars-progress" } },
		castbarEntries(key, minWidth, maxWidth, desc, enabledBy, isNew)
	)
end

local function castbarLatency()
	return {
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
			advanced = true,
			enabledBy = "unitFrames.castbarLatency",
		},
	}
end

local function auraToggle(path, label, desc)
	return new({ path = path, label = label, type = "toggle", desc = desc })
end

local AURA_PLACEMENT_LABELS = {
	Debuff = { L["Debuff position"], L["Debuff growth"] },
	Buff = { L["Buff position"], L["Buff growth"] },
}

local function auraPlacement(key, kind, shownPath)
	local labels = AURA_PLACEMENT_LABELS[kind]
	local position = new({
		path = uf(key .. kind .. "Position"),
		label = labels[1],
		type = "select",
		values = AURA_POSITION_VALUES,
		enabledBy = shownPath,
		desc = L["Side of the frame the icons are attached to. On the left or right the rows go down from the top of the frame."],
	})
	local growth = new({
		path = uf(key .. kind .. "Growth"),
		label = labels[2],
		type = "select",
		values = HORIZONTAL_GROWTH_VALUES,
		enabledBy = shownPath,
		desc = L["Direction the icons fill a row in."],
	})
	return position, growth
end

local function targetAuras(key)
	local name = capitalize(key)
	local debuffs, buffs = uf("show" .. name .. "Debuffs"), uf("show" .. name .. "Buffs")
	local either = { debuffs, buffs }
	local debuffPosition, debuffGrowth = auraPlacement(key, "Debuff", debuffs)
	local buffPosition, buffGrowth = auraPlacement(key, "Buff", buffs)
	return {
		{ header = L["Auras"], glyph = "wand-magic-sparkles" },
		auraToggle(debuffs, L["Debuffs"]),
		debuffPosition,
		debuffGrowth,
		auraToggle(buffs, L["Buffs"]),
		buffPosition,
		buffGrowth,
		{
			path = uf(key .. "AuraPerRow"),
			new = "1.4.0",
			label = L["Icons per row"],
			type = "number",
			min = 4,
			max = 12,
			step = 1,
			enabledByAny = either,
			desc = L["More per row means smaller icons: they share the frame width."],
		},
		new({
			path = uf(key .. "AuraRows"),
			label = L["Rows"],
			type = "number",
			min = 1,
			max = 4,
			step = 1,
			enabledByAny = either,
			advanced = true,
			desc = L["Rows of debuffs and rows of buffs each."],
		}),
		new({
			path = uf(key .. "OwnAuraScale"),
			label = L["Your auras scale"],
			type = "number",
			min = 1,
			max = 2,
			step = 0.05,
			percent = true,
			advanced = true,
			enabledByAny = either,
			desc = L["Scale of the buffs and debuffs cast by you, your pet or vehicle. 100% keeps them the same size as the rest."],
		}),
		new({
			path = uf(key .. "AuraOrder"),
			label = L["Aura order"],
			type = "select",
			values = AURA_ORDER_VALUES,
			advanced = true,
			enabledBy = either,
			desc = AURA_ORDER_DESC,
		}),
		ns.ClickThrough(uf(key .. "AuraClickThrough"), nil, either),
	}
end

local function groupAuras(key, enabledBy)
	local name = capitalize(key)
	local debuffs, buffs = uf("show" .. name .. "Debuffs"), uf("show" .. name .. "Buffs")
	local debuffToggle = auraToggle(debuffs, L["Debuffs"])
	local buffToggle = auraToggle(buffs, L["Buffs"])
	debuffToggle.enabledBy, buffToggle.enabledBy = enabledBy, enabledBy
	local debuffPosition, debuffGrowth = auraPlacement(key, "Debuff", debuffs)
	local buffPosition, buffGrowth = auraPlacement(key, "Buff", buffs)
	return {
		{ header = L["Auras"], glyph = "wand-magic-sparkles" },
		debuffToggle,
		debuffPosition,
		debuffGrowth,
		size(uf(key .. "DebuffSize"), L["Debuff size"], 16, 60, FIT_DESC, debuffs),
		advanced(
			size(
				uf(key .. "DebuffMax"),
				L["Debuff limit"],
				1,
				40,
				L["Most debuffs shown per frame; the rest are dropped."],
				debuffs
			)
		),
		buffToggle,
		buffPosition,
		buffGrowth,
		size(uf(key .. "BuffSize"), L["Buff size"], 10, 40, FIT_DESC, buffs),
		advanced(
			size(
				uf(key .. "BuffMax"),
				L["Buff limit"],
				1,
				40,
				L["Most buffs shown per frame; the rest are dropped."],
				buffs
			)
		),
		{
			path = uf(key .. "AuraSpacing"),
			label = L["Aura spacing"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			advanced = true,
			enabledByAny = { debuffs, buffs },
			desc = L["Space between the frame, its debuffs and buffs."],
		},
		new({
			path = uf(key .. "AuraOrder"),
			label = L["Aura order"],
			type = "select",
			values = AURA_ORDER_VALUES,
			advanced = true,
			enabledBy = { debuffs, buffs },
			desc = AURA_ORDER_DESC,
		}),
		ns.ClickThrough(uf(key .. "AuraClickThrough"), enabledBy, { debuffs, buffs }),
	}
end

local function squareAuras(key, enabledBy)
	local name = capitalize(key)
	local debuffs, buffs = uf("show" .. name .. "Debuffs"), uf("show" .. name .. "Buffs")
	local either = { debuffs, buffs }
	local debuffToggle = auraToggle(debuffs, L["Debuffs"], L["Icons under the frame."])
	local buffToggle = auraToggle(buffs, L["Buffs"], L["Icons under the frame, below the debuffs."])
	debuffToggle.enabledBy, buffToggle.enabledBy = enabledBy, enabledBy
	return {
		{ header = L["Auras"], glyph = "wand-magic-sparkles" },
		debuffToggle,
		buffToggle,
		new({
			path = uf(key .. "AuraSize"),
			label = L["Icon size"],
			type = "number",
			min = 10,
			max = 40,
			step = 1,
			enabledByAny = either,
		}),
		new({
			path = uf(key .. "AuraPerRow"),
			label = L["Icons per row"],
			type = "number",
			min = 1,
			max = 12,
			step = 1,
			enabledByAny = either,
		}),
		new({
			path = uf(key .. "AuraRows"),
			label = L["Rows"],
			type = "number",
			min = 1,
			max = 4,
			step = 1,
			advanced = true,
			enabledByAny = either,
			desc = L["Rows of debuffs and rows of buffs each."],
		}),
		new({
			path = uf(key .. "AuraGrowth"),
			label = L["Growth direction"],
			type = "select",
			values = HORIZONTAL_GROWTH_VALUES,
			advanced = true,
			enabledByAny = either,
		}),
		ns.ClickThrough(uf(key .. "AuraClickThrough"), enabledBy, either),
	}
end

local function squareLayout(key, shownPath, shownLabel, shownDesc, enabledBy, isNew)
	return {
		layoutHeader(),
		{
			path = shownPath,
			new = isNew and "1.4.1" or nil,
			label = shownLabel,
			type = "toggle",
			enabledBy = enabledBy,
			desc = shownDesc,
		},
		size(uf(key .. "Width"), L["Width"], 20, 120, nil, shownPath),
		size(uf(key .. "Height"), L["Height"], 20, 120, nil, shownPath),
	}
end

local function petPower(key, shownPath)
	return new({
		path = uf(key .. "Power"),
		label = L["Power bar"],
		type = "toggle",
		enabledBy = shownPath,
		desc = L["Mana, focus or energy strip at the bottom of the pet frame."],
	})
end

local function petHappiness()
	return {
		path = "unitFrames.petHappiness",
		new = "1.4.1",
		label = L["Pet happiness"],
		type = "toggle",
		hidden = ns.NotClass("HUNTER"),
		enabledBy = "unitFrames.showPet",
		desc = L["Happiness icon in the corner of your pet frame."],
	}
end

local function hideTargetOfTargetSelf()
	return {
		path = "unitFrames.hideTargetOfTargetSelf",
		new = "1.4.1",
		label = L["Hide when it is you"],
		type = "toggle",
		enabledBy = "unitFrames.showTargetOfTarget",
		desc = L["Make the frame invisible while your target is targeting you. It still reacts to clicks, as secure frames cannot be hidden in combat."],
	}
end

local function squareDisplay(square)
	local list = {}
	if square.pet then
		list[#list + 1] = petPower(square.key, square.shownPath)
	end
	if square.key == "pet" then
		list[#list + 1] = petHappiness()
	end
	if #list == 0 then
		return list
	end
	table.insert(list, 1, { header = L["Display"], glyph = "icons" })
	return list
end

local function squareVisibility(square)
	if square.key ~= "targetOfTarget" then
		return {}
	end
	return {
		{ header = L["Visibility"], glyph = "eye" },
		hideTargetOfTargetSelf(),
	}
end

local SQUARES = {
	pet = {
		key = "pet",
		pet = true,
		shownPath = "unitFrames.showPet",
		label = L["Player pet"],
	},
	targetOfTarget = {
		key = "targetOfTarget",
		shownPath = "unitFrames.showTargetOfTarget",
		label = L["Target of target"],
		isNew = true,
	},
	focusTarget = {
		key = "focusTarget",
		shownPath = "unitFrames.showFocusTarget",
		label = L["Target of focus"],
		isNew = true,
	},
	partyPet = {
		key = "partyPet",
		pet = true,
		group = "unitFrames.showParty",
		shownPath = "unitFrames.showPartyPet",
		label = L["Party pets"],
		desc = L["Each pet frame moves on its own; by default it is attached to its owner's frame."],
		isNew = true,
	},
	partyTarget = {
		key = "partyTarget",
		group = "unitFrames.showParty",
		shownPath = "unitFrames.showPartyTarget",
		label = L["Party member targets"],
		desc = L["Square frame with the unit's target. Each one moves on its own; by default it is attached to the pet frame."],
		isNew = true,
	},
	arenaPet = {
		key = "arenaPet",
		pet = true,
		group = "unitFrames.showArena",
		shownPath = "unitFrames.showArenaPet",
		label = L["Arena pets"],
		desc = L["Each pet frame moves on its own; by default it is attached to its owner's frame."],
		isNew = true,
	},
	arenaTarget = {
		key = "arenaTarget",
		group = "unitFrames.showArena",
		shownPath = "unitFrames.showArenaTarget",
		label = L["Arena opponent targets"],
		desc = L["Square frame with the unit's target. Each one moves on its own; by default it is attached to the pet frame."],
		isNew = true,
	},
}

local function squarePanel(square)
	return concat(
		squareLayout(square.key, square.shownPath, L["Show"], square.desc, square.group, square.isNew),
		squareAuras(square.key, square.shownPath),
		squareDisplay(square),
		squareVisibility(square)
	)
end

local function squareTab(square)
	return concat(
		framesSection(),
		squareLayout(square.key, square.shownPath, square.label, square.desc, square.group, square.isNew),
		castbarSection(square.key, 60, 300, nil, square.shownPath, true),
		squareAuras(square.key, square.shownPath),
		squareDisplay(square),
		squareVisibility(square)
	)
end

local function castbarPanel(key, minWidth, desc, isNew)
	local shownPath = castbarShownPath(key)
	return {
		showToggle(shownPath, isNew),
		layoutHeader(),
		size(uf(key .. "CastbarWidth"), L["Width"], minWidth, 400, desc, shownPath),
		size(uf(key .. "CastbarHeight"), L["Height"], 10, 50, L["The spell icon follows the height."], shownPath),
	}
end

local function playerIndicators()
	return {
		{ header = L["Indicators"], glyph = "icons" },
		{
			path = "unitFrames.pvpTimer",
			new = "1.4.1",
			label = L["PvP flag timer"],
			type = "toggle",
			advanced = true,
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
			advanced = true,
			enabledBy = "unitFrames.combatGlow",
		},
	}
end

local function comboPoints()
	return {
		{ header = L["Combo points"], glyph = "circle-dot" },
		size("unitFrames.comboPointSize", L["Combo point size"], 4, 20, L["Dots above the target frame."]),
		{ path = "unitFrames.comboPointColor", label = L["Combo points (full)"], type = "color", advanced = true },
		{
			path = "unitFrames.comboPointPartialColor",
			label = L["Combo points (partial)"],
			type = "color",
			advanced = true,
		},
	}
end

local function playerAuraGrowth(path)
	return {
		path = path,
		new = "1.4.1",
		label = L["Growth direction"],
		type = "select",
		values = HORIZONTAL_GROWTH_VALUES,
	}
end

local function playerAuraClickThrough()
	local entry = ns.ClickThrough("unitFrames.playerAuraClickThrough")
	entry.desc =
		L["Player buffs and debuffs ignore the mouse: no tooltips and no right-click cancel, clicks pass through to the world behind them. Switched in combat, right-click cancel follows when combat ends."]
	return entry
end

local function playerBuffSection()
	return {
		{ header = L["Buffs"], glyph = "wand-magic-sparkles" },
		playerAuraGrowth("unitFrames.playerAuraGrowth"),
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
			advanced = true,
			desc = L["Right-click cancels a buff, in combat too. A sorted grid keeps the buff names it had when combat started, so after the order changes in combat a click may cancel a different buff."],
		},
		playerAuraClickThrough(),
	}
end

local function playerDebuffSection()
	return {
		{ header = L["Debuffs"], glyph = "skull-crossbones" },
		new(playerAuraGrowth("unitFrames.playerDebuffGrowth")),
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
	}
end

local function arenaUnseen()
	return {
		{ header = L["Unseen opponents"], glyph = "user-secret" },
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
			advanced = true,
		},
		{
			path = "arenaUnseen.prep",
			new = "1.4.0",
			label = L["Arena preparation frames"],
			type = "toggle",
			enabledBy = "unitFrames.showArena",
			desc = L["Placeholder frames for the expected opponents before the gates open, filled with class, spec and name as soon as an opponent is seen."],
		},
	}
end

local function registerElement(element)
	element.page = "unitframes"
	element.enabledBy = element.enabledBy or "unitFrames.enabled"
	ns.RegisterElement(element)
end

registerElement({
	path = "unitFrames.player",
	tab = "player",
	name = L["Player"],
	glyph = "user",
	schema = concat(frameLayout("player"), playerIndicators()),
})

registerElement({
	path = "unitFrames.playerCastbar",
	tab = "player",
	name = L["Player castbar"],
	glyph = "bars-progress",
	schema = concat(castbarPanel("player", 100), { { header = L["Latency"], glyph = "signal" } }, castbarLatency()),
})

registerElement({
	path = "unitFrames.playerAuras",
	tab = "player",
	name = L["Player buffs"],
	glyph = "wand-magic-sparkles",
	schema = playerBuffSection(),
})

registerElement({
	path = "unitFrames.playerDebuffs",
	tab = "player",
	new = "1.4.1",
	name = L["Player debuffs"],
	glyph = "skull-crossbones",
	schema = playerDebuffSection(),
})

registerElement({
	path = "unitFrames.target",
	tab = "target",
	name = L["Target"],
	glyph = "bullseye",
	schema = concat(frameLayout("target"), targetAuras("target"), {
		{ header = L["Castbar"], glyph = "bars-progress" },
		{ path = castbarShownPath("target"), label = L["Castbar"], type = "toggle" },
	}, comboPoints()),
})

registerElement({
	path = "unitFrames.targetCastbar",
	tab = "target",
	new = "1.4.1",
	name = L["Target castbar"],
	glyph = "bars-progress",
	schema = castbarPanel("target", 60),
})

registerElement({
	path = "unitFrames.focus",
	tab = "focus",
	name = L["Focus"],
	glyph = "eye",
	schema = concat(frameLayout("focus"), targetAuras("focus"), {
		{ header = L["Castbar"], glyph = "bars-progress" },
		{ path = castbarShownPath("focus"), label = L["Castbar"], type = "toggle" },
	}),
})

registerElement({
	path = "unitFrames.focusCastbar",
	tab = "focus",
	new = "1.4.1",
	name = L["Focus castbar"],
	glyph = "bars-progress",
	schema = castbarPanel("focus", 60),
})

local SINGLE_SQUARES = {
	{ key = "pet", name = L["Pet"], castbar = L["Pet castbar"], glyph = "paw" },
	{
		key = "targetOfTarget",
		name = L["Target of target"],
		castbar = L["Target of target castbar"],
		glyph = "bullseye",
	},
	{ key = "focusTarget", name = L["Target of focus"], castbar = L["Target of focus castbar"], glyph = "bullseye" },
}

for _, info in ipairs(SINGLE_SQUARES) do
	local square = SQUARES[info.key]
	registerElement({
		path = uf(info.key),
		tab = info.key,
		name = info.name,
		glyph = info.glyph,
		schema = squarePanel(square),
	})
	registerElement({
		path = uf(info.key .. "Castbar"),
		tab = info.key,
		new = "1.4.1",
		name = info.castbar,
		glyph = "bars-progress",
		enabledBy = { "unitFrames.enabled", square.shownPath },
		schema = castbarPanel(info.key, 60, nil, true),
	})
end

local GROUP_CASTBAR_DESC = L["Shared by all frames of the group."]

local function groupSchema(prefix, shownPath)
	return concat(frameLayout(prefix, shownPath, L["Show"]), {
		{
			description = L["Each frame moves on its own; by default it is attached to the previous one, so dragging the first frame moves the whole group."],
		},
	}, groupAuras(prefix, shownPath))
end

local function registerGroup(group)
	local enabledBy = { "unitFrames.enabled", group.shownPath }
	for i = 1, group.count do
		local first = i == 1
		local label = group.label .. " " .. i
		registerElement({
			path = uf(first and group.prefix or group.prefix .. i),
			tab = group.prefix,
			name = first and group.name or L[label],
			glyph = group.glyph,
			hidden = not first,
			enabledBy = enabledBy,
			schema = groupSchema(group.prefix, group.shownPath),
		})
		registerElement({
			path = uf(group.prefix .. i .. "Castbar"),
			tab = group.prefix,
			new = "1.4.1",
			name = first and group.castbarsName or L[label .. " castbar"],
			glyph = "bars-progress",
			hidden = not first,
			enabledBy = enabledBy,
			schema = castbarPanel(group.prefix, 60, GROUP_CASTBAR_DESC),
		})
		for _, kind in ipairs({ "Pet", "Target" }) do
			local key = group.prefix .. kind
			local square = SQUARES[key]
			local names = group[kind]
			local childLabel = label .. " " .. kind:lower()
			registerElement({
				path = uf(group.prefix .. i .. kind),
				tab = key,
				new = "1.4.1",
				name = first and names.frames or L[childLabel],
				glyph = kind == "Pet" and "paw" or "bullseye",
				hidden = not first,
				enabledBy = enabledBy,
				schema = squarePanel(square),
			})
			registerElement({
				path = uf(group.prefix .. i .. kind .. "Castbar"),
				tab = key,
				new = "1.4.1",
				name = first and names.castbars or L[childLabel .. " castbar"],
				glyph = "bars-progress",
				hidden = not first,
				enabledBy = { "unitFrames.enabled", group.shownPath, square.shownPath },
				schema = castbarPanel(key, 60, GROUP_CASTBAR_DESC, true),
			})
		end
	end
end

registerGroup({
	prefix = "party",
	count = 4,
	label = "Party",
	name = L["Party"],
	castbarsName = L["Party castbars"],
	glyph = "users",
	shownPath = "unitFrames.showParty",
	Pet = { frames = L["Party pets"], castbars = L["Party pet castbars"] },
	Target = { frames = L["Party member targets"], castbars = L["Party target castbars"] },
})

registerGroup({
	prefix = "arena",
	count = 3,
	label = "Arena",
	name = L["Arena"],
	castbarsName = L["Arena castbars"],
	glyph = "crosshairs",
	shownPath = "unitFrames.showArena",
	Pet = { frames = L["Arena pets"], castbars = L["Arena pet castbars"] },
	Target = { frames = L["Arena opponent targets"], castbars = L["Arena target castbars"] },
})

function ns.CastbarIndicators()
	return {
		{
			path = "unitFrames.castbarTargetName",
			new = "1.4.0",
			label = L["Show cast target"],
			type = "toggle",
			desc = L["Class-colored name of the caster's target on the right of unit frame and nameplate castbars."],
		},
		{
			path = "unitFrames.castbarTargetingYou",
			new = "1.4.0",
			label = L["Highlight casts on you"],
			type = "toggle",
			desc = L["Colored border of unit frame and nameplate castbars while an enemy casts at you."],
		},
		{
			path = "unitFrames.castbarImportant",
			new = "1.4.0",
			label = L["Pulse important casts"],
			type = "toggle",
			desc = L["Pulsing glow around unit frame and nameplate castbars for crowd control and heals."],
		},
		{
			path = "unitFrames.castbarInterrupter",
			new = "1.4.0",
			label = L["Show who interrupted"],
			type = "toggle",
			desc = L["Keep an interrupted unit frame or nameplate castbar red for a second with the interrupter's name."],
		},
	}
end

local function generalSettings()
	return {
		{ header = L["General"], glyph = "gear" },
		{
			path = "unitFrames.rightClick",
			label = L["Right click"],
			type = "select",
			values = RIGHT_CLICK_VALUES,
			desc = L["Action on right-clicking a frame. Arena frames always set focus."],
		},
		{
			path = "unitFrames.middleClick",
			label = L["Middle click"],
			type = "select",
			values = RIGHT_CLICK_VALUES,
			desc = L["Action on middle-clicking a frame. Set focus on the focus frame clears it."],
		},
		{
			path = "unitFrames.hoverAlpha",
			label = L["Highlight on mouseover"],
			type = "number",
			min = 0,
			max = 0.5,
			step = 0.02,
			percent = true,
			zeroText = L["Off"],
			advanced = true,
			desc = L["Light overlay on the frame under the cursor."],
		},
		{
			path = "unitFrames.outOfRangeAlpha",
			label = L["Out of range alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			percent = true,
			advanced = true,
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
			advanced = true,
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
			advanced = true,
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
	}
end

local function displaySettings()
	return {
		{
			path = "unitFrames.castbarTicks",
			new = "1.4.1",
			label = L["Channel ticks"],
			type = "toggle",
			advanced = true,
			desc = L["Marks on the castbar where the ticks of channeled spells (Drain Life, Mind Flay, Penance, Blizzard and others) land."],
		},
		{
			path = "unitFrames.castbarTimeFormat",
			new = "1.4.1",
			label = L["Cast time"],
			type = "select",
			values = CAST_TIME_VALUES,
			advanced = true,
		},
		{ header = L["Auras"], glyph = "wand-magic-sparkles" },
		{
			path = "unitFrames.auraTimers",
			new = "1.4.1",
			label = L["Aura timers"],
			type = "toggle",
			desc = L["Remaining time on buff and debuff icons of every unit frame."],
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
			advanced = true,
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
			advanced = true,
			desc = L["Crown in the corner of the party leader's frame."],
		},
		{ path = "unitFrames.showCombatIcon", label = L["Combat icon"], type = "toggle", advanced = true },
		{
			path = "unitFrames.showPvpIcon",
			label = L["PvP flag icon"],
			type = "toggle",
			advanced = true,
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
		{ header = L["Text"], glyph = "font", advanced = true },
		{
			path = "unitFrames.textFont",
			label = L["Text font"],
			type = "font",
			desc = L["Name, health and power text."],
		},
		{ path = "unitFrames.castbarFont", label = L["Castbar font"], type = "font" },
	}
end

local function colorSettings()
	return {
		{ header = L["Colors"], glyph = "palette", advanced = true },
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
		{ header = L["Castbar colors"], glyph = "palette", advanced = true },
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
	}
end

local function generalSchema()
	return concat(
		generalSettings(),
		ns.CastbarIndicators(),
		displaySettings(),
		textEntries(
			"health",
			L["Health bar texts"],
			L["Pick a point of the health bar to edit its text; points with a text are green. Each text is aligned to its point and grows away from it."]
		),
		textEntries(
			"power",
			L["Power bar texts"],
			L["Pick a side of the power bar to edit its text; sides with a text are green."]
		),
		colorSettings()
	)
end

local RECT_COPY = { "Width", "Height", "IconSide", "CastbarWidth", "CastbarHeight" }
local AURA_PLACEMENT_COPY = { "DebuffPosition", "DebuffGrowth", "BuffPosition", "BuffGrowth" }
local TARGET_COPY = concat({ "AuraPerRow", "AuraRows", "OwnAuraScale", "AuraOrder" }, AURA_PLACEMENT_COPY)
local GROUP_COPY =
	concat({ "DebuffSize", "DebuffMax", "BuffSize", "BuffMax", "AuraSpacing", "AuraOrder" }, AURA_PLACEMENT_COPY)
local SQUARE_COPY = {
	"Width",
	"Height",
	"CastbarWidth",
	"CastbarHeight",
	"AuraSize",
	"AuraPerRow",
	"AuraRows",
	"AuraGrowth",
}

local function copyMap(key, suffixes, extra, namespace)
	local map = {}
	local prefix = namespace and namespace .. "." or ""
	for _, list in ipairs({ suffixes, extra or {} }) do
		for _, suffix in ipairs(list) do
			map[prefix .. suffix] = uf(key .. suffix)
		end
	end
	local name = capitalize(key)
	map[prefix .. "Castbar"] = uf("show" .. name .. "Castbar")
	if extra then
		map[prefix .. "Debuffs"] = uf("show" .. name .. "Debuffs")
		map[prefix .. "Buffs"] = uf("show" .. name .. "Buffs")
	end
	return map
end

local function rectCopy(key, extra)
	return copyMap(key, RECT_COPY, extra)
end

local function squareCopy(key)
	local map = copyMap(key, SQUARE_COPY, {}, "square")
	if SQUARES[key].pet then
		map["square.Power"] = uf(key .. "Power")
	end
	return map
end

local function squareTabEntry(key, parent, name, glyph)
	return {
		key = key,
		parent = parent,
		name = name,
		glyph = glyph,
		copy = squareCopy(key),
		schema = squareTab(SQUARES[key]),
	}
end

local raidTab, raidIndicatorsTab
do
	local ENABLED = "raidFrames.enabled"

	local function path(key)
		return "raidFrames." .. key
	end

	local function entry(key, label, kind, fields)
		local row = fields or {}
		row.path = path(key)
		row.label = label
		row.type = kind
		row.new = "1.4.1"
		row.enabledBy = row.enabledBy and { ENABLED, row.enabledBy } or ENABLED
		return row
	end

	local function number(key, label, min, max, step, fields)
		fields = fields or {}
		fields.min, fields.max, fields.step = min, max, step
		return entry(key, label, "number", fields)
	end

	local function layout()
		return {
			layoutHeader(),
			number("width", L["Width"], 30, 200, 1),
			number("height", L["Height"], 16, 100, 1),
			entry("orientation", L["Arrange in"], "select", {
				values = {
					{ "horizontal", L["Rows"], L["Frames fill a row, the next row goes below or above."] },
					{ "vertical", L["Columns"], L["Frames fill a column, the next column goes to the side."] },
				},
			}),
			entry("growthX", L["Horizontal growth"], "select", { values = HORIZONTAL_GROWTH_VALUES }),
			entry("growthY", L["Vertical growth"], "select", {
				values = {
					{ "DOWN", L["Down"], glyph = "arrow-down" },
					{ "UP", L["Up"], glyph = "arrow-up" },
				},
			}),
			number("unitsPerColumn", L["Frames per row / column"], 1, 40, 1),
			number("columns", L["Rows / columns"], 1, 40, 1, {
				desc = L["Most rows or columns shown; frames that do not fit are not shown."],
			}),
			number("spacing", L["Spacing"], 0, 20, 1, { advanced = true }),
			number("groupSpacing", L["Row / column spacing"], 0, 40, 1, { advanced = true }),
		}
	end

	local function showIn()
		local row = entry("showInBattleground", L["Show in"], "multiselect", {
			values = {
				{ "showInBattleground", L["Battlegrounds"] },
				{ "showInRaid", L["Raids"], L["Raid groups outside battlegrounds, e.g. world PvP."] },
				{
					"showInParty",
					L["Party"],
					L["Use raid frames instead of the party frames in a party and in arenas."],
				},
			},
			desc = L["Party frames are hidden while the raid frames show your group."],
		})
		row.path = "raidFrames"
		return row
	end

	local function general()
		return {
			{ header = L["General"], glyph = "gear" },
			showIn(),
			entry("showPlayer", L["Show yourself in a party"], "toggle", { advanced = true }),
			entry("sort", L["Sort"], "select", {
				values = {
					{ "group", L["Group"] },
					{ "class", L["Class"], L["Healing classes first, then melee, then ranged."] },
					{ "name", L["Name"] },
				},
			}),
			number("outOfRangeAlpha", L["Out of range alpha"], 0, 1, 0.05, { percent = true, advanced = true }),
			entry("testCount", L["Test frame count"], "select", {
				values = { { 10, "10" }, { 15, "15" }, { 40, "40" } },
				desc = L["Number of fake frames in the unit frame test mode."],
			}),
		}
	end

	local function bars()
		return {
			{ header = L["Health bar"], glyph = "heart" },
			entry("classColor", L["Class color"], "toggle", {
				desc = L["Off: colored by the health percent."],
			}),
			entry("healthText", L["Health text"], "select", {
				values = {
					{ "none", L["None"] },
					{ "percent", L["Percent"] },
					{ "deficit", L["Missing health"] },
				},
			}),
			number("nameLength", L["Name length"], 2, 20, 1, { advanced = true }),
			entry("nameClassColor", L["Class-colored name"], "toggle"),
			entry("font", L["Text font"], "font", { advanced = true }),
			{ header = L["Power bar"], glyph = "bolt" },
			entry("power", L["Power bar"], "select", {
				values = {
					{ "all", L["All"] },
					{
						"healers",
						L["Healers"],
						L["Mana users of a healing class, unless their spec is known to be a damage spec."],
					},
					{ "mana", L["Mana"] },
					{ "none", L["None"] },
				},
			}),
			number("powerHeight", L["Power bar height"], 1, 20, 1, { advanced = true }),
		}
	end

	local function indicators()
		return {
			{ header = L["Crowd control"], glyph = "lock" },
			entry("ccIcon", L["Crowd control icon"], "toggle", {
				desc = L["Icon and timer of the strongest crowd control effect in the middle of the frame: stuns, fears and incapacitates first, then silences, disarms and roots."],
			}),
			number("ccIconSize", L["Icon size"], 10, 40, 1, { enabledBy = path("ccIcon"), advanced = true }),
			{ header = L["Dispel"], glyph = "hand-sparkles" },
			entry("dispel", L["Dispellable debuffs"], "toggle", {
				desc = L["Colors the frame by the type of a debuff on the unit."],
			}),
			entry("dispelMine", L["Only ones you can dispel"], "toggle", { enabledBy = path("dispel") }),
			entry("dispelStyle", L["Style"], "select", {
				enabledBy = path("dispel"),
				advanced = true,
				values = {
					{ "border", L["Border"] },
					{ "overlay", L["Overlay"], L["Uses the dispel highlight alpha of the General tab."] },
				},
			}),
			{ header = L["Auras"], glyph = "wand-magic-sparkles" },
			number("buffMax", L["Your buffs"], 0, 6, 1, {
				zeroText = L["Off"],
				desc = L["Your buffs on the unit, in the bottom-right corner."],
			}),
			entry("buffFilter", L["Show"], "select", {
				values = {
					{ "hots", L["Heals and protections"], L["Heals over time, shields and Hand spells."] },
					{ "all", L["All timed"] },
				},
			}),
			number("buffSize", L["Icon size"], 6, 30, 1, { advanced = true }),
			ns.ClickThrough(path("auraClickThrough"), ENABLED),
			{ header = L["Indicators"], glyph = "icons" },
			entry("raidIcon", L["Raid target icon"], "toggle"),
			number(
				"raidIconSize",
				L["Raid target icon size"],
				8,
				32,
				1,
				{ enabledBy = path("raidIcon"), advanced = true }
			),
			entry("leaderIcon", L["Leader icon"], "toggle", { desc = L["Leader and assistant marks."] }),
		}
	end

	registerElement({
		path = "raidFrames.point",
		tab = "raid",
		new = "1.4.1",
		name = L["Raid"],
		glyph = "people-group",
		enabledBy = { "unitFrames.enabled", ENABLED },
		schema = layout(),
	})

	raidTab = {
		key = "raid",
		name = L["Raid"],
		glyph = "people-group",
		schema = concat({
			{
				path = ENABLED,
				new = "1.4.1",
				label = L["Enable"],
				type = "toggle",
				desc = L["Compact frames for battlegrounds and raid groups."],
			},
		}, framesSection(), general(), layout(), bars()),
	}
	raidIndicatorsTab = {
		key = "raidIndicators",
		parent = "raid",
		name = L["Raid indicators"],
		glyph = "icons",
		schema = indicators(),
	}
end

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
	},
	tabs = {
		{
			key = "general",
			name = L["General"],
			glyph = "gear",
			schema = generalSchema(),
		},
		{
			key = "player",
			name = L["Player"],
			glyph = "user",
			copy = rectCopy("player"),
			schema = concat(
				framesSection(),
				frameLayout("player"),
				castbarSection("player", 100, 500),
				castbarLatency(),
				playerBuffSection(),
				playerDebuffSection(),
				playerIndicators()
			),
		},
		squareTabEntry("pet", "player", L["Pet"], "paw"),
		{
			key = "target",
			name = L["Target"],
			glyph = "bullseye",
			copy = rectCopy("target", TARGET_COPY),
			schema = concat(
				framesSection(),
				frameLayout("target"),
				castbarSection("target", 60, 400),
				targetAuras("target"),
				comboPoints()
			),
		},
		squareTabEntry("targetOfTarget", "target", L["Target of target"], "bullseye"),
		{
			key = "focus",
			name = L["Focus"],
			glyph = "eye",
			copy = rectCopy("focus", TARGET_COPY),
			schema = concat(
				framesSection(),
				frameLayout("focus"),
				castbarSection("focus", 60, 400),
				targetAuras("focus")
			),
		},
		squareTabEntry("focusTarget", "focus", L["Target of focus"], "bullseye"),
		{
			key = "party",
			name = L["Party"],
			glyph = "users",
			copy = rectCopy("party", GROUP_COPY),
			schema = concat(
				framesSection(),
				frameLayout("party", "unitFrames.showParty", L["Party frames"]),
				castbarSection("party", 60, 400, GROUP_CASTBAR_DESC, "unitFrames.showParty"),
				groupAuras("party", "unitFrames.showParty")
			),
		},
		squareTabEntry("partyPet", "party", L["Party pets"], "paw"),
		squareTabEntry("partyTarget", "party", L["Party targets"], "bullseye"),
		raidTab,
		raidIndicatorsTab,
		{
			key = "arena",
			name = L["Arena"],
			glyph = "crosshairs",
			copy = rectCopy("arena", GROUP_COPY),
			schema = concat(
				framesSection(),
				frameLayout("arena", "unitFrames.showArena", L["Arena frames"]),
				castbarSection("arena", 60, 400, GROUP_CASTBAR_DESC, "unitFrames.showArena"),
				groupAuras("arena", "unitFrames.showArena"),
				arenaUnseen()
			),
		},
		squareTabEntry("arenaPet", "arena", L["Arena pets"], "paw"),
		squareTabEntry("arenaTarget", "arena", L["Arena targets"], "bullseye"),
	},
})
