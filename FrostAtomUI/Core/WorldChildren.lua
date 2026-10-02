local _, ns = ...

local WorldFrame = WorldFrame
local floor = math.floor

local WorldChildren = {}
ns.WorldChildren = WorldChildren

local pixelX, pixelY = 1, 1
local gridX, gridY = 0, 0

function WorldChildren.UpdatePixel()
	pixelX, pixelY = ns.Pixel.Units(WorldFrame)
	gridX, gridY = ns.Pixel.GridOffset()
end

function WorldChildren.Pixel()
	return pixelY
end

function WorldChildren.Snap(value)
	return floor(value / pixelY + 0.5) * pixelY
end

function WorldChildren.SnapX(value)
	return (floor(value / pixelX - gridX + 0.5) + gridX) * pixelX
end

function WorldChildren.SnapY(value)
	return (floor(value / pixelY - gridY + 0.5) + gridY) * pixelY
end

local KIND_BY_TEXTURE = {
	["Interface\\TargetingFrame\\UI-TargetingFrame-Flash"] = "NamePlate",
	["Interface\\Tooltips\\ChatBubble-Background"] = "ChatBubble",
}

local seen = {}
local frames = {}
local handlers = {}
local known = 0

local function identify(frame)
	if frame:GetName() or not frame.GetRegions then
		return
	end
	local region = frame:GetRegions()
	return region and region.GetTexture and KIND_BY_TEXTURE[region:GetTexture()]
end

local function dispatch(handler, frame)
	local ok, err = pcall(handler, frame)
	if not ok then
		geterrorhandler()(err)
	end
end

local function add(frame)
	if seen[frame] then
		return
	end
	seen[frame] = true
	local kind = identify(frame)
	if not kind then
		return
	end
	local list = frames[kind]
	if not list then
		list = {}
		frames[kind] = list
	end
	list[#list + 1] = frame
	local callbacks = handlers[kind]
	if callbacks then
		for i = 1, #callbacks do
			dispatch(callbacks[i], frame)
		end
	end
end

local function addAll(frame, ...)
	if not frame then
		return
	end
	add(frame)
	return addAll(...)
end

local function scanNewChildren()
	local count = WorldFrame:GetNumChildren()
	if count == known then
		return
	end
	if count > known then
		addAll(select(known + 1, WorldFrame:GetChildren()))
	else
		addAll(WorldFrame:GetChildren())
	end
	known = count
end

function WorldChildren.Register(kind, handler)
	local callbacks = handlers[kind]
	if not callbacks then
		callbacks = {}
		handlers[kind] = callbacks
	end
	callbacks[#callbacks + 1] = handler
	local list = frames[kind]
	if list then
		for i = 1, #list do
			dispatch(handler, list[i])
		end
	end
end

local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", scanNewChildren)

local pixelWatcher = ns.Mixin({}, ns.EventMixin)
pixelWatcher:RegisterEvent("PLAYER_LOGIN", WorldChildren.UpdatePixel)
pixelWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED", WorldChildren.UpdatePixel)
pixelWatcher:RegisterEvent(ns.PIXEL_CHANGED, WorldChildren.UpdatePixel)
WorldChildren.UpdatePixel()
