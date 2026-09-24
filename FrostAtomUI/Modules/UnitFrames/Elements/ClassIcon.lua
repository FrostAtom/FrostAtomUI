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

local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local TRIM = 0.07

local SPEC_ICONS = {
	DEATHKNIGHT = {
		"Spell_Deathknight_BloodPresence",
		"Spell_Deathknight_FrostPresence",
		"Spell_Deathknight_UnholyPresence",
	},
	DRUID = { "Spell_Nature_StarFall", "Ability_Racial_BearForm", "Spell_Nature_HealingTouch" },
	HUNTER = { "Ability_Hunter_BeastTaming", "Ability_Marksmanship", "Ability_Hunter_SwiftStrike" },
	MAGE = { "Spell_Holy_MagicalSentry", "Spell_Fire_FlameBolt", "Spell_Frost_FrostBolt02" },
	PALADIN = { "Spell_Holy_HolyBolt", "Spell_Holy_DevotionAura", "Spell_Holy_AuraOfLight" },
	PRIEST = { "Spell_Holy_WordFortitude", "Spell_Holy_HolyBolt", "Spell_Shadow_ShadowWordPain" },
	ROGUE = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
	SHAMAN = { "Spell_Nature_Lightning", "Spell_Nature_LightningShield", "Spell_Nature_MagicImmunity" },
	WARLOCK = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
	WARRIOR = { "Ability_Rogue_Eviscerate", "Ability_Warrior_InnerRage", "Ability_Warrior_DefensiveStance" },
}
for _, icons in pairs(SPEC_ICONS) do
	for i = 1, #icons do
		icons[i] = "Interface\\Icons\\" .. icons[i]
	end
end

local classCoords = {}
for class, coords in pairs(CLASS_ICON_TCOORDS) do
	local l, r, t, b = unpack(coords)
	local w, h = (r - l) * TRIM, (b - t) * TRIM
	classCoords[class] = { l + w, r - w, t + h, b - h }
end

UF.CLASS_ICONS = CLASS_ICONS
UF.ICON_TRIM = TRIM
UF.classCoords = classCoords
UF.specIcons = SPEC_ICONS

function UF.SetClassTexture(texture, class, spec)
	local coords = class and classCoords[class]
	if not coords then
		return false
	end
	local specIcon = spec and SPEC_ICONS[class] and SPEC_ICONS[class][spec]
	if specIcon then
		texture:SetTexture(specIcon)
		texture:SetTexCoord(0, 1, 0, 1)
	else
		texture:SetTexture(CLASS_ICONS)
		texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	end
	return true
end

local function applyModel(model)
	local guid = UnitGUID(model.unit)
	if model.guid ~= guid then
		model.guid = guid
		model:ClearModel()
		model:SetUnit(model.unit)
	end
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
	model.background = background

	local overlay = CreateFrame("Frame", nil, icon)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(model:GetFrameLevel() + 1)
	icon.border:SetParent(overlay)

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
	local shown = config.showClassIcon
	local style = config.classIconStyle
	local model = shown and style == "model" and UnitIsVisible(unit)
	ns.SetShown(icon.texture, shown and not model)
	ns.SetShown(icon.border, shown)
	if not model then
		hideModel(icon)
	end
	if not shown then
		frame:SetContentInset(0)
		return
	end

	if model then
		setModel(icon, unit)
	elseif style == "portrait" or not UF.SetClassTexture(icon.texture, class, style ~= "class" and spec) then
		SetPortraitTexture(icon.texture, unit)
		icon.texture:SetTexCoord(0, 1, 0, 1)
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
	UF.SkinIcon(icon, icon.texture)

	frame:RegisterEvent(ns.TALENTS_UPDATED, onTalentsUpdated)
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", update)
	frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", update)

	return icon
end

UF:RegisterElement("classicon", create, update, test)
