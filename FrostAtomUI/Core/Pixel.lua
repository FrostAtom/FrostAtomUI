local _, ns = ...

local GetCVar, GetCursorPosition, GetScreenWidth, GetScreenHeight =
	GetCVar, GetCursorPosition, GetScreenWidth, GetScreenHeight
local InCombatLockdown = InCombatLockdown
local floor, abs, sqrt, tonumber = math.floor, math.abs, math.sqrt, tonumber

local Pixel = ns.Mixin({}, ns.EventMixin)
ns.Pixel = Pixel

local REFERENCE_HEIGHT = 768
local MIN_SIZE, MAX_SIZE = 200, 16384
local SAMPLES_NEEDED = 8
local TOLERANCE = 0.01
local EDGE = 0.001

local axisX, axisY = {}, {}
local alignedX, alignedY, alignedUnit

local function aspectRatio()
	return GetScreenWidth() / GetScreenHeight()
end

local function isFullscreen()
	return GetCVar("gxWindow") ~= "1"
end

local function useResolution()
	local width, height = (GetCVar("gxResolution") or ""):match("^(%d+)x(%d+)")
	width, height = tonumber(width) or 1024, tonumber(height) or REFERENCE_HEIGHT
	local changed = width ~= axisX.size or height ~= axisY.size
	axisX.size, axisY.size = width, height
	return changed
end

local function fits(value, size, span)
	local pixels = value * size / span
	return abs(pixels - floor(pixels + 0.5)) < TOLERANCE
end

local function restart(axis, value, span)
	local candidates = {}
	for size = MIN_SIZE, MAX_SIZE do
		if fits(value, size, span) then
			candidates[#candidates + 1] = size
		end
	end
	axis.candidates = candidates
	axis.samples = 1
end

local function feed(axis, value, span)
	if abs(value) < EDGE or abs(value - span) < EDGE then
		return
	end
	local candidates = axis.candidates
	if not candidates then
		if axis.calibrated and fits(value, axis.size, span) then
			return
		end
		restart(axis, value, span)
		return
	end
	local kept = 0
	for i = 1, #candidates do
		local size = candidates[i]
		candidates[i] = nil
		if fits(value, size, span) then
			kept = kept + 1
			candidates[kept] = size
		end
	end
	if kept == 0 then
		restart(axis, value, span)
		return
	end
	axis.samples = axis.samples + 1
	if axis.samples < SAMPLES_NEEDED then
		return
	end
	axis.candidates = nil
	axis.calibrated = true
	if candidates[1] ~= axis.size then
		axis.size = candidates[1]
		return true
	end
end

local lastX, lastY
-- 3.3.5 has no API for the windowed backbuffer size; GetCursorPosition is quantized to it
local sampler = CreateFrame("Frame")
sampler:SetScript("OnUpdate", function()
	local x, y = GetCursorPosition()
	local changed
	if y ~= lastY then
		lastY = y
		changed = feed(axisY, y, REFERENCE_HEIGHT)
	end
	if x ~= lastX then
		lastX = x
		changed = feed(axisX, x, REFERENCE_HEIGHT * aspectRatio()) or changed
	end
	if changed then
		ns:Fire(ns.E.PIXEL_CHANGED)
	end
end)

useResolution()
axisX.calibrated = isFullscreen()
axisY.calibrated = axisX.calibrated

Pixel:RegisterEvent("DISPLAY_SIZE_CHANGED", function()
	if not isFullscreen() then
		return
	end
	axisX.calibrated, axisY.calibrated = true, true
	axisX.candidates, axisY.candidates = nil, nil
	if useResolution() then
		ns:Fire(ns.E.PIXEL_CHANGED)
	end
end)

local function effectiveScale(region)
	region = region or UIParent
	if not region.GetEffectiveScale then
		region = region:GetParent()
	end
	return region:GetEffectiveScale()
end

function Pixel.Units(region)
	local scale = effectiveScale(region)
	return REFERENCE_HEIGHT * aspectRatio() / (axisX.size * scale), REFERENCE_HEIGHT / (axisY.size * scale)
end

function Pixel.GridOffset()
	-- D3D9: the client's broken half-pixel projection puts the UI off the pixel grid (smeared edges, text)
	if not (GetCVar("gxApi") or ""):upper():find("^D3D") then
		return 0, 0
	end
	local aspect = aspectRatio()
	local diagonal = sqrt(aspect * aspect + 1)
	return 0.5 + aspect / diagonal / 4, 0.5 - 1 / diagonal / 4
end

function Pixel.AlignUIParent()
	if InCombatLockdown() then
		return
	end
	local unitX, unitY = Pixel.Units(UIParent)
	local gridX, gridY = Pixel.GridOffset()
	local x, y = gridX * unitX, gridY * unitY
	if x == alignedX and y == alignedY and unitY == alignedUnit then
		return
	end
	alignedX, alignedY, alignedUnit = x, y, unitY
	UIParent:ClearAllPoints()
	UIParent:SetPoint("TOPLEFT", x, y)
	UIParent:SetPoint("BOTTOMRIGHT", x, y)
	return true
end

function ns.PixelPerfectScale()
	return REFERENCE_HEIGHT / axisY.size
end

function ns.PixelPerfect(pixels, region)
	return pixels * REFERENCE_HEIGHT / (axisY.size * effectiveScale(region))
end
