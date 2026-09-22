local _, ns = ...

local L = FrostAtomUI.L

local ui = FrostAtomUI
local Section = ns.Section

local HEALTH_COLOR_VALUES = {
	{ "class", L["Class color"] },
	{ "health", L["Health percent"] },
	{ "custom", L["Fixed color"] },
}

local function notClass(class)
	return ui.PLAYER_CLASS ~= class
end

local schema = {}

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
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "width", label = L["Width"], type = "number", min = 60, max = 400, step = 1 },
	{ path = "healthHeight", label = L["Health bar height"], type = "number", min = 3, max = 40, step = 1 },
	{ path = "powerHeight", label = L["Power bar height"], type = "number", min = 2, max = 40, step = 1 },
	{ path = "gap", label = L["Bar spacing"], type = "number", min = 0, max = 20, step = 1 },
	{
		path = "showText",
		label = L["Show values"],
		type = "toggle",
		desc = L["Current health and power numbers on the bars."],
	},
	{ path = "font", label = L["Font"], type = "font" },
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
})

Section(schema, L["Shield indicator"], "shieldIndicator", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Show the equipped shield icon next to the player plate."],
	},
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 64, step = 1 },
}, notClass("WARRIOR"))

Section(schema, L["Runes"], "runes", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace the Blizzard rune frame."],
	},
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "width", label = L["Rune width"], type = "number", min = 10, max = 100, step = 1 },
	{ path = "height", label = L["Rune height"], type = "number", min = 4, max = 40, step = 1 },
	{ path = "gap", label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
	{ path = "bloodColor", label = L["Blood"], type = "color" },
	{ path = "unholyColor", label = L["Unholy"], type = "color" },
	{ path = "frostColor", label = L["Frost"], type = "color" },
	{ path = "deathColor", label = L["Death"], type = "color", desc = L["Runes converted to death runes."] },
	{ path = "emptyColor", label = L["Empty"], type = "color", desc = L["Runes on cooldown."] },
}, notClass("DEATHKNIGHT"))

Section(schema, L["Totems"], "totems", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Totem icons with timers, right-click to destroy."],
	},
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "size", label = L["Icon size"], type = "number", min = 16, max = 64, step = 1 },
	{ path = "gap", label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
	{ path = "timerFont", label = L["Timer font"], type = "font" },
}, notClass("SHAMAN"))

Section(schema, L["Aura tracker"], "auraTracker", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Class-specific proc and buff icons around the character."],
	},
	{ path = "scale", label = L["Scale"], type = "number", min = 0.5, max = 2, step = 0.05 },
	{
		path = "auras." .. ui.PLAYER_CLASS,
		label = L["Add spell ID"],
		type = "list",
		desc = L["Track an aura by spell ID. Press Enter or Add."],
		create = function(id)
			if not GetSpellInfo(id) then
				return nil
			end
			return { spell = id, unit = "player", point = { "CENTER", 0, -72 }, size = 36 }
		end,
		describe = function(item)
			local name, _, icon = GetSpellInfo(item.spell)
			return ("%s (%d)"):format(name or "?", item.spell), icon
		end,
		fields = {
			{
				key = "unit",
				label = L["Unit"],
				type = "select",
				values = { { "player", L["Player"] }, { "target", L["Target"] }, { "focus", L["Focus"] } },
				desc = L["Whose auras to scan for this spell."],
			},
			{ key = "debuff", label = L["Debuff"], type = "toggle", desc = L["Look for a debuff instead of a buff."] },
			{ key = "isMine", label = L["Only mine"], type = "toggle", desc = L["Only auras applied by you."] },
			{ key = "size", label = L["Size"], type = "number", min = 16, max = 80, step = 1 },
			{ key = "point", label = L["Position"], type = "point" },
		},
	},
})

Section(schema, L["Weapon enchants"], "temporaryEnchant", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace the Blizzard temporary enchant icons, right-click to cancel."],
	},
	{ path = "point", label = L["Position"], type = "point" },
	{ path = "size", label = L["Icon size"], type = "number", min = 16, max = 64, step = 1 },
	{ path = "gap", label = L["Spacing"], type = "number", min = 0, max = 12, step = 1 },
})

ns.RegisterPage({
	key = "player",
	name = L["Player resources"],
	order = 30,
	schema = schema,
})
