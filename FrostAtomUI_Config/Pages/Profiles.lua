local ADDON_NAME, ns = ...

local L = FrostAtomUI.L

local ui = FrostAtomUI

local WINDOW_NAME = ADDON_NAME .. "ProfileText"
local WINDOW_WIDTH, WINDOW_HEIGHT = 520, 320
local PADDING = 12

local window

local function createWindow()
	window = CreateFrame("Frame", WINDOW_NAME, UIParent)
	window:Hide()
	window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	window:SetPoint("CENTER")
	window:SetFrameStrata("FULLSCREEN_DIALOG")
	window:EnableMouse(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	window:SetBackdrop(ui.CreateBackdrop(14, 3))
	window:SetBackdropColor(0, 0, 0, 0.9)
	tinsert(UISpecialFrames, WINDOW_NAME)

	local title = window:CreateFontString(nil, "OVERLAY")
	ui.SetFont(title, 13, "OUTLINE", true)
	title:SetPoint("TOPLEFT", PADDING, -PADDING - 4)
	window.title = title

	local close = ns.CreateButton(window, L["Close"], 80)
	close:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
	close:SetScript("OnClick", function()
		window:Hide()
	end)

	local action = ns.CreateButton(window, L["Import"], 80)
	action:SetPoint("RIGHT", close, "LEFT", -8, 0)
	window.action = action

	local scroll = CreateFrame("ScrollFrame", WINDOW_NAME .. "Scroll", window, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", PADDING, -PADDING - 28)
	scroll:SetPoint("BOTTOMRIGHT", -PADDING - 18, PADDING + 30)
	scroll:SetBackdrop(ui.CreateBackdrop(8))
	scroll:SetBackdropColor(0, 0, 0, 0.5)
	scroll:SetBackdropBorderColor(0.4, 0.4, 0.4)

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetMaxLetters(0)
	box:SetWidth(WINDOW_WIDTH - PADDING * 2 - 26)
	box:SetTextInsets(4, 4, 4, 4)
	ui.SetFont(box, 12)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnTextChanged", function(self)
		scroll:UpdateScrollChildRect()
	end)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	window.box = box
end

local function showExport()
	if not window then
		createWindow()
	end
	window.title:SetText(L["Export profile: %s"]:format(ui:GetActiveProfile()))
	window.action:Hide()
	window.box:SetText(ui:ExportProfile())
	window:Show()
	window.box:SetFocus()
	window.box:HighlightText()
end

local function showImport()
	if not window then
		createWindow()
	end
	window.title:SetText(L["Import into profile: %s"]:format(ui:GetActiveProfile()))
	window.action:Show()
	window.action:SetScript("OnClick", function()
		local text = window.box:GetText()
		ns.Confirm(L["Replace all settings of the active profile with the imported ones?"], function()
			local ok, err = ui:ImportProfile(text)
			if ok then
				window:Hide()
			else
				ui.Print(L["import failed: %s"], err)
			end
		end)
	end)
	window.box:SetText("")
	window:Show()
	window.box:SetFocus()
end

local function profileOptions(skipActive)
	local options = {}
	for _, name in ipairs(ui:GetProfileNames()) do
		if not skipActive or name ~= ui:GetActiveProfile() then
			options[#options + 1] = { name, name }
		end
	end
	return options
end

local function noOtherProfiles()
	return #profileOptions(true) == 0
end

local schema = {
	{ header = L["Active profile"] },
	{
		description = L["Each character remembers its profile; several characters can share one."],
	},
	{
		label = L["Profile"],
		type = "select",
		values = function()
			return profileOptions()
		end,
		get = function()
			return ui:GetActiveProfile()
		end,
		set = function(name)
			ui:SetProfile(name)
		end,
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
		set = function(name)
			ui:SetProfile(name)
		end,
		desc = L["Type a name and press Enter to create an empty profile and switch to it."],
	},
	{
		label = L["Copy from"],
		type = "select",
		placeholder = L["Select profile..."],
		values = function()
			return profileOptions(true)
		end,
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
		values = function()
			return profileOptions(true)
		end,
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
		confirm = L["Reset all settings of the active profile to defaults?"],
		func = function()
			ui:ResetConfig()
		end,
	},
	{ header = L["Import / export"] },
	{
		label = L["Export"],
		type = "execute",
		text = L["Export"],
		func = showExport,
		desc = L["Show the active profile as a string to copy."],
	},
	{
		label = L["Import"],
		type = "execute",
		text = L["Import"],
		func = showImport,
		desc = L["Paste a profile string to replace the active profile."],
	},
}

ns.RegisterPage({
	key = "profiles",
	name = L["Profiles"],
	order = 60,
	schema = schema,
	noReset = true,
})
