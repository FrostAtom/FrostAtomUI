local _, ns = ...

local L = FrostAtomUI.L

local DRAG_BUTTON_VALUES = {
	{ "LeftButton", L["Left button"] },
	{ "RightButton", L["Right button"] },
	{ "MiddleButton", L["Middle button"] },
}

local DRAG_MODIFIER_VALUES = {
	{ "none", L["No modifier"] },
	{ "shift", L["Shift"] },
	{ "ctrl", L["Ctrl"] },
	{ "alt", L["Alt"] },
}

local schema = {
	{
		path = "actionBar.enabled",
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace Blizzard action bars."],
	},
	{ path = "actionBar.gap", label = L["Button spacing"], type = "number", min = 0, max = 12, step = 1 },
	{
		path = "actionBar.clickAnimation",
		label = L["Click animation"],
		type = "toggle",
		desc = L["Star burst on a pressed button. Toggle with /vr."],
	},
	{
		path = "actionBar.dragButton",
		label = L["Drag spells with"],
		type = "select",
		values = DRAG_BUTTON_VALUES,
		desc = L["Mouse button that picks a spell up from a bar button. Dropping always works with any button."],
	},
	{
		path = "actionBar.dragModifier",
		label = L["Drag modifier"],
		type = "select",
		values = DRAG_MODIFIER_VALUES,
		desc = L["Key to hold while dragging a spell off a bar. Without a modifier a spell can be dragged away by accident."],
	},
	{ header = L["Micro menu and bags"] },
	{ path = "actionBar.microMenu", label = L["Micro menu position"], type = "point" },
	{
		path = "actionBar.microMenuScale",
		label = L["Micro menu scale"],
		type = "number",
		min = 0.5,
		max = 2,
		step = 0.05,
	},
	{
		path = "actionBar.microMenuMouseover",
		label = L["Micro menu on mouseover"],
		type = "toggle",
		desc = L["Keep the micro menu faded until the cursor is over it."],
	},
	{ path = "actionBar.bagButton", label = L["Bag button position"], type = "point" },
	{
		path = "actionBar.bagButtonMouseover",
		label = L["Bag button on mouseover"],
		type = "toggle",
		desc = L["Keep the bag button faded until the cursor is over it."],
	},
	{
		path = "actionBar.menuFadeAlpha",
		label = L["Faded alpha"],
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
		schema[#schema + 1] = { path = enabledBy, label = L["Show"], type = "toggle" }
	end
	schema[#schema + 1] = { path = prefix .. ".point", label = L["Position"], type = "point", enabledBy = enabledBy }
	if hasCount then
		schema[#schema + 1] = {
			path = prefix .. ".buttons",
			label = L["Buttons"],
			type = "number",
			min = 1,
			max = 12,
			step = 1,
			enabledBy = enabledBy,
			desc = L["Number of slots shown on the bar."],
		}
	end
	schema[#schema + 1] = {
		path = prefix .. ".columns",
		label = L["Columns"],
		type = "number",
		min = 1,
		max = 12,
		step = 1,
		enabledBy = enabledBy,
		desc = L["Buttons per row."],
	}
	schema[#schema + 1] = {
		path = prefix .. ".buttonSize",
		label = L["Button size"],
		type = "number",
		min = 16,
		max = 60,
		step = 1,
		enabledBy = enabledBy,
	}
end

bar(L["Bar 1"], "bar1", false, true)
bar(L["Bar 2"], "bar2", true, true)
bar(L["Bar 3"], "bar3", true, true)
bar(L["Bar 4"], "bar4", true, true)
bar(L["Bar 5"], "bar5", true, true)
bar(L["Stance bar"], "stance", false, false)
bar(L["Pet bar"], "pet", false, false)

schema[#schema + 1] = { header = L["Text"] }
schema[#schema + 1] = { path = "actionBar.showHotkeys", label = L["Show hotkeys"], type = "toggle" }
schema[#schema + 1] = {
	path = "actionBar.showShapeshiftHotkeys",
	label = L["Stance bar hotkeys"],
	type = "toggle",
	enabledBy = "actionBar.showHotkeys",
	desc = L["Also show key bindings on stance / form buttons."],
}
schema[#schema + 1] =
	{ path = "actionBar.hotkeyFont", label = L["Hotkey font"], type = "font", enabledBy = "actionBar.showHotkeys" }
schema[#schema + 1] = {
	path = "actionBar.showNames",
	label = L["Show macro names / counts"],
	type = "toggle",
	desc = L["Macro name or item count at the bottom of the button."],
}
schema[#schema + 1] =
	{ path = "actionBar.nameFont", label = L["Name font"], type = "font", enabledBy = "actionBar.showNames" }
schema[#schema + 1] = { header = L["Colors"] }
schema[#schema + 1] = {
	path = "actionBar.rangeColor",
	label = L["Out of range"],
	type = "color",
	desc = L["Icon tint when the target is out of range."],
}
schema[#schema + 1] = {
	path = "actionBar.manaColor",
	label = L["Not enough mana"],
	type = "color",
	desc = L["Icon tint when the ability cannot be afforded."],
}
schema[#schema + 1] = {
	path = "actionBar.unusableColor",
	label = L["Unusable"],
	type = "color",
	desc = L["Icon tint when the ability cannot be used for any other reason."],
}

ns.RegisterPage({
	key = "actionbar",
	name = L["Action bars"],
	order = 15,
	enable = "actionBar.enabled",
	schema = schema,
})
