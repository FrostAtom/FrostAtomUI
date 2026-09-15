local ADDON_NAME, ns = ...

local tremove = table.remove
local floor = math.floor
local modf = math.modf

--------------------------------------------------
-- Tables

function ns.tContains(tbl, item)
	for i = 1, #tbl do
		if tbl[i] == item then
			return i
		end
	end
end

function ns.tDeleteItem(tbl, item)
	local index = ns.tContains(tbl, item)
	if index then
		return tremove(tbl, index)
	end
end

--------------------------------------------------
-- Frames

function ns.noop() end

-- Permanently hides a Blizzard frame: it stops receiving events and re-hides
-- itself whenever something tries to show it. With `deep` the same is done to
-- every child frame.
function ns.DestroyFrame(frame, deep)
	if not frame then
		return
	end

	frame:Hide()
	frame:SetScript("OnShow", frame.Hide)
	frame:UnregisterAllEvents()

	if deep then
		for _, child in ipairs({ frame:GetChildren() }) do
			ns.DestroyFrame(child)
		end
	end
end

-- Scales a size so that it maps to whole screen pixels at the current UI scale.
function ns.PixelPerfect(size)
	return size * (2 - UIParent:GetEffectiveScale())
end

--------------------------------------------------
-- Formatting

local PRINT_PREFIX = "|cff177cbf[" .. ADDON_NAME .. "]|r: "

function ns.Print(format, ...)
	print(PRINT_PREFIX .. format:format(...))
end

-- 1234 -> "1.2k", 1234567 -> "1.2m"
function ns.FormatValue(value)
	if value < 1e3 then
		return value
	elseif value < 1e6 then
		return ("%.1fk"):format(value / 1e3)
	else
		return ("%.1fm"):format(value / 1e6)
	end
end

-- Interpolates between an arbitrary number of r,g,b triplets.
-- ns.ColorGradient(0.5, 1,0,0, 0,1,0) -> 0.5, 0.5, 0
function ns.ColorGradient(percent, ...)
	if percent ~= percent then -- NaN
		percent = 0
	end

	local numColors = select("#", ...) / 3
	if percent >= 1 then
		return select(numColors * 3 - 2, ...)
	elseif percent <= 0 then
		return ...
	end

	local segment, relativePercent = modf(percent * (numColors - 1))
	local r1, g1, b1, r2, g2, b2 = select(segment * 3 + 1, ...)

	return r1 + (r2 - r1) * relativePercent, g1 + (g2 - g1) * relativePercent, b1 + (b2 - b1) * relativePercent
end

-- Places the i-th (1-based) item of a grid, `perRow` items per row, `size` units apart.
-- Returns arguments for SetPoint: point, xOffset, yOffset.
function ns.GridPoint(point, i, perRow, size)
	i = i - 1
	local column, row = i % perRow, floor(i / perRow)

	local xSign = point:find("RIGHT") and -1 or 1
	local ySign = point:find("BOTTOM") and 1 or -1
	return point, xSign * column * size, ySign * row * size
end
