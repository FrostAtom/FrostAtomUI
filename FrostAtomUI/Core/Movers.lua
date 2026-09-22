local _, ns = ...

local GameTooltip = GameTooltip
local InCombatLockdown, GetCursorPosition, IsShiftKeyDown = InCombatLockdown, GetCursorPosition, IsShiftKeyDown
local floor, abs = math.floor, math.abs
local tconcat = table.concat

local BACKDROP_COLOR = { 0.2, 0.6, 1, 0.35 }
local BORDER_COLOR = { 0.5, 0.8, 1 }
local HOVER_COLOR = { 0.3, 0.8, 1, 0.5 }
local MIN_SIZE = 20
local SNAP_DISTANCE = 8

local Movers = ns:NewModule("Movers")
ns.Movers = Movers

local movers = {}
local byFrame = {}
local unlocked = false
local panel

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

local function resolve(value)
	if type(value) == "function" then
		return value()
	end
	return value
end

local function fallbackSize(mover)
	local size = mover.size
	if type(size) == "function" then
		return size()
	elseif size then
		return size[1], size[2]
	end
	return MIN_SIZE, MIN_SIZE
end

local function relative(mover)
	local point = ns:GetConfig(mover.path)[1]
	return resolve(mover.relativeTo) or UIParent, mover.relativePoint or point
end

local function attach(mover)
	local overlay = mover.overlay
	overlay:ClearAllPoints()
	local frame = mover.frame
	if frame and frame:GetLeft() then
		if frame:GetWidth() < MIN_SIZE or frame:GetHeight() < MIN_SIZE then
			local point = ns:GetConfig(mover.path)[1]
			overlay:SetSize(fallbackSize(mover))
			overlay:SetPoint(point, frame, point)
		elseif mover.extendTo then
			overlay:SetPoint("TOPLEFT", frame)
			overlay:SetPoint("BOTTOMRIGHT", mover.extendTo)
		else
			overlay:SetAllPoints(frame)
		end
		return
	end
	local point, x, y = unpack(ns:GetConfig(mover.path))
	local relativeTo, relativePoint = relative(mover)
	overlay:SetSize(fallbackSize(mover))
	overlay:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function showTooltip(overlay)
	local mover = overlay.mover
	local point, x, y = unpack(ns:GetConfig(mover.path))
	GameTooltip:SetOwner(overlay, "ANCHOR_TOP")
	GameTooltip:SetText(mover.label, 1, 1, 1)
	GameTooltip:AddLine(("%s  %d, %d"):format(point, x, y), 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Drag to move, right-click to reset, hold Shift to disable snapping", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local snapX, snapY, edges = {}, {}, {}

local function collectSnapLines(mover)
	wipe(snapX)
	wipe(snapY)
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	snapX[1], snapX[2], snapX[3] = 0, width / 2, width
	snapY[1], snapY[2], snapY[3] = 0, height / 2, height
	for _, other in ipairs(movers) do
		local overlay = other.overlay
		if other ~= mover and overlay and overlay:IsShown() and overlay:GetLeft() then
			local left, right = overlay:GetLeft(), overlay:GetRight()
			local bottom, top = overlay:GetBottom(), overlay:GetTop()
			snapX[#snapX + 1] = left
			snapX[#snapX + 1] = right
			snapX[#snapX + 1] = (left + right) / 2
			snapY[#snapY + 1] = bottom
			snapY[#snapY + 1] = top
			snapY[#snapY + 1] = (bottom + top) / 2
		end
	end
end

local function snapOffset(lines, low, size)
	local best = 0
	local bestDistance = SNAP_DISTANCE
	edges[1], edges[2], edges[3] = low, low + size / 2, low + size
	for i = 1, #lines do
		local line = lines[i]
		for j = 1, 3 do
			local distance = line - edges[j]
			if abs(distance) < bestDistance then
				best, bestDistance = distance, abs(distance)
			end
		end
	end
	return best
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

	if not IsShiftKeyDown() then
		dx = dx + snapOffset(snapX, mover.left + dx, mover.width)
		dy = dy + snapOffset(snapY, mover.bottom + dy, mover.height)
	end

	local factor = uiScale / (mover.frame or overlay):GetEffectiveScale()
	local x = floor(mover.startX + dx * factor + 0.5)
	local y = floor(mover.startY + dy * factor + 0.5)
	if x ~= mover.lastX or y ~= mover.lastY then
		mover.lastX, mover.lastY = x, y
		ns:SetConfig(mover.path, { mover.point, x, y })
		showTooltip(overlay)
	end
end

dragFrame:SetScript("OnUpdate", updateDrag)

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
	mover.left, mover.bottom = overlay:GetLeft(), overlay:GetBottom()
	mover.width, mover.height = overlay:GetWidth(), overlay:GetHeight()
	mover.point, mover.startX, mover.startY = unpack(ns:GetConfig(mover.path))
	mover.lastX, mover.lastY = mover.startX, mover.startY
	collectSnapLines(mover)
	dragging = mover
	dragFrame:Show()
end

local function onDragStop(overlay)
	if dragging ~= overlay.mover then
		return
	end
	updateDrag()
	dragging = nil
	dragFrame:Hide()
	if overlay:IsMouseOver() then
		showTooltip(overlay)
	end
end

local function onClick(overlay, button)
	if button == "RightButton" then
		ns:ResetConfig(overlay.mover.path)
		showTooltip(overlay)
	end
end

local function onEnter(overlay)
	overlay:SetBackdropColor(unpack(HOVER_COLOR))
	showTooltip(overlay)
end

local function onLeave(overlay)
	overlay:SetBackdropColor(unpack(BACKDROP_COLOR))
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
	overlay:SetBackdropBorderColor(unpack(BORDER_COLOR))
	overlay:SetScript("OnMouseDown", onMouseDown)
	overlay:SetScript("OnDragStart", onDragStart)
	overlay:SetScript("OnDragStop", onDragStop)
	overlay:SetScript("OnClick", onClick)
	overlay:SetScript("OnEnter", onEnter)
	overlay:SetScript("OnLeave", onLeave)

	local text = overlay:CreateFontString(nil, "OVERLAY")
	ns.SetFont(text, 11, "OUTLINE", true)
	text:SetPoint("CENTER")
	text:SetText(mover.label)
	overlay.text = text
	return overlay
end

function Movers.Register(frame, path, label, options)
	options = options or {}
	local mover = frame and byFrame[frame]
	if not mover then
		mover = {}
		movers[#movers + 1] = mover
		if frame then
			byFrame[frame] = mover
		end
	end
	mover.frame = frame
	mover.path = path
	mover.label = label or mover.label or humanize(path)
	for key, value in pairs(options) do
		mover[key] = value
	end
	if mover.overlay then
		mover.overlay.text:SetText(mover.label)
		if unlocked then
			attach(mover)
		end
	elseif unlocked then
		mover.overlay = createOverlay(mover)
		attach(mover)
		mover.overlay:Show()
	end
	return mover
end

function Movers.Unregister(frame)
	local mover = byFrame[frame]
	if not mover then
		return
	end
	byFrame[frame] = nil
	ns.tDeleteItem(movers, mover)
	if mover.overlay then
		mover.overlay:Hide()
	end
end

function ns.ModulePrototype:RegisterMover(frame, path, label, options)
	return Movers.Register(frame, path, label, options)
end

local function createPanel()
	panel = CreateFrame("Frame", "FrostAtomUIMovers", UIParent)
	panel:SetSize(220, 52)
	panel:SetPoint("TOP", 0, -60)
	panel:SetFrameStrata("TOOLTIP")
	panel:SetBackdrop(ns.CreateBackdrop(14, 3))
	panel:SetBackdropColor(0, 0, 0, 0.85)

	local hint = panel:CreateFontString(nil, "OVERLAY")
	ns.SetFont(hint, 11)
	hint:SetTextColor(0.7, 0.7, 0.7)
	hint:SetPoint("TOP", 0, -8)
	hint:SetText("Drag frames, right-click to reset")

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
	text:SetText("Lock frames")
end

function Movers.Unlock()
	if unlocked then
		return
	end
	if InCombatLockdown() then
		ns.Print("cannot unlock frames in combat")
		return
	end
	unlocked = true
	if not panel then
		createPanel()
	end
	panel:Show()
	for _, mover in ipairs(movers) do
		if not mover.overlay then
			mover.overlay = createOverlay(mover)
		end
		attach(mover)
		mover.overlay:Show()
	end
end

function Movers.Lock()
	if not unlocked then
		return
	end
	unlocked = false
	panel:Hide()
	for _, mover in ipairs(movers) do
		mover.overlay:Hide()
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
	for _, mover in ipairs(movers) do
		if not path or path == mover.path then
			attach(mover)
		end
	end
end)
