local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local Section = ns.Section
local ElementSchema = ns.ElementSchema
local NotClass = ns.NotClass

local HEALTH_COLOR_VALUES = {
	{ "class", L["Class color"], L["Your class color."] },
	{ "health", L["Health percent"], L["A color mixed from the current health percent."] },
	{ "custom", L["Fixed color"], L["The health color below."] },
}

local HEALTH_TEXT_VALUES = {
	{ "percent", L["Percent"] },
	{ "value", L["Current health"] },
}

local schema = {
	{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
	{ type = "elements" },
}

Section(schema, L["Player plate"], "playerPlate", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Compact health and power bars below the character."],
	},
	{
		path = "alwaysShow",
		label = L["Always show"],
		type = "toggle",
		desc = L["Keep visible out of combat at full health."],
	},
	{
		path = "fadeTime",
		advanced = true,
		label = L["Fade out time"],
		type = "number",
		min = 0,
		max = 3,
		step = 0.1,
		unit = "s",
		zeroText = L["Instant"],
		desc = L["Time to fade out after leaving combat at full health."],
		disabled = function()
			return ui:GetConfig("playerPlate.alwaysShow")
		end,
		disabledDesc = L["Not used while Always show is on."],
	},
}, nil, nil, "heart-pulse")

Section(schema, L["Shield indicator"], "shieldIndicator", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Show the equipped shield icon next to the player plate."],
	},
}, NotClass("WARRIOR"), nil, "shield-halved")

Section(schema, L["Runes"], "runes", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace the Blizzard rune frame."],
	},
}, NotClass("DEATHKNIGHT"), nil, "gem")

Section(schema, L["Totems"], "totems", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Totem icons with timers, right-click to destroy."],
	},
	ns.ClickThrough("clickThrough"),
}, NotClass("SHAMAN"), nil, "monument")

local enchantClickThrough = ns.ClickThrough("clickThrough")
enchantClickThrough.disabled = function()
	return ui:GetConfig("temporaryEnchant.showInAuras") and ui:GetConfig("unitFrames.enabled")
end
enchantClickThrough.disabledDesc = L["In the player buffs the enchants follow the click-through of the player buffs."]

Section(schema, L["Weapon enchants"], "temporaryEnchant", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace the Blizzard temporary enchant icons, right-click to cancel."],
	},
	{
		path = "showInAuras",
		new = "1.4.1",
		label = L["Show in player buffs"],
		type = "toggle",
		desc = L["Show the enchants in the player buff list like buffs, in front of all other buffs, instead of separate icons. Needs the unit frames."],
		enabledBy = "unitFrames.enabled",
	},
	enchantClickThrough,
}, nil, nil, "wand-sparkles")

ns.RegisterPage({
	key = "player",
	name = L["Player resources"],
	glyph = "user",
	order = 26,
	group = "frames",
	schema = schema,
})

ns.RegisterElement({
	path = "playerPlate.point",
	page = "player",
	name = L["Player plate"],
	glyph = "heart-pulse",
	enabledBy = "playerPlate.enabled",
	schema = ElementSchema("playerPlate", {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{ path = "width", label = L["Width"], type = "number", min = 60, max = 400, step = 1 },
		{ path = "healthHeight", label = L["Health bar height"], type = "number", min = 3, max = 40, step = 1 },
		{ header = L["Display"], glyph = "bars-staggered" },
		{
			path = "showPower",
			new = "1.4.0",
			label = L["Power bar"],
			type = "toggle",
			desc = L["Mana, rage, energy or runic power below the health bar."],
		},
		{
			path = "powerHeight",
			advanced = true,
			label = L["Power bar height"],
			type = "number",
			min = 2,
			max = 40,
			step = 1,
			enabledBy = "playerPlate.showPower",
		},
		{
			path = "gap",
			advanced = true,
			label = L["Bar spacing"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			desc = L["Gap between the health and power bars."],
			enabledBy = "playerPlate.showPower",
		},
		{
			path = "druidMana",
			advanced = true,
			new = "1.4.1",
			label = L["Mana in shapeshift forms"],
			type = "toggle",
			hidden = NotClass("DRUID"),
			desc = L["Thin mana bar at the bottom of the plate while in bear or cat form."],
		},
		{
			path = "healPrediction",
			new = "1.4.0",
			label = L["Incoming heals"],
			type = "toggle",
			desc = L["Segment after the health fill for heals being cast on you. Colors are shared with the unit frames."],
		},
		{
			path = "absorbs",
			new = "1.4.0",
			label = L["Absorb shields"],
			type = "toggle",
			desc = L["Estimated size of absorb shields on you, with a glow at the bar edge while a shield is up. Colors are shared with the unit frames."],
		},
		{ header = L["Text"], glyph = "font" },
		{
			path = "showText",
			label = L["Values"],
			type = "toggle",
			desc = L["Health and power numbers on the bars."],
		},
		{
			path = "healthText",
			advanced = true,
			new = "1.4.0",
			label = L["Health text"],
			type = "select",
			values = HEALTH_TEXT_VALUES,
			enabledBy = "playerPlate.showText",
		},
		{ path = "font", advanced = true, label = L["Font"], type = "font", enabledBy = "playerPlate.showText" },
		{ header = L["Colors"], glyph = "palette" },
		{
			path = "healthColorMode",
			label = L["Health bar color"],
			type = "select",
			values = HEALTH_COLOR_VALUES,
		},
		{
			path = "healthColor",
			advanced = true,
			label = L["Health color"],
			type = "color",
			desc = L["Used with the fixed color mode."],
			disabled = function()
				return ui:GetConfig("playerPlate.healthColorMode") ~= "custom"
			end,
		},
	}),
})

ns.RegisterElement({
	path = "shieldIndicator.point",
	page = "player",
	name = L["Shield indicator"],
	glyph = "shield-halved",
	enabledBy = "shieldIndicator.enabled",
	hidden = NotClass("WARRIOR"),
	schema = ElementSchema("shieldIndicator", {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 64, step = 1 },
	}),
})

ns.RegisterElement({
	path = "runes.point",
	page = "player",
	name = L["Runes"],
	glyph = "gem",
	enabledBy = "runes.enabled",
	hidden = NotClass("DEATHKNIGHT"),
	schema = ElementSchema("runes", {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{ path = "width", label = L["Rune width"], type = "number", min = 10, max = 100, step = 1 },
		{ path = "height", label = L["Rune height"], type = "number", min = 4, max = 40, step = 1 },
		{ path = "gap", advanced = true, label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
		{ header = L["Colors"], glyph = "palette", advanced = true },
		{ path = "bloodColor", label = L["Blood"], type = "color" },
		{ path = "unholyColor", label = L["Unholy"], type = "color" },
		{ path = "frostColor", label = L["Frost"], type = "color" },
		{ path = "deathColor", label = L["Death"], type = "color", desc = L["Runes converted to death runes."] },
		{ path = "emptyColor", label = L["Empty"], type = "color", desc = L["Runes on cooldown."] },
	}),
})

ns.RegisterElement({
	path = "totems.point",
	page = "player",
	name = L["Totems"],
	glyph = "monument",
	enabledBy = "totems.enabled",
	hidden = NotClass("SHAMAN"),
	schema = ElementSchema("totems", {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{ path = "size", label = L["Icon size"], type = "number", min = 16, max = 64, step = 1 },
		{ path = "gap", advanced = true, label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
		{ header = L["Text"], glyph = "font", advanced = true },
		{ path = "timerFont", label = L["Timer font"], type = "font", desc = L["Remaining totem time on the icons."] },
	}),
})

ns.RegisterElement({
	path = "temporaryEnchant.point",
	page = "player",
	name = L["Weapon enchants"],
	glyph = "wand-sparkles",
	enabledBy = "temporaryEnchant.enabled",
	disabled = function()
		return ui:GetConfig("temporaryEnchant.showInAuras") and ui:GetConfig("unitFrames.enabled")
	end,
	schema = ElementSchema("temporaryEnchant", {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{ path = "size", label = L["Icon size"], type = "number", min = 16, max = 64, step = 1 },
		{ path = "gap", advanced = true, label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
		{ header = L["Text"], glyph = "font" },
		{
			path = "showTimer",
			new = "1.4.0",
			label = L["Timer"],
			type = "toggle",
			desc = L["Remaining enchant time on the icons."],
		},
		{
			path = "timerFont",
			advanced = true,
			new = "1.4.0",
			label = L["Timer font"],
			type = "font",
			enabledBy = "temporaryEnchant.showTimer",
		},
	}),
})
