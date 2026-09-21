local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local UnitExists = UnitExists
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local max = math.max

local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText
local ccSpellNames = ns:GetModule("UnitFrames").ccSpellNames

local config = ns.Config.namePlates
local ICON_RATIO = 0.65
local ICON_GAP = 2
local MAX_ICONS = 6
local MAX_AURAS = 40
local DURATION_BAR_HEIGHT = 2

local OWN_SPELL_IDS = {
	47465, -- Rend
	47486, -- Mortal Strike
	1715, -- Hamstring
	12323, -- Piercing Howl
	47437, -- Demoralizing Shout
	47502, -- Thunder Clap
}
local ownSpellNames = {}
for i = 1, #OWN_SPELL_IDS do
	local name = GetSpellInfo(OWN_SPELL_IDS[i])
	if name then
		ownSpellNames[name] = true
	end
end

local row = CreateFrame("Frame", nil, WorldFrame)
row:Hide()
row:SetFrameStrata("LOW")

local icons = {}

local CROP_Y = (0.86 - 0.86 * ICON_RATIO) / 2
local TEXCOORD_TOP, TEXCOORD_BOTTOM = 0.07 + CROP_Y, 0.93 - CROP_Y

local function layoutIcon(icon, index)
	local size = config.auraSize
	icon:SetSize(size, size * ICON_RATIO)
	icon:ClearAllPoints()
	icon:SetPoint("LEFT", (index - 1) * (size + ICON_GAP), 0)
	icon.timer:SetFont(ns.Media.font, config.auraFont.size, config.auraFont.outline)
end

local function createIcon(index)
	local icon = CreateFrame("Frame", nil, row)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0.07, 0.93, TEXCOORD_TOP, TEXCOORD_BOTTOM)

	icon.border = icon:CreateTexture(nil, "BACKGROUND")
	icon.border:SetTexture(0, 0, 0)
	icon.border:SetPoint("TOPRIGHT", 1, 1)
	icon.border:SetPoint("BOTTOMLEFT", -1, -1)

	icon.timer = icon:CreateFontString(nil, "OVERLAY")
	icon.timer:SetPoint("CENTER")
	layoutIcon(icon, index)

	icon.bar = icon:CreateTexture(nil, "OVERLAY")
	icon.bar:SetTexture(1, 0.85, 0.2)
	icon.bar:SetHeight(DURATION_BAR_HEIGHT)
	icon.bar:SetPoint("BOTTOMLEFT")

	icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.count:SetPoint("BOTTOMRIGHT", 1, 0)

	icons[index] = icon
	return icon
end

local function updateAuras()
	if not UnitExists("target") or not config.showAuras then
		row:Hide()
		return
	end

	local shown = 0
	for i = 1, MAX_AURAS do
		local name, _, texture, count, _, duration, endTime, caster = UnitAura("target", i, "HARMFUL")
		if not name then
			break
		end

		if ccSpellNames[name] or (ownSpellNames[name] and caster == "player") then
			shown = shown + 1
			local icon = icons[shown] or createIcon(shown)
			icon.texture:SetTexture(texture)
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

	row:SetSize(max(shown * (config.auraSize + ICON_GAP) - ICON_GAP, 1), config.auraSize * ICON_RATIO)
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
				icon.bar:SetWidth(max(config.auraSize * remain / icon.duration, 0.1))
			else
				icon.endTime = nil
				icon.timer:Hide()
				icon.bar:Hide()
			end
		end
	end
end

CreateFrame("Frame"):SetScript("OnUpdate", function()
	local plate = row.hasAuras and NamePlates:GetTargetPlate()
	if plate and not plate.totem:IsShown() then
		row:ClearAllPoints()
		row:SetPoint("BOTTOM", plate.name, "TOP", 0, 4)
		row:SetAlpha(1)
		updateTimers()
	else
		row:SetAlpha(0)
	end
end)

NamePlates:RegisterEvent("UNIT_AURA", function(_, unit)
	if unit == "target" then
		updateAuras()
	end
end)
NamePlates:RegisterEvent("PLAYER_TARGET_CHANGED", updateAuras)
NamePlates:WatchConfig("namePlates", function()
	for i = 1, #icons do
		layoutIcon(icons[i], i)
	end
	updateAuras()
end)
