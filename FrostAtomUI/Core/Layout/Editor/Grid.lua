local _, ns = ...

local floor = math.floor

local Movers = ns.Movers
local home = Movers.home
local COLOR = home.COLOR

local grid

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
	line:ClearAllPoints()
	if vertical then
		line:SetWidth(ns.PixelPerfect(1, grid))
		line:SetPoint("TOPLEFT", grid, "TOP", offset, 0)
		line:SetPoint("BOTTOMLEFT", grid, "BOTTOM", offset, 0)
	else
		line:SetHeight(ns.PixelPerfect(1, grid))
		line:SetPoint("BOTTOMLEFT", grid, "LEFT", 0, offset)
		line:SetPoint("BOTTOMRIGHT", grid, "RIGHT", 0, offset)
	end
end

local function toggleGrid()
	ns:SetConfig("general.showGrid", not ns.Config.general.showGrid)
end

local function paintGridButton()
	local button = home.panel and home.panel.gridButton
	if button then
		button.color = ns.Config.general.showGrid and COLOR.GRID_BUTTON_ON or COLOR.GRID_BUTTON_OFF
		button:Paint()
	end
end

local function updateGrid()
	if not home.unlocked then
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
			drawGridLine(index, COLOR.GRID, true, offset)
		end
		for offset = -floor(centerY / size) * size, centerY, size do
			index = index + 1
			drawGridLine(index, COLOR.GRID, false, offset)
		end
	end

	drawGridLine(index + 1, COLOR.GRID_CENTER, true, 0)
	drawGridLine(index + 2, COLOR.GRID_CENTER, false, 0)
	index = index + 2

	for i = index + 1, #grid.lines do
		grid.lines[i]:Hide()
	end
	grid:Show()
	paintGridButton()
end

function home.hideGrid()
	if grid then
		grid:Hide()
	end
end

home.toggleGrid = toggleGrid
home.updateGrid = updateGrid
