local _, ns = ...

local ui = FrostAtomUI
local L = ui.L
local Data = ui.SpellAlertData

local ENABLED = "spellAlerts.enabled"
local ICON_FORMAT = "|T%s:16:16:0:0:64:64:5:59:5:59|t  %s"
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local CATEGORY_GLYPHS = {
	cast = "wand-sparkles",
	control = "ban",
	defensive = "shield-halved",
	offensive = "fire",
	utility = "bolt",
}

local ZONE_VALUES = {
	{ "arena", L["Arena"] },
	{ "battleground", L["Battlegrounds"] },
	{ "world", L["World"] },
}

local function spellToggle(spell, name, icon)
	local path = "spellAlerts.spells." .. spell.key
	local default = not spell.off
	return {
		label = ICON_FORMAT:format(icon or QUESTION_MARK, name),
		type = "toggle",
		enabledBy = ENABLED,
		desc = L["Spell IDs: %s"]:format(table.concat(spell, ", ")),
		get = function()
			local value = ui:GetConfig(path)
			if value == nil then
				return default
			end
			return value
		end,
		set = function(value)
			if value == default then
				ui:ResetConfig(path)
			else
				ui:SetConfig(path, value)
			end
		end,
		isDefault = function()
			return ui:GetConfig(path) == nil
		end,
		reset = function()
			ui:ResetConfig(path)
		end,
		onClick = function(value)
			if value then
				PlaySoundFile(Data.VOICE_PATH:format(spell.sound))
			end
		end,
		defaultText = default and L["On"] or L["Off"],
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
		enabledBy = ENABLED,
		toggles = toggles,
		toggleDesc = L["Turn every spell of this category on or off."],
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
		desc = L["A voice names important spells of enemy players: crowd control cast at you or your allies, defensive and offensive cooldowns, trinkets. Plays through the sound effects channel: follows the master and sound effects volume and is silent while sound effects are off."],
	},
	{
		label = L["Test"],
		type = "execute",
		text = L["Play"],
		glyph = "volume-high",
		enabledBy = ENABLED,
		desc = L["Play three alerts in a row to hear the volume and the queue."],
		func = function()
			ui:GetModule("SpellAlerts"):Test()
		end,
	},
	{ path = "spellAlerts.spells", hidden = true },
	{ header = L["General"], glyph = "gear" },
	{
		path = "spellAlerts.zones",
		label = L["Play in"],
		type = "multiselect",
		values = ZONE_VALUES,
		enabledBy = ENABLED,
	},
	{
		path = "spellAlerts.targetOnly",
		label = L["Outside arenas only target and focus"],
		type = "toggle",
		enabledBy = ENABLED,
		desc = L["On battlegrounds and in the world announce only your target and focus, and crowd control cast at you or landing on your party."],
	},
	{
		path = "spellAlerts.defensiveEnd",
		label = L["Defensive ends"],
		type = "toggle",
		enabledBy = ENABLED,
		desc = L["Also announce when Divine Shield, Ice Block, Hand of Protection, Deterrence, Cloak of Shadows or Anti-Magic Shell ends."],
	},
	{
		path = "spellAlerts.controlOnYou",
		label = L["Crowd control on you"],
		type = "toggle",
		enabledBy = ENABLED,
		desc = L["Also announce crowd control that lands on you, not only on your allies."],
	},
	{
		path = "spellAlerts.controlEnd",
		label = L["Your crowd control ends"],
		type = "toggle",
		enabledBy = ENABLED,
		desc = L["Announce when your Polymorph, Sap, Blind, Fear, Freezing Trap or other breakable crowd control ends on an enemy player."],
	},
	{
		path = "spellAlerts.interrupted",
		label = L["You are interrupted"],
		type = "toggle",
		enabledBy = ENABLED,
		desc = L["Announce when an enemy player interrupts your cast and locks the school."],
	},
	{
		description = L["Crowd control casts aimed at you sound at once, over other alerts. The rest wait in a short queue: a more important alert goes first, one that waits too long is dropped, and the same spell of the same player is not repeated for 3 seconds."],
	},
}

for _, category in ipairs(Data.CATEGORIES) do
	categoryEntries(schema, category)
end

ns.RegisterPage({
	key = "spellalerts",
	name = L["Spell alerts"],
	glyph = "bullhorn",
	order = 37,
	group = "pvp",
	new = "1.4.1",
	enable = ENABLED,
	schema = schema,
})
