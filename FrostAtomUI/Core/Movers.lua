local _, ns = ...
local L = ns.L

local GameTooltip = GameTooltip
local InCombatLockdown, GetCursorPosition, IsShiftKeyDown = InCombatLockdown, GetCursorPosition, IsShiftKeyDown
local IsAddOnLoaded, LoadAddOn = IsAddOnLoaded, LoadAddOn
local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local tconcat, sort = table.concat, table.sort
local StaticPopup_Show = StaticPopup_Show

local BACKDROP_COLOR = { 0.2, 0.6, 1, 0.35 }
local BORDER_COLOR = { 0.5, 0.8, 1 }
local HOVER_COLOR = { 0.3, 0.8, 1, 0.5 }
local TEXT_COLOR = { 1, 1, 1 }
local ANCHORED_BACKDROP_COLOR = { 0.16, 0.34, 0.5, 0.18 }
local ANCHORED_BORDER_COLOR = { 0.3, 0.45, 0.55 }
local ANCHORED_HOVER_COLOR = { 0.22, 0.5, 0.65, 0.35 }
local ANCHORED_TEXT_COLOR = { 0.6, 0.65, 0.7 }
local GRIP_COLOR = { 0.8, 0.95, 1, 0.8 }
local GRID_COLOR = { 1, 1, 1, 0.12 }
local GRID_CENTER_COLOR = { 1, 0.4, 0.4, 0.4 }
local SELECTED_BORDER_COLOR = { 1, 0.82, 0 }
local SNAP_LINE_COLOR = { 1, 0.82, 0, 0.9 }
local ATTACH_LINE_COLOR = { 0.4, 1, 0.5, 0.9 }
local MIN_WIDTH, MIN_HEIGHT = 96, 26
local GRIP_SIZE = 12
local SNAP_DISTANCE = 10
local SNAP_GAP = 4
local ADJACENT_GAP = 24
local SHIFT_NUDGE = 10
local NUDGE_BUTTON = "FrostAtomUIMoversNudge"
local CONFIG_ADDON = "FrostAtomUI_Config"
local OVERLAY_STRATA = "DIALOG"
local LAYOUT_PREFIX = "FAUIL1:"
local MAX_LAYOUT_NAME = 32

local NUDGE_KEYS = {
	UP = { 0, 1 },
	DOWN = { 0, -1 },
	LEFT = { -1, 0 },
	RIGHT = { 1, 0 },
}

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

local PART_POINTS = {
	[1] = { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
	[2] = { "LEFT", "CENTER", "RIGHT" },
	[3] = { "TOPLEFT", "TOP", "TOPRIGHT" },
}

local Movers = ns:NewModule("Movers")
ns.Movers = Movers

local movers = {}
local byFrame = {}
local byPath = {}
local unlocked = false
local panel, grid
local selected
local testModeOwned = false

local function humanize(path)
	local words = {}
	for key in path:gmatch("[^.]+") do
		key = key:gsub("[pP]oint$", "")
		for word in key:gsub("(%l)(%u)", "%1 %2"):gmatch("%S+") do
			words[#words + 1] = word:lower()
		end
	end
	local text = tconcat(words, " ")
	return text:sub(1, 1):upper() .. text:sub(2)
end

local function fallbackSize(mover)
	local size = mover.size
	if type(size) == "function" then
		return size()
	elseif size then
		return size[1], size[2]
	end
	return MIN_WIDTH, MIN_HEIGHT
end

local function registeredFrame(path)
	local mover = byPath[path]
	return mover and mover.frame
end

local function isListPath(path)
	return path:find("%.%d+%.") ~= nil or path:find("%.%d+$") ~= nil
end

local function defaultPoint(path)
	local node = ns.Defaults
	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[tonumber(key) or key]
	end
	return type(node) == "table" and node[1] ~= nil and node or nil
end

local function isStorable(path)
	return not isListPath(path) and defaultPoint(path) ~= nil
end

local function isEnabledAlong(path)
	local node = ns.Config
	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return true
		elseif node.enabled == false then
			return false
		end
		node = node[tonumber(key) or key]
	end
	return true
end

local function isActive(mover)
	if not isEnabledAlong(mover.path) then
		return false
	elseif mover.enabledPath and ns:GetConfig(mover.enabledPath) == false then
		return false
	end
	return not mover.visible or mover.visible() and true or false
end

function Movers.GetLabel(path)
	local mover = byPath[path]
	return mover and L[mover.label] or path and humanize(path)
end

function ns.ApplyPoint(frame, path, offset)
	local point, x, y, anchorPath, anchorPoint = unpack(ns:GetConfig(path))
	local parent = anchorPath and registeredFrame(anchorPath)
	frame:ClearAllPoints()
	frame:SetPoint(point, parent or UIParent, parent and anchorPoint or point, x, y - (offset or 0))
end

local function notifyDependents(path)
	for i = 1, #movers do
		local other = movers[i]
		local value = other.path ~= path and ns:GetConfig(other.path)
		if value and value[4] == path then
			ns:Fire(ns.CONFIG_CHANGED, other.path)
		end
	end
end

local function wouldLoop(path, anchorPath)
	local steps = 0
	while anchorPath do
		if anchorPath == path then
			return true
		end
		steps = steps + 1
		if steps > #movers then
			return true
		end
		anchorPath = ns:GetConfig(anchorPath)[4]
	end
	return false
end

local function scaleOf(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function uiToFrameFactor(mover)
	return UIParent:GetEffectiveScale() / (mover.frame or mover.overlay):GetEffectiveScale()
end

local function cursorPosition()
	local uiScale = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	return cursorX / uiScale, cursorY / uiScale
end

local function rectOf(frame)
	if not frame or not frame:GetLeft() then
		return nil
	end
	local scale = scaleOf(frame)
	return frame:GetLeft() * scale, frame:GetBottom() * scale, frame:GetWidth() * scale, frame:GetHeight() * scale
end

local function edge(low, size, part)
	if part == 1 then
		return low
	elseif part == 3 then
		return low + size
	end
	return low + size / 2
end

local function frameRect(mover)
	local left, bottom, width, height = rectOf(mover.frame)
	if not left then
		left, bottom, width, height = rectOf(mover.overlay)
	end
	return left, bottom, width, height
end

local function insetsOf(mover)
	local insets = mover.insets
	if type(insets) == "function" then
		return insets()
	elseif insets then
		return insets[1], insets[2], insets[3], insets[4]
	end
	return 0, 0, 0, 0
end

local function moverRect(mover)
	local left, bottom, width, height = rectOf(mover.frame)
	if not left then
		return rectOf(mover.overlay)
	end

	local scale = scaleOf(mover.frame)
	if mover.size then
		local sizeWidth, sizeHeight = fallbackSize(mover)
		sizeWidth, sizeHeight = sizeWidth * scale, sizeHeight * scale
		local xPart, yPart = unpack(POINT_PARTS[ns:GetConfig(mover.path)[1]] or POINT_PARTS.CENTER)
		left = edge(left, width, xPart) - (xPart - 1) * sizeWidth / 2
		bottom = edge(bottom, height, yPart) - (yPart - 1) * sizeHeight / 2
		width, height = sizeWidth, sizeHeight
	end

	local insetLeft, insetRight, insetTop, insetBottom = insetsOf(mover)
	return left - insetLeft * scale,
		bottom - insetBottom * scale,
		width + (insetLeft + insetRight) * scale,
		height + (insetTop + insetBottom) * scale
end

local function placeLabel(overlay)
	local text = overlay.text
	text:ClearAllPoints()
	if overlay:GetWidth() < text:GetStringWidth() + 8 or overlay:GetHeight() < MIN_HEIGHT then
		text:SetPoint("BOTTOM", overlay, "TOP", 0, 2)
	else
		text:SetPoint("CENTER")
	end
end

local function attach(mover)
	local overlay = mover.overlay
	overlay:ClearAllPoints()
	local left, bottom, width, height = moverRect(mover)
	local frameLeft, frameBottom = rectOf(mover.frame)
	if left and frameLeft then
		overlay:SetSize(max(width, 1), max(height, 1))
		overlay:SetPoint("BOTTOMLEFT", mover.frame, "BOTTOMLEFT", left - frameLeft, bottom - frameBottom)
	else
		local fallbackWidth, fallbackHeight = fallbackSize(mover)
		overlay:SetSize(max(fallbackWidth, 1), max(fallbackHeight, 1))
		ns.ApplyPoint(overlay, mover.path)
	end
	placeLabel(overlay)
end

local function showTooltip(overlay)
	local mover = overlay.mover
	local point, x, y, anchorPath, anchorPoint = unpack(ns:GetConfig(mover.path))
	GameTooltip:SetOwner(overlay, "ANCHOR_TOP")
	GameTooltip:SetText(L[mover.label], 1, 1, 1)
	if anchorPath then
		GameTooltip:AddLine(
			L["%s  %d, %d  of  %s %s"]:format(point, x, y, Movers.GetLabel(anchorPath), anchorPoint),
			0.4,
			1,
			0.5
		)
	else
		GameTooltip:AddLine(("%s  %d, %d"):format(point, x, y), 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine(L["Click to open settings"], 0.6, 0.6, 0.6)
	GameTooltip:AddLine(L["Drag to move, right-click to reset, hold Shift to drop snapping"], 0.6, 0.6, 0.6)
	if mover == selected then
		GameTooltip:AddLine(L["Arrow keys nudge by 1 px, Shift+arrows by 10 px, Esc clears the selection"], 1, 0.82, 0)
	else
		GameTooltip:AddLine(L["Selected frames nudge with the arrow keys"], 0.6, 0.6, 0.6)
	end
	if mover.resize then
		GameTooltip:AddLine(L["Drag the bottom-right corner to resize"], 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

local linesX, linesY, parts = {}, {}, {}

local function addLine(lines, low, size, owner)
	for part = 1, 3 do
		lines[#lines + 1] = { value = edge(low, size, part), part = part, mover = owner }
	end
end

local function collectSnapLines(mover)
	wipe(linesX)
	wipe(linesY)
	addLine(linesX, 0, UIParent:GetWidth(), nil)
	addLine(linesY, 0, UIParent:GetHeight(), nil)
	for i = 1, #movers do
		local other = movers[i]
		if other ~= mover and other.overlay and other.overlay:IsShown() then
			local left, bottom, width, height = moverRect(other)
			if left then
				addLine(linesX, left, width, other)
				addLine(linesY, bottom, height, other)
			end
		end
	end
end

local function gapBetween(part, linePart, owner)
	if not owner then
		return 0
	elseif part == 1 and linePart == 3 then
		return SNAP_GAP
	elseif part == 3 and linePart == 1 then
		return -SNAP_GAP
	end
	return 0
end

local function snapOffset(lines, low, size)
	local best, bestDistance, bestLine, bestPart = 0, SNAP_DISTANCE, nil, nil
	parts[1], parts[2], parts[3] = low, low + size / 2, low + size
	for i = 1, #lines do
		local line = lines[i]
		for part = 1, 3 do
			local distance = line.value + gapBetween(part, line.part, line.mover) - parts[part]
			if abs(distance) < bestDistance then
				best, bestDistance, bestLine, bestPart = distance, abs(distance), line, part
			end
		end
	end
	return best, bestLine, bestPart
end

local snapLineFrame
local snapLines = {}

local function snapLine(axis)
	local line = snapLines[axis]
	if not line then
		if not snapLineFrame then
			snapLineFrame = CreateFrame("Frame", nil, UIParent)
			snapLineFrame:SetAllPoints()
			snapLineFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		end
		line = snapLineFrame:CreateTexture(nil, "OVERLAY")
		line:SetTexture(ns.Media.blank)
		snapLines[axis] = line
	end
	return line
end

local function hideSnapLines()
	for _, line in pairs(snapLines) do
		line:Hide()
	end
end

local function showSnapLine(axis, value, attached)
	local line = snapLine(axis)
	local thickness = ns.PixelPerfect(2)
	line:ClearAllPoints()
	if axis == "x" then
		local x = min(max(value - thickness / 2, 0), UIParent:GetWidth() - thickness)
		line:SetWidth(thickness)
		line:SetPoint("TOPLEFT", snapLineFrame, "TOPLEFT", x, 0)
		line:SetPoint("BOTTOMLEFT", snapLineFrame, "BOTTOMLEFT", x, 0)
	else
		local y = min(max(value - thickness / 2, 0), UIParent:GetHeight() - thickness)
		line:SetHeight(thickness)
		line:SetPoint("BOTTOMLEFT", snapLineFrame, "BOTTOMLEFT", 0, y)
		line:SetPoint("BOTTOMRIGHT", snapLineFrame, "BOTTOMRIGHT", 0, y)
	end
	line:SetVertexColor(unpack(attached and ATTACH_LINE_COLOR or SNAP_LINE_COLOR))
	line:Show()
end

local updateSnapLines

local dragging
local dragFrame = CreateFrame("Frame")
dragFrame:Hide()

local function updateDrag()
	local mover = dragging
	local cursorX, cursorY = cursorPosition()
	local dx = cursorX - mover.cursorX
	local dy = cursorY - mover.cursorY

	mover.snapX, mover.snapY, mover.lineX, mover.lineY = nil, nil, nil, nil
	if not IsShiftKeyDown() then
		local offsetX, lineX, partX = snapOffset(linesX, mover.left + dx, mover.width)
		local offsetY, lineY, partY = snapOffset(linesY, mover.bottom + dy, mover.height)
		dx, dy = dx + offsetX, dy + offsetY
		mover.lineX, mover.lineY = lineX, lineY
		if lineX and lineX.mover then
			mover.snapX = { line = lineX, part = partX, distance = abs(offsetX) }
		end
		if lineY and lineY.mover then
			mover.snapY = { line = lineY, part = partY, distance = abs(offsetY) }
		end
	end

	local factor = uiToFrameFactor(mover)
	local x = floor(mover.startX + dx * factor + 0.5)
	local y = floor(mover.startY + dy * factor + 0.5)
	mover.finalLeft = mover.left + (x - mover.startX) / factor
	mover.finalBottom = mover.bottom + (y - mover.startY) / factor
	updateSnapLines(mover)
	if x ~= mover.lastX or y ~= mover.lastY then
		mover.lastX, mover.lastY = x, y
		local point, _, _, anchorPath, anchorPoint = unpack(ns:GetConfig(mover.path))
		ns:SetConfig(mover.path, { point, x, y, anchorPath, anchorPoint })
		showTooltip(mover.overlay)
	end
end

local function draggedRect(mover)
	if mover.finalLeft then
		return mover.finalLeft, mover.finalBottom, mover.width, mover.height
	end
	return moverRect(mover)
end

local function draggedFrameRect(mover)
	local left, bottom, width, height = frameRect(mover)
	if left and mover.finalLeft and mover.frameLeft then
		return mover.frameLeft + (mover.finalLeft - mover.left),
			mover.frameBottom + (mover.finalBottom - mover.bottom),
			width,
			height
	end
	return left, bottom, width, height
end

local function anchorTo(mover, target, xPart, yPart, theirXPart, theirYPart)
	local left, bottom, width, height = draggedFrameRect(mover)
	local targetLeft, targetBottom, targetWidth, targetHeight = frameRect(target)
	if not left or not targetLeft then
		return
	end
	local factor = uiToFrameFactor(mover)
	local x = (edge(left, width, xPart) - edge(targetLeft, targetWidth, theirXPart)) * factor
	local y = (edge(bottom, height, yPart) - edge(targetBottom, targetHeight, theirYPart)) * factor
	ns:SetConfig(mover.path, {
		PART_POINTS[yPart][xPart],
		floor(x + 0.5),
		floor(y + 0.5),
		target.path,
		PART_POINTS[theirYPart][theirXPart],
	})
end

local function detach(mover)
	local point, offsetX, offsetY, anchorPath = unpack(ns:GetConfig(mover.path))
	if not anchorPath then
		return
	end
	local left, bottom, width, height = draggedFrameRect(mover)
	if not left then
		ns:SetConfig(mover.path, { point, offsetX, offsetY })
		return
	end
	local xPart, yPart = unpack(POINT_PARTS[point] or POINT_PARTS.CENTER)
	local factor = uiToFrameFactor(mover)
	local x = (edge(left, width, xPart) - edge(0, UIParent:GetWidth(), xPart)) * factor
	local y = (edge(bottom, height, yPart) - edge(0, UIParent:GetHeight(), yPart)) * factor
	ns:SetConfig(mover.path, { point, floor(x + 0.5), floor(y + 0.5) })
end

local function isNear(mover, target, axis)
	local left, bottom, width, height = draggedRect(mover)
	local targetLeft, targetBottom, targetWidth, targetHeight = moverRect(target)
	if not left or not targetLeft then
		return false
	end
	local low, high, targetLow, targetHigh
	if axis == "x" then
		low, high, targetLow, targetHigh = bottom, bottom + height, targetBottom, targetBottom + targetHeight
	else
		low, high, targetLow, targetHigh = left, left + width, targetLeft, targetLeft + targetWidth
	end
	return low - targetHigh < ADJACENT_GAP and targetLow - high < ADJACENT_GAP
end

local function resolveSnaps(mover)
	local snapX, snapY = mover.snapX, mover.snapY
	if snapX and not isNear(mover, snapX.line.mover, "x") then
		snapX = nil
	end
	if snapY and not isNear(mover, snapY.line.mover, "y") then
		snapY = nil
	end
	if not snapX and not snapY then
		return
	end

	if snapX and snapY and snapX.line.mover ~= snapY.line.mover then
		if snapX.distance <= snapY.distance then
			snapY = nil
		else
			snapX = nil
		end
	end
	local target = (snapX or snapY).line.mover
	if target == mover or wouldLoop(mover.path, target.path) then
		return
	end
	return target, snapX, snapY
end

function updateSnapLines(mover)
	local lineX, lineY = mover.lineX, mover.lineY
	if not lineX and not lineY then
		hideSnapLines()
		return
	end
	local _, snapX, snapY = resolveSnaps(mover)
	if lineX then
		showSnapLine("x", lineX.value, snapX ~= nil)
	elseif snapLines.x then
		snapLines.x:Hide()
	end
	if lineY then
		showSnapLine("y", lineY.value, snapY ~= nil)
	elseif snapLines.y then
		snapLines.y:Hide()
	end
end

local function applySnapAnchor(mover)
	local target, snapX, snapY = resolveSnaps(mover)
	if not target then
		return
	end

	anchorTo(
		mover,
		target,
		snapX and snapX.part or 2,
		snapY and snapY.part or 2,
		snapX and snapX.line.part or 2,
		snapY and snapY.line.part or 2
	)
end

local selectMover

local function loadedConfig()
	return IsAddOnLoaded(CONFIG_ADDON) and _G[CONFIG_ADDON] or nil
end

local function loadConfig()
	if not IsAddOnLoaded(CONFIG_ADDON) then
		local loaded, reason = LoadAddOn(CONFIG_ADDON)
		if not loaded then
			ns.Print(L["cannot load FrostAtomUI_Config: %s"], _G["ADDON_" .. reason] or reason)
			return nil
		end
	end
	return _G[CONFIG_ADDON]
end

local function openSettings(path)
	local config = loadConfig()
	local mover = byPath[path]
	if config and config.OpenElement then
		config.OpenElement(path, mover and mover.overlay)
	end
end

local function closeSettings()
	local config = loadedConfig()
	if config and config.CloseElement then
		config.CloseElement()
	end
end

local function openedSettings()
	local config = loadedConfig()
	return config and config.GetOpenElement and config.GetOpenElement()
end

local function onMouseDown(overlay, button)
	local mover = overlay.mover
	mover.cursorX, mover.cursorY = cursorPosition()
	mover.dragged = false
	if button == "LeftButton" then
		selectMover(mover)
		local opened = openedSettings()
		if opened and opened ~= mover.path and selected == mover then
			openSettings(mover.path)
		end
	end
end

local function onDragStart(overlay)
	local mover = overlay.mover
	mover.dragged = true
	if mover.secure and InCombatLockdown() then
		return
	end
	mover.left, mover.bottom, mover.width, mover.height = moverRect(mover)
	if not mover.left then
		return
	end
	mover.frameLeft, mover.frameBottom = frameRect(mover)
	mover.finalLeft, mover.finalBottom = nil, nil
	detach(mover)
	local _, startX, startY = unpack(ns:GetConfig(mover.path))
	mover.startX, mover.startY = startX, startY
	mover.lastX, mover.lastY = mover.startX, mover.startY
	collectSnapLines(mover)
	dragging = mover
	dragFrame:Show()
end

local function onDragStop(overlay)
	local mover = overlay.mover
	if dragging ~= mover then
		return
	end
	updateDrag()
	dragging = nil
	dragFrame:Hide()
	hideSnapLines()
	applySnapAnchor(mover)
	mover.finalLeft, mover.finalBottom, mover.frameLeft, mover.frameBottom = nil, nil, nil, nil
	attach(mover)
	if overlay:IsMouseOver() then
		showTooltip(overlay)
	end
end

dragFrame:SetScript("OnUpdate", updateDrag)

local resizing
local resizeFrame = CreateFrame("Frame")
resizeFrame:Hide()

local function updateResize()
	local mover = resizing
	local resize = mover.resize
	local cursorX, cursorY = cursorPosition()
	local width = mover.startWidth + cursorX - mover.cursorX
	local height = mover.startHeight - (cursorY - mover.cursorY)

	width = floor(max(resize.minWidth or MIN_WIDTH, min(resize.maxWidth or UIParent:GetWidth(), width)) + 0.5)
	height = floor(max(resize.minHeight or MIN_HEIGHT, min(resize.maxHeight or UIParent:GetHeight(), height)) + 0.5)
	if resize.square then
		width = max(width, height)
		height = width
	end
	if width ~= mover.lastWidth or height ~= mover.lastHeight then
		mover.lastWidth, mover.lastHeight = width, height
		resize.set(width, height)
	end
end

resizeFrame:SetScript("OnUpdate", updateResize)

local function onGripMouseDown(grip)
	local mover = grip:GetParent().mover
	if mover.secure and InCombatLockdown() then
		return
	end
	mover.cursorX, mover.cursorY = cursorPosition()
	local _, _, width, height = moverRect(mover)
	mover.startWidth, mover.startHeight = mover.resize.get()
	mover.startWidth = mover.startWidth or width
	mover.startHeight = mover.startHeight or height
	mover.lastWidth, mover.lastHeight = nil, nil
	resizing = mover
	resizeFrame:Show()
end

local function onGripMouseUp(grip)
	local mover = grip:GetParent().mover
	if resizing ~= mover then
		return
	end
	updateResize()
	resizing = nil
	resizeFrame:Hide()
	attach(mover)
end

local function createGrip(overlay)
	local grip = CreateFrame("Button", nil, overlay)
	grip:SetSize(GRIP_SIZE, GRIP_SIZE)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(overlay:GetFrameLevel() + 1)
	grip:SetScript("OnMouseDown", onGripMouseDown)
	grip:SetScript("OnMouseUp", onGripMouseUp)

	for i = 1, 3 do
		local line = grip:CreateTexture(nil, "OVERLAY")
		line:SetTexture(ns.Media.blank)
		line:SetVertexColor(unpack(GRIP_COLOR))
		line:SetSize(GRIP_SIZE - (i - 1) * 4, 2)
		line:SetPoint("BOTTOMRIGHT", 0, (i - 1) * 4)
	end
	return grip
end

local function onClick(overlay, button)
	local mover = overlay.mover
	if button == "RightButton" then
		ns:ResetConfig(mover.path)
		attach(mover)
		showTooltip(overlay)
	elseif not mover.dragged and selected == mover then
		openSettings(mover.path)
	end
end

local function updateColors(mover, hover)
	local overlay = mover.overlay
	local anchored = ns:GetConfig(mover.path)[4] ~= nil
	if hover then
		overlay:SetBackdropColor(unpack(anchored and ANCHORED_HOVER_COLOR or HOVER_COLOR))
	else
		overlay:SetBackdropColor(unpack(anchored and ANCHORED_BACKDROP_COLOR or BACKDROP_COLOR))
	end
	if mover == selected then
		overlay:SetBackdropBorderColor(unpack(SELECTED_BORDER_COLOR))
	else
		overlay:SetBackdropBorderColor(unpack(anchored and ANCHORED_BORDER_COLOR or BORDER_COLOR))
	end
	overlay.text:SetTextColor(unpack(anchored and ANCHORED_TEXT_COLOR or TEXT_COLOR))
end

local function onEnter(overlay)
	updateColors(overlay.mover, true)
	showTooltip(overlay)
end

local function onLeave(overlay)
	updateColors(overlay.mover)
	GameTooltip:Hide()
end

local function createOverlay(mover)
	local overlay = CreateFrame("Button", nil, UIParent)
	overlay.mover = mover
	overlay:Hide()
	overlay:SetFrameStrata(OVERLAY_STRATA)
	overlay:SetMovable(true)
	overlay:SetClampedToScreen(true)
	overlay:EnableMouse(true)
	overlay:RegisterForDrag("LeftButton")
	overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	overlay:SetBackdrop(ns.CreateBackdrop(8, 2))
	overlay:SetBackdropColor(unpack(BACKDROP_COLOR))
	overlay:SetScript("OnMouseDown", onMouseDown)
	overlay:SetScript("OnDragStart", onDragStart)
	overlay:SetScript("OnDragStop", onDragStop)
	overlay:SetScript("OnClick", onClick)
	overlay:SetScript("OnEnter", onEnter)
	overlay:SetScript("OnLeave", onLeave)

	local text = overlay:CreateFontString(nil, "OVERLAY")
	ns.SetFont(text, 11, "OUTLINE", true)
	text:SetPoint("CENTER")
	text:SetText(L[mover.label])
	overlay.text = text

	if mover.resize then
		overlay.grip = createGrip(overlay)
	end
	return overlay
end

local function refresh(mover)
	updateColors(mover, mover.overlay:IsMouseOver())
	attach(mover)
end

local function updateVisibility(mover)
	local active = isActive(mover)
	if not active and mover == selected then
		selectMover(nil)
	end
	if active and not mover.overlay:IsShown() then
		refresh(mover)
	end
	ns.SetShown(mover.overlay, active)
end

local nudgeButton

local function nudge(_, button)
	local mover = selected
	if not mover then
		return
	end
	local key = button:gsub("^SHIFT%-", "")
	if key == "ESCAPE" then
		selectMover(nil)
		return
	end
	local step = NUDGE_KEYS[key]
	if not step or (mover.secure and InCombatLockdown()) then
		return
	end
	local distance = key ~= button and SHIFT_NUDGE or 1
	detach(mover)
	local point, x, y = unpack(ns:GetConfig(mover.path))
	ns:SetConfig(mover.path, { point, x + step[1] * distance, y + step[2] * distance })
	if mover.overlay:IsMouseOver() then
		showTooltip(mover.overlay)
	end
end

local function bindNudgeKeys()
	if not nudgeButton then
		nudgeButton = CreateFrame("Button", NUDGE_BUTTON, UIParent)
		nudgeButton:RegisterForClicks("AnyDown")
		nudgeButton:SetScript("OnClick", nudge)
	end
	ClearOverrideBindings(nudgeButton)
	for key in pairs(NUDGE_KEYS) do
		SetOverrideBindingClick(nudgeButton, true, key, NUDGE_BUTTON, key)
		SetOverrideBindingClick(nudgeButton, true, "SHIFT-" .. key, NUDGE_BUTTON, "SHIFT-" .. key)
	end
	SetOverrideBindingClick(nudgeButton, true, "ESCAPE", NUDGE_BUTTON, "ESCAPE")
end

function selectMover(mover)
	if mover == selected or (mover and InCombatLockdown()) then
		return
	end
	local previous = selected
	selected = mover
	if previous and previous.overlay then
		updateColors(previous, previous.overlay:IsMouseOver())
	end
	if mover then
		updateColors(mover, mover.overlay:IsMouseOver())
		if mover.overlay:IsMouseOver() then
			showTooltip(mover.overlay)
		end
		bindNudgeKeys()
	else
		if nudgeButton then
			ClearOverrideBindings(nudgeButton)
		end
		closeSettings()
	end
end

function Movers.Select(path)
	local mover = byPath[path]
	if not unlocked or not mover or not mover.overlay or not mover.overlay:IsShown() then
		return false
	end
	selectMover(mover)
	if selected ~= mover then
		return false
	end
	openSettings(path)
	return true
end

function Movers.ClearSelection()
	selectMover(nil)
end

function Movers.SetScale(frame, scale, keepPosition)
	local old = frame:GetScale()
	local mover = byFrame[frame]
	if not keepPosition or not mover or abs(old - scale) < 0.0001 then
		frame:SetScale(scale)
		return
	end
	local point, x, y, anchorPath, anchorPoint = unpack(ns:GetConfig(mover.path))
	local kept = mover.kept
	if not kept or kept.x ~= x or kept.y ~= y then
		kept = { visualX = x * old, visualY = y * old }
		mover.kept = kept
	end
	kept.x = floor(kept.visualX / scale + 0.5)
	kept.y = floor(kept.visualY / scale + 0.5)
	frame:SetScale(scale)
	ns:SetConfig(mover.path, { point, kept.x, kept.y, anchorPath, anchorPoint })
	ns.ApplyPoint(frame, mover.path)
end

function Movers.Register(frame, path, label, options)
	options = options or {}
	local mover = frame and byFrame[frame] or byPath[path]
	if not mover then
		mover = {}
		movers[#movers + 1] = mover
	end
	if frame then
		byFrame[frame] = mover
	end
	byPath[path] = mover
	mover.frame = frame
	mover.path = path
	mover.label = label or mover.label or humanize(path)
	for key, value in pairs(options) do
		mover[key] = value
	end
	if mover.overlay then
		mover.overlay.text:SetText(L[mover.label])
		if unlocked then
			refresh(mover)
			updateVisibility(mover)
		end
	elseif unlocked then
		mover.overlay = createOverlay(mover)
		updateVisibility(mover)
	end
	notifyDependents(path)
	return mover
end

function Movers.Unregister(frame)
	local mover = byFrame[frame]
	if not mover then
		return
	end
	if mover == selected then
		selectMover(nil)
	end
	byFrame[frame] = nil
	byPath[mover.path] = nil
	ns.tDeleteItem(movers, mover)
	if mover.overlay then
		mover.overlay:Hide()
	end
end

function Movers.Detach(path)
	local mover = byPath[path]
	if mover then
		detach(mover)
	end
end

local function anchorDepth(path)
	local depth, point = 0, defaultPoint(path)
	while point and point[4] and depth <= #movers do
		depth = depth + 1
		point = defaultPoint(point[4])
	end
	return depth
end

local function positionPaths()
	local paths, depths = {}, {}
	for i = 1, #movers do
		local path = movers[i].path
		if isStorable(path) then
			paths[#paths + 1] = path
			depths[path] = anchorDepth(path)
		end
	end
	sort(paths, function(a, b)
		if depths[a] ~= depths[b] then
			return depths[a] < depths[b]
		end
		return a < b
	end)
	return paths
end

local function canMove()
	if InCombatLockdown() then
		ns.Print(L["cannot move frames in combat"])
		return false
	end
	return true
end

function Movers.ResetPositions()
	if not canMove() then
		return
	end
	local paths = positionPaths()
	for i = 1, #paths do
		ns:ResetConfig(paths[i])
	end
end

StaticPopupDialogs.FROSTATOMUI_RESET_POSITIONS = {
	text = "Reset the positions of all frames to defaults?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		Movers.ResetPositions()
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

ns.OnLocaleReady(function()
	StaticPopupDialogs.FROSTATOMUI_RESET_POSITIONS.text = L["Reset the positions of all frames to defaults?"]
end)

function Movers.ConfirmResetPositions()
	local dialog = StaticPopup_Show("FROSTATOMUI_RESET_POSITIONS")
	if dialog then
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	end
end

local function layoutStore()
	local store = ns.db.layouts
	if not store then
		store = {}
		ns.db.layouts = store
	end
	return store
end

local function isValidPoint(value)
	if type(value) ~= "table" or not POINT_PARTS[value[1]] then
		return false
	elseif type(value[2]) ~= "number" or type(value[3]) ~= "number" then
		return false
	end
	local anchorPath = value[4]
	if anchorPath == nil then
		return true
	end
	return type(anchorPath) == "string" and POINT_PARTS[value[5]] ~= nil and type(ns:GetConfig(anchorPath)) == "table"
end

local function sanitizeLayout(points)
	if type(points) ~= "table" then
		return nil
	end
	local result, count = {}, 0
	for path, value in pairs(points) do
		if type(path) == "string" and isStorable(path) and isValidPoint(value) then
			local anchorPath = value[4]
			result[path] = {
				value[1],
				floor(value[2] + 0.5),
				floor(value[3] + 0.5),
				anchorPath,
				anchorPath and value[5] or nil,
			}
			count = count + 1
		end
	end
	return count > 0 and result or nil
end

local function cleanName(name)
	name = type(name) == "string" and name:trim() or ""
	if name == "" then
		return nil
	end
	return name:sub(1, MAX_LAYOUT_NAME)
end

function Movers.GetLayoutNames()
	local names = {}
	for name in pairs(layoutStore()) do
		names[#names + 1] = name
	end
	sort(names)
	return names
end

function Movers.SaveLayout(name)
	name = cleanName(name)
	if not name then
		return false
	end
	local points = {}
	for i = 1, #movers do
		local path = movers[i].path
		if isStorable(path) then
			local value = ns:GetConfig(path)
			points[path] = { value[1], value[2], value[3], value[4], value[5] }
		end
	end
	layoutStore()[name] = points
	return true, name
end

function Movers.LoadLayout(name)
	local points = sanitizeLayout(layoutStore()[name])
	if not points or not canMove() then
		return false
	end
	for path, value in pairs(points) do
		ns:SetConfig(path, value)
	end
	for path in pairs(points) do
		local point, x, y, anchorPath = unpack(ns:GetConfig(path))
		if anchorPath and wouldLoop(path, anchorPath) then
			ns:SetConfig(path, { point, x, y })
		end
	end
	return true
end

function Movers.DeleteLayout(name)
	layoutStore()[name] = nil
end

function Movers.ExportLayout(name)
	local points = layoutStore()[name]
	if not points then
		return nil
	end
	return LAYOUT_PREFIX .. ns.Encode(ns.Serialize({ name = name, points = points }))
end

function Movers.ImportLayout(text)
	text = text and text:trim()
	if not text or text:sub(1, #LAYOUT_PREFIX) ~= LAYOUT_PREFIX then
		return false, L["not a FrostAtom UI layout string"]
	end
	local body, err = ns.Decode(text:sub(#LAYOUT_PREFIX + 1))
	if not body then
		return false, err
	end
	local data = ns.Deserialize(body)
	local points = type(data) == "table" and sanitizeLayout(data.points)
	if not points then
		return false, L["malformed layout string"]
	end
	local store = layoutStore()
	local base = cleanName(data.name) or L["Imported layout"]
	local name, suffix = base, 1
	while store[name] do
		suffix = suffix + 1
		name = ("%s %d"):format(base, suffix)
	end
	store[name] = points
	return true, name
end

function ns.ModulePrototype:RegisterMover(frame, path, label, options)
	return Movers.Register(frame, path, label, options)
end

local function createGrid()
	grid = CreateFrame("Frame", nil, UIParent)
	grid:SetAllPoints()
	grid:SetFrameStrata("BACKGROUND")
	grid.lines = {}
end

local function gridLine(index)
	local line = grid.lines[index]
	if not line then
		line = grid:CreateTexture(nil, "BACKGROUND")
		grid.lines[index] = line
	end
	line:Show()
	return line
end

local function drawGridLine(index, color, vertical, offset)
	local line = gridLine(index)
	line:SetTexture(unpack(color))
	if vertical then
		line:SetWidth(1)
		line:SetPoint("TOP", grid, "TOP", offset, 0)
		line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
	else
		line:SetHeight(1)
		line:SetPoint("LEFT", grid, "LEFT", 0, offset)
		line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
	end
end

local function updateGrid()
	if not unlocked then
		return
	end
	if not grid then
		createGrid()
	end

	local size = ns.Config.general.gridSize
	local index = 0
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	local centerX, centerY = width / 2, height / 2

	if ns.Config.general.showGrid then
		for offset = -floor(centerX / size) * size, centerX, size do
			index = index + 1
			drawGridLine(index, GRID_COLOR, true, offset)
		end
		for offset = -floor(centerY / size) * size, centerY, size do
			index = index + 1
			drawGridLine(index, GRID_COLOR, false, offset)
		end
	end

	drawGridLine(index + 1, GRID_CENTER_COLOR, true, 0)
	drawGridLine(index + 2, GRID_CENTER_COLOR, false, 0)
	index = index + 2

	for i = index + 1, #grid.lines do
		grid.lines[i]:Hide()
	end
	grid:Show()
end

local function createLabel(parent, size, shade, text)
	local label = parent:CreateFontString(nil, "OVERLAY")
	ns.SetFont(label, size)
	label:SetTextColor(shade, shade, shade)
	label:SetText(text)
	return label
end

local function unitFrames()
	local UF = ns:GetModule("UnitFrames")
	return UF.frames and #UF.frames > 0 and UF or nil
end

local function onTestModeClick(check)
	local UF = unitFrames()
	if not UF then
		return
	end
	UF:SetTestMode(check:GetChecked() and true or false)
	testModeOwned = UF.testing or false
	check:SetChecked(UF.testing)
end

local function createPanelButton(text, onClick)
	local button = CreateFrame("Button", nil, panel)
	button:SetSize(120, 20)
	button:SetBackdrop(ns.CreateBackdrop(8))
	button:SetBackdropColor(0, 0, 0, 0.5)
	button:SetBackdropBorderColor(0.6, 0.6, 0.6)
	button:SetHighlightTexture(ns.Media.blank)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	button:SetScript("OnClick", onClick)
	createLabel(button, 12, 0.8, text):SetPoint("CENTER")
	return button
end

local function createPanel()
	panel = CreateFrame("Frame", "FrostAtomUIMovers", UIParent)
	panel:SetPoint("TOP", 0, -60)
	panel:SetFrameStrata(OVERLAY_STRATA)
	panel:SetBackdrop(ns.CreateBackdrop(14, 3))
	panel:SetBackdropColor(0, 0, 0, 0.85)

	local hint = createLabel(panel, 11, 0.7, L["Drag to move and snap, Shift drops snapping"])
	hint:SetPoint("TOP", 0, -8)

	local nudgeHint = createLabel(panel, 11, 0.7, L["Click a frame to open its settings, arrow keys nudge it"])
	nudgeHint:SetPoint("TOP", hint, "BOTTOM", 0, -4)

	local check = CreateFrame("CheckButton", "FrostAtomUIMoversTestMode", panel, "UICheckButtonTemplate")
	check:SetSize(22, 22)
	check:SetScript("OnClick", onTestModeClick)
	local checkLabel = createLabel(check, 11, 0.85, L["Show test unit frames"])
	checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
	check:SetPoint("TOPLEFT", panel, "TOP", -(22 + 2 + checkLabel:GetStringWidth()) / 2, -44)
	panel.testCheck = check

	panel:SetSize(max(260, hint:GetStringWidth() + 24, nudgeHint:GetStringWidth() + 24), 102)

	local lock = createPanelButton(L["Lock frames"], Movers.Lock)
	lock:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -4, 8)

	local reset = createPanelButton(L["Reset positions"], Movers.ConfirmResetPositions)
	reset:SetPoint("BOTTOMLEFT", panel, "BOTTOM", 4, 8)
end

function Movers.Unlock()
	if unlocked then
		return
	end
	if InCombatLockdown() then
		ns.Print(L["cannot unlock frames in combat"])
		return
	end
	unlocked = true
	if not panel then
		createPanel()
	end
	local UF = unitFrames()
	if UF then
		panel.testCheck:SetChecked(UF.testing)
		panel.testCheck:Show()
	else
		panel.testCheck:Hide()
	end
	panel:Show()
	updateGrid()
	for _, mover in ipairs(movers) do
		if not mover.overlay then
			mover.overlay = createOverlay(mover)
		end
		updateVisibility(mover)
	end
end

function Movers.Lock()
	if not unlocked then
		return
	end
	selectMover(nil)
	closeSettings()
	unlocked = false
	panel:Hide()
	if testModeOwned and not InCombatLockdown() then
		unitFrames():SetTestMode(false)
	end
	testModeOwned = false
	if grid then
		grid:Hide()
	end
	for _, mover in ipairs(movers) do
		if mover.overlay then
			mover.overlay:Hide()
		end
	end
end

function Movers.Toggle()
	if unlocked then
		Movers.Lock()
	else
		Movers.Unlock()
	end
end

function Movers.IsUnlocked()
	return unlocked
end

Movers:RegisterEvent("PLAYER_REGEN_DISABLED", Movers.Lock)

Movers:RegisterEvent(ns.CONFIG_CHANGED, function(_, path)
	if not unlocked then
		return
	end
	if not path or path:find("^general%.") then
		updateGrid()
	end
	local toggled = not path or path:find("enabled$") ~= nil
	for _, mover in ipairs(movers) do
		if not path or path == mover.path then
			refresh(mover)
		end
		if toggled or path == mover.enabledPath then
			updateVisibility(mover)
		end
	end
end)
