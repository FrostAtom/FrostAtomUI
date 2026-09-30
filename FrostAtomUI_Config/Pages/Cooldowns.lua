local _, ns = ...

local ui = FrostAtomUI
local L = ui.L
local GroupCooldowns = ui.GroupCooldowns
local Data = ui.CooldownData

local Section = ns.Section
local Requires = ns.Requires

local ICON_FORMAT = "|T%s:16:16:0:0:64:64:5:59:5:59|t  %s"
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

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

local GROWTH_VALUES = { { "RIGHT", L["Right"], glyph = "arrow-right" }, { "LEFT", L["Left"], glyph = "arrow-left" } }

local LAYOUT_VALUES = {
	{ "group", L["One block"], glyph = "table-cells" },
	{ "frames", L["Next to unit frames"], glyph = "id-card" },
}

local selectedClass = Data.SPELLS[ui.PLAYER_CLASS] and ui.PLAYER_CLASS or CLASSES[1]

local function classValues()
	local values = {}
	for i, class in ipairs(CLASSES) do
		local color = RAID_CLASS_COLORS[class]
		local name = LOCALIZED_CLASS_NAMES_MALE[class] or class
		values[i] = { class, ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, name) }
	end
	values[#values + 1] = { "COMMON", L["Racials and items"] }
	return values
end

local function notFrames(side)
	return function()
		return ui:GetConfig("groupCooldowns." .. side .. "Layout") == "frames"
	end
end

local function sidePanel(side, name, interruptName)
	local prefix = "groupCooldowns." .. side
	local function growth()
		return {
			path = prefix .. "Growth",
			label = L["Row direction"],
			type = "select",
			values = GROWTH_VALUES,
			advanced = true,
			desc = L["Side the rows grow toward; category labels sit on the other side."],
		}
	end
	ns.RegisterElement({
		path = prefix .. "Point",
		page = "cooldowns",
		name = name,
		enabledBy = { "groupCooldowns.enabled", prefix },
		disabled = notFrames(side),
		schema = Requires({ "groupCooldowns.enabled", prefix }, {
			{ header = L["Layout"], glyph = "up-down-left-right" },
			growth(),
		}),
	})
	ns.RegisterElement({
		path = prefix .. "InterruptPoint",
		page = "cooldowns",
		name = interruptName,
		enabledBy = { "groupCooldowns.enabled", prefix, prefix .. "SeparateInterrupts" },
		schema = Requires({ "groupCooldowns.enabled", prefix, prefix .. "SeparateInterrupts" }, {
			{ header = L["Layout"], glyph = "up-down-left-right" },
			growth(),
		}),
	})
end

sidePanel("friendly", L["Ally cooldowns"], L["Ally interrupts"])
sidePanel("enemy", L["Enemy cooldowns"], L["Enemy interrupts"])

local function framePanels(side, prefix, label, count, name)
	local enabledBy = { "groupCooldowns.enabled", "groupCooldowns." .. side }
	for i = 1, count do
		ns.RegisterElement({
			path = "groupCooldowns." .. prefix .. i .. "Point",
			page = "cooldowns",
			name = i == 1 and name or L[label .. " " .. i .. " cooldowns"],
			hidden = i ~= 1,
			enabledBy = enabledBy,
			disabled = function()
				return ui:GetConfig("groupCooldowns." .. side .. "Layout") ~= "frames"
			end,
			schema = Requires(enabledBy, {
				{
					description = L["The row of every frame moves on its own; by default it hangs under the frame's corner."],
				},
			}),
		})
	end
end

framePanels("friendly", "party", "Party", 4, L["Party cooldowns"])
framePanels("enemy", "arena", "Arena", 3, L["Arena opponent cooldowns"])

local function categoryValues()
	local values = {}
	for i, category in ipairs(Data.CATEGORIES) do
		values[i] = { category, GroupCooldowns.CATEGORY_NAMES[category] }
	end
	return values
end

local function sideSection(schema, side, header, toggleLabel, toggleDesc, framesDesc, trinketDesc)
	local prefix = "groupCooldowns." .. side
	Section(schema, header, "groupCooldowns", {
		{ path = side, label = toggleLabel, type = "toggle", desc = toggleDesc },
		{
			path = side .. "Layout",
			label = L["Display"],
			type = "select",
			values = LAYOUT_VALUES,
			enabledBy = prefix,
			desc = framesDesc,
		},
		{
			path = side .. "Categories",
			label = L["Categories"],
			type = "multiselect",
			values = categoryValues(),
			enabledBy = prefix,
			desc = L["Ability types to show. The PvP trinket always comes first, then interrupts."],
		},
		{
			path = side .. "SeparateInterrupts",
			label = L["Interrupts in a separate panel"],
			type = "toggle",
			enabledBy = { prefix, prefix .. "Categories.interrupt" },
			desc = L["Interrupts and silences of every player leave the main icons and gather in one panel of their own, moved separately."],
		},
		{
			path = side .. "SeparateTrinket",
			label = L["Trinket separately"],
			type = "toggle",
			enabledBy = { prefix, prefix .. "Categories.trinket" },
			desc = trinketDesc,
		},
	}, nil, nil, side == "friendly" and "user-group" or "users")
end

local function spellPath(id)
	return "groupCooldowns.spells." .. id
end

local function spellToggle(id)
	local info = ui:GetModule("CooldownTracker"):GetInfo(id)
	local name, _, icon = GetSpellInfo(id)
	return {
		label = ICON_FORMAT:format(icon or QUESTION_MARK, name or tostring(id)),
		type = "toggle",
		desc = L["Cooldown: %s."]:format(SecondsToTime(info.cooldown)),
		get = function()
			return GroupCooldowns.IsSpellShown(id)
		end,
		set = function(value)
			if value == not info.hidden then
				ui:ResetConfig(spellPath(id))
			else
				ui:SetConfig(spellPath(id), value)
			end
		end,
		isDefault = function()
			return GroupCooldowns.IsSpellShown(id) == not info.hidden
		end,
		reset = function()
			ui:ResetConfig(spellPath(id))
		end,
		defaultText = info.hidden and L["Off"] or L["On"],
	}
end

local function spellEntries(schema)
	local byCategory = {}
	for _, entry in ipairs(Data.SPELLS[selectedClass]) do
		local id = entry[1]
		local category = entry.cat or "utility"
		byCategory[category] = byCategory[category] or {}
		tinsert(byCategory[category], id)
	end
	for _, category in ipairs(Data.CATEGORIES) do
		local ids = byCategory[category]
		if ids then
			local toggles = {}
			schema[#schema + 1] = {
				header = GroupCooldowns.CATEGORY_NAMES[category],
				toggles = toggles,
				toggleDesc = L["Show or hide every spell of this category."],
			}
			for i, id in ipairs(ids) do
				toggles[i] = spellToggle(id)
				schema[#schema + 1] = toggles[i]
			end
		end
	end
end

local function buildSchema()
	local schema = {
		{ path = "groupCooldowns.enabled", label = L["Enable"], type = "toggle" },
		{
			description = L["Cooldowns of party members and arena opponents, set up separately for allies and enemies: one block with rows grouped by ability type, or a row next to each unit frame. Every tracked ability is always shown: bright when ready, dark with a timer on cooldown, glowing while its effect is up. The PvP trinket comes first, then interrupts; the border shows the class."],
		},
		{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
		{ type = "elements" },
	}

	sideSection(
		schema,
		"friendly",
		L["Ally cooldowns"],
		L["Party cooldowns"],
		L["Cooldowns of your party members."],
		L["One block: every ally's icons in one panel, rows grouped by ability type. Next to unit frames: each ally's icons in a row under the right corner of their party frame, moved on its own."],
		L["The PvP trinket leaves the cooldown icons and gets an icon of its own left of each party pet, only inside arenas."]
	)
	sideSection(
		schema,
		"enemy",
		L["Enemy cooldowns"],
		L["Arena opponent cooldowns"],
		L["Cooldowns of arena opponents."],
		L["One block: every opponent's icons in one panel, rows grouped by ability type. Next to unit frames: each opponent's icons in a row under the left corner of their arena frame, moved on its own."],
		L["The PvP trinket leaves the cooldown icons and gets an icon of its own right of each arena frame."]
	)

	Section(schema, L["General"], "groupCooldowns", {
		{
			path = "labels",
			label = L["Category labels"],
			type = "toggle",
			advanced = true,
			desc = L["Category name beside each row of icons."],
		},
		{
			path = "desaturate",
			label = L["Desaturate on cooldown"],
			type = "toggle",
			advanced = true,
			desc = L["Grey out the icon while the ability is on cooldown."],
		},
		{
			path = "readyFlash",
			label = L["Cooldown ready flash"],
			type = "toggle",
			advanced = true,
			desc = L["Short bright flash on a tracked cooldown icon as the ability becomes ready."],
		},
		{
			path = "glowColor",
			label = L["Active effect glow"],
			type = "color",
			advanced = true,
			desc = L["Glow around a cooldown icon while the spell's effect is still active."],
		},
		ns.ClickThrough("clickThrough"),
	}, nil, nil, "sliders")

	Section(schema, L["Layout"], "groupCooldowns", {
		{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 48, step = 1 },
		{ path = "spacing", label = L["Spacing"], type = "number", min = 0, max = 10, step = 1, advanced = true },
		{
			path = "perRow",
			label = L["Icons per row"],
			type = "number",
			min = 1,
			max = 12,
			step = 1,
			desc = L["A category with more icons continues on the next row down."],
		},
		{
			path = "framePerRow",
			label = L["Icons per row next to frames"],
			type = "number",
			min = 1,
			max = 20,
			step = 1,
			desc = L["Icons in a row next to a unit frame; further icons continue on the next row."],
		},
		{
			path = "rowSpacing",
			label = L["Row spacing"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			advanced = true,
			desc = L["Space between the rows of icons."],
		},
	}, nil, nil, "up-down-left-right")
	schema[#schema + 1] = {
		path = "arenaTrinket.size",
		label = L["Separate trinket size"],
		type = "number",
		min = 16,
		max = 60,
		step = 1,
		enabledBy = "groupCooldowns.enabled",
		enabledByAny = { "groupCooldowns.friendlySeparateTrinket", "groupCooldowns.enemySeparateTrinket" },
		desc = L["Size of the trinket icon next to the party and arena frames."],
	}

	schema[#schema + 1] = { header = L["Spells"], glyph = "book" }
	schema[#schema + 1] = {
		label = L["Class"],
		type = "select",
		width = 200,
		values = classValues,
		get = function()
			return selectedClass
		end,
		set = function(value)
			selectedClass = value
			ns.RefreshPage()
		end,
	}
	schema[#schema + 1] = {
		label = L["Spell list"],
		type = "execute",
		text = L["Default"],
		glyph = "rotate-left",
		confirm = L["Restore the default spell selection for every class?"],
		desc = L["Show and hide spells for every class as they were by default."],
		func = function()
			ui:ResetConfig("groupCooldowns.spells")
		end,
	}
	spellEntries(schema)
	return schema
end

local function setPreview(shown)
	local UF = ui:GetModule("UnitFrames")
	GroupCooldowns.SetPreview(shown or UF.testing)
end

ns.RegisterPage({
	key = "cooldowns",
	name = L["Cooldowns"],
	glyph = "hourglass-half",
	order = 32,
	group = "pvp",
	new = "1.4.1",
	enable = "groupCooldowns.enabled",
	schema = { { path = "groupCooldowns", hidden = true } },
	buildSchema = buildSchema,
	signature = function()
		return selectedClass
	end,
	onShow = function()
		setPreview(true)
	end,
	onHide = function()
		setPreview(false)
	end,
})
