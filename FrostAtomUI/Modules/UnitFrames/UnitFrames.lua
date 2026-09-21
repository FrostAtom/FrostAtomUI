local ADDON_NAME, ns = ...

local CreateFrame = CreateFrame
local RegisterUnitWatch, UnregisterUnitWatch = RegisterUnitWatch, UnregisterUnitWatch
local UnitFrame_OnEnter = UnitFrame_OnEnter
local UnitFrame_OnLeave = UnitFrame_OnLeave
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil

local UF = ns:NewModule("UnitFrames")
UF.configKey = "unitFrames"

local FRAME_NAME = ADDON_NAME .. "%sUnitFrame"
local BORDER_INSET = 4
local CLASS_ICON_INSET = 2
local POWER_RATIO = 0.2
local CASTBAR_GAP = 4
local CASTBAR_ICON_GAP = 2
local TARGET_AURAS_PER_ROW = 8
local TARGET_AURA_ROWS = 2
local config = ns.Config.unitFrames

UF.BORDER_INSET = BORDER_INSET
UF.CLASS_ICON_INSET = CLASS_ICON_INSET
UF.CASTBAR_ICON_GAP = CASTBAR_ICON_GAP
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

	local widget = element.create(frame, ...)
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

function UF:CreateIconGrid(frame, options)
	options = options or {}

	local grid = CreateFrame("Frame", nil, frame)
	grid:SetFrameLevel(frame:GetFrameLevel())
	grid.size = options.size or 22
	grid.gap = options.gap or 1
	grid.perRow = options.perRow or 8
	if options.width then
		grid.perRow = max(floor((options.width + grid.gap) / (grid.size + grid.gap)), 1)
		grid.size = (options.width + grid.gap) / grid.perRow - grid.gap
	end
	grid.anchor = options.anchor or "TOPLEFT"
	grid.max = options.max
	grid.minRows = options.minRows or 0
	grid.Layout = layoutGrid
	grid.SetIconSize = setGridIconSize
	grid.rows = 0
	grid:SetSize(grid.perRow * (grid.size + grid.gap) - grid.gap, 1)

	return grid
end

function UF.GridIconPoint(grid, index)
	return ns.GridPoint(grid.anchor, index, grid.perRow, grid.size + grid.gap)
end

local UnitFrameMixin = {}
UF.FrameMixin = UnitFrameMixin

function UnitFrameMixin:UpdateAll()
	if UF.testing or not self:IsShown() then
		return
	end

	for name, element in pairs(elements) do
		if self[name] then
			element.update(self)
		end
	end
end

local eventWrappers = setmetatable({}, {
	__index = function(self, handler)
		local wrapper = function(frame, ...)
			if not UF.testing then
				handler(frame, ...)
			end
		end
		self[handler] = wrapper
		return wrapper
	end,
})

local unitEventWrappers = setmetatable({}, {
	__index = function(self, handler)
		local wrapper = function(frame, unit, ...)
			if unit == frame.unit and not UF.testing then
				handler(frame, ...)
			end
		end
		self[handler] = wrapper
		return wrapper
	end,
})

local RegisterEvent = ns.EventMixin.RegisterEvent

function UnitFrameMixin:RegisterEvent(event, handler)
	if type(handler) == "function" then
		handler = eventWrappers[handler]
	end
	RegisterEvent(self, event, handler)
end

function UnitFrameMixin:RegisterUnitEvent(event, handler)
	RegisterEvent(self, event, unitEventWrappers[handler])
end

local function capitalize(text)
	return (text:gsub("^%l", string.upper))
end

function UF:CreateBase(unit)
	local frame = CreateFrame("Button", FRAME_NAME:format(capitalize(unit)), UIParent, "SecureUnitButtonTemplate")
	ns.Mixin(frame, ns.EventMixin, UnitFrameMixin)
	frame.unit = unit

	frame:RegisterForClicks("AnyDown")
	frame:SetBackdrop(UF.backdrop)
	UF.SetBackdropColors(frame)
	UF.frames[#UF.frames + 1] = frame

	frame:SetAttribute("unit", unit)
	frame:SetAttribute("*type1", "target")
	if unit:find("^arena%d$") then
		frame:SetAttribute("*type2", "focus")
	else
		frame:SetAttribute("*type2", "menu")
		if unit == "focus" then
			frame:SetAttribute("*type3", "macro")
			frame:SetAttribute("macrotext", "/clearfocus")
		else
			frame:SetAttribute("*type3", "focus")
		end
	end

	frame:SetScript("OnEnter", UnitFrame_OnEnter)
	frame:SetScript("OnLeave", UnitFrame_OnLeave)
	frame:SetScript("OnShow", frame.UpdateAll)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
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

function UF:ApplyColors()
	for i = 1, #self.frames do
		local frame = self.frames[i]
		UF.SetBackdropColors(frame)
		for _, key in ipairs({ "health", "power", "name" }) do
			local element = frame[key]
			local text = element and (element.text or (key == "name" and element))
			if text then
				text:SetTextColor(unpack(config.textColor))
				if key ~= "power" then
					text:SetFont(ns.Media.font, config.textFont.size, config.textFont.outline)
				end
			end
		end
		local castbar = frame.castbar
		if castbar then
			UF.SetBackdropColors(castbar)
			castbar.timer:SetFont(ns.Media.font, config.castbarFont.size, config.castbarFont.outline)
			castbar.name:SetFont(ns.Media.font, config.castbarFont.size, config.castbarFont.outline)
		end
		frame:UpdateAll()
	end
end

function UnitFrameMixin:SetContentInset(inset)
	local left, right = BORDER_INSET, -BORDER_INSET
	if self.iconSide == "LEFT" then
		left = left + inset
	elseif self.iconSide == "RIGHT" then
		right = right - inset
	end
	self.health:SetPoint("TOPRIGHT", right, -BORDER_INSET)
	self.health:SetPoint("BOTTOMLEFT", left, BORDER_INSET + self.innerHeight * POWER_RATIO)
	self.power:SetPoint("BOTTOMLEFT", left, BORDER_INSET)
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
		icon:SetPoint("TOP" .. iconSide, iconSide == "LEFT" and CLASS_ICON_INSET or -CLASS_ICON_INSET, -CLASS_ICON_INSET)
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
	castbar:SetSize(width, height)
	if side == "RIGHT" then
		castbar:SetPoint("TOPLEFT", frame, "TOPRIGHT", BORDER_INSET, 0)
	else
		castbar:SetPoint("TOPRIGHT", frame, "TOPLEFT", -BORDER_INSET, 0)
	end
	castbar.icon:SetSize(height, height)
	return castbar
end

function UF:CreateSquare(unit, size)
	local frame = self:CreateBase(unit)
	frame:SetSize(size, size)

	local health = self:AddElement(frame, "health")
	health:SetPoint("TOPRIGHT", -BORDER_INSET, -BORDER_INSET)
	health:SetPoint("BOTTOMLEFT", BORDER_INSET, BORDER_INSET)
	health.text:SetPoint("CENTER")

	return frame
end

local function onOwnerUnitChanged(self, owner)
	if self.ownerUnit == owner then
		self:UpdateAll()
	end
end

function UF:CreatePet(unit, size)
	local frame = self:CreateSquare(unit, size)
	frame.ownerUnit = unit == "pet" and "player" or unit:gsub("pet(%d)$", "%1")
	frame:RegisterEvent("UNIT_PET", onOwnerUnitChanged)
	return frame
end

function UF:CreateTargetOfTarget(unit, size)
	local frame = self:CreateSquare(unit, size)
	frame.ownerUnit = unit:match("^(.+)target$")
	frame:RegisterEvent("UNIT_TARGET", onOwnerUnitChanged)

	local name = self:AddElement(frame, "name", 3)
	name:SetPoint("TOP", 0, -BORDER_INSET)

	return frame
end

function UF:CreateTarget(unit, width, height)
	local frame = self:CreateRectangle(unit, width, height, "RIGHT")

	local targetOfTarget = self:CreateTargetOfTarget(unit .. "target", height)
	targetOfTarget:SetPoint("LEFT", frame, "RIGHT", 20)

	local auraOptions = {
		size = width / TARGET_AURAS_PER_ROW - 1,
		width = width,
		max = TARGET_AURAS_PER_ROW * TARGET_AURA_ROWS,
	}
	local debuffs = self:AddElement(frame, "debuffs", auraOptions)
	debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -CASTBAR_GAP)

	local buffs = self:AddElement(frame, "buffs", auraOptions)
	buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -CASTBAR_GAP)
	debuffs.OnRowsChanged = function(grid, rows)
		buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -CASTBAR_GAP - (rows > 0 and grid:GetHeight() + CASTBAR_GAP or 0))
	end

	local gridHeight = TARGET_AURA_ROWS * (debuffs.size + debuffs.gap) - debuffs.gap
	local castbarOffset = CASTBAR_GAP * 3 + gridHeight * 2
	local castbar = self:AddElement(frame, "castbar")
	castbar:SetHeight(height)
	castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", height + CASTBAR_ICON_GAP, -castbarOffset)
	castbar:SetPoint("TOPRIGHT", targetOfTarget, "BOTTOMRIGHT", 0, -castbarOffset)
	castbar.icon:SetSize(height, height)

	self:AddElement(frame, "losecontrol")

	return frame, targetOfTarget
end
