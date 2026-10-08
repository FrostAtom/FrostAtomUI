local _, ns = ...

local L = FrostAtomUI.L

local ui = FrostAtomUI

local function fontValues()
	local values = {}
	for _, font in ipairs(ui.MediaList("fonts")) do
		local label = font[2]
		if ui.LOCALE ~= "enUS" and not ui.CanRenderLocale(ui.LOCALE, font[1]) then
			label = label .. " " .. L["(no letters of this language)"]
		end
		values[#values + 1] = { font[1], label }
	end
	return values
end

local schema = {
	{ header = L["Language"], glyph = "language" },
	{
		label = L["Interface language"],
		type = "select",
		width = 180,
		values = ui.GetLocaleOptions,
		get = ui.GetLocaleOverride,
		set = function(value)
			ui.SetLocaleOverride(value)
			ns.ShowReloadButton(L["Interface language"])
		end,
		desc = L["Language of FrostAtom UI text. Auto follows the game client."],
	},
	{
		label = L["Server"],
		type = "select",
		width = 180,
		values = ui.GetRealmOptions,
		get = ui.GetRealmOverride,
		set = function(value)
			ui.SetRealmOverride(value)
			ns.ShowReloadButton(L["Server"])
		end,
		desc = L["Features made for one server: WoW Circle solo queue, gossip windows, top killers and the combat log fix. Auto checks the realmlist."],
	},
	{ header = L["Appearance"], glyph = "palette" },
	{
		path = "general.font",
		label = L["Font"],
		type = "select",
		values = fontValues(),
		preview = "font",
		desc = L["The list also has fonts that other addons share through LibSharedMedia, for example SharedMedia."],
	},
	{
		path = "general.fontBold",
		label = L["Bold font"],
		type = "select",
		values = fontValues(),
		preview = "font",
		advanced = true,
	},
	{
		path = "general.statusbar",
		label = L["Status bar texture"],
		type = "select",
		values = ui.MediaList("statusbars"),
		preview = "statusbar",
		desc = L["The list also has textures that other addons share through LibSharedMedia, for example SharedMedia."],
	},
	{
		path = "general.uiScaleMode",
		label = L["UI scale"],
		type = "select",
		width = 180,
		values = {
			{ "game", L["As in game"], L["The game's own setting from the video options."] },
			{
				"pixel",
				L["Sharp frames (%d%%)"]:format(floor(ui.PixelPerfectScale() * 100 + 0.5)),
				L["One interface unit becomes one screen pixel, borders stay sharp. On large screens everything gets smaller."],
			},
			{ "custom", L["Custom size"], L["The size from the slider below."] },
		},
		set = function(value)
			if value == "custom" then
				ui:SetConfig("general.uiScale", floor(UIParent:GetScale() * 100 + 0.5) / 100)
			end
			ui:SetConfig("general.uiScaleMode", value)
		end,
		confirmRevert = true,
		desc = L['"As in game" brings back the scale you had before.'],
	},
	{
		path = "general.uiScale",
		label = L["Custom scale"],
		type = "number",
		percent = true,
		min = 0.4,
		max = 1.15,
		step = 0.01,
		applyOnRelease = true,
		disabled = function()
			return ui:GetConfig("general.uiScaleMode") ~= "custom"
		end,
		disabledDesc = L['Pick "Custom size" in UI scale.'],
		confirmRevert = true,
		desc = L["Below 64% the scale is applied by FrostAtom UI itself, the game's own setting stops at 64%."],
	},
	{ header = L["Mouse"], glyph = "computer-mouse" },
	{
		label = L["Aura icons ignore the mouse"],
		type = "toggle",
		get = function()
			return ns.AllClickThrough()
		end,
		set = function(value)
			ns.SetAllClickThrough(value)
		end,
		desc = L["Turns click-through on or off for every block of icons at once: unit frame auras, player buffs, DR, trinkets, cooldowns. Each block keeps its own switch."],
	},
	{ header = L["Cooldown timers"], new = "1.4.0", glyph = "stopwatch" },
	{
		description = L["Countdown text on action buttons, bags, unit frame cooldowns, nameplate auras and totems."],
	},
	{
		path = "cooldownTimer.minDuration",
		new = "1.4.0",
		label = L["Hide timers up to"],
		type = "number",
		min = 1.5,
		max = 10,
		step = 0.5,
		unit = "s",
		desc = L["Cooldowns this long or shorter get no countdown. 1.5 hides only the global cooldown."],
	},
	{
		path = "cooldownTimer.decimalThreshold",
		advanced = true,
		new = "1.4.0",
		label = L["Tenths below"],
		type = "number",
		min = 0,
		max = 10,
		step = 0.5,
		unit = "s",
		zeroText = L["Off"],
		desc = L["Remaining time under this value is shown with tenths of a second in the expiring color."],
	},
	{
		path = "cooldownTimer.readyFlash",
		advanced = true,
		label = L["Cooldown ready flash"],
		type = "toggle",
		desc = L["Short bright flash on cooldown tracker and internal cooldown icons as the ability becomes ready."],
	},
	{
		path = "cooldownTimer.expiringColor",
		new = "1.4.0",
		label = L["Expiring color"],
		type = "color",
		advanced = true,
	},
	{
		path = "cooldownTimer.secondsColor",
		advanced = true,
		new = "1.4.0",
		label = L["Seconds color"],
		type = "color",
		desc = L["Under a minute left."],
	},
	{
		path = "cooldownTimer.minutesColor",
		advanced = true,
		new = "1.4.0",
		label = L["Minutes color"],
		type = "color",
		desc = L["A minute or more left."],
	},
	{ header = L["Other addons"], new = "1.5.0", glyph = "puzzle-piece" },
	{
		label = L["Conflicting addons"],
		new = "1.5.0",
		type = "execute",
		text = L["Ask again"],
		glyph = "arrows-rotate",
		func = function()
			ui.ResetConflictChoices()
		end,
		desc = L["Forget the answers given when another addon was found doing the same job as a FrostAtom UI module, and check the loaded addons again."],
	},
}

ns.RegisterPage({
	key = "general",
	name = L["General"],
	desc = L["Language, fonts, interface size and cooldown timers."],
	glyph = "gear",
	order = 10,
	group = "start",
	schema = schema,
})
