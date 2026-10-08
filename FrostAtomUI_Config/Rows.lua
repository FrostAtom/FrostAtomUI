local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local P = ns.private
local CONTROL_X = P.CONTROL_X
local FONT_SIZE = P.FONT_SIZE
local FONT_SLIDER_WIDTH = P.FONT_SLIDER_WIDTH
local GLYPH_BOX = P.GLYPH_BOX
local GLYPH_GAP = P.GLYPH_GAP
local GLYPH_SIZE = P.GLYPH_SIZE
local HEADER_HEIGHT = P.HEADER_HEIGHT
local LABEL_X = P.LABEL_X
local OUTLINES = P.OUTLINES
local POPUP_STRATA = P.POPUP_STRATA
local ROW_HEIGHT = P.ROW_HEIGHT
local SLIDER_WIDTH = P.SLIDER_WIDTH
local TEXTURE = P.TEXTURE
local addNewBadge = P.addNewBadge
local bindHighlight = P.bindHighlight
local bindRow = P.bindRow
local changes = P.changes
local createButton = P.createButton
local createCheckButton = P.createCheckButton
local createDropdown = P.createDropdown
local createEditBox = P.createEditBox
local createGlyph = P.createGlyph
local createRow = P.createRow
local createSliderBox = P.createSliderBox
local createSpacerLine = P.createSpacerLine
local font = P.font
local forwardWheel = P.forwardWheel
local get = P.get
local isNewEntry = P.isNewEntry
local playCheckSound = P.playCheckSound
local rowEnter = P.rowEnter
local rowLeave = P.rowLeave
local set = P.set
local setControlEnabled = P.setControlEnabled
local setEditBoxEnabled = P.setEditBoxEnabled
local setTextEnabled = P.setTextEnabled
local showTooltip = P.showTooltip

local creators = {}
ns.creators = creators
ns.ROW_HEIGHT = ROW_HEIGHT
ns.CreateRow = createRow
ns.Get = get
ns.Set = set
ns.RowEnter = rowEnter
ns.RowLeave = rowLeave
ns.CreateCheckButton = createCheckButton
ns.PlayCheckSound = playCheckSound
ns.SetControlEnabled = setControlEnabled
ns.SetTextEnabled = setTextEnabled
ns.CreateEditBox = createEditBox
ns.SetEditBoxEnabled = setEditBoxEnabled
ns.CreateDropdown = createDropdown
ns.BindRow = bindRow
ns.BindHighlight = bindHighlight
ns.ValidateRow = changes.Validate
ns.ShowTooltip = showTooltip
ns.ForwardWheel = forwardWheel

local function noop() end

function creators.header(parent, entry)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(HEADER_HEIGHT)
	header:SetPoint("LEFT")
	header:SetPoint("RIGHT")

	local x = 4
	local label = header:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(font("GameFontNormal"))
	label:SetText(entry.header)
	if entry.glyph then
		local glyph = createGlyph(header, entry.glyph, GLYPH_SIZE, NORMAL_FONT_COLOR)
		glyph:SetPoint("CENTER", label, "LEFT", -GLYPH_GAP - GLYPH_BOX / 2, 0)
		x = x + GLYPH_BOX + GLYPH_GAP
	end
	label:SetPoint("BOTTOMLEFT", x, 6)
	local width = label:GetStringWidth()
	if isNewEntry(entry) then
		local badge = addNewBadge(header, label, width + 6)
		width = width + 6 + badge:GetStringWidth()
	end

	local line = createSpacerLine(header)
	line:SetPoint("BOTTOMLEFT", x + width + 8, 4)
	line:SetPoint("BOTTOMRIGHT", -4, 4)
	header.line = line
	return header
end

function creators.description(parent, entry)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("LEFT")
	holder:SetPoint("RIGHT")

	local text = holder:CreateFontString(nil, "ARTWORK")
	text:SetFontObject(font("GameFontHighlightSmall"))
	text:SetPoint("TOPLEFT", LABEL_X, -2)
	text:SetWidth(parent:GetWidth() - LABEL_X * 2)
	text:SetJustifyH("LEFT")
	text:SetText(entry.description)
	holder:SetHeight(text:GetStringHeight() + 8)
	return holder
end

function creators.toggle(parent, entry)
	local row = createRow(parent, entry)

	local check = createCheckButton(row)
	check:SetPoint("LEFT", CONTROL_X - 4, 0)
	check:SetScript("OnClick", function(self)
		local value = self:GetChecked() and true or false
		playCheckSound(self)
		set(entry, value)
		if entry.onClick then
			entry.onClick(value)
		end
	end)
	bindRow(check, row)
	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and check:IsEnabled() == 1 then
			check:Click()
		end
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
	local _, refresh, setEnabled = createSliderBox(row, entry, SLIDER_WIDTH)
	row.Refresh = refresh
	row.SetEnabled = function(_, enabled)
		setEnabled(enabled)
	end
	return row
end

function creators.string(parent, entry)
	local row = createRow(parent, entry)
	local box = createEditBox(row, entry.width or 200)
	box:SetPoint("LEFT", CONTROL_X + 6, 0)
	box:SetMaxLetters(entry.maxLetters or 24)
	row.box = box
	box.OnCommit = function(self)
		local text = self:GetText()
		if changes.Validate(row, self, text, true) then
			set(entry, text)
		end
	end
	box.OnCancel = function(self)
		changes.Validate(row, self)
		row.Refresh()
	end
	bindRow(box, row)
	row.Refresh = function()
		if box.editing or (row.problem and row.problem.rejected) then
			return
		end
		local text = get(entry) or ""
		box:SetText(text)
		box:SetCursorPosition(0)
		changes.Validate(row, box, text)
	end
	row.SetEnabled = function(_, enabled)
		setEditBoxEnabled(box, enabled)
	end
	return row
end

function creators.input(parent, entry)
	local row = createRow(parent, entry)
	local box = createEditBox(row, entry.width or 160)
	box:SetPoint("LEFT", CONTROL_X + 6, 0)
	box:SetMaxLetters(entry.maxLetters or 32)
	local button = createButton(row, entry.text or L["Save"], 80, nil, nil, entry.glyph)
	button:SetPoint("LEFT", box, "RIGHT", 8, 0)
	bindRow(box, row)
	bindRow(button, row)

	local function submit()
		local text = strtrim(box:GetText())
		if text ~= "" and changes.Validate(row, box, text, true) then
			box:SetText("")
			entry.func(text)
		end
	end
	box:SetScript("OnEnterPressed", function(self)
		submit()
		self:ClearFocus()
	end)
	box.OnCancel = function(self)
		self:SetText("")
		changes.Validate(row, self)
	end
	button:SetScript("OnClick", submit)

	row.Refresh = noop
	row.SetEnabled = function(_, enabled)
		setEditBoxEnabled(box, enabled)
		setControlEnabled(button, enabled)
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
		row.Refresh()
	end)
	dropdown:SetPoint("LEFT", CONTROL_X - 16, -2)
	bindRow(_G[dropdown:GetName() .. "Button"], row)
	row.dropdown = dropdown

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
	local sizeEntry = { path = entry.path .. ".size", min = FONT_SIZE.MIN, max = FONT_SIZE.MAX, step = 1 }
	local outlineEntry = { path = entry.path .. ".outline" }

	local box, refreshSize, setSizeEnabled = createSliderBox(row, sizeEntry, FONT_SLIDER_WIDTH)

	local dropdown = createDropdown(row, 80, function()
		return OUTLINES
	end, function(value)
		set(outlineEntry, value)
	end)
	dropdown:SetPoint("LEFT", box, "RIGHT", -8, -2)
	bindRow(_G[dropdown:GetName() .. "Button"], row)

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

local function addSquare(parent, layer, size, point, x, y, r, g, b)
	local square = parent:CreateTexture(nil, layer)
	square:SetTexture(r, g, b)
	square:SetSize(size, size)
	square:SetPoint(point, x, y)
	return square
end

function creators.color(parent, entry)
	local row = createRow(parent, entry)

	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(16, 16)
	swatch:SetPoint("LEFT", CONTROL_X + 2, 0)
	swatch:SetNormalTexture(TEXTURE.SWATCH)
	local fill = swatch:GetNormalTexture()
	local background = addSquare(swatch, "BACKGROUND", 14, "CENTER", 0, 0, 1, 1, 1)
	if entry.alpha then
		addSquare(swatch, "BORDER", 6, "TOPRIGHT", -2, -2, 0.6, 0.6, 0.6)
		addSquare(swatch, "BORDER", 6, "BOTTOMLEFT", 2, 2, 0.6, 0.6, 0.6)
	end
	swatch:SetScript("OnEnter", function()
		background:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		rowEnter(row)
	end)
	swatch:SetScript("OnLeave", function()
		background:SetVertexColor(1, 1, 1)
		rowLeave(row)
	end)

	local hex = row:CreateFontString(nil, "ARTWORK")
	hex:SetFontObject(font("GameFontHighlightSmall"))
	hex:SetPoint("LEFT", swatch, "RIGHT", 8, 0)

	local function current()
		local color = get(entry)
		return color[1], color[2], color[3], color[4] or 1
	end

	local function apply(r, g, b, a)
		local color = get(entry)
		if r ~= color[1] or g ~= color[2] or b ~= color[3] or (entry.alpha and a ~= (color[4] or 1)) then
			set(entry, entry.alpha and { r, g, b, a } or { r, g, b })
		end
	end

	local function paint()
		local r, g, b, a = current()
		if swatch:IsEnabled() ~= 1 then
			r = r * 0.3 + g * 0.59 + b * 0.11
			g, b = r, r
		end
		fill:SetVertexColor(r, g, b, a)
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

	row.Refresh = function()
		local r, g, b = current()
		paint()
		hex:SetText(("%02x%02x%02x"):format(r * 255, g * 255, b * 255))
	end
	row.SetEnabled = function(_, enabled)
		setControlEnabled(swatch, enabled)
		setTextEnabled(hex, enabled)
		paint()
	end
	return row
end

function creators.execute(parent, entry)
	local row = createRow(parent, entry)
	local button =
		createButton(row, entry.text or entry.label, entry.width or 140, entry.confirm ~= nil, nil, entry.glyph)
	button:SetPoint("LEFT", CONTROL_X, 0)
	button:SetScript("OnClick", function()
		if entry.confirm then
			ns.Confirm(type(entry.confirm) == "function" and entry.confirm() or entry.confirm, entry.func)
		else
			entry.func()
		end
	end)
	bindRow(button, row)
	row.Refresh = noop
	row.SetEnabled = function(_, enabled)
		setControlEnabled(button, enabled)
	end
	return row
end

do
	local IGNORED_KEYS = {
		LSHIFT = true,
		RSHIFT = true,
		LCTRL = true,
		RCTRL = true,
		LALT = true,
		RALT = true,
		UNKNOWN = true,
	}

	local MOUSE_KEYS = {
		LeftButton = "BUTTON1",
		RightButton = "BUTTON2",
		MiddleButton = "BUTTON3",
	}

	local function keyCombo(key)
		local combo = MOUSE_KEYS[key] or (key:find("^Button%d+$") and key:upper()) or key
		if IsShiftKeyDown() then
			combo = "SHIFT-" .. combo
		end
		if IsControlKeyDown() then
			combo = "CTRL-" .. combo
		end
		if IsAltKeyDown() then
			combo = "ALT-" .. combo
		end
		return combo
	end

	local function keysText(action)
		local keys = { GetBindingKey(action) }
		if #keys == 0 then
			return GRAY_FONT_COLOR_CODE .. L["Not bound"] .. FONT_COLOR_CODE_CLOSE
		end
		for i = 1, #keys do
			keys[i] = GetBindingText(keys[i], "KEY_")
		end
		return table.concat(keys, ", ")
	end

	local function clearBinding(action)
		local key = GetBindingKey(action)
		while key do
			SetBinding(key)
			key = GetBindingKey(action)
		end
	end

	function creators.keybind(parent, entry)
		local row = createRow(parent, entry)
		local action = entry.binding

		local button = createButton(row, keysText(action), entry.width or 160, true)
		button:SetPoint("LEFT", CONTROL_X, 0)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:GetFontString():SetWidth((entry.width or 160) - 12)
		bindRow(button, row)

		local catcher = CreateFrame("Button", nil, button)
		catcher:SetAllPoints()
		catcher:Hide()
		catcher:EnableKeyboard(true)
		catcher:EnableMouseWheel(true)
		catcher:RegisterForClicks("AnyUp")

		local function stopCapture()
			catcher:Hide()
			row.Refresh()
		end

		local function bindKey(key)
			local combo = keyCombo(key)
			if InCombatLockdown() or combo == "BUTTON1" or combo == "BUTTON2" then
				stopCapture()
				return
			end
			local previous = GetBindingAction(combo)
			if previous and previous ~= "" and previous ~= action then
				ui.Print(
					L["%s was unbound from %s"],
					GetBindingText(combo, "KEY_"),
					GetBindingText(previous, "BINDING_NAME_")
				)
			end
			clearBinding(action)
			SetBinding(combo, action)
			SaveBindings(GetCurrentBindingSet())
			stopCapture()
		end

		catcher:SetScript("OnKeyDown", function(_, key)
			if key == "ESCAPE" then
				stopCapture()
			elseif not IGNORED_KEYS[key] then
				bindKey(key)
			end
		end)
		catcher:SetScript("OnMouseDown", function(_, mouse)
			bindKey(mouse)
		end)
		catcher:SetScript("OnMouseWheel", function(_, delta)
			bindKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
		end)
		catcher:SetScript("OnHide", function()
			button:UnlockHighlight()
		end)

		button:SetScript("OnClick", function(_, mouse)
			if InCombatLockdown() then
				ui.Print(L["cannot change bindings in combat"])
				return
			end
			if mouse == "RightButton" then
				clearBinding(action)
				SaveBindings(GetCurrentBindingSet())
				row.Refresh()
				return
			end
			button:LockHighlight()
			button:SetText(NORMAL_FONT_COLOR_CODE .. L["Press a key..."] .. FONT_COLOR_CODE_CLOSE)
			catcher:Show()
		end)

		row.Refresh = function()
			if not catcher:IsShown() then
				button:SetText(keysText(action))
			end
		end
		row.SetEnabled = function(_, enabled)
			if not enabled then
				catcher:Hide()
			end
			setControlEnabled(button, enabled)
		end
		return row
	end
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

P.creators = creators
