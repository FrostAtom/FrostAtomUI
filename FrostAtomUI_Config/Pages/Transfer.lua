local ADDON_NAME, ns = ...

local ui = FrostAtomUI
local L = ui.L
local Transfer = ui.Transfer

local WINDOW_NAME = ADDON_NAME .. "TransferImport"
local WINDOW_WIDTH, WINDOW_HEIGHT = 520, 380
local EDGE = 16
local BOX_TOP = -30
local BOX_HEIGHT = 140
local SCROLL_INSET = 6
local SCROLL_RIGHT = 27
local COLUMN_WIDTH = 244
local CHECK_LINE = 22
local ROWS = 5

local window, decoded

local function exportToggles()
	local toggles = {}
	for _, category in ipairs(Transfer.CATEGORIES) do
		toggles[#toggles + 1] = {
			label = L[category.label],
			type = "toggle",
			get = function()
				return Transfer.IsExported(category.key)
			end,
			set = function(value)
				Transfer.SetExported(category.key, value)
				ns.RefreshPage()
			end,
			desc = L[category.desc],
		}
	end
	return toggles
end

local function showExport()
	local text, err = Transfer.Export()
	if text then
		ns.ShowTextWindow(L["Export settings: %s"]:format(UnitName("player")), text)
	else
		ui.Print(err)
	end
end

local function selectedCategories()
	local selected, labels = {}, {}
	for i, category in ipairs(Transfer.CATEGORIES) do
		local check = window.checks[i]
		if check:IsEnabled() == 1 and check:GetChecked() then
			selected[category.key] = true
			labels[#labels + 1] = L[category.label]
		end
	end
	return selected, labels
end

local function updateApply()
	local _, labels = selectedCategories()
	ns.SetControlEnabled(window.apply, #labels > 0)
end

local function updateContents(text)
	local data, err
	if strtrim(text) ~= "" then
		data, err = Transfer.Decode(text)
	end
	decoded = data

	local summary = window.summary
	if data then
		summary:SetText(L["Settings of %s:"]:format(type(data.character) == "string" and data.character or "?"))
		summary:SetTextColor(1, 0.82, 0)
	elseif err then
		summary:SetText(err)
		summary:SetTextColor(1, 0.3, 0.3)
	else
		summary:SetText(L["Paste a settings string above."])
		summary:SetTextColor(0.5, 0.5, 0.5)
	end

	for i, category in ipairs(Transfer.CATEGORIES) do
		local check = window.checks[i]
		local count = data and Transfer.Count(data, category.key)
		check:SetChecked(count ~= nil)
		ns.SetControlEnabled(check, count ~= nil)
		if count then
			check.label:SetFormattedText("%s (%d)", L[category.label], count)
			check.label:SetTextColor(1, 1, 1)
		else
			check.label:SetText(L[category.label])
			check.label:SetTextColor(0.5, 0.5, 0.5)
		end
	end
	updateApply()
end

local function apply()
	local data = decoded
	local selected, labels = selectedCategories()
	if not data or #labels == 0 then
		return
	end
	local from = type(data.character) == "string" and data.character or "?"
	ns.Confirm(
		L["Apply settings of %s: %s? Current settings in these categories are replaced."]:format(
			from,
			table.concat(labels, ", ")
		),
		function()
			if Transfer.Import(data, selected) then
				window:Hide()
				ns.ShowReloadButton()
				ui.Print(L["reload the UI to apply everything"])
			end
		end
	)
end

local function createCheck(index, category)
	local check = ns.CreateCheckButton(window, "InterfaceOptionsSmallCheckButtonTemplate")
	local column, row = floor((index - 1) / ROWS), (index - 1) % ROWS
	check:SetPoint("TOPLEFT", window.summary, "BOTTOMLEFT", column * COLUMN_WIDTH - 4, -4 - row * CHECK_LINE)
	local label = _G[check:GetName() .. "Text"]
	label:SetFontObject(ns.Font("GameFontHighlightSmall"))
	check:SetHitRectInsets(0, -(COLUMN_WIDTH - check:GetWidth() - 8), 0, 0)
	check.label = label
	check:SetScript("OnClick", function(self)
		ns.PlayCheckSound(self)
		updateApply()
	end)
	check:SetScript("OnEnter", function(self)
		ns.ShowTooltip(self, L[category.label], L[category.desc])
	end)
	check:SetScript("OnLeave", GameTooltip_Hide)
	return check
end

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
	window.heading:SetText(L["Import settings"])

	local close = ns.CreateButton(window, L["Close"], 96)
	close:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	close:SetScript("OnClick", function()
		window:Hide()
	end)

	local applyButton = ns.CreateButton(window, L["Apply"], 96)
	applyButton:SetPoint("RIGHT", close, "LEFT", -4, 0)
	applyButton:SetScript("OnClick", apply)
	window.apply = applyButton

	local inset = ui.CreateInset(window, "tooltip")
	inset:SetBackdropBorderColor(0.6, 0.6, 0.6)
	inset:SetPoint("TOPLEFT", EDGE, BOX_TOP)
	inset:SetPoint("TOPRIGHT", -EDGE, BOX_TOP)
	inset:SetHeight(BOX_HEIGHT)

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
	box:SetScript("OnTextChanged", function(self)
		scroll:UpdateScrollChildRect()
		updateContents(self:GetText())
	end)
	scroll:SetScrollChild(box)
	scroll:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	window.box = box

	local summary = window:CreateFontString(nil, "ARTWORK")
	summary:SetFontObject(ns.Font("GameFontNormal"))
	summary:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 4, -10)
	summary:SetPoint("RIGHT", -EDGE, 0)
	summary:SetJustifyH("LEFT")
	window.summary = summary

	window.checks = {}
	for i, category in ipairs(Transfer.CATEGORIES) do
		window.checks[i] = createCheck(i, category)
	end
end

local function showImport()
	if not window then
		createWindow()
	end
	ns.HideTextWindow()
	window.box:SetText("")
	updateContents("")
	window:Show()
	window.box:SetFocus()
end

local toggles = exportToggles()

local schema = {
	{
		description = L["Moves game settings to another account or character as a text string, like a profile: macros, action bars, key bindings, game options, chat windows, friends."],
	},
	{
		header = L["What to copy"],
		glyph = "file-export",
		toggles = toggles,
		toggleDesc = L["Select or clear every category."],
	},
}
for _, toggle in ipairs(toggles) do
	schema[#schema + 1] = toggle
end
schema[#schema + 1] = {
	label = L["Export"],
	type = "execute",
	text = L["Export"],
	glyph = "file-export",
	func = showExport,
	desc = L["Show the selected settings of this character as a string to copy."],
}
schema[#schema + 1] = { header = L["Import"], glyph = "file-import" }
schema[#schema + 1] = {
	label = L["Settings string"],
	type = "execute",
	text = L["Import"],
	glyph = "file-import",
	func = showImport,
	desc = L["Paste a settings string, see what it contains and choose what to apply. Each applied category replaces the current settings of this category."],
}

ns.RegisterPage({
	key = "transfer",
	name = L["Transfer"],
	glyph = "arrow-right-arrow-left",
	new = "1.4.1",
	order = 88,
	group = "system",
	schema = schema,
	noReset = true,
})
