local _, ns = ...

local ui = FrostAtomUI
local L = ui.L
local Trackers = ui.Trackers

local Section = ns.Section
local CreateButton = ns.CreateButton
local Font = ns.Font

local ICON_SIZE = 22
local BUTTON_GAP = 4
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local LAST_EQUIPMENT_SLOT = 19
local BUTTON_ROW_X = ns.CONTROL_X
local ICON_BUTTON_WIDTH = 64
local ICON_BUTTON_HEIGHT = 20
local HIGHLIGHT_TEXTURE = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
local HIGHLIGHT_COLOR = { 0.196, 0.388, 0.8 }

local CLASSES = {
	"WARRIOR",
	"PALADIN",
	"HUNTER",
	"ROGUE",
	"PRIEST",
	"DEATHKNIGHT",
	"SHAMAN",
	"MAGE",
	"WARLOCK",
	"DRUID",
}

local TYPE_NAMES = {
	aura = L["Buff / debuff"],
	cooldown = L["Spell cooldown"],
	item = L["Item cooldown"],
	totem = L["Totem"],
	icd = L["Internal cooldown"],
	unitcd = L["Enemy cooldown"],
	dr = L["Diminishing returns"],
}

local SHOW_NAMES = {
	present = L["When present"],
	absent = L["When absent"],
	always = L["Always"],
	ready = L["When ready"],
	cooldown = L["When on cooldown"],
	usable = L["When usable"],
}

local UNIT_NAMES = {
	player = L["Player"],
	target = L["Target"],
	focus = L["Focus"],
	pet = L["Pet"],
}

local SPELLS_DESC = {
	aura = L["Spell IDs or names separated by semicolons. #stun, #silence, #root, #fear, #disorient, #slowed, #healingreduced, #immune, #immunemagic, #defensive and #burst match whole groups."],
	cooldown = L["Spell ID or name; the first entry is tracked."],
	item = L["Item IDs or names; 13 and 14 are the trinket slots. The first owned item is tracked."],
	totem = L["Totem names; a partial name matches every rank."],
	icd = L["Proc spell IDs or names that start the internal cooldown."],
	unitcd = L["Spell IDs or names from the enemy cooldown tracker; the first ready one is shown."],
}

local selectedGroup, selectedIcon

local function groups()
	return ui.Config.trackers.groups
end

local function groupPath(index)
	return "trackers.groups." .. index
end

local function iconPath(groupIndex, iconIndex)
	return groupPath(groupIndex) .. ".icons." .. iconIndex
end

local function loadsForPlayerClass(group)
	return group.class == "" or group.class == ui.PLAYER_CLASS
end

local function groupLoaded(index)
	local group = groups()[index]
	return group and loadsForPlayerClass(group) or false
end

local function groupIndexFromPath(path)
	return tonumber(path:match("^trackers%.groups%.(%d+)%.point$"))
end

ns.RegisterElement({
	match = "^trackers%.groups%.%d+%.point$",
	page = "trackers",
	glyph = "list-check",
	name = function(path)
		local group = groups()[groupIndexFromPath(path)]
		return group and group.name or L["Group"]
	end,
	build = function(path)
		local prefix = groupPath(groupIndexFromPath(path))
		local enabledBy = { "trackers.enabled", prefix .. ".enabled" }
		local function entry(spec)
			spec.path = prefix .. "." .. spec.path
			spec.enabledBy = enabledBy
			return spec
		end
		return {
			{ header = L["Size"], glyph = "up-down-left-right" },
			entry({ path = "size", label = L["Icon size"], type = "number", min = 12, max = 80, step = 1 }),
			entry({ path = "spacing", label = L["Spacing"], type = "number", min = 0, max = 20, step = 1 }),
			entry({ path = "columns", label = L["Columns"], type = "number", min = 1, max = 16, step = 1 }),
			entry({
				path = "collapse",
				label = L["Collapse hidden icons"],
				type = "toggle",
				desc = L["Shift visible icons into the gaps of hidden ones."],
			}),
			{ header = L["Text"], glyph = "font" },
			entry({ path = "timer", label = L["Timer text"], type = "toggle" }),
			{ header = L["Visibility"], glyph = "eye" },
			entry({
				path = "inactiveAlpha",
				label = L["Inactive alpha"],
				type = "number",
				min = 0,
				max = 1,
				step = 0.05,
				desc = L['Opacity of "Always" icons while their condition is not met.'],
			}),
		}
	end,
})

local function setGroups(list)
	ui:SetConfig("trackers.groups", list)
end

local function copyGroups()
	return CopyTable(groups())
end

local function validateSelection()
	local list = groups()
	if selectedGroup and not list[selectedGroup] then
		selectedGroup = #list > 0 and #list or nil
	end
	if not selectedGroup and #list > 0 then
		for i, group in ipairs(list) do
			if loadsForPlayerClass(group) then
				selectedGroup = i
				break
			end
		end
		selectedGroup = selectedGroup or 1
	end
	local icons = selectedGroup and list[selectedGroup].icons or {}
	if selectedIcon and not icons[selectedIcon] then
		selectedIcon = nil
	end
end

local function selectItem(groupIndex, iconIndex)
	selectedGroup, selectedIcon = groupIndex, iconIndex
	ns.RefreshPage()
end

local function iconTexture(icon)
	local list = Trackers.ParseList(icon.spells)
	if icon.type == "item" then
		local entry = list.entries[1]
		local id = entry and entry.id
		if id and id <= LAST_EQUIPMENT_SLOT then
			return GetInventoryItemTexture("player", id) or QUESTION_MARK
		elseif id then
			return GetItemIcon(id) or QUESTION_MARK
		end
	elseif icon.type ~= "dr" then
		local first = list.first
		if first then
			return first.id and select(3, GetSpellInfo(first.id)) or GetSpellTexture(first.name or "") or QUESTION_MARK
		end
	end
	return QUESTION_MARK
end

local function spellNames(icon)
	local names = {}
	for token in (icon.spells or ""):gmatch("[^;,\n]+") do
		token = strtrim(token)
		local id = tonumber(token)
		if id and icon.type == "item" then
			token = id <= LAST_EQUIPMENT_SLOT and L["Slot %d"]:format(id) or GetItemInfo(id) or token
		elseif id then
			token = GetSpellInfo(id) or token
		end
		if token ~= "" then
			names[#names + 1] = token
		end
	end
	return #names > 0 and table.concat(names, ", ") or L["(empty)"]
end

local function describeIcon(icon)
	local text
	if icon.type == "dr" then
		text = L[ui.DRData.CATEGORY_NAMES[icon.category] or "?"]
	else
		text = spellNames(icon)
	end
	return ("%s: %s"):format(TYPE_NAMES[icon.type] or icon.type, text), iconTexture(icon)
end

local function createArrow(parent, direction, onClick)
	local template = direction == "up" and "UIPanelScrollUpButtonTemplate" or "UIPanelScrollDownButtonTemplate"
	local button = CreateFrame("Button", ui.WidgetName(), parent, template)
	button:SetScript("OnClick", onClick)
	return button
end

local function buttonRow(buttons)
	return function(row)
		local previous
		for _, spec in ipairs(buttons) do
			local button = spec.arrow and createArrow(row, spec.arrow)
				or CreateButton(row, spec[1], spec[3] or 90, spec.gray)
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", BUTTON_GAP, 0)
			else
				button:SetPoint("LEFT", row, "LEFT", spec.x or BUTTON_ROW_X, 0)
			end
			button:SetScript("OnClick", spec[2])
			previous = button
		end
	end
end

local function moveItem(list, from, to)
	if to < 1 or to > #list then
		return false
	end
	list[from], list[to] = list[to], list[from]
	return true
end

local function groupValues()
	local values = {}
	for i, group in ipairs(groups()) do
		local class = group.class ~= "" and LOCALIZED_CLASS_NAMES_MALE[group.class]
		values[#values + 1] = { i, class and ("%s (%s)"):format(group.name, class) or group.name }
	end
	return values
end

local function classValues()
	local values = { { "", L["Any class"] } }
	for _, class in ipairs(CLASSES) do
		values[#values + 1] = { class, LOCALIZED_CLASS_NAMES_MALE[class] or class }
	end
	return values
end

local function unitValues()
	local values = {}
	for _, unit in ipairs(Trackers.UNITS) do
		local name = UNIT_NAMES[unit]
		if not name then
			local kind, index = unit:match("^(%a+)(%d)$")
			name = (kind == "arena" and L["Arena %d"] or L["Party %d"]):format(index)
		end
		values[#values + 1] = { unit, name }
	end
	return values
end

local function typeValues()
	local values = {}
	for _, kind in ipairs(Trackers.TYPES) do
		values[#values + 1] = { kind, TYPE_NAMES[kind] }
	end
	return values
end

local function categoryValues()
	local values = {}
	for key, name in pairs(ui.DRData.CATEGORY_NAMES) do
		values[#values + 1] = { key, L[name] }
	end
	table.sort(values, function(a, b)
		return a[2] < b[2]
	end)
	return values
end

local function addGroup()
	local list = copyGroups()
	list[#list + 1] = Trackers.NewGroup(L["Group %d"]:format(#list + 1))
	setGroups(list)
	selectItem(#list, nil)
end

local function deleteGroup()
	if not selectedGroup then
		return
	end
	ns.Confirm(L["Delete tracker group %s?"]:format(groups()[selectedGroup].name), function()
		local list = copyGroups()
		table.remove(list, selectedGroup)
		selectedGroup, selectedIcon = nil, nil
		setGroups(list)
	end)
end

local function moveGroup(delta)
	return function()
		local list = copyGroups()
		if selectedGroup and moveItem(list, selectedGroup, selectedGroup + delta) then
			selectedGroup = selectedGroup + delta
			setGroups(list)
		end
	end
end

local function addIcon()
	local list = copyGroups()
	local icons = list[selectedGroup].icons
	icons[#icons + 1] = Trackers.NewIcon("aura")
	selectedIcon = #icons
	setGroups(list)
end

local function removeIcon(index)
	return function()
		local list = copyGroups()
		table.remove(list[selectedGroup].icons, index)
		if selectedIcon == index then
			selectedIcon = nil
		elseif selectedIcon and selectedIcon > index then
			selectedIcon = selectedIcon - 1
		end
		setGroups(list)
	end
end

local function moveIcon(index, delta)
	return function()
		local list = copyGroups()
		local target = index + delta
		if not moveItem(list[selectedGroup].icons, index, target) then
			return
		end
		if selectedIcon == index then
			selectedIcon = target
		elseif selectedIcon == target then
			selectedIcon = index
		end
		setGroups(list)
	end
end

local function iconRow(groupIndex, index)
	return {
		type = "custom",
		label = "",
		indent = false,
		build = function(row)
			local selected = row:CreateTexture(nil, "BACKGROUND")
			selected:SetTexture(HIGHLIGHT_TEXTURE)
			selected:SetBlendMode("ADD")
			selected:SetVertexColor(HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3])
			selected:SetAllPoints()
			selected:Hide()

			local texture = row:CreateTexture(nil, "ARTWORK")
			texture:SetSize(ICON_SIZE, ICON_SIZE)
			texture:SetPoint("LEFT", 8, 0)
			texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

			local text = row:CreateFontString(nil, "ARTWORK")
			text:SetFontObject(Font("GameFontHighlight"))
			text:SetPoint("LEFT", texture, "RIGHT", 8, 0)
			text:SetPoint("RIGHT", row, "RIGHT", -210, 0)
			text:SetJustifyH("LEFT")
			text:SetWordWrap(false)

			local remove = CreateButton(row, L["Remove"], ICON_BUTTON_WIDTH, true, ICON_BUTTON_HEIGHT)
			remove:SetPoint("RIGHT", -4, 0)
			remove:SetScript("OnClick", removeIcon(index))
			local down = createArrow(row, "down", moveIcon(index, 1))
			down:SetPoint("RIGHT", remove, "LEFT", -BUTTON_GAP, 0)
			local up = createArrow(row, "up", moveIcon(index, -1))
			up:SetPoint("RIGHT", down, "LEFT", -BUTTON_GAP, 0)
			local edit = CreateButton(row, L["Edit"], ICON_BUTTON_WIDTH, false, ICON_BUTTON_HEIGHT)
			edit:SetPoint("RIGHT", up, "LEFT", -BUTTON_GAP, 0)
			edit:SetScript("OnClick", function()
				selectItem(groupIndex, selectedIcon ~= index and index or nil)
			end)

			row.texture, row.text, row.edit, row.selected = texture, text, edit, selected
		end,
		refresh = function(row)
			local current = groups()[groupIndex].icons[index]
			if not current then
				return
			end
			local label, texture = describeIcon(current)
			row.texture:SetTexture(texture)
			row.text:SetText(label)
			local selected = selectedIcon == index
			local color = selected and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			row.text:SetTextColor(color.r, color.g, color.b)
			row.edit:SetText(selected and L["Close"] or L["Edit"])
			ui.SetShown(row.selected, selected)
		end,
	}
end

local function buildIconEntries(schema, groupIndex, iconIndex, icon)
	local kind = icon.type
	local showValues = {}
	for _, key in ipairs(Trackers.SHOW[kind] or Trackers.SHOW.aura) do
		showValues[#showValues + 1] = { key, SHOW_NAMES[key] }
	end
	local hasUnit = kind == "aura" or kind == "dr" or kind == "unitcd"

	schema[#schema + 1] = { header = L["Icon %d"]:format(iconIndex), glyph = "pen-to-square" }
	local prefix = iconPath(groupIndex, iconIndex)
	local function entry(spec)
		spec.path = prefix .. "." .. spec.path
		spec.enabledBy = { "trackers.enabled", groupPath(groupIndex) .. ".enabled" }
		schema[#schema + 1] = spec
	end
	entry({
		path = "type",
		label = L["Type"],
		type = "select",
		width = 160,
		values = typeValues(),
		set = function(value)
			local list = copyGroups()
			local target = list[groupIndex].icons[iconIndex]
			target.type = value
			target.show = Trackers.SHOW[value][1]
			setGroups(list)
		end,
	})
	if kind ~= "dr" then
		entry({
			path = "spells",
			label = kind == "item" and L["Items"] or L["Spells"],
			type = "string",
			width = 260,
			maxLetters = 255,
			desc = SPELLS_DESC[kind],
		})
	else
		entry({ path = "category", label = L["Category"], type = "select", width = 180, values = categoryValues() })
	end
	if hasUnit then
		entry({ path = "unit", label = L["Unit"], type = "select", values = unitValues() })
	end
	entry({ path = "show", label = L["Show"], type = "select", width = 160, values = showValues })
	if kind == "aura" then
		entry({
			path = "debuff",
			label = L["Debuff"],
			type = "toggle",
			desc = L["Look for a debuff instead of a buff."],
		})
		entry({
			path = "mine",
			label = L["Only mine"],
			type = "toggle",
			desc = L["Only auras applied by you or your pet."],
		})
		entry({
			path = "minStacks",
			label = L["Minimum stacks"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			desc = L["Treat the aura as absent below this many stacks; 0 ignores stacks."],
		})
	elseif kind == "cooldown" then
		entry({
			path = "range",
			label = L["Range check"],
			type = "toggle",
			desc = L["Tint the icon red while your target is out of range."],
		})
		entry({
			path = "usable",
			label = L["Power check"],
			type = "toggle",
			desc = L["Tint the icon blue while you lack the power to cast it."],
		})
	elseif kind == "icd" then
		entry({
			path = "duration",
			label = L["Cooldown (seconds)"],
			type = "number",
			min = 0,
			max = 180,
			step = 1,
			desc = L["0 takes the cooldown from the built-in list of trinket, enchant and talent procs (45 if the proc is unknown)."],
		})
	end
end

local function buildSchema()
	validateSelection()
	local schema = {
		{
			description = L["Minimal TellMeWhen: groups of icons that watch buffs, debuffs, cooldowns, items, totems, internal cooldowns, enemy cooldowns and diminishing returns. Icons of the page are shown while it is open; move groups with Unlock frames."],
		},
		{ path = "trackers.enabled", label = L["Enable"], type = "toggle" },
		{
			label = L["Group"],
			type = "select",
			width = 220,
			values = groupValues,
			placeholder = L["No groups"],
			get = function()
				return selectedGroup
			end,
			set = function(value)
				selectItem(value, nil)
			end,
			enabledBy = "trackers.enabled",
		},
		{
			type = "custom",
			label = "",
			build = buttonRow({
				{ L["New group"], addGroup },
				{ L["Delete"], deleteGroup, 70, gray = true },
				{ nil, moveGroup(-1), arrow = "up" },
				{ nil, moveGroup(1), arrow = "down" },
			}),
		},
	}

	local groupIndex = selectedGroup
	local group = groupIndex and groups()[groupIndex]
	if not group then
		return schema
	end

	Section(schema, L["Group settings"], groupPath(groupIndex), {
		{ path = "enabled", label = L["Enable group"], type = "toggle" },
		{ path = "name", label = L["Name"], type = "string", maxLetters = 40 },
		{
			path = "class",
			label = L["Class"],
			type = "select",
			values = classValues(),
			desc = L["Load the group only for this class."],
		},
		{
			label = L["Layout"],
			type = "execute",
			text = L["Edit"],
			glyph = "up-down-left-right",
			desc = L["Position, icon size, spacing and timer of the group, edited on screen."],
			disabled = function()
				return not groupLoaded(groupIndex)
			end,
			func = function()
				ns.EditElement(groupPath(groupIndex) .. ".point")
			end,
		},
		{
			path = "combat",
			label = L["Combat"],
			type = "select",
			values = { { "any", L["Always"] }, { "combat", L["In combat"] }, { "nocombat", L["Out of combat"] } },
		},
		{
			path = "zone",
			label = L["Zone"],
			type = "select",
			values = {
				{ "any", L["Anywhere"] },
				{ "arena", L["Arena"] },
				{ "pvp", L["Arena or battleground"] },
				{ "world", L["Outside instances"] },
			},
		},
		{
			path = "talentGroup",
			label = L["Talent spec"],
			type = "select",
			values = { { 0, L["Both"] }, { 1, L["Primary"] }, { 2, L["Secondary"] } },
		},
	}, nil, nil, "sliders")

	schema[#schema + 1] = { header = L["Icons"], glyph = "icons" }
	for iconIndex in ipairs(group.icons or {}) do
		schema[#schema + 1] = iconRow(groupIndex, iconIndex)
	end
	schema[#schema + 1] = {
		type = "custom",
		label = "",
		build = buttonRow({ { L["Add icon"], addIcon, 100, x = 8 } }),
	}

	local icon = selectedIcon and group.icons[selectedIcon]
	if icon then
		buildIconEntries(schema, groupIndex, selectedIcon, icon)
	end
	return schema
end

local function signature()
	validateSelection()
	local list = groups()
	local group = selectedGroup and list[selectedGroup]
	local icon = group and selectedIcon and group.icons[selectedIcon]
	return ("%d:%s:%s:%d:%s"):format(
		#list,
		tostring(selectedGroup),
		tostring(selectedIcon),
		group and #group.icons or 0,
		icon and icon.type or ""
	)
end

ns.RegisterPage({
	key = "trackers",
	name = L["Trackers"],
	glyph = "list-check",
	order = 32,
	new = "1.4.0",
	schema = { { path = "trackers", hidden = true } },
	buildSchema = buildSchema,
	signature = signature,
	onShow = function()
		Trackers.SetPreview(true)
	end,
	onHide = function()
		Trackers.SetPreview(ui.Movers.IsUnlocked())
	end,
})
