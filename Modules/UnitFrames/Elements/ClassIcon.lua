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
local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS
local GAP = 2
local TRIM = 0.07

local SPEC_ICONS = {
	DEATHKNIGHT = { "Spell_Deathknight_BloodPresence", "Spell_Deathknight_FrostPresence", "Spell_Deathknight_UnholyPresence" },
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

local function update(frame)
	local unit = frame.unit
	local icon = frame.classicon
	local _, class = UnitClass(unit)
	if not UnitExists(unit) then
		icon:Hide()
		frame:SetContentInset(0)
		return
	end

	local coords = UnitIsPlayer(unit) and class and CLASS_ICON_TCOORDS[class]
	local spec = coords and Talents:GetSpec(UnitGUID(unit))
	local specIcon = spec and SPEC_ICONS[class] and SPEC_ICONS[class][spec]
	if specIcon then
		icon.texture:SetTexture("Interface\\Icons\\" .. specIcon)
		icon.texture:SetTexCoord(TRIM, 1 - TRIM, TRIM, 1 - TRIM)
	elseif coords then
		local l, r, t, b = unpack(coords)
		local w, h = (r - l) * TRIM, (b - t) * TRIM
		icon.texture:SetTexture(CLASS_ICONS)
		icon.texture:SetTexCoord(l + w, r - w, t + h, b - h)
	else
		SetPortraitTexture(icon.texture, unit)
		icon.texture:SetTexCoord(TRIM, 1 - TRIM, TRIM, 1 - TRIM)
	end

	icon:Show()
	frame:SetContentInset(icon:GetWidth() + GAP)
end

local function onTalentsUpdated(frame, guid)
	if guid == UnitGUID(frame.unit) then
		update(frame)
	end
end

local function onPortraitUpdate(frame, unit)
	if unit == frame.unit then
		update(frame)
	end
end

local function create(frame, size)
	local icon = CreateFrame("Frame", nil, frame)
	icon:SetSize(size, size)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()

	frame:RegisterEvent(ns.TALENTS_UPDATED, onTalentsUpdated)
	frame:RegisterEvent("UNIT_PORTRAIT_UPDATE", onPortraitUpdate)

	return icon
end

UF:RegisterElement("classicon", create, update)
