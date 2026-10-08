local _, ns = ...

local ui = FrostAtomUI
local L = ui.L
local GroupCooldowns = ui.GroupCooldowns
local Data = ui.API.Catalog("cooldowns")

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
		values[i] = { class, ui.ClassColorText(class, LOCALIZED_CLASS_NAMES_MALE[class] or class) }
	end
	values[#values + 1] = { "COMMON", L["Racials and items"] }
	return values
end

local function isFramesLayout(side)
	return ui:GetConfig("groupCooldowns." .. side .. "Layout") == "frames"
end

local function sidePanel(side, name, interruptName)
	local prefix = "groupCooldowns." .. side
	ns.RegisterElement({
		path = prefix .. "Point",
		page = "cooldowns",
		tab = side,
		name = name,
		enabledBy = { "groupCooldowns.enabled", prefix },
		disabled = function()
			return isFramesLayout(side)
		end,
		disabledDesc = L['The cooldowns are shown next to the unit frames: pick "One block" in Display.'],
		schema = {},
	})
	ns.RegisterElement({
		path = prefix .. "InterruptPoint",
		page = "cooldowns",
		tab = side .. "Interrupts",
		name = interruptName,
		enabledBy = { "groupCooldowns.enabled", prefix, prefix .. "SeparateInterrupts" },
		schema = {},
	})
end

sidePanel("friendly", L["Ally cooldowns"], L["Ally interrupts"])
sidePanel("enemy", L["Enemy cooldowns"], L["Enemy interrupts"])

local function framePanels(side, prefix, label, count, name)
	local enabledBy = { "groupCooldowns.enabled", "groupCooldowns." .. side }
	local function isBlockLayout()
		return not isFramesLayout(side)
	end
	for i = 1, count do
		ns.RegisterElement({
			path = "groupCooldowns." .. prefix .. i .. "Point",
			page = "cooldowns",
			tab = side,
			name = i == 1 and name or L[label .. " " .. i .. " cooldowns"],
			hidden = i ~= 1,
			enabledBy = enabledBy,
			disabled = isBlockLayout,
			disabledDesc = L['The cooldowns are shown as one block: pick "Next to unit frames" in Display.'],
			schema = Requires(enabledBy, {
				{
					description = L["The row of every frame moves on its own; by default it hangs under the frame's corner."],
				},
			}),
		})
	end
end

framePanels("friendly", "party", "Party member", 4, L["Party cooldowns"])
framePanels("enemy", "arena", "Arena opponent", 3, L["Arena opponent cooldowns"])

local function categoryValues()
	local values = {}
	for i, category in ipairs(Data.CATEGORIES) do
		values[i] = { category, L[GroupCooldowns.CATEGORY_NAMES[category]] }
	end
	return values
end

local function layoutEntries(schema, prefix, enabledBy, framed)
	local entries = {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = prefix .. "Growth",
			label = L["Row direction"],
			type = "select",
			values = GROWTH_VALUES,
			advanced = true,
			desc = L["Side the rows grow toward; category labels sit on the other side."],
		},
		{ path = prefix .. "Size", label = L["Icon size"], type = "number", min = 12, max = 48, step = 1 },
		{
			path = prefix .. "Spacing",
			label = L["Spacing"],
			type = "number",
			min = 0,
			max = 10,
			step = 1,
			advanced = true,
		},
		{
			path = prefix .. "PerRow",
			label = L["Icons per row"],
			type = "number",
			min = 1,
			max = 12,
			step = 1,
			desc = framed and L["A category with more icons continues on the next row down."]
				or L["Icons per row; further icons continue on the next row."],
		},
	}
	if framed then
		entries[#entries + 1] = {
			path = prefix .. "FramePerRow",
			label = L["Icons per row next to frames"],
			type = "number",
			min = 1,
			max = 20,
			step = 1,
			desc = L["Icons in a row next to a unit frame; further icons continue on the next row."],
		}
	end
	entries[#entries + 1] = {
		path = prefix .. "RowSpacing",
		label = L["Row spacing"],
		type = "number",
		min = 0,
		max = 20,
		step = 1,
		advanced = true,
		desc = L["Space between the rows of icons."],
	}
	for _, entry in ipairs(Requires(enabledBy, entries)) do
		schema[#schema + 1] = entry
	end
end

local function copyPaths(prefix, keys)
	local copy = {}
	for _, key in ipairs(keys) do
		copy[key] = prefix .. key:sub(1, 1):upper() .. key:sub(2)
	end
	return copy
end

local function sideTab(side, name, glyph, toggleLabel, toggleDesc, framesDesc, trinketDesc)
	local prefix = "groupCooldowns." .. side
	local enabledBy = { "groupCooldowns.enabled", prefix }
	local schema = {
		{
			path = prefix,
			label = toggleLabel,
			type = "toggle",
			enabledBy = "groupCooldowns.enabled",
			desc = toggleDesc,
		},
		{
			path = prefix .. "Layout",
			label = L["Display"],
			type = "select",
			values = LAYOUT_VALUES,
			enabledBy = enabledBy,
			desc = framesDesc,
		},
		{
			path = prefix .. "Categories",
			label = L["Categories"],
			type = "multiselect",
			values = categoryValues(),
			enabledBy = enabledBy,
			desc = L["Ability types to show. The PvP trinket always comes first, then interrupts."],
		},
		{
			path = prefix .. "SeparateTrinket",
			label = L["Separate trinket icon"],
			type = "toggle",
			enabledBy = { enabledBy, prefix .. "Categories.trinket" },
			desc = trinketDesc,
		},
	}
	layoutEntries(schema, prefix, enabledBy, true)
	schema[#schema + 1] = { header = L["Frames"], glyph = "arrows-up-down-left-right" }
	schema[#schema + 1] = { type = "elements" }
	return {
		key = side,
		name = name,
		glyph = glyph,
		schema = schema,
		copy = copyPaths(prefix, {
			"growth",
			"size",
			"spacing",
			"perRow",
			"framePerRow",
			"rowSpacing",
			"layout",
			"categories",
			"separateTrinket",
		}),
	}
end

local function interruptTab(side, name, glyph)
	local prefix = "groupCooldowns." .. side
	local separate = prefix .. "SeparateInterrupts"
	local schema = {
		{
			path = separate,
			label = L["Interrupts in a separate panel"],
			type = "toggle",
			enabledBy = { "groupCooldowns.enabled", prefix, prefix .. "Categories.interrupt" },
			desc = L["Interrupts and silences of every player leave the main icons and gather in one panel of their own, moved separately."],
		},
	}
	layoutEntries(schema, prefix .. "Interrupt", { "groupCooldowns.enabled", prefix, separate })
	schema[#schema + 1] = { header = L["Frames"], glyph = "arrows-up-down-left-right" }
	schema[#schema + 1] = { type = "elements" }
	return {
		key = side .. "Interrupts",
		name = name,
		glyph = glyph,
		schema = schema,
		copy = copyPaths(prefix, {
			"interruptGrowth",
			"interruptSize",
			"interruptSpacing",
			"interruptPerRow",
			"interruptRowSpacing",
			"separateInterrupts",
		}),
	}
end

local function spellToggle(id)
	local path = "groupCooldowns.spells." .. id
	local info = ui.API.RunAction("cooldownInfo", id)
	local name, _, icon = GetSpellInfo(id)
	return {
		label = ICON_FORMAT:format(info.icon or icon or QUESTION_MARK, name or tostring(id)),
		type = "toggle",
		desc = L["Cooldown: %s."]:format(SecondsToTime(info.cooldown)),
		get = function()
			return GroupCooldowns.IsSpellShown(id)
		end,
		set = function(value)
			if value == not info.hidden then
				ui:ResetConfig(path)
			else
				ui:SetConfig(path, value)
			end
		end,
		isDefault = function()
			return GroupCooldowns.IsSpellShown(id) == not info.hidden
		end,
		reset = function()
			ui:ResetConfig(path)
		end,
		defaultText = info.hidden and L["Off"] or L["On"],
	}
end

local function spellEntries(schema)
	local byCategory = {}
	for _, entry in ipairs(Data.SPELLS[selectedClass]) do
		local id = entry[1]
		local category = entry.cat or "utility"
		local ids = byCategory[category]
		if not ids then
			ids = {}
			byCategory[category] = ids
		end
		ids[#ids + 1] = id
	end
	for _, category in ipairs(Data.CATEGORIES) do
		local ids = byCategory[category]
		if ids then
			local toggles = {}
			schema[#schema + 1] = {
				header = L[GroupCooldowns.CATEGORY_NAMES[category]],
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

local function generalSchema()
	local schema = {
		{
			description = L["Cooldowns of party members and arena opponents, set up separately for allies and enemies: one block with rows grouped by ability type, or a row next to each unit frame. Every tracked ability is always shown: bright when ready, dark with a timer on cooldown, glowing while its effect is up. The PvP trinket comes first, then interrupts; the border shows the class."],
		},
	}
	Section(schema, L["General"], "groupCooldowns", {
		{
			path = "zones",
			new = "1.5.0",
			label = L["Show in"],
			type = "multiselect",
			values = {
				{ "arena", L["Arena"] },
				{ "battleground", L["Battlegrounds"] },
				{ "world", L["World and dungeons"] },
			},
			desc = L["Unit frame test mode shows them everywhere."],
		},
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
			path = "glowColor",
			label = L["Active effect glow"],
			type = "color",
			advanced = true,
			desc = L["Glow around a cooldown icon while the spell's effect is still active."],
		},
		ns.ClickThrough("clickThrough"),
	}, nil, nil, "sliders")
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
	return schema
end

local function buildGeneralSchema()
	local schema = generalSchema()
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
	GroupCooldowns.SetPreview(shown or ui.API.IsPreviewActive("unitFrames"))
end

local generalTabSchema = generalSchema()
generalTabSchema[#generalTabSchema + 1] =
	{ path = "groupCooldowns.spells", hidden = true, userContent = true, label = L["Spell list"] }

ns.RegisterPage({
	key = "cooldowns",
	name = L["Cooldowns"],
	desc = L["Cooldowns of allies and enemies next to their frames."],
	glyph = "hourglass-half",
	order = 32,
	group = "pvp",
	new = "1.5.0",
	enable = "groupCooldowns.enabled",
	schema = {
		{ path = "groupCooldowns.enabled", label = L["Enable"], type = "toggle" },
		{ path = "groupCooldowns", hidden = true },
	},
	tabs = {
		{
			key = "general",
			name = L["General"],
			glyph = "gear",
			schema = generalTabSchema,
			buildSchema = buildGeneralSchema,
			signature = function()
				return selectedClass
			end,
		},
		sideTab(
			"friendly",
			L["Allies"],
			"user-group",
			L["Party cooldowns"],
			L["Cooldowns of your party members."],
			L["One block: every ally's icons in one panel, rows grouped by ability type. Next to unit frames: each ally's icons in a row under the right corner of their party frame, moved on its own."],
			L["The PvP trinket leaves the cooldown icons and gets an icon of its own left of each party pet, only inside arenas."]
		),
		sideTab(
			"enemy",
			L["Enemies"],
			"user-ninja",
			L["Arena opponent cooldowns"],
			L["Cooldowns of arena opponents."],
			L["One block: every opponent's icons in one panel, rows grouped by ability type. Next to unit frames: each opponent's icons in a row under the left corner of their arena frame, moved on its own."],
			L["The PvP trinket leaves the cooldown icons and gets an icon of its own right of each arena frame."]
		),
		interruptTab("friendly", L["Ally interrupts"], "hand"),
		interruptTab("enemy", L["Enemy interrupts"], "hand-fist"),
	},
	onShow = function()
		setPreview(true)
	end,
	onHide = function()
		setPreview(false)
	end,
})
