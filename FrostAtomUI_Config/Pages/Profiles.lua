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
	box:SetScript("OnTextChanged", function()
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

local function showText(heading, text)
	prepareWindow(heading)
	window.action:Hide()
	window.box:SetText(text)
	window:Show()
	window.box:SetFocus()
	window.box:HighlightText()
end

local function showImportWindow(heading, onImport)
	prepareWindow(heading)
	window.action:Show()
	window.action:SetScript("OnClick", function()
		onImport(window.box:GetText())
	end)
	window.box:SetText("")
	window:Show()
	window.box:SetFocus()
end

local function showExport()
	showText(L["Export profile: %s"]:format(ui:GetActiveProfile()), ui:ExportProfile())
end

local function showImport()
	showImportWindow(L["Import into profile: %s"]:format(ui:GetActiveProfile()), function(text)
		ns.Confirm(L["Replace all settings of the active profile with the imported ones?"], function()
			local ok, err = ui:ImportProfile(text)
			if ok then
				window:Hide()
			else
				ui.Print(L["import failed: %s"], err)
			end
		end)
	end)
end

local function showLayoutExport(name)
	local text = ui.Movers.ExportLayout(name)
	if text then
		showText(L["Export layout: %s"]:format(name), text)
	end
end

local function showLayoutImport()
	showImportWindow(L["Import layout"], function(text)
		local ok, result = ui.Movers.ImportLayout(text)
		if ok then
			window:Hide()
			ui.Print(L["layout %q imported"], result)
			ns.RefreshPage()
		else
			ui.Print(L["import failed: %s"], result)
		end
	end)
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

local function layoutOptions()
	local options = {}
	for _, name in ipairs(ui.Movers.GetLayoutNames()) do
		options[#options + 1] = { name, name }
	end
	return options
end

local function noLayouts()
	return #ui.Movers.GetLayoutNames() == 0
end

local function saveLayout(name)
	local ok, saved = ui.Movers.SaveLayout(name)
	if ok then
		ui.Print(L["layout %q saved"], saved)
		ns.RefreshPage()
	end
end

local function loadLayout(name)
	ns.Confirm(L["Move all frames to the positions saved in layout %q?"]:format(name), function()
		ui.Movers.LoadLayout(name)
	end)
end

local function deleteLayout(name)
	ns.Confirm(L["Delete layout %q?"]:format(name), function()
		ui.Movers.DeleteLayout(name)
		ns.RefreshPage()
	end)
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
		label = L["New profile"],
		type = "string",
		width = 160,
		maxLetters = 32,
		get = function()
			return ""
		end,
		set = switchProfile,
		desc = L["Type a name and press Enter to create an empty profile and switch to it."],
	},
	{
		label = L["Default for new characters"],
		new = "1.4.1",
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
		label = L["Copy from"],
		type = "select",
		placeholder = L["Select profile..."],
		values = otherProfileOptions,
		get = function() end,
		set = function(name)
			ns.Confirm(L["Overwrite the active profile with settings from %q?"]:format(name), function()
				ui:CopyProfile(name)
			end)
		end,
		disabled = noOtherProfiles,
		desc = L["Replace all settings of the active profile with a copy of another one."],
	},
	{
		label = L["Delete profile"],
		type = "select",
		placeholder = L["Select profile..."],
		values = otherProfileOptions,
		get = function() end,
		set = function(name)
			ns.Confirm(L["Delete profile %q? Characters using it fall back to Default."]:format(name), function()
				ui:DeleteProfile(name)
			end)
		end,
		disabled = noOtherProfiles,
		desc = L["The active profile cannot be deleted."],
	},
	{
		label = L["Reset profile"],
		type = "execute",
		text = L["Reset"],
		glyph = "rotate-left",
		confirm = L["Reset all settings of the active profile to defaults?"],
		func = function()
			ui:ResetConfig()
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
		label = L["Import"],
		type = "execute",
		text = L["Import"],
		glyph = "file-import",
		func = showImport,
		desc = L["Paste a profile string to replace the active profile."],
	},
	{ header = L["Layouts"], new = "1.4.1", glyph = "layer-group" },
	{
		description = L["A layout keeps only frame positions, shared by all characters. Loading one moves the frames of the active profile and leaves every other setting alone."],
	},
	{
		label = L["Save layout"],
		new = "1.4.1",
		type = "string",
		width = 160,
		maxLetters = 32,
		get = function()
			return ""
		end,
		set = saveLayout,
		desc = L["Type a name and press Enter to save the current frame positions. An existing layout with that name is overwritten."],
	},
	{
		label = L["Load layout"],
		new = "1.4.1",
		type = "select",
		placeholder = L["Select layout..."],
		values = layoutOptions,
		get = function() end,
		set = loadLayout,
		disabled = noLayouts,
	},
	{
		label = L["Delete layout"],
		new = "1.4.1",
		type = "select",
		placeholder = L["Select layout..."],
		values = layoutOptions,
		get = function() end,
		set = deleteLayout,
		disabled = noLayouts,
	},
	{
		label = L["Export layout"],
		new = "1.4.1",
		type = "select",
		placeholder = L["Select layout..."],
		values = layoutOptions,
		get = function() end,
		set = showLayoutExport,
		disabled = noLayouts,
		desc = L["Show a layout as a string to copy."],
	},
	{
		label = L["Import layout"],
		new = "1.4.1",
		type = "execute",
		text = L["Import"],
		glyph = "file-import",
		func = showLayoutImport,
		desc = L["Paste a layout string to add it to the list."],
	},
}

ns.RegisterPage({
	key = "profiles",
	name = L["Profiles"],
	glyph = "address-card",
	order = 90,
	group = "system",
	schema = schema,
	noReset = true,
})
