local _, ns = ...

local WorldFrame = WorldFrame
local GetCurrentResolution, GetScreenResolutions = GetCurrentResolution, GetScreenResolutions
local floor, tonumber = math.floor, tonumber

local WorldChildren = {}
ns.WorldChildren = WorldChildren

local pixel = 1

function WorldChildren.UpdatePixel()
	local resolution = select(GetCurrentResolution(), GetScreenResolutions())
	local height = resolution and tonumber(resolution:match("x(%d+)$"))
	pixel = height and WorldFrame:GetHeight() / height or 1
end

function WorldChildren.Pixel()
	return pixel
end

function WorldChildren.Snap(value)
	return floor(value / pixel + 0.5) * pixel
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

local function scan(frame, ...)
	if not frame then
		return
	end
	add(frame)
	return scan(...)
end

function WorldChildren.Scan()
	local count = WorldFrame:GetNumChildren()
	if count == known then
		return
	end
	if count > known then
		scan(select(known + 1, WorldFrame:GetChildren()))
	else
		scan(WorldFrame:GetChildren())
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
scanner:SetScript("OnUpdate", WorldChildren.Scan)
scanner:SetScript("OnEvent", WorldChildren.UpdatePixel)
scanner:RegisterEvent("PLAYER_LOGIN")
scanner:RegisterEvent("DISPLAY_SIZE_CHANGED")
WorldChildren.UpdatePixel()
