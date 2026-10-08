local _, ns = ...

local L = FrostAtomUI.L

local Section = ns.Section
local Requires = ns.Requires

local LOSS_OF_CONTROL = "lossOfControl.enabled"
local EXTERNALS = "externalDefensives.enabled"

local function testModeToggle(preview)
	return function()
		FrostAtomUI.API.SetPreview(preview, not FrostAtomUI.API.IsPreviewActive(preview))
	end
end

ns.RegisterElement({
	path = "lossOfControl.point",
	page = "control",
	tab = "alert",
	name = L["CC alert"],
	glyph = "lock",
	enabledBy = LOSS_OF_CONTROL,
	schema = Requires(LOSS_OF_CONTROL, {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "lossOfControl.scale",
			label = L["Scale"],
			type = "number",
			min = 0.5,
			max = 2,
			step = 0.05,
			percent = true,
			desc = L["Size of the alert icon and text."],
		},
		{ header = L["Display"], glyph = "bars-staggered" },
		{
			path = "lossOfControl.background",
			new = "1.4.0",
			label = L["Background"],
			type = "toggle",
			advanced = true,
			desc = L["Dark backdrop and red lines around the icon and text."],
		},
		{ header = L["Test"], glyph = "flask" },
		{
			label = L["Test"],
			type = "execute",
			text = L["Toggle"],
			glyph = "flask",
			enabledBy = LOSS_OF_CONTROL,
			desc = L["Cycle through fake effects to preview the alert. /uftest toggles it too."],
			func = testModeToggle("lossOfControl"),
		},
	}),
})

ns.RegisterElement({
	path = "externalDefensives.point",
	page = "control",
	tab = "defensives",
	name = L["External defensives"],
	glyph = "shield-heart",
	enabledBy = EXTERNALS,
	schema = Requires(EXTERNALS, {
		{ header = L["Layout"], glyph = "up-down-left-right" },
		{
			path = "externalDefensives.size",
			label = L["Icon size"],
			type = "number",
			min = 16,
			max = 64,
			step = 1,
		},
		{
			path = "externalDefensives.gap",
			label = L["Spacing"],
			type = "number",
			min = 0,
			max = 20,
			step = 1,
			advanced = true,
		},
		{
			path = "externalDefensives.maxIcons",
			new = "1.4.0",
			label = L["Maximum icons"],
			type = "number",
			min = 1,
			max = 6,
			step = 1,
			advanced = true,
			desc = L["Buffs past this count are not shown; the longest remaining come first."],
		},
		{ header = L["Test"], glyph = "flask" },
		{
			label = L["Test"],
			type = "execute",
			text = L["Toggle"],
			glyph = "flask",
			enabledBy = EXTERNALS,
			desc = L["Show fake buffs to preview the layout. /uftest toggles it too."],
			func = testModeToggle("externalDefensives"),
		},
	}),
})

local alert = {}
Section(alert, L["CC alert"], "lossOfControl", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Large alert in the middle of the screen while you are stunned, feared, silenced, disarmed or rooted."],
	},
	{
		path = "categories",
		new = "1.4.0",
		label = L["Also alert on"],
		type = "multiselect",
		values = { { "silence", L["Silences"] }, { "disarm", L["Disarms"] }, { "root", L["Roots"] } },
		desc = L["Stuns, fears, polymorphs and other full loss of control effects always show."],
	},
	{
		path = "lockouts",
		label = L["Spell school lockouts"],
		type = "toggle",
		advanced = true,
		desc = L["Also show the locked spell school and the time left when an enemy interrupts your cast."],
	},
	{
		path = "sound",
		label = L["Play sound"],
		type = "toggle",
		desc = L["Play a warning sound when a new effect starts."],
	},
}, nil, "1.4.0", "lock")
alert[#alert + 1] = {
	description = L['Uses its own spell list; unchecking a spell on the "CC on frames" tab does not affect this alert.'],
}
alert[#alert + 1] = { header = L["Frames"], glyph = "arrows-up-down-left-right" }
alert[#alert + 1] = { type = "elements" }

local defensives = {}
Section(defensives, L["External defensives"], "externalDefensives", {
	{
		path = "enabled",
		label = L["Enable"],
		type = "toggle",
		desc = L["Row of defensive buffs other players cast on you, such as Pain Suppression, Guardian Spirit and Hand spells, longest remaining first."],
	},
}, nil, "1.4.0", "shield-heart")
defensives[#defensives + 1] = { header = L["Frames"], glyph = "arrows-up-down-left-right" }
defensives[#defensives + 1] = { type = "elements" }

ns.AddTab("control", { key = "alert", order = 2, name = L["CC alert"], glyph = "triangle-exclamation", schema = alert })
ns.AddTab("control", {
	key = "defensives",
	order = 3,
	name = L["External defensives"],
	glyph = "shield-heart",
	schema = defensives,
})

ns.RegisterPage({
	key = "control",
	name = L["CC & defensives"],
	desc = L["Crowd control on frames, the alert when you lose control, and defensives cast on you."],
	glyph = "shield-halved",
	order = 34,
	group = "pvp",
	schema = {},
})
