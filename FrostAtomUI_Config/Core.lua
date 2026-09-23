local ADDON_NAME, ns = ...

local ui = FrostAtomUI
local L = ui.L

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local tinsert, sort = tinsert, table.sort

local FRAME_NAME = ADDON_NAME .. "Frame"
local WIDTH, HEIGHT = 720, 580
local PADDING = 12
local NAV_WIDTH = 150
local NAV_BUTTON_HEIGHT = 24
local SEARCH_HEIGHT = 30
local SEARCH_DELAY = 0.2
local TITLE_HEIGHT = 32
local ROW_HEIGHT = 30
local HEADER_HEIGHT = 26
local SECTION_GAP = 10
local LABEL_WIDTH = 200
local CONTROL_X = LABEL_WIDTH + 8
local CLOSE_ICON = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"
local CLOSE_ICON_HIGHLIGHT = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight"
local DISABLED_ALPHA = 0.4
local CHILD_INDENT = 14
local NEW_COLOR = { 1, 0.82, 0 }
local REVERT_SECONDS = 8
local ELEMENT_WIDTH = 558
local ELEMENT_GAP = 8
local ELEMENT_MIN_HEIGHT = 140
local ELEMENT_MAX_HEIGHT = 560
local ELEMENT_FOOTER_HEIGHT = 28
local ELEMENT_STRATA = "FULLSCREEN"
local POPUP_STRATA = "FULLSCREEN_DIALOG"
local FONT_SIZE_MIN, FONT_SIZE_MAX = 6, 32

local ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local OUTLINES = { { "", L["None"] }, { "OUTLINE", L["Outline"] }, { "THICKOUTLINE", L["Thick outline"] } }

local pages = {}
local elements = {}
local elementsByPath = {}
local elementMatchers = {}
local elementInstances = {}
local frame
local elementFrame
local currentPage
local lastNavPage
local refreshing = false
local widgetCount = 0

local searchPage = { key = "search", name = L["Search"], schema = {}, noReset = true }

local function adoptEntries(schema, owner)
	for _, entry in ipairs(schema) do
		entry.page = owner
	end
end

function ns.RegisterPage(page)
	adoptEntries(page.schema, page)
	tinsert(pages, page)
	sort(pages, function(a, b)
		return a.order < b.order
	end)
end

function ns.RegisterElement(element)
	if element.match then
		tinsert(elementMatchers, element)
		return
	end
	element.key = "element:" .. element.path
	element.schema = element.schema or {}
	adoptEntries(element.schema, element)
	tinsert(elements, element)
	elementsByPath[element.path] = element
end

local function instantiateMatcher(matcher, path)
	local name = matcher.name
	if type(name) == "function" then
		name = name(path)
	end
	local element = {
		key = "element:" .. path,
		path = path,
		page = matcher.page,
		name = name,
		schema = matcher.build and matcher.build(path) or {},
		noReset = true,
	}
	adoptEntries(element.schema, element)
	elementInstances[path] = element
	return element
end

local function elementFor(path)
	local element = elementsByPath[path] or elementInstances[path]
	if element then
		return element
	end
	for _, matcher in ipairs(elementMatchers) do
		if path:match(matcher.match) then
			return instantiateMatcher(matcher, path)
		end
	end
	return { key = "element:" .. path, path = path, name = ui.Movers.GetLabel(path), schema = {} }
end

local function elementButton(element, page, enabledBy)
	return {
		type = "execute",
		label = element.name,
		text = L["Edit"],
		width = 100,
		desc = L["Open this frame in move mode together with its settings."],
		enabledBy = element.enabledBy or enabledBy,
		page = page,
		func = function()
			ns.EditElement(element.path)
		end,
	}
end

local function addRequirement(entry, enabledBy)
	entry.enabledBy = entry.enabledBy and { enabledBy, entry.enabledBy } or enabledBy
end
ns.AddRequirement = addRequirement

function ns.Requires(enabledBy, entries)
	for _, entry in ipairs(entries) do
		if entry.path then
			addRequirement(entry, enabledBy)
		end
	end
	return entries
end

local function prefixPaths(prefix, entries)
	for _, entry in ipairs(entries) do
		if entry.path then
			entry.path = prefix .. "." .. entry.path
		end
	end
end

function ns.ElementSchema(prefix, entries)
	prefixPaths(prefix, entries)
	return ns.Requires(prefix .. ".enabled", entries)
end

function ns.Section(schema, header, prefix, entries, hidden, new)
	if hidden then
		return schema
	end
	local enable = prefix .. ".enabled"
	prefixPaths(prefix, entries)
	schema[#schema + 1] = { header = header, new = new }
	for _, entry in ipairs(entries) do
		if entry.path ~= enable then
			addRequirement(entry, enable)
		end
		schema[#schema + 1] = entry
	end
	return schema
end

function ns.NotClass(class)
	return ui.PLAYER_CLASS ~= class
end

local function nextName()
	widgetCount = widgetCount + 1
	return FRAME_NAME .. "Widget" .. widgetCount
end

local function round(value, step)
	return floor(value / step + 0.5) * step
end

local function formatNumber(value, step)
	if step >= 1 then
		return tostring(floor(value + 0.5))
	end
	local text = ("%.2f"):format(value):gsub("0+$", "")
	return (text:gsub("%.$", ""))
end

local function setEnabledAlpha(region, enabled)
	region:SetAlpha(enabled and 1 or DISABLED_ALPHA)
end

local function setControlEnabled(control, enabled)
	if enabled then
		control:Enable()
	else
		control:Disable()
	end
end

local function setMouseEnabled(region, enabled)
	region:EnableMouse(enabled)
	setEnabledAlpha(region, enabled)
end

local function versionValue(version)
	local major, minor, patch = tostring(version or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
	if not major then
		return 0
	end
	return tonumber(major) * 1000000 + (tonumber(minor) or 0) * 1000 + (tonumber(patch) or 0)
end

local releaseValue = floor(versionValue(GetAddOnMetadata("FrostAtomUI", "Version")) / 1000) * 1000
local seenAtOpen = {}

local function seenStore()
	local db = ui.db
	db.seenNew = db.seenNew or {}
	return db.seenNew
end

local function isUnseen(new, pageKey, seen)
	if not new then
		return false
	end
	local value = versionValue(new)
	return value >= releaseValue and value > versionValue(seen[pageKey])
end

local function isNewEntry(entry)
	local page = entry.page
	return page and isUnseen(entry.new, page.key, seenAtOpen) or false
end

local function newestUnseen(page)
	local seen = seenStore()
	local newest = isUnseen(page.new, page.key, seen) and page.new or nil
	for _, entry in ipairs(page.schema) do
		if isUnseen(entry.new, page.key, seen) and versionValue(entry.new) > versionValue(newest) then
			newest = entry.new
		end
	end
	return newest
end

local function markSeen(page)
	local newest = newestUnseen(page)
	if newest then
		seenStore()[page.key] = newest
	end
end

local function addNewBadge(parent, anchor, offset)
	local badge = parent:CreateFontString(nil, "OVERLAY")
	ui.SetFont(badge, 9, "OUTLINE")
	badge:SetTextColor(unpack(NEW_COLOR))
	badge:SetText(L["NEW"])
	badge:SetPoint("LEFT", anchor, "LEFT", offset, 0)
	return badge
end

local function hasParentToggle(paths)
	if type(paths) == "table" then
		for i = 1, #paths do
			if hasParentToggle(paths[i]) then
				return true
			end
		end
		return false
	end
	return paths ~= nil and not paths:find("enabled$")
end

local function isChildEntry(entry)
	if entry.indent ~= nil then
		return entry.indent
	end
	return hasParentToggle(entry.enabledBy) or hasParentToggle(entry.enabledByAny)
end

local function showTooltip(row)
	local entry = row.entry
	if not entry.desc then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(entry.label, 1, 1, 1)
	GameTooltip:AddLine(entry.desc, nil, nil, nil, true)
	GameTooltip:Show()
end

local function createButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, 20)
	button:SetBackdrop(ui.CreateBackdrop(8))
	button:SetBackdropColor(0, 0, 0, 0.5)
	button:SetBackdropBorderColor(0.6, 0.6, 0.6)
	button:SetHighlightTexture(ui.Media.blank)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	button.text = button:CreateFontString(nil, "OVERLAY")
	ui.SetFont(button.text, 12)
	button.text:SetTextColor(0.8, 0.8, 0.8)
	button.text:SetPoint("CENTER")
	button.text:SetText(text)
	return button
end
ns.CreateButton = createButton

local function createWindow(name, strata, backgroundAlpha)
	local window = CreateFrame("Frame", name, UIParent)
	window:Hide()
	window:SetFrameStrata(strata)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	window:SetBackdrop(ui.CreateBackdrop(14, 3))
	window:SetBackdropColor(0, 0, 0, backgroundAlpha)
	tinsert(UISpecialFrames, name)

	local heading = window:CreateFontString(nil, "OVERLAY")
	ui.SetFont(heading, 13, "OUTLINE", true)
	heading:SetPoint("TOPLEFT", PADDING, -PADDING - 4)
	window.heading = heading
	return window
end
ns.CreateWindow = createWindow

local function createCloseButton(window)
	local close = CreateFrame("Button", nil, window)
	close:SetSize(26, 26)
	close:SetPoint("TOPRIGHT", -PADDING + 6, -PADDING + 6)
	close:SetNormalTexture(CLOSE_ICON)
	close:SetHighlightTexture(CLOSE_ICON_HIGHLIGHT)
	close:SetScript("OnClick", function()
		window:Hide()
	end)
end

local function createEditBox(parent, width, numeric)
	local box = CreateFrame("EditBox", nextName(), parent, "InputBoxTemplate")
	box:SetSize(width, 20)
	box:SetAutoFocus(false)
	ui.SetFont(box, 12)
	if numeric then
		box:SetMaxLetters(7)
	end
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		if self.OnCommit then
			self:OnCommit()
		end
	end)
	return box
end

local function setEditBoxEnabled(box, enabled)
	setMouseEnabled(box, enabled)
	if not enabled then
		box:ClearFocus()
	end
end

local function createDropdown(parent, width, getValues, onSelect)
	local dropdown = CreateFrame("Frame", nextName(), parent, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(dropdown, width)
	UIDropDownMenu_Initialize(dropdown, function()
		local info = UIDropDownMenu_CreateInfo()
		for _, option in ipairs(getValues()) do
			info.text = option[2]
			info.value = option[1]
			info.checked = option[1] == dropdown.selected
			info.func = function()
				onSelect(option[1])
			end
			UIDropDownMenu_AddButton(info)
		end
	end)
	dropdown.Select = function(self, value)
		self.selected = value
		UIDropDownMenu_SetSelectedValue(self, value)
		for _, option in ipairs(getValues()) do
			if option[1] == value then
				UIDropDownMenu_SetText(self, option[2])
				return
			end
		end
		UIDropDownMenu_SetText(self, tostring(value))
	end
	dropdown.SetEnabled = function(self, enabled)
		if enabled then
			UIDropDownMenu_EnableDropDown(self)
		else
			UIDropDownMenu_DisableDropDown(self)
		end
	end
	return dropdown
end

local function createCheckButton(parent, x)
	local check = CreateFrame("CheckButton", nextName(), parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("LEFT", x, 0)
	return check
end

local function createRow(parent, entry)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("LEFT", PADDING, 0)
	row:SetPoint("RIGHT", -PADDING, 0)
	row.entry = entry
	row:EnableMouse(true)
	row:SetScript("OnEnter", showTooltip)
	row:SetScript("OnLeave", GameTooltip_Hide)

	local indent = isChildEntry(entry) and CHILD_INDENT or 0
	local label = row:CreateFontString(nil, "OVERLAY")
	ui.SetFont(label, 12)
	label:SetTextColor(0.85, 0.85, 0.85)
	label:SetPoint("LEFT", indent, 0)
	label:SetWidth(LABEL_WIDTH - indent)
	label:SetJustifyH("LEFT")
	label:SetText(entry.label)
	row.label = label

	if isNewEntry(entry) then
		addNewBadge(row, label, min(label:GetStringWidth(), LABEL_WIDTH - indent) + 4)
	end
	return row
end

local function get(entry)
	if entry.get then
		return entry.get()
	end
	return ui:GetConfig(entry.path)
end

local function applyValue(entry, value)
	if entry.set then
		entry.set(value)
	else
		ui:SetConfig(entry.path, value)
	end
end

local revertEntry, revertValue

local function revertText(seconds)
	return L["Keep these settings? Reverting in %d s."]:format(seconds)
end

StaticPopupDialogs["FROSTATOMUI_CONFIG_REVERT"] = {
	text = "%s",
	button1 = L["Keep"],
	button2 = L["Revert"],
	OnAccept = function()
		revertEntry, revertValue = nil, nil
	end,
	OnUpdate = function(dialog)
		_G[dialog:GetName() .. "Text"]:SetText(revertText(ceil(dialog.timeleft)))
	end,
	OnHide = function()
		local entry, value = revertEntry, revertValue
		revertEntry, revertValue = nil, nil
		if entry then
			applyValue(entry, value)
		end
	end,
	timeout = REVERT_SECONDS,
	whileDead = 1,
	hideOnEscape = 1,
}

local function confirmRevert(entry, previous)
	local name = StaticPopup_Visible("FROSTATOMUI_CONFIG_REVERT")
	if name and revertEntry == entry then
		_G[name].timeleft = REVERT_SECONDS
		return
	end
	if name then
		revertEntry = nil
		StaticPopup_Hide("FROSTATOMUI_CONFIG_REVERT")
	end
	revertEntry, revertValue = entry, previous
	StaticPopup_Show("FROSTATOMUI_CONFIG_REVERT", revertText(REVERT_SECONDS))
end

local function set(entry, value)
	local previous = get(entry)
	if previous == value then
		return
	end
	if entry.confirmRevert then
		confirmRevert(entry, type(previous) == "table" and CopyTable(previous) or previous)
	end
	if entry.set then
		entry.set(value)
		return
	end
	ui:SetConfig(entry.path, value)
	if entry.reload then
		if frame then
			frame.reloadButton:Show()
		end
		if entry.type == "toggle" then
			ns.Confirm(L["This change takes effect after a UI reload. Reload now?"], ReloadUI)
		end
	end
end

local function createSliderBox(row, entry, sliderWidth, boxWidth, boxGap, showRange)
	local slider = CreateFrame("Slider", nextName(), row, "OptionsSliderTemplate")
	slider:SetPoint("LEFT", CONTROL_X, 0)
	slider:SetWidth(sliderWidth)
	slider:SetMinMaxValues(entry.min, entry.max)
	slider:SetValueStep(entry.step)
	local sliderName = slider:GetName()
	_G[sliderName .. "Low"]:SetText(showRange and formatNumber(entry.min, entry.step) or "")
	_G[sliderName .. "High"]:SetText(showRange and formatNumber(entry.max, entry.step) or "")
	_G[sliderName .. "Text"]:SetText("")

	local box = createEditBox(row, boxWidth, true)
	box:SetPoint("LEFT", slider, "RIGHT", boxGap, 0)

	local function commit(value)
		set(entry, round(max(entry.min, min(entry.max, value)), entry.step))
	end

	slider:SetScript("OnValueChanged", function(_, value)
		if not refreshing then
			commit(value)
		end
	end)
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		if self:IsEnabled() then
			commit(self:GetValue() + delta * entry.step)
		end
	end)
	box.OnCommit = function(self)
		local value = tonumber(self:GetText())
		if value then
			commit(value)
		else
			row.Refresh()
		end
	end

	local function refresh()
		local value = get(entry)
		slider:SetValue(value)
		box:SetText(formatNumber(value, entry.step))
		box:SetCursorPosition(0)
	end
	local function setEnabled(enabled)
		setControlEnabled(slider, enabled)
		setEditBoxEnabled(box, enabled)
	end
	return box, refresh, setEnabled
end

local creators = {}

function creators.header(parent, entry)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(HEADER_HEIGHT)
	header:SetPoint("LEFT", PADDING, 0)
	header:SetPoint("RIGHT", -PADDING, 0)

	local label = header:CreateFontString(nil, "OVERLAY")
	ui.SetFont(label, 13, "OUTLINE", true)
	label:SetPoint("BOTTOMLEFT", 0, 4)
	label:SetText(entry.header)
	if isNewEntry(entry) then
		addNewBadge(header, label, label:GetStringWidth() + 6)
	end

	local line = header:CreateTexture(nil, "ARTWORK")
	line:SetTexture(1, 1, 1, 0.15)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	return header
end

function creators.description(parent, entry)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("LEFT", PADDING, 0)
	holder:SetPoint("RIGHT", -PADDING, 0)

	local text = holder:CreateFontString(nil, "OVERLAY")
	ui.SetFont(text, 12)
	text:SetTextColor(0.6, 0.6, 0.6)
	text:SetPoint("TOPLEFT", 0, -4)
	text:SetWidth(parent:GetWidth() - PADDING * 2)
	text:SetJustifyH("LEFT")
	text:SetText(entry.description)
	holder:SetHeight(text:GetStringHeight() + 12)
	return holder
end

function creators.toggle(parent, entry)
	local row = createRow(parent, entry)

	local check = createCheckButton(row, CONTROL_X - 4)
	check:SetScript("OnClick", function(self)
		set(entry, self:GetChecked() and true or false)
	end)

	row.Refresh = function()
		check:SetChecked(get(entry))
	end
	row.SetEnabled = function(_, enabled)
		setControlEnabled(check, enabled)
	end
	return row
end

function creators.number(parent, entry)
	local row = createRow(parent, entry)
	local _, refresh, setEnabled = createSliderBox(row, entry, 180, 54, 16, true)
	row.Refresh = refresh
	row.SetEnabled = function(_, enabled)
		setEnabled(enabled)
	end
	return row
end

function creators.string(parent, entry)
	local row = createRow(parent, entry)
	local box = createEditBox(row, entry.width or 200)
	box:SetPoint("LEFT", CONTROL_X, 0)
	box:SetMaxLetters(entry.maxLetters or 24)
	box.OnCommit = function(self)
		set(entry, self:GetText())
	end
	row.Refresh = function()
		box:SetText(get(entry) or "")
		box:SetCursorPosition(0)
	end
	row.SetEnabled = function(_, enabled)
		setEditBoxEnabled(box, enabled)
	end
	return row
end

function creators.select(parent, entry)
	local row = createRow(parent, entry)
	local values = entry.values
	local getValues = type(values) == "function" and values or function()
		return values
	end
	local dropdown = createDropdown(row, entry.width or 140, getValues, function(value)
		set(entry, value)
	end)
	dropdown:SetPoint("LEFT", CONTROL_X - 20, -2)

	row.Refresh = function()
		local value = get(entry)
		dropdown:Select(value)
		if value == nil then
			UIDropDownMenu_SetText(dropdown, entry.placeholder or "")
		end
	end
	row.SetEnabled = function(_, enabled)
		dropdown:SetEnabled(enabled)
	end
	return row
end

function creators.multiselect(parent, entry)
	local row = createRow(parent, entry)
	local checks = {}
	local x = CONTROL_X - 4
	for i, option in ipairs(entry.values) do
		local check = createCheckButton(row, x)
		local label = check:CreateFontString(nil, "OVERLAY")
		ui.SetFont(label, 12)
		label:SetTextColor(0.85, 0.85, 0.85)
		label:SetPoint("LEFT", check, "RIGHT", 0, 0)
		label:SetText(option[2])
		check.label = label
		check:SetScript("OnClick", function(self)
			ui:SetConfig(entry.path .. "." .. option[1], self:GetChecked() and true or false)
		end)
		checks[i] = check
		x = x + 24 + label:GetStringWidth() + 10
	end

	row.Refresh = function()
		local value = get(entry)
		for i, check in ipairs(checks) do
			check:SetChecked(value[entry.values[i][1]])
		end
	end
	row.SetEnabled = function(_, enabled)
		for _, check in ipairs(checks) do
			setControlEnabled(check, enabled)
			setEnabledAlpha(check.label, enabled)
		end
	end
	return row
end

function creators.font(parent, entry)
	local row = createRow(parent, entry)
	local sizeEntry = { path = entry.path .. ".size", min = FONT_SIZE_MIN, max = FONT_SIZE_MAX, step = 1 }
	local outlineEntry = { path = entry.path .. ".outline" }

	local box, refreshSize, setSizeEnabled = createSliderBox(row, sizeEntry, 120, 40, 10, false)

	local dropdown = createDropdown(row, 100, function()
		return OUTLINES
	end, function(value)
		set(outlineEntry, value)
	end)
	dropdown:SetPoint("LEFT", box, "RIGHT", -6, -2)

	row.Refresh = function()
		refreshSize()
		dropdown:Select(get(outlineEntry) or "")
	end
	row.SetEnabled = function(_, enabled)
		setSizeEnabled(enabled)
		dropdown:SetEnabled(enabled)
	end
	return row
end

function creators.color(parent, entry)
	local row = createRow(parent, entry)

	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(20, 20)
	swatch:SetPoint("LEFT", CONTROL_X, 0)
	swatch:SetBackdrop(ui.CreateBackdrop(8))
	swatch:SetBackdropBorderColor(0.6, 0.6, 0.6)
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	fill:SetTexture(ui.Media.blank)
	fill:SetPoint("TOPLEFT", 3, -3)
	fill:SetPoint("BOTTOMRIGHT", -3, 3)

	local hex = row:CreateFontString(nil, "OVERLAY")
	ui.SetFont(hex, 12)
	hex:SetTextColor(0.6, 0.6, 0.6)
	hex:SetPoint("LEFT", swatch, "RIGHT", 8, 0)

	local function current()
		local color = get(entry)
		return color[1], color[2], color[3], color[4] or 1
	end

	local function apply(r, g, b, a)
		local color = get(entry)
		if r ~= color[1] or g ~= color[2] or b ~= color[3] or (entry.alpha and a ~= (color[4] or 1)) then
			ui:SetConfig(entry.path, entry.alpha and { r, g, b, a } or { r, g, b })
		end
	end

	swatch:SetScript("OnClick", function()
		local r, g, b, a = current()
		ColorPickerFrame.hasOpacity = entry.alpha and true or false
		ColorPickerFrame.opacity = 1 - a
		ColorPickerFrame.previousValues = { r, g, b, a }
		ColorPickerFrame.func = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			apply(nr, ng, nb, entry.alpha and 1 - OpacitySliderFrame:GetValue() or 1)
		end
		ColorPickerFrame.opacityFunc = ColorPickerFrame.func
		ColorPickerFrame.cancelFunc = function(previous)
			apply(previous[1], previous[2], previous[3], previous[4])
		end
		ColorPickerFrame:SetColorRGB(r, g, b)
		ColorPickerFrame:SetFrameStrata(POPUP_STRATA)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)

	local reset = createButton(row, L["Default"], 60)
	reset:SetPoint("LEFT", hex, "RIGHT", 12, 0)
	reset:SetScript("OnClick", function()
		ui:ResetConfig(entry.path)
	end)

	row.Refresh = function()
		local r, g, b, a = current()
		fill:SetVertexColor(r, g, b, a)
		hex:SetText(("%02x%02x%02x"):format(r * 255, g * 255, b * 255))
		ui.SetShown(reset, not ui:IsDefaultConfig(entry.path))
	end
	row.SetEnabled = function(_, enabled)
		setMouseEnabled(swatch, enabled)
		setMouseEnabled(reset, enabled)
	end
	return row
end

local function anchorOptions()
	local options = {}
	for i = 1, #ANCHORS do
		options[i] = { ANCHORS[i], ANCHORS[i] }
	end
	return options
end

function creators.point(parent, entry)
	local row = createRow(parent, entry)
	local dropdown, commit

	dropdown = createDropdown(row, 100, anchorOptions, function(anchor)
		dropdown.selected = anchor
		commit()
	end)
	dropdown:SetPoint("LEFT", CONTROL_X - 20, -2)

	local xBox = createEditBox(row, 54, true)
	xBox:SetPoint("LEFT", dropdown, "RIGHT", 4, 2)
	local yBox = createEditBox(row, 54, true)
	yBox:SetPoint("LEFT", xBox, "RIGHT", 10, 0)

	local anchor = row:CreateFontString(nil, "OVERLAY")
	ui.SetFont(anchor, 11)
	anchor:SetTextColor(0.4, 1, 0.5)
	anchor:SetWidth(LABEL_WIDTH - 70)
	anchor:SetJustifyH("RIGHT")
	anchor:SetPoint("RIGHT", row, "LEFT", CONTROL_X - 26, 0)

	local detach = createButton(row, "x", 20)
	detach:SetPoint("LEFT", yBox, "RIGHT", 8, 0)
	detach:SetScript("OnClick", function()
		ui.Movers.Detach(entry.path)
		row.Refresh()
	end)
	detach:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(L["Detach"], 1, 1, 1)
		GameTooltip:AddLine(anchor.tooltip or "", 0.6, 0.6, 0.6, true)
		GameTooltip:Show()
	end)
	detach:SetScript("OnLeave", GameTooltip_Hide)

	commit = function()
		local x, y = tonumber(xBox:GetText()), tonumber(yBox:GetText())
		if not x or not y then
			row.Refresh()
			return
		end
		x, y = floor(x + 0.5), floor(y + 0.5)
		local point = dropdown.selected
		local value = get(entry)
		if point ~= value[1] or x ~= value[2] or y ~= value[3] then
			ui:SetConfig(entry.path, { point, x, y, value[4], value[5] })
		end
	end
	xBox.OnCommit = commit
	yBox.OnCommit = commit

	row.Refresh = function()
		local point, x, y, anchorPath, anchorPoint = unpack(get(entry))
		dropdown:Select(point)
		xBox:SetText(tostring(x))
		yBox:SetText(tostring(y))
		xBox:SetCursorPosition(0)
		yBox:SetCursorPosition(0)
		if anchorPath then
			local anchorLabel = ui.Movers.GetLabel(anchorPath)
			anchor:SetText(L["of %s"]:format(anchorLabel))
			anchor.tooltip = L["Offsets are relative to %s %s."]:format(anchorLabel, anchorPoint)
			detach:Show()
		else
			anchor:SetText("")
			detach:Hide()
		end
	end
	row.SetEnabled = function(_, enabled)
		dropdown:SetEnabled(enabled)
		setEditBoxEnabled(xBox, enabled)
		setEditBoxEnabled(yBox, enabled)
		setMouseEnabled(detach, enabled)
	end
	return row
end

function creators.execute(parent, entry)
	local row = createRow(parent, entry)
	local button = createButton(row, entry.text or entry.label, entry.width or 140)
	button:SetPoint("LEFT", CONTROL_X, 0)
	button:SetScript("OnClick", function()
		if entry.confirm then
			ns.Confirm(entry.confirm, entry.func)
		else
			entry.func()
		end
	end)
	row.Refresh = function() end
	row.SetEnabled = function(_, enabled)
		setMouseEnabled(button, enabled)
	end
	return row
end

function creators.custom(parent, entry)
	local row = createRow(parent, entry)
	if entry.height then
		row:SetHeight(entry.height)
	end
	entry.build(row)
	row.Refresh = function()
		if entry.refresh then
			entry.refresh(row)
		end
	end
	row.SetEnabled = function(_, enabled)
		if entry.setEnabled then
			entry.setEnabled(row, enabled)
		end
	end
	return row
end

local function expandSchema(page)
	local schema = {}
	local source = page.schema
	if page.buildSchema then
		source = page.buildSchema()
		page.lastSignature = page.signature()
		adoptEntries(source, page)
	end
	for _, entry in ipairs(source) do
		if entry.type == "elements" then
			for _, element in ipairs(elements) do
				if element.page == page.key and not element.hidden then
					schema[#schema + 1] = elementButton(element, page, entry.enabledBy)
				end
			end
		else
			schema[#schema + 1] = entry
		end
	end
	return schema
end

local confirmAction

StaticPopupDialogs["FROSTATOMUI_CONFIG_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		confirmAction()
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

function ns.Confirm(text, action)
	confirmAction = action
	local dialog = StaticPopup_Show("FROSTATOMUI_CONFIG_CONFIRM", text)
	if dialog then
		dialog:SetFrameStrata(POPUP_STRATA)
	end
end

local function isEnabledBy(enabledBy)
	if type(enabledBy) == "table" then
		for i = 1, #enabledBy do
			if not isEnabledBy(enabledBy[i]) then
				return false
			end
		end
		return true
	end
	return ui:GetConfig(enabledBy) and true or false
end

local function isEnabledByAny(paths)
	for i = 1, #paths do
		if ui:GetConfig(paths[i]) then
			return true
		end
	end
	return false
end

local function isEntryEnabled(entry)
	if entry.disabled and entry.disabled() then
		return false
	end
	if entry.enabledBy and not isEnabledBy(entry.enabledBy) then
		return false
	end
	if entry.enabledByAny and not isEnabledByAny(entry.enabledByAny) then
		return false
	end
	local page = entry.page
	local enable = page and page.enable
	return not (enable and entry.path ~= enable and not ui:GetConfig(enable))
end

local function showContent(page, scroll, offset)
	scroll:SetScrollChild(page.content)
	page.content:Show()
	scroll:SetVerticalScroll(offset)
end

local function buildPage(page)
	local scroll = page.scroll or frame.scroll
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(page.width or scroll:GetWidth())
	content:Hide()
	page.content = content
	page.rows = {}

	local offset = PADDING / 2
	local first = true
	for _, entry in ipairs(expandSchema(page)) do
		if not entry.hidden then
			local kind = entry.type or (entry.header and "header") or (entry.description and "description")
			local row = creators[kind](content, entry)
			if kind == "header" and not first then
				offset = offset + SECTION_GAP
			end
			row:SetPoint("TOP", 0, -offset)
			offset = offset + row:GetHeight()
			if row.Refresh then
				tinsert(page.rows, row)
			end
			first = false
		end
	end
	content:SetHeight(offset + PADDING)
end

local function rebuildPage(page)
	local scroll = page.scroll or frame.scroll
	local offset = scroll:GetVerticalScroll()
	page.content:Hide()
	buildPage(page)
	showContent(page, scroll, offset)
end

local function refreshPage(page)
	if not page.rows then
		return
	end
	if page.signature and page.signature() ~= page.lastSignature then
		rebuildPage(page)
	end
	refreshing = true
	for _, row in ipairs(page.rows) do
		row.Refresh()
		local enabled = isEntryEnabled(row.entry)
		row:SetEnabled(enabled)
		setEnabledAlpha(row.label, enabled)
	end
	refreshing = false
end

function ns.RefreshPage()
	if frame and frame:IsShown() then
		refreshPage(currentPage)
	end
end

local function resetSchema(schema)
	for _, entry in ipairs(schema) do
		if entry.path then
			ui:ResetConfig(entry.path)
		end
	end
end

local function resetElement(element)
	resetSchema(element.schema)
	ui:ResetConfig(element.path)
end

local function resetPage(page)
	resetSchema(page.schema)
	for _, element in ipairs(elements) do
		if element.page == page.key then
			resetElement(element)
		end
	end
end

local function showPage(page)
	if currentPage then
		if currentPage.onHide then
			currentPage.onHide()
		end
		currentPage.content:Hide()
		if currentPage.button then
			currentPage.button:UnlockHighlight()
		end
	end
	currentPage = page
	if not page.content then
		buildPage(page)
	end
	showContent(page, frame.scroll, 0)
	if page.button then
		page.button:LockHighlight()
		lastNavPage = page
		markSeen(page)
		page.button.newBadge:Hide()
	end
	frame.title:SetText(page.name)
	if page.onShow then
		page.onShow()
	end
	ui.SetShown(frame.resetPageButton, not page.noReset)
	refreshPage(page)
end

local function selectPage(page)
	if currentPage ~= page then
		showPage(page)
	end
end

local function matchesQuery(entry, query)
	local label = entry.label
	if not label then
		return false
	end
	if label:lower():find(query, 1, true) then
		return true
	end
	local desc = entry.desc
	return desc and desc:lower():find(query, 1, true) and true or false
end

local function collectEntries(schema, entries, title, query)
	local count = 0
	local header, headerAdded
	for _, entry in ipairs(entries) do
		if entry.header then
			header, headerAdded = entry.header, false
		elseif not entry.hidden and matchesQuery(entry, query) then
			if not headerAdded then
				headerAdded = true
				schema[#schema + 1] = { header = header and (title .. " / " .. header) or title }
			end
			schema[#schema + 1] = entry
			count = count + 1
		end
	end
	return count
end

local function collectSearch(query)
	local schema = {}
	local count = 0
	for _, page in ipairs(pages) do
		count = count + collectEntries(schema, page.schema, page.name, query)
		for _, element in ipairs(elements) do
			if element.page == page.key and not element.hidden then
				local title = page.name .. " / " .. element.name
				local found = collectEntries(schema, element.schema, title, query)
				if found == 0 and element.name:lower():find(query, 1, true) then
					schema[#schema + 1] = { header = title }
					schema[#schema + 1] = elementButton(element, page)
					found = 1
				end
				count = count + found
			end
		end
	end
	return schema, count
end

local function runSearch()
	local query = frame.searchBox:GetText():trim():lower()
	if query == "" then
		if currentPage == searchPage then
			showPage(lastNavPage or pages[1])
		end
		return
	end
	if searchPage.query == query then
		selectPage(searchPage)
		return
	end
	local schema, count = collectSearch(query)
	if searchPage.content then
		searchPage.content:Hide()
	end
	if currentPage == searchPage then
		currentPage = nil
	end
	searchPage.query = query
	searchPage.schema = schema
	searchPage.content = nil
	searchPage.rows = nil
	searchPage.name = count > 0 and L["Search: %d results"]:format(count) or L["Search: no results"]
	showPage(searchPage)
end

local function scheduleSearch()
	local token = (frame.searchToken or 0) + 1
	frame.searchToken = token
	ui.After(SEARCH_DELAY, function()
		if frame.searchToken == token then
			runSearch()
		end
	end)
end

local function createSearchBox()
	local box = createEditBox(frame.nav, NAV_WIDTH - 18)
	box:SetPoint("TOPLEFT", 6, -2)
	box:SetMaxLetters(40)
	box.OnCommit = function() end
	box:SetScript("OnTextChanged", function(self)
		ui.SetShown(self.placeholder, self:GetText() == "")
		scheduleSearch()
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		runSearch()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		self:SetText("")
	end)

	local placeholder = box:CreateFontString(nil, "OVERLAY")
	ui.SetFont(placeholder, 12)
	placeholder:SetTextColor(0.5, 0.5, 0.5)
	placeholder:SetPoint("LEFT", 6, 0)
	placeholder:SetText(L["Search settings..."])
	box.placeholder = placeholder
	frame.searchBox = box
end

local function createNavButton(page, index)
	local button = CreateFrame("Button", nil, frame.nav)
	button:SetHeight(NAV_BUTTON_HEIGHT)
	button:SetPoint("TOPLEFT", 0, -SEARCH_HEIGHT - (index - 1) * NAV_BUTTON_HEIGHT)
	button:SetPoint("RIGHT")
	button:SetHighlightTexture(ui.Media.blank)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

	local text = button:CreateFontString(nil, "OVERLAY")
	ui.SetFont(text, 12)
	text:SetTextColor(0.85, 0.85, 0.85)
	text:SetPoint("LEFT", 10, 0)
	text:SetText(page.name)

	button.newBadge = addNewBadge(button, text, text:GetStringWidth() + 6)
	ui.SetShown(button.newBadge, newestUnseen(page))

	button:SetScript("OnClick", function()
		frame.searchBox:SetText("")
		selectPage(page)
	end)
	page.button = button
end

local seenLoaded = false

local function initSeen()
	if seenLoaded then
		return
	end
	seenLoaded = true
	for key, version in pairs(seenStore()) do
		seenAtOpen[key] = version
	end
end

local function createFrame()
	initSeen()

	frame = createWindow(FRAME_NAME, "DIALOG", 0.85)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetScript("OnShow", function()
		if currentPage and currentPage.onShow then
			currentPage.onShow()
		end
		refreshPage(currentPage)
	end)
	frame:SetScript("OnHide", function()
		if currentPage and currentPage.onHide then
			currentPage.onHide()
		end
	end)
	frame.heading:SetText("FrostAtom UI")
	createCloseButton(frame)

	local nav = CreateFrame("Frame", nil, frame)
	nav:SetPoint("TOPLEFT", PADDING, -(PADDING + TITLE_HEIGHT))
	nav:SetPoint("BOTTOMLEFT", PADDING, PADDING)
	nav:SetWidth(NAV_WIDTH)
	frame.nav = nav

	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetTexture(1, 1, 1, 0.12)
	divider:SetWidth(1)
	divider:SetPoint("TOP", nav, "TOPRIGHT", 0, 0)
	divider:SetPoint("BOTTOM", nav, "BOTTOMRIGHT", 0, 0)

	local resetAll = createButton(nav, L["Reset all"], NAV_WIDTH - 12)
	resetAll:SetPoint("BOTTOMLEFT", 0, 0)
	resetAll:SetScript("OnClick", function()
		ns.Confirm(L["Reset all FrostAtom UI settings to defaults?"], function()
			ui:ResetConfig()
		end)
	end)

	local unlock = createButton(nav, L["Unlock frames"], NAV_WIDTH - 12)
	unlock:SetPoint("BOTTOMLEFT", resetAll, "TOPLEFT", 0, 6)
	unlock:SetScript("OnClick", function()
		ui.Movers.Unlock()
		if ui.Movers.IsUnlocked() then
			frame:Hide()
		end
	end)

	local title = frame:CreateFontString(nil, "OVERLAY")
	ui.SetFont(title, 13, "OUTLINE", true)
	title:SetPoint("TOPLEFT", nav, "TOPRIGHT", PADDING, 0)
	frame.title = title

	local resetPageButton = createButton(frame, L["Reset page"], 100)
	resetPageButton:SetPoint("TOPRIGHT", -PADDING - 26, -PADDING - 1)
	resetPageButton:SetScript("OnClick", function()
		ns.Confirm(L["Reset %s settings to defaults?"]:format(currentPage.name), function()
			resetPage(currentPage)
		end)
	end)
	frame.resetPageButton = resetPageButton

	local reloadButton = createButton(frame, L["Reload UI"], 90)
	reloadButton:SetPoint("RIGHT", resetPageButton, "LEFT", -8, 0)
	reloadButton.text:SetTextColor(1, 0.6, 0.2)
	reloadButton:SetScript("OnClick", ReloadUI)
	reloadButton:Hide()
	frame.reloadButton = reloadButton

	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, -TITLE_HEIGHT + 8)
	scroll:SetPoint("BOTTOMRIGHT", -PADDING - 18, PADDING)
	frame.scroll = scroll

	createSearchBox()
	for i, page in ipairs(pages) do
		createNavButton(page, i)
	end

	selectPage(pages[1])
end

local function placeElementFrame(anchor)
	elementFrame:ClearAllPoints()
	local left, right = anchor and anchor:GetLeft(), anchor and anchor:GetRight()
	if not left then
		elementFrame:SetPoint("CENTER")
		return
	end
	local scale = anchor:GetEffectiveScale() / elementFrame:GetEffectiveScale()
	local top = anchor:GetTop() * scale
	local screenWidth = UIParent:GetWidth() * UIParent:GetEffectiveScale() / elementFrame:GetEffectiveScale()
	local width = elementFrame:GetWidth()
	local x
	if right * scale + ELEMENT_GAP + width <= screenWidth then
		x = right * scale + ELEMENT_GAP
	elseif left * scale - ELEMENT_GAP - width >= 0 then
		x = left * scale - ELEMENT_GAP - width
	else
		x = (screenWidth - width) / 2
	end
	elementFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
end

local function createElementFrame()
	initSeen()
	elementFrame = createWindow(FRAME_NAME .. "Element", ELEMENT_STRATA, 0.9)
	elementFrame:SetSize(ELEMENT_WIDTH, 200)
	elementFrame:SetToplevel(true)
	elementFrame:SetScript("OnDragStart", function(self)
		self.userPlaced = true
		self:StartMoving()
	end)
	elementFrame:SetScript("OnHide", function(self)
		self.userPlaced = nil
		ui.Movers.ClearSelection()
	end)

	local title = elementFrame.heading
	title:SetPoint("RIGHT", -PADDING - 26, 0)
	title:SetJustifyH("LEFT")
	elementFrame.title = title
	createCloseButton(elementFrame)

	local resetPosition = createButton(elementFrame, L["Reset position"], 120)
	resetPosition:SetPoint("BOTTOMLEFT", PADDING, PADDING)
	resetPosition:SetScript("OnClick", function()
		ui:ResetConfig(elementFrame.view.element.path)
	end)
	elementFrame.resetPosition = resetPosition

	local resetAll = createButton(elementFrame, L["Reset all"], 100)
	resetAll:SetPoint("LEFT", resetPosition, "RIGHT", 8, 0)
	resetAll:SetScript("OnClick", function()
		local element = elementFrame.view.element
		ns.Confirm(L["Reset %s settings to defaults?"]:format(element.name), function()
			resetElement(element)
		end)
	end)
	elementFrame.resetAll = resetAll

	local more = createButton(elementFrame, L["All settings"], 120)
	more:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
	more:SetScript("OnClick", function()
		local pageKey = elementFrame.view.element.page
		ui.Movers.Lock()
		ns.Toggle(pageKey)
	end)
	elementFrame.more = more

	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "ElementScroll", elementFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -(PADDING + TITLE_HEIGHT) + 8)
	scroll:SetPoint("BOTTOMRIGHT", -PADDING - 18, PADDING + ELEMENT_FOOTER_HEIGHT)
	elementFrame.scroll = scroll
end

local function elementView(element)
	local view = element.view
	if view then
		return view
	end
	local schema = {}
	for _, entry in ipairs(element.schema) do
		schema[#schema + 1] = entry
	end
	view = {
		key = element.key,
		element = element,
		scroll = elementFrame.scroll,
		width = ELEMENT_WIDTH - PADDING - 18,
		schema = schema,
	}
	schema[#schema + 1] = { header = L["Position"], page = view }
	schema[#schema + 1] = {
		type = "point",
		path = element.path,
		label = L["Anchor and offset"],
		desc = L["Drag the frame to move it; snapping to another frame attaches it to that frame."],
		page = view,
	}
	element.view = view
	return view
end

function ns.OpenElement(path, anchor)
	if not elementFrame then
		createElementFrame()
	end
	local element = elementFor(path)
	local view = elementView(element)
	if elementFrame:IsShown() and elementFrame.view == view then
		refreshPage(view)
		return
	end
	if elementFrame.view and elementFrame.view.content then
		elementFrame.view.content:Hide()
	end
	elementFrame.view = view
	elementFrame.title:SetText(element.name)
	if not view.content then
		buildPage(view)
	end
	showContent(view, elementFrame.scroll, 0)
	markSeen(element)
	ui.SetShown(elementFrame.more, element.page ~= nil)
	ui.SetShown(elementFrame.resetPosition, not element.noReset)
	ui.SetShown(elementFrame.resetAll, not element.noReset)

	local height = PADDING + TITLE_HEIGHT - 8 + view.content:GetHeight() + PADDING + ELEMENT_FOOTER_HEIGHT
	elementFrame:SetHeight(max(ELEMENT_MIN_HEIGHT, min(ELEMENT_MAX_HEIGHT, height)))
	if not elementFrame.userPlaced or not elementFrame:IsShown() then
		placeElementFrame(anchor)
	end
	elementFrame:Show()
	refreshPage(view)
end

function ns.CloseElement()
	if elementFrame and elementFrame:IsShown() then
		elementFrame:Hide()
	end
end

function ns.GetOpenElement()
	local view = elementFrame and elementFrame:IsShown() and elementFrame.view
	return view and view.element.path or nil
end

function ns.EditElement(path)
	if frame then
		frame:Hide()
	end
	ui.Movers.Unlock()
	if not ui.Movers.IsUnlocked() then
		return
	end
	if not ui.Movers.Select(path) then
		ns.OpenElement(path)
	end
end

local function refreshShown()
	if frame and frame:IsShown() then
		refreshPage(currentPage)
	end
	if elementFrame and elementFrame:IsShown() then
		refreshPage(elementFrame.view)
	end
end

local watcher = ui.Mixin({}, ui.EventMixin)
watcher:RegisterEvent(ui.CONFIG_CHANGED, refreshShown)
watcher:RegisterEvent(ui.PROFILES_CHANGED, refreshShown)

local function pageByKey(key)
	for _, page in ipairs(pages) do
		if page.key == key then
			return page
		end
	end
end

function ns.Toggle(pageKey)
	if not frame then
		createFrame()
	end
	if not pageKey then
		ui.SetShown(frame, not frame:IsShown())
		return
	end
	local page = pageByKey(pageKey)
	if page then
		frame.searchBox:SetText("")
		selectPage(page)
	else
		frame.searchBox:SetText(pageKey)
		runSearch()
	end
	frame:Show()
end

_G[ADDON_NAME] = ns
