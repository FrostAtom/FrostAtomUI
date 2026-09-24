local _, ns = ...

local Media = ns.Media
local codes = ns.GlyphCodes

local floor, char = math.floor, string.char

local BUTTON_COLOR = { 0.75, 0.75, 0.75 }
local BUTTON_HOVER_COLOR = { 1, 0.82, 0 }
local BUTTON_DISABLED_COLOR = { 0.35, 0.35, 0.35 }

local glyphs = {}

local function encode(code)
	if code < 0x80 then
		return char(code)
	elseif code < 0x800 then
		return char(0xC0 + floor(code / 0x40), 0x80 + code % 0x40)
	end
	return char(0xE0 + floor(code / 0x1000), 0x80 + floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

function ns.Glyph(name)
	local glyph = glyphs[name]
	if glyph then
		return glyph
	end
	local code = type(name) == "number" and name or codes[name]
	if not code then
		error(("unknown glyph [%s]"):format(tostring(name)), 2)
	end
	glyph = encode(code)
	glyphs[name] = glyph
	return glyph
end

function ns.SetGlyph(region, name, size, outline)
	if size then
		region:SetFont(Media.glyphFont, size, outline or "")
		region:SetTextHeight(size)
	end
	region:SetText(name and ns.Glyph(name) or "")
end

function ns.CreateGlyph(parent, name, size, layer, outline)
	local glyph = parent:CreateFontString(nil, layer or "OVERLAY")
	ns.SetGlyph(glyph, name, size, outline)
	return glyph
end

local function paintButton(button)
	local color = button.disabledColor or BUTTON_DISABLED_COLOR
	if button:IsEnabled() == 1 then
		color = button.hovered and (button.hoverColor or BUTTON_HOVER_COLOR) or (button.color or BUTTON_COLOR)
	end
	button.glyph:SetTextColor(color[1], color[2], color[3])
end

local function buttonEnter(button)
	button.hovered = true
	paintButton(button)
	local tooltip = button.tooltip
	if not tooltip then
		return
	end
	GameTooltip:SetOwner(button, button.tooltipAnchor or "ANCHOR_RIGHT")
	GameTooltip:SetText(tooltip, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if button.tooltipText then
		GameTooltip:AddLine(button.tooltipText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end
	GameTooltip:Show()
end

local function buttonLeave(button)
	button.hovered = nil
	paintButton(button)
	if button.tooltip then
		GameTooltip:Hide()
	end
end

local function buttonDown(button)
	if button:IsEnabled() == 1 then
		button.glyph:SetPoint("CENTER", 1, -1)
	end
end

local function buttonUp(button)
	button.glyph:SetPoint("CENTER", 0, 0)
end

function ns.CreateGlyphButton(parent, name, size, tooltip, frameName)
	local button = CreateFrame("Button", frameName, parent)
	button:SetSize(size + 6, size + 6)
	button.glyph = ns.CreateGlyph(button, name, size, "ARTWORK")
	button.glyph:SetPoint("CENTER")
	button.tooltip = tooltip
	button:SetScript("OnEnter", buttonEnter)
	button:SetScript("OnLeave", buttonLeave)
	button:SetScript("OnMouseDown", buttonDown)
	button:SetScript("OnMouseUp", buttonUp)
	button:SetScript("OnEnable", paintButton)
	button:SetScript("OnDisable", paintButton)
	button.Paint = paintButton
	paintButton(button)
	return button
end
