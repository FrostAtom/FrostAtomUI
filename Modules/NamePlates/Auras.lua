local _, ns = ...
local NamePlates = ns:GetModule("NamePlates")

-- Important debuffs on the target, as a row of icons above the target's
-- nameplate: crowd control from anyone (the losecontrol list) and a few of
-- the player's own. Plates have no unit, so only the target can be matched
-- reliably (its plate is the one the client keeps at full alpha).
--
-- No Cooldown frames here: they are models, and a model anchored to a frame
-- that moves every frame (a plate) is drawn a frame late at the wrong scale.
-- The remaining time is a text and a shrinking bar under the icon instead.

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local UnitExists = UnitExists
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo

local SetTimerText = ns:GetModule("CooldownTimer").SetTimerText
local ccSpellNames = ns:GetModule("UnitFrames").ccSpellNames

local ICON_SIZE = 20
local ICON_GAP = 2
local MAX_ICONS = 6
local MAX_AURAS = 40
local TIMER_FONT_SIZE = 10
local DURATION_BAR_HEIGHT = 2
local DURATION_BAR_COLOR = { 1, 0.85, 0.2 }

-- Shown only when applied by the player (matched by name, any rank).
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

	icon.timer = icon:CreateFontString(nil, "OVERLAY")
	icon.timer:SetFont(ns.Media.font, TIMER_FONT_SIZE, "OUTLINE")
	icon.timer:SetPoint("CENTER")

	-- Full width when applied, shrinks from the right as time runs out.
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
				-- Expired; UNIT_AURA will drop the icon shortly.
				icon.endTime = nil
				icon.timer:Hide()
				icon.bar:Hide()
			end
		end
	end
end

-- The target's plate can appear, vanish or change every frame.
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
