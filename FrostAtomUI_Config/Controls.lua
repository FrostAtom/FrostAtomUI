local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local max, min, floor, ceil = math.max, math.min, math.floor, math.ceil

local creators = ns.creators
local CONTROL_X = ns.CONTROL_X
local ROW_HEIGHT = ns.ROW_HEIGHT
local RESET_RESERVE = 26
local GLYPH_SIZE = 12
local GLYPH_GAP = 4
local SEGMENT_HEIGHT = 20
local SEGMENT_PADDING = 8
local SEGMENT_GAP = 2
local SEGMENT_GLYPH_WIDTH = 28
local SEGMENT_MAX_OPTIONS = 4
local SEGMENT_COLOR = { 0, 0, 0, 0.45 }
local SELECTED_COLOR = { 0.196, 0.388, 0.8, 0.6 }
local BORDER_COLOR = { 0.4, 0.4, 0.4 }
local HOVER_BORDER_COLOR = { 0.8, 0.8, 0.8 }
local SELECTED_BORDER_COLOR = { 1, 0.82, 0 }
local CHECK_LINE = 22
local CHECK_GAP = 8
local CHECK_X = CONTROL_X - 4
local VALUE_BOX_WIDTH = 44
local AXIS_GAP = 4
local GRID_CELL = 8
local GRID_GAP = 2
local GRID_ROW_HEIGHT = 34
local GRID_COLOR = { 0.45, 0.45, 0.45 }
local GRID_HOVER_COLOR = { 1, 1, 1 }
local GRID_SELECTED_COLOR = { 1, 0.82, 0 }
local ACTION_BUTTON_WIDTH = 28
local ACTION_GAP = 4
local PREVIEW_FONT_SIZE = 13
local STATUSBAR_PREVIEW = "|T%s:12:56|t  %s"

local ANCHOR_GRID = {
	{ "TOPLEFT", L["Top left"] },
	{ "TOP", L["Top center"] },
	{ "TOPRIGHT", L["Top right"] },
	{ "LEFT", L["Middle left"] },
	{ "CENTER", L["Center"] },
	{ "RIGHT", L["Middle right"] },
	{ "BOTTOMLEFT", L["Bottom left"] },
	{ "BOTTOM", L["Bottom center"] },
	{ "BOTTOMRIGHT", L["Bottom right"] },
}

ns.UNITS = {
	s = L["%s s"],
	ms = L["%s ms"],
	min = L["%s min"],
}

local measure = CreateFrame("Frame")
measure:Hide()
local measureText = measure:CreateFontString(nil, "ARTWORK")
local measureGlyph = measure:CreateFontString(nil, "ARTWORK")

local function textWidth(text)
	measureText:SetFontObject(ns.Font("GameFontHighlightSmall"))
	measureText:SetText(text)
	return measureText:GetStringWidth()
end

local function glyphWidth(name)
	ui.SetGlyph(measureGlyph, name, GLYPH_SIZE)
	return measureGlyph:GetStringWidth()
end

local function controlWidth(parent)
	return parent:GetWidth() - CONTROL_X - RESET_RESERVE
end

local function optionDesc(option)
	return option.desc or option[3]
end

local function addOptionTooltip(row, option, showName)
	local desc = optionDesc(option)
	if not desc and not showName then
		return
	end
	if not (GameTooltip:IsShown() and GameTooltip:IsOwned(row)) then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:SetText(row.entry.label, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
	GameTooltip:AddLine(option[2], HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if desc then
		GameTooltip:AddLine(desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end
	GameTooltip:Show()
end

local function segmentLayout(values, width, forced)
	local count = #values
	local gaps = (count - 1) * SEGMENT_GAP
	local widths, widest, total, glyphs = {}, 0, 0, true
	for i, option in ipairs(values) do
		local w = textWidth(option[2]) + SEGMENT_PADDING * 2
		if option.glyph then
			w = w + glyphWidth(option.glyph) + GLYPH_GAP
		else
			glyphs = false
		end
		widths[i] = ceil(w)
		widest = max(widest, widths[i])
		total = total + widths[i]
	end
	if widest * count + gaps <= width then
		for i = 1, count do
			widths[i] = widest
		end
		return widths
	elseif total + gaps <= width then
		return widths
	elseif glyphs then
		for i = 1, count do
			widths[i] = SEGMENT_GLYPH_WIDTH
		end
		return widths, true
	elseif forced then
		local w = floor((width - gaps) / count)
		for i = 1, count do
			widths[i] = w
		end
		return widths
	end
end

local function paintSegment(segment)
	local control = segment.control
	local selected = control.value == segment.option[1]
	local enabled = control.enabled
	local border = BORDER_COLOR
	if selected then
		border = SELECTED_BORDER_COLOR
	elseif segment.hovered and enabled then
		border = HOVER_BORDER_COLOR
	end
	local shade = enabled and 1 or 0.5
	segment:SetBackdropBorderColor(border[1] * shade, border[2] * shade, border[3] * shade)
	local fill = selected and SELECTED_COLOR or SEGMENT_COLOR
	segment:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] * shade)
	local color = NORMAL_FONT_COLOR
	if not enabled then
		color = GRAY_FONT_COLOR
	elseif selected or segment.hovered then
		color = HIGHLIGHT_FONT_COLOR
	end
	segment.text:SetTextColor(color.r, color.g, color.b)
	if segment.glyph then
		segment.glyph:SetTextColor(color.r, color.g, color.b)
	end
end

local function segmentEnter(segment)
	segment.hovered = true
	paintSegment(segment)
	local control = segment.control
	if control.OnSegmentEnter then
		control.OnSegmentEnter(segment)
	end
end

local function segmentLeave(segment)
	segment.hovered = nil
	paintSegment(segment)
	local control = segment.control
	if control.OnSegmentLeave then
		control.OnSegmentLeave(segment)
	end
end

local function segmentClick(segment)
	local control = segment.control
	local value = segment.option[1]
	if value == control.value then
		return
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	control:SetValue(value)
	control.onSelect(value)
end

local function setSegmentedValue(control, value)
	control.value = value
	for _, segment in ipairs(control.segments) do
		paintSegment(segment)
	end
end

local function setSegmentedEnabled(control, enabled)
	control.enabled = enabled and true or false
	for _, segment in ipairs(control.segments) do
		if enabled then
			segment:Enable()
		else
			segment:Disable()
		end
		paintSegment(segment)
	end
end

local function createSegment(control, option, width, glyphOnly)
	local segment = CreateFrame("Button", nil, control)
	segment:SetSize(width, SEGMENT_HEIGHT)
	segment:SetBackdrop(ui.CreateBackdrop(8))
	segment.control = control
	segment.option = option

	local text = segment:CreateFontString(nil, "ARTWORK")
	text:SetFontObject(ns.Font("GameFontHighlightSmall"))
	segment.text = text
	if option.glyph then
		local glyph = ui.CreateGlyph(segment, option.glyph, GLYPH_SIZE, "ARTWORK")
		segment.glyph = glyph
		if glyphOnly then
			glyph:SetPoint("CENTER")
		else
			text:SetText(option[2])
			text:SetPoint("CENTER", (glyph:GetStringWidth() + GLYPH_GAP) / 2, 0)
			glyph:SetPoint("RIGHT", text, "LEFT", -GLYPH_GAP, 0)
		end
	else
		text:SetText(option[2])
		text:SetPoint("CENTER")
		if text:GetStringWidth() > width - SEGMENT_PADDING then
			text:SetWidth(width - SEGMENT_PADDING)
			text:SetHeight(SEGMENT_HEIGHT - 6)
		end
	end

	segment:SetScript("OnEnter", segmentEnter)
	segment:SetScript("OnLeave", segmentLeave)
	segment:SetScript("OnClick", segmentClick)
	return segment
end

function ns.CreateSegmented(parent, values, widths, glyphOnly, onSelect)
	local control = CreateFrame("Frame", nil, parent)
	control.segments = {}
	control.enabled = true
	control.onSelect = onSelect
	control.SetValue = setSegmentedValue
	control.SetEnabled = setSegmentedEnabled
	local x = 0
	for i, option in ipairs(values) do
		local segment = createSegment(control, option, widths[i], glyphOnly)
		segment:SetPoint("LEFT", x, 0)
		x = x + widths[i] + SEGMENT_GAP
		control.segments[i] = segment
	end
	control:SetSize(x - SEGMENT_GAP, SEGMENT_HEIGHT)
	return control
end

local function wantsSegmented(entry)
	local style = entry.style
	local values = entry.values
	if style == "dropdown" or type(values) ~= "table" or entry.placeholder or #values < 2 then
		return false
	end
	return style == "segmented" or #values <= SEGMENT_MAX_OPTIONS
end

local function createSegmentedRow(parent, entry, widths, glyphOnly)
	local row = ns.CreateRow(parent, entry)
	local control = ns.CreateSegmented(row, entry.values, widths, glyphOnly, function(value)
		ns.Set(entry, value)
		row.Refresh()
	end)
	control:SetPoint("LEFT", CONTROL_X, 0)
	control.OnSegmentEnter = function(segment)
		ns.RowEnter(row)
		addOptionTooltip(row, segment.option, glyphOnly)
	end
	control.OnSegmentLeave = function()
		ns.RowLeave(row)
	end
	row.segmented = control
	row.Refresh = function()
		control:SetValue(ns.Get(entry))
	end
	row.SetEnabled = function(_, enabled)
		control:SetEnabled(enabled)
	end
	return row
end

local createDropdownRow = creators.select

local previewFonts = {}
local previewFontCount = 0

local function previewFont(path)
	local object = previewFonts[path]
	if not object then
		previewFontCount = previewFontCount + 1
		object = CreateFont("FrostAtomUI_ConfigPreviewFont" .. previewFontCount)
		object:CopyFontObject(GameFontHighlightSmallLeft)
		object:SetFont(path, PREVIEW_FONT_SIZE, "")
		previewFonts[path] = object
	end
	return object
end

local function previewValues(entry)
	local values = {}
	for i, option in ipairs(entry.values) do
		local copy = { option[1], option[2], option[3], desc = option.desc, glyph = option.glyph }
		if entry.preview == "font" then
			copy.fontObject = previewFont(option[1])
		elseif entry.preview == "statusbar" then
			copy[2] = STATUSBAR_PREVIEW:format(option[1], option[2])
		end
		values[i] = copy
	end
	return values
end

local function addFontPreview(row, entry)
	local text = _G[row.dropdown:GetName() .. "Text"]
	local refresh = row.Refresh
	row.Refresh = function()
		refresh()
		local value = ns.Get(entry)
		text:SetFontObject(value and previewFonts[value] or ns.Font("GameFontHighlightSmall"))
	end
end

local function addSoundButton(row, entry)
	local play = ui.CreateGlyphButton(row, "play", GLYPH_SIZE, L["Play"])
	play:SetPoint("LEFT", row.dropdown, "RIGHT", -12, 2)
	play:SetScript("OnClick", function()
		ui.PlayAlertSound(ns.Get(entry))
	end)
	ns.BindHighlight(play, row)
	local setEnabled = row.SetEnabled
	row.SetEnabled = function(self, enabled)
		setEnabled(self, enabled)
		ns.SetControlEnabled(play, enabled)
	end
end

local function createPreviewRow(parent, entry)
	if not entry.previewValues then
		entry.previewValues = entry.preview ~= "sound" and previewValues(entry) or entry.values
		entry.values = entry.previewValues
	end
	local row = createDropdownRow(parent, entry)
	if entry.preview == "font" then
		addFontPreview(row, entry)
	elseif entry.preview == "sound" then
		addSoundButton(row, entry)
	end
	return row
end

function creators.select(parent, entry)
	if entry.preview then
		return createPreviewRow(parent, entry)
	end
	if wantsSegmented(entry) then
		local widths, glyphOnly = segmentLayout(entry.values, controlWidth(parent), entry.style == "segmented")
		if widths then
			return createSegmentedRow(parent, entry, widths, glyphOnly)
		end
	end
	return createDropdownRow(parent, entry)
end

local function placeChecks(row, checks, widths, width)
	local total, widest = 0, 0
	for i = 1, #widths do
		total = total + widths[i] + CHECK_GAP
		widest = max(widest, widths[i])
	end
	if total - CHECK_GAP <= width then
		local x = CHECK_X
		for i, check in ipairs(checks) do
			check:SetPoint("LEFT", x, 0)
			x = x + widths[i] + CHECK_GAP
		end
		return 1
	end
	local column = widest + CHECK_GAP
	local columns = max(1, floor((width + CHECK_GAP) / column))
	local top = (ROW_HEIGHT - checks[1]:GetHeight()) / 2
	for i, check in ipairs(checks) do
		local index = i - 1
		check:SetPoint("TOPLEFT", CHECK_X + (index % columns) * column, -top - floor(index / columns) * CHECK_LINE)
	end
	return ceil(#checks / columns)
end

function creators.multiselect(parent, entry)
	local row = ns.CreateRow(parent, entry)
	local checks, widths = {}, {}
	for i, option in ipairs(entry.values) do
		local target = { path = entry.path .. "." .. option[1], type = "toggle", label = option[2], reload = entry.reload }
		local check = ns.CreateCheckButton(row, "InterfaceOptionsSmallCheckButtonTemplate")
		local label = _G[check:GetName() .. "Text"]
		label:SetFontObject(ns.Font("GameFontHighlightSmall"))
		label:SetText(option[2])
		local width = label:GetStringWidth()
		local inset = (check:GetHeight() - CHECK_LINE) / 2
		check:SetHitRectInsets(0, -width, inset, inset)
		check.label = label
		check:SetScript("OnClick", function(self)
			ns.PlayCheckSound(self)
			ns.Set(target, self:GetChecked() and true or false)
		end)
		check:HookScript("OnEnter", function()
			ns.RowEnter(row)
			addOptionTooltip(row, option)
		end)
		check:HookScript("OnLeave", function()
			ns.RowLeave(row)
		end)
		checks[i] = check
		widths[i] = check:GetWidth() + width
	end

	local lines = placeChecks(row, checks, widths, controlWidth(parent) + CONTROL_X - CHECK_X)
	if lines > 1 then
		local height = ROW_HEIGHT + (lines - 1) * CHECK_LINE
		row:SetHeight(max(row:GetHeight(), height))
		local point, relative, relativePoint, x = row.label:GetPoint(1)
		row.label:SetPoint(point, relative, relativePoint, x, (row:GetHeight() - ROW_HEIGHT) / 2)
	end

	row.Refresh = function()
		local value = ns.Get(entry) or {}
		for i, check in ipairs(checks) do
			check:SetChecked(value[entry.values[i][1]])
		end
	end
	row.SetEnabled = function(_, enabled)
		for _, check in ipairs(checks) do
			ns.SetControlEnabled(check, enabled)
			ns.SetTextEnabled(check.label, enabled)
		end
	end
	return row
end

local function showTooltip(owner, title, desc)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if desc then
		GameTooltip:AddLine(desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end
	GameTooltip:Show()
end

local function forwardWheel(frame, delta)
	local scroll = frame:GetParent()
	while scroll and scroll:GetObjectType() ~= "ScrollFrame" do
		scroll = scroll:GetParent()
	end
	local handler = scroll and scroll:GetScript("OnMouseWheel")
	if handler then
		handler(scroll, delta)
	end
end

local function createAxis(row, text, commit)
	local label = row:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(ns.Font("GameFontHighlightSmall"))
	label:SetText(text)
	local box = ns.CreateEditBox(row, VALUE_BOX_WIDTH, true)
	box:SetPoint("LEFT", label, "RIGHT", AXIS_GAP + 6, 0)
	ns.BindRow(box, row)
	box.OnCommit = commit
	box:EnableMouseWheel(true)
	box:SetScript("OnMouseWheel", function(self, delta)
		if not (IsShiftKeyDown() or self.editing) then
			forwardWheel(self, delta)
			return
		end
		local value = tonumber(self:GetText())
		if value then
			self:SetText(tostring(value + delta))
			self.committed = self:GetText()
			commit()
		end
	end)
	return label, box
end

local function setAxisEnabled(label, box, enabled)
	ns.SetEditBoxEnabled(box, enabled)
	ns.SetTextEnabled(label, enabled)
end

local function anchorName(point)
	for _, option in ipairs(ANCHOR_GRID) do
		if option[1] == point then
			return option[2]
		end
	end
	return point
end

local function paintCell(cell)
	local grid = cell.grid
	local color = GRID_COLOR
	if grid.value == cell.option[1] then
		color = GRID_SELECTED_COLOR
	elseif cell.hovered and grid.enabled then
		color = GRID_HOVER_COLOR
	end
	local shade = grid.enabled and 1 or 0.5
	cell.texture:SetVertexColor(color[1] * shade, color[2] * shade, color[3] * shade)
end

local function paintGrid(grid)
	for _, cell in ipairs(grid.cells) do
		paintCell(cell)
	end
end

local function setGridValue(grid, value)
	grid.value = value
	paintGrid(grid)
end

local function setGridEnabled(grid, enabled)
	grid.enabled = enabled and true or false
	for _, cell in ipairs(grid.cells) do
		ns.SetControlEnabled(cell, enabled)
	end
	paintGrid(grid)
end

local function cellEnter(cell)
	cell.hovered = true
	paintCell(cell)
	cell.grid.row.highlight:Show()
	showTooltip(cell, cell.option[2])
end

local function cellLeave(cell)
	cell.hovered = nil
	paintCell(cell)
	cell.grid.row.highlight:Hide()
	GameTooltip:Hide()
end

local function cellClick(cell)
	local grid = cell.grid
	local point = cell.option[1]
	if grid.value == point then
		return
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	grid:SetValue(point)
	grid.onSelect(point)
end

function ns.CreateAnchorGrid(row, onSelect)
	local grid = CreateFrame("Frame", nil, row)
	local step = GRID_CELL + GRID_GAP
	grid:SetSize(GRID_CELL * 3 + GRID_GAP * 2, GRID_CELL * 3 + GRID_GAP * 2)
	grid.row = row
	grid.cells = {}
	grid.enabled = true
	grid.onSelect = onSelect
	grid.SetValue = setGridValue
	grid.SetEnabled = setGridEnabled
	for i, option in ipairs(ANCHOR_GRID) do
		local cell = CreateFrame("Button", nil, grid)
		cell:SetSize(GRID_CELL, GRID_CELL)
		cell:SetPoint("TOPLEFT", ((i - 1) % 3) * step, -floor((i - 1) / 3) * step)
		cell:SetHitRectInsets(-GRID_GAP / 2, -GRID_GAP / 2, -GRID_GAP / 2, -GRID_GAP / 2)
		local texture = cell:CreateTexture(nil, "ARTWORK")
		texture:SetTexture(ui.Media.blank)
		texture:SetAllPoints()
		cell.texture = texture
		cell.grid = grid
		cell.option = option
		cell:SetScript("OnEnter", cellEnter)
		cell:SetScript("OnLeave", cellLeave)
		cell:SetScript("OnClick", cellClick)
		grid.cells[i] = cell
	end
	paintGrid(grid)
	return grid
end

function creators.point(parent, entry)
	local row = ns.CreateRow(parent, entry)
	row:SetHeight(max(row:GetHeight(), GRID_ROW_HEIGHT))
	local grid, xBox, yBox

	local function commit()
		local x, y = tonumber(xBox:GetText()), tonumber(yBox:GetText())
		if not x or not y then
			row.Refresh()
			return
		end
		x, y = floor(x + 0.5), floor(y + 0.5)
		local value = ns.Get(entry)
		local point = grid.value
		if point ~= value[1] or x ~= value[2] or y ~= value[3] then
			ui:SetConfig(entry.path, { point, x, y, value[4], value[5] })
		end
	end

	grid = ns.CreateAnchorGrid(row, commit)
	grid:SetPoint("LEFT", CONTROL_X, 0)
	local xLabel, yLabel
	xLabel, xBox = createAxis(row, "X", commit)
	xLabel:SetPoint("LEFT", grid, "RIGHT", 12, 0)
	yLabel, yBox = createAxis(row, "Y", commit)
	yLabel:SetPoint("LEFT", xBox, "RIGHT", 10, 0)

	local anchor = row:CreateFontString(nil, "ARTWORK")
	anchor:SetFontObject(ns.Font("GameFontGreenSmall"))
	anchor:SetWidth(CONTROL_X - 100)
	anchor:SetJustifyH("RIGHT")
	anchor:SetPoint("RIGHT", row, "LEFT", CONTROL_X - 16, 0)

	local detach = ui.CreateGlyphButton(row, "link-slash", GLYPH_SIZE, L["Detach"])
	detach:SetPoint("LEFT", yBox, "RIGHT", 6, 0)
	detach:SetScript("OnClick", function()
		ui.Movers.Detach(entry.path)
		row.Refresh()
	end)
	ns.BindHighlight(detach, row)

	row.Refresh = function()
		local point, x, y, anchorPath, anchorPoint = ui.UnpackPoint(ns.Get(entry))
		grid:SetValue(point)
		xBox:SetText(tostring(x))
		yBox:SetText(tostring(y))
		xBox:SetCursorPosition(0)
		yBox:SetCursorPosition(0)
		if anchorPath then
			local anchorLabel = ui.Movers.GetLabel(anchorPath)
			anchor:SetText(L["of %s"]:format(anchorLabel))
			detach.tooltipText = L["Offsets are relative to %s, point: %s."]:format(anchorLabel, anchorName(anchorPoint))
			detach:Show()
		else
			anchor:SetText(anchorPoint and anchorPoint ~= point and L["of screen %s"]:format(anchorName(anchorPoint)) or "")
			detach:Hide()
		end
	end
	row.SetEnabled = function(_, enabled)
		grid:SetEnabled(enabled)
		setAxisEnabled(xLabel, xBox, enabled)
		setAxisEnabled(yLabel, yBox, enabled)
		ns.SetControlEnabled(detach, enabled)
	end
	return row
end

function creators.offset(parent, entry)
	local row = ns.CreateRow(parent, entry)
	local targets = { { path = entry.path, reload = entry.reload }, { path = entry.pathY, reload = entry.reload } }
	local labels, boxes = {}, {}
	for i, axis in ipairs({ "X", "Y" }) do
		labels[i], boxes[i] = createAxis(row, axis, function()
			local value = tonumber(boxes[i]:GetText())
			if value then
				ns.Set(targets[i], max(entry.min, min(entry.max, floor(value + 0.5))))
			end
			row.Refresh()
		end)
	end
	labels[1]:SetPoint("LEFT", CONTROL_X + 4, 0)
	labels[2]:SetPoint("LEFT", boxes[1], "RIGHT", 12, 0)

	row.Refresh = function()
		for i, box in ipairs(boxes) do
			if not box.editing then
				box:SetText(tostring(ns.Get(targets[i]) or 0))
				box:SetCursorPosition(0)
			end
		end
	end
	row.SetEnabled = function(_, enabled)
		for i = 1, 2 do
			setAxisEnabled(labels[i], boxes[i], enabled)
		end
	end
	return row
end

local function confirmText(action, value)
	local confirm = action.confirm
	if type(confirm) == "function" then
		return confirm(value)
	end
	return confirm and confirm:format(value)
end

function creators.choice(parent, entry)
	local row = ns.CreateRow(parent, entry)
	local values = entry.values
	local getValues = type(values) == "function" and values or function()
		return values
	end
	local selected
	local enabled = true
	local buttons = {}

	local function updateButtons()
		for _, button in ipairs(buttons) do
			ns.SetControlEnabled(button, enabled and selected ~= nil)
		end
	end

	local dropdown = ns.CreateDropdown(row, entry.width or 140, getValues, function(value)
		selected = value
		updateButtons()
	end)
	dropdown:SetPoint("LEFT", CONTROL_X - 16, -2)
	ns.BindRow(_G[dropdown:GetName() .. "Button"], row)

	local anchor, x, y = dropdown, -12, 2
	for i, action in ipairs(entry.actions) do
		local button = ns.CreateButton(row, " ", ACTION_BUTTON_WIDTH, action.confirm ~= nil, 22, action.glyph)
		button:SetWidth(ACTION_BUTTON_WIDTH)
		button.glyph:ClearAllPoints()
		button.glyph:SetPoint("CENTER")
		button:SetPoint("LEFT", anchor, "RIGHT", x, y)
		anchor, x, y = button, ACTION_GAP, 0
		button:HookScript("OnEnter", function(self)
			row.highlight:Show()
			showTooltip(self, action.text, action.desc)
		end)
		button:HookScript("OnLeave", function()
			row.highlight:Hide()
			GameTooltip:Hide()
		end)
		button:SetScript("OnClick", function()
			local value = selected
			if value == nil then
				return
			end
			local function run()
				action.func(value)
				ns.RefreshPage()
			end
			local text = confirmText(action, value)
			if text then
				ns.Confirm(text, run)
			else
				run()
			end
		end)
		buttons[i] = button
	end

	row.Refresh = function()
		if selected ~= nil then
			local found = false
			for _, option in ipairs(getValues()) do
				if option[1] == selected then
					found = true
					break
				end
			end
			if not found then
				selected = nil
			end
		end
		dropdown:Select(selected)
		if selected == nil then
			UIDropDownMenu_SetText(dropdown, entry.placeholder or "")
		end
		updateButtons()
	end
	row.SetEnabled = function(_, value)
		enabled = value
		dropdown:SetEnabled(value)
		updateButtons()
	end
	return row
end

local createHeader = creators.header

local function groupState(entries)
	local on = 0
	for _, entry in ipairs(entries) do
		if ns.Get(entry) then
			on = on + 1
		end
	end
	if on == 0 then
		return false
	elseif on == #entries then
		return true
	end
end

local MOVE_BUTTON_WIDTH = 96

local function addMoveButton(header, entry)
	local element = entry.element
	local button = ns.CreateButton(header, L["Move"], MOVE_BUTTON_WIDTH, true, 18, "up-down-left-right")
	button:SetPoint("BOTTOMRIGHT", -4, 2)
	button:SetScript("OnClick", function()
		ns.EditElement(element.path)
	end)
	button:SetScript("OnEnter", function(self)
		showTooltip(self, L["Move"], L["Open this frame in move mode; the window next to it holds its size and position settings."])
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	header.line:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -4, 2)
	header.moveButton = button
	if header.Refresh then
		local setEnabled = header.SetEnabled
		header.SetEnabled = function(self, enabled)
			setEnabled(self, enabled)
			ns.SetControlEnabled(button, enabled)
		end
		return
	end
	header.entry = entry
	header.label = header:CreateFontString(nil, "ARTWORK")
	header.label:SetFontObject(ns.Font("GameFontHighlightSmall"))
	header.label:Hide()
	header.Refresh = function() end
	header.SetEnabled = function(_, enabled)
		ns.SetControlEnabled(button, enabled)
	end
end

function creators.header(parent, entry)
	local header = createHeader(parent, entry)
	local toggles = entry.toggles
	if not toggles then
		if entry.element then
			addMoveButton(header, entry)
		end
		return header
	end
	local check = ns.CreateCheckButton(header)
	check:SetPoint("BOTTOMLEFT", CHECK_X, 0)
	local dash = ui.CreateGlyph(check, "minus", GLYPH_SIZE, "OVERLAY")
	dash:SetPoint("CENTER", 0, 1)
	check:SetScript("OnClick", function(self)
		local value = groupState(toggles) ~= true
		self:SetChecked(value)
		ns.PlayCheckSound(self)
		for _, toggle in ipairs(toggles) do
			ns.Set(toggle, value)
		end
	end)
	check:SetScript("OnEnter", function(self)
		showTooltip(self, entry.header, entry.toggleDesc)
	end)
	check:SetScript("OnLeave", GameTooltip_Hide)
	header.line:SetPoint("BOTTOMRIGHT", header, "BOTTOMLEFT", CHECK_X - 4, 4)

	local label = header:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(ns.Font("GameFontHighlightSmall"))
	label:Hide()
	header.entry = entry
	header.label = label
	header.Refresh = function()
		local state = groupState(toggles)
		check:SetChecked(state == true)
		ui.SetShown(dash, state == nil)
	end
	header.SetEnabled = function(_, enabled)
		ns.SetControlEnabled(check, enabled)
		local color = enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
		dash:SetTextColor(color.r, color.g, color.b)
	end
	if entry.element then
		addMoveButton(header, entry)
	end
	return header
end

local LAYOUT_TYPES = { point = true, offset = true }
local LAYOUT_KEYS = {
	"size",
	"width",
	"height",
	"scale",
	"spacing",
	"padding",
	"gap",
	"column",
	"perrow",
	"rows?$",
	"^buttons$",
	"max$",
	"^max",
	"grow",
	"direction",
	"orientation",
	"anchor",
	"offset",
	"attach",
	"position",
}
local NOT_LAYOUT_KEYS = { "font", "text", "border" }

function ns.IsLayoutEntry(entry)
	if entry.layout ~= nil then
		return entry.layout
	elseif LAYOUT_TYPES[entry.type] then
		return true
	elseif not entry.path or entry.type == "font" or entry.type == "color" then
		return false
	end
	local key = entry.path:match("[^.]+$"):lower()
	for _, word in ipairs(NOT_LAYOUT_KEYS) do
		if key:find(word) then
			return false
		end
	end
	for _, word in ipairs(LAYOUT_KEYS) do
		if key:find(word) then
			return true
		end
	end
	return false
end

function ns.FindEntry(page, path)
	local schemas = { page.schema }
	for _, tab in ipairs(page.tabs or {}) do
		schemas[#schemas + 1] = tab.schema
	end
	for _, schema in ipairs(schemas) do
		for _, entry in ipairs(schema) do
			if entry.path == path then
				return entry
			end
		end
	end
end

local TAG_BUTTON_GAP = 8
local TAG_PREVIEW_HEIGHT = 14
local TAG_LINE = 16
local TAG_HEADER = 18
local TAG_PADDING = 6
local TAG_NAME_WIDTH = 76
local TAG_POPOVER_WIDTH = 300
local TAG_POPOVER_COLOR = { 0.05, 0.05, 0.05, 0.95 }

local tagPopover

local function modifierOffset(text, cursor)
	local offset
	local position = 1
	while true do
		local start, stop = text:find("%[[^%[%]]*%]", position)
		if not start or start > cursor then
			break
		end
		offset = stop - 1
		position = stop + 1
	end
	return offset
end

local function insertTagText(row, insert, offset)
	local box = row.box
	local text = box:GetText()
	local value = text:sub(1, offset) .. insert .. text:sub(offset + 1)
	if #value > (row.entry.maxLetters or 24) then
		return
	end
	box:SetFocus()
	box:SetText(value)
	box:SetCursorPosition(offset + #insert)
	row.tagCursor = offset + #insert
	box:OnCommit()
	box.committed = value
end

local function insertTag(row, option, modifier)
	local text = row.box:GetText()
	local cursor = min(row.tagCursor or #text, #text)
	if not modifier then
		insertTagText(row, "[" .. option[1] .. "]", cursor)
		return
	end
	local offset = modifierOffset(text, cursor)
	if offset then
		insertTagText(row, ":" .. option[1], offset)
	else
		insertTagText(row, ("[%s:%s]"):format(row.entry.tags[1][1], option[1]), cursor)
	end
end

local function tagItemEnter(item)
	item.highlight:Show()
end

local function tagItemLeave(item)
	item.highlight:Hide()
end

local function tagItemClick(item)
	PlaySound("igMainMenuOptionCheckBoxOn")
	insertTag(tagPopover.row, item.option, item.modifier)
end

local function createTagItem(popover)
	local item = CreateFrame("Button", nil, popover)
	item:SetHeight(TAG_LINE)
	local highlight = item:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(ui.Media.blank)
	highlight:SetVertexColor(SELECTED_COLOR[1], SELECTED_COLOR[2], SELECTED_COLOR[3], SELECTED_COLOR[4])
	highlight:SetAllPoints()
	highlight:Hide()
	item.highlight = highlight
	local name = item:CreateFontString(nil, "ARTWORK")
	name:SetFontObject(ns.Font("GameFontNormalSmall"))
	name:SetJustifyH("LEFT")
	name:SetWidth(TAG_NAME_WIDTH)
	name:SetPoint("LEFT", 4, 0)
	item.name = name
	local desc = item:CreateFontString(nil, "ARTWORK")
	desc:SetFontObject(ns.Font("GameFontHighlightSmall"))
	desc:SetJustifyH("LEFT")
	desc:SetHeight(TAG_LINE)
	desc:SetPoint("LEFT", name, "RIGHT", 4, 0)
	desc:SetPoint("RIGHT", -4, 0)
	item.desc = desc
	item:SetScript("OnEnter", tagItemEnter)
	item:SetScript("OnLeave", tagItemLeave)
	item:SetScript("OnClick", tagItemClick)
	return item
end

local function placeTagSection(popover, title, options, modifier, y)
	if not options then
		return y
	end
	local index = #popover.shownHeaders + 1
	local header = popover.headers[index]
	if not header then
		header = popover:CreateFontString(nil, "ARTWORK")
		header:SetFontObject(ns.Font("GameFontDisableSmall"))
		popover.headers[index] = header
	end
	header:SetText(title)
	header:SetPoint("TOPLEFT", TAG_PADDING + 4, y - 4)
	header:Show()
	popover.shownHeaders[index] = header
	y = y - TAG_HEADER
	for _, option in ipairs(options) do
		local count = popover.shownItems + 1
		popover.shownItems = count
		local item = popover.items[count]
		if not item then
			item = createTagItem(popover)
			popover.items[count] = item
		end
		item.option = option
		item.modifier = modifier
		item.name:SetText(modifier and ":" .. option[1] or "[" .. option[1] .. "]")
		item.desc:SetText(option[2])
		item:SetPoint("TOPLEFT", TAG_PADDING, y)
		item:SetPoint("RIGHT", -TAG_PADDING, 0)
		item:Show()
		y = y - TAG_LINE
	end
	return y
end

local function layoutTagPopover(popover, entry)
	for _, item in ipairs(popover.items) do
		item:Hide()
	end
	for _, header in ipairs(popover.headers) do
		header:Hide()
	end
	wipe(popover.shownHeaders)
	popover.shownItems = 0
	local y = placeTagSection(popover, L["Tags"], entry.tags, false, -TAG_PADDING)
	y = placeTagSection(popover, L["Tag options"], entry.modifiers, true, y)
	popover:SetHeight(TAG_PADDING - y)
end

local function tagPopoverUpdate(popover)
	if
		(IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
		and not MouseIsOver(popover)
		and not MouseIsOver(popover.button)
	then
		popover:Hide()
	end
end

local function createTagPopover()
	local popover = CreateFrame("Frame", nil, UIParent)
	popover:SetFrameStrata("FULLSCREEN_DIALOG")
	popover:SetWidth(TAG_POPOVER_WIDTH)
	popover:SetBackdrop(ui.CreateBackdrop(8))
	popover:SetBackdropColor(unpack(TAG_POPOVER_COLOR))
	popover:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3])
	popover:SetClampedToScreen(true)
	popover:EnableMouse(true)
	popover:Hide()
	popover.items = {}
	popover.headers = {}
	popover.shownHeaders = {}
	popover.shownItems = 0
	popover:SetScript("OnUpdate", tagPopoverUpdate)
	tagPopover = popover
	return popover
end

local function hideTagPopover(row)
	if tagPopover and tagPopover.row == row then
		tagPopover:Hide()
	end
end

local function toggleTagPopover(row, button)
	local popover = tagPopover or createTagPopover()
	if popover:IsShown() and popover.row == row then
		popover:Hide()
		return
	end
	if popover.entry ~= row.entry then
		layoutTagPopover(popover, row.entry)
		popover.entry = row.entry
	end
	popover.row = row
	popover.button = button
	local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
	popover:SetScale(scale)
	popover:ClearAllPoints()
	local below = button:GetBottom()
	if below < popover:GetHeight() + 2 and UIParent:GetHeight() / scale - button:GetTop() > below then
		popover:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 2)
	else
		popover:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
	end
	popover:Show()
end

local function updateTagPreview(row, text)
	local preview = row.tagPreview
	local rendered = text ~= "" and row.entry.render(text) or ""
	if rendered == "" then
		preview:SetText(L["(empty)"])
		preview:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	else
		preview:SetText(rendered)
		preview:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
end

local createStringRow = creators.string

local function createTagRow(parent, entry)
	local row = createStringRow(parent, entry)
	local box = row.box
	local height = max(row:GetHeight(), ROW_HEIGHT + TAG_PREVIEW_HEIGHT)
	local top = (height - ROW_HEIGHT) / 2
	row:SetHeight(height)
	box:ClearAllPoints()
	box:SetPoint("LEFT", CONTROL_X + 6, top)
	local point, relative, relativePoint, x = row.label:GetPoint(1)
	row.label:SetPoint(point, relative, relativePoint, x, top)
	if row.resetButton then
		row.resetButton:ClearAllPoints()
		row.resetButton:SetPoint("RIGHT", -4, top)
	end

	local button = ui.CreateGlyphButton(row, "tags", GLYPH_SIZE, L["Tags"])
	button.tooltipText = L["Insert a tag at the cursor."]
	button:SetPoint("LEFT", box, "RIGHT", TAG_BUTTON_GAP, 0)
	button:SetScript("OnClick", function(self)
		toggleTagPopover(row, self)
	end)
	ns.BindHighlight(button, row)

	local preview = row:CreateFontString(nil, "ARTWORK")
	preview:SetFontObject(ns.Font("GameFontHighlightSmall"))
	preview:SetJustifyH("LEFT")
	preview:SetHeight(TAG_PREVIEW_HEIGHT)
	preview:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -1)
	preview:SetPoint("RIGHT", button, "RIGHT")
	row.tagPreview = preview

	box:HookScript("OnCursorChanged", function(self)
		if self.editing then
			row.tagCursor = self:GetCursorPosition()
		end
	end)
	box:HookScript("OnTextChanged", function(self)
		local text = self:GetText()
		updateTagPreview(row, text)
		if self.editing then
			ns.ValidateRow(row, self, text)
		end
	end)
	row:HookScript("OnHide", hideTagPopover)

	local refresh = row.Refresh
	row.Refresh = function()
		refresh()
		updateTagPreview(row, box:GetText())
	end
	local setEnabled = row.SetEnabled
	row.SetEnabled = function(self, enabled)
		setEnabled(self, enabled)
		ns.SetControlEnabled(button, enabled)
		preview:SetAlpha(enabled and 1 or 0.5)
		if not enabled then
			hideTagPopover(row)
		end
	end
	return row
end

function creators.string(parent, entry)
	if entry.tags then
		return createTagRow(parent, entry)
	end
	return createStringRow(parent, entry)
end
