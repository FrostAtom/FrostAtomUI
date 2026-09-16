local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local UnitExists = UnitExists
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo

local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText
local ccSpellNames = ns:GetModule("UnitFrames").ccSpellNames

local ICON_SIZE = 20
local ICON_HEIGHT = 13
local ICON_GAP = 2
local MAX_ICONS = 6
local MAX_AURAS = 40
local TIMER_FONT_SIZE = 10
local DURATION_BAR_HEIGHT = 2
local DURATION_BAR_COLOR = { 1, 0.85, 0.2 }

-- Rend, Mortal Strike, Hamstring, Piercing Howl, Demoralizing Shout, Thunder Clap
local OWN_SPELL_IDS = { 47465, 47486, 1715, 12323, 47437, 47502 }
local ownSpellNames = {}
for _, spellId in ipairs(OWN_SPELL_IDS) do
	local name = GetSpellInfo(spellId)
	if name then
		ownSpellNames[name] = true
	end
end

local function isWanted(name, caster)
	return ccSpellNames[name] or (ownSpellNames[name] and caster == "player")
end

local row = CreateFrame("Frame", nil, WorldFrame)
row:Hide()
row:SetSize(MAX_ICONS * (ICON_SIZE + ICON_GAP), ICON_HEIGHT)
row:SetFrameStrata("LOW")

local icons = {}

local CROP_Y = (0.86 - 0.86 * ICON_HEIGHT / ICON_SIZE) / 2
local TEXCOORD_TOP, TEXCOORD_BOTTOM = 0.07 + CROP_Y, 0.93 - CROP_Y

local function createIcon(index)
	local icon = CreateFrame("Frame", nil, row)
	icon:SetSize(ICON_SIZE, ICON_HEIGHT)
	icon:SetPoint("LEFT", (index - 1) * (ICON_SIZE + ICON_GAP), 0)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()

	icon.border = icon:CreateTexture(nil, "BACKGROUND")
	icon.border:SetTexture(0, 0, 0)
	icon.border:SetPoint("TOPRIGHT", 1, 1)
	icon.border:SetPoint("BOTTOMLEFT", -1, -1)

	icon.timer = icon:CreateFontString(nil, "OVERLAY")
	icon.timer:SetFont(ns.Media.font, TIMER_FONT_SIZE, "OUTLINE")
	icon.timer:SetPoint("CENTER")

	icon.bar = icon:CreateTexture(nil, "OVERLAY")
	icon.bar:SetTexture(unpack(DURATION_BAR_COLOR))
	icon.bar:SetHeight(DURATION_BAR_HEIGHT)
	icon.bar:SetPoint("BOTTOMLEFT")

	icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.count:SetPoint("BOTTOMRIGHT", 1, 0)

	icons[index] = icon
	return icon
end

local function updateAuras()
	if not UnitExists("target") then
		row:Hide()
		return
	end

	local shown = 0
	for i = 1, MAX_AURAS do
		local name, _, texture, count, _, duration, endTime, caster = UnitAura("target", i, "HARMFUL")
		if not name then
			break
		end

		if isWanted(name, caster) then
			shown = shown + 1
			local icon = icons[shown] or createIcon(shown)
			icon.texture:SetTexture(texture)
			icon.texture:SetTexCoord(0.07, 0.93, TEXCOORD_TOP, TEXCOORD_BOTTOM)
			if duration and duration > 0 then
				icon.duration, icon.endTime = duration, endTime
				icon.timer:Show()
				icon.bar:Show()
			else
				icon.endTime = nil
				icon.timer:Hide()
				icon.bar:Hide()
			end
			icon.count:SetText(count > 1 and count or "")
			icon:Show()

			if shown == MAX_ICONS then
				break
			end
		end
	end

	for i = shown + 1, #icons do
		icons[i]:Hide()
	end

	row:SetWidth(math.max(shown * (ICON_SIZE + ICON_GAP) - ICON_GAP, 1))
	row.hasAuras = shown > 0
	row:Show()
end

local function updateTimers()
	local now = GetTime()
	for i = 1, #icons do
		local icon = icons[i]
		if icon.endTime and icon:IsShown() then
			local remain = icon.endTime - now
			if remain > 0 then
				SetTimerText(icon.timer, remain)
				icon.bar:SetWidth(math.max(ICON_SIZE * remain / icon.duration, 0.1))
			else
				icon.endTime = nil
				icon.timer:Hide()
				icon.bar:Hide()
			end
		end
	end
end

local function onUpdate()
	local plate = row.hasAuras and NamePlates:GetTargetPlate()
	if plate and not plate.totem:IsShown() then
		row:ClearAllPoints()
		row:SetPoint("BOTTOM", plate.name, "TOP", 0, 4)
		row:SetAlpha(1)
		updateTimers()
	else
		row:SetAlpha(0)
	end
end

local anchorUpdater = CreateFrame("Frame")
anchorUpdater:SetScript("OnUpdate", onUpdate)

function NamePlates:UNIT_AURA(unit)
	if unit == "target" then
		updateAuras()
	end
end

NamePlates:RegisterEvent("UNIT_AURA")
NamePlates:RegisterEvent("PLAYER_TARGET_CHANGED", updateAuras)
