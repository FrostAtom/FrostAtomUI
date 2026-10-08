local _, ns = ...
local L = ns.L

local InCombatLockdown = InCombatLockdown
local floor = math.floor
local sort = table.sort

local Movers = ns.Movers
local home = Movers.home
local POINT_PARTS = home.POINT_PARTS
local defaultPoint = home.defaultPoint
local defaultValue = home.defaultValue
local isStorable = home.isStorable
local movers = home.movers
local unpackPoint = home.unpackPoint
local wouldLoop = home.wouldLoop

local LAYOUT_PREFIX = "FAUIL1:"
local MAX_LAYOUT_NAME = 32

local PRESET_PREFIX, SAVED_PREFIX = "preset:", "saved:"

local function anchorDepth(path)
	local depth, point = 0, defaultPoint(path)
	while point and point[4] and depth <= #movers do
		depth = depth + 1
		point = defaultPoint(point[4])
	end
	return depth
end

local function sortByAnchorDepth(paths)
	local depths = {}
	for i = 1, #paths do
		depths[paths[i]] = anchorDepth(paths[i])
	end
	sort(paths, function(a, b)
		if depths[a] ~= depths[b] then
			return depths[a] < depths[b]
		end
		return a < b
	end)
	return paths
end

local function positionPaths()
	local paths = {}
	for i = 1, #movers do
		local path = movers[i].path
		if isStorable(path) then
			paths[#paths + 1] = path
		end
	end
	return sortByAnchorDepth(paths)
end

local function canMove()
	if InCombatLockdown() then
		ns.Print(L["cannot move frames in combat"])
		return false
	end
	return true
end

local layoutsSlot = ns.Storage.Claim("layouts", "Layout", "settings")
local trashSlot = ns.Storage.Claim("layoutTrash", "Layout", "state")
local baseSlot = ns.Storage.Claim("layoutBase", "Layout", "settings")

local function layoutStore()
	return layoutsSlot:Table()
end

local function isValidPoint(value)
	if type(value) ~= "table" or not POINT_PARTS[value[1]] then
		return false
	elseif type(value[2]) ~= "number" or type(value[3]) ~= "number" then
		return false
	end
	local anchorPath = value[4]
	if anchorPath == nil then
		return value[5] == nil or POINT_PARTS[value[5]] ~= nil
	end
	return type(anchorPath) == "string" and POINT_PARTS[value[5]] ~= nil and type(ns:GetConfig(anchorPath)) == "table"
end

local function sanitizeLayout(points)
	if type(points) ~= "table" then
		return nil
	end
	local result, count = {}, 0
	for path, value in pairs(points) do
		if type(path) == "string" and isStorable(path) and isValidPoint(value) then
			result[path] = {
				value[1],
				floor(value[2] + 0.5),
				floor(value[3] + 0.5),
				value[4],
				(value[4] or value[5] ~= value[1]) and value[5] or nil,
			}
			count = count + 1
		end
	end
	return count > 0 and result or nil
end

local layoutSettings = {}
for _, path in ipairs(ns.LayoutSettings) do
	layoutSettings[path] = true
end

local function sanitizeSettings(settings)
	if type(settings) ~= "table" then
		return nil
	end
	local result, count = {}, 0
	for path, value in pairs(settings) do
		local default = layoutSettings[path] and defaultValue(path)
		if default ~= nil and type(value) == type(default) and type(value) ~= "table" then
			result[path] = value
			count = count + 1
		end
	end
	return count > 0 and result or nil
end

local allPointPaths

local function collectPointPaths(node, prefix, paths)
	for key, value in pairs(node) do
		if type(key) == "string" and type(value) == "table" then
			local path = prefix and prefix .. "." .. key or key
			if POINT_PARTS[value[1]] then
				paths[#paths + 1] = path
			else
				collectPointPaths(value, path, paths)
			end
		end
	end
	return paths
end

local function pointPaths()
	if not allPointPaths then
		allPointPaths = sortByAnchorDepth(collectPointPaths(ns.Defaults, nil, {}))
	end
	return allPointPaths
end

local function samePoint(a, b)
	for i = 1, 5 do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function clearUnless(path, keep)
	if not keep and (not ns:IsDefaultConfig(path) or ns:GetBaselineConfig(path) ~= nil) then
		ns:SetBaselineConfig(path, nil)
	end
end

function home.start(path)
	local value = ns:GetDefaultConfig(path)
	return type(value) == "table" and value[1] ~= nil and value or nil
end

function home.move(path, point)
	local start = home.start(path)
	if point and not (start and samePoint(point, start)) then
		ns:SetConfig(path, point)
	else
		ns:ResetConfig(path)
	end
end

local function breakLoops(points)
	for path in pairs(points) do
		local point, x, y, anchorPath = unpackPoint(ns:GetConfig(path))
		if anchorPath and wouldLoop(path, anchorPath) then
			ns:SetConfig(path, { point, x, y })
		end
	end
end

local function applyLayout(points, settings, full)
	if full then
		local paths = pointPaths()
		for i = 1, #paths do
			clearUnless(paths[i], points[paths[i]])
		end
	end
	if settings or full then
		for i = 1, #ns.LayoutSettings do
			local path = ns.LayoutSettings[i]
			clearUnless(path, settings and settings[path] ~= nil)
		end
	end
	for path, value in pairs(settings or {}) do
		ns:SetBaselineConfig(path, value)
	end
	for path, value in pairs(points) do
		ns:SetBaselineConfig(path, value)
	end
	breakLoops(points)
end

local function matchesLayout(points, settings)
	local paths = pointPaths()
	for i = 1, #paths do
		local path = paths[i]
		local expected = points[path] or defaultPoint(path)
		if not samePoint(ns:GetConfig(path), expected) then
			return false
		end
	end
	for i = 1, #ns.LayoutSettings do
		local path = ns.LayoutSettings[i]
		local expected = settings and settings[path]
		if expected == nil then
			expected = defaultValue(path)
		end
		if ns:GetConfig(path) ~= expected then
			return false
		end
	end
	return true
end

local function presetByKey(key)
	for _, preset in ipairs(ns.LayoutPresets) do
		if preset.key == key then
			return preset
		end
	end
end

local function merged(base, overrides)
	local result = {}
	for key, value in pairs(base or {}) do
		result[key] = value
	end
	for key, value in pairs(overrides or {}) do
		result[key] = value
	end
	return result
end

local function compactLayout(preset)
	local compact = preset.compact
	if not compact then
		return nil
	end
	if not compact.merged then
		compact.merged = {
			points = merged(preset.points, compact.points),
			settings = merged(preset.settings, compact.settings),
		}
	end
	return compact.merged.points, compact.merged.settings
end

local function isCompactScreen(height)
	return (height or UIParent:GetHeight()) < ns.COMPACT_SCREEN_HEIGHT
end

local function presetLayout(preset, height)
	if isCompactScreen(height) and preset.compact then
		return compactLayout(preset)
	end
	return preset.points, preset.settings
end

local function presetMatches(preset)
	return matchesLayout(presetLayout(preset))
end

function Movers.GetPresets()
	return ns.LayoutPresets
end

function Movers.GetPresetLayout(key, screenHeight)
	local preset = presetByKey(key)
	if preset then
		return presetLayout(preset, screenHeight)
	end
end

function home.setBase(value)
	ns.Undo.TrackLayoutBase()
	local bases = baseSlot:Table()
	bases[ns:GetActiveProfile()] = value
end

function home.base()
	local bases = baseSlot:Get()
	local value = type(bases) == "table" and bases[ns:GetActiveProfile()]
	return type(value) == "string" and value or nil
end

function Movers.ApplyPreset(key)
	local preset = presetByKey(key)
	if not preset or not canMove() then
		return false
	end
	local points, settings = presetLayout(preset)
	ns.Undo.Snapshot("layout", L[preset.name])
	ns.Undo.Run(L['Apply the "%s" layout']:format(L[preset.name]), function()
		applyLayout(points, settings, true)
		home.setBase(PRESET_PREFIX .. key)
	end)
	return true
end

function Movers.GetActivePreset()
	for _, preset in ipairs(ns.LayoutPresets) do
		if presetMatches(preset) then
			return preset.key
		end
	end
end

local function cleanName(name)
	name = type(name) == "string" and name:trim() or ""
	if name == "" then
		return nil
	end
	return name:sub(1, MAX_LAYOUT_NAME)
end

function Movers.GetLayoutNames()
	local names = {}
	for name in pairs(layoutStore()) do
		names[#names + 1] = name
	end
	sort(names)
	return names
end

local function storedLayout(name)
	local layout = layoutStore()[name]
	if type(layout) ~= "table" then
		return nil
	elseif layout.points then
		return layout.points, layout.settings
	end
	return layout
end

function home.toTrash(name, replaced)
	local layout = layoutStore()[name]
	if type(layout) == "table" then
		trashSlot:Set({ name = name, layout = layout, time = time(), replaced = replaced or nil })
	end
end

function Movers.LayoutExists(name)
	name = cleanName(name)
	return name ~= nil and layoutStore()[name] ~= nil
end

function Movers.SaveLayout(name)
	name = cleanName(name)
	if not name then
		return false
	end
	local points, settings = {}, {}
	local paths = pointPaths()
	for i = 1, #paths do
		local value = ns:GetConfig(paths[i])
		points[paths[i]] = { value[1], value[2], value[3], value[4], value[5] }
	end
	for _, path in ipairs(ns.LayoutSettings) do
		settings[path] = ns:GetConfig(path)
	end
	home.toTrash(name, true)
	layoutStore()[name] = { points = points, settings = settings }
	return true, name
end

function Movers.GetLayoutTrash()
	local trash = trashSlot:Get()
	if type(trash) == "table" and type(trash.name) == "string" and type(trash.layout) == "table" then
		return trash.name, trash.time, trash.replaced
	end
end

function Movers.RestoreLayoutTrash()
	local name = Movers.GetLayoutTrash()
	if not name then
		return false
	end
	local store = layoutStore()
	local layout = trashSlot:Get().layout
	trashSlot:Set(nil)
	local free, suffix = name, 1
	while store[free] do
		suffix = suffix + 1
		free = ("%s %d"):format(name, suffix)
	end
	store[free] = layout
	return true, free
end

function Movers.LoadLayout(name)
	local stored, storedSettings = storedLayout(name)
	local points = sanitizeLayout(stored)
	if not points or not canMove() then
		return false
	end
	ns.Undo.Snapshot("layout", name)
	ns.Undo.Run(L['Apply the "%s" layout']:format(name), function()
		applyLayout(points, sanitizeSettings(storedSettings))
		home.setBase(SAVED_PREFIX .. name)
	end)
	return true
end

local function isLayoutActive(name)
	local stored, storedSettings = storedLayout(name)
	local points = sanitizeLayout(stored)
	if not points then
		return false
	end
	local settings = sanitizeSettings(storedSettings)
	for path, value in pairs(points) do
		if not samePoint(ns:GetConfig(path), value) then
			return false
		end
	end
	for path, value in pairs(settings or {}) do
		if ns:GetConfig(path) ~= value then
			return false
		end
	end
	return true
end

function Movers.DeleteLayout(name)
	local points, settings = storedLayout(name)
	local paths = {}
	for path in pairs(type(points) == "table" and points or {}) do
		paths[#paths + 1] = path
	end
	for path in pairs(type(settings) == "table" and settings or {}) do
		paths[#paths + 1] = path
	end
	home.toTrash(name)
	layoutStore()[name] = nil
	local bases = baseSlot:Get()
	if type(bases) ~= "table" then
		return
	end
	ns.Undo.Run(L['Delete the "%s" layout']:format(name), function()
		if bases[ns:GetActiveProfile()] == SAVED_PREFIX .. name then
			ns.Undo.TrackLayoutBase()
		end
		for profile, value in pairs(bases) do
			if value == SAVED_PREFIX .. name then
				bases[profile] = nil
				ns:KeepBaselineAsOwn(profile, paths)
			end
		end
	end)
end

function Movers.ExportLayout(name)
	local points, settings = storedLayout(name)
	if not points then
		return nil
	end
	return LAYOUT_PREFIX .. ns.Encode(ns.Serialize({ name = name, points = points, settings = settings }))
end

function Movers.ImportLayout(text)
	text = text and text:trim()
	if not text or text:sub(1, #LAYOUT_PREFIX) ~= LAYOUT_PREFIX then
		return false, L["not a FrostAtom UI layout string"]
	end
	local body, err = ns.Decode(text:sub(#LAYOUT_PREFIX + 1))
	if not body then
		return false, err
	end
	local data = ns.Deserialize(body)
	local points = type(data) == "table" and sanitizeLayout(data.points)
	if not points then
		return false, L["malformed layout string"]
	end
	local store = layoutStore()
	local base = cleanName(data.name) or L["Imported layout"]
	local name, suffix = base, 1
	while store[name] do
		suffix = suffix + 1
		name = ("%s %d"):format(base, suffix)
	end
	store[name] = { points = points, settings = sanitizeSettings(data.settings) }
	return true, name
end

home.PRESET_PREFIX = PRESET_PREFIX
home.SAVED_PREFIX = SAVED_PREFIX
home.breakLoops = breakLoops
home.canMove = canMove
home.isLayoutActive = isLayoutActive
home.layoutSettings = layoutSettings
home.positionPaths = positionPaths
home.presetByKey = presetByKey
home.presetLayout = presetLayout
home.samePoint = samePoint
home.sanitizeLayout = sanitizeLayout
home.sanitizeSettings = sanitizeSettings
home.storedLayout = storedLayout
