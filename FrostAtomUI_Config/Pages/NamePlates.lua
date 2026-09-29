local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local PLAYER_COLOR_VALUES = {
	{ "class", L["Class color"] },
	{ "reaction", L["Reaction color"] },
	{ "health", L["Health percent"] },
	{ "custom", L["Fixed color"] },
}

local NPC_COLOR_VALUES = {
	{ "reaction", L["Reaction color"] },
	{ "health", L["Health percent"] },
	{ "custom", L["Fixed color"] },
}

local PLAYER_NAME_COLOR_VALUES = {
	{ "class", L["Class color"] },
	{ "reaction", L["Reaction color"] },
	{ "white", L["White"] },
}

local NPC_NAME_COLOR_VALUES = {
	{ "reaction", L["Reaction color"] },
	{ "white", L["White"] },
}

local HEALTH_TEXT_VALUES = {
	{ "none", L["None"] },
	{ "target", L["Target only"] },
	{ "all", L["Always"] },
}

local HEALTH_TEXT_FORMAT_VALUES = {
	{ "percent", L["Percent"] },
	{ "value", L["Value"] },
	{ "both", L["Value and percent"] },
}

local NEW = "1.4.1"

local COPY_FIELDS = { "width", "height", "showName", "healthText", "showCastbar", "castbarHeight", "showAuras" }

local function arenaIconSchema(prefix, owner)
	if owner then
		return {
			path = prefix .. "arenaIconSize",
			new = NEW,
			label = L["Pet icon size in arena"],
			type = "number",
			min = 12,
			max = 64,
			step = 1,
			desc = L["Pet icons are turned on with the class icon option on the players tab."],
			enabledBy = "namePlates." .. owner .. ".arenaIcon",
		}
	end
	return {
		path = prefix .. "arenaIcon",
		new = NEW,
		label = L["Class icon in arena"],
		type = "toggle",
		desc = L["In arena, replace the nameplates of players with their class icon and the nameplates of hunter pets, warlock demons, the death knight's ghoul and the mage's water elemental with the pet's icon, framed in the reaction color. A compact castbar is shown under it, auras are not."],
	}, {
		path = prefix .. "arenaIconSize",
		new = NEW,
		label = L["Arena icon size"],
		type = "number",
		min = 12,
		max = 64,
		step = 1,
		enabledBy = prefix .. "arenaIcon",
	}
end

local function categoryTab(key, name, glyph, classColors, about, colorDesc, arenaIconOwner)
	local prefix = "namePlates." .. key .. "."
	local modePath = prefix .. "healthColorMode"
	local kind = classColors and "class" or "reaction"
	local copy = {
		[kind .. "HealthColorMode"] = modePath,
		[kind .. "NameColorMode"] = prefix .. "nameColorMode",
		healthColor = prefix .. "healthColor",
	}
	for _, field in ipairs(COPY_FIELDS) do
		copy[field] = prefix .. field
	end

	local schema = {
		{ description = about },
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = prefix .. "width",
			new = NEW,
			label = L["Health bar width"],
			type = "number",
			min = 40,
			max = 200,
			step = 1,
			desc = L["Width of the health bar and the castbar under it."],
		},
		{
			path = prefix .. "height",
			new = NEW,
			label = L["Health bar height"],
			type = "number",
			min = 3,
			max = 30,
			step = 1,
		},
		{ header = L["Display"], glyph = "bars-staggered" },
		{ path = prefix .. "showName", new = NEW, label = L["Name"], type = "toggle" },
		{
			path = prefix .. "healthText",
			new = NEW,
			label = L["Health text"],
			type = "select",
			values = HEALTH_TEXT_VALUES,
			desc = L["Health text on the right of the health bar: never, only on your target, or on every nameplate."],
		},
		{
			path = prefix .. "showCastbar",
			new = NEW,
			label = L["Castbar"],
			type = "toggle",
			desc = L["Castbar under the health bar. Colors and indicators are set on the General tab."],
		},
		{
			path = prefix .. "castbarHeight",
			advanced = true,
			new = NEW,
			label = L["Castbar height"],
			type = "number",
			min = 3,
			max = 30,
			step = 1,
			enabledBy = prefix .. "showCastbar",
		},
		{
			path = prefix .. "showAuras",
			new = NEW,
			label = L["Auras"],
			type = "toggle",
			desc = L["CC and other tracked auras above the nameplate. Which auras are shown is set on the General tab."],
		},
		{ header = L["Colors"], glyph = "palette" },
		{
			path = modePath,
			new = NEW,
			label = L["Health bar color"],
			type = "select",
			values = classColors and PLAYER_COLOR_VALUES or NPC_COLOR_VALUES,
			desc = colorDesc,
		},
		{
			path = prefix .. "healthColor",
			new = NEW,
			label = L["Health color"],
			type = "color",
			desc = L["Used with the fixed color mode."],
			disabled = function()
				return ui:GetConfig(modePath) ~= "custom"
			end,
		},
		{
			path = prefix .. "nameColorMode",
			advanced = true,
			new = NEW,
			label = L["Name color"],
			type = "select",
			values = classColors and PLAYER_NAME_COLOR_VALUES or NPC_NAME_COLOR_VALUES,
			enabledBy = prefix .. "showName",
		},
		{ header = L["Arena"], glyph = "trophy" },
	}
	for _, row in ipairs({ arenaIconSchema(prefix, arenaIconOwner) }) do
		schema[#schema + 1] = row
	end

	return {
		key = key,
		name = name,
		glyph = glyph,
		copy = copy,
		schema = schema,
	}
end

local generalSchema = {
	{ header = L["General"], glyph = "gear" },
	{
		path = "namePlates.spreadPlates",
		new = NEW,
		label = L["Spread overlapping nameplates"],
		type = "toggle",
		desc = L["Push overlapping enemy nameplates apart vertically, like the stacking nameplates of the modern client."],
	},
	{
		path = "namePlates.hoverHighlight",
		advanced = true,
		new = NEW,
		label = L["Highlight on mouseover"],
		type = "toggle",
		desc = L["Light wash over the health bar of the nameplate under the cursor."],
	},
	{
		path = "namePlates.fitClickArea",
		advanced = true,
		new = NEW,
		label = L["Click area fits the nameplate"],
		type = "toggle",
		desc = L["Nameplates react to clicks and mouseover only over the visible health bar or icon, not over the larger area of the Blizzard nameplate. Works in combat too."],
	},
	{
		path = "namePlates.targetBorder",
		label = L["Highlight target border"],
		type = "toggle",
		desc = L["Thick white border around the nameplate or arena icon of the current target."],
	},
	{
		path = "namePlates.nonTargetAlpha",
		new = NEW,
		label = L["Non-target opacity"],
		type = "number",
		min = 0.1,
		max = 1,
		step = 0.05,
		percent = true,
		desc = L["Opacity of the other nameplates while you have a target."],
	},
	{
		path = "namePlates.totemIcons",
		new = "1.4.0",
		label = L["Totems as icons"],
		type = "toggle",
		desc = L["Replace totem nameplates with the totem's spell icon, framed in the reaction color."],
	},
	{
		path = "namePlates.totemTimer",
		new = "1.4.1",
		label = L["Totem timer"],
		type = "toggle",
		enabledBy = "namePlates.totemIcons",
		desc = L["Time left on totems whose summon was seen nearby."],
	},
	{
		path = "namePlates.totemPulse",
		new = "1.4.1",
		label = L["Totem pulse bar"],
		type = "toggle",
		enabledBy = "namePlates.totemIcons",
		desc = L["Bar above pulsing totems (Tremor, Earthbind, Cleansing, Magma, Healing Stream, Stoneclaw, Mana Tide) that fills up to the next pulse. Synced from the summon and every pulse seen in the combat log."],
	},
	{
		path = "namePlates.totemPulseHeight",
		advanced = true,
		new = "1.4.1",
		label = L["Totem pulse bar height"],
		type = "number",
		min = 2,
		max = 12,
		step = 1,
		enabledBy = "namePlates.totemPulse",
	},
	{
		path = "namePlates.totemPulseColor",
		advanced = true,
		new = "1.4.1",
		label = L["Totem pulse bar color"],
		type = "color",
		enabledBy = "namePlates.totemPulse",
	},
	{
		path = "namePlates.totemIconSize",
		advanced = true,
		label = L["Totem icon size"],
		type = "number",
		min = 12,
		max = 48,
		step = 1,
		enabledBy = "namePlates.totemIcons",
	},
	{
		path = "namePlates.totemFullAlpha",
		advanced = true,
		new = NEW,
		label = L["Opaque totems"],
		type = "toggle",
		enabledBy = "namePlates.totemIcons",
		desc = L["Totem icons stay fully opaque when another unit is targeted instead of fading with the other nameplates."],
	},
	{ header = L["Text"], glyph = "font" },
	{
		path = "namePlates.healthTextFormat",
		new = NEW,
		label = L["Health text format"],
		type = "select",
		values = HEALTH_TEXT_FORMAT_VALUES,
		desc = L["Where the health text is shown is set per nameplate type."],
	},
	{ path = "namePlates.nameFont", advanced = true, label = L["Name font"], type = "font" },
	{ path = "namePlates.percentFont", advanced = true, label = L["Health text font"], type = "font" },
	{ description = L["Backdrop, border and text colors follow the unit frame settings."], advanced = true },
	{ header = L["Indicators"], glyph = "icons" },
	{ path = "namePlates.showRaidIcon", label = L["Raid icon"], type = "toggle" },
	{
		path = "namePlates.raidIconSize",
		advanced = true,
		label = L["Raid icon size"],
		type = "number",
		min = 10,
		max = 40,
		step = 1,
		enabledBy = "namePlates.showRaidIcon",
	},
	{
		path = "namePlates.arenaNumbers",
		new = NEW,
		label = L["Arena numbers"],
		type = "toggle",
		desc = L["Arena opponent number (1, 2, 3) to the left of enemy nameplates in arena."],
	},
	{ header = L["Castbar"], glyph = "bars-progress" },
	{
		path = "namePlates.castbarsAllPlates",
		new = NEW,
		label = L["Castbars on every nameplate"],
		type = "toggle",
		desc = L["Casts of arena opponents, your focus, the unit under the cursor and your group's targets on their nameplates, not only on the target. A cast keeps running after you switch targets."],
	},
	{
		path = "namePlates.castbarsCombatLog",
		advanced = true,
		new = NEW,
		label = L["Casts from the combat log"],
		type = "toggle",
		desc = L["Show casts of enemy players that no unit points at, timed from the spell's base cast time."],
		enabledBy = "namePlates.castbarsAllPlates",
	},
	{
		path = "namePlates.castbarIconSize",
		advanced = true,
		label = L["Castbar icon size"],
		type = "number",
		min = 8,
		max = 40,
		step = 1,
	},
	{
		path = "namePlates.castbarGap",
		advanced = true,
		label = L["Castbar spacing"],
		type = "number",
		min = 0,
		max = 20,
		step = 1,
		desc = L["Gap between the health bar and the castbar."],
	},
	{ path = "namePlates.castbarColor", advanced = true, label = L["Castbar color"], type = "color" },
	{
		path = "namePlates.castbarLockedColor",
		advanced = true,
		label = L["Not interruptible color"],
		type = "color",
		desc = L["Castbar color while the cast cannot be interrupted."],
	},
	{ header = L["Castbar indicators"], glyph = "bolt" },
	{
		path = "namePlates.castbarSpellName",
		new = NEW,
		label = L["Show spell name"],
		type = "toggle",
		desc = L["Name of the spell being cast on the left of the castbar."],
	},
	{
		path = "namePlates.castbarTargetName",
		advanced = true,
		new = "1.4.0",
		label = L["Show cast target"],
		type = "toggle",
		desc = L["Class-colored name of the caster's target on the right of the castbar."],
	},
	{
		path = "namePlates.castbarTargetingYou",
		new = "1.4.0",
		label = L["Highlight casts on you"],
		type = "toggle",
		desc = L["Colored castbar border while an enemy casts at you."],
	},
	{
		path = "namePlates.castbarImportant",
		new = "1.4.0",
		label = L["Pulse important casts"],
		type = "toggle",
		desc = L["Pulsing glow around the castbar for crowd control and heals."],
	},
	{
		path = "namePlates.castbarInterrupter",
		advanced = true,
		new = "1.4.0",
		label = L["Show who interrupted"],
		type = "toggle",
		desc = L["Keep an interrupted castbar red for a second with the interrupter's name."],
	},
	{
		path = "namePlates.castbarFinishFlash",
		advanced = true,
		new = "1.4.0",
		label = L["Flash on finished cast"],
		type = "toggle",
		desc = L["Short white flash when a cast completes."],
	},
	{
		path = "namePlates.castbarShield",
		advanced = true,
		new = "1.4.0",
		label = L["Shield on uninterruptible casts"],
		type = "toggle",
		desc = L["Shield in place of the spell icon when the cast cannot be interrupted."],
	},
	{ header = L["Auras"], glyph = "wand-magic-sparkles" },
	{
		path = "namePlates.aurasAllPlates",
		new = NEW,
		label = L["Auras on every nameplate"],
		type = "toggle",
		desc = L["Auras on all nameplates, not only on the target. Without a unit pointing at the nameplate they come from the combat log."],
	},
	{
		path = "namePlates.ownDebuffs",
		label = L["Include own debuffs"],
		type = "toggle",
		desc = L["Debuffs applied by you or your pet, in addition to CC."],
	},
	{
		path = "namePlates.enemyBuffs",
		new = NEW,
		label = L["Enemy defensives and purgeable buffs"],
		type = "toggle",
		desc = L["Divine Shield, Ice Block, Cloak of Shadows, Hand of Freedom and other defensives, plus short Magic and Enrage buffs you can dispel."],
	},
	{
		path = "namePlates.otherDebuffs",
		advanced = true,
		new = NEW,
		label = L["Include snares and DoTs from others"],
		type = "toggle",
		desc = L["Snares, healing reduction and key damage over time effects applied by other players."],
	},
	{
		path = "namePlates.maxAuraIcons",
		advanced = true,
		label = L["Max aura icons"],
		type = "number",
		min = 1,
		max = 12,
		step = 1,
	},
	{ header = L["Aura icons"], glyph = "table-cells" },
	{
		path = "namePlates.auraSize",
		label = L["Aura icon size"],
		type = "number",
		min = 12,
		max = 40,
		step = 1,
	},
	{
		path = "namePlates.ccAuraSize",
		advanced = true,
		new = NEW,
		label = L["CC icon size"],
		type = "number",
		min = 12,
		max = 48,
		step = 1,
		desc = L["Crowd control icons can be larger than the rest of the row."],
	},
	{
		path = "namePlates.auraGap",
		advanced = true,
		label = L["Aura spacing"],
		type = "number",
		min = 0,
		max = 12,
		step = 1,
		desc = L["Gap between aura icons."],
	},
	{
		path = "namePlates.auraRowGap",
		advanced = true,
		label = L["Aura row offset"],
		type = "number",
		min = 0,
		max = 30,
		step = 1,
		desc = L["Gap between the health bar and the aura row above it."],
	},
	{
		path = "namePlates.showAuraTimer",
		advanced = true,
		label = L["Aura timers"],
		type = "toggle",
		desc = L["Remaining time text on aura icons."],
	},
	{
		path = "namePlates.showAuraCount",
		advanced = true,
		label = L["Aura stacks"],
		type = "toggle",
		desc = L["Stack count in the corner of aura icons."],
	},
	{
		path = "namePlates.auraFont",
		advanced = true,
		label = L["Aura font"],
		type = "font",
		desc = L["Timer and stack text on aura icons."],
	},
	{ header = L["Enemy healers"], glyph = "user-nurse" },
	{
		path = "namePlates.showHealers",
		label = L["Enable"],
		type = "toggle",
		desc = L["Healer icon next to the name in battlegrounds."],
	},
	{
		path = "namePlates.healerClasses",
		advanced = true,
		label = L["Healer classes"],
		type = "multiselect",
		values = {
			{ "PRIEST", L["Priest"] },
			{ "PALADIN", L["Paladin"] },
			{ "SHAMAN", L["Shaman"] },
			{ "DRUID", L["Druid"] },
		},
		desc = L["Only these classes can be marked as healers."],
		enabledBy = "namePlates.showHealers",
		indent = false,
	},
	{
		path = "namePlates.healerIconSize",
		advanced = true,
		label = L["Healer icon size"],
		type = "number",
		min = 8,
		max = 32,
		step = 1,
		enabledBy = "namePlates.showHealers",
		indent = false,
	},
	{
		path = "namePlates.healerThreshold",
		advanced = true,
		label = L["Healer heal / damage ratio"],
		type = "number",
		min = 0.5,
		max = 10,
		step = 0.5,
		desc = L["A player counts as a healer when their battleground healing exceeds their damage by this factor."],
		enabledBy = "namePlates.showHealers",
		indent = false,
	},
}

local HIDDEN_PATH = "namePlates.hiddenNames"
local HIDE_ENABLE = "namePlates.hideByName"
local NAME_BUTTON_WIDTH = 64
local NAME_BUTTON_HEIGHT = 20

local function hiddenNames()
	return ui.Config.namePlates.hiddenNames
end

local function addHiddenName(name)
	name = name and strtrim(name)
	if not name or name == "" then
		return
	end
	local lower = strlower(name)
	for _, existing in ipairs(hiddenNames()) do
		if strlower(existing) == lower then
			return
		end
	end
	local list = CopyTable(hiddenNames())
	list[#list + 1] = name
	ui:SetConfig(HIDDEN_PATH, list)
end

local function removeHiddenName(index)
	return function()
		local list = CopyTable(hiddenNames())
		table.remove(list, index)
		ui:SetConfig(HIDDEN_PATH, list)
	end
end

local function hiddenNameRow(index)
	return {
		type = "custom",
		label = "",
		indent = false,
		enabledBy = HIDE_ENABLE,
		build = function(row)
			local text = row:CreateFontString(nil, "ARTWORK")
			text:SetFontObject(ns.Font("GameFontHighlight"))
			text:SetPoint("LEFT", 8, 0)
			text:SetPoint("RIGHT", row, "RIGHT", -NAME_BUTTON_WIDTH - 12, 0)
			text:SetJustifyH("LEFT")
			text:SetWordWrap(false)
			local remove = ns.CreateButton(row, L["Remove"], NAME_BUTTON_WIDTH, true, NAME_BUTTON_HEIGHT)
			remove:SetPoint("RIGHT", -4, 0)
			remove:SetScript("OnClick", removeHiddenName(index))
			row.text, row.remove = text, remove
		end,
		refresh = function(row)
			row.text:SetText(hiddenNames()[index] or "")
		end,
		setEnabled = function(row, enabled)
			ns.SetTextEnabled(row.text, enabled)
			ns.SetControlEnabled(row.remove, enabled)
		end,
	}
end

local function buildHiddenSchema()
	local schema = {
		{
			path = HIDE_ENABLE,
			label = L["Enable"],
			type = "toggle",
			desc = L["Nameplates of the units in the list are not shown and do not react to clicks or mouseover."],
		},
		{ header = L["Names"], glyph = "eye-slash" },
	}
	for index in ipairs(hiddenNames()) do
		schema[#schema + 1] = hiddenNameRow(index)
	end
	schema[#schema + 1] = {
		label = L["Add name"],
		type = "input",
		text = L["Add"],
		glyph = "plus",
		width = 160,
		maxLetters = 48,
		enabledBy = HIDE_ENABLE,
		func = addHiddenName,
	}
	schema[#schema + 1] = {
		type = "custom",
		label = "",
		enabledBy = HIDE_ENABLE,
		build = function(row)
			local button = ns.CreateButton(row, L["Add from target"], 140)
			button:SetPoint("LEFT", row, "LEFT", ns.CONTROL_X + 6, 0)
			button:SetScript("OnClick", function()
				addHiddenName(UnitExists("target") and UnitName("target"))
			end)
			row.button = button
		end,
		setEnabled = function(row, enabled)
			ns.SetControlEnabled(row.button, enabled)
		end,
	}
	return schema
end

local function hiddenSignature()
	return table.concat(hiddenNames(), "\n")
end

ns.RegisterPage({
	key = "nameplates",
	name = L["Nameplates"],
	glyph = "id-card",
	order = 22,
	group = "frames",
	enable = "namePlates.enabled",
	schema = {
		{
			path = "namePlates.enabled",
			label = L["Enable"],
			type = "toggle",
			reload = true,
			desc = L["Restyle Blizzard nameplates."],
		},
	},
	tabs = {
		{ key = "general", name = L["General"], glyph = "gear", schema = generalSchema },
		categoryTab(
			"enemyPlayer",
			L["Enemy players"],
			"user-ninja",
			true,
			L["Hostile players, recognized by the class color of their nameplate."],
			L["Class color: the player's class. Reaction color: hostile red. Health percent: a color mixed from the current health. Fixed color: the color below."]
		),
		categoryTab(
			"friendlyPlayer",
			L["Friendly players"],
			"user-group",
			false,
			L["Players friendly to you."],
			L["Reaction color: friendly blue. Health percent: a color mixed from the current health. Fixed color: the color below."]
		),
		categoryTab(
			"enemyNpc",
			L["Enemy NPCs"],
			"skull",
			false,
			L["Hostile and neutral creatures, including the pets and guardians of enemy players."],
			L["Reaction color: red for hostile, yellow for neutral. Health percent: a color mixed from the current health. Fixed color: the color below."],
			"enemyPlayer"
		),
		categoryTab(
			"friendlyNpc",
			L["Friendly NPCs"],
			"handshake",
			false,
			L["Friendly creatures, including the pets and guardians of friendly players."],
			L["Reaction color: friendly green. Health percent: a color mixed from the current health. Fixed color: the color below."],
			"friendlyPlayer"
		),
		{
			key = "hidden",
			name = L["Hidden"],
			glyph = "eye-slash",
			schema = { { path = HIDE_ENABLE, hidden = true }, { path = HIDDEN_PATH, hidden = true } },
			buildSchema = buildHiddenSchema,
			signature = hiddenSignature,
		},
	},
})
