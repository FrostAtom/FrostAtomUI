local _, ns = ...
local L = ns.L

local GameTooltip = GameTooltip
local max = math.max
local min = math.min
local tconcat = table.concat

local Movers = ns.Movers
local home = Movers.home
local COLOR = home.COLOR
local attach = home.attach
local moverRect = home.moverRect
local rectOf = home.rectOf
local movers = home.movers
local updateColors = home.updateColors

local OVERLAP_TOLERANCE = 4
local MAX_STATUS_LINES = 12

local conflictPairs, offScreenMovers = {}, {}

local function showStatusTooltip(status)
	GameTooltip:SetOwner(status, "ANCHOR_BOTTOM")
	if #conflictPairs == 0 and #offScreenMovers == 0 then
		GameTooltip:SetText(L["No frames overlap"], unpack(COLOR.STATUS_OK))
		GameTooltip:AddLine(L["Turn on test unit frames to check party and arena frames too."], 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
		return
	end
	GameTooltip:SetText(L["Frames to fix"], 1, 1, 1)
	local lines = 0
	for _, pair in ipairs(conflictPairs) do
		if lines < MAX_STATUS_LINES then
			GameTooltip:AddLine(("%s - %s"):format(L[pair[1].label], L[pair[2].label]), 1, 0.6, 0.55)
		end
		lines = lines + 1
	end
	for _, mover in ipairs(offScreenMovers) do
		if lines < MAX_STATUS_LINES then
			GameTooltip:AddLine(L["%s: partly off screen"]:format(L[mover.label]), 1, 0.6, 0.55)
		end
		lines = lines + 1
	end
	if lines > MAX_STATUS_LINES then
		GameTooltip:AddLine(L["and %d more"]:format(lines - MAX_STATUS_LINES), 0.6, 0.6, 0.6)
	end
	GameTooltip:AddLine(
		L["Such frames are outlined in red. A smaller UI scale or a layout preset leaves more room."],
		0.8,
		0.8,
		0.8,
		true
	)
	GameTooltip:Show()
end

local function conflictRect(mover)
	if mover.floating or not mover.overlay or not mover.overlay:IsShown() then
		return nil
	elseif mover.frame and not mover.frame:IsVisible() then
		return nil
	end
	local left, bottom, width, height = moverRect(mover)
	if not left or width <= 0 or height <= 0 then
		return nil
	end
	return { left, bottom, left + width, bottom + height, mover = mover }
end

local function partRects(mover, union, rects)
	local parts = mover.parts and mover.parts()
	local left, bottom, width, height = rectOf(mover.frame)
	if not parts or not left then
		rects[#rects + 1] = union
		return
	end
	local scale = mover.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	for i = 1, #parts do
		local insetLeft, insetRight, insetTop, insetBottom = unpack(parts[i])
		rects[#rects + 1] = {
			left - insetLeft * scale,
			bottom - insetBottom * scale,
			left + width + insetRight * scale,
			bottom + height + insetTop * scale,
			mover = mover,
		}
	end
end

local function overlaps(a, b)
	if a.mover == b.mover then
		return false
	end
	local contextA, contextB = a.mover.context, b.mover.context
	if contextA and contextB and contextA ~= contextB then
		return false
	end
	return min(a[3], b[3]) - max(a[1], b[1]) > OVERLAP_TOLERANCE
		and min(a[4], b[4]) - max(a[2], b[2]) > OVERLAP_TOLERANCE
end

local function addConflict(mover, other)
	mover.conflicts = mover.conflicts or {}
	mover.conflicts[#mover.conflicts + 1] = other
end

local function updateStatus()
	local status = home.panel and home.panel.status
	if not status then
		return
	end
	if #conflictPairs == 0 and #offScreenMovers == 0 then
		status.text:SetText(L["No frames overlap"])
		status.text:SetTextColor(unpack(COLOR.STATUS_OK))
		ns.SetGlyph(status.icon, "circle-check")
		status.icon:SetTextColor(unpack(COLOR.STATUS_OK))
	else
		local parts = {}
		if #conflictPairs > 0 then
			parts[#parts + 1] = L["Overlapping frames: %d"]:format(#conflictPairs)
		end
		if #offScreenMovers > 0 then
			parts[#parts + 1] = L["Off screen: %d"]:format(#offScreenMovers)
		end
		status.text:SetText(tconcat(parts, ", "))
		status.text:SetTextColor(unpack(COLOR.STATUS_WARN))
		ns.SetGlyph(status.icon, "triangle-exclamation")
		status.icon:SetTextColor(unpack(COLOR.STATUS_WARN))
	end
	status:SetWidth(status.text:GetStringWidth() + status.icon:GetStringWidth() + 5)
end

local function updateConflicts()
	wipe(conflictPairs)
	wipe(offScreenMovers)
	local rects = {}
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	for _, mover in ipairs(movers) do
		mover.conflicts, mover.offScreen = nil, nil
		local rect = conflictRect(mover)
		if rect then
			partRects(mover, rect, rects)
			if rect[1] < -1 or rect[2] < -1 or rect[3] > screenWidth + 1 or rect[4] > screenHeight + 1 then
				mover.offScreen = true
				offScreenMovers[#offScreenMovers + 1] = mover
			end
		end
	end
	local paired = {}
	for i = 1, #rects do
		for j = i + 1, #rects do
			local a, b = rects[i], rects[j]
			if overlaps(a, b) then
				local seen = paired[a.mover]
				if not seen then
					seen = {}
					paired[a.mover] = seen
				end
				if not seen[b.mover] then
					seen[b.mover] = true
					addConflict(a.mover, b.mover)
					addConflict(b.mover, a.mover)
					conflictPairs[#conflictPairs + 1] = { a.mover, b.mover }
				end
			end
		end
	end
	for _, mover in ipairs(movers) do
		if mover.overlay and mover.overlay:IsShown() then
			updateColors(mover, mover.overlay:IsMouseOver())
		end
	end
	updateStatus()
end

function Movers.Refresh()
	if not home.unlocked or home.dragging or home.resizing then
		return
	end
	for _, mover in ipairs(movers) do
		if mover.overlay and mover.overlay:IsShown() then
			attach(mover)
		end
	end
	updateConflicts()
end

home.showStatusTooltip = showStatusTooltip
home.updateConflicts = updateConflicts
