local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

-- The player's own debuffs on the target, as a row of icons above the
-- target's nameplate. Plates have no unit, so only the target can be matched
-- reliably (its plate is the one the client keeps at full alpha).

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local UnitExists = UnitExists

local CooldownTimer = ns:GetModule("CooldownTimer")

local ICON_SIZE = 20
local ICON_GAP = 2
local MAX_ICONS = 6
local FILTER = "HARMFUL|PLAYER"

local row = CreateFrame("Frame", nil, WorldFrame)
row:Hide()
row:SetSize(MAX_ICONS * (ICON_SIZE + ICON_GAP), ICON_SIZE)
row:SetFrameStrata("LOW") -- plates live in BACKGROUND

local icons = {}

local function createIcon(index)
	local icon = CreateFrame("Frame", nil, row)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("LEFT", (index - 1) * (ICON_SIZE + ICON_GAP), 0)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	icon.border = icon:CreateTexture(nil, "BACKGROUND")
	icon.border:SetTexture(0, 0, 0)
	icon.border:SetPoint("TOPRIGHT", 1, 1)
	icon.border:SetPoint("BOTTOMLEFT", -1, -1)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)
	CooldownTimer:Attach(icon.cooldown, 10)

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
	for i = 1, 40 do
		local name, _, texture, count, _, duration, endTime = UnitAura("target", i, FILTER)
		if not name then
			break
		end

		shown = shown + 1
		local icon = icons[shown] or createIcon(shown)
		icon.texture:SetTexture(texture)
		if duration and duration > 0 then
			icon.cooldown:SetCooldown(endTime - duration, duration)
			icon.cooldown:Show()
		else
			icon.cooldown:Hide()
		end
		icon.count:SetText(count > 1 and count or "")
		icon:Show()

		if shown == MAX_ICONS then
			break
		end
	end

	for i = shown + 1, #icons do
		icons[i]:Hide()
	end

	row:SetWidth(math.max(shown * (ICON_SIZE + ICON_GAP) - ICON_GAP, 1))
	row.hasAuras = shown > 0
	row:Show()
end

-- The target's plate can appear, vanish or change every frame.
local function onUpdate()
	local plate = row.hasAuras and NamePlates:GetTargetPlate()
	if plate and not plate.totem:IsShown() then
		row:ClearAllPoints()
		row:SetPoint("BOTTOM", plate.name, "TOP", 0, 4)
		row:SetAlpha(1)
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
