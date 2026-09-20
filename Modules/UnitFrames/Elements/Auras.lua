local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local CancelUnitBuff = CancelUnitBuff
local GameTooltip = GameTooltip
local min = math.min

local MAX_AURAS = 40

local debuffColors = UF.debuffColors
local NO_TYPE_COLOR = debuffColors[""]
local STEALABLE_COLOR = debuffColors.Magic

local PURGE_CLASSES = { PRIEST = true, SHAMAN = true, MAGE = true, HUNTER = true, WARLOCK = true }
local canPurge = PURGE_CLASSES[ns.PLAYER_CLASS]

local function onIconUpdate(icon)
	GameTooltip:SetUnitAura(icon.unit, icon:GetID(), icon.filter)
end

local function onIconEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	icon:SetScript("OnUpdate", onIconUpdate)
end

local function onIconLeave(icon)
	icon:SetScript("OnUpdate", nil)
	GameTooltip:Hide()
end

local function onIconClick(icon)
	CancelUnitBuff("player", icon:GetID(), icon.filter)
end

local function createIcon(container, index)
	local icon = CreateFrame("Button", nil, container)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:SetSize(container.size, container.size)
	icon:SetPoint(UF.GridIconPoint(container, index))
	icon:SetID(index)
	icon.unit = container.unit
	icon.filter = container.filter
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)
	icon.cooldown:SetDrawEdge(true)
	icon.cooldown:SetFrameLevel(icon:GetFrameLevel())

	icon.texture = icon:CreateTexture(nil, "BACKGROUND")
	UF.SkinIcon(icon, icon.texture)

	icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	icon.count:SetPoint("BOTTOMRIGHT", icon, -1, 0)

	if container.unit == "player" then
		icon:RegisterForClicks("RightButtonDown")
		icon:SetScript("OnClick", onIconClick)
	else
		icon:RegisterForClicks()
	end

	if container.isDebuff or canPurge then
		icon.overlay = icon:CreateTexture(nil, "OVERLAY")
		icon.overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		icon.overlay:SetAllPoints()
		icon.overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		icon.isDebuff = container.isDebuff
	end

	return icon
end

local function setIcon(icon, texture, count, debuffType, duration, endTime, stealable)
	icon.texture:SetTexture(texture)

	local overlay = icon.overlay
	if overlay then
		if icon.isDebuff then
			local color = debuffType and debuffColors[debuffType] or NO_TYPE_COLOR
			overlay:SetVertexColor(color[1], color[2], color[3])
		elseif stealable then
			overlay:SetVertexColor(STEALABLE_COLOR[1], STEALABLE_COLOR[2], STEALABLE_COLOR[3])
			overlay:Show()
		else
			overlay:Hide()
		end
	end

	if duration and duration > 0 then
		icon.cooldown:SetCooldown(endTime - duration, duration)
	else
		icon.cooldown:Hide()
	end

	if count and count > 1 then
		icon.count:SetText(count)
		icon.count:Show()
	else
		icon.count:Hide()
	end

	icon:Show()
end

local function updateContainer(container)
	local unit, filter = container.unit, container.filter

	local shown = 0
	for i = 1, container.limit do
		local name, _, texture, count, debuffType, duration, endTime, _, stealable = UnitAura(unit, i, filter)
		if not name then
			break
		end

		local icon = container[i]
		if not icon then
			icon = createIcon(container, i)
			container[i] = icon
		end
		setIcon(icon, texture, count, debuffType, duration, endTime, stealable)
		shown = i
	end

	container:Layout(shown)
end

local function createContainer(frame, options, filter, isDebuff)
	local container = UF:CreateIconGrid(frame, options)
	container.unit = frame.unit
	container.filter = filter
	container.isDebuff = isDebuff
	container.limit = min(container.max or MAX_AURAS, MAX_AURAS)
	return container
end

local function updateBuffs(frame)
	updateContainer(frame.buffs)
end

local function createBuffs(frame, options)
	frame:RegisterUnitEvent("UNIT_AURA", updateBuffs)
	return createContainer(frame, options, "HELPFUL", false)
end

UF:RegisterElement("buffs", createBuffs, updateBuffs)

local function updateDebuffs(frame)
	updateContainer(frame.debuffs)
end

local function createDebuffs(frame, options)
	frame:RegisterUnitEvent("UNIT_AURA", updateDebuffs)
	return createContainer(frame, options, "HARMFUL", true)
end

UF:RegisterElement("debuffs", createDebuffs, updateDebuffs)
