local ADDON_NAME, ns = ...

local RegisterUnitWatch, UnregisterUnitWatch = RegisterUnitWatch, UnregisterUnitWatch
local UnitHasVehicleUI, UnitIsConnected, UnitIsUnit = UnitHasVehicleUI, UnitIsConnected, UnitIsUnit
local UnitFrame_OnEnter = UnitFrame_OnEnter
local UnitFrame_OnLeave = UnitFrame_OnLeave
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil

local UF = ns:NewModule("UnitFrames")
UF.configKey = "unitFrames"

local FRAME_NAME = ADDON_NAME .. "%sUnitFrame"
local BORDER_INSET = 4
local CLASS_ICON_INSET = 2
local CLASS_ICON_GAP = 2
local CASTBAR_GAP = 4
local CASTBAR_ICON_GAP = 2
local TARGET_AURA_ROWS = 2
local BAR_BACKGROUND_DIM = 0.3
local RIGHT_CLICK_ACTIONS = { menu = "menu", focus = "focus" }
local config = ns.Config.unitFrames

UF.BORDER_INSET = BORDER_INSET
UF.CLASS_ICON_INSET = CLASS_ICON_INSET
UF.CASTBAR_ICON_GAP = CASTBAR_ICON_GAP
UF.BAR_BACKGROUND_DIM = BAR_BACKGROUND_DIM
UF.backdrop = ns.CreateBackdrop(14, 3)

UF.classColors = {}
UF.classBarColors = {}
UF.classList = {}
for class, color in pairs(RAID_CLASS_COLORS) do
	UF.classColors[class] = { min(color.r * 1.25, 1), min(color.g * 1.25, 1), min(color.b * 1.25, 1) }
	UF.classBarColors[class] = { color.r * 0.75, color.g * 0.75, color.b * 0.75 }
	UF.classList[#UF.classList + 1] = class
end
table.sort(UF.classList)

UF.powerColors = {}
for powerType = 0, #PowerBarColor do
	local color = PowerBarColor[powerType]
	UF.powerColors[powerType] = { color.r * 0.66, color.g * 0.66, color.b * 0.66 }
end

UF.debuffColors = {}
for debuffType, color in pairs(DebuffTypeColor) do
	UF.debuffColors[debuffType] = { color.r, color.g, color.b }
end

UF.textColor = config.textColor
UF.frames = {}

local elements = {}
UF.elements = elements

function UF:RegisterElement(name, create, update, test)
	elements[name] = { create = create, update = update, test = test }
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

function UF.SkinIcon(icon, texture)
	texture:SetAllPoints()
	icon.border = icon:CreateTexture(nil, "ARTWORK")
	icon.border:SetTexture(ns.Media.buttonNormal)
	icon.border:SetAllPoints()
end

function UF.SetBackdropColors(frame)
	frame:SetBackdropColor(unpack(config.backdropColor))
	frame:SetBackdropBorderColor(unpack(config.borderColor))
end

function UF.SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.bg:SetVertexColor(r * BAR_BACKGROUND_DIM, g * BAR_BACKGROUND_DIM, b * BAR_BACKGROUND_DIM)
end

function UF.SetCastbarSize(castbar, width, height)
	castbar:SetSize(width, height)
	castbar.icon:SetSize(height, height)
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

	for name, element in pairs(elements) do
		if self[name] then
			element.update(self)
		end
	end
end

function UnitFrameMixin:QueueUpdate()
	ns.Defer(self, self.UpdateAll)
end

local eventWrappers = setmetatable({}, {
	__index = function(self, handler)
		local wrapper = function(frame, ...)
			if frame.watched and not UF.testing then
				handler(frame, ...)
			end
		end
		self[handler] = wrapper
		return wrapper
	end,
})

local unitEventWrappers = setmetatable({}, {
	__index = function(self, handler)
		local wrapper = function(frame, _, ...)
			if frame.watched and not UF.testing then
				handler(frame, ...)
			end
		end
		self[handler] = wrapper
		return wrapper
	end,
})

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
	for name in pairs(elements) do
		if not (fixed and fixed[name]) then
			retarget(self[name], from, unit)
		end
	end
	self.unit = unit
end

local function onVehicleChanged(frame)
	frame:QueueUpdate()
end

function UnitFrameMixin:EnableVehicleSwap(owner, vehicleUnit, fixed)
	self.vehicleOwner = owner
	self.vehicleUnit = vehicleUnit
	self.fixedUnit = fixed
	self:SetAttribute("toggleForVehicle", true)
	RegisterUnitEvent(self, "UNIT_ENTERED_VEHICLE", owner, onVehicleChanged)
	RegisterUnitEvent(self, "UNIT_EXITED_VEHICLE", owner, onVehicleChanged)
end

local function capitalize(text)
	return (text:gsub("^%l", string.upper))
end

local TEXT_ELEMENTS = { "health", "power", "name" }

local function setHovered(frame, hovered)
	frame.hovered = hovered
	ns.SetShown(frame.hover, hovered and config.hoverHighlight)
	local method = UF.testing and "test" or frame:IsShown() and "update"
	if not method then
		return
	end
	for i = 1, #TEXT_ELEMENTS do
		local key = TEXT_ELEMENTS[i]
		if frame[key] then
			elements[key][method](frame)
		end
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

function UF:CreateBase(unit)
	local frame = CreateFrame("Button", FRAME_NAME:format(capitalize(unit)), UIParent, "SecureUnitButtonTemplate")
	ns.Mixin(frame, ns.EventMixin, UnitFrameMixin)
	frame.unit = unit
	frame.baseUnit = unit
	frame.unitEvents = {}

	frame:RegisterForClicks("AnyDown")
	frame:SetBackdrop(UF.backdrop)
	UF.SetBackdropColors(frame)
	UF.frames[#UF.frames + 1] = frame

	frame:SetAttribute("unit", unit)
	frame:SetAttribute("*type1", "target")
	if isArenaUnit(unit) then
		frame:SetAttribute("*type2", "focus")
	else
		frame:SetAttribute("*type2", RIGHT_CLICK_ACTIONS[config.rightClick])
		if unit == "focus" then
			frame:SetAttribute("*type3", "macro")
			frame:SetAttribute("macrotext", "/clearfocus")
		else
			frame:SetAttribute("*type3", "focus")
		end
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
	if watched then
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
		for j = 1, #TEXT_ELEMENTS do
			local key = TEXT_ELEMENTS[j]
			local element = frame[key]
			local text = element and (element.text or (key == "name" and element))
			if text then
				text:SetTextColor(unpack(config.textColor))
				ns.SetFont(text, config.textFont.size, config.textFont.outline)
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

function UF:ApplyClicks()
	local action = RIGHT_CLICK_ACTIONS[config.rightClick]
	for i = 1, #self.frames do
		local frame = self.frames[i]
		if not isArenaUnit(frame.unit) then
			frame:SetAttribute("*type2", action)
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
		local size = height - CLASS_ICON_INSET * 2
		icon:SetSize(size, size)
		self:SetContentInset(icon:IsShown() and config.showClassIcon and UF.ClassIconInset(size) or 0)
	else
		self:SetContentInset(0)
	end
end

function UF.ClassIconInset(size)
	return size + CLASS_ICON_GAP + CLASS_ICON_INSET - BORDER_INSET
end

function UF:CreateRectangle(unit, width, height, iconSide)
	local frame = self:CreateBase(unit)
	frame:SetSize(width, height)
	frame.iconSide = iconSide
	frame.innerHeight = height - BORDER_INSET * 2

	local health = self:AddElement(frame, "health")
	health.text:SetPoint("BOTTOMRIGHT")

	local power = self:AddElement(frame, "power")
	power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT")
	power.text:SetPoint("RIGHT")

	frame:SetContentInset(0)

	if iconSide then
		local icon = self:AddElement(frame, "classicon", height - CLASS_ICON_INSET * 2)
		icon:SetPoint(
			"TOP" .. iconSide,
			iconSide == "LEFT" and CLASS_ICON_INSET or -CLASS_ICON_INSET,
			-CLASS_ICON_INSET
		)
	end

	local name = self:AddElement(frame, "name")
	name:SetJustifyH("RIGHT")
	name:SetPoint("BOTTOMLEFT", health)

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
	if side == "RIGHT" then
		castbar:SetPoint("TOPLEFT", frame, "TOPRIGHT", BORDER_INSET, 0)
	else
		castbar:SetPoint("TOPRIGHT", frame, "TOPLEFT", -BORDER_INSET, 0)
	end
	UF.SetCastbarSize(castbar, width, height)
	return castbar
end

function UF:CreateSquare(unit, size)
	local frame = self:CreateBase(unit)
	frame:SetSize(size, size)

	local health = self:AddElement(frame, "health")
	health:SetPoint("TOPRIGHT", -BORDER_INSET, -BORDER_INSET)
	health:SetPoint("BOTTOMLEFT", BORDER_INSET, BORDER_INSET)
	health.text:SetPoint("CENTER")
	health.text.template = "[curhp]"

	return frame
end

local function onOwnerUnitChanged(self)
	self:QueueUpdate()
end

function UF:CreatePet(unit, size)
	local frame = self:CreateSquare(unit, size)
	frame.ownerUnit = unit == "pet" and "player" or unit:gsub("pet(%d)$", "%1")
	RegisterUnitEvent(frame, "UNIT_PET", frame.ownerUnit, onOwnerUnitChanged)

	frame.innerHeight = size - BORDER_INSET * 2
	local power = self:AddElement(frame, "power")
	power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT")
	power.text.template = ""
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

UF:RegisterElement("hideself", function()
	return true
end, updateHideSelf, testHideSelf)

function UF:CreateTargetOfTarget(unit, size)
	local frame = self:CreateSquare(unit, size)
	frame.ownerUnit = unit:match("^(.+)target$")
	RegisterUnitEvent(frame, "UNIT_TARGET", frame.ownerUnit, onOwnerUnitChanged)

	local name = self:AddElement(frame, "name", "[name:3]")
	name:SetPoint("TOP", 0, -BORDER_INSET)

	return frame
end

local function targetAuraSize(width, perRow)
	return width / perRow - 1
end

function UF:CreateTarget(unit, width, height)
	local frame = self:CreateRectangle(unit, width, height, "RIGHT")

	local targetOfTarget = self:CreateTargetOfTarget(unit .. "target", height)

	local perRow = config.targetAuraPerRow
	local auraOptions = {
		size = targetAuraSize(width, perRow),
		width = width,
		max = perRow * TARGET_AURA_ROWS,
	}
	local debuffs = self:AddElement(frame, "debuffs", auraOptions)
	debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -CASTBAR_GAP)

	local buffs = self:AddElement(frame, "buffs", auraOptions)
	buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -CASTBAR_GAP)
	debuffs.OnRowsChanged = function(grid, rows)
		buffs:SetPoint(
			"TOPLEFT",
			frame,
			"BOTTOMLEFT",
			0,
			-CASTBAR_GAP - (rows > 0 and grid:GetHeight() + CASTBAR_GAP or 0)
		)
	end

	self:AddElement(frame, "castbar")
	self:AddElement(frame, "losecontrol")
	frame.targetOfTarget = targetOfTarget
	self:ResizeTarget(frame, width, height)

	return frame, targetOfTarget
end

function UF:ResizeTarget(frame, width, height)
	frame:SetFrameSize(width, height)
	frame.targetOfTarget:SetFrameSize(height, height)
	local perRow = config.targetAuraPerRow
	local auraSize, auraLimit = targetAuraSize(width, perRow), perRow * TARGET_AURA_ROWS
	local debuffs, buffs = frame.debuffs, frame.buffs
	debuffs:SetLayout(width, auraSize)
	buffs:SetLayout(width, auraSize)
	debuffs:SetLimit(auraLimit)
	buffs:SetLimit(auraLimit)

	debuffs:OnRowsChanged(debuffs.rows)
	local rowSize = debuffs.RowSize and debuffs:RowSize() or debuffs.size
	local gridHeight = TARGET_AURA_ROWS * (rowSize + debuffs.gap) - debuffs.gap
	local castbarOffset = CASTBAR_GAP * 3 + gridHeight * 2
	local castbar = frame.castbar
	castbar:SetHeight(height)
	castbar:ClearAllPoints()
	castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", height + CASTBAR_ICON_GAP, -castbarOffset)
	castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -castbarOffset)
	castbar.icon:SetSize(height, height)
end
