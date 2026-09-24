local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

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

ns.COMBAT_VISIBILITY_VALUES = {
	{ "any", L["Always"] },
	{ "combat", L["In combat"] },
	{ "nocombat", L["Out of combat"] },
}

local PAGE = "actionbar"
local ENABLE = "actionBar.enabled"
local COMBAT_DESC = L["Fade out of combat or in combat. With mouseover the cursor still reveals it."]
local FADE_DISABLED_DESC = L["Used only with mouseover or when Visible is not Always."]

local function fadeDisabled(mouseoverPath, combatPath)
	return function()
		return not ui:GetConfig(mouseoverPath) and ui:GetConfig(combatPath) == "any"
	end
end

local function barSchema(prefix, hasToggle, hasCount, extra)
	local enabledBy
	local schema = {}
	if hasToggle then
		enabledBy = prefix .. ".enabled"
		schema[#schema + 1] = { path = enabledBy, label = L["Show"], type = "toggle" }
	end
	schema[#schema + 1] = { header = L["Layout"], glyph = "up-down-left-right" }
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
		path = prefix .. ".buttonSize",
		label = L["Button size"],
		type = "number",
		min = 16,
		max = 60,
		step = 1,
		enabledBy = enabledBy,
	}
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
		path = prefix .. ".spacing",
		label = L["Spacing"],
		type = "number",
		min = 0,
		max = 12,
		step = 1,
		enabledBy = enabledBy,
		desc = L["Gap between buttons."],
	}
	for _, entry in ipairs(extra or {}) do
		entry.enabledBy = entry.path and enabledBy
		schema[#schema + 1] = entry
	end
	schema[#schema + 1] = { header = L["Visibility"], glyph = "eye" }
	schema[#schema + 1] = {
		path = prefix .. ".mouseover",
		new = "1.4.0",
		label = L["Show on mouseover"],
		type = "toggle",
		enabledBy = enabledBy,
		desc = L["Keep the bar faded until the cursor is over it or a spell is being dragged."],
	}
	schema[#schema + 1] = {
		path = prefix .. ".combat",
		new = "1.4.1",
		label = L["Visible"],
		type = "select",
		values = ns.COMBAT_VISIBILITY_VALUES,
		enabledBy = enabledBy,
		desc = L["Fade out of combat or in combat. With mouseover the cursor still reveals it. While faded this way the bar lets clicks through."],
	}
	schema[#schema + 1] = {
		path = prefix .. ".fadeAlpha",
		new = "1.4.0",
		label = L["Faded alpha"],
		type = "number",
		min = 0,
		max = 1,
		step = 0.05,
		percent = true,
		enabledBy = enabledBy,
		disabled = fadeDisabled(prefix .. ".mouseover", prefix .. ".combat"),
		disabledDesc = FADE_DISABLED_DESC,
		desc = L["Bar alpha while it is faded by mouseover or combat visibility."],
	}
	return schema
end

local function barElement(name, key, hasToggle, hasCount, new, hidden, extra)
	local prefix = "actionBar." .. key
	ns.RegisterElement({
		path = prefix .. ".point",
		page = PAGE,
		name = name,
		new = new,
		enabledBy = ENABLE,
		hidden = hidden,
		schema = barSchema(prefix, hasToggle, hasCount, extra),
	})
end

barElement(L["Bar 1"], "bar1", false, true)
barElement(L["Bar 2"], "bar2", true, true)
barElement(L["Bar 3"], "bar3", true, true)
barElement(L["Bar 4"], "bar4", true, true)
barElement(L["Bar 5"], "bar5", true, true)
barElement(L["Bar 6"], "bar6", true, true, "1.4.0")
barElement(L["Stance bar"], "stance", false, false)
barElement(L["Pet bar"], "pet", false, false)
barElement(L["Totem bar"], "totemBar", true, false, "1.4.1", ns.NotClass("SHAMAN"), {
	{ header = L["Totem menu"], glyph = "fire" },
	{
		path = "actionBar.totemBar.flyoutButtonSize",
		label = L["Menu button size"],
		type = "number",
		min = 16,
		max = 60,
		step = 1,
		desc = L["Menu that opens above a totem slot or the summon button."],
	},
	{
		path = "actionBar.totemBar.flyoutRows",
		label = L["Buttons per column"],
		type = "number",
		min = 1,
		max = 12,
		step = 1,
	},
	{
		path = "actionBar.totemBar.flyoutSpacing",
		label = L["Menu spacing"],
		type = "number",
		min = 0,
		max = 12,
		step = 1,
		desc = L["Gap between buttons."],
	},
})

ns.RegisterElement({
	path = "actionBar.vehicleExit.point",
	page = PAGE,
	name = L["Vehicle exit"],
	new = "1.4.1",
	enabledBy = ENABLE,
	schema = {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "actionBar.vehicleExit.buttonSize",
			label = L["Button size"],
			type = "number",
			min = 16,
			max = 60,
			step = 1,
			desc = L["Shown in a vehicle or while mind controlling; leaves the vehicle or cancels the control."],
		},
	},
})

ns.RegisterElement({
	path = "actionBar.microMenu",
	page = PAGE,
	name = L["Micro menu"],
	enabledBy = ENABLE,
	schema = {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "actionBar.microMenuScale",
			label = L["Scale"],
			type = "number",
			min = 0.5,
			max = 2,
			step = 0.05,
			percent = true,
		},
		{ header = L["Visibility"], glyph = "eye" },
		{
			path = "actionBar.microMenuMouseover",
			label = L["Show on mouseover"],
			type = "toggle",
			desc = L["Keep the micro menu faded until the cursor is over it."],
		},
		{
			path = "actionBar.microMenuCombat",
			new = "1.4.1",
			label = L["Visible"],
			type = "select",
			values = ns.COMBAT_VISIBILITY_VALUES,
			desc = COMBAT_DESC,
		},
		{
			path = "actionBar.menuFadeAlpha",
			label = L["Faded alpha (micro menu, bag button)"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			percent = true,
			disabled = fadeDisabled("actionBar.microMenuMouseover", "actionBar.microMenuCombat"),
			disabledDesc = FADE_DISABLED_DESC,
		},
	},
})

ns.RegisterElement({
	path = "actionBar.bagButton",
	page = PAGE,
	name = L["Bag button"],
	enabledBy = ENABLE,
	schema = {
		{ header = L["Visibility"], glyph = "eye" },
		{
			path = "actionBar.bagButtonMouseover",
			label = L["Show on mouseover"],
			type = "toggle",
			desc = L["Keep the bag button faded until the cursor is over it."],
		},
		{
			path = "actionBar.bagButtonCombat",
			new = "1.4.1",
			label = L["Visible"],
			type = "select",
			values = ns.COMBAT_VISIBILITY_VALUES,
			desc = COMBAT_DESC,
		},
		{
			path = "actionBar.menuFadeAlpha",
			label = L["Faded alpha (micro menu, bag button)"],
			type = "number",
			min = 0,
			max = 1,
			step = 0.05,
			percent = true,
			disabled = fadeDisabled("actionBar.bagButtonMouseover", "actionBar.bagButtonCombat"),
			disabledDesc = FADE_DISABLED_DESC,
		},
	},
})

local ActionBar = ui.ActionBar
local EXTRA_BARS = "actionBar.extraBars"
local ROW_BUTTON_GAP = 4

local CLASS_PAGE_SPELLS = {
	WARRIOR = {
		[7] = 2457, -- Battle Stance
		[8] = 71, -- Defensive Stance
		[9] = 2458, -- Berserker Stance
	},
	DRUID = {
		[7] = 768, -- Cat Form
		[8] = 5215, -- Prowl
		[9] = 5487, -- Bear Form
		[10] = 24858, -- Moonkin Form
	},
	ROGUE = {
		[7] = 1784, -- Stealth
		[8] = 51713, -- Shadow Dance
	},
	PRIEST = {
		[7] = 15473, -- Shadowform
	},
}

local function extraBars()
	return ui.Config.actionBar.extraBars
end

local function extraBarName(page)
	return L["Bar %d"]:format(page)
end

local function pageOwner(page)
	local spells = CLASS_PAGE_SPELLS[ui.PLAYER_CLASS]
	local spell = spells and spells[page]
	return spell and GetSpellInfo(spell)
end

local function pageFromPath(path)
	return tonumber(path:match("^actionBar%.extraBars%.bar(%d+)%."))
end

ns.RegisterElement({
	match = "^actionBar%.extraBars%.bar%d+%.point$",
	page = PAGE,
	name = function(path)
		return extraBarName(pageFromPath(path))
	end,
	build = function(path)
		return barSchema(path:gsub("%.point$", ""), true, true)
	end,
})

local function freePageValues()
	local values = {}
	for page = ActionBar.FIRST_EXTRA_PAGE, ActionBar.LAST_EXTRA_PAGE do
		if not extraBars()["bar" .. page] then
			local owner = pageOwner(page)
			values[#values + 1] = {
				page,
				owner and L["Page %d (%s)"]:format(page, owner) or L["Page %d"]:format(page),
			}
		end
	end
	return values
end

local function clearButtonBindings(page)
	local first = (page - 1) * ActionBar.BUTTONS_PER_BAR
	for i = 1, ActionBar.BUTTONS_PER_BAR do
		local command = ActionBar.BINDING_NAME:format(first + i)
		local key = GetBindingKey(command)
		while key do
			SetBinding(key)
			key = GetBindingKey(command)
		end
	end
	SaveBindings(GetCurrentBindingSet())
end

local function removeExtraBar(page)
	ns.Confirm(L["Remove %s? Key bindings of its buttons are cleared."]:format(extraBarName(page)), function()
		if InCombatLockdown() then
			ui.Print(L["cannot change bindings in combat"])
			return
		end
		local path = ActionBar.ExtraBarPath(page)
		if ns.GetOpenElement() == path .. ".point" then
			ns.CloseElement()
		end
		clearButtonBindings(page)
		ui:SetConfig(path, nil)
	end)
end

local function extraBarRow(page)
	local owner = pageOwner(page)
	return {
		type = "custom",
		label = extraBarName(page),
		desc = owner and L["Action page %d, the actions of %s."]:format(page, owner)
			or L["Action page %d."]:format(page),
		build = function(row)
			local edit = ns.CreateButton(row, L["Edit"], 100, false, nil, "up-down-left-right")
			edit:SetPoint("LEFT", ns.CONTROL_X, 0)
			edit:SetScript("OnClick", function()
				ns.EditElement(ActionBar.ExtraBarPath(page) .. ".point")
			end)
			local remove = ns.CreateButton(row, L["Remove"], 80, true, nil, "trash")
			remove:SetPoint("LEFT", edit, "RIGHT", ROW_BUTTON_GAP, 0)
			remove:SetScript("OnClick", function()
				removeExtraBar(page)
			end)
			row.edit, row.remove = edit, remove
		end,
		setEnabled = function(row, enabled)
			for _, button in ipairs({ row.edit, row.remove }) do
				if enabled then
					button:Enable()
				else
					button:Disable()
				end
			end
		end,
	}
end

local addBarEntry = {
	label = L["Add bar"],
	type = "select",
	width = 200,
	values = freePageValues,
	placeholder = L["Choose a page..."],
	desc = L["Another bar on a spare action page (7 - 10). A page of your stances or forms shows the actions of that stance or form."],
	disabled = function()
		return #freePageValues() == 0
	end,
	disabledDesc = L["All spare action pages are in use."],
	get = function() end,
	set = function(page)
		ui:SetConfig(ActionBar.ExtraBarPath(page), ActionBar.NewExtraBar(page))
	end,
}

local schema = {
	{
		path = ENABLE,
		label = L["Enable"],
		type = "toggle",
		reload = true,
		desc = L["Replace Blizzard action bars."],
	},
	{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
	{ type = "elements" },
	{ path = EXTRA_BARS, hidden = true },
	{ header = L["General"], glyph = "gear" },
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
	{ header = L["Range and cooldowns"], glyph = "hourglass-half" },
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
	{ header = L["Text"], glyph = "font" },
	{ path = "actionBar.showHotkeys", label = L["Hotkeys"], type = "toggle" },
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
		label = L["Macro names"],
		type = "toggle",
		desc = L["Macro name at the bottom of the button."],
	},
	{ path = "actionBar.nameFont", label = L["Name font"], type = "font", enabledBy = "actionBar.showNames" },
	{
		path = "actionBar.showCounts",
		new = "1.4.1",
		label = L["Item counts"],
		type = "toggle",
		desc = L["Stack or charge count in the bottom-right corner of the button."],
	},
	{
		path = "actionBar.countFont",
		new = "1.4.1",
		label = L["Count font"],
		type = "font",
		enabledBy = "actionBar.showCounts",
	},
	{
		path = "actionBar.cooldownFont",
		new = "1.4.1",
		label = L["Cooldown font"],
		type = "font",
		desc = L["Remaining cooldown text on action bar buttons."],
	},
	{ header = L["Colors"], glyph = "palette" },
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
}

local function buildSchema()
	local result = {}
	for _, entry in ipairs(schema) do
		result[#result + 1] = entry
		if entry.path == EXTRA_BARS then
			for page = ActionBar.FIRST_EXTRA_PAGE, ActionBar.LAST_EXTRA_PAGE do
				if extraBars()["bar" .. page] then
					result[#result + 1] = extraBarRow(page)
				end
			end
			result[#result + 1] = addBarEntry
		end
	end
	return result
end

local function signature()
	local keys = {}
	for page = ActionBar.FIRST_EXTRA_PAGE, ActionBar.LAST_EXTRA_PAGE do
		if extraBars()["bar" .. page] then
			keys[#keys + 1] = page
		end
	end
	return table.concat(keys, ",")
end

ns.RegisterPage({
	key = PAGE,
	name = L["Action bars"],
	glyph = "table-cells",
	order = 24,
	group = "frames",
	schema = schema,
	buildSchema = buildSchema,
	signature = signature,
	enable = ENABLE,
})
