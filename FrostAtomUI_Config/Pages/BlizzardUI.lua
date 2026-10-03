local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local NEW = "1.4.1"
local PAGE = "blizzard"
local ACTION_BARS = "hideBlizzard.actionBars"

ns.RegisterElement({
	path = "actionBar.microMenu",
	page = PAGE,
	name = L["Micro menu"],
	glyph = "bars",
	enabledBy = ACTION_BARS,
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
		ns.MenuVisibility("actionBar.microMenu", L["Keep the micro menu faded until the cursor is over it."]),
	},
})

ns.RegisterElement({
	path = "actionBar.bagButton",
	page = PAGE,
	name = L["Bag button"],
	glyph = "bag-shopping",
	enabledBy = ACTION_BARS,
	schema = {
		ns.MenuVisibility("actionBar.bagButton", L["Keep the bag button faded until the cursor is over it."]),
	},
})

local toggles = {}

local function hideToggle(key, label, desc, hidden)
	local entry = {
		path = "hideBlizzard." .. key,
		label = label,
		type = "toggle",
		reload = true,
		hidden = hidden,
		desc = desc,
	}
	if not hidden then
		toggles[#toggles + 1] = entry
	end
	return entry
end

local schema = {
	{
		description = L["Each Blizzard frame is hidden on its own, with or without its FrostAtom UI replacement."],
	},
	{
		header = L["Hidden frames"],
		glyph = "eye-slash",
		toggles = toggles,
		toggleDesc = L["Hide or show every frame on this list."],
	},
	hideToggle(
		"actionBars",
		L["Hide action bars"],
		L["Main and side bars with the stance, pet, possess and vehicle bars, bag slots and the experience and reputation bars. The micro menu and the bag button stay as separate movable frames."]
	),
	hideToggle(
		"unitFrames",
		L["Hide unit frames"],
		L["Player, target, focus, party and arena frames and the combo points next to the target."]
	),
	hideToggle("castBar", L["Hide player castbar"], L["The castbar at the bottom of the screen."]),
	hideToggle("buffs", L["Hide buffs and debuffs"], L["Your buffs and debuffs in the top right corner."]),
	hideToggle("weaponEnchants", L["Hide weapon enchants"], L["Poison, oil and weapon imbue icons next to the buffs."]),
	hideToggle("runes", L["Hide runes"], L["The rune bar under the player frame."], ns.NotClass("DEATHKNIGHT")),
	{ header = L["Frames"], glyph = "arrows-up-down-left-right" },
	{ type = "elements" },
}

ns.RegisterPage({
	key = PAGE,
	name = L["Blizzard UI"],
	glyph = "eye-slash",
	new = NEW,
	order = 64,
	group = "system",
	schema = schema,
})
