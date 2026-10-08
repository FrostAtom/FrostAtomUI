local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local floor = math.floor
local max = math.max
local min = math.min

local P = ns.private
local CHILD_INDENT = P.CHILD_INDENT
local CONTROL_X = P.CONTROL_X
local FONT_OBJECTS = P.FONT_OBJECTS
local FRAME_NAME = P.FRAME_NAME
local GLYPH_GAP = P.GLYPH_GAP
local GLYPH_SIZE = P.GLYPH_SIZE
local HIGHLIGHT_COLOR = P.HIGHLIGHT_COLOR
local LABEL_X = P.LABEL_X
local MARKER_SIZE = P.MARKER_SIZE
local RELOAD_COLOR = P.RELOAD_COLOR
local ROW_HEIGHT = P.ROW_HEIGHT
local TEXTURE = P.TEXTURE
local changes = P.changes
local elements = P.elements
local pages = P.pages

local function nextName()
	P.widgetCount = P.widgetCount + 1
	return FRAME_NAME .. "Widget" .. P.widgetCount
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

local PIXEL_KEYS = {
	"Width$",
	"Height$",
	"Size$",
	"Spacing$",
	"Gap$",
	"Padding$",
	"^width$",
	"^height$",
	"^size$",
	"^spacing$",
	"^gap$",
}

local function unitOf(entry)
	if entry.unit then
		return ns.UNITS[entry.unit] and entry.unit
	end
	if entry.type ~= "number" or entry.percent or type(entry.path) ~= "string" then
		return nil
	end
	local key = entry.path:match("([^.]+)$")
	if key:find("[fF]ont") then
		return nil
	end
	for _, pattern in ipairs(PIXEL_KEYS) do
		if key:find(pattern) then
			return "px"
		end
	end
end
P.unitOf = unitOf

local function formatValue(entry, value)
	if entry.zeroText and value == 0 then
		return entry.zeroText
	end
	if entry.percent then
		return formatNumber(value * 100, entry.step * 100) .. "%"
	end
	local unit = unitOf(entry)
	if unit then
		return ns.UNITS[unit]:format(formatNumber(value, entry.step))
	end
	return formatNumber(value, entry.step)
end

local function parseValue(entry, text)
	text = strtrim(text)
	if entry.zeroText and ui.Lower(text) == ui.Lower(entry.zeroText) then
		return 0
	end
	local number = text:match("^[-+]?[%d.,]+")
	local value = number and tonumber((number:gsub(",", ".")))
	if value and entry.percent then
		return value / 100
	end
	return value
end

local fontObjects = {}

local function font(name)
	return fontObjects[name] or _G[name]
end
ns.Font = font

local function initFonts()
	local locale = ui.LOCALE
	if not locale or ui.CanRenderLocale(locale, (GameFontNormal:GetFont())) then
		return
	end
	for _, name in ipairs(FONT_OBJECTS) do
		local source = _G[name]
		local object = CreateFont(FRAME_NAME .. name)
		object:CopyFontObject(source)
		local _, size, flags = source:GetFont()
		object:SetFont(ui.Media.font, size, flags)
		fontObjects[name] = object
	end
end
initFonts()

local function setButtonFonts(button, normal, highlight, disabled)
	button:SetNormalFontObject(font(normal or "GameFontNormal"))
	button:SetHighlightFontObject(font(highlight or "GameFontHighlight"))
	button:SetDisabledFontObject(font(disabled or "GameFontDisable"))
end

local function setTextEnabled(region, enabled)
	local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
	region:SetTextColor(color.r, color.g, color.b)
end

local function createGlyph(parent, name, size, color)
	local glyph = ui.CreateGlyph(parent, name, size)
	glyph:SetTextColor(color.r, color.g, color.b)
	return glyph
end

local function addTooltipLine(text, color, wrap)
	GameTooltip:AddLine(text, color.r, color.g, color.b, wrap)
end

local function showTooltip(owner, title, desc)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if desc then
		addTooltipLine(desc, NORMAL_FONT_COLOR, true)
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

local function createHighlight(parent, alpha)
	local highlight = parent:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(TEXTURE.HIGHLIGHT)
	highlight:SetBlendMode("ADD")
	highlight:SetVertexColor(HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3], alpha)
	highlight:SetAllPoints()
	return highlight
end

local function createSpacerLine(parent)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(TEXTURE.SPACER)
	line:SetVertexColor(0.6, 0.6, 0.6)
	line:SetHeight(16)
	return line
end

local function paintButtonGlyph(button)
	local color = NORMAL_FONT_COLOR
	if button:IsEnabled() ~= 1 then
		color = GRAY_FONT_COLOR
	elseif button.hovered or button.gray then
		color = HIGHLIGHT_FONT_COLOR
	end
	button.glyph:SetTextColor(color.r, color.g, color.b)
end

local function hoverButtonGlyph(button)
	button.hovered = true
	paintButtonGlyph(button)
end

local function leaveButtonGlyph(button)
	button.hovered = nil
	paintButtonGlyph(button)
end

local function addButtonGlyph(button, name, minWidth, gray, right)
	local glyph = ui.CreateGlyph(button, name, GLYPH_SIZE)
	local width = glyph:GetStringWidth()
	local text = button:GetFontString()
	text:ClearAllPoints()
	if right then
		text:SetPoint("CENTER", -(width + GLYPH_GAP) / 2, 0)
		glyph:SetPoint("LEFT", text, "RIGHT", GLYPH_GAP, 0)
	else
		text:SetPoint("CENTER", (width + GLYPH_GAP) / 2, 0)
		glyph:SetPoint("RIGHT", text, "LEFT", -GLYPH_GAP, 0)
	end
	button.glyph = glyph
	button.gray = gray
	button:HookScript("OnEnter", hoverButtonGlyph)
	button:HookScript("OnLeave", leaveButtonGlyph)
	button:HookScript("OnEnable", paintButtonGlyph)
	button:HookScript("OnDisable", paintButtonGlyph)
	paintButtonGlyph(button)
	ui.FitButton(button, 20 + width + GLYPH_GAP, minWidth)
end

local function setControlEnabled(control, enabled)
	if enabled then
		control:Enable()
	else
		control:Disable()
	end
end

local function playCheckSound(check)
	PlaySound(check:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
end

local function versionValue(version)
	local major, minor, patch = tostring(version or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
	if not major then
		return 0
	end
	return tonumber(major) * 1000000 + (tonumber(minor) or 0) * 1000 + (tonumber(patch) or 0)
end

local seenAtOpen = {}
local seenStore, isNewEntry, newestUnseen, markSeen, updateNavBadge

do
	local function releaseOf(version)
		return floor(versionValue(version) / 1000) * 1000
	end

	local releaseValue = releaseOf(GetAddOnMetadata("FrostAtomUI", "Version"))

	function seenStore()
		return ui.API.UIStore("seenTabs")
	end

	local function isUnseen(new, key, seen)
		if not new or not key then
			return false
		end
		local value = versionValue(new)
		return value >= releaseValue
			and releaseOf(new) > releaseOf(ui.API.GetUIState("seenRelease"))
			and value > versionValue(seen[key])
	end

	local function elementSeenKey(element)
		local tab = element.tab
		if not tab then
			for _, page in ipairs(pages) do
				if page.key == element.page then
					for _, candidate in ipairs(page.tabs or {}) do
						if candidate.elements == "all" or candidate.elements == "untabbed" then
							tab = candidate.key
							break
						end
					end
					break
				end
			end
		end
		return tab and element.page .. ":" .. tab or element.page
	end

	local function seenKeyOf(entry)
		local owner = entry.page
		if not owner then
			return nil
		end
		if owner.path and owner.page then
			return elementSeenKey(owner)
		end
		return entry.seenTab and owner.key .. ":" .. entry.seenTab or owner.key
	end

	function P.isReleaseEntry(entry)
		return entry.new ~= nil and versionValue(entry.new) >= releaseValue
	end

	function isNewEntry(entry)
		return entry.new ~= nil and isUnseen(entry.new, seenKeyOf(entry), seenAtOpen)
	end

	local function newestIn(schema, key, seen, newest)
		for _, entry in ipairs(schema) do
			if isUnseen(entry.new, key, seen) and versionValue(entry.new) > versionValue(newest) then
				newest = entry.new
			end
		end
		return newest
	end

	function newestUnseen(page, onlyKey)
		local seen = seenStore()
		local newest
		local function scan(schema, key)
			if not onlyKey or onlyKey == key then
				newest = newestIn(schema, key, seen, newest)
			end
		end
		if (not onlyKey or onlyKey == page.key) and isUnseen(page.new, page.key, seen) then
			newest = page.new
		end
		scan(page.schema, page.key)
		for _, tab in ipairs(page.tabs or {}) do
			scan(tab.schema, page.key .. ":" .. tab.key)
		end
		for _, element in ipairs(elements) do
			if element.page == page.key and not element.hidden then
				scan(element.schema, elementSeenKey(element))
			end
		end
		return newest
	end

	function markSeen(page, key)
		local newest = newestUnseen(page, key)
		if newest then
			seenStore()[key] = newest
		end
	end

	function updateNavBadge(page)
		local button = page.button
		if button then
			ui.SetShown(button.newBadge, newestUnseen(page))
		end
	end
end

local function addNewBadge(parent, anchor, offset)
	local badge = parent:CreateFontString(nil, "OVERLAY")
	badge:SetFontObject(font("GameFontGreenSmall"))
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

function ns.NeedsReload(entry)
	return entry.reload or entry.path ~= nil and ui.RequiresReload(entry.path)
end

local function rowEnter(row)
	row.highlight:Show()
	local entry = row.entry
	local range = entry.type == "number"
	local requirement = row.disabled and P.requirementText(entry)
	local default = row.modified and changes.DefaultText(entry)
	local baseline = row.baselineNote
	local problem = row.problem
	local wheel = range or entry.type == "font" or entry.type == "offset" or entry.type == "point"
	local added = row.newBadge and entry.new
	local alias = entry.aliasPlace
	if
		not entry.desc
		and not alias
		and not wheel
		and not ns.NeedsReload(entry)
		and not requirement
		and not default
		and not baseline
		and not problem
		and not added
	then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(entry.label, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if entry.desc then
		addTooltipLine(entry.desc, NORMAL_FONT_COLOR, true)
	end
	if problem then
		addTooltipLine(problem.text, problem.color, true)
	end
	if alias then
		addTooltipLine(L["The same setting as on %s."]:format(alias), GRAY_FONT_COLOR, true)
	end
	if requirement then
		addTooltipLine(requirement, RED_FONT_COLOR, true)
	end
	if ns.NeedsReload(entry) then
		addTooltipLine(L["Requires a UI reload."], RELOAD_COLOR, true)
	end
	if range then
		addTooltipLine(
			("%s - %s"):format(formatValue(entry, entry.min), formatValue(entry, entry.max)),
			GRAY_FONT_COLOR
		)
	end
	if default then
		addTooltipLine(L["Default: %s"]:format(default), GRAY_FONT_COLOR)
	end
	if baseline then
		addTooltipLine(baseline, GRAY_FONT_COLOR, true)
	end
	if wheel then
		addTooltipLine(L["Shift + mouse wheel changes the value."], GRAY_FONT_COLOR)
	end
	if added then
		addTooltipLine(L["Added in %s"]:format(added), GREEN_FONT_COLOR)
	end
	GameTooltip:Show()
end

local function rowLeave(row)
	row.highlight:Hide()
	GameTooltip:Hide()
end

local function bindRow(control, row)
	control:HookScript("OnEnter", function()
		rowEnter(row)
	end)
	control:HookScript("OnLeave", function()
		rowLeave(row)
	end)
end

local function bindHighlight(control, row)
	control:HookScript("OnEnter", function()
		row.highlight:Show()
	end)
	control:HookScript("OnLeave", function()
		row.highlight:Hide()
	end)
end

local function createButton(parent, text, width, gray, height, glyph, glyphRight)
	local button = ui.CreateButton(parent, text, width, height or 22, nextName(), gray)
	setButtonFonts(button, gray and "GameFontHighlight" or "GameFontNormal")
	if glyph then
		addButtonGlyph(button, glyph, width, gray, glyphRight)
	else
		ui.FitButton(button, 20, width)
	end
	return button
end
ns.CreateButton = createButton

local function createWindow(name, options)
	local window = ui.CreateWindow(name, options)
	window.title:SetFontObject(font("GameFontNormal"))
	window.heading = window.title
	return window
end
ns.CreateWindow = createWindow

local function createEditBox(parent, width, numeric)
	local box = ui.CreateEditBox(parent, width, 20, nextName())
	if numeric then
		box:SetMaxLetters(7)
	end
	box:HookScript("OnEditFocusGained", function(self)
		self.editing = true
		self.committed = self:GetText()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self.cancelled = true
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	box:SetScript("OnEditFocusLost", function(self)
		self.editing = nil
		self:HighlightText(0, 0)
		if self.cancelled then
			self.cancelled = nil
			self:SetText(self.committed or "")
			self:SetCursorPosition(0)
			if self.OnCancel then
				self:OnCancel()
			end
		elseif self.OnCommit then
			self:OnCommit()
		end
	end)
	return box
end

local function setEditBoxEnabled(box, enabled)
	box:EnableMouse(enabled)
	setTextEnabled(box, enabled)
	if not enabled then
		box:ClearFocus()
	end
end

local function createDropdown(parent, width, getValues, onSelect)
	local dropdown = ui.CreateDropdown(parent, width, getValues, onSelect, nextName())
	local text = _G[dropdown:GetName() .. "Text"]
	text:SetFontObject(font("GameFontHighlightSmall"))
	text:SetJustifyH("LEFT")
	return dropdown
end

local function createCheckButton(parent, template)
	local check = CreateFrame("CheckButton", nextName(), parent, template or "OptionsBaseCheckButtonTemplate")
	check:SetHitRectInsets(0, 0, 0, 0)
	return check
end

local function createRow(parent, entry)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("LEFT")
	row:SetPoint("RIGHT")
	row.entry = entry
	row:EnableMouse(true)
	row:SetScript("OnEnter", rowEnter)
	row:SetScript("OnLeave", rowLeave)

	local highlight = createHighlight(row, 0.35)
	highlight:Hide()
	row.highlight = highlight

	local indent = isChildEntry(entry) and CHILD_INDENT or 0
	local width = CONTROL_X - LABEL_X - 10 - indent
	if ns.NeedsReload(entry) then
		width = width - MARKER_SIZE - GLYPH_GAP
	end
	local label = row:CreateFontString(nil, "ARTWORK")
	label:SetFontObject(font("GameFontHighlight"))
	label:SetPoint("LEFT", LABEL_X + indent, 0)
	label:SetWidth(width)
	label:SetJustifyH("LEFT")
	label:SetText(entry.label)
	row.label = label
	row:SetHeight(max(ROW_HEIGHT, label:GetStringHeight() + 8))

	local offset = min(label:GetStringWidth(), width) + GLYPH_GAP
	if ns.NeedsReload(entry) then
		local marker = createGlyph(row, "rotate", MARKER_SIZE, RELOAD_COLOR)
		marker:SetPoint("LEFT", label, "LEFT", offset, 0)
		offset = offset + marker:GetStringWidth() + GLYPH_GAP
	end
	if isNewEntry(entry) then
		row.newBadge = addNewBadge(row, label, offset)
	end
	changes.Attach(row, entry)
	return row
end

local function get(entry)
	if entry.get then
		return entry.get()
	end
	return ui:GetConfig(entry.path)
end

P.addNewBadge = addNewBadge
P.addTooltipLine = addTooltipLine
P.bindHighlight = bindHighlight
P.bindRow = bindRow
P.createButton = createButton
P.createCheckButton = createCheckButton
P.createDropdown = createDropdown
P.createEditBox = createEditBox
P.createGlyph = createGlyph
P.createHighlight = createHighlight
P.createRow = createRow
P.createSpacerLine = createSpacerLine
P.createWindow = createWindow
P.font = font
P.formatValue = formatValue
P.forwardWheel = forwardWheel
P.get = get
P.isNewEntry = isNewEntry
P.markSeen = markSeen
P.newestUnseen = newestUnseen
P.nextName = nextName
P.parseValue = parseValue
P.playCheckSound = playCheckSound
P.round = round
P.rowEnter = rowEnter
P.rowLeave = rowLeave
P.seenAtOpen = seenAtOpen
P.seenStore = seenStore
P.setButtonFonts = setButtonFonts
P.setControlEnabled = setControlEnabled
P.setEditBoxEnabled = setEditBoxEnabled
P.setTextEnabled = setTextEnabled
P.showTooltip = showTooltip
P.updateNavBadge = updateNavBadge
P.versionValue = versionValue
