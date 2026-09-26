local ADDON_NAME, ns = ...

local max = math.max
local tinsert = tinsert

local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local DIALOG_CORNER = "Interface\\DialogFrame\\UI-DialogBox-Corner"
local DIALOG_DIVIDER = "Interface\\DialogFrame\\UI-DialogBox-Divider"
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local TOOLTIP_BACKGROUND = "Interface\\Tooltips\\UI-Tooltip-Background"
local CLOSE_UP = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"
local CLOSE_DOWN = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down"
local CLOSE_HIGHLIGHT = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight"
local SCROLL_TRACK = "Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar"

local BACKGROUNDS = {
	normal = "Interface\\DialogFrame\\UI-DialogBox-Background",
	dark = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	gold = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
}

local WINDOW_INSET = { left = 16, right = 16, top = 36, bottom = 16 }
local GEAR_INSET = { left = 12, right = 10, top = 30, bottom = 12 }
ns.WINDOW_INSET = WINDOW_INSET

local HEADER_HEIGHT = 40
local HEADER_CAP = 14
local HEADER_PADDING = 36
local HEADER_MIN_WIDTH = 100

local PLACEHOLDER_GLYPH_SIZE = 9
local PLACEHOLDER_GLYPH_GAP = 4

local TAB_TEMPLATES = {
	bottom = "CharacterFrameTabButtonTemplate",
	top = "OptionsFrameTabButtonTemplate",
	tall = "TabButtonTemplate",
}
local TAB_OVERLAP = { bottom = -15, top = -16, tall = 0 }

local INSET_STYLES = {
	box = { border = { 0.4, 0.4, 0.4, 1 } },
	panel = { border = { 0.6, 0.6, 0.6, 1 } },
	list = { border = { 0.6, 0.6, 0.6, 1 } },
	dark = { border = { 1, 1, 1, 0.5 }, background = { 0.09, 0.09, 0.19, 1 } },
	tooltip = { border = { 1, 1, 1, 1 }, background = { 0, 0, 0, 0.6 } },
}

local HIGHLIGHTS = {
	list = { "Interface\\QuestFrame\\UI-QuestTitleHighlight" },
	category = { "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", 0.196, 0.388, 0.8 },
	listbox = { "Interface\\Buttons\\UI-Listbox-Highlight2", 0.11, 0.325, 0.48 },
	square = { "Interface\\Buttons\\ButtonHilight-Square" },
}

local SLOT_BACKGROUNDS = {
	empty = { "Interface\\Buttons\\UI-EmptySlot-Disabled", 45 / 36, 0, -1, 0.140625, 0.84375, 0.140625, 0.84375 },
	slot = { "Interface\\Buttons\\UI-EmptySlot", 64 / 37, 0, 0 },
	spell = { "Interface\\Spellbook\\UI-Spellbook-SpellBackground", 64 / 37, 29 / 37, -29 / 37 },
}

local widgetCount = 0

local function widgetName(name)
	if name then
		return name
	end
	widgetCount = widgetCount + 1
	return ADDON_NAME .. "Widget" .. widgetCount
end
ns.WidgetName = widgetName

local function backdrop(bgFile, edgeFile, edgeSize, tileSize, left, right, top, bottom)
	return {
		bgFile = bgFile,
		edgeFile = edgeFile,
		tile = true,
		tileSize = tileSize,
		edgeSize = edgeSize,
		insets = { left = left, right = right, top = top, bottom = bottom },
	}
end

local windowBackdrops = {}
for key, file in pairs(BACKGROUNDS) do
	windowBackdrops[key] = backdrop(file, DIALOG_BORDER, 32, 32, 11, 12, 12, 11)
end
local insetBackdrop = backdrop(nil, TOOLTIP_BORDER, 16, 16, 5, 5, 5, 5)
local insetFilledBackdrop = backdrop(TOOLTIP_BACKGROUND, TOOLTIP_BORDER, 16, 16, 5, 5, 5, 5)

function ns.CreateLabel(parent, text, template, layer)
	local label = parent:CreateFontString(nil, layer or "ARTWORK", template or "GameFontHighlight")
	if text then
		label:SetText(text)
	end
	return label
end

local function updateHeader(frame)
	local header = frame.header
	local width = max(frame.title:GetStringWidth() + HEADER_PADDING, frame.headerWidth or HEADER_MIN_WIDTH)
	header.middle:SetWidth(width)
	header:SetWidth(width + HEADER_CAP * 2)
end

local function createHeader(frame)
	local header = CreateFrame("Frame", nil, frame)
	header:SetHeight(HEADER_HEIGHT)
	header:SetPoint("TOP", 0, 12)
	header:SetFrameLevel(frame:GetFrameLevel() + 5)

	local middle = header:CreateTexture(nil, "ARTWORK")
	middle:SetTexture(DIALOG_HEADER)
	middle:SetTexCoord(0.28125, 0.71484375, 0, 0.625)
	middle:SetHeight(HEADER_HEIGHT)
	middle:SetPoint("TOP")
	header.middle = middle

	local left = header:CreateTexture(nil, "ARTWORK")
	left:SetTexture(DIALOG_HEADER)
	left:SetTexCoord(0.2265625, 0.28125, 0, 0.625)
	left:SetSize(HEADER_CAP, HEADER_HEIGHT)
	left:SetPoint("RIGHT", middle, "LEFT")

	local right = header:CreateTexture(nil, "ARTWORK")
	right:SetTexture(DIALOG_HEADER)
	right:SetTexCoord(0.71484375, 0.76953125, 0, 0.625)
	right:SetSize(HEADER_CAP, HEADER_HEIGHT)
	right:SetPoint("LEFT", middle, "RIGHT")

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", middle, "TOP", 0, -14)
	frame.header = header
	frame.title = title
	hooksecurefunc(title, "SetText", function()
		updateHeader(frame)
	end)
end

local function hideWindow(self)
	self:GetParent():Hide()
end

local function createCloseButton(frame, secure)
	local close
	if secure then
		close = CreateFrame("Button", nil, frame, "SecureHandlerClickTemplate")
		close:SetSize(32, 32)
		close:SetNormalTexture(CLOSE_UP)
		close:SetPushedTexture(CLOSE_DOWN)
		close:SetHighlightTexture(CLOSE_HIGHLIGHT)
		close:GetHighlightTexture():SetBlendMode("ADD")
		close:SetFrameRef("window", frame)
		close:SetAttribute("_onclick", [[self:GetFrameRef("window"):Hide()]])
	else
		close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetScript("OnClick", hideWindow)
	end
	close:SetPoint("TOPRIGHT", -3, -3)
	close:SetFrameLevel(frame:GetFrameLevel() + 6)

	local corner = frame:CreateTexture(nil, "OVERLAY")
	corner:SetTexture(DIALOG_CORNER)
	corner:SetSize(32, 32)
	corner:SetPoint("TOPRIGHT", -6, -7)
	frame.corner = corner
	return close
end

local function copyInset(inset)
	return { left = inset.left, right = inset.right, top = inset.top, bottom = inset.bottom }
end

function ns.CreateWindow(name, options)
	local gear = options.style == "gear"
	local frame = CreateFrame("Frame", name, options.parent or UIParent, gear and "UIPanelDialogTemplate" or nil)
	frame:Hide()
	frame:SetWidth(options.width)
	if options.height then
		frame:SetHeight(options.height)
	end
	frame:SetFrameStrata(options.strata or "HIGH")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	if options.movable ~= false then
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	end
	if name and options.special ~= false then
		tinsert(UISpecialFrames, name)
	end

	if gear then
		frame.close = _G[name .. "Close"]
		frame.close:SetScript("OnClick", hideWindow)
		frame.inset = copyInset(GEAR_INSET)
		if options.title then
			frame.title:SetText(options.title)
		end
		return frame
	end

	frame:SetBackdrop(windowBackdrops[options.background or "normal"])
	frame.inset = copyInset(WINDOW_INSET)
	frame.headerWidth = options.headerWidth

	if options.header then
		createHeader(frame)
	else
		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -17)
		frame.title = title
	end
	if options.title then
		frame.title:SetText(options.title)
	elseif frame.header then
		updateHeader(frame)
	end

	if not options.noClose then
		frame.close = createCloseButton(frame, options.secureClose)
	end
	return frame
end

function ns.SetUIPanelLayout(frame, area, pushable)
	frame:SetAttribute("UIPanelLayout-defined", true)
	frame:SetAttribute("UIPanelLayout-enabled", true)
	frame:SetAttribute("UIPanelLayout-area", area)
	frame:SetAttribute("UIPanelLayout-pushable", pushable)
	frame:SetAttribute("UIPanelLayout-whileDead", 1)
end

function ns.CreateInset(parent, style, title)
	local config = INSET_STYLES[style or "box"]
	local inset = CreateFrame("Frame", nil, parent)
	inset:SetBackdrop(config.background and insetFilledBackdrop or insetBackdrop)
	inset:SetBackdropBorderColor(unpack(config.border))
	if config.background then
		inset:SetBackdropColor(unpack(config.background))
	end
	if title then
		local label =
			inset:CreateFontString(nil, "BACKGROUND", style == "dark" and "GameFontNormal" or "GameFontHighlightSmall")
		label:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 5, style == "dark" and 2 or 0)
		label:SetText(title)
		inset.title = label
	end
	return inset
end

function ns.CreateButton(parent, text, width, height, name, gray)
	local button =
		CreateFrame("Button", widgetName(name), parent, gray and "UIPanelButtonGrayTemplate" or "UIPanelButtonTemplate")
	button:SetSize(width or 100, height or 22)
	button:SetText(text or "")
	button.text = button:GetFontString()
	return button
end

function ns.FitButton(button, padding, minWidth)
	button:SetWidth(max(minWidth or 0, button:GetTextWidth() + (padding or 24)))
end

local function playCheckSound(self)
	PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
end

local function setCheckLabel(check, text)
	check.text:SetText(text or "")
	check:SetHitRectInsets(0, -(check.text:GetStringWidth() + 4), 0, 0)
end

function ns.CreateCheckButton(parent, text, name, small)
	local check = CreateFrame("CheckButton", widgetName(name), parent, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	local label = _G[check:GetName() .. "Text"]
	label:SetFontObject(_G[small and "GameFontHighlightSmall" or "GameFontHighlight"])
	label:ClearAllPoints()
	label:SetPoint("LEFT", check, "RIGHT", 0, 1)
	check.text = label
	check.SetLabel = setCheckLabel
	check:SetScript("PostClick", playCheckSound)
	setCheckLabel(check, text)
	return check
end

function ns.CreateRadioButton(parent, text, name)
	local radio = CreateFrame("CheckButton", widgetName(name), parent, "UIRadioButtonTemplate")
	local label = _G[radio:GetName() .. "Text"]
	label:SetFontObject(GameFontHighlightSmall)
	radio.text = label
	radio.SetLabel = setCheckLabel
	setCheckLabel(radio, text)
	return radio
end

local function updatePlaceholder(box)
	local shown = box:GetText() == "" and not box.focused
	ns.SetShown(box.placeholder, shown)
	if box.placeholderGlyph then
		ns.SetShown(box.placeholderGlyph, shown)
	end
end

function ns.CreateEditBox(parent, width, height, name, placeholder, glyph)
	local box = CreateFrame("EditBox", widgetName(name), parent, "InputBoxTemplate")
	box:SetSize(width or 120, height or 20)
	box:SetAutoFocus(false)
	box:SetTextInsets(0, 0, 0, 0)
	if placeholder then
		local text = box:CreateFontString(nil, "ARTWORK", "GameFontDisable")
		text:SetText(placeholder)
		box.placeholder = text
		if glyph ~= false then
			local icon = ns.CreateGlyph(box, glyph or "magnifying-glass", PLACEHOLDER_GLYPH_SIZE, "ARTWORK")
			icon:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
			icon:SetPoint("LEFT", 1, 0)
			text:SetPoint("LEFT", icon, "RIGHT", PLACEHOLDER_GLYPH_GAP, 0)
			box.placeholderGlyph = icon
		else
			text:SetPoint("LEFT", 1, 0)
		end
		box:HookScript("OnEditFocusGained", function(self)
			self.focused = true
			updatePlaceholder(self)
		end)
		box:HookScript("OnEditFocusLost", function(self)
			self.focused = nil
			updatePlaceholder(self)
		end)
		box:HookScript("OnTextChanged", updatePlaceholder)
	end
	return box
end

local function selectDropdown(dropdown, value)
	dropdown.selected = value
	UIDropDownMenu_SetSelectedValue(dropdown, value)
	for _, option in ipairs(dropdown.getValues()) do
		if option[1] == value then
			UIDropDownMenu_SetText(dropdown, option[2])
			return
		end
	end
	UIDropDownMenu_SetText(dropdown, value ~= nil and tostring(value) or "")
end

local function setDropdownEnabled(dropdown, enabled)
	if enabled then
		UIDropDownMenu_EnableDropDown(dropdown)
	else
		UIDropDownMenu_DisableDropDown(dropdown)
	end
end

local function showOptionTooltip(button)
	local desc = button.optionDesc
	if not desc or not button.tooltipOnButton or button.tooltipText ~= desc then
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText(button.tooltipTitle, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddLine(desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	GameTooltip:Show()
end

local function addOptionButton(info, desc)
	UIDropDownMenu_AddButton(info)
	local list = _G["DropDownList" .. (UIDROPDOWNMENU_MENU_LEVEL or 1)]
	local button = list and _G[list:GetName() .. "Button" .. list.numButtons]
	if not button then
		return
	end
	button.optionDesc = desc
	if desc and not button.optionTooltipHooked then
		button.optionTooltipHooked = true
		button:HookScript("OnEnter", showOptionTooltip)
	end
end

function ns.CreateDropdown(parent, width, values, onSelect, name)
	local dropdown = CreateFrame("Frame", widgetName(name), parent, "UIDropDownMenuTemplate")
	local getValues = type(values) == "function" and values or function()
		return values
	end
	dropdown.getValues = getValues
	UIDropDownMenu_SetWidth(dropdown, width or 120)
	UIDropDownMenu_Initialize(dropdown, function()
		local info = UIDropDownMenu_CreateInfo()
		for _, option in ipairs(getValues()) do
			local desc = option.desc or option[3]
			info.text = option[2]
			info.value = option[1]
			info.checked = option[1] == dropdown.selected
			info.fontObject = option.fontObject
			info.tooltipTitle = desc and option[2]
			info.tooltipText = desc
			info.tooltipOnButton = desc and 1
			info.func = function()
				selectDropdown(dropdown, option[1])
				if onSelect then
					onSelect(option[1])
				end
			end
			addOptionButton(info, desc)
		end
	end)
	dropdown.Select = selectDropdown
	dropdown.SetEnabled = setDropdownEnabled
	return dropdown
end

function ns.CreateSlider(parent, width, minValue, maxValue, step, name)
	local slider = CreateFrame("Slider", widgetName(name), parent, "OptionsSliderTemplate")
	local sliderName = slider:GetName()
	slider:SetWidth(width or 144)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step or 1)
	slider.text = _G[sliderName .. "Text"]
	slider.low = _G[sliderName .. "Low"]
	slider.high = _G[sliderName .. "High"]
	slider.low:SetText(minValue)
	slider.high:SetText(maxValue)
	slider.text:SetText("")
	return slider
end

function ns.SkinScrollBar(scroll)
	local bar = _G[scroll:GetName() .. "ScrollBar"]
	if not bar or bar.track then
		return bar
	end
	local up = _G[bar:GetName() .. "ScrollUpButton"]
	local down = _G[bar:GetName() .. "ScrollDownButton"]

	local top = bar:CreateTexture(nil, "BORDER")
	top:SetTexture(SCROLL_TRACK)
	top:SetTexCoord(0, 0.484375, 0, 1)
	top:SetSize(31, 256)
	top:SetPoint("TOPLEFT", up, "TOPLEFT", -8, 5)

	local bottom = bar:CreateTexture(nil, "BORDER")
	bottom:SetTexture(SCROLL_TRACK)
	bottom:SetTexCoord(0.515625, 1, 0, 0.4140625)
	bottom:SetSize(31, 106)
	bottom:SetPoint("BOTTOMLEFT", down, "BOTTOMLEFT", -8, -2)

	local middle = bar:CreateTexture(nil, "BACKGROUND")
	middle:SetTexture(SCROLL_TRACK)
	middle:SetTexCoord(0, 0.484375, 0.2, 0.8)
	middle:SetWidth(31)
	middle:SetPoint("TOPLEFT", top, "TOPLEFT")
	middle:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT")

	local function clampTop()
		local height = bar:GetHeight() + 32 + 7
		top:SetHeight(math.min(256, height))
		top:SetTexCoord(0, 0.484375, 0, math.min(256, height) / 256)
	end
	bar:HookScript("OnSizeChanged", clampTop)
	clampTop()

	bar.track = { top = top, middle = middle, bottom = bottom }
	return bar
end

local function fitScrollChild(scroll, width)
	scroll.child:SetWidth(width)
end

function ns.CreateScrollFrame(parent, name, track)
	local scroll = CreateFrame("ScrollFrame", widgetName(name), parent, "UIPanelScrollFrameTemplate")
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	scroll.child = child
	scroll.scrollBar = _G[scroll:GetName() .. "ScrollBar"]
	scroll:SetScript("OnSizeChanged", fitScrollChild)
	if track then
		ns.SkinScrollBar(scroll)
	end
	return scroll, child
end

function ns.CreateFauxScrollFrame(parent, name, track)
	local scroll = CreateFrame("ScrollFrame", widgetName(name), parent, "FauxScrollFrameTemplate")
	scroll.scrollBar = _G[scroll:GetName() .. "ScrollBar"]
	if track then
		ns.SkinScrollBar(scroll)
	end
	return scroll
end

ns.SCROLLBAR_WIDTH = 24
ns.SCROLLBAR_TRACK_WIDTH = 30

function ns.CreateDivider(parent, width)
	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetTexture(DIALOG_DIVIDER)
	divider:SetTexCoord(0, 0.75390625, 0, 0.5)
	divider:SetHeight(16)
	if width then
		divider:SetWidth(width)
	end
	return divider
end

function ns.CreateHeader(parent, text, template)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(20)

	local label = header:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
	label:SetPoint("LEFT")
	label:SetJustifyH("LEFT")
	label:SetText(text or "")
	header.text = label

	local line = header:CreateTexture(nil, "ARTWORK")
	line:SetTexture(TOOLTIP_BACKGROUND)
	line:SetVertexColor(1, 0.82, 0, 0.35)
	line:SetHeight(1)
	line:SetPoint("LEFT", label, "RIGHT", 8, 0)
	line:SetPoint("RIGHT")
	header.line = line
	return header
end

function ns.AddHighlight(button, style)
	local config = HIGHLIGHTS[style or "list"]
	button:SetHighlightTexture(config[1])
	local highlight = button:GetHighlightTexture()
	highlight:SetBlendMode("ADD")
	if config[2] then
		highlight:SetVertexColor(config[2], config[3], config[4])
	end
	return highlight
end

local function setSelected(button, selected)
	button.selected = selected and true or nil
	if selected then
		button:LockHighlight()
	else
		button:UnlockHighlight()
	end
end

function ns.CreateListButton(parent, height, style, template)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(height or 16)
	local text = button:CreateFontString(nil, "ARTWORK", template or "GameFontNormalLeft")
	text:SetPoint("LEFT", 4, 0)
	text:SetPoint("RIGHT", -4, 0)
	button:SetFontString(text)
	button:SetNormalFontObject(_G[template or "GameFontNormalLeft"])
	button:SetHighlightFontObject(GameFontHighlightLeft)
	button:SetDisabledFontObject(GameFontDisableLeft)
	button.text = text
	button.SetSelected = setSelected
	ns.AddHighlight(button, style)
	return button
end

function ns.SkinIconButton(button, background)
	local size = button:GetWidth()
	local scale = size / 37

	if background ~= false then
		local config = SLOT_BACKGROUNDS[background or "empty"]
		local bg = button.slotBackground or button:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture(config[1])
		if config[5] then
			bg:SetTexCoord(config[5], config[6], config[7], config[8])
		else
			bg:SetTexCoord(0, 1, 0, 1)
		end
		local bgSize = size * config[2]
		bg:SetSize(bgSize, bgSize)
		bg:ClearAllPoints()
		if background == "spell" then
			bg:SetPoint("TOPLEFT", -3 * scale, 3 * scale)
		else
			bg:SetPoint("CENTER", config[3] * scale, config[4] * scale)
		end
		button.slotBackground = bg
	end

	local icon = button.icon
	if not icon then
		icon = button:CreateTexture(nil, "BORDER")
		icon:SetAllPoints()
		button.icon = icon
	end

	button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
	local normal = button:GetNormalTexture()
	normal:SetSize(64 * scale, 64 * scale)
	normal:ClearAllPoints()
	normal:SetPoint("CENTER", 0, -scale)
	button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	button:GetHighlightTexture():SetBlendMode("ADD")
	if button.SetCheckedTexture then
		button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
		button:GetCheckedTexture():SetBlendMode("ADD")
	end
	return button
end

function ns.CreateIconSlot(parent, size, background, name, check)
	local button = CreateFrame(check and "CheckButton" or "Button", name, parent)
	button:SetSize(size or 37, size or 37)
	ns.SkinIconButton(button, background)
	local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	count:SetPoint("BOTTOMRIGHT", -5, 2)
	count:SetJustifyH("RIGHT")
	button.count = count
	return button
end

local function resizeTab(tab)
	PanelTemplates_TabResize(tab, tab.padding)
	if tab.style == "top" then
		_G[tab:GetName() .. "HighlightTexture"]:SetWidth(tab:GetTextWidth() + 30)
	elseif tab.style == "tall" then
		_G[tab:GetName() .. "HighlightTexture"]:SetWidth(tab:GetTextWidth() + 31)
	end
end

function ns.SelectTab(owner, index)
	PanelTemplates_SetTab(owner, index)
end

function ns.SetTabEnabled(owner, index, enabled)
	if enabled then
		PanelTemplates_EnableTab(owner, index)
	else
		PanelTemplates_DisableTab(owner, index)
	end
end

function ns.CreateTabs(owner, labels, options)
	options = options or {}
	local style = options.style or "bottom"
	local parent = options.parent or owner
	local ownerName = assert(owner:GetName(), "CreateTabs: owner frame needs a global name")
	local tabs = {}
	for i, label in ipairs(labels) do
		local tab = CreateFrame("Button", ownerName .. "Tab" .. i, parent, TAB_TEMPLATES[style])
		tab:SetID(i)
		tab.style = style
		tab.padding = options.padding or 0
		tab:SetText(label)
		tab:SetScript("OnShow", resizeTab)
		tab:SetScript("OnClick", function(self)
			PlaySound("igCharacterInfoTab")
			PanelTemplates_SetTab(owner, self:GetID())
			if options.onSelect then
				options.onSelect(self:GetID(), self)
			end
		end)
		if i == 1 then
			if options.point then
				tab:SetPoint(unpack(options.point))
			elseif style == "bottom" then
				tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 12, 8)
			else
				tab:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 12, -8)
			end
		else
			tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", options.spacing or TAB_OVERLAP[style], 0)
		end
		resizeTab(tab)
		tabs[i] = tab
	end
	PanelTemplates_SetNumTabs(owner, #tabs)
	PanelTemplates_SetTab(owner, options.selected or 1)
	return tabs
end

local function showSideTabTooltip(self)
	if self.tooltip then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltip)
	end
end

function ns.CreateSideTab(parent, icon, tooltip, name)
	local tab = CreateFrame("CheckButton", name, parent, "SpellBookSkillLineTabTemplate")
	tab:SetNormalTexture(icon)
	tab.tooltip = tooltip
	tab:SetScript("OnClick", nil)
	tab:SetScript("OnEnter", showSideTabTooltip)
	tab:Show()
	return tab
end
