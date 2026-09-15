local _, ns = ...
local UF = ns:GetModule("UnitFrames")

-- "buffs" and "debuffs" elements: a grid of aura icons growing from an anchor.
--
-- Options (table passed to AddElement):
--   size    icon size (default 22)
--   gap     space between icons (default 0)
--   perRow  icons per row (default 8)
--   anchor  corner the grid grows from (default "TOPLEFT")
--   max     maximum number of auras shown (default: all)

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local CancelUnitBuff = CancelUnitBuff
local GameTooltip = GameTooltip
local unpack = unpack
local ceil = math.ceil

local MAX_AURAS = 40

local debuffColors = {}
for debuffType, color in pairs(DebuffTypeColor) do
	debuffColors[debuffType] = { color.r, color.g, color.b }
end

--------------------------------------------------
-- Icon

local function onIconUpdate(icon)
	GameTooltip:SetUnitAura(icon:GetParent():GetParent().unit, icon:GetID(), icon.filter)
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
	local frame = container:GetParent()

	local icon = CreateFrame("Button", nil, container)
	icon:SetFrameLevel(container:GetFrameLevel())
	icon:SetSize(container.size, container.size)
	icon:SetPoint(ns.GridPoint(container.anchor, index, container.perRow, container.size + container.gap))
	icon:SetID(index)
	icon.filter = container.filter
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)
	icon.cooldown:SetDrawEdge(true)
	icon.cooldown:SetFrameLevel(icon:GetFrameLevel())

	icon.texture = icon:CreateTexture(nil, "BACKGROUND")
	icon.texture:SetAllPoints()

	icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	icon.count:SetPoint("BOTTOMRIGHT", icon, -1, 0)

	-- Right click cancels own buffs.
	if frame.unit == "player" then
		icon:RegisterForClicks("RightButtonDown")
		icon:SetScript("OnClick", onIconClick)
	else
		icon:RegisterForClicks()
	end

	if container.isDebuff then
		icon.overlay = icon:CreateTexture(nil, "OVERLAY")
		icon.overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		icon.overlay:SetAllPoints()
		icon.overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
	end

	return icon
end

local function setIcon(icon, texture, count, debuffType, duration, endTime)
	icon.texture:SetTexture(texture)

	if icon.overlay then
		icon.overlay:SetVertexColor(unpack(debuffColors[debuffType or ""]))
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

--------------------------------------------------
-- Container

local function updateContainer(container)
	local unit = container:GetParent().unit
	local filter = container.filter
	local limit = math.min(container.max or MAX_AURAS, MAX_AURAS)

	local shown = 0
	for i = 1, limit do
		local name, _, texture, count, debuffType, duration, endTime = UnitAura(unit, i, filter)
		if not name then
			break
		end

		local icon = container[i]
		if not icon then
			icon = createIcon(container, i)
			container[i] = icon
		end
		setIcon(icon, texture, count, debuffType, duration, endTime)
		shown = i
	end

	for i = shown + 1, #container do
		container[i]:Hide()
	end

	-- Keep the container's height in sync so other elements can anchor below it.
	local rows = ceil(shown / container.perRow)
	container:SetHeight(math.max(rows * (container.size + container.gap), 2))
end

local function createContainer(frame, options, filter, isDebuff)
	options = options or {}

	local container = CreateFrame("Frame", nil, frame)
	container:SetFrameLevel(frame:GetFrameLevel())
	container:SetSize(2, 2)
	container.filter = filter
	container.isDebuff = isDebuff
	container.size = options.size or 22
	container.gap = options.gap or 0
	container.perRow = options.perRow or 8
	container.anchor = options.anchor or "TOPLEFT"
	container.max = options.max

	return container
end

--------------------------------------------------

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
