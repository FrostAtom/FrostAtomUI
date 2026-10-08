local _, ns = ...

local ui = FrostAtomUI
local L = ui.L
local Data = ui.API.Catalog("control")

local ENABLED = "loseControl.enabled"
local UNIT_FRAMES = "unitFrames.enabled"
local ICON_FORMAT = "|T%s:16:16:0:0:64:64:5:59:5:59|t  %s"
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local CATEGORY_GLYPHS = {
	immune = "shield",
	magicImmune = "wand-magic-sparkles",
	physicalImmune = "shield-halved",
	stun = "face-dizzy",
	incapacitate = "ban",
	fear = "ghost",
	silence = "volume-xmark",
	disarm = "hand",
	root = "anchor",
}

local FRAME_VALUES = {
	{ "target", L["Target"] },
	{ "focus", L["Focus"] },
	{ "party", L["Party"] },
	{ "arena", L["Arena"] },
}

local function spellToggle(spell, name, icon)
	local path = "loseControl.spells." .. spell[1]
	return {
		label = ICON_FORMAT:format(icon or QUESTION_MARK, name),
		type = "toggle",
		enabledBy = UNIT_FRAMES,
		desc = L["Spell IDs: %s"]:format(table.concat(spell, ", ")),
		get = function()
			return ui:GetConfig(path) ~= false
		end,
		set = function(value)
			if value then
				ui:ResetConfig(path)
			else
				ui:SetConfig(path, false)
			end
		end,
		isDefault = function()
			return ui:GetConfig(path) == nil
		end,
		reset = function()
			ui:ResetConfig(path)
		end,
		defaultText = L["On"],
	}
end

local function categoryEntries(schema, category)
	local spells = {}
	for _, spell in ipairs(Data.SPELLS[category]) do
		local name, _, icon = GetSpellInfo(spell[1])
		spells[#spells + 1] = { spell = spell, name = name or tostring(spell[1]), icon = icon }
	end
	table.sort(spells, function(a, b)
		return a.name < b.name
	end)
	local toggles = {}
	schema[#schema + 1] = {
		header = L[Data.CATEGORY_NAMES[category]],
		glyph = CATEGORY_GLYPHS[category],
		enabledBy = UNIT_FRAMES,
		advanced = true,
		extraLabel = L["Spells (%d)"],
		lessLabel = L["Hide spells"],
		toggles = toggles,
		toggleDesc = L["Show or hide every spell of this category."],
	}
	for i, info in ipairs(spells) do
		toggles[i] = spellToggle(info.spell, info.name, info.icon)
		schema[#schema + 1] = toggles[i]
	end
end

local schema = {
	{
		path = ENABLED,
		label = L["Enable"],
		type = "toggle",
		enabledBy = UNIT_FRAMES,
		desc = L["Icon and timer of the strongest crowd control effect or damage immunity over the class icon of target, focus, party and arena frames."],
	},
	{
		label = L["Test frames"],
		type = "execute",
		text = L["Toggle"],
		glyph = "flask",
		enabledBy = UNIT_FRAMES,
		desc = L["Show every frame with fake units to preview the layout."],
		func = function()
			ui.API.RunAction("unitFrameTest")
		end,
	},
	{ path = "loseControl.spells", hidden = true, userContent = true, label = L["Spell list"] },
	{ header = L["General"], glyph = "gear" },
	{
		path = "loseControl.frames",
		label = L["Show on"],
		type = "multiselect",
		values = FRAME_VALUES,
		enabledBy = UNIT_FRAMES,
	},
	{
		path = "loseControl.lockouts",
		new = "1.5.0",
		label = L["Locked school after an interrupt"],
		type = "toggle",
		enabledBy = UNIT_FRAMES,
		desc = L["When someone interrupts an enemy player, the interrupted spell's icon shows how long that school stays locked. Ranks with silences, below stuns and fears."],
	},
	{
		description = L["One effect is shown at a time: the category higher in this list wins (stuns, incapacitates and fears are equal), among equal effects the one lasting longest. Uncheck a spell to ignore it, or the box in a category header to ignore the whole category."],
	},
}

for _, category in ipairs(Data.CATEGORIES) do
	categoryEntries(schema, category)
end

ns.AddTab("control", {
	key = "frames",
	order = 1,
	name = L["CC on frames"],
	glyph = "lock",
	new = "1.5.0",
	schema = ns.TabRequires(ENABLED, schema),
})
