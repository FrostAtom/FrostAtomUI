local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local Section = ns.Section
local ElementSchema = ns.ElementSchema
local NotClass = ns.NotClass

local HEALTH_COLOR_VALUES = {
	{ "class", L["Class color"] },
	{ "health", L["Health percent"] },
	{ "custom", L["Fixed color"] },
}

local HEALTH_TEXT_VALUES = {
	{ "percent", L["Percent"] },
	{ "value", L["Current health"] },
}

local schema = {
	{ header = L["Frames"] },
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
		label = L["Fade out time"],
		type = "number",
		min = 0,
		max = 3,
		step = 0.1,
		desc = L["Seconds to fade out after leaving combat at full health. 0 hides instantly."],
		disabled = function()
			return ui:GetConfig("playerPlate.alwaysShow")
		end,
	},
})

Section(schema, L["Shield indicator"], "shieldIndicator", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Show the equipped shield icon next to the player plate."],
	},
}, NotClass("WARRIOR"))

Section(schema, L["Runes"], "runes", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace the Blizzard rune frame."],
	},
}, NotClass("DEATHKNIGHT"))

Section(schema, L["Totems"], "totems", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Totem icons with timers, right-click to destroy."],
	},
}, NotClass("SHAMAN"))

Section(schema, L["Weapon enchants"], "temporaryEnchant", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace the Blizzard temporary enchant icons, right-click to cancel."],
	},
})

ns.RegisterPage({
	key = "player",
	name = L["Player resources"],
	order = 30,
	schema = schema,
})

ns.RegisterElement({
	path = "playerPlate.point",
	page = "player",
	name = L["Player plate"],
	enabledBy = "playerPlate.enabled",
	schema = ElementSchema("playerPlate", {
		{ header = L["Bars"] },
		{
			path = "showPower",
			new = "1.4.0",
			label = L["Show power bar"],
			type = "toggle",
			desc = L["Mana, rage, energy or runic power below the health bar."],
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
		{ header = L["Size"] },
		{ path = "width", label = L["Width"], type = "number", min = 60, max = 400, step = 1 },
		{ path = "healthHeight", label = L["Health bar height"], type = "number", min = 3, max = 40, step = 1 },
		{
			path = "powerHeight",
			label = L["Power bar height"],
			type = "number",
			min = 2,
			max = 40,
			step = 1,
			enabledBy = "playerPlate.showPower",
		},
		{
			path = "gap",
			label = L["Bar spacing"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			desc = L["Gap between the health and power bars."],
			enabledBy = "playerPlate.showPower",
		},
		{ header = L["Text"] },
		{
			path = "showText",
			label = L["Show values"],
			type = "toggle",
			desc = L["Health and power numbers on the bars."],
		},
		{
			path = "healthText",
			new = "1.4.0",
			label = L["Health text"],
			type = "select",
			values = HEALTH_TEXT_VALUES,
			enabledBy = "playerPlate.showText",
		},
		{ path = "font", label = L["Font"], type = "font", enabledBy = "playerPlate.showText" },
		{ header = L["Colors"] },
		{
			path = "healthColorMode",
			label = L["Health bar color"],
			type = "select",
			values = HEALTH_COLOR_VALUES,
			desc = L["Your class color, a color mixed from the current health percent, or a fixed color."],
		},
		{
			path = "healthColor",
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
	enabledBy = "shieldIndicator.enabled",
	hidden = NotClass("WARRIOR"),
	schema = ElementSchema("shieldIndicator", {
		{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 64, step = 1 },
	}),
})

ns.RegisterElement({
	path = "runes.point",
	page = "player",
	name = L["Runes"],
	enabledBy = "runes.enabled",
	hidden = NotClass("DEATHKNIGHT"),
	schema = ElementSchema("runes", {
		{ header = L["Size"] },
		{ path = "width", label = L["Rune width"], type = "number", min = 10, max = 100, step = 1 },
		{ path = "height", label = L["Rune height"], type = "number", min = 4, max = 40, step = 1 },
		{ path = "gap", label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
		{ header = L["Colors"] },
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
	enabledBy = "totems.enabled",
	hidden = NotClass("SHAMAN"),
	schema = ElementSchema("totems", {
		{ path = "size", label = L["Icon size"], type = "number", min = 16, max = 64, step = 1 },
		{ path = "gap", label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
		{ path = "timerFont", label = L["Timer font"], type = "font" },
	}),
})

ns.RegisterElement({
	path = "temporaryEnchant.point",
	page = "player",
	name = L["Weapon enchants"],
	enabledBy = "temporaryEnchant.enabled",
	schema = ElementSchema("temporaryEnchant", {
		{ path = "size", label = L["Icon size"], type = "number", min = 16, max = 64, step = 1 },
		{ path = "gap", label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
		{
			path = "showTimer",
			new = "1.4.0",
			label = L["Show timer"],
			type = "toggle",
			desc = L["Remaining enchant time on the icons."],
		},
		{
			path = "timerFont",
			new = "1.4.0",
			label = L["Timer font"],
			type = "font",
			enabledBy = "temporaryEnchant.showTimer",
		},
	}),
})
