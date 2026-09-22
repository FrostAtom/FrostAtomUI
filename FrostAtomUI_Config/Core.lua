local ADDON_NAME, ns = ...

local ui = FrostAtomUI

local floor, max, min = math.floor, math.max, math.min
local tinsert, tremove, sort = tinsert, table.remove, table.sort

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

local ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local OUTLINES = { { "", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } }

ns.ANCHORS = ANCHORS
ns.OUTLINES = OUTLINES

local pages = {}
local frame
local currentPage
local lastNavPage
local refreshing = false
local widgetCount = 0

local searchPage = { key = "search", name = "Search", schema = {}, noReset = true }

function ns.RegisterPage(page)
	for _, entry in ipairs(page.schema) do
		entry.page = page
	end
	tinsert(pages, page)
	sort(pages, function(a, b)
		return a.order < b.order
	end)
end

function ns.Section(schema, header, prefix, entries, hidden)
	if hidden then
		return schema
	end
	local enable = prefix .. ".enabled"
	schema[#schema + 1] = { header = header }
	for _, entry in ipairs(entries) do
		if entry.path then
			entry.path = prefix .. "." .. entry.path
		end
		if entry.path ~= enable then
			if entry.enabledBy then
				entry.enabledBy = { enable, entry.enabledBy }
			else
				entry.enabledBy = enable
			end
		end
		schema[#schema + 1] = entry
	end
	return schema
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

local function createButton(parent, text, width, height)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height or 20)
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
	box:EnableMouse(enabled)
	setEnabledAlpha(box, enabled)
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

local function createRow(parent, entry)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("LEFT", PADDING, 0)
	row:SetPoint("RIGHT", -PADDING, 0)
	row.entry = entry
	row:EnableMouse(true)
	row:SetScript("OnEnter", showTooltip)
	row:SetScript("OnLeave", GameTooltip_Hide)

	local label = row:CreateFontString(nil, "OVERLAY")
	ui.SetFont(label, 12)
	label:SetTextColor(0.85, 0.85, 0.85)
	label:SetPoint("LEFT", 0, 0)
	label:SetWidth(LABEL_WIDTH)
	label:SetJustifyH("LEFT")
	label:SetText(entry.label)
	row.label = label
	return row
end

local function get(entry)
	if entry.get then
		return entry.get()
	end
	return ui:GetConfig(entry.path)
end

local function set(entry, value)
	if get(entry) == value then
		return
	end
	if entry.set then
		entry.set(value)
		return
	end
	ui:SetConfig(entry.path, value)
	if entry.reload then
		frame.reloadButton:Show()
		if entry.type == "toggle" then
			ns.Confirm("This change takes effect after a UI reload. Reload now?", ReloadUI)
		end
	end
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
	text:SetPoint("RIGHT")
	text:SetJustifyH("LEFT")
	text:SetText(entry.description)
	holder:SetHeight(text:GetStringHeight() + 12)
	return holder
end

function creators.toggle(parent, entry)
	local row = createRow(parent, entry)

	local check = CreateFrame("CheckButton", nextName(), row, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("LEFT", CONTROL_X - 4, 0)
	check:SetScript("OnClick", function(self)
		set(entry, self:GetChecked() and true or false)
	end)

	row.Refresh = function()
		check:SetChecked(get(entry))
	end
	row.SetEnabled = function(_, enabled)
		if enabled then
			check:Enable()
		else
			check:Disable()
		end
	end
	return row
end

function creators.number(parent, entry)
	local row = createRow(parent, entry)

	local slider = CreateFrame("Slider", nextName(), row, "OptionsSliderTemplate")
	slider:SetPoint("LEFT", CONTROL_X, 0)
	slider:SetWidth(180)
	slider:SetMinMaxValues(entry.min, entry.max)
	slider:SetValueStep(entry.step)
	_G[slider:GetName() .. "Low"]:SetText(formatNumber(entry.min, entry.step))
	_G[slider:GetName() .. "High"]:SetText(formatNumber(entry.max, entry.step))
	_G[slider:GetName() .. "Text"]:SetText("")

	local box = createEditBox(row, 54, true)
	box:SetPoint("LEFT", slider, "RIGHT", 16, 0)

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

	row.Refresh = function()
		local value = get(entry)
		slider:SetValue(value)
		box:SetText(formatNumber(value, entry.step))
		box:SetCursorPosition(0)
	end
	row.SetEnabled = function(_, enabled)
		if enabled then
			slider:Enable()
		else
			slider:Disable()
		end
		setEditBoxEnabled(box, enabled)
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

function creators.font(parent, entry)
	local row = createRow(parent, entry)
	local sizeEntry = { path = entry.path .. ".size", min = 6, max = 32, step = 1 }
	local outlineEntry = { path = entry.path .. ".outline" }

	local slider = CreateFrame("Slider", nextName(), row, "OptionsSliderTemplate")
	slider:SetPoint("LEFT", CONTROL_X, 0)
	slider:SetWidth(120)
	slider:SetMinMaxValues(sizeEntry.min, sizeEntry.max)
	slider:SetValueStep(1)
	_G[slider:GetName() .. "Low"]:SetText("")
	_G[slider:GetName() .. "High"]:SetText("")
	_G[slider:GetName() .. "Text"]:SetText("")

	local box = createEditBox(row, 40, true)
	box:SetPoint("LEFT", slider, "RIGHT", 10, 0)

	local function commitSize(value)
		set(sizeEntry, round(max(sizeEntry.min, min(sizeEntry.max, value)), 1))
	end
	slider:SetScript("OnValueChanged", function(_, value)
		if not refreshing then
			commitSize(value)
		end
	end)
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		if self:IsEnabled() then
			commitSize(self:GetValue() + delta)
		end
	end)
	box.OnCommit = function(self)
		local value = tonumber(self:GetText())
		if value then
			commitSize(value)
		else
			row.Refresh()
		end
	end

	local dropdown = createDropdown(row, 100, function()
		return OUTLINES
	end, function(value)
		set(outlineEntry, value)
	end)
	dropdown:SetPoint("LEFT", box, "RIGHT", -6, -2)

	row.Refresh = function()
		local size = get(sizeEntry)
		slider:SetValue(size)
		box:SetText(tostring(size))
		box:SetCursorPosition(0)
		dropdown:Select(get(outlineEntry) or "")
	end
	row.SetEnabled = function(_, enabled)
		if enabled then
			slider:Enable()
		else
			slider:Disable()
		end
		setEditBoxEnabled(box, enabled)
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
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)

	local reset = createButton(row, "Default", 60)
	reset:SetPoint("LEFT", hex, "RIGHT", 12, 0)
	reset:SetScript("OnClick", function()
		ui:ResetConfig(entry.path)
	end)

	row.Refresh = function()
		local r, g, b, a = current()
		fill:SetVertexColor(r, g, b, a)
		hex:SetText(("%02x%02x%02x"):format(r * 255, g * 255, b * 255))
		if ui:IsDefaultConfig(entry.path) then
			reset:Hide()
		else
			reset:Show()
		end
	end
	row.SetEnabled = function(_, enabled)
		swatch:EnableMouse(enabled)
		setEnabledAlpha(swatch, enabled)
		reset:EnableMouse(enabled)
		setEnabledAlpha(reset, enabled)
	end
	return row
end

function creators.point(parent, entry)
	local row = createRow(parent, entry)

	local dropdown = createDropdown(row, 100, function()
		local options = {}
		for i = 1, #ANCHORS do
			options[i] = { ANCHORS[i], ANCHORS[i] }
		end
		return options
	end, function(anchor)
		row.dropdown.selected = anchor
		row.commit()
	end)
	dropdown:SetPoint("LEFT", CONTROL_X - 20, -2)
	row.dropdown = dropdown

	local xBox = createEditBox(row, 54, true)
	xBox:SetPoint("LEFT", dropdown, "RIGHT", 4, 2)
	local yBox = createEditBox(row, 54, true)
	yBox:SetPoint("LEFT", xBox, "RIGHT", 10, 0)

	row.commit = function()
		local x, y = tonumber(xBox:GetText()), tonumber(yBox:GetText())
		if not x or not y then
			row.Refresh()
			return
		end
		x, y = floor(x + 0.5), floor(y + 0.5)
		local point = dropdown.selected
		local value = get(entry)
		if point ~= value[1] or x ~= value[2] or y ~= value[3] then
			ui:SetConfig(entry.path, { point, x, y })
		end
	end
	xBox.OnCommit = row.commit
	yBox.OnCommit = row.commit

	row.Refresh = function()
		local point, x, y = unpack(get(entry))
		dropdown:Select(point)
		xBox:SetText(tostring(x))
		yBox:SetText(tostring(y))
		xBox:SetCursorPosition(0)
		yBox:SetCursorPosition(0)
	end
	row.SetEnabled = function(_, enabled)
		dropdown:SetEnabled(enabled)
		setEditBoxEnabled(xBox, enabled)
		setEditBoxEnabled(yBox, enabled)
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
		button:EnableMouse(enabled)
		setEnabledAlpha(button, enabled)
	end
	return row
end

local function listItems(entry)
	return get(entry) or {}
end

local function copyList(list)
	local result = {}
	for i = 1, #list do
		result[i] = list[i]
	end
	return result
end

function creators.list(parent, entry)
	local row = createRow(parent, entry)

	local box = createEditBox(row, 80, true)
	box:SetPoint("LEFT", CONTROL_X, 0)

	local add = createButton(row, entry.addText or "Add", 60)
	add:SetPoint("LEFT", box, "RIGHT", 8, 0)

	local function commit()
		local id = tonumber(box:GetText())
		if not id then
			return
		end
		local item = entry.create(id)
		if not item then
			ui.Print("unknown ID %d", id)
			return
		end
		local list = copyList(listItems(entry))
		list[#list + 1] = item
		box:SetText("")
		ui:SetConfig(entry.path, list)
	end
	box.OnCommit = function() end
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		commit()
	end)
	add:SetScript("OnClick", commit)

	row.Refresh = function() end
	row.SetEnabled = function(_, enabled)
		setEditBoxEnabled(box, enabled)
		add:EnableMouse(enabled)
		setEnabledAlpha(add, enabled)
	end
	return row
end

function creators.listItem(parent, entry)
	local row = createRow(parent, entry)
	row.label:SetPoint("LEFT", 28, 0)
	row.label:SetTextColor(1, 1, 1)

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("LEFT", 2, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetTexture(entry.icon)

	local remove = createButton(row, "Remove", 70)
	remove:SetPoint("RIGHT", 0, 0)
	remove:SetScript("OnClick", function()
		local list = copyList(listItems(entry.list))
		tremove(list, entry.index)
		ui:SetConfig(entry.list.path, list)
	end)

	row.Refresh = function() end
	row.SetEnabled = function(_, enabled)
		remove:EnableMouse(enabled)
		setEnabledAlpha(remove, enabled)
	end
	return row
end

local function expandList(schema, entry)
	local items = listItems(entry)
	for index = 1, #items do
		local item = items[index]
		local prefix = entry.path .. "." .. index .. "."
		local label, icon = entry.describe(item)
		schema[#schema + 1] =
			{ type = "listItem", label = label, icon = icon, list = entry, index = index, page = entry.page }
		for _, field in ipairs(entry.fields) do
			local sub = {}
			for key, value in pairs(field) do
				sub[key] = value
			end
			sub.path = prefix .. field.key
			sub.enabledBy = entry.enabledBy
			sub.page = entry.page
			schema[#schema + 1] = sub
		end
	end
end

local function expandSchema(page)
	local schema = {}
	local counts = {}
	for _, entry in ipairs(page.schema) do
		schema[#schema + 1] = entry
		if entry.type == "list" then
			expandList(schema, entry)
			counts[#counts + 1] = #listItems(entry)
		end
	end
	page.listCounts = counts
	return schema
end

local function listCountsChanged(page)
	local counts = page.listCounts
	if not counts then
		return false
	end
	local i = 0
	for _, entry in ipairs(page.schema) do
		if entry.type == "list" then
			i = i + 1
			if counts[i] ~= #listItems(entry) then
				return true
			end
		end
	end
	return false
end

local confirmAction

StaticPopupDialogs["FROSTATOMUI_CONFIG_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		confirmAction()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

function ns.Confirm(text, action)
	confirmAction = action
	StaticPopup_Show("FROSTATOMUI_CONFIG_CONFIRM", text)
end

local function isEnabledBy(enabledBy)
	if type(enabledBy) == "table" then
		for i = 1, #enabledBy do
			if not ui:GetConfig(enabledBy[i]) then
				return false
			end
		end
		return true
	end
	return ui:GetConfig(enabledBy) and true or false
end

local function isEntryEnabled(entry)
	if entry.disabled and entry.disabled() then
		return false
	end
	if entry.enabledBy and not isEnabledBy(entry.enabledBy) then
		return false
	end
	local page = entry.page
	local enable = page and page.enable
	if enable and entry.path ~= enable and not ui:GetConfig(enable) then
		return false
	end
	return true
end

local buildPage

local function refreshPage(page)
	if not page.rows then
		return
	end
	if listCountsChanged(page) then
		local scroll = frame.scroll:GetVerticalScroll()
		page.content:Hide()
		buildPage(page)
		frame.scroll:SetScrollChild(page.content)
		page.content:Show()
		frame.scroll:SetVerticalScroll(scroll)
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

function buildPage(page)
	local content = CreateFrame("Frame", nil, frame.scroll)
	content:SetWidth(frame.scroll:GetWidth())
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

local function resetPage(page)
	for _, entry in ipairs(page.schema) do
		if entry.path then
			ui:ResetConfig(entry.path)
		end
	end
end

local function showPage(page)
	if currentPage then
		currentPage.content:Hide()
		if currentPage.button then
			currentPage.button:UnlockHighlight()
		end
	end
	currentPage = page
	if not page.content then
		buildPage(page)
	end
	frame.scroll:SetScrollChild(page.content)
	frame.scroll:SetVerticalScroll(0)
	page.content:Show()
	if page.button then
		page.button:LockHighlight()
		lastNavPage = page
	end
	frame.title:SetText(page.name)
	if page.noReset then
		frame.resetPageButton:Hide()
	else
		frame.resetPageButton:Show()
	end
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

local function collectSearch(query)
	local schema = {}
	local count = 0
	for _, page in ipairs(pages) do
		local header, headerAdded
		for _, entry in ipairs(page.schema) do
			if entry.header then
				header, headerAdded = entry.header, false
			elseif not entry.hidden and matchesQuery(entry, query) then
				if not headerAdded then
					headerAdded = true
					schema[#schema + 1] = { header = header and (page.name .. " / " .. header) or page.name }
				end
				schema[#schema + 1] = entry
				count = count + 1
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
	searchPage.name = count > 0 and ("Search: %d result%s"):format(count, count == 1 and "" or "s")
		or "Search: no results"
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
		if self:GetText() == "" then
			self.placeholder:Show()
		else
			self.placeholder:Hide()
		end
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
	placeholder:SetText("Search settings...")
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

	button:SetScript("OnClick", function()
		frame.searchBox:SetText("")
		selectPage(page)
	end)
	page.button = button
end

local function createFrame()
	frame = CreateFrame("Frame", FRAME_NAME, UIParent)
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnShow", function()
		refreshPage(currentPage)
	end)
	frame:SetBackdrop(ui.CreateBackdrop(14, 3))
	frame:SetBackdropColor(0, 0, 0, 0.85)
	tinsert(UISpecialFrames, FRAME_NAME)

	local heading = frame:CreateFontString(nil, "OVERLAY")
	ui.SetFont(heading, 13, "OUTLINE", true)
	heading:SetPoint("TOPLEFT", PADDING, -PADDING - 4)
	heading:SetText("FrostAtom UI")

	local close = CreateFrame("Button", nil, frame)
	close:SetSize(26, 26)
	close:SetPoint("TOPRIGHT", -PADDING + 6, -PADDING + 6)
	close:SetNormalTexture(CLOSE_ICON)
	close:SetHighlightTexture(CLOSE_ICON_HIGHLIGHT)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

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

	local resetAll = createButton(nav, "Reset all", NAV_WIDTH - 12)
	resetAll:SetPoint("BOTTOMLEFT", 0, 0)
	resetAll:SetScript("OnClick", function()
		ns.Confirm("Reset all FrostAtom UI settings to defaults?", function()
			ui:ResetConfig()
		end)
	end)

	local unlock = createButton(nav, "Unlock frames", NAV_WIDTH - 12)
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

	local resetPageButton = createButton(frame, "Reset page", 100)
	resetPageButton:SetPoint("TOPRIGHT", -PADDING - 26, -PADDING - 1)
	frame.resetPageButton = resetPageButton

	local reloadButton = createButton(frame, "Reload UI", 90)
	reloadButton:SetPoint("RIGHT", resetPageButton, "LEFT", -8, 0)
	reloadButton.text:SetTextColor(1, 0.6, 0.2)
	reloadButton:SetScript("OnClick", ReloadUI)
	reloadButton:Hide()
	frame.reloadButton = reloadButton
	resetPageButton:SetScript("OnClick", function()
		ns.Confirm(("Reset %s settings to defaults?"):format(currentPage.name), function()
			resetPage(currentPage)
		end)
	end)

	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, -TITLE_HEIGHT + 8)
	scroll:SetPoint("BOTTOMRIGHT", -PADDING - 18, PADDING)
	frame.scroll = scroll

	createSearchBox()
	for i, page in ipairs(pages) do
		createNavButton(page, i)
	end

	local watcher = ui.Mixin({}, ui.EventMixin)
	local function refreshShown()
		if frame:IsShown() then
			refreshPage(currentPage)
		end
	end
	watcher:RegisterEvent(ui.CONFIG_CHANGED, refreshShown)
	watcher:RegisterEvent(ui.PROFILES_CHANGED, refreshShown)

	selectPage(pages[1])
end

function ns.Toggle(pageKey)
	if not frame then
		createFrame()
	end
	if pageKey then
		for _, page in ipairs(pages) do
			if page.key == pageKey then
				frame.searchBox:SetText("")
				selectPage(page)
				frame:Show()
				return
			end
		end
		frame.searchBox:SetText(pageKey)
		runSearch()
		frame:Show()
		return
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

_G[ADDON_NAME] = ns
