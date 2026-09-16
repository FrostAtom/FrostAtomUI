local ADDON_NAME, ns = ...

local CreateFrame = CreateFrame
local RegisterUnitWatch = RegisterUnitWatch
local UnitFrame_OnEnter = UnitFrame_OnEnter
local UnitFrame_OnLeave = UnitFrame_OnLeave

local UF = ns:NewModule("UnitFrames")

local FRAME_NAME = ADDON_NAME .. "%sUnitFrame"
local BORDER_INSET = 2

UF.classColors = {}
for class, color in pairs(RAID_CLASS_COLORS) do
	UF.classColors[class] = { math.min(color.r * 1.25, 1), math.min(color.g * 1.25, 1), math.min(color.b * 1.25, 1) }
end

UF.powerColors = {}
for powerType = 0, #PowerBarColor do
	local color = PowerBarColor[powerType]
	UF.powerColors[powerType] = { color.r * 0.66, color.g * 0.66, color.b * 0.66 }
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

function UF:CreateRectangle(unit, width, height)
	local frame = self:CreateBase(unit)
	frame:SetSize(width, height)

	local innerHeight = height - BORDER_INSET * 2
	local health = self:AddElement(frame, "health")
	health:SetPoint("TOPRIGHT", -BORDER_INSET, -BORDER_INSET)
	health:SetPoint("BOTTOMLEFT", BORDER_INSET, BORDER_INSET + innerHeight / 3)
	health.text:SetPoint("BOTTOMRIGHT")

	local power = self:AddElement(frame, "power")
	power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT")
	power:SetPoint("BOTTOMLEFT", BORDER_INSET, BORDER_INSET)
	power.text:SetPoint("BOTTOMRIGHT")

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

local function onOwnerPetChanged(self, owner)
	if self.ownerUnit == owner then
		self:UpdateAll()
	end
end

function UF:CreatePet(unit, size)
	local frame = self:CreateSquare(unit, size)
	frame.ownerUnit = unit == "pet" and "player" or unit:gsub("pet(%d)$", "%1")
	frame:RegisterEvent("UNIT_PET", onOwnerPetChanged)
	return frame
end

local function onOwnerTargetChanged(self, owner)
	if self.ownerUnit == owner then
		self:UpdateAll()
	end
end

function UF:CreateTargetOfTarget(unit, size)
	local frame = self:CreateSquare(unit, size)
	frame.ownerUnit = unit:match("^(.+)target$")
	frame:RegisterEvent("UNIT_TARGET", onOwnerTargetChanged)

	local name = self:AddElement(frame, "name", 3)
	name:SetPoint("TOP", 0, -2)

	return frame
end

function UF:CreateTarget(unit, width, height)
	local frame = self:CreateRectangle(unit, width, height)

	local targetOfTarget = self:CreateTargetOfTarget(unit .. "target", height)
	targetOfTarget:SetPoint("LEFT", frame, "RIGHT", 20)

	local buffs = self:AddElement(frame, "buffs", { size = width / 8 })
	buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT")

	local debuffs = self:AddElement(frame, "debuffs", { size = width / 8 })
	debuffs:SetPoint("TOPLEFT", buffs, "BOTTOMLEFT")

	local castbar = self:AddElement(frame, "castbar")
	castbar:SetSize(width, width * 0.1)
	castbar:SetPoint("TOPLEFT", debuffs, "BOTTOMLEFT")
	castbar.icon:SetSize(width * 0.1 + 2, width * 0.1 + 2)

	local loseControl = self:AddElement(frame, "losecontrol")
	loseControl:SetSize(30, 30)
	loseControl:SetPoint("CENTER")

	return frame, targetOfTarget
end
