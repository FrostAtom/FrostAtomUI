local _, ns = ...

local schema = {
	{
		path = "actionBar.enabled",
		label = "Enable",
		type = "toggle",
		reload = true,
		desc = "Replace Blizzard action bars.",
	},
	{ path = "actionBar.gap", label = "Button spacing", type = "number", min = 0, max = 12, step = 1 },
	{
		path = "actionBar.clickAnimation",
		label = "Click animation",
		type = "toggle",
		desc = "Star burst on a pressed button. Toggle with /vr.",
	},
	{ header = "Micro menu and bags" },
	{ path = "actionBar.microMenu", label = "Micro menu position", type = "point" },
	{
		path = "actionBar.microMenuScale",
		label = "Micro menu scale",
		type = "number",
		min = 0.5,
		max = 2,
		step = 0.05,
	},
	{
		path = "actionBar.microMenuMouseover",
		label = "Micro menu on mouseover",
		type = "toggle",
		desc = "Keep the micro menu faded until the cursor is over it.",
	},
	{ path = "actionBar.bagButton", label = "Bag button position", type = "point" },
	{
		path = "actionBar.bagButtonMouseover",
		label = "Bag button on mouseover",
		type = "toggle",
		desc = "Keep the bag button faded until the cursor is over it.",
	},
	{
		path = "actionBar.menuFadeAlpha",
		label = "Faded alpha",
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		enabledByAny = { "actionBar.microMenuMouseover", "actionBar.bagButtonMouseover" },
	},
}

local function bar(header, key, hasToggle, hasCount)
	local prefix = "actionBar." .. key
	schema[#schema + 1] = { header = header }
	local enabledBy
	if hasToggle then
		enabledBy = prefix .. ".enabled"
		schema[#schema + 1] = { path = enabledBy, label = "Show", type = "toggle" }
	end
	schema[#schema + 1] = { path = prefix .. ".point", label = "Position", type = "point", enabledBy = enabledBy }
	if hasCount then
		schema[#schema + 1] = {
			path = prefix .. ".buttons",
			label = "Buttons",
			type = "number",
			min = 1,
			max = 12,
			step = 1,
			enabledBy = enabledBy,
			desc = "Number of slots shown on the bar.",
		}
	end
	schema[#schema + 1] = {
		path = prefix .. ".columns",
		label = "Columns",
		type = "number",
		min = 1,
		max = 12,
		step = 1,
		enabledBy = enabledBy,
		desc = "Buttons per row.",
	}
	schema[#schema + 1] = {
		path = prefix .. ".buttonSize",
		label = "Button size",
		type = "number",
		min = 16,
		max = 60,
		step = 1,
		enabledBy = enabledBy,
	}
end

bar("Bar 1", "bar1", false, true)
bar("Bar 2", "bar2", true, true)
bar("Bar 3", "bar3", true, true)
bar("Bar 4", "bar4", true, true)
bar("Bar 5", "bar5", true, true)
bar("Stance bar", "stance", false, false)
bar("Pet bar", "pet", false, false)

schema[#schema + 1] = { header = "Text" }
schema[#schema + 1] = { path = "actionBar.showHotkeys", label = "Show hotkeys", type = "toggle" }
schema[#schema + 1] = {
	path = "actionBar.showShapeshiftHotkeys",
	label = "Stance bar hotkeys",
	type = "toggle",
	enabledBy = "actionBar.showHotkeys",
	desc = "Also show key bindings on stance / form buttons.",
}
schema[#schema + 1] =
	{ path = "actionBar.hotkeyFont", label = "Hotkey font", type = "font", enabledBy = "actionBar.showHotkeys" }
schema[#schema + 1] = {
	path = "actionBar.showNames",
	label = "Show macro names / counts",
	type = "toggle",
	desc = "Macro name or item count at the bottom of the button.",
}
schema[#schema + 1] =
	{ path = "actionBar.nameFont", label = "Name font", type = "font", enabledBy = "actionBar.showNames" }
schema[#schema + 1] = { header = "Colors" }
schema[#schema + 1] = {
	path = "actionBar.rangeColor",
	label = "Out of range",
	type = "color",
	desc = "Icon tint when the target is out of range.",
}
schema[#schema + 1] = {
	path = "actionBar.manaColor",
	label = "Not enough mana",
	type = "color",
	desc = "Icon tint when the ability cannot be afforded.",
}
schema[#schema + 1] = {
	path = "actionBar.unusableColor",
	label = "Unusable",
	type = "color",
	desc = "Icon tint when the ability cannot be used for any other reason.",
}

ns.RegisterPage({
	key = "actionbar",
	name = "Action bars",
	order = 15,
	enable = "actionBar.enabled",
	schema = schema,
})
