local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

local UnitExists = UnitExists
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local max = math.max

local Auras = ns.Auras
local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText
local ccSpellNames = ns:GetModule("UnitFrames").ccSpellNames

local config = ns.Config.namePlates
local ICON_RATIO = 0.65
local ICON_GAP = 2
local ROW_GAP = 3
local MAX_ICONS = 6
local DURATION_BAR_HEIGHT = 2
local TIMER_INTERVAL = 0.1

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
row.nextTick = 0

local icons = {}

local CROP_Y = (1 - ICON_RATIO) / 2

local function layoutIcon(icon, index)
	local size = config.auraSize
	icon:SetSize(size, size * ICON_RATIO)
	icon:ClearAllPoints()
	icon:SetPoint("LEFT", (index - 1) * (size + ICON_GAP), 0)
	ns.SetFont(icon.timer, config.auraFont.size, config.auraFont.outline)
	ns.SetFont(icon.count, config.auraFont.size, config.auraFont.outline)
end

local function createIcon(index)
	local icon = CreateFrame("Frame", nil, row)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0, 1, CROP_Y, 1 - CROP_Y)
	NamePlates.SkinIcon(icon, icon.texture)

	icon.timer = icon:CreateFontString(nil, "OVERLAY")
	icon.timer:SetPoint("CENTER")

	icon.bar = icon:CreateTexture(nil, "OVERLAY")
	icon.bar:SetTexture(unpack(ns.Config.unitFrames.castbarColor))
	icon.bar:SetHeight(DURATION_BAR_HEIGHT)
	icon.bar:SetPoint("BOTTOMLEFT", 1, 1)

	icon.count = icon:CreateFontString(nil, "OVERLAY")
	icon.count:SetPoint("BOTTOMRIGHT", -1, 1)
	layoutIcon(icon, index)

	icons[index] = icon
	return icon
end

local shownCount = 0

local function updateAuras()
	shownCount = 0
	if not UnitExists("target") or not config.showAuras then
		row:Hide()
		return
	end

	local auras, count = Auras.Get("target", "HARMFUL")
	local shown = 0
	for i = 1, count do
		local aura = auras[i]
		local name = aura.name
		if ccSpellNames[name] or (ownSpellNames[name] and aura.caster == "player") then
			shown = shown + 1
			local icon = icons[shown] or createIcon(shown)
			icon.texture:SetTexture(aura.icon)
			local duration = aura.duration
			if duration and duration > 0 then
				icon.duration, icon.endTime = duration, aura.expires
				icon.timer:Show()
				icon.bar:Show()
			else
				icon.endTime = nil
				icon.timer:Hide()
				icon.bar:Hide()
			end
			if aura.count > 1 then
				icon.count:SetFormattedText("%d", aura.count)
			else
				icon.count:SetText("")
			end
			icon:Show()

			if shown == MAX_ICONS then
				break
			end
		end
	end

	for i = shown + 1, #icons do
		icons[i]:Hide()
	end

	shownCount = shown
	if shown == 0 then
		row:Hide()
		return
	end
	row:SetSize(shown * (config.auraSize + ICON_GAP) - ICON_GAP, config.auraSize * ICON_RATIO)
	row.nextTick = 0
end

local function updateTimers(now)
	for i = 1, shownCount do
		local icon = icons[i]
		if icon.endTime then
			local remain = icon.endTime - now
			if remain > 0 then
				SetTimerText(icon.timer, remain)
				icon.bar:SetWidth(max((config.auraSize - 2) * remain / icon.duration, 0.1))
			else
				icon.endTime = nil
				icon.timer:Hide()
				icon.bar:Hide()
			end
		end
	end
end

local anchoredPlate

local function anchorRow(plate)
	if plate ~= anchoredPlate then
		anchoredPlate = plate
		row:SetPoint("BOTTOM", plate.holder, "TOP", 0, ROW_GAP)
	end
	row:Show()
end

CreateFrame("Frame"):SetScript("OnUpdate", function()
	if shownCount == 0 then
		return
	end

	local plate = anchoredPlate
	if not (plate and plate:IsShown() and plate:IsTarget()) then
		plate = NamePlates:GetTargetPlate()
	end
	if plate and not plate.totem:IsShown() then
		anchorRow(plate)
		local now = GetTime()
		if now >= row.nextTick then
			row.nextTick = now + TIMER_INTERVAL
			updateTimers(now)
		end
	else
		row:Hide()
	end
end)

NamePlates:RegisterUnitEvent("UNIT_AURA", "target", updateAuras)
NamePlates:RegisterEvent("PLAYER_TARGET_CHANGED", updateAuras)
NamePlates:WatchConfig("namePlates", function()
	for i = 1, #icons do
		layoutIcon(icons[i], i)
	end
	updateAuras()
end)
