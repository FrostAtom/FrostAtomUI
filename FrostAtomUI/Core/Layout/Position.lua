local _, ns = ...
local L = ns.L

local InCombatLockdown = InCombatLockdown
local floor = math.floor
local abs = math.abs
local tconcat = table.concat
local sort = table.sort

local MIN_WIDTH, MIN_HEIGHT = 96, 26

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
ns.POINT_PARTS = POINT_PARTS

local home = {}
Movers.home = home
home.unlocked = false

local movers = {}
local byFrame = {}
local byPath = {}

local sizeHooked = {}
local refreshKey = {}

local function runRefresh()
	Movers.Refresh()
end

local function deferRefresh()
	ns.Defer(refreshKey, runRefresh)
end

local function queueRefresh()
	if home.unlocked then
		ns.Defer(refreshKey, deferRefresh)
	end
end

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

local function defaultValue(path)
	local node = ns.Defaults
	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[tonumber(key) or key]
	end
	return node
end

local function defaultPoint(path)
	local node = defaultValue(path)
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

local function enabledPaths(mover)
	local paths = mover.enabledPath
	if type(paths) == "string" then
		return { paths }
	end
	return paths or {}
end

local function watchesPath(mover, path)
	local paths = enabledPaths(mover)
	for i = 1, #paths do
		if paths[i] == path then
			return true
		end
	end
	return false
end

local function isActive(mover)
	if not isEnabledAlong(mover.path) then
		return false
	end
	local paths = enabledPaths(mover)
	for i = 1, #paths do
		if ns:GetConfig(paths[i]) == false then
			return false
		end
	end
	return not mover.visible or mover.visible() and true or false
end

function Movers.GetLabel(path)
	local mover = byPath[path]
	return mover and L[mover.label] or path and humanize(path)
end

function Movers.HasMover(path)
	return byPath[path] ~= nil
end

local function unpackPoint(value)
	return value[1], value[2], value[3], value[4], value[5]
end
ns.UnpackPoint = unpackPoint

function ns.ApplyPoint(frame, path, offset)
	local point, x, y, anchorPath, anchorPoint = unpackPoint(ns:GetConfig(path))
	local parent = anchorPath and registeredFrame(anchorPath)
	frame:ClearAllPoints()
	frame:SetPoint(point, parent or UIParent, (parent or not anchorPath) and anchorPoint or point, x, y - (offset or 0))
end

local function notifyDependents(path)
	for i = 1, #movers do
		local other = movers[i]
		local value = other.path ~= path and ns:GetConfig(other.path)
		if value and value[4] == path then
			ns:Fire(ns.E.POSITION_INVALIDATED, other.path)
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
		local value = ns:GetConfig(anchorPath)
		if type(value) ~= "table" then
			return false
		end
		anchorPath = value[4]
	end
	return false
end

local function scaleOf(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function uiToFrameFactor(mover)
	return UIParent:GetEffectiveScale() / (mover.frame or mover.overlay):GetEffectiveScale()
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

local function screenPart(low, size, total)
	local center = low + size / 2
	if center < total / 3 then
		return 1
	elseif center > total * 2 / 3 then
		return 3
	end
	return 2
end

local function placeOnScreen(mover)
	local point, offsetX, offsetY = unpackPoint(ns:GetConfig(mover.path))
	local left, bottom, width, height = draggedFrameRect(mover)
	if not left then
		ns:SetConfig(mover.path, { point, offsetX, offsetY })
		return
	end
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local xPart, yPart = unpack(POINT_PARTS[point] or POINT_PARTS.CENTER)
	local screenX, screenY = screenPart(left, width, screenWidth), screenPart(bottom, height, screenHeight)
	local relative = PART_POINTS[screenY][screenX]
	local factor = uiToFrameFactor(mover)
	local x = (edge(left, width, xPart) - edge(0, screenWidth, screenX)) * factor
	local y = (edge(bottom, height, yPart) - edge(0, screenHeight, screenY)) * factor
	ns:SetConfig(mover.path, { point, floor(x + 0.5), floor(y + 0.5), nil, relative ~= point and relative or nil })
end

local function detach(mover)
	if ns:GetConfig(mover.path)[4] then
		placeOnScreen(mover)
	end
end

function Movers.SetScale(frame, scale, keepPosition)
	local old = frame:GetScale()
	local mover = byFrame[frame]
	if not keepPosition or not mover or abs(old - scale) < 0.0001 or ns.Undo.IsRestoring() then
		frame:SetScale(scale)
		return
	end
	local point, x, y, anchorPath, anchorPoint = unpackPoint(ns:GetConfig(mover.path))
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
	local moved = not mover or mover.frame ~= frame or mover.path ~= path
	if not mover then
		mover = {}
		movers[#movers + 1] = mover
	end
	if frame then
		byFrame[frame] = mover
		if not (InCombatLockdown() and frame:IsProtected()) then
			frame:SetClampedToScreen(true)
		end
		if not sizeHooked[frame] then
			sizeHooked[frame] = true
			frame:HookScript("OnSizeChanged", queueRefresh)
		end
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
		if home.unlocked then
			home.refresh(mover)
			home.updateVisibility(mover)
		end
	elseif home.unlocked then
		mover.overlay = home.createOverlay(mover)
		home.updateVisibility(mover)
	end
	if not moved then
		return mover
	end
	local value = ns:GetConfig(path)
	if type(value) == "table" and value[4] and registeredFrame(value[4]) then
		ns:Fire(ns.E.POSITION_INVALIDATED, path)
	end
	notifyDependents(path)
	return mover
end

function Movers.Unregister(frame)
	local mover = byFrame[frame]
	if not mover then
		return
	end
	if mover == home.selected then
		home.selectMover(nil)
	end
	byFrame[frame] = nil
	byPath[mover.path] = nil
	ns.tDeleteItem(movers, mover)
	if mover.overlay then
		mover.overlay:Hide()
	end
	local dependents = {}
	for i = 1, #movers do
		local value = ns:GetConfig(movers[i].path)
		if type(value) == "table" and value[4] == mover.path then
			dependents[#dependents + 1] = movers[i]
		end
	end
	for i = 1, #dependents do
		placeOnScreen(dependents[i])
	end
end

function Movers.GetFrameSize(path)
	local mover = byPath[path]
	local frame = mover and mover.frame
	if not frame then
		return nil
	end
	local scale = scaleOf(frame)
	return frame:GetWidth() * scale, frame:GetHeight() * scale, scale
end

function Movers.Detach(path)
	local mover = byPath[path]
	if mover then
		detach(mover)
	end
end

local ATTACH_TARGETS = 15

function Movers.AttachTargets(path)
	local mover = byPath[path]
	if not mover then
		return {}
	end
	local left, bottom, width, height = frameRect(mover)
	if not left then
		return {}
	end
	local cx, cy = left + width / 2, bottom + height / 2
	local list = {}
	for i = 1, #movers do
		local other = movers[i]
		if other ~= mover and other.frame and other.frame:IsVisible() and not wouldLoop(path, other.path) then
			local oLeft, oBottom, oWidth, oHeight = frameRect(other)
			if oLeft then
				local dx, dy = oLeft + oWidth / 2 - cx, oBottom + oHeight / 2 - cy
				list[#list + 1] = { path = other.path, label = L[other.label], distance = dx * dx + dy * dy }
			end
		end
	end
	sort(list, function(a, b)
		return a.distance < b.distance
	end)
	for i = #list, ATTACH_TARGETS + 1, -1 do
		list[i] = nil
	end
	return list
end

function Movers.AttachTo(path, targetPath)
	local mover, target = byPath[path], byPath[targetPath]
	if not mover or not target or mover == target or wouldLoop(path, targetPath) then
		return false
	end
	local left, bottom, width, height = frameRect(mover)
	local targetLeft, targetBottom, targetWidth, targetHeight = frameRect(target)
	if not left or not targetLeft then
		return false
	end
	local point = unpackPoint(ns:GetConfig(path))
	local xPart, yPart = unpack(POINT_PARTS[point] or POINT_PARTS.CENTER)
	local factor = uiToFrameFactor(mover)
	local x = (edge(left, width, xPart) - edge(targetLeft, targetWidth, xPart)) * factor
	local y = (edge(bottom, height, yPart) - edge(targetBottom, targetHeight, yPart)) * factor
	ns:SetConfig(path, { point, floor(x + 0.5), floor(y + 0.5), targetPath, point })
	return true
end

function Movers.SavePosition(path)
	local mover = byPath[path]
	if mover then
		placeOnScreen(mover)
	end
end

function Movers.ChangePoint(path, point)
	local value = ns:GetConfig(path)
	local old = type(value) == "table" and value[1]
	if not old or not POINT_PARTS[point] or point == old then
		return
	end
	local _, x, y, anchorPath, anchorPoint = unpackPoint(value)
	local mover = byPath[path]
	local width, height
	if mover and mover.size then
		width, height = fallbackSize(mover)
	elseif mover and mover.frame then
		width, height = mover.frame:GetWidth(), mover.frame:GetHeight()
	end
	if width and POINT_PARTS[old] and (not anchorPath or registeredFrame(anchorPath)) then
		local oldX, oldY = unpack(POINT_PARTS[old])
		local newX, newY = unpack(POINT_PARTS[point])
		x = floor(x + (newX - oldX) * width / 2 + 0.5)
		y = floor(y + (newY - oldY) * height / 2 + 0.5)
		if not anchorPath then
			anchorPoint = anchorPoint or old
		end
	end
	if not anchorPath and anchorPoint == point then
		anchorPoint = nil
	end
	ns:SetConfig(path, { point, x, y, anchorPath, anchorPoint })
end

function ns.ModulePrototype:RegisterMover(frame, path, label, options)
	return Movers.Register(frame, path, label, options)
end

function ns.ModulePrototype:AnchorToConfig(frame, path, label, options)
	local function apply()
		ns.ApplyPoint(frame, path)
	end
	apply()
	self:WatchConfig(path, apply, options and options.secure)
	Movers.Register(frame, path, label, options)
end

ns.Undo.RegisterDescriber(function(key)
	if Movers.HasMover(key) then
		return L['Move "%s"']:format(Movers.GetLabel(key))
	end
end)

home.MIN_HEIGHT = MIN_HEIGHT
home.MIN_WIDTH = MIN_WIDTH
home.PART_POINTS = PART_POINTS
home.POINT_PARTS = POINT_PARTS
home.byPath = byPath
home.defaultPoint = defaultPoint
home.defaultValue = defaultValue
home.detach = detach
home.draggedFrameRect = draggedFrameRect
home.edge = edge
home.fallbackSize = fallbackSize
home.frameRect = frameRect
home.isActive = isActive
home.isListPath = isListPath
home.isStorable = isStorable
home.moverRect = moverRect
home.movers = movers
home.placeOnScreen = placeOnScreen
home.queueRefresh = queueRefresh
home.rectOf = rectOf
home.uiToFrameFactor = uiToFrameFactor
home.unpackPoint = unpackPoint
home.watchesPath = watchesPath
home.wouldLoop = wouldLoop
