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

local GROWTH_VALUES = { { "RIGHT", L["Right"] }, { "LEFT", L["Left"] } }

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

local function sidePanel(side, name)
	local prefix = "groupCooldowns." .. side
	local entries = {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = prefix .. "Growth",
			label = L["Row direction"],
			type = "select",
			values = GROWTH_VALUES,
			desc = L["Side the rows grow toward; category labels sit on the other side."],
		},
		{ header = L["Categories"], glyph = "list-check" },
	}
	for _, category in ipairs(Data.CATEGORIES) do
		entries[#entries + 1] = {
			path = prefix .. "Categories." .. category,
			label = GroupCooldowns.CATEGORY_NAMES[category],
			type = "toggle",
		}
	end
	ns.RegisterElement({
		path = prefix .. "Point",
		page = "cooldowns",
		name = name,
		enabledBy = { "groupCooldowns.enabled", prefix },
		schema = Requires({ "groupCooldowns.enabled", prefix }, entries),
	})
end

sidePanel("friendly", L["Ally cooldowns"])
sidePanel("enemy", L["Enemy cooldowns"])

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
			schema[#schema + 1] = { header = GroupCooldowns.CATEGORY_NAMES[category] }
			for _, id in ipairs(ids) do
				schema[#schema + 1] = spellToggle(id)
			end
		end
	end
end

local function buildSchema()
	local schema = {
		{ path = "groupCooldowns.enabled", label = L["Enable"], type = "toggle" },
		{
			description = L["Cooldowns of party members and arena opponents, gathered in two panels under the party and arena frames. Every tracked ability is always shown: bright when ready, dark with a timer on cooldown, glowing while its effect is up. Rows group abilities by type, icons of one player stay together and the border shows the class. PvP trinkets are shown next to the party and arena frames instead."],
		},
		{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
		{ type = "elements" },
	}

	Section(schema, L["General"], "groupCooldowns", {
		{
			path = "friendly",
			label = L["Party cooldowns"],
			type = "toggle",
			desc = L["Panel with the cooldowns of your party members."],
		},
		{
			path = "enemy",
			label = L["Arena opponent cooldowns"],
			type = "toggle",
			desc = L["Panel with the cooldowns of arena opponents."],
		},
		{
			path = "labels",
			label = L["Category labels"],
			type = "toggle",
			desc = L["Category name beside each row of icons."],
		},
		{
			path = "desaturate",
			label = L["Desaturate on cooldown"],
			type = "toggle",
			desc = L["Grey out the icon while the ability is on cooldown."],
		},
		{
			path = "readyFlash",
			label = L["Cooldown ready flash"],
			type = "toggle",
			desc = L["Short bright flash on a tracked cooldown icon as the ability becomes ready."],
		},
		{
			path = "glowColor",
			label = L["Active effect glow"],
			type = "color",
			desc = L["Glow around a cooldown icon while the spell's effect is still active."],
		},
	}, nil, nil, "sliders")

	Section(schema, L["Layout"], "groupCooldowns", {
		{ path = "size", label = L["Icon size"], type = "number", min = 12, max = 48, step = 1 },
		{ path = "spacing", label = L["Spacing"], type = "number", min = 0, max = 10, step = 1 },
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
