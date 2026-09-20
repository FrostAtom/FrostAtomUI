local ADDON_NAME, ns = ...

local CreateFrame = CreateFrame
local RegisterUnitWatch = RegisterUnitWatch
local UnitFrame_OnEnter = UnitFrame_OnEnter
local UnitFrame_OnLeave = UnitFrame_OnLeave
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil

local UF = ns:NewModule("UnitFrames")

local FRAME_NAME = ADDON_NAME .. "%sUnitFrame"
local BORDER_INSET = 2

UF.classColors = {}
UF.classBarColors = {}
for class, color in pairs(RAID_CLASS_COLORS) do
	UF.classColors[class] = { min(color.r * 1.25, 1), min(color.g * 1.25, 1), min(color.b * 1.25, 1) }
	UF.classBarColors[class] = { color.r * 0.75, color.g * 0.75, color.b * 0.75 }
end

UF.powerColors = {}
for powerType = 0, #PowerBarColor do
	local color = PowerBarColor[powerType]
	UF.powerColors[powerType] = { color.r * 0.66, color.g * 0.66, color.b * 0.66 }
end

UF.debuffColors = {}
for debuffType, color in pairs(DebuffTypeColor) do
	UF.debuffColors[debuffType] = { color.r, color.g, color.b }
end

UF.textColor = { 1, 0.9, 0.8 }

local elements = {}

function UF:RegisterElement(name, create, update)
	elements[name] = { create = create, update = update }
end

function UF:AddElement(frame, name, ...)
	local element = assert(elements[name], ("unknown unit frame element [%s]"):format(tostring(name)))
	assert(not frame[name], ("element [%s] already added to %s"):format(name, frame.unit))

	local widget = element.create(frame, ...)
	frame[name] = widget
	return widget
end

local ICON_TEXCOORD = { 0.07, 0.93, 0.07, 0.93 }
local ICON_BORDER = 1
local GRID_PADDING = 2
local GRID_BG_ALPHA = 0.4

function UF.SkinIcon(icon, texture)
	icon.border = icon:CreateTexture(nil, "BACKGROUND", nil, -1)
	icon.border:SetTexture(0, 0, 0)
	icon.border:SetAllPoints()
	texture:SetPoint("TOPLEFT", ICON_BORDER, -ICON_BORDER)
	texture:SetPoint("BOTTOMRIGHT", -ICON_BORDER, ICON_BORDER)
	texture:SetTexCoord(unpack(ICON_TEXCOORD))
end

local function layoutGrid(grid, shown)
	for i = shown + 1, #grid do
		grid[i]:Hide()
	end

	local gap = grid.gap
	local step = grid.size + gap
	local rows = ceil(shown / grid.perRow)
	grid:SetHeight(max(max(rows, grid.minRows) * step - gap, 2))

	if shown > 0 then
		local columns = min(shown, grid.perRow)
		grid.bg:SetSize(columns * step - gap + GRID_PADDING * 2, rows * step - gap + GRID_PADDING * 2)
		grid.bg:Show()
	else
		grid.bg:Hide()
	end
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
	grid:SetSize(grid.perRow * (grid.size + grid.gap) - grid.gap, 2)

	grid.bg = CreateFrame("Frame", nil, grid)
	grid.bg:SetFrameLevel(max(grid:GetFrameLevel() - 1, 0))
	grid.bg.texture = grid.bg:CreateTexture(nil, "BACKGROUND")
	grid.bg.texture:SetAllPoints()
	grid.bg.texture:SetTexture(0, 0, 0, GRID_BG_ALPHA)
	grid.bg:SetPoint(
		grid.anchor,
		grid.anchor:find("RIGHT") and GRID_PADDING or -GRID_PADDING,
		grid.anchor:find("BOTTOM") and -GRID_PADDING or GRID_PADDING
	)
	grid.bg:Hide()

	return grid
end

function UF.GridIconPoint(grid, index)
	return ns.GridPoint(grid.anchor, index, grid.perRow, grid.size + grid.gap)
end

local UnitFrameMixin = {}
UF.FrameMixin = UnitFrameMixin

function UnitFrameMixin:UpdateAll()
	if not self:IsShown() then
		return
	end

	for name, element in pairs(elements) do
		if self[name] then
			element.update(self)
		end
	end
end

local unitEventWrappers = setmetatable({}, {
	__index = function(self, handler)
		local wrapper = function(frame, unit, ...)
			if unit == frame.unit then
				handler(frame, ...)
			end
		end
		self[handler] = wrapper
		return wrapper
	end,
})

function UnitFrameMixin:RegisterUnitEvent(event, handler)
	self:RegisterEvent(event, unitEventWrappers[handler])
end

local function capitalize(text)
	return (text:gsub("^%l", string.upper))
end

function UF:CreateBase(unit)
	local frame = CreateFrame("Button", FRAME_NAME:format(capitalize(unit)), UIParent, "SecureUnitButtonTemplate")
	ns.Mixin(frame, ns.EventMixin, UnitFrameMixin)
	frame.unit = unit

	frame:RegisterForClicks("AnyDown")
	frame:SetBackdrop(ns.CreateBackdrop(8))
	frame:SetBackdropColor(0.137, 0.137, 0.137)
	frame:SetBackdropBorderColor(0.2, 0.2, 0.2)

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

	return frame
end

function UnitFrameMixin:SetContentInset(inset)
	local left, right = BORDER_INSET, -BORDER_INSET
	if self.iconSide == "LEFT" then
		left = left + inset
	elseif self.iconSide == "RIGHT" then
		right = right - inset
	end
	self.health:SetPoint("TOPRIGHT", right, -BORDER_INSET)
	self.health:SetPoint("BOTTOMLEFT", left, BORDER_INSET + self.innerHeight / 3)
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
	power.text:SetPoint("BOTTOMRIGHT")

	frame:SetContentInset(0)

	if iconSide then
		local icon = self:AddElement(frame, "classicon", frame.innerHeight)
		icon:SetPoint("TOP" .. iconSide, iconSide == "LEFT" and BORDER_INSET or -BORDER_INSET, -BORDER_INSET)
	end

	local name = self:AddElement(frame, "name")
	name:SetJustifyH("RIGHT")
	name:SetPoint("BOTTOMLEFT", health)

	local combat = self:AddElement(frame, "combat")
	combat:SetPoint("TOPLEFT", health, 6, 6)

	return frame
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
	name:SetPoint("TOP", 0, -2)

	return frame
end

function UF:CreateTarget(unit, width, height)
	local frame = self:CreateRectangle(unit, width, height, "RIGHT")

	local targetOfTarget = self:CreateTargetOfTarget(unit .. "target", height)
	targetOfTarget:SetPoint("LEFT", frame, "RIGHT", 20)

	local buffs = self:AddElement(frame, "buffs", { size = width / 8 - 1, width = width })
	buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT")

	local debuffs = self:AddElement(frame, "debuffs", { size = width / 8 - 1, width = width })
	debuffs:SetPoint("TOPLEFT", buffs, "BOTTOMLEFT")

	local castbar = self:AddElement(frame, "castbar")
	castbar:SetSize(width, width * 0.1)
	castbar:SetPoint("TOPLEFT", debuffs, "BOTTOMLEFT")
	castbar.icon:SetSize(width * 0.1 + 2, width * 0.1 + 2)

	self:AddElement(frame, "losecontrol")

	return frame, targetOfTarget
end
