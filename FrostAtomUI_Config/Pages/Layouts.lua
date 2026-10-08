local _, ns = ...

local ui = FrostAtomUI
local L = ui.L

local floor, min, max, ceil = math.floor, math.min, math.max, math.ceil

local COLUMNS = 3
local CARD_WIDTH = 160
local CARD_GAP = 10
local CARD_PADDING = 5
local THUMB_WIDTH = CARD_WIDTH - CARD_PADDING * 2
local NAME_HEIGHT = 22
local CARD_X = 8
local MAX_DEPTH = 12

local POINT_PARTS = ui.POINT_PARTS

local COLORS = {
	info = { 0.45, 0.5, 0.58, 0.55 },
	bar = { 0.3, 0.55, 0.95, 0.85 },
	cooldown = { 0.25, 0.75, 0.75, 0.55 },
	cast = { 1, 0.7, 0.2, 0.9 },
	friend = { 0.35, 0.82, 0.45, 0.95 },
	enemy = { 0.92, 0.33, 0.3, 0.95 },
	focus = { 0.7, 0.45, 1, 0.95 },
}
local SCREEN_COLOR = { 0.04, 0.06, 0.09, 0.95 }
local CARD_COLOR = { 0, 0, 0, 0.45 }
local BORDER_COLOR = { 0.4, 0.4, 0.4 }
local HOVER_BORDER_COLOR = { 0.8, 0.8, 0.8 }
local ACTIVE_BORDER_COLOR = { 1, 0.82, 0 }
local BADGE_COLOR = { 0, 0, 0, 0.8 }
local BADGE_TEXT_COLOR = { 0.85, 0.85, 0.85 }
local BADGE_INSET, BADGE_PADDING = 2, 3
local BADGE_FONT, BADGE_SMALL_FONT, BADGE_SMALL_THUMB = 10, 8, 70
local UI_BASE_HEIGHT = 768

local layoutSettings = {}
for _, path in ipairs(ui.LayoutSettings) do
	layoutSettings[path] = true
end

local function defaultValue(path)
	local _, value = ui.API.FactoryValue(path)
	return value
end

local function enabled(path)
	return function()
		return ui:GetConfig(path) ~= false
	end
end

local function cooldownBlock(side)
	local prefix = "groupCooldowns." .. side
	return function()
		return ui:GetConfig(prefix) ~= false and ui:GetConfig(prefix .. "Layout") ~= "frames"
	end
end

local function interruptPanel(side)
	local prefix = "groupCooldowns." .. side
	return function()
		return ui:GetConfig(prefix) ~= false and ui:GetConfig(prefix .. "SeparateInterrupts") == true
	end
end

local function barSize(key)
	local prefix = "actionBar." .. key .. "."
	return function(setting)
		local count = setting(prefix .. "buttons")
		local columns = min(setting(prefix .. "columns"), count)
		local slot = setting(prefix .. "buttonSize") + setting(prefix .. "spacing")
		return columns * slot, ceil(count / columns) * slot
	end
end

local function sized(widthPath, heightPath)
	return function(setting)
		return setting(widthPath), setting(heightPath or widthPath)
	end
end

local function unitSize(prefix)
	return sized("unitFrames." .. prefix .. "Width", "unitFrames." .. prefix .. "Height")
end

local function castbarSize(prefix)
	return sized("unitFrames." .. prefix .. "CastbarWidth", "unitFrames." .. prefix .. "CastbarHeight")
end

local ELEMENTS = {
	{ "chat.point", "info", sized("chat.width", "chat.height"), enabled("chat.enabled") },
	{ "minimap.point", "info", sized("minimap.size"), enabled("minimap.enabled") },
	{ "unitFrames.playerAuras", "info" },
	{ "unitFrames.playerDebuffs", "info" },
	{ "actionBar.microMenu", "info", nil, enabled("hideBlizzard.actionBars") },
	{ "groupCooldowns.friendlyPoint", "cooldown", nil, cooldownBlock("friendly") },
	{ "groupCooldowns.enemyPoint", "cooldown", nil, cooldownBlock("enemy") },
	{ "groupCooldowns.friendlyInterruptPoint", "cooldown", nil, interruptPanel("friendly") },
	{ "groupCooldowns.enemyInterruptPoint", "cooldown", nil, interruptPanel("enemy") },
}

for i = 1, 6 do
	local key = "bar" .. i
	ELEMENTS[#ELEMENTS + 1] =
		{ "actionBar." .. key .. ".point", "bar", barSize(key), enabled("actionBar." .. key .. ".enabled") }
end

local function addGroup(prefix, count, kind, shownPath)
	local frameSize, castSize, shown = unitSize(prefix), castbarSize(prefix), enabled(shownPath)
	for i = 1, count do
		local path = "unitFrames." .. (i == 1 and prefix or prefix .. i)
		ELEMENTS[#ELEMENTS + 1] = { path, kind, frameSize, shown }
		ELEMENTS[#ELEMENTS + 1] = { "unitFrames." .. prefix .. i .. "Castbar", "cast", castSize, shown }
	end
end

addGroup("party", 4, "friend", "unitFrames.showParty")
addGroup("arena", 3, "enemy", "unitFrames.showArena")

for _, element in ipairs({
	{ "playerPlate.point", "friend", nil, enabled("playerPlate.enabled") },
	{ "unitFrames.playerCastbar", "cast", castbarSize("player") },
	{ "unitFrames.targetCastbar", "cast", castbarSize("target"), enabled("unitFrames.showTargetCastbar") },
	{ "unitFrames.focusCastbar", "cast", castbarSize("focus"), enabled("unitFrames.showFocusCastbar") },
	{ "unitFrames.player", "friend", unitSize("player") },
	{ "unitFrames.target", "enemy", unitSize("target") },
	{ "unitFrames.focus", "focus", unitSize("focus") },
}) do
	ELEMENTS[#ELEMENTS + 1] = element
end

local SIZES = {}
for _, element in ipairs(ELEMENTS) do
	SIZES[element[1]] = element[3]
end

local function screenSize(scale)
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	if not scale then
		return width, height
	end
	return UI_BASE_HEIGHT / scale * width / height, UI_BASE_HEIGHT / scale
end

local function previewRects(preset, scale)
	local screenWidth, screenHeight = screenSize(scale)
	local points, settings = ui.Movers.GetPresetLayout(preset.key, screenHeight)
	settings = settings or {}
	local rects = {}

	local function setting(path)
		local value = settings[path]
		if value == nil then
			value = layoutSettings[path] and defaultValue(path) or ui:GetConfig(path)
		end
		return value
	end

	local function sizeOf(path)
		local width, height, scale = ui.Movers.GetFrameSize(path)
		local size = SIZES[path]
		if size then
			width, height = size(setting)
			scale = scale or 1
		end
		return width, height, scale
	end

	local function resolve(path, depth)
		if rects[path] ~= nil then
			return rects[path]
		end
		local point = points[path] or defaultValue(path)
		local width, height, scale = sizeOf(path)
		if type(point) ~= "table" or not width or depth > MAX_DEPTH then
			rects[path] = false
			return false
		end
		local left, bottom, parentWidth, parentHeight = 0, 0, screenWidth, screenHeight
		local relative = not point[4] and point[5] or point[1]
		local anchor = point[4] and resolve(point[4], depth + 1)
		if anchor then
			left, bottom, parentWidth, parentHeight = anchor[1], anchor[2], anchor[3], anchor[4]
			relative = point[5]
		end
		local relX, relY = unpack(POINT_PARTS[relative] or POINT_PARTS.CENTER)
		local ownX, ownY = unpack(POINT_PARTS[point[1]] or POINT_PARTS.CENTER)
		local x = left + (relX - 1) * parentWidth / 2 + point[2] * scale
		local y = bottom + (relY - 1) * parentHeight / 2 + point[3] * scale
		local rect = { x - (ownX - 1) * width / 2, y - (ownY - 1) * height / 2, width, height }
		rects[path] = rect
		return rect
	end

	local result = {}
	for _, element in ipairs(ELEMENTS) do
		local shown = element[4]
		local rect = (not shown or shown()) and resolve(element[1], 0)
		if rect and rect[3] > 0 and rect[4] > 0 then
			result[#result + 1] = { rect = rect, kind = element[2] }
		end
	end
	return result, screenWidth, screenHeight
end

local function isCompactScreen(scale)
	local _, height = screenSize(scale)
	return height < ui.COMPACT_SCREEN_HEIGHT
end

local function fullScalePercent()
	return floor(UI_BASE_HEIGHT / ui.COMPACT_SCREEN_HEIGHT * 100)
end

local function variantText(scale)
	local percent = fullScalePercent()
	if isCompactScreen(scale) then
		return L["above %d%%"]:format(percent),
			L["Compact variant: the UI scale is above %d%%, the screen is less than 1000 interface units high. At %d%% or lower the full variant is applied."]:format(
				percent,
				percent
			)
	end
	return L["up to %d%%"]:format(percent),
		L["Full variant: the UI scale is %d%% or lower, the screen is at least 1000 interface units high. Above %d%% the compact variant is applied."]:format(
			percent,
			percent
		)
end

local function layoutFitText(preset, scale)
	if not preset.compact then
		return nil, L["The same on any screen and at any UI scale."]
	end
	local short, long = variantText(scale)
	if preset.key == "fullhd" then
		return L["1080p"], L["Made for a 1920x1080 screen or a smaller one."] .. " " .. long
	end
	return short, long
end

local function createBadge(thumb)
	local badge = CreateFrame("Frame", nil, thumb)
	badge:SetFrameLevel(thumb:GetFrameLevel() + 2)
	local text = badge:CreateFontString(nil, "OVERLAY")
	text:SetTextColor(unpack(BADGE_TEXT_COLOR))
	text:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -BADGE_INSET - BADGE_PADDING, BADGE_INSET + 1)
	badge:SetPoint("TOPLEFT", text, "TOPLEFT", -BADGE_PADDING, 1)
	badge:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", BADGE_PADDING, -1)
	local background = badge:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(ui.Media.blank)
	background:SetVertexColor(unpack(BADGE_COLOR))
	background:SetAllPoints()
	badge.text = text
	return badge
end

local function drawBadge(thumb, preset, scale)
	local short = layoutFitText(preset, scale)
	if not short then
		if thumb.badge then
			thumb.badge:Hide()
		end
		return
	end
	thumb.badge = thumb.badge or createBadge(thumb)
	local badge = thumb.badge
	local font, _, flags = ns.Font("GameFontHighlightSmall"):GetFont()
	badge.text:SetFont(font, thumb:GetHeight() < BADGE_SMALL_THUMB and BADGE_SMALL_FONT or BADGE_FONT, flags)
	badge.text:SetText(short)
	badge:Show()
end

local function drawThumbnail(thumb, preset, noBadge, scale)
	if not thumb.screen then
		local screen = thumb:CreateTexture(nil, "BACKGROUND")
		screen:SetTexture(ui.Media.blank)
		screen:SetVertexColor(unpack(SCREEN_COLOR))
		screen:SetAllPoints()
		thumb.screen = screen
	end
	thumb.textures = thumb.textures or {}
	for _, texture in ipairs(thumb.textures) do
		texture:Hide()
	end
	if noBadge then
		if thumb.badge then
			thumb.badge:Hide()
		end
	else
		drawBadge(thumb, preset, scale)
	end
	local rects, screenWidth, screenHeight = previewRects(preset, scale)
	local thumbWidth, thumbHeight = thumb:GetWidth(), thumb:GetHeight()
	local scaleX, scaleY = thumbWidth / screenWidth, thumbHeight / screenHeight
	for i, item in ipairs(rects) do
		local texture = thumb.textures[i]
		if not texture then
			texture = thumb:CreateTexture(nil, "ARTWORK")
			texture:SetTexture(ui.Media.blank)
			thumb.textures[i] = texture
		end
		local rect = item.rect
		local left = max(0, min(thumbWidth - 1, rect[1] * scaleX))
		local bottom = max(0, min(thumbHeight - 1, rect[2] * scaleY))
		local right = max(left + 1, min(thumbWidth, (rect[1] + rect[3]) * scaleX))
		local top = max(bottom + 1, min(thumbHeight, (rect[2] + rect[4]) * scaleY))
		texture:ClearAllPoints()
		texture:SetPoint("BOTTOMLEFT", left, bottom)
		texture:SetSize(right - left, top - bottom)
		texture:SetVertexColor(unpack(COLORS[item.kind]))
		texture:Show()
	end
end

local function cardHeight()
	local thumbHeight = floor(THUMB_WIDTH * UIParent:GetHeight() / UIParent:GetWidth() + 0.5)
	return thumbHeight + CARD_PADDING * 2 + NAME_HEIGHT
end

local function paintCard(card)
	local color = BORDER_COLOR
	if card.active then
		color = ACTIVE_BORDER_COLOR
	elseif card.hovered then
		color = HOVER_BORDER_COLOR
	end
	card:SetBackdropBorderColor(color[1], color[2], color[3])
	local text = card.active and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR
	card.name:SetTextColor(text.r, text.g, text.b)
	ui.SetShown(card.check, card.active)
end

local function cardEnter(card)
	card.hovered = true
	paintCard(card)
	local preset = card.preset
	GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
	GameTooltip:SetText(L[preset.name], HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddLine(L[preset.desc], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	local _, fit = layoutFitText(preset)
	GameTooltip:AddLine(fit, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, true)
	if card.active then
		GameTooltip:AddLine(L["Active layout"], GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
	else
		GameTooltip:AddLine(L["Click to apply"], GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	end
	GameTooltip:Show()
end

local function cardLeave(card)
	card.hovered = nil
	paintCard(card)
	GameTooltip:Hide()
end

local function applyPreset(preset)
	ns.Confirm(
		L["Apply the %s layout? Frames move, and bar columns, frame and castbar sizes change to the layout's. Other settings stay."]:format(
			L[preset.name]
		),
		function()
			if ui.Movers.ApplyPreset(preset.key) then
				ui.Print(L["layout %q applied"], L[preset.name])
			end
		end
	)
end

local function cardClick(card)
	if not card.active then
		applyPreset(card.preset)
	end
end

local function createCard(row, preset, index, height)
	local card = CreateFrame("Button", nil, row)
	card:SetSize(CARD_WIDTH, height)
	local column, line = (index - 1) % COLUMNS, floor((index - 1) / COLUMNS)
	card:SetPoint("TOPLEFT", CARD_X + column * (CARD_WIDTH + CARD_GAP), -line * (height + CARD_GAP))
	card:SetBackdrop(ui.CreateBackdrop(8))
	card:SetBackdropColor(unpack(CARD_COLOR))
	card:SetScript("OnEnter", cardEnter)
	card:SetScript("OnLeave", cardLeave)
	card:SetScript("OnClick", cardClick)
	card.preset = preset

	local thumb = CreateFrame("Frame", nil, card)
	thumb:SetPoint("TOPLEFT", CARD_PADDING, -CARD_PADDING)
	thumb:SetSize(THUMB_WIDTH, height - CARD_PADDING * 2 - NAME_HEIGHT)
	card.thumb = thumb

	local name = card:CreateFontString(nil, "OVERLAY")
	name:SetFontObject(ns.Font("GameFontHighlight"))
	name:SetPoint("BOTTOM", 0, CARD_PADDING + 3)
	name:SetText(L[preset.name])
	card.name = name

	local check = ui.CreateGlyph(card, "circle-check", 12)
	check:SetTextColor(ACTIVE_BORDER_COLOR[1], ACTIVE_BORDER_COLOR[2], ACTIVE_BORDER_COLOR[3])
	check:SetPoint("RIGHT", name, "LEFT", -5, 0)
	card.check = check
	return card
end

local function refreshGallery(row)
	local active = ui.Movers.GetActivePreset()
	for _, card in ipairs(row.cards) do
		card.active = card.preset.key == active
		paintCard(card)
		drawThumbnail(card.thumb, card.preset)
	end
end

local function galleryHeight()
	local lines = ceil(#ui.Movers.GetPresets() / COLUMNS)
	return lines * cardHeight() + (lines - 1) * CARD_GAP + 4
end

local function buildGallery(row)
	row:EnableMouse(false)
	local height = cardHeight()
	row:SetHeight(galleryHeight())
	row.cards = {}
	for index, preset in ipairs(ui.Movers.GetPresets()) do
		row.cards[index] = createCard(row, preset, index, height)
	end
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
	local function save()
		local ok, saved = ui.Movers.SaveLayout(name)
		if ok then
			ui.Print(L["layout %q saved"], saved)
			ns.RefreshPage()
		end
	end
	if ui.Movers.LayoutExists(name) then
		ns.Confirm(L['Replace the layout "%s"? The old one can be restored on the Backups page.']:format(name), save)
	else
		save()
	end
end

local function showLayoutExport(name)
	local text = ui.Movers.ExportLayout(name)
	if text then
		ns.ShowTextWindow(L["Export layout: %s"]:format(name), text)
	end
end

local function showLayoutImport()
	ns.ShowImportWindow(L["Import layout"], function(text)
		local ok, result = ui.Movers.ImportLayout(text)
		if ok then
			ns.HideTextWindow()
			ui.Print(L["layout %q imported"], result)
			ns.RefreshPage()
			ns.Confirm(L['Layout "%s" is imported. Load it now?']:format(result), function()
				ui.Movers.LoadLayout(result)
			end)
		else
			ui.Print(L["import failed: %s"], result)
		end
	end)
end

local schema = {
	{ header = L["Presets"], new = "1.5.0", glyph = "table-cells-large" },
	{
		description = L["Ready-made arrangements of the action bars, unit frames, castbars and cooldowns. A preset moves the frames and sets bar columns, frame and castbar sizes; colors, texts and everything else stay."],
	},
	{
		description = L["Presets have a full variant for a UI scale of %d%% or lower (a screen at least 1000 interface units high) and a compact one for a larger scale. The badge on a card shows the UI scale of the variant that applies on this screen. FullHD is made for 1920x1080 and smaller screens. Standard is the same on any screen."]:format(
			fullScalePercent()
		),
	},
	{
		type = "custom",
		label = "",
		indent = false,
		height = galleryHeight(),
		build = buildGallery,
		refresh = refreshGallery,
	},
	{ header = L["Frame movers"], glyph = "arrows-up-down-left-right" },
	{
		label = L["Move frames"],
		type = "execute",
		text = L["Unlock"],
		glyph = "up-down-left-right",
		desc = L["Drag frames to move them, drag the bottom-right corner of a frame to resize it. Frames snap to each other, to screen edges and to screen center lines, and stay attached to the frame they snapped to. Hold Shift to move without snapping; the attachment is kept."],
		func = function()
			ui.Movers.Unlock()
			if ui.Movers.IsUnlocked() then
				ns.Toggle()
			end
		end,
	},
	{
		path = "general.showGrid",
		label = L["Alignment grid"],
		type = "toggle",
		desc = L["Grid over the screen while frames are unlocked; dragged frames snap to its lines. Screen center lines are always drawn."],
	},
	{
		path = "general.gridSize",
		label = L["Grid step"],
		type = "number",
		min = 8,
		max = 128,
		step = 4,
		enabledBy = "general.showGrid",
	},
	{
		path = "general.snapGap",
		new = "1.5.0",
		label = L["Gap when snapping"],
		type = "number",
		min = 0,
		max = 20,
		step = 1,
		advanced = true,
		desc = L["Space left between two frames that snap side by side. 0 puts them edge to edge."],
	},
	{
		path = "general.snapDistance",
		new = "1.5.0",
		label = L["Snapping distance"],
		type = "number",
		min = 0,
		max = 30,
		step = 1,
		zeroText = L["Off"],
		advanced = true,
		desc = L["How close a dragged frame must come to an edge or center line to snap to it."],
	},
	{
		label = L["Reset positions"],
		new = "1.5.0",
		type = "execute",
		text = L["Reset"],
		glyph = "rotate-left",
		confirm = ui.Movers.GetResetPositionsText,
		func = function()
			ui.Movers.ResetPositions()
		end,
		desc = L["Move every frame back to its place in the last applied or loaded layout. Other settings stay. Also: /fui reset"],
	},
	{ header = L["Saved layouts"], new = "1.5.0", glyph = "layer-group" },
	{
		description = L["A saved layout keeps frame positions together with bar columns, frame and castbar sizes, shared by all characters. Loading one changes only those in the active profile."],
	},
	{
		label = L["Save layout"],
		new = "1.5.0",
		type = "input",
		text = L["Save"],
		glyph = "floppy-disk",
		width = 160,
		maxLetters = 32,
		func = saveLayout,
		desc = L["Type a name and press Enter to save the current layout. Saving under an existing name asks first."],
	},
	{
		label = L["Saved layout"],
		new = "1.5.0",
		type = "choice",
		placeholder = L["Select layout..."],
		values = layoutOptions,
		disabled = noLayouts,
		disabledDesc = L["No saved layouts yet."],
		actions = {
			{
				text = L["Load layout"],
				glyph = "folder-open",
				confirm = L["Move all frames to the positions saved in layout %q?"],
				func = ui.Movers.LoadLayout,
			},
			{
				text = L["Export layout"],
				glyph = "file-export",
				desc = L["Show a layout as a string to copy."],
				func = showLayoutExport,
			},
			{
				text = L["Delete layout"],
				glyph = "trash-can",
				confirm = L["Delete layout %q? It can be restored on the Backups page until another layout is deleted or replaced."],
				func = ui.Movers.DeleteLayout,
			},
		},
		desc = L["Pick a saved layout, then load, export or delete it with the buttons."],
	},
	{
		label = L["Import layout"],
		new = "1.5.0",
		type = "execute",
		text = L["Import"],
		glyph = "file-import",
		func = showLayoutImport,
		desc = L["Paste a layout string to add it to the list."],
	},
}

ns.DrawLayoutThumbnail = drawThumbnail
ns.LayoutFitText = layoutFitText

ns.RegisterPage({
	key = "layouts",
	name = L["Layouts"],
	desc = L["Ready-made frame layouts and your saved ones."],
	glyph = "table-cells-large",
	order = 12,
	group = "start",
	schema = schema,
	noReset = true,
})
