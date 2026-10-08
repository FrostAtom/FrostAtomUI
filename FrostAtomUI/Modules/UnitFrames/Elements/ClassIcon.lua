local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local UnitIsVisible = UnitIsVisible
local SetPortraitTexture = SetPortraitTexture

local Talents = ns:GetModule("Talents")
local config = ns.Config.unitFrames

local ClassIcons = ns.ClassIcons
local PORTRAIT_TRIM = 0.15

UF.CLASS_ICONS = ClassIcons.TEXTURE
UF.ICON_TRIM = ClassIcons.TRIM
UF.SPELL_TRIM = ClassIcons.SPELL_TRIM
UF.classCoords = ClassIcons.coords
UF.specIcons = ClassIcons.specIcons
UF.SetClassTexture = ClassIcons.SetClassTexture
UF.SetSpecBadge = ClassIcons.SetSpecBadge

local function applyModel(model)
	local guid = UnitGUID(model.unit)
	if model.guid ~= guid then
		model.guid = guid
		model:ClearModel()
		model:SetUnit(model.unit)
	end
	model:SetCamera(0)
end

-- 3.3.5: a reloaded model (gear, form, late loading) falls back to the full-body camera
local function onModelUpdate(model)
	model:SetCamera(0)
end

local function onModelShow(model)
	model.guid = nil
	if model.unit then
		applyModel(model)
	end
end

local function createModel(icon)
	local background = icon:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetTexture(0, 0, 0)

	local model = CreateFrame("PlayerModel", nil, icon)
	model:SetAllPoints()
	model:SetScript("OnShow", onModelShow)
	model:SetScript("OnUpdate", onModelUpdate)
	model.background = background

	icon.model = model
	return model
end

local function setModel(icon, unit)
	local model = icon.model or createModel(icon)
	model.background:Show()
	model.unit = unit
	if model:IsShown() then
		applyModel(model)
	else
		model:Show()
	end
end

local function hideModel(icon)
	local model = icon.model
	if model then
		model.unit = nil
		model:Hide()
		model.background:Hide()
	end
end

local function setIcon(frame, icon, unit, class, spec)
	icon:Show()
	local shown = UF.ClassIconShown(frame)
	local style = config.classIconStyle
	local model = shown and style == "model" and UnitIsVisible(unit)
	ns.SetShown(icon.texture, shown and not model)
	ClassIcons.SetSpecBadge(icon, shown and style == "badge" and class, spec)
	if not model then
		hideModel(icon)
	end
	if not shown then
		frame:SetContentInset(0)
		return
	end

	if model then
		setModel(icon, unit)
	elseif style == "portrait" or not ClassIcons.SetClassTexture(icon.texture, class, style == "spec" and spec) then
		SetPortraitTexture(icon.texture, unit)
		icon.texture:SetTexCoord(PORTRAIT_TRIM, 1 - PORTRAIT_TRIM, PORTRAIT_TRIM, 1 - PORTRAIT_TRIM)
	end

	frame:SetContentInset(UF.ClassIconInset(icon:GetWidth()))
end

local function update(frame)
	local unit = frame.unit
	local icon = frame.classicon
	if not UnitExists(unit) then
		icon:Hide()
		hideModel(icon)
		frame:SetContentInset(0)
		return
	end

	local _, class = UnitClass(unit)
	class = UnitIsPlayer(unit) and class
	setIcon(frame, icon, unit, class, class and Talents:GetSpec(UnitGUID(unit)))
end

local function test(frame)
	setIcon(frame, frame.classicon, "player", frame.test.class, frame.test.spec)
end

local function onTalentsUpdated(frame, guid)
	if guid == UnitGUID(frame.unit) then
		update(frame)
	end
end

local function create(frame, size)
	local icon = CreateFrame("Frame", nil, frame)
	icon:SetSize(size, size)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetAllPoints()

	frame:RegisterEvent(ns.E.TALENTS_UPDATED, onTalentsUpdated)
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", update)
	frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", update)

	return icon
end

UF:RegisterElement({ name = "classicon", Create = create, Update = update, Test = test })
