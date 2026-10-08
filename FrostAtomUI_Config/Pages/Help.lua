local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local TERM_COLOR = "|cffffd100%s|r - %s"

local function open(page, tab)
	return function()
		ns.Toggle(page, tab)
	end
end

local function dragText()
	local modifier = ui:GetConfig("actionBar.dragModifier")
	local button = ui:GetConfig("actionBar.dragButton")
	local key = modifier ~= "none" and ui.SetupPresets.ValueText("actionBar.dragModifier", modifier)
	local mouse = ui.SetupPresets.ValueText("actionBar.dragButton", button)
	return key and ("%s + %s"):format(key, mouse) or mouse
end

local function layoutName()
	return ui.Movers.GetBaseLayoutName and ui.Movers.GetBaseLayoutName() or L["Standard"]
end

local function onOff(path)
	return ui:GetConfig(path) and L["on"] or L["off"]
end

local function question(list, text, answer, button, func)
	list[#list + 1] = { header = text }
	list[#list + 1] = { description = answer }
	if button then
		list[#list + 1] = { label = " ", type = "execute", text = button, width = 160, func = func }
	end
end

local function buildQuestions()
	local list = {}
	question(
		list,
		L["How do I move a spell on a bar?"],
		L["Drag it while holding %s. The key is set on the Action bars page, General tab."]:format(dragText()),
		L["Open"],
		open("actionbar")
	)
	question(
		list,
		L['Why don\'t I see "Out of range" and other red messages?'],
		L['Red error messages: %s now. Choose "All" or "No spam" to see them.']:format(
			ui.SetupPresets.ValueText("tweaks.errorMessages", ui:GetConfig("tweaks.errorMessages"))
		),
		L["Open"],
		open("quicksetup")
	)
	question(
		list,
		L["How do I move a frame and put it back?"],
		L['Press "Unlock frames" at the bottom of this window and drag the frame. Right-click a frame to move it back to the layout "%s". Ctrl+Z undoes a move.']:format(
			layoutName()
		),
		L["Unlock frames"],
		function()
			ui.Movers.Unlock()
		end
	)
	question(
		list,
		L["How do I undo changes?"],
		L['The arrow next to a setting returns its value, "Undo" at the bottom (Ctrl+Z) undoes the last change, Backups keep copies of the whole profile.'],
		L["Backups"],
		open("profiles", "backups")
	)
	question(
		list,
		L["Does the addon post to chat in my name?"],
		L["Only what you turn on. Interrupt messages: %s, arena results to the party: %s."]:format(
			onOff("announce.interrupts"),
			onOff("announce.arenaResultToParty")
		),
		L["Open"],
		open("automation")
	)
	question(
		list,
		L["What is the English voice in combat?"],
		L["FrostAtom UI spell alerts: a voice names dangerous enemy spells. You can turn it off or keep it for arenas only."],
		L["Open"],
		open("alerts", "voice")
	)
	question(
		list,
		L["Where did the grass and the tips for new players go?"],
		L['FrostAtom UI can hide them (Game client page). "Restore game settings" there brings back everything it changed.'],
		L["Open"],
		open("client")
	)
	question(
		list,
		L["How do I copy my settings to another character or a friend?"],
		L["Characters of one account can share a profile. For a friend, export a profile string or a layout string."],
		L["Profiles"],
		open("profiles")
	)
	question(
		list,
		L["How do I bring back the default Blizzard frames?"],
		L['Press "Bring back the Blizzard interface" on the Blizzard UI page, or turn off one FrostAtom UI module and choose to bring its Blizzard frames back.'],
		L["Open"],
		open("blizzard", "hidden")
	)
	question(
		list,
		L["How do I remove the addon and get the game back as it was?"],
		L['First press "Restore game settings" on the Game client page, then delete the FrostAtomUI and FrostAtomUI_Config folders.']
	)
	question(
		list,
		L["The settings window does not open."],
		L['Turn on "FrostAtom UI Config" in the AddOns list on the character screen.']
	)
	question(list, L["I sold an item by mistake. How do I get it back?"], L['The merchant window has a "Buyback" tab.'])
	question(
		list,
		L["Found a bug. What should I send?"],
		L["The report from Diagnostics and the steps that lead to the bug."],
		L["Copy report"],
		function()
			ui.ShowDebugReport()
		end
	)
	return list
end

local COMMANDS = {
	{ "/fui", L["open the settings (also %s)"]:format("/ui, /агш, /гш") },
	{ "/fui castbar", L["search the settings in English or Russian"] },
	{ "/fui is:changed", L["settings you changed; also is:preset, is:new, is:reload, is:off and in:<page>"] },
	{ "/fui unlock", L["move frames"] },
	{ "/moveui", L["move frames or lock them again"] },
	{ "/kb", L["key binding mode for the action bars"] },
	{ "/fui reset", L["move all frames back to the active layout"] },
	{ "/fui setup", L["run the setup again"] },
	{ "/fui restore", L["backups of the profile"] },
	{ "/fui debug", L["report for the developer"] },
	{ "/fui help", L["this list"] },
	{ "/bind", L["key binding mode"] },
	{ "/ia", L["interrupt messages on or off"] },
	{ "/history", L["arena history"] },
	{ "/recap", L["death recap"] },
	{ "/uftest", L["test unit frames"] },
	{ "/cdtest", L["test cooldowns"] },
	{ "/copy", L["copy chat text"] },
	{ "/sort", L["sort bags"] },
	{ "/rl", L["reload the UI"] },
}

local function buildCommands()
	local list = {
		{
			description = L["Type a command in chat. Russian words work too: %s."]:format(
				"/fui мастер, /fui двигать, /fui справка"
			),
		},
	}
	for _, command in ipairs(COMMANDS) do
		list[#list + 1] = {
			label = command[1],
			type = "execute",
			text = L["Type it"],
			width = 90,
			func = function()
				ns.HideWindow()
				ChatFrame_OpenChat(command[1] .. " ")
			end,
			desc = command[2],
		}
		list[#list + 1] = { description = command[2] }
	end
	return list
end

local TERMS = {
	{ L["Focus"], L["A second remembered target you can watch, e.g. to interrupt its casts. Mostly used in PvP."] },
	{ L["Global cooldown (GCD)"], L["A pause of about 1.5 s after most spells."] },
	{ L["Crowd control (CC)"], L["Stuns, fears, polymorphs, silences and other loss-of-control effects."] },
	{
		L["Diminishing returns (DR)"],
		L["Repeated control of one type on the same target lasts half, then a quarter, then fails; resets after 15 s."],
	},
	{ L["Cooldown"], L["Time until an ability can be used again."] },
	{ L["PvP trinket"], L["Breaks crowd control; 2 minute cooldown."] },
	{ L["Internal cooldown"], L["A hidden pause between procs of a trinket or talent."] },
	{ L["Nameplate"], L["Name and health bar above a character or creature."] },
	{ L["Buff / debuff"], L["Helpful / harmful effect."] },
	{ L["Dispel"], L["Removing an effect with a spell."] },
	{ L["Opacity"], L["100% is fully visible, 0% is hidden."] },
	{ L["UI reload"], L["/reload: 5-10 seconds, your character stays in place."] },
	{ L["Profile"], L["A full set of settings; several characters can share one."] },
	{
		L["Play style"],
		L["A set of values for how you play; resetting a setting returns to it, not to factory values."],
	},
	{ L["Frame layout"], L["Where frames are and their sizes; stored apart from colors and texts."] },
	{ L["Game settings (CVars)"], L["Client options missing from the game menu."] },
}

local function buildTerms()
	local list = {}
	for _, term in ipairs(TERMS) do
		list[#list + 1] = { description = TERM_COLOR:format(term[1], term[2]) }
	end
	return list
end

local LINKS = {
	{ "GitHub", "https://github.com/FrostAtom/FrostAtomUI", L["Releases, source code and bug reports."] },
	{ "Telegram", "https://t.me/wow_soft", L["News and updates."] },
	{ "Discord", "https://discord.gg/ghgr7euKaM", L["Questions and discussion."] },
}

local function addLinks(list)
	list[#list + 1] = { header = L["Links"], glyph = "link" }
	for _, entry in ipairs(LINKS) do
		local url = entry[2]
		list[#list + 1] = {
			label = entry[1],
			type = "execute",
			text = L["Copy link"],
			glyph = "copy",
			func = function()
				ui.ShowCopyPopup(url)
			end,
		}
		list[#list + 1] = { description = entry[3] }
	end
	return list
end

local function buildStart()
	return addLinks({
		{
			description = L["FrostAtom UI replaces the action bars, unit frames, nameplates, chat, bags, minimap and tooltips and adds arena and battleground helpers. Everything can be changed here."],
		},
		{ label = L["Quick setup"], type = "execute", text = L["Open"], glyph = "bolt", func = open("quicksetup") },
		{ description = L["The settings asked about most, on one page."] },
		{
			label = L["Setup wizard"],
			type = "execute",
			text = L["Run the setup"],
			glyph = "wand-magic-sparkles",
			func = ui.RunSetup,
		},
		{ description = L["The same questions as at the first start; a backup of the profile is saved first."] },
		{
			label = L["Move frames"],
			type = "execute",
			text = L["Unlock frames"],
			glyph = "up-down-left-right",
			func = function()
				ui.Movers.Unlock()
			end,
		},
		{ description = L['Drag frames with the mouse; Ctrl+Z undoes a move, "Done" or combat locks them.'] },
		{
			label = L["How to move frames"],
			type = "execute",
			text = L["Show"],
			glyph = "route",
			func = function()
				ns.StartTour()
			end,
		},
		{ description = L["Four hints right on the frames in move mode."] },
		{
			label = L["Three tips"],
			type = "execute",
			text = L["Show"],
			glyph = "lightbulb",
			func = function()
				ns.ShowTips()
			end,
		},
		{ description = L["Moving spells, finding trainers and where the settings are."] },
		{
			label = L["Blizzard UI"],
			type = "execute",
			text = L["Open"],
			glyph = "eye-slash",
			func = open("blizzard"),
		},
		{ description = L["Which default Blizzard frames are hidden or kept."] },
	})
end

local function buildWhatsNew()
	local list = {
		{ header = L["What's new in %s"]:format(ui.WHATS_NEW_VERSION) },
	}
	for _, item in ipairs(ns.WhatsNew) do
		list[#list + 1] = { description = "- " .. item.text }
	end
	if #ui:GetLegacyRecommendations() > 0 then
		list[#list + 1] = {
			label = L["Recommended new values"],
			type = "execute",
			text = L["Show..."],
			glyph = "list-check",
			func = ns.ShowRecommendations,
		}
	end
	return list
end

local function diagnosticsLine()
	local version = GetAddOnMetadata("FrostAtomUI", "Version") or "?"
	local build = GetAddOnMetadata("FrostAtomUI", "X-Build") or "?"
	local clientVersion, clientBuild = GetBuildInfo()
	return L["FrostAtom UI %s (%s), settings schema %s. Client %s (%s), %s. Realm %s. Profile %s."]:format(
		version,
		build,
		tostring(ui.API.GetUIState("schemaVersion")),
		clientVersion,
		clientBuild,
		GetLocale(),
		GetRealmName(),
		ui:GetActiveProfile()
	)
end

local function buildDiagnostics()
	return {
		{ description = diagnosticsLine() },
		{
			label = L["Report for the developer"],
			type = "execute",
			text = L["Copy report"],
			glyph = "copy",
			func = function()
				ui.ShowDebugReport()
			end,
		},
		{ description = L["Versions, client, modules, other addons and the last errors, ready to copy."] },
		{
			path = "tweaks.scriptErrors",
			label = L["Show addon error windows"],
			type = "toggle",
		},
		{ description = L["The game's Lua error windows, for reports."] },
		{
			label = L["Conflicting addons"],
			type = "execute",
			text = L["Ask again"],
			glyph = "arrows-rotate",
			func = function()
				ui.ResetConflictChoices()
			end,
		},
		{ label = L["Restore game settings"], type = "execute", text = L["Open"], func = open("client") },
		{ label = L["Backups"], type = "execute", text = L["Open"], func = open("profiles", "backups") },
	}
end

local function tab(key, name, glyph, build)
	return {
		key = key,
		name = name,
		glyph = glyph,
		schema = {},
		buildSchema = build,
		signature = function()
			return tostring(ui:GetActiveProfile()) .. tostring(#ui:GetLegacyRecommendations())
		end,
	}
end

ns.RegisterPage({
	key = "help",
	name = L["Help"],
	desc = L["Answers, commands, terms and a report for the developer."],
	glyph = "circle-question",
	order = 2,
	group = "start",
	noReset = true,
	tabs = {
		tab("start", L["Getting started"], "flag-checkered", buildStart),
		tab("questions", L["Questions"], "circle-question", buildQuestions),
		tab("commands", L["Commands"], "terminal", buildCommands),
		tab("terms", L["Terms"], "book-open", buildTerms),
		tab("whatsnew", L["What's new"], "newspaper", buildWhatsNew),
		tab("diagnostics", L["Diagnostics"], "stethoscope", buildDiagnostics),
	},
})
