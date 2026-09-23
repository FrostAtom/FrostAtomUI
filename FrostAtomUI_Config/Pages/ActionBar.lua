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

local PAGE = "actionbar"
local ENABLE = "actionBar.enabled"

local function barElement(name, key, hasToggle, hasCount)
	local prefix = "actionBar." .. key
	local enabledBy
	local schema = { { header = L["Layout"] } }
	if hasToggle then
		enabledBy = prefix .. ".enabled"
		schema[#schema + 1] = { path = enabledBy, label = L["Show"], type = "toggle" }
	end
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
	schema[#schema + 1] = {
		path = prefix .. ".spacing",
		label = L["Spacing"],
		type = "number",
		min = 0,
		max = 12,
		step = 1,
		enabledBy = enabledBy,
		desc = L["Gap between buttons."],
	}
	schema[#schema + 1] = { header = L["Visibility"] }
	schema[#schema + 1] = {
		path = prefix .. ".mouseover",
		new = "1.4.0",
		label = L["Show on mouseover"],
		type = "toggle",
		enabledBy = enabledBy,
		desc = L["Keep the bar faded until the cursor is over it or a spell is being dragged."],
	}
	schema[#schema + 1] = {
		path = prefix .. ".fadeAlpha",
		new = "1.4.0",
		label = L["Faded alpha"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		enabledBy = enabledBy and { enabledBy, prefix .. ".mouseover" } or prefix .. ".mouseover",
	}

	ns.RegisterElement({
		path = prefix .. ".point",
		page = PAGE,
		name = name,
		enabledBy = ENABLE,
		schema = schema,
	})
end

barElement(L["Bar 1"], "bar1", false, true)
barElement(L["Bar 2"], "bar2", true, true)
barElement(L["Bar 3"], "bar3", true, true)
barElement(L["Bar 4"], "bar4", true, true)
barElement(L["Bar 5"], "bar5", true, true)
barElement(L["Stance bar"], "stance", false, false)
barElement(L["Pet bar"], "pet", false, false)

ns.RegisterElement({
	path = "actionBar.microMenu",
	page = PAGE,
	name = L["Micro menu"],
	enabledBy = ENABLE,
	schema = {
		{ header = L["Layout"] },
		{
			path = "actionBar.microMenuScale",
			label = L["Scale"],
			type = "number",
			min = 0.5,
			max = 2,
			step = 0.05,
		},
		{ header = L["Visibility"] },
		{
			path = "actionBar.microMenuMouseover",
			label = L["Show on mouseover"],
			type = "toggle",
			desc = L["Keep the micro menu faded until the cursor is over it."],
		},
		{
			path = "actionBar.menuFadeAlpha",
			label = L["Faded alpha"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			enabledBy = "actionBar.microMenuMouseover",
			desc = L["Shared by the micro menu and the bag button."],
		},
	},
})

ns.RegisterElement({
	path = "actionBar.bagButton",
	page = PAGE,
	name = L["Bag button"],
	enabledBy = ENABLE,
	schema = {
		{ header = L["Visibility"] },
		{
			path = "actionBar.bagButtonMouseover",
			label = L["Show on mouseover"],
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
			enabledBy = "actionBar.bagButtonMouseover",
			desc = L["Shared by the micro menu and the bag button."],
		},
	},
})

local schema = {
	{
		path = ENABLE,
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace Blizzard action bars."],
	},
	{ type = "elements" },
	{ header = L["General"] },
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
	{ header = L["Text"] },
	{ path = "actionBar.showHotkeys", label = L["Show hotkeys"], type = "toggle" },
	{
		path = "actionBar.showShapeshiftHotkeys",
		label = L["Stance bar hotkeys"],
		type = "toggle",
		enabledBy = "actionBar.showHotkeys",
		desc = L["Also show key bindings on stance / form buttons."],
	},
	{ path = "actionBar.hotkeyFont", label = L["Hotkey font"], type = "font", enabledBy = "actionBar.showHotkeys" },
	{
		path = "actionBar.showNames",
		label = L["Show macro names / counts"],
		type = "toggle",
		desc = L["Macro name or item count at the bottom of the button."],
	},
	{ path = "actionBar.nameFont", label = L["Name font"], type = "font", enabledBy = "actionBar.showNames" },
	{ header = L["Colors"] },
	{
		path = "actionBar.rangeColor",
		label = L["Out of range"],
		type = "color",
		desc = L["Icon tint when the target is out of range."],
	},
	{
		path = "actionBar.manaColor",
		label = L["Not enough mana"],
		type = "color",
		desc = L["Icon tint when the ability cannot be afforded."],
	},
	{
		path = "actionBar.unusableColor",
		label = L["Unusable"],
		type = "color",
		desc = L["Icon tint when the ability cannot be used for any other reason."],
	},
	{ header = L["Range and cooldowns"] },
	{
		path = "actionBar.rangeIconTint",
		new = "1.4.0",
		label = L["Tint icon out of range"],
		type = "toggle",
		desc = L["Color the icon with the out of range color."],
	},
	{
		path = "actionBar.rangeHotkey",
		new = "1.4.0",
		label = L["Color hotkey out of range"],
		type = "toggle",
		desc = L["Color the key binding text with the out of range color."],
	},
	{
		path = "actionBar.desaturateOnCooldown",
		new = "1.4.0",
		label = L["Desaturate on cooldown"],
		type = "toggle",
		desc = L["Grey out the icon while the ability is on cooldown. The global cooldown is ignored."],
	},
	{
		path = "actionBar.lossOfControl",
		new = "1.4.0",
		label = L["Loss of control"],
		type = "toggle",
		desc = L["Red overlay with the remaining duration on abilities you cannot use while stunned, feared, polymorphed or silenced."],
	},
	{
		path = "actionBar.interruptLockout",
		new = "1.4.0",
		label = L["Interrupt lockout"],
		type = "toggle",
		desc = L["Red overlay on abilities of the school locked by an interrupt."],
	},
	{
		path = "actionBar.lossOfControlColor",
		new = "1.4.0",
		label = L["Loss of control color"],
		type = "color",
		alpha = true,
		enabledByAny = { "actionBar.lossOfControl", "actionBar.interruptLockout" },
	},
}

ns.RegisterPage({
	key = PAGE,
	name = L["Action bars"],
	order = 15,
	enable = ENABLE,
	schema = schema,
})
