local _, ns = ...

local min = math.min

local Colors = { class = {}, classBar = {}, classList = {}, power = {}, debuff = {} }
ns.Colors = Colors

local function setColor(target, r, g, b)
	target[1], target[2], target[3] = r, g, b
	return target
end

local function buildClassColors()
	local custom = type(CUSTOM_CLASS_COLORS) == "table" and CUSTOM_CLASS_COLORS
	for class, color in pairs(RAID_CLASS_COLORS) do
		local own = custom and custom[class]
		local text = Colors.class[class] or {}
		local bar = Colors.classBar[class] or {}
		if own then
			Colors.class[class] = setColor(text, own.r, own.g, own.b)
			Colors.classBar[class] = setColor(bar, own.r * 0.75, own.g * 0.75, own.b * 0.75)
		else
			Colors.class[class] = setColor(text, min(color.r * 1.25, 1), min(color.g * 1.25, 1), min(color.b * 1.25, 1))
			Colors.classBar[class] = setColor(bar, color.r * 0.75, color.g * 0.75, color.b * 0.75)
		end
	end
end

buildClassColors()
for class in pairs(RAID_CLASS_COLORS) do
	Colors.classList[#Colors.classList + 1] = class
end
table.sort(Colors.classList)
if type(CUSTOM_CLASS_COLORS) == "table" and type(CUSTOM_CLASS_COLORS.RegisterCallback) == "function" then
	CUSTOM_CLASS_COLORS:RegisterCallback(buildClassColors)
end

function ns.ClassColor(class)
	local color = class and Colors.class[class]
	if color then
		return color[1], color[2], color[3]
	end
	return 1, 1, 1
end

function ns.ClassColorText(class, text)
	local color = class and Colors.class[class]
	if not color then
		return text
	end
	return ("|cff%02x%02x%02x%s|r"):format(color[1] * 255, color[2] * 255, color[3] * 255, text)
end

for powerType = 0, #PowerBarColor do
	local color = PowerBarColor[powerType]
	Colors.power[powerType] = { color.r * 0.66, color.g * 0.66, color.b * 0.66 }
end

for debuffType, color in pairs(DebuffTypeColor) do
	Colors.debuff[debuffType] = { color.r, color.g, color.b }
end

local UIKit = {}
ns.UIKit = UIKit
UIKit.BORDER_INSET = 4
UIKit.backdrop = ns.CreateBackdrop(14, 3)

function UIKit.SkinIcon(icon, texture)
	texture:SetAllPoints()
	icon.border = icon:CreateTexture(nil, "ARTWORK")
	icon.border:SetTexture(ns.Media.buttonNormal)
	icon.border:SetAllPoints()
end

function UIKit.SetBackdropColors(frame)
	local config = ns.Config.theme
	frame:SetBackdropColor(unpack(config.backdropColor))
	frame:SetBackdropBorderColor(unpack(config.borderColor))
end

function UIKit.TextColor()
	return ns.Config.theme.textColor
end

function UIKit.CenterRow(parent, buttons, gap, y)
	local width, previous = -gap, nil
	for _, button in ipairs(buttons) do
		if button:IsShown() then
			width = width + button:GetWidth() + gap
		end
	end
	for _, button in ipairs(buttons) do
		if button:IsShown() then
			button:ClearAllPoints()
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
			else
				button:SetPoint("BOTTOMLEFT", parent, "BOTTOM", -width / 2, y)
			end
			previous = button
		end
	end
end

local DISPEL_TYPES = {
	PRIEST = { Magic = true, Disease = true },
	PALADIN = { Magic = true, Poison = true, Disease = true },
	SHAMAN = { Poison = true, Disease = true, Curse = true },
	DRUID = { Curse = true, Poison = true },
	MAGE = { Curse = true },
	WARLOCK = { Magic = true },
}
ns.PlayerDispel = DISPEL_TYPES[ns.PLAYER_CLASS]

local FrameBridge = { waiters = {} }
ns.FrameBridge = FrameBridge

function FrameBridge.OnReady(callback)
	if FrameBridge.ready then
		callback()
	else
		FrameBridge.waiters[#FrameBridge.waiters + 1] = callback
	end
end

function FrameBridge.SetReady()
	FrameBridge.ready = true
	for i = 1, #FrameBridge.waiters do
		ns.SafeCall(FrameBridge.waiters[i])
	end
	wipe(FrameBridge.waiters)
end

function FrameBridge.HasWeaponEnchantAuras()
	return false
end

function FrameBridge.SetWeaponEnchants() end

local ClassIcons = {}
ns.ClassIcons = ClassIcons

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
	PRIEST = { "Spell_Holy_WordFortitude", "Spell_Holy_GuardianSpirit", "Spell_Shadow_ShadowWordPain" },
	ROGUE = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
	SHAMAN = { "Spell_Nature_Lightning", "Spell_Nature_LightningShield", "Spell_Nature_MagicImmunity" },
	WARLOCK = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
	WARRIOR = { "Ability_Warrior_SavageBlow", "Ability_Warrior_InnerRage", "Ability_Warrior_DefensiveStance" },
}
for _, icons in pairs(SPEC_ICONS) do
	for i = 1, #icons do
		icons[i] = "Interface\\Icons\\" .. icons[i]
	end
end

local CLASS_TRIM = 0.1
local SPELL_TRIM = 0.08
local BADGE_SIZE = 0.45

local function trimCoords(trim)
	local result = {}
	for class, coords in pairs(CLASS_ICON_TCOORDS) do
		local l, r, t, b = unpack(coords)
		local w, h = (r - l) * trim, (b - t) * trim
		result[class] = { l + w, r - w, t + h, b - h }
	end
	return result
end

local classCoords = trimCoords(TRIM)
local innerClassCoords = trimCoords(CLASS_TRIM)

ClassIcons.TEXTURE = CLASS_ICONS
ClassIcons.TRIM = TRIM
ClassIcons.SPELL_TRIM = SPELL_TRIM
ClassIcons.coords = classCoords
ClassIcons.specIcons = SPEC_ICONS

local function specIconFor(class, spec)
	local icons = class and spec and SPEC_ICONS[class]
	return icons and icons[spec]
end

function ClassIcons.SetClassTexture(texture, class, spec)
	local coords = class and innerClassCoords[class]
	if not coords then
		return false
	end
	local specIcon = specIconFor(class, spec)
	if specIcon then
		texture:SetTexture(specIcon)
		texture:SetTexCoord(SPELL_TRIM, 1 - SPELL_TRIM, SPELL_TRIM, 1 - SPELL_TRIM)
	else
		texture:SetTexture(CLASS_ICONS)
		texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	end
	return true
end

function ClassIcons.SetSpecBadge(icon, class, spec)
	local specIcon = specIconFor(class, spec)
	local badge = icon.badge
	if not specIcon then
		if badge then
			badge:Hide()
		end
		return
	end
	if not badge then
		badge = CreateFrame("Frame", nil, icon)
		badge:SetFrameLevel(icon:GetFrameLevel() + 2)
		badge:SetPoint("BOTTOMRIGHT")
		badge.texture = badge:CreateTexture(nil, "BORDER")
		UIKit.SkinIcon(badge, badge.texture)
		badge.texture:SetTexCoord(TRIM, 1 - TRIM, TRIM, 1 - TRIM)
		icon.badge = badge
	end
	local size = icon:GetWidth() * BADGE_SIZE
	badge:SetSize(size, size)
	badge.texture:SetTexture(specIcon)
	badge:Show()
end
