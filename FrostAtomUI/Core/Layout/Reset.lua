local _, ns = ...
local L = ns.L

local Movers = ns.Movers
local home = Movers.home
local POINT_PARTS = home.POINT_PARTS
local PRESET_PREFIX = home.PRESET_PREFIX
local SAVED_PREFIX = home.SAVED_PREFIX
local breakLoops = home.breakLoops
local byPath = home.byPath
local canMove = home.canMove
local defaultPoint = home.defaultPoint
local isListPath = home.isListPath
local layoutSettings = home.layoutSettings
local positionPaths = home.positionPaths
local presetByKey = home.presetByKey
local presetLayout = home.presetLayout
local samePoint = home.samePoint
local sanitizeLayout = home.sanitizeLayout
local sanitizeSettings = home.sanitizeSettings
local storedLayout = home.storedLayout

do
	local function baseLayout()
		local base = home.base()
		if base and base:sub(1, #PRESET_PREFIX) == PRESET_PREFIX then
			local preset = presetByKey(base:sub(#PRESET_PREFIX + 1))
			if preset then
				local points, settings = presetLayout(preset)
				return points, settings, L[preset.name]
			end
		elseif base and base:sub(1, #SAVED_PREFIX) == SAVED_PREFIX then
			local name = base:sub(#SAVED_PREFIX + 1)
			local stored, storedSettings = storedLayout(name)
			local points = sanitizeLayout(stored)
			if points then
				return points, sanitizeSettings(storedSettings), name
			end
		end
		local preset = presetByKey("default")
		return nil, nil, preset and L[preset.name] or "default"
	end

	function Movers.GetBaseLayoutName()
		local _, _, name = baseLayout()
		return name
	end

	local function basePoint(path)
		if isListPath(path) then
			return nil
		end
		local points = baseLayout()
		return points and points[path]
	end

	function Movers.GetBaseLayoutValue(path)
		local points, settings, name = baseLayout()
		local value = points and points[path]
		if value == nil and settings then
			value = settings[path]
		end
		return value, name
	end

	function Movers.ResetPosition(path)
		local mover = byPath[path]
		local point = mover and mover.defaultPoint or basePoint(path)
		if not point and not defaultPoint(path) then
			return
		end
		ns.Undo.Run(L['Move "%s" back']:format(Movers.GetLabel(path)), function()
			home.move(path, point)
			breakLoops({ [path] = true })
		end)
	end

	function Movers.IsAtHome(path)
		local value = ns:GetConfig(path)
		local mover = byPath[path]
		local target = mover and mover.defaultPoint or basePoint(path) or home.start(path)
		return type(value) ~= "table" or not target or samePoint(value, target)
	end

	function Movers.RestoreValue(path)
		local point = defaultPoint(path)
		if byPath[path] or point and POINT_PARTS[point[1]] then
			Movers.ResetPosition(path)
			return
		end
		local _, settings = baseLayout()
		local value = layoutSettings[path] and settings and settings[path]
		if value ~= nil and value ~= ns:GetDefaultConfig(path) then
			ns:SetConfig(path, value)
		else
			ns:ResetConfig(path)
		end
	end

	function Movers.ResetPositions()
		if not canMove() then
			return
		end
		local paths = positionPaths()
		local points = baseLayout()
		local changed = {}
		ns.Undo.Snapshot("positions")
		ns.Undo.Begin(L["Move all frames back"])
		for i = 1, #paths do
			local path = paths[i]
			home.move(path, points and points[path])
			changed[path] = true
		end
		breakLoops(changed)
		ns.Undo.End()
	end
end

function Movers.GetResetPositionsText()
	return L['Move all frames back to the "%s" layout? Sizes and other settings stay.']:format(
		Movers.GetBaseLayoutName()
	)
end

StaticPopupDialogs.FROSTATOMUI_RESET_POSITIONS = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		Movers.ResetPositions()
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

function Movers.ConfirmResetPositions()
	local dialog = StaticPopup_Show("FROSTATOMUI_RESET_POSITIONS", Movers.GetResetPositionsText())
	if dialog then
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	end
end
