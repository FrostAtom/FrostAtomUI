local ADDON_NAME, ns = ...

local RegisterUnitWatch, UnregisterUnitWatch = RegisterUnitWatch, UnregisterUnitWatch
local UnitHasVehicleUI, UnitIsConnected, UnitIsUnit = UnitHasVehicleUI, UnitIsConnected, UnitIsUnit
local UnitFrame_OnEnter = UnitFrame_OnEnter
local UnitFrame_OnLeave = UnitFrame_OnLeave
local max, floor, ceil = math.max, math.floor, math.ceil

local UF = ns:NewModule("UnitFrames")
UF.configKey = "unitFrames"

local FRAME_NAME = ADDON_NAME .. "%sUnitFrame"
local BORDER_INSET = ns.UIKit.BORDER_INSET
local CLASS_ICON_INSET = BORDER_INSET
local CLASS_ICON_GAP = 2
local CASTBAR_GAP = 4
local CASTBAR_ICON_GAP = 2
local CASTBAR_SPARK_SCALE = 2
local BAR_BACKGROUND_DIM = 0.3
local RIGHT_CLICK_ACTIONS = { menu = "menu", focus = "focus" }
local config = ns.Config.unitFrames

UF.BORDER_INSET = BORDER_INSET
UF.CLASS_ICON_INSET = CLASS_ICON_INSET
UF.CASTBAR_ICON_GAP = CASTBAR_ICON_GAP
UF.CASTBAR_GAP = CASTBAR_GAP
UF.BAR_BACKGROUND_DIM = BAR_BACKGROUND_DIM
UF.backdrop = ns.UIKit.backdrop

UF.classColors = ns.Colors.class
UF.classBarColors = ns.Colors.classBar
UF.classList = ns.Colors.classList
UF.powerColors = ns.Colors.power
UF.debuffColors = ns.Colors.debuff

UF.textColor = ns.Config.theme.textColor
UF.frames = {}

UF:OnInitialize(function()
	ns.FrameBridge.SetReady()
end)

local elements = {}
local elementOrder = {}
UF.elements = elements
UF.elementOrder = elementOrder

function UF:RegisterElement(spec, create, update, test, poll)
	if type(spec) ~= "table" then
		spec = { name = spec, Create = create, Update = update, Test = test, Poll = poll }
	end
	local name = spec.name
	assert(type(name) == "string", "unit frame element needs a name")
	assert(
		type(spec.Create) == "function" and type(spec.Update) == "function",
		("element [%s] needs Create and Update"):format(name)
	)
	local element = { name = name, create = spec.Create, update = spec.Update, test = spec.Test, poll = spec.Poll }
	local previous = elements[name]
	if previous then
		for i = 1, #elementOrder do
			if elementOrder[i] == previous then
				elementOrder[i] = element
			end
		end
	else
		elementOrder[#elementOrder + 1] = element
	end
	elements[name] = element
end

function UF:AddElement(frame, name, ...)
	local element = assert(elements[name], ("unknown unit frame element [%s]"):format(tostring(name)))
	assert(not frame[name], ("element [%s] already added to %s"):format(name, frame.unit))

	frame.addingElement = name
	local widget = element.create(frame, ...)
	frame.addingElement = nil
	frame[name] = widget
	return widget
end

UF.SkinIcon = ns.UIKit.SkinIcon

function UF.StyleText(text, key)
	local size = key and config[key .. "TextSize"] or 0
	ns.SetFont(text, size > 0 and size or config.textFont.size, config.textFont.outline)
	text:SetTextColor(unpack(UF.textColor))
end

function UF.CreateText(parent, key)
	local text = parent:CreateFontString(nil, "OVERLAY")
	UF.StyleText(text, key)
	return text
end

UF.SetBackdropColors = ns.UIKit.SetBackdropColors

function UF.SetBorder(frame)
	frame:SetBackdrop(UF.backdrop)
	UF.SetBackdropColors(frame)
end

function UF.SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.bg:SetVertexColor(r * BAR_BACKGROUND_DIM, g * BAR_BACKGROUND_DIM, b * BAR_BACKGROUND_DIM)
end

function UF.SetCastbarHeight(castbar, height)
	castbar:SetHeight(height)
	castbar.icon:SetSize(height, height)
	castbar.spark:SetHeight(height * CASTBAR_SPARK_SCALE)
end

function UF.SetCastbarSize(castbar, width, height)
	castbar:SetWidth(width)
	UF.SetCastbarHeight(castbar, height)
end

local function classIconSize(frameHeight)
	return frameHeight - CLASS_ICON_INSET * 2
end

local function isArenaUnit(unit)
	return unit:find("^arena%d$") ~= nil
end

local function fitRow(width, size, gap)
	local perRow = max(floor((width + gap) / (size + gap)), 1)
	return perRow, (width + gap) / perRow - gap
end

local function layoutGrid(grid, shown)
	for i = shown + 1, #grid do
		grid[i]:Hide()
	end

	local rows = max(ceil(shown / grid.perRow), grid.minRows)
	grid:SetHeight(max(rows * (grid.size + grid.gap) - grid.gap, 1))
	if grid.rows ~= rows then
		grid.rows = rows
		if grid.OnRowsChanged then
			grid:OnRowsChanged(rows)
		end
	end
end

local function setGridIconSize(grid, size)
	if grid.size == size then
		return
	end
	grid.size = size
	grid:SetWidth(grid.perRow * (size + grid.gap) - grid.gap)

	local shown = 0
	for i = 1, #grid do
		local icon = grid[i]
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint(UF.GridIconPoint(grid, i))
		if icon.OnResize then
			icon:OnResize(size)
		end
		if icon:IsShown() then
			shown = i
		end
	end
	layoutGrid(grid, shown)
end

local function setGridShape(grid, perRow, anchor)
	if grid.perRow == perRow and grid.anchor == anchor then
		return
	end
	grid.perRow = perRow
	grid.anchor = anchor
	local size = grid.size
	grid.size = nil
	setGridIconSize(grid, size)
end

local function setGridLayout(grid, width, size)
	local perRow, fittedSize = fitRow(width, size, grid.gap)
	grid.perRow = perRow
	grid.size = nil
	setGridIconSize(grid, fittedSize)
end

function UF:CreateIconGrid(frame, options)
	options = options or {}

	local grid = CreateFrame("Frame", nil, frame)
	grid:SetFrameLevel(frame:GetFrameLevel())
	grid.size = options.size or 22
	grid.gap = options.gap or 1
	grid.perRow = options.perRow or 8
	if options.width then
		grid.perRow, grid.size = fitRow(options.width, grid.size, grid.gap)
	end
	grid.anchor = options.anchor or "TOPLEFT"
	grid.max = options.max
	grid.minRows = options.minRows or 0
	grid.Layout = layoutGrid
	grid.SetIconSize = setGridIconSize
	grid.SetLayout = setGridLayout
	grid.SetShape = setGridShape
	grid.rows = 0
	grid:SetSize(grid.perRow * (grid.size + grid.gap) - grid.gap, 1)

	return grid
end

function UF.StackAuraGrids(frame, point, gap, order)
	local first, second = frame.debuffs, frame.buffs
	if second and order == "buffs" then
		first, second = second, first
	end
	local relative = point:gsub("^TOP", "BOTTOM")
	first:ClearAllPoints()
	first:SetPoint(point, frame, relative, 0, -gap)
	if not second then
		return
	end
	second.OnRowsChanged = nil
	first.OnRowsChanged = function(grid, rows)
		second:ClearAllPoints()
		if rows > 0 then
			second:SetPoint(point, grid, relative, 0, -gap)
		else
			second:SetPoint(point, frame, relative, 0, -gap)
		end
	end
	first:OnRowsChanged(first.rows)
end

local function auraGridAnchor(position, growth)
	return (position == "TOP" and "BOTTOM" or "TOP") .. (growth == "LEFT" and "RIGHT" or "LEFT")
end

local function auraAttachPoints(position, anchor, gap)
	if position == "LEFT" then
		return "TOPRIGHT", "TOPLEFT", -gap, 0
	elseif position == "RIGHT" then
		return "TOPLEFT", "TOPRIGHT", gap, 0
	elseif position == "TOP" then
		return anchor, (anchor:gsub("^BOTTOM", "TOP")), 0, gap
	end
	return anchor, (anchor:gsub("^TOP", "BOTTOM")), 0, -gap
end

local function auraStackPoints(position, anchor, gap)
	if position == "LEFT" then
		return "TOPRIGHT", "BOTTOMRIGHT", 0, -gap
	elseif position == "RIGHT" then
		return "TOPLEFT", "BOTTOMLEFT", 0, -gap
	end
	return auraAttachPoints(position, anchor, gap)
end

local function attachAuraGrid(grid, relativeTo, point, relative, x, y)
	grid:ClearAllPoints()
	grid:SetPoint(point, relativeTo, relative, x, y)
end

function UF.PlaceAuraGrids(frame, keys, gap)
	local debuffs, buffs = frame.debuffs, frame.buffs
	local debuffPosition, buffPosition = config[keys.debuffPosition], config[keys.buffPosition]
	debuffs.position, buffs.position = debuffPosition, buffPosition
	debuffs:SetShape(debuffs.perRow, auraGridAnchor(debuffPosition, config[keys.debuffGrowth]))
	buffs:SetShape(buffs.perRow, auraGridAnchor(buffPosition, config[keys.buffGrowth]))
	debuffs.OnRowsChanged, buffs.OnRowsChanged = nil, nil
	if debuffPosition ~= buffPosition then
		attachAuraGrid(debuffs, frame, auraAttachPoints(debuffPosition, debuffs.anchor, gap))
		attachAuraGrid(buffs, frame, auraAttachPoints(buffPosition, buffs.anchor, gap))
		return
	end
	local first, second = debuffs, buffs
	if config[keys.auraOrder] == "buffs" then
		first, second = buffs, debuffs
	end
	attachAuraGrid(first, frame, auraAttachPoints(debuffPosition, first.anchor, gap))
	first.OnRowsChanged = function(grid, rows)
		if rows > 0 then
			attachAuraGrid(second, grid, auraStackPoints(debuffPosition, second.anchor, gap))
		else
			attachAuraGrid(second, frame, auraAttachPoints(debuffPosition, second.anchor, gap))
		end
	end
	first:OnRowsChanged(first.rows)
end

function UF.GridIconPoint(grid, index)
	return ns.GridPoint(grid.anchor, index, grid.perRow, grid.size + grid.gap)
end

local UnitFrameMixin = {}
UF.FrameMixin = UnitFrameMixin

local function vehicleDisplayUnit(frame)
	local owner = frame.vehicleOwner
	if UnitHasVehicleUI(owner) and (owner == "player" or UnitIsConnected(owner)) then
		return frame.vehicleUnit
	end
	return frame.baseUnit
end

function UnitFrameMixin:UpdateAll()
	if UF.testing or not self:IsShown() then
		return
	end

	if self.vehicleOwner then
		self:SetDisplayUnit(vehicleDisplayUnit(self))
	end

	for i = 1, #elementOrder do
		local element = elementOrder[i]
		if self[element.name] then
			element.update(self)
		end
	end
end

function UnitFrameMixin:QueueUpdate()
	ns.Defer(self, self.UpdateAll)
end

local function wrapperCache(wrap)
	return setmetatable({}, {
		__index = function(self, handler)
			local wrapper = wrap(handler)
			self[handler] = wrapper
			return wrapper
		end,
	})
end

local eventWrappers = wrapperCache(function(handler)
	return function(frame, ...)
		if frame.watched and not UF.testing then
			handler(frame, ...)
		end
	end
end)

local unitEventWrappers = wrapperCache(function(handler)
	return function(frame, _, ...)
		if frame.watched and not UF.testing then
			handler(frame, ...)
		end
	end
end)

local RegisterEvent = ns.EventMixin.RegisterEvent
local RegisterUnitEvent = ns.EventMixin.RegisterUnitEvent
local UnregisterUnitEvent = ns.EventMixin.UnregisterUnitEvent

function UnitFrameMixin:RegisterEvent(event, handler)
	if type(handler) == "function" then
		handler = eventWrappers[handler]
	end
	RegisterEvent(self, event, handler)
end

function UnitFrameMixin:RegisterUnitEvent(event, handler)
	local wrapper = unitEventWrappers[handler]
	local unitEvents = self.unitEvents
	unitEvents[#unitEvents + 1] = { event = event, handler = wrapper, element = self.addingElement }
	RegisterUnitEvent(self, event, self.unit, wrapper)
end

local function retarget(widget, from, to)
	if type(widget) ~= "table" then
		return
	end
	if widget.unit == from then
		widget.unit = to
	end
	if widget.targetUnit == from .. "target" then
		widget.targetUnit = to .. "target"
	end
	for i = 1, #widget do
		local child = widget[i]
		if type(child) == "table" and child.unit == from then
			child.unit = to
		end
	end
end

function UnitFrameMixin:SetDisplayUnit(unit)
	local from = self.unit
	if from == unit then
		return
	end
	local fixed = self.fixedUnit
	local unitEvents = self.unitEvents
	for i = 1, #unitEvents do
		local entry = unitEvents[i]
		if not (fixed and fixed[entry.element]) then
			UnregisterUnitEvent(self, entry.event, from, entry.handler)
			RegisterUnitEvent(self, entry.event, unit, entry.handler)
		end
	end
	for i = 1, #elementOrder do
		local name = elementOrder[i].name
		if not (fixed and fixed[name]) then
			retarget(self[name], from, unit)
		end
	end
	self.unit = unit
end

local function queueUpdate(frame)
	frame:QueueUpdate()
end

function UnitFrameMixin:EnableVehicleSwap(owner, vehicleUnit, fixed)
	self.vehicleOwner = owner
	self.vehicleUnit = vehicleUnit
	self.fixedUnit = fixed
	self:SetAttribute("toggleForVehicle", true)
	RegisterUnitEvent(self, "UNIT_ENTERED_VEHICLE", owner, queueUpdate)
	RegisterUnitEvent(self, "UNIT_EXITED_VEHICLE", owner, queueUpdate)
end

local function capitalize(text)
	return (text:gsub("^%l", string.upper))
end

local categoryKeys = {}

function UF.CategoryKeys(key)
	local keys = categoryKeys[key]
	if keys then
		return keys
	end
	local name = capitalize(key)
	keys = {
		width = key .. "Width",
		height = key .. "Height",
		iconSide = key .. "IconSide",
		castbar = "show" .. name .. "Castbar",
		castbarWidth = key .. "CastbarWidth",
		castbarHeight = key .. "CastbarHeight",
		debuffs = "show" .. name .. "Debuffs",
		buffs = "show" .. name .. "Buffs",
		auraSize = key .. "AuraSize",
		auraPerRow = key .. "AuraPerRow",
		auraRows = key .. "AuraRows",
		auraGrowth = key .. "AuraGrowth",
		auraOrder = key .. "AuraOrder",
		auraSpacing = key .. "AuraSpacing",
		debuffSize = key .. "DebuffSize",
		debuffMax = key .. "DebuffMax",
		debuffPosition = key .. "DebuffPosition",
		debuffGrowth = key .. "DebuffGrowth",
		buffSize = key .. "BuffSize",
		buffMax = key .. "BuffMax",
		buffPosition = key .. "BuffPosition",
		buffGrowth = key .. "BuffGrowth",
		power = key .. "Power",
	}
	categoryKeys[key] = keys
	return keys
end

local POLL_INTERVAL = 0.2
local polledFrames = {}
local poller = CreateFrame("Frame")
poller:Hide()
poller.elapsed = 0

poller:SetScript("OnUpdate", function(self, elapsed)
	local total = self.elapsed + elapsed
	if total < POLL_INTERVAL then
		self.elapsed = total
		return
	end
	self.elapsed = 0
	if UF.testing then
		return
	end
	for i = 1, #polledFrames do
		local frame = polledFrames[i]
		if frame.watched and frame:IsShown() then
			local polls = frame.polls
			for j = 1, #polls do
				polls[j](frame)
			end
		end
	end
end)

function UF.EnablePolling(frame)
	local polls = {}
	for i = 1, #elementOrder do
		local element = elementOrder[i]
		if frame[element.name] and element.poll then
			polls[#polls + 1] = element.poll
		end
	end
	frame.polls = polls
	polledFrames[#polledFrames + 1] = frame
end

function UF.SetPollingActive(active)
	ns.SetShown(poller, active)
end

local function setHovered(frame, hovered)
	frame.hovered = hovered
	ns.SetShown(frame.hover, hovered and config.hoverAlpha > 0)
	if frame.test or frame:IsShown() then
		UF.UpdateTexts(frame)
	end
end

local function onEnter(frame)
	setHovered(frame, true)
	UnitFrame_OnEnter(frame)
end

local function onLeave(frame)
	setHovered(frame, false)
	UnitFrame_OnLeave(frame)
end

local function setMiddleClick(frame, action)
	if action == "focus" and frame.unit == "focus" then
		frame:SetAttribute("*type3", "macro")
		frame:SetAttribute("macrotext", "/clearfocus")
	else
		frame:SetAttribute("*type3", action)
	end
end

function UF:CreateBase(unit, parent)
	local frame =
		CreateFrame("Button", FRAME_NAME:format(capitalize(unit)), parent or UIParent, "SecureUnitButtonTemplate")
	ns.Mixin(frame, ns.EventMixin, UnitFrameMixin)
	frame.unit = unit
	frame.baseUnit = unit
	frame.unitEvents = {}

	frame:RegisterForClicks("AnyDown")
	UF.SetBorder(frame)
	UF.frames[#UF.frames + 1] = frame

	frame:SetAttribute("unit", unit)
	frame:SetAttribute("*type1", "target")
	if isArenaUnit(unit) then
		frame:SetAttribute("*type2", "focus")
	else
		frame:SetAttribute("*type2", RIGHT_CLICK_ACTIONS[config.rightClick])
		setMiddleClick(frame, RIGHT_CLICK_ACTIONS[config.middleClick])
	end

	local hover = CreateFrame("Frame", nil, frame)
	hover:SetFrameLevel(frame:GetFrameLevel() + 2)
	hover:SetPoint("TOPLEFT", BORDER_INSET, -BORDER_INSET)
	hover:SetPoint("BOTTOMRIGHT", -BORDER_INSET, BORDER_INSET)
	hover.texture = hover:CreateTexture(nil, "OVERLAY")
	hover.texture:SetAllPoints()
	hover.texture:SetTexture(ns.Media.blank)
	hover.texture:SetBlendMode("ADD")
	hover.texture:SetVertexColor(1, 1, 1, config.hoverAlpha)
	hover:Hide()
	frame.hover = hover

	frame:SetScript("OnEnter", onEnter)
	frame:SetScript("OnLeave", onLeave)
	frame:SetScript("OnShow", frame.UpdateAll)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", "QueueUpdate")
	RegisterUnitWatch(frame)
	frame.watched = true

	return frame
end

function UnitFrameMixin:SetWatched(watched)
	if self.watched == watched then
		return
	end
	self.watched = watched
	if UF.testing then
		UF.StartTest(self)
	elseif watched then
		RegisterUnitWatch(self)
	else
		UnregisterUnitWatch(self)
		self:Hide()
	end
end

local CASTBAR_TEXTS = { "timer", "name", "target" }

function UF:ApplyColors()
	for i = 1, #self.frames do
		local frame = self.frames[i]
		UF.SetBackdropColors(frame)
		if frame.health.text then
			UF.StyleText(frame.health.text)
		end
		if frame.name then
			UF.StyleText(frame.name)
		end
		local texts = frame.texts
		if texts then
			for j = 1, #texts do
				UF.StyleText(texts[j], frame.textKey)
			end
		end
		local castbar = frame.castbar
		if castbar then
			UF.SetBackdropColors(castbar)
			for j = 1, #CASTBAR_TEXTS do
				ns.SetFont(castbar[CASTBAR_TEXTS[j]], config.castbarFont.size, config.castbarFont.outline)
			end
		end
		frame.hover.texture:SetVertexColor(1, 1, 1, config.hoverAlpha)
		if self.testing then
			self:RunTest(frame)
		else
			frame:UpdateAll()
		end
	end
end

local ARENA_CLICKS = { shift = "arenaShiftClick", ctrl = "arenaCtrlClick", alt = "arenaAltClick" }

local function setArenaClick(frame, modifier, text)
	text = strtrim(text or "")
	local prefix = modifier .. "-"
	if text == "" then
		frame:SetAttribute(prefix .. "type1", nil)
		frame:SetAttribute(prefix .. "spell1", nil)
		frame:SetAttribute(prefix .. "macrotext1", nil)
	elseif text:sub(1, 1) == "/" then
		frame:SetAttribute(prefix .. "type1", "macro")
		frame:SetAttribute(prefix .. "spell1", nil)
		frame:SetAttribute(prefix .. "macrotext1", (text:gsub("%%u", frame.unit)))
	else
		frame:SetAttribute(prefix .. "type1", "spell")
		frame:SetAttribute(prefix .. "spell1", text)
		frame:SetAttribute(prefix .. "macrotext1", nil)
	end
end

function UF:ApplyClicks()
	local rightAction = RIGHT_CLICK_ACTIONS[config.rightClick]
	local middleAction = RIGHT_CLICK_ACTIONS[config.middleClick]
	for i = 1, #self.frames do
		local frame = self.frames[i]
		if not isArenaUnit(frame.unit) then
			frame:SetAttribute("*type2", rightAction)
			setMiddleClick(frame, middleAction)
		elseif frame.unit:find("^arena%d$") then
			for modifier, key in pairs(ARENA_CLICKS) do
				setArenaClick(frame, modifier, config[key])
			end
		end
	end
end

function UnitFrameMixin:SetContentInset(inset)
	local left, right = BORDER_INSET, -BORDER_INSET
	if self.iconSide == "LEFT" then
		left = left + inset
	elseif self.iconSide == "RIGHT" then
		right = right - inset
	end
	local powerHeight = self.power:IsShown() and self.innerHeight * config.powerRatio or 0
	self.health:SetPoint("TOPRIGHT", right, -BORDER_INSET)
	self.health:SetPoint("BOTTOMLEFT", left, BORDER_INSET + powerHeight)
	self.power:SetPoint("BOTTOMLEFT", left, BORDER_INSET)
end

function UnitFrameMixin:SetFrameSize(width, height)
	self:SetSize(width, height)
	self.innerHeight = height - BORDER_INSET * 2
	if not self.power then
		return
	end
	local icon = self.classicon
	if icon then
		local size = classIconSize(height)
		icon:SetSize(size, size)
	end
	self:UpdateContentInset()
end

function UnitFrameMixin:UpdateContentInset()
	local icon = self.classicon
	self:SetContentInset(
		icon and icon:IsShown() and UF.ClassIconShown(self) and UF.ClassIconInset(icon:GetWidth()) or 0
	)
end

function UF.ClassIconShown(frame)
	return config.showClassIcon and frame.iconSide ~= "NONE"
end

function UnitFrameMixin:SetIconSide(side)
	local icon = self.classicon
	if not icon or self.iconSide == side then
		return
	end
	local previous = self.iconSide
	self.iconSide = side
	icon:ClearAllPoints()
	if side == "RIGHT" then
		icon:SetPoint("TOPRIGHT", -CLASS_ICON_INSET, -CLASS_ICON_INSET)
	else
		icon:SetPoint("TOPLEFT", CLASS_ICON_INSET, -CLASS_ICON_INSET)
	end
	self:UpdateContentInset()
	if previous and (previous == "NONE" or side == "NONE") then
		if UF.testing then
			UF:RunTest(self)
		else
			self:QueueUpdate()
		end
	end
end

function UF.ClassIconInset(size)
	return size + CLASS_ICON_GAP + CLASS_ICON_INSET - BORDER_INSET
end

function UF:CreateRectangle(unit, width, height, iconSide, parent)
	local frame = self:CreateBase(unit, parent)
	frame:SetSize(width, height)
	frame.innerHeight = height - BORDER_INSET * 2

	local health = self:AddElement(frame, "health")

	local power = self:AddElement(frame, "power")
	power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT")

	frame:SetContentInset(0)

	if iconSide then
		self:AddElement(frame, "classicon", classIconSize(height))
		frame:SetIconSide(iconSide)
	end

	self:AddElement(frame, "texts")

	local combat = self:AddElement(frame, "combat")
	if frame.classicon then
		combat:SetPoint("TOPLEFT", frame.classicon, 1, -1)
	else
		combat:SetPoint("TOPLEFT", health, 2, -2)
	end

	return frame
end

function UF:CreateSideCastbar(frame, side, width, height)
	local castbar = self:AddElement(frame, "castbar", side)
	castbar.iconSide = side
	UF.SetCastbarSize(castbar, width, height)
	return castbar
end

function UF:CreateSquare(unit, size, parent)
	local frame = self:CreateBase(unit, parent)
	frame:SetSize(size, size)

	local health = self:AddElement(frame, "health")
	health:SetPoint("TOPRIGHT", -BORDER_INSET, -BORDER_INSET)
	health:SetPoint("BOTTOMLEFT", BORDER_INSET, BORDER_INSET)
	health.text = UF.CreateText(health)
	health.text:SetPoint("CENTER")
	health.text.template = "[curhp]"

	return frame
end

function UF:CreatePet(unit, size, parent)
	local frame = self:CreateSquare(unit, size, parent)
	frame.ownerUnit = unit == "pet" and "player" or unit:gsub("pet(%d)$", "%1")
	RegisterUnitEvent(frame, "UNIT_PET", frame.ownerUnit, queueUpdate)

	frame.innerHeight = size - BORDER_INSET * 2
	local power = self:AddElement(frame, "power")
	power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT")
	frame:SetContentInset(0)

	if not isArenaUnit(frame.ownerUnit) then
		frame:EnableVehicleSwap(frame.ownerUnit, frame.ownerUnit)
	end
	return frame
end

function UF.SetPetPowerShown(frame, shown)
	ns.SetShown(frame.power, shown)
	frame:SetContentInset(0)
end

local function updateHideSelf(frame)
	frame:SetAlpha(config.hideTargetOfTargetSelf and UnitIsUnit(frame.unit, "player") and 0 or 1)
end

local function testHideSelf(frame)
	frame:SetAlpha(1)
end

UF:RegisterElement({
	name = "hideself",
	Create = function()
		return true
	end,
	Update = updateHideSelf,
	Test = testHideSelf,
})

function UF:CreateTargetOfTarget(unit, size, parent)
	local frame = self:CreateSquare(unit, size, parent)
	frame.ownerUnit = unit:match("^(.+)target$")
	RegisterUnitEvent(frame, "UNIT_TARGET", frame.ownerUnit, queueUpdate)

	local name = self:AddElement(frame, "name", "[name:3]")
	name:SetPoint("TOP", 0, -BORDER_INSET)

	return frame
end

local function targetAuraSize(width, perRow)
	return width / perRow - 1
end

function UF:CreateTarget(unit, width, height)
	local frame = self:CreateRectangle(unit, width, height, config[unit .. "IconSide"])

	local targetOfTarget = self:CreateTargetOfTarget(unit .. "target", height)

	local keys = UF.CategoryKeys(unit)
	local perRow = config[keys.auraPerRow]
	local auraOptions = {
		size = targetAuraSize(width, perRow),
		width = width,
		max = perRow * config[keys.auraRows],
	}
	self:AddElement(frame, "debuffs", auraOptions)
	self:AddElement(frame, "buffs", auraOptions)

	self:AddElement(frame, "castbar")
	self:AddElement(frame, "losecontrol")
	frame.targetOfTarget = targetOfTarget
	self:ResizeTarget(frame, width, height)

	return frame, targetOfTarget
end

function UF:ResizeTarget(frame, width, height)
	frame:SetFrameSize(width, height)
	local keys = UF.CategoryKeys(frame.baseUnit)
	local perRow = config[keys.auraPerRow]
	local auraSize, auraLimit = targetAuraSize(width, perRow), perRow * config[keys.auraRows]
	local debuffs, buffs = frame.debuffs, frame.buffs
	debuffs:SetLayout(width, auraSize)
	buffs:SetLayout(width, auraSize)
	debuffs:SetLimit(config[keys.debuffs] and auraLimit or 0)
	buffs:SetLimit(config[keys.buffs] and auraLimit or 0)

	UF.PlaceAuraGrids(frame, keys, CASTBAR_GAP)
	UF.SetCastbarSize(frame.castbar, config[keys.castbarWidth], config[keys.castbarHeight])
end
