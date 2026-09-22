local _, ns = ...
local L = ns.L

local GameTooltip = GameTooltip
local InCombatLockdown, GetCursorPosition, IsShiftKeyDown = InCombatLockdown, GetCursorPosition, IsShiftKeyDown
local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local tconcat = table.concat

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
local MIN_WIDTH, MIN_HEIGHT = 96, 26
local GRIP_SIZE = 12
local SNAP_DISTANCE = 10
local SNAP_GAP = 4
local ADJACENT_GAP = 24

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

function Movers.GetFrame(path)
	local mover = byPath[path]
	return mover and mover.frame
end

function Movers.GetLabel(path)
	local mover = byPath[path]
	return mover and L[mover.label] or path and humanize(path)
end

local function anchorParent(path)
	local anchorPath = ns:GetConfig(path)[4]
	if not anchorPath then
		return nil
	end
	return Movers.GetFrame(anchorPath), anchorPath
end

function ns.ApplyPoint(frame, path, offset)
	local point, x, y, anchorPath, anchorPoint = unpack(ns:GetConfig(path))
	local parent = anchorPath and Movers.GetFrame(anchorPath)
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

-- geometry in UIParent units

local function scaleOf(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
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
		local point, x, y, anchorPath, anchorPoint = unpack(ns:GetConfig(mover.path))
		local parent = anchorPath and Movers.GetFrame(anchorPath)
		local fallbackWidth, fallbackHeight = fallbackSize(mover)
		overlay:SetSize(max(fallbackWidth, 1), max(fallbackHeight, 1))
		overlay:SetPoint(point, parent or UIParent, parent and anchorPoint or point, x, y)
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
	GameTooltip:AddLine(L["Drag to move, right-click to reset, hold Shift to drop snapping"], 0.6, 0.6, 0.6)
	if mover.resize then
		GameTooltip:AddLine(L["Drag the bottom-right corner to resize"], 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

-- snapping

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

local dragging
local dragFrame = CreateFrame("Frame")
dragFrame:Hide()

local function updateDrag()
	local mover = dragging
	local overlay = mover.overlay
	local uiScale = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	local dx = cursorX / uiScale - mover.cursorX
	local dy = cursorY / uiScale - mover.cursorY

	mover.snapX, mover.snapY = nil, nil
	if not IsShiftKeyDown() then
		local offsetX, lineX, partX = snapOffset(linesX, mover.left + dx, mover.width)
		local offsetY, lineY, partY = snapOffset(linesY, mover.bottom + dy, mover.height)
		dx, dy = dx + offsetX, dy + offsetY
		if lineX and lineX.mover then
			mover.snapX = { line = lineX, part = partX, distance = abs(offsetX) }
		end
		if lineY and lineY.mover then
			mover.snapY = { line = lineY, part = partY, distance = abs(offsetY) }
		end
	end

	local factor = uiScale / (mover.frame or overlay):GetEffectiveScale()
	local x = floor(mover.startX + dx * factor + 0.5)
	local y = floor(mover.startY + dy * factor + 0.5)
	mover.finalLeft = mover.left + (x - mover.startX) / factor
	mover.finalBottom = mover.bottom + (y - mover.startY) / factor
	if x ~= mover.lastX or y ~= mover.lastY then
		mover.lastX, mover.lastY = x, y
		local point, _, _, anchorPath, anchorPoint = unpack(ns:GetConfig(mover.path))
		ns:SetConfig(mover.path, { point, x, y, anchorPath, anchorPoint })
		showTooltip(overlay)
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
	local factor = UIParent:GetEffectiveScale() / (mover.frame or mover.overlay):GetEffectiveScale()
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
	local factor = UIParent:GetEffectiveScale() / (mover.frame or mover.overlay):GetEffectiveScale()
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

local function applySnapAnchor(mover)
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

	anchorTo(
		mover,
		target,
		snapX and snapX.part or 2,
		snapY and snapY.part or 2,
		snapX and snapX.line.part or 2,
		snapY and snapY.line.part or 2
	)
end

local function onMouseDown(overlay)
	local uiScale = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	overlay.mover.cursorX, overlay.mover.cursorY = cursorX / uiScale, cursorY / uiScale
end

local function onDragStart(overlay)
	local mover = overlay.mover
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
	mover.point, mover.startX, mover.startY = unpack(ns:GetConfig(mover.path))
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
	applySnapAnchor(mover)
	mover.finalLeft, mover.finalBottom, mover.frameLeft, mover.frameBottom = nil, nil, nil, nil
	attach(mover)
	if overlay:IsMouseOver() then
		showTooltip(overlay)
	end
end

dragFrame:SetScript("OnUpdate", updateDrag)

-- resizing

local resizing
local resizeFrame = CreateFrame("Frame")
resizeFrame:Hide()

local function updateResize()
	local mover = resizing
	local resize = mover.resize
	local uiScale = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	local width = mover.startWidth + cursorX / uiScale - mover.cursorX
	local height = mover.startHeight - (cursorY / uiScale - mover.cursorY)

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
	local uiScale = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	mover.cursorX, mover.cursorY = cursorX / uiScale, cursorY / uiScale
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

-- overlays

local function onClick(overlay, button)
	if button == "RightButton" then
		ns:ResetConfig(overlay.mover.path)
		attach(overlay.mover)
		showTooltip(overlay)
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
	overlay:SetBackdropBorderColor(unpack(anchored and ANCHORED_BORDER_COLOR or BORDER_COLOR))
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
	overlay:SetFrameStrata("TOOLTIP")
	overlay:SetMovable(true)
	overlay:SetClampedToScreen(true)
	overlay:EnableMouse(true)
	overlay:RegisterForDrag("LeftButton")
	overlay:RegisterForClicks("RightButtonUp")
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
		end
	elseif unlocked then
		mover.overlay = createOverlay(mover)
		refresh(mover)
		mover.overlay:Show()
	end
	notifyDependents(path)
	return mover
end

function Movers.Unregister(frame)
	local mover = byFrame[frame]
	if not mover then
		return
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

function ns.ModulePrototype:RegisterMover(frame, path, label, options)
	return Movers.Register(frame, path, label, options)
end

-- alignment grid

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
			local line = gridLine(index)
			line:SetTexture(unpack(GRID_COLOR))
			line:SetWidth(1)
			line:SetPoint("TOP", grid, "TOP", offset, 0)
			line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
		end
		for offset = -floor(centerY / size) * size, centerY, size do
			index = index + 1
			local line = gridLine(index)
			line:SetTexture(unpack(GRID_COLOR))
			line:SetHeight(1)
			line:SetPoint("LEFT", grid, "LEFT", 0, offset)
			line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
		end
	end

	index = index + 1
	local vertical = gridLine(index)
	vertical:SetTexture(unpack(GRID_CENTER_COLOR))
	vertical:SetWidth(1)
	vertical:SetPoint("TOP")
	vertical:SetPoint("BOTTOM")

	index = index + 1
	local horizontal = gridLine(index)
	horizontal:SetTexture(unpack(GRID_CENTER_COLOR))
	horizontal:SetHeight(1)
	horizontal:SetPoint("LEFT")
	horizontal:SetPoint("RIGHT")

	for i = index + 1, #grid.lines do
		grid.lines[i]:Hide()
	end
	grid:Show()
end

-- panel

local function createPanel()
	panel = CreateFrame("Frame", "FrostAtomUIMovers", UIParent)
	panel:SetSize(260, 52)
	panel:SetPoint("TOP", 0, -60)
	panel:SetFrameStrata("TOOLTIP")
	panel:SetBackdrop(ns.CreateBackdrop(14, 3))
	panel:SetBackdropColor(0, 0, 0, 0.85)

	local hint = panel:CreateFontString(nil, "OVERLAY")
	ns.SetFont(hint, 11)
	hint:SetTextColor(0.7, 0.7, 0.7)
	hint:SetPoint("TOP", 0, -8)
	hint:SetText(L["Drag to move and snap, Shift drops snapping"])

	local lock = CreateFrame("Button", nil, panel)
	lock:SetSize(120, 20)
	lock:SetPoint("BOTTOM", 0, 8)
	lock:SetBackdrop(ns.CreateBackdrop(8))
	lock:SetBackdropColor(0, 0, 0, 0.5)
	lock:SetBackdropBorderColor(0.6, 0.6, 0.6)
	lock:SetHighlightTexture(ns.Media.blank)
	lock:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	lock:SetScript("OnClick", Movers.Lock)

	local text = lock:CreateFontString(nil, "OVERLAY")
	ns.SetFont(text, 12)
	text:SetTextColor(0.8, 0.8, 0.8)
	text:SetPoint("CENTER")
	text:SetText(L["Lock frames"])
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
	panel:Show()
	updateGrid()
	for _, mover in ipairs(movers) do
		if not mover.overlay then
			mover.overlay = createOverlay(mover)
		end
		refresh(mover)
		mover.overlay:Show()
	end
end

function Movers.Lock()
	if not unlocked then
		return
	end
	unlocked = false
	panel:Hide()
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

function Movers.Iterate()
	return ipairs(movers)
end

Movers:RegisterEvent("PLAYER_REGEN_DISABLED", Movers.Lock)

Movers:RegisterEvent(ns.CONFIG_CHANGED, function(_, path)
	if not unlocked then
		return
	end
	if not path or path:find("^general%.") then
		updateGrid()
	end
	for _, mover in ipairs(movers) do
		if not path or path == mover.path then
			refresh(mover)
		end
	end
end)
