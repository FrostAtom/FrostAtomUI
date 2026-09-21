local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local SetPortraitTexture = SetPortraitTexture
local unpack = unpack

local Talents = ns:GetModule("Talents")

local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local GAP = 2
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

local function setIcon(frame, icon, class, spec)
	local coords = class and classCoords[class]
	local specIcon = coords and spec and SPEC_ICONS[class] and SPEC_ICONS[class][spec]
	if specIcon then
		icon.texture:SetTexture(specIcon)
		icon.texture:SetTexCoord(0, 1, 0, 1)
	elseif coords then
		icon.texture:SetTexture(CLASS_ICONS)
		icon.texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		SetPortraitTexture(icon.texture, frame.unit)
		icon.texture:SetTexCoord(0, 1, 0, 1)
	end

	icon:Show()
	frame:SetContentInset(icon:GetWidth() + GAP)
end

local function update(frame)
	local unit = frame.unit
	local icon = frame.classicon
	if not UnitExists(unit) then
		icon:Hide()
		frame:SetContentInset(0)
		return
	end

	local _, class = UnitClass(unit)
	class = UnitIsPlayer(unit) and class
	setIcon(frame, icon, class, class and Talents:GetSpec(UnitGUID(unit)))
end

local function test(frame)
	setIcon(frame, frame.classicon, frame.test.class, frame.test.spec)
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

	return icon
end

UF:RegisterElement("classicon", create, update, test)
