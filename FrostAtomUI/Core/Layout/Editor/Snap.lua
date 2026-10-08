local _, ns = ...
local L = ns.L

local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local floor = math.floor
local abs = math.abs
local max = math.max
local min = math.min

local Movers = ns.Movers
local home = Movers.home
local COLOR = home.COLOR
local PART_POINTS = home.PART_POINTS
local attach = home.attach
local cursorPosition = home.cursorPosition
local detach = home.detach
local draggedFrameRect = home.draggedFrameRect
local edge = home.edge
local frameRect = home.frameRect
local moverRect = home.moverRect
local movers = home.movers
local placeOnScreen = home.placeOnScreen
local showTooltip = home.showTooltip
local uiToFrameFactor = home.uiToFrameFactor
local unpackPoint = home.unpackPoint
local wouldLoop = home.wouldLoop

local ADJACENT_GAP = 24

local linesX, linesY, parts = {}, {}, {}

local function addLine(lines, low, size, owner)
	for part = 1, 3 do
		lines[#lines + 1] = { value = edge(low, size, part), part = part, mover = owner }
	end
end

local function addGridLines(lines, length)
	local size = ns.Config.general.gridSize
	local center = length / 2
	for offset = -floor(center / size) * size, center, size do
		if offset ~= 0 then
			lines[#lines + 1] = { value = center + offset, part = 2 }
		end
	end
end

local function collectSnapLines(mover)
	wipe(linesX)
	wipe(linesY)
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	addLine(linesX, 0, width, nil)
	addLine(linesY, 0, height, nil)
	if ns.Config.general.showGrid then
		addGridLines(linesX, width)
		addGridLines(linesY, height)
	end
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
		return ns.Config.general.snapGap
	elseif part == 3 and linePart == 1 then
		return -ns.Config.general.snapGap
	end
	return 0
end

local function snapOffset(lines, low, size)
	local best, bestDistance, bestLine, bestPart = 0, ns.Config.general.snapDistance, nil, nil
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
	local thickness = ns.PixelPerfect(2, snapLineFrame)
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
	line:SetVertexColor(unpack(attached and COLOR.ATTACH_LINE or COLOR.SNAP_LINE))
	line:Show()
end

local updateSnapLines

local dragFrame = CreateFrame("Frame")
dragFrame:Hide()

local function updateDrag()
	local mover = home.dragging
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
		local point, _, _, anchorPath, anchorPoint = unpackPoint(ns:GetConfig(mover.path))
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
	ns.Undo.Begin(L['Move "%s"']:format(L[mover.label]))
	detach(mover)
	local _, startX, startY = unpack(ns:GetConfig(mover.path))
	mover.startX, mover.startY = startX, startY
	mover.lastX, mover.lastY = startX, startY
	collectSnapLines(mover)
	home.dragging = mover
	dragFrame:Show()
end

local function onDragStop(overlay)
	local mover = overlay.mover
	if home.dragging ~= mover then
		return
	end
	updateDrag()
	home.dragging = nil
	dragFrame:Hide()
	hideSnapLines()
	applySnapAnchor(mover)
	if not ns:GetConfig(mover.path)[4] then
		placeOnScreen(mover)
	end
	mover.finalLeft, mover.finalBottom, mover.frameLeft, mover.frameBottom = nil, nil, nil, nil
	ns.Undo.End()
	attach(mover)
	home.updateConflicts()
	if overlay:IsMouseOver() then
		showTooltip(overlay)
	end
end

dragFrame:SetScript("OnUpdate", updateDrag)

home.onDragStart = onDragStart
home.onDragStop = onDragStop
