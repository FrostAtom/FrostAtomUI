local _, ns = ...

local ui = FrostAtomUI
local Section = ns.Section

local function notClass(class)
	return ui.PLAYER_CLASS ~= class
end

local schema = {}

Section(schema, "Player plate", "playerPlate", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		desc = "Compact health and power bars below the character.",
	},
	{
		path = "alwaysShow",
		label = "Always show",
		type = "toggle",
		desc = "Keep visible out of combat at full health.",
	},
	{
		path = "fadeTime",
		label = "Fade out time",
		type = "number",
		min = 0,
		max = 3,
		step = 0.1,
		desc = "Seconds to fade out after leaving combat at full health. 0 hides instantly.",
		disabled = function()
			return ui:GetConfig("playerPlate.alwaysShow")
		end,
	},
	{ path = "point", label = "Position", type = "point" },
	{ path = "width", label = "Width", type = "number", min = 60, max = 400, step = 1 },
	{ path = "healthHeight", label = "Health bar height", type = "number", min = 3, max = 40, step = 1 },
	{ path = "powerHeight", label = "Power bar height", type = "number", min = 2, max = 40, step = 1 },
	{ path = "gap", label = "Bar spacing", type = "number", min = 0, max = 20, step = 1 },
	{
		path = "showText",
		label = "Show values",
		type = "toggle",
		desc = "Current health and power numbers on the bars.",
	},
	{ path = "font", label = "Font", type = "font" },
	{
		path = "classColorHealth",
		label = "Class colored health",
		type = "toggle",
		desc = "Health bar in your class color instead of a fixed color.",
	},
	{
		path = "healthColor",
		label = "Health color",
		type = "color",
		desc = "Used when class coloring is off.",
		disabled = function()
			return ui:GetConfig("playerPlate.classColorHealth")
		end,
	},
})

Section(schema, "Shield indicator", "shieldIndicator", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		desc = "Show the equipped shield icon next to the player plate.",
	},
	{ path = "point", label = "Position", type = "point" },
	{ path = "size", label = "Icon size", type = "number", min = 12, max = 64, step = 1 },
}, notClass("WARRIOR"))

Section(schema, "Runes", "runes", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		reload = true,
		desc = "Replace the Blizzard rune frame.",
	},
	{ path = "point", label = "Position", type = "point" },
	{ path = "width", label = "Rune width", type = "number", min = 10, max = 100, step = 1 },
	{ path = "height", label = "Rune height", type = "number", min = 4, max = 40, step = 1 },
	{ path = "gap", label = "Spacing", type = "number", min = 0, max = 12, step = 1 },
	{ path = "bloodColor", label = "Blood", type = "color" },
	{ path = "unholyColor", label = "Unholy", type = "color" },
	{ path = "frostColor", label = "Frost", type = "color" },
	{ path = "deathColor", label = "Death", type = "color", desc = "Runes converted to death runes." },
	{ path = "emptyColor", label = "Empty", type = "color", desc = "Runes on cooldown." },
}, notClass("DEATHKNIGHT"))

Section(schema, "Totems", "totems", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		desc = "Totem icons with timers, right-click to destroy.",
	},
	{ path = "point", label = "Position", type = "point" },
	{ path = "size", label = "Icon size", type = "number", min = 16, max = 64, step = 1 },
	{ path = "gap", label = "Spacing", type = "number", min = 0, max = 12, step = 1 },
	{ path = "timerFont", label = "Timer font", type = "font" },
}, notClass("SHAMAN"))

Section(schema, "Aura tracker", "auraTracker", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		desc = "Class-specific proc and buff icons around the character.",
	},
	{ path = "scale", label = "Scale", type = "number", min = 0.5, max = 2, step = 0.05 },
	{
		path = "auras." .. ui.PLAYER_CLASS,
		label = "Add spell ID",
		type = "list",
		desc = "Track an aura by spell ID. Press Enter or Add.",
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
				label = "Unit",
				type = "select",
				values = { { "player", "Player" }, { "target", "Target" }, { "focus", "Focus" } },
				desc = "Whose auras to scan for this spell.",
			},
			{ key = "debuff", label = "Debuff", type = "toggle", desc = "Look for a debuff instead of a buff." },
			{ key = "isMine", label = "Only mine", type = "toggle", desc = "Only auras applied by you." },
			{ key = "size", label = "Size", type = "number", min = 16, max = 80, step = 1 },
			{ key = "point", label = "Position", type = "point" },
		},
	},
})

Section(schema, "Weapon enchants", "temporaryEnchant", {
	{
		path = "enabled",
		label = "Enable",
		type = "toggle",
		reload = true,
		desc = "Replace the Blizzard temporary enchant icons, right-click to cancel.",
	},
	{ path = "point", label = "Position", type = "point" },
	{ path = "size", label = "Icon size", type = "number", min = 16, max = 64, step = 1 },
	{ path = "gap", label = "Spacing", type = "number", min = 0, max = 12, step = 1 },
})

ns.RegisterPage({
	key = "player",
	name = "Player resources",
	order = 30,
	schema = schema,
})
