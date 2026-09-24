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

local POINT_PARTS = {
	BOTTOMLEFT = { 1, 1 },
	BOTTOM = { 2, 1 },
	BOTTOMRIGHT = { 3, 1 },
	LEFT = { 1, 2 },
	CENTER = { 2, 2 },
	RIGHT = { 3, 2 },
	TOPLEFT = { 1, 3 },
	TOP = { 2, 3 },
	TOPRIGHT = { 3, 3 },
}

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

local layoutSettings = {}
for _, path in ipairs(ui.LayoutSettings) do
	layoutSettings[path] = true
end

local function defaultValue(path)
	local node = ui.Defaults
	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

local function enabled(path)
	return function()
		return ui:GetConfig(path) ~= false
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
	{ "actionBar.microMenu", "info" },
	{ "groupCooldowns.friendlyPoint", "cooldown", nil, enabled("groupCooldowns.friendly") },
	{ "groupCooldowns.enemyPoint", "cooldown", nil, enabled("groupCooldowns.enemy") },
}

for i = 1, 6 do
	local key = "bar" .. i
	ELEMENTS[#ELEMENTS + 1] =
		{ "actionBar." .. key .. ".point", "bar", barSize(key), enabled("actionBar." .. key .. ".enabled") }
end

local function addGroup(prefix, count, kind, shownPath)
	for i = 1, count do
		local path = "unitFrames." .. (i == 1 and prefix or prefix .. i)
		ELEMENTS[#ELEMENTS + 1] = { path, kind, unitSize(prefix), enabled(shownPath) }
		ELEMENTS[#ELEMENTS + 1] = {
			"unitFrames." .. prefix .. i .. "Castbar",
			"cast",
			castbarSize(prefix),
			enabled(shownPath),
		}
	end
end

addGroup("party", 4, "friend", "unitFrames.showParty")
addGroup("arena", 3, "enemy", "unitFrames.showArena")

local tail = {
	{ "playerPlate.point", "friend", nil, enabled("playerPlate.enabled") },
	{ "unitFrames.playerCastbar", "cast", castbarSize("player") },
	{ "unitFrames.targetCastbar", "cast", castbarSize("target"), enabled("unitFrames.showTargetCastbar") },
	{ "unitFrames.focusCastbar", "cast", castbarSize("focus"), enabled("unitFrames.showFocusCastbar") },
	{ "unitFrames.player", "friend", unitSize("player") },
	{ "unitFrames.target", "enemy", unitSize("player") },
	{ "unitFrames.focus", "focus", unitSize("player") },
}
for _, element in ipairs(tail) do
	ELEMENTS[#ELEMENTS + 1] = element
end

local SIZES = {}
for _, element in ipairs(ELEMENTS) do
	SIZES[element[1]] = element[3]
end

local function previewRects(preset)
	local points, settings = ui.Movers.GetPresetLayout(preset.key)
	settings = settings or {}
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
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

local function drawThumbnail(thumb, preset)
	thumb.textures = thumb.textures or {}
	for _, texture in ipairs(thumb.textures) do
		texture:Hide()
	end
	local rects, screenWidth, screenHeight = previewRects(preset)
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

local function thumbHeight()
	return floor(THUMB_WIDTH * UIParent:GetHeight() / UIParent:GetWidth() + 0.5)
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
	local screen = thumb:CreateTexture(nil, "BACKGROUND")
	screen:SetTexture(ui.Media.blank)
	screen:SetVertexColor(unpack(SCREEN_COLOR))
	screen:SetAllPoints()
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
	return lines * (thumbHeight() + CARD_PADDING * 2 + NAME_HEIGHT) + (lines - 1) * CARD_GAP + 4
end

local function buildGallery(row)
	row:EnableMouse(false)
	local cardHeight = thumbHeight() + CARD_PADDING * 2 + NAME_HEIGHT
	row:SetHeight(galleryHeight())
	row.cards = {}
	for index, preset in ipairs(ui.Movers.GetPresets()) do
		row.cards[index] = createCard(row, preset, index, cardHeight)
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
	local ok, saved = ui.Movers.SaveLayout(name)
	if ok then
		ui.Print(L["layout %q saved"], saved)
		ns.RefreshPage()
	end
end

local function loadLayout(name)
	ns.Confirm(L["Move all frames to the positions saved in layout %q?"]:format(name), function()
		ui.Movers.LoadLayout(name)
	end)
end

local function deleteLayout(name)
	ns.Confirm(L["Delete layout %q?"]:format(name), function()
		ui.Movers.DeleteLayout(name)
		ns.RefreshPage()
	end)
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
		else
			ui.Print(L["import failed: %s"], result)
		end
	end)
end

local schema = {
	{ header = L["Presets"], new = "1.4.1", glyph = "table-cells-large" },
	{
		description = L["Ready-made arrangements of the action bars, unit frames, castbars and cooldowns. A preset moves the frames and sets bar columns, frame and castbar sizes; colors, texts and everything else stay."],
	},
	{
		description = L["Presets are built for a screen at least 1000 interface units high. Below that (UI scale above about 0.77 on a 16:9 screen) they use a compact variant, and so does Reset positions."],
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
		desc = L["Drag frames to move them, drag the bottom-right corner of a frame to resize it. Frames snap to each other, to screen edges and to screen center lines, and stay attached to the frame they snapped to. Hold Shift to drop snapping and detach."],
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
		desc = L["Grid over the screen while frames are unlocked. Screen center lines are always drawn."],
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
		label = L["Reset positions"],
		new = "1.4.1",
		type = "execute",
		text = L["Reset"],
		glyph = "rotate-left",
		confirm = L["Reset the positions of all frames to defaults?"],
		func = function()
			ui.Movers.ResetPositions()
		end,
		desc = L["Move every frame back to its default position. Other settings stay. Also: /fui reset"],
	},
	{ header = L["Saved layouts"], new = "1.4.1", glyph = "layer-group" },
	{
		description = L["A saved layout keeps frame positions together with bar columns, frame and castbar sizes, shared by all characters. Loading one changes only those in the active profile."],
	},
	{
		label = L["Save layout"],
		new = "1.4.1",
		type = "string",
		width = 160,
		maxLetters = 32,
		get = function()
			return ""
		end,
		set = saveLayout,
		desc = L["Type a name and press Enter to save the current layout. An existing layout with that name is overwritten."],
	},
	{
		label = L["Load layout"],
		new = "1.4.1",
		type = "select",
		placeholder = L["Select layout..."],
		values = layoutOptions,
		get = function() end,
		set = loadLayout,
		disabled = noLayouts,
	},
	{
		label = L["Delete layout"],
		new = "1.4.1",
		type = "select",
		placeholder = L["Select layout..."],
		values = layoutOptions,
		get = function() end,
		set = deleteLayout,
		disabled = noLayouts,
	},
	{
		label = L["Export layout"],
		new = "1.4.1",
		type = "select",
		placeholder = L["Select layout..."],
		values = layoutOptions,
		get = function() end,
		set = showLayoutExport,
		disabled = noLayouts,
		desc = L["Show a layout as a string to copy."],
	},
	{
		label = L["Import layout"],
		new = "1.4.1",
		type = "execute",
		text = L["Import"],
		glyph = "file-import",
		func = showLayoutImport,
		desc = L["Paste a layout string to add it to the list."],
	},
}

ns.RegisterPage({
	key = "layouts",
	name = L["Layouts"],
	glyph = "table-cells-large",
	order = 12,
	group = "core",
	schema = schema,
	noReset = true,
})
