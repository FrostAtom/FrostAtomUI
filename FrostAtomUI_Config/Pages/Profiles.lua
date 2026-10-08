local ADDON_NAME, ns = ...

local ui = FrostAtomUI
local L = ui.L

local WINDOW_NAME = ADDON_NAME .. "ProfileText"
local WINDOW_WIDTH, WINDOW_HEIGHT = 520, 320
local EDGE = 16
local BOX_TOP = -30
local BOX_BOTTOM = 46
local SCROLL_INSET = 6
local SCROLL_RIGHT = 27

local window

local function createWindow()
	window = ns.CreateWindow(WINDOW_NAME, {
		width = WINDOW_WIDTH,
		height = WINDOW_HEIGHT,
		header = true,
		strata = "FULLSCREEN_DIALOG",
		noClose = true,
		movable = false,
	})
	window:SetPoint("CENTER")

	local close = ns.CreateButton(window, L["Close"], 96)
	close:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	close:SetScript("OnClick", function()
		window:Hide()
	end)

	local action = ns.CreateButton(window, L["Import"], 96)
	action:SetPoint("RIGHT", close, "LEFT", -4, 0)
	window.action = action

	local inset = ui.CreateInset(window, "tooltip")
	inset:SetBackdropBorderColor(0.6, 0.6, 0.6)
	inset:SetPoint("TOPLEFT", EDGE, BOX_TOP)
	inset:SetPoint("BOTTOMRIGHT", -EDGE, BOX_BOTTOM)

	local scroll = CreateFrame("ScrollFrame", WINDOW_NAME .. "Scroll", inset, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", SCROLL_INSET, -SCROLL_INSET)
	scroll:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT, SCROLL_INSET)

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetMaxLetters(0)
	box:SetWidth(WINDOW_WIDTH - EDGE * 2 - SCROLL_INSET - SCROLL_RIGHT)
	box:SetTextInsets(2, 2, 2, 2)
	box:SetFontObject(ChatFontNormal)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnEditFocusGained", function()
		if window.readOnly then
			box:HighlightText()
		end
	end)
	box:SetScript("OnTextChanged", function()
		if window.readOnly and box:GetText() ~= window.readOnly then
			box:SetText(window.readOnly)
			box:HighlightText()
		end
		scroll:UpdateScrollChildRect()
	end)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	window.box = box
end

local function prepareWindow(heading)
	if not window then
		createWindow()
	end
	window.heading:SetText(heading)
end

local function showTextWindow(heading, text)
	prepareWindow(heading)
	window.action:Hide()
	window.readOnly = nil
	window.box:SetText(text)
	window.readOnly = window.box:GetText()
	window.box:ClearFocus()
	window.box:SetCursorPosition(0)
	window:Show()
end

local function showImportWindow(heading, onImport)
	prepareWindow(heading)
	window.readOnly = nil
	window.action:Show()
	window.action:SetScript("OnClick", function()
		onImport(window.box:GetText())
	end)
	window.box:SetText("")
	window:Show()
	window.box:SetFocus()
end

ns.ShowTextWindow = showTextWindow
ns.ShowImportWindow = showImportWindow

local function showExport()
	showTextWindow(L["Export profile: %s"]:format(ui:GetActiveProfile()), ui:ExportProfile())
end

local function showExportMine()
	showTextWindow(L["Export profile: %s"]:format(ui:GetActiveProfile()), ui:ExportProfile(true))
end

local CATEGORIES = {
	{ key = "general", label = L["General and look"], sections = { "general", "cooldownTimer", "tooltip" } },
	{
		key = "unitFrames",
		label = L["Unit frames"],
		sections = {
			"unitFrames",
			"raidFrames",
			"playerPlate",
			"shieldIndicator",
			"runes",
			"totems",
			"temporaryEnchant",
			"experienceBar",
		},
	},
	{ key = "namePlates", label = L["Nameplates"], sections = { "namePlates" } },
	{ key = "actionBar", label = L["Action bars"], sections = { "actionBar", "wheelPaging" } },
	{
		key = "pvp",
		label = L["PvP and alerts"],
		sections = {
			"trackers",
			"loseControl",
			"lossOfControl",
			"externalDefensives",
			"soundAlerts",
			"spellAlerts",
			"announce",
			"arenaTrinket",
			"groupCooldowns",
			"diminishingReturns",
			"internalCooldowns",
			"arenaUnseen",
			"arena",
			"battleground",
			"matchResults",
			"queueInvite",
			"soloQueue",
			"arenaHistory",
			"deathRecap",
			"combatAlert",
			"queuePopFlash",
			"lowHealthFlash",
			"dispelHighlightAlpha",
			"dispelHighlightMode",
		},
	},
	{ key = "chat", label = L["Chat, map and bags"], sections = { "chat", "minimap", "worldMap", "bags" } },
	{ key = "other", label = L["Everything else"] },
	{ key = "positions", label = L["Frame positions"] },
	{ key = "scale", label = L["UI scale from the other screen"], off = true },
}

local POINTS = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}
local SCALE_KEYS = { uiScaleMode = true, uiScale = true }

local sectionCategory = {}
for _, category in ipairs(CATEGORIES) do
	for _, section in ipairs(category.sections or {}) do
		sectionCategory[section] = category.key
	end
end

local function isPoint(value)
	return type(value) == "table" and POINTS[value[1]] ~= nil
end

local function isSection(value)
	return type(value) == "table" and value[1] == nil
end

local function clone(value)
	return type(value) == "table" and CopyTable(value) or value
end

local function choose(take, theirs, mine)
	if take then
		return clone(theirs)
	end
	return clone(mine)
end

local function pick(current, imported, settings, points)
	local result, any = {}, false
	local keys = {}
	for key in pairs(current or {}) do
		keys[key] = true
	end
	for key in pairs(imported or {}) do
		keys[key] = true
	end
	for key in pairs(keys) do
		local mine, theirs = current and current[key], imported and imported[key]
		local value
		if isPoint(mine) or isPoint(theirs) then
			value = choose(points, theirs, mine)
		elseif (isSection(mine) or mine == nil) and (isSection(theirs) or theirs == nil) then
			value = pick(mine, theirs, settings, points)
		else
			value = choose(settings, theirs, mine)
		end
		result[key] = value
		any = any or value ~= nil
	end
	return any and result or nil
end

local function countValues(node)
	local settings, positions = 0, 0
	for _, value in pairs(node or {}) do
		if isPoint(value) then
			positions = positions + 1
		elseif isSection(value) then
			local s, p = countValues(value)
			settings, positions = settings + s, positions + p
		else
			settings = settings + 1
		end
	end
	return settings, positions
end

local function categoryOf(section)
	return sectionCategory[section] or "other"
end

local function combine(current, imported, chosen)
	local result = {}
	local sections = {}
	for key in pairs(current or {}) do
		sections[key] = true
	end
	for key in pairs(imported or {}) do
		sections[key] = true
	end
	sections.baseline = nil
	for section in pairs(sections) do
		local mine, theirs = current and current[section], imported and imported[section]
		local settings = chosen[categoryOf(section)]
		if isSection(mine) or isSection(theirs) then
			result[section] =
				pick(isSection(mine) and mine or nil, isSection(theirs) and theirs or nil, settings, chosen.positions)
		else
			result[section] = choose(settings, theirs, mine)
		end
	end
	local general = result.general or {}
	for key in pairs(SCALE_KEYS) do
		local mine = current and current.general and current.general[key]
		local theirs = imported and imported.general and imported.general[key]
		general[key] = choose(chosen.scale, theirs, mine)
	end
	result.general = next(general) and general or nil
	return result
end

local function merged(current, imported, chosen)
	local result = combine(current, imported, chosen)
	local baseline = combine(current and current.baseline, imported and imported.baseline, chosen)
	result.baseline = next(baseline) and baseline or nil
	return result
end

local importWindow

local function importCounts(profile)
	local counts = {}
	for section, value in pairs(profile) do
		if section ~= "baseline" then
			local key = categoryOf(section)
			local settings, positions = 1, 0
			if isSection(value) then
				settings, positions = countValues(value)
			end
			if section == "general" and isSection(value) then
				for scaleKey in pairs(SCALE_KEYS) do
					if value[scaleKey] ~= nil then
						settings = settings - 1
						counts.scale = (counts.scale or 0) + 1
					end
				end
			end
			counts[key] = (counts[key] or 0) + settings
			counts.positions = (counts.positions or 0) + positions
		end
	end
	return counts
end

local function importedValue(profile, path)
	local section, key = strsplit(".", path)
	for _, layer in ipairs({ profile, profile.baseline }) do
		local values = isSection(layer) and layer[section]
		if isSection(values) and values[key] ~= nil then
			return values[key]
		end
	end
	return ui:GetFactoryConfig(path)
end

local function noBarsWarning(profile)
	if importedValue(profile, "actionBar.enabled") == false and importedValue(profile, "hideBlizzard.actionBars") then
		return "\n|cffff8000"
			.. L["The string turns off FrostAtom UI action bars and hides Blizzard's: without another action bar addon you will have no bars."]
			.. "|r"
	end
	return ""
end

local function updateImport()
	local w = importWindow
	local text = strtrim(w.box:GetText())
	w.profile = nil
	local status
	if text == "" then
		status = L["Paste a profile string above."]
	elseif text:sub(1, 7) == "FAUIL1:" then
		status = L["This is a layout string: import it on the Layouts page."]
	elseif text:sub(1, 7) == "FAUIT1:" then
		status = L["This is a game settings string: import it on the Transfer page."]
	else
		local profile, message = ui:DecodeProfile(text)
		if profile then
			w.profile = profile
			status = (message or L["A FrostAtom UI profile. Choose what to take."]) .. noBarsWarning(profile)
		else
			status = L["import failed: %s"]:format(message or "?")
		end
	end
	w.status:SetText(status)
	local counts = w.profile and importCounts(w.profile) or {}
	if w.profile and isSection(w.profile.baseline) then
		for key, count in pairs(importCounts(w.profile.baseline)) do
			counts[key] = (counts[key] or 0) + count
		end
	end
	for _, check in ipairs(w.checks) do
		local category = check.category
		local count = counts[category.key] or 0
		check:SetLabel(("%s (%d)"):format(category.label, count))
		ns.SetControlEnabled(check, count > 0)
		check:SetChecked(count > 0 and not category.off)
	end
	ns.SetControlEnabled(w.accept, w.profile ~= nil)
end

local function chosenCategories()
	local chosen, any = {}, false
	for _, check in ipairs(importWindow.checks) do
		if check:IsEnabled() == 1 and check:GetChecked() then
			chosen[check.category.key] = true
			any = true
		end
	end
	return chosen, any
end

local function applyImport()
	local w = importWindow
	local chosen, any = chosenCategories()
	if not w.profile or not any then
		return
	end
	if w.toNew:GetChecked() then
		local name = strtrim(w.name:GetText())
		if name == "" or tContains(ui:GetProfileNames(), name) then
			ui.Print(L["choose a name that no profile has yet"])
			return
		end
		if ui:NewProfile(name, true, merged(nil, w.profile, chosen)) then
			w:Hide()
			ui.Print(L["profile %q created from the string"], name)
		end
		return
	end
	ns.Confirm(
		L["Replace the chosen settings of the active profile with the imported ones? A backup is saved first."],
		function()
			ui:ReplaceProfile(merged(ui.ConfigStore.readAll(), w.profile, chosen))
			w:Hide()
			ui.Print(L["profile imported"])
		end
	)
end

local function createImportWindow()
	local w = ns.CreateWindow(ADDON_NAME .. "ProfileImport", {
		width = WINDOW_WIDTH,
		height = 470,
		header = true,
		strata = "FULLSCREEN_DIALOG",
		noClose = true,
		movable = false,
	})
	w:SetPoint("CENTER")
	w.heading:SetText(L["Import profile"])
	local shade = w:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(0, 0, 0, 0.92)
	shade:SetPoint("TOPLEFT", 4, -4)
	shade:SetPoint("BOTTOMRIGHT", -4, 4)
	importWindow = w

	local inset = ui.CreateInset(w, "tooltip")
	inset:SetBackdropBorderColor(0.6, 0.6, 0.6)
	inset:SetPoint("TOPLEFT", EDGE, BOX_TOP)
	inset:SetPoint("TOPRIGHT", -EDGE, BOX_TOP)
	inset:SetHeight(90)
	local scroll = CreateFrame("ScrollFrame", ADDON_NAME .. "ProfileImportScroll", inset, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", SCROLL_INSET, -SCROLL_INSET)
	scroll:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT, SCROLL_INSET)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetMaxLetters(0)
	box:SetWidth(WINDOW_WIDTH - EDGE * 2 - SCROLL_INSET - SCROLL_RIGHT)
	box:SetTextInsets(2, 2, 2, 2)
	box:SetFontObject(ChatFontNormal)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnTextChanged", function()
		scroll:UpdateScrollChildRect()
		updateImport()
	end)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	w.box = box

	local status = w:CreateFontString(nil, "ARTWORK")
	status:SetFontObject(ns.Font("GameFontNormal"))
	status:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 4, -10)
	status:SetPoint("RIGHT", -EDGE, 0)
	status:SetJustifyH("LEFT")
	w.status = status

	local toNew = ui.CreateCheckButton(w, L["Into a new profile:"], nil, true)
	toNew:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -4, -8)
	local name = ui.CreateEditBox(w, 160, 20)
	name:SetPoint("LEFT", toNew.text, "RIGHT", 10, 0)
	name:SetMaxLetters(32)
	w.name = name
	local toCurrent = ui.CreateCheckButton(w, "", nil, true)
	toCurrent:SetPoint("TOPLEFT", toNew, "BOTTOMLEFT", 0, -2)
	toNew:SetScript("OnClick", function()
		toNew:SetChecked(true)
		toCurrent:SetChecked(false)
	end)
	toCurrent:SetScript("OnClick", function()
		toCurrent:SetChecked(true)
		toNew:SetChecked(false)
	end)
	w.toNew, w.toCurrent = toNew, toCurrent

	w.checks = {}
	for index, category in ipairs(CATEGORIES) do
		local check = ui.CreateCheckButton(w, category.label, nil, true)
		local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
		check:SetPoint("TOPLEFT", toCurrent, "BOTTOMLEFT", column * 240, -10 - row * 22)
		check.category = category
		w.checks[index] = check
	end

	local close = ns.CreateButton(w, CANCEL, 96)
	close:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	close:SetScript("OnClick", function()
		w:Hide()
	end)
	local accept = ns.CreateButton(w, L["Import"], 96)
	accept:SetPoint("RIGHT", close, "LEFT", -4, 0)
	accept:SetScript("OnClick", applyImport)
	w.accept = accept
end

local function showImport()
	if not importWindow then
		createImportWindow()
	end
	ns.HideTextWindow()
	local w = importWindow
	w.heading:SetText(L["Import profile"])
	w.toNew:SetChecked(true)
	w.toCurrent:SetChecked(false)
	w.toCurrent:SetLabel(L['Into the active profile "%s" (replaces the chosen parts)']:format(ui:GetActiveProfile()))
	w.name:SetText(L["Imported"])
	w.box:SetText("")
	updateImport()
	w:Show()
	w.box:SetFocus()
end
ns.ShowProfileImport = showImport

local function showCopyParts(source)
	showImport()
	local w = importWindow
	w.heading:SetText(L["Take parts of a profile"])
	w.toNew:SetChecked(false)
	w.toCurrent:SetChecked(true)
	w.box:SetText(ui:ExportProfile(false, source))
	w.box:ClearFocus()
end

function ns.HideTextWindow()
	if window then
		window:Hide()
	end
end

local function profileOptions(excluded)
	local options = {}
	for _, name in ipairs(ui:GetProfileNames()) do
		if name ~= excluded then
			options[#options + 1] = { name, name }
		end
	end
	return options
end

local function otherProfileOptions()
	return profileOptions(ui:GetActiveProfile())
end

local function noOtherProfiles()
	return #otherProfileOptions() == 0
end

local function switchProfile(name)
	ui:SetProfile(name)
end

local newProfileMode = "copy"

local function uniqueName(name)
	for _, existing in ipairs(ui:GetProfileNames()) do
		if existing == name then
			return false, L["A profile with this name already exists."]
		end
	end
	return true
end

local schema = {
	{ header = L["Active profile"], glyph = "user-gear" },
	{
		description = L["Each character remembers its profile; several characters can share one."],
	},
	{
		label = L["Profile"],
		type = "select",
		values = profileOptions,
		get = function()
			return ui:GetActiveProfile()
		end,
		set = switchProfile,
		desc = L["Switch this character to another profile."],
	},
	{
		label = L["New profile starts as"],
		type = "select",
		values = {
			{ "copy", L["A copy of the active profile"] },
			{ "empty", L["Empty (FrostAtom UI's starting values)"] },
		},
		get = function()
			return newProfileMode
		end,
		set = function(value)
			newProfileMode = value
		end,
		desc = L["A copy keeps your settings, layout and frame positions; an empty profile starts from FrostAtom UI's starting values."],
	},
	{
		label = L["New profile"],
		type = "input",
		text = L["Create"],
		glyph = "plus",
		width = 160,
		maxLetters = 32,
		func = function(name)
			ui:NewProfile(name, newProfileMode == "empty")
		end,
		validate = uniqueName,
		desc = L["Type a name and press Enter to create a profile and switch to it."],
	},
	{
		label = L["Rename profile"],
		type = "input",
		text = L["Rename"],
		glyph = "pen",
		width = 160,
		maxLetters = 32,
		func = function(name)
			ui:RenameProfile(ui:GetActiveProfile(), name)
		end,
		validate = uniqueName,
		desc = L["Type a new name for the active profile and press Enter. Characters using it keep it."],
	},
	{
		label = L["Default for new characters"],
		new = "1.5.0",
		type = "select",
		values = profileOptions,
		get = function()
			return ui:GetDefaultProfile()
		end,
		set = function(name)
			ui:SetDefaultProfile(name)
		end,
		desc = L["Profile a character starts with when it has none assigned yet, including characters whose profile was deleted."],
	},
	{
		label = L["Other profiles"],
		type = "choice",
		placeholder = L["Select profile..."],
		values = otherProfileOptions,
		disabled = noOtherProfiles,
		disabledDesc = L["There are no other profiles yet."],
		actions = {
			{
				text = L["Take parts"],
				glyph = "list-check",
				desc = L["Choose which parts of another profile to take into the active one: unit frames, nameplates, positions and so on."],
				func = function(name)
					showCopyParts(name)
				end,
			},
			{
				text = L["Copy from"],
				glyph = "copy",
				desc = L["Replace all settings of the active profile with a copy of another one."],
				confirm = L["Overwrite the active profile with settings from %q?"],
				func = function(name)
					ui:CopyProfile(name)
				end,
			},
			{
				text = L["Delete profile"],
				glyph = "trash-can",
				confirm = L["Delete profile %q? Characters using it fall back to Default."],
				func = function(name)
					ui:DeleteProfile(name)
				end,
			},
		},
		desc = L["Pick another profile, then copy its settings into the active profile or delete it. The active profile cannot be deleted."],
	},
	{
		label = L["Reset profile"],
		type = "execute",
		text = L["Reset"],
		glyph = "rotate-left",
		confirm = L["Reset all settings of the active profile to defaults?"],
		func = function()
			ui.Undo.Snapshot("resetProfile")
			ui.Undo.Run(L["Reset the profile"], ui.ResetConfig, ui)
		end,
	},
	{ header = L["Import / export"], glyph = "arrow-right-arrow-left" },
	{
		label = L["Export"],
		type = "execute",
		text = L["Export"],
		glyph = "file-export",
		func = showExport,
		desc = L["Show the active profile as a string to copy."],
	},
	{
		label = L["Export only my changes"],
		type = "execute",
		text = L["Export"],
		glyph = "file-export",
		advanced = true,
		func = showExportMine,
		desc = L["Leave out values set by a layout or kept from the previous version: the string holds only what you changed yourself."],
	},
	{
		label = L["Import"],
		type = "execute",
		text = L["Import"],
		glyph = "file-import",
		func = showImport,
		desc = L["Paste a profile string, see what it holds and take it into a new profile or take chosen parts into the active one."],
	},
}

local function specProfileOptions()
	local options = { { "", L["Do not switch"] } }
	for _, option in ipairs(profileOptions()) do
		options[#options + 1] = option
	end
	return options
end

local function specProfileEntry(group)
	return {
		label = L["Talent set %d"]:format(group),
		type = "select",
		values = specProfileOptions,
		new = "1.5.0",
		get = function()
			return ui:GetSpecProfile(group) or ""
		end,
		set = function(value)
			ui:SetSpecProfile(group, value)
			ns.RefreshPage()
		end,
		desc = L["Switching to this talent set turns this profile on. The chat line offers a link back to the previous profile."],
	}
end

schema[#schema + 1] = { header = L["Profile by talent set"], glyph = "arrows-rotate", new = "1.5.0" }
schema[#schema + 1] = specProfileEntry(1)
schema[#schema + 1] = specProfileEntry(2)

ns.AddTab("profiles", { key = "profiles", order = 1, name = L["Profiles"], glyph = "address-card", schema = schema })

ns.RegisterPage({
	key = "profiles",
	name = L["Profiles & transfer"],
	desc = L["Profiles, import and export, settings from another character and backups."],
	glyph = "address-card",
	order = 90,
	group = "system",
	schema = {},
	history = true,
	noReset = true,
})
