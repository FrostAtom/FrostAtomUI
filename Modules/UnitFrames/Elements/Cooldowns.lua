local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitGUID = UnitGUID
local GetSpellInfo = GetSpellInfo
local GameTooltip = GameTooltip
local GetTime = GetTime

local CooldownTracker = ns:GetModule("CooldownTracker")
local CooldownTimer = ns:GetModule("CooldownTimer")

local EXPIRY_CHECK_INTERVAL = 0.5
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 1.75
local GLOW_COLOR = { 1, 0.85, 0.3 }

local function onIconEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetHyperlink("spell:" .. icon.spellId)
end

local function onIconLeave()
	GameTooltip:Hide()
end

local function createIcon(container, index)
	local icon = CreateFrame("Frame", nil, container)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:SetSize(container.size, container.size)
	icon:SetPoint(UF.GridIconPoint(container, index))
	icon:EnableMouse(true)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	UF.SkinIcon(icon, icon.texture)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetAlpha(0)
	CooldownTimer:Attach(icon.cooldown, container.size * 0.38, icon)
	icon.cooldown.timer:ClearAllPoints()
	icon.cooldown.timer:SetPoint("BOTTOM", 0, 1)

	icon.glow = icon:CreateTexture(nil, "OVERLAY")
	icon.glow:SetPoint("CENTER")
	icon.glow:SetSize(container.size * GLOW_SCALE, container.size * GLOW_SCALE)
	icon.glow:SetTexture(GLOW_TEXTURE)
	icon.glow:SetBlendMode("ADD")
	icon.glow:SetVertexColor(unpack(GLOW_COLOR))
	icon.glow:Hide()

	return icon
end

local function onContainerUpdate(container, elapsed)
	container.untilCheck = container.untilCheck - elapsed
	if container.untilCheck > 0 then
		return
	end
	container.untilCheck = EXPIRY_CHECK_INTERVAL

	if container.nextExpiry <= GetTime() then
		container:Refresh()
	end
end

local function refresh(container)
	local frame = container:GetParent()
	container.guid = UnitGUID(frame.unit)

	local shown = 0
	local nextExpiry = math.huge
	for _, id in ipairs(CooldownTracker:GetTracked(frame.unit) or {}) do
		local start, duration = CooldownTracker:GetCooldown(container.guid, id)
		local highlighted = CooldownTracker:IsHighlighted(container.guid, id)
		if (start or highlighted) and not container.skip[id] then
			shown = shown + 1
			local icon = container[shown]
			if not icon then
				icon = createIcon(container, shown)
				container[shown] = icon
			end

			icon.spellId = id
			icon.texture:SetTexture((select(3, GetSpellInfo(id))))

			if start then
				icon.cooldown:SetCooldown(start, duration)
				nextExpiry = math.min(nextExpiry, start + duration)
			else
				icon.cooldown:SetCooldown(0, 0)
			end
			if highlighted then
				icon.glow:Show()
			else
				icon.glow:Hide()
			end
			icon:Show()
		end
	end

	container:Layout(shown)

	container.nextExpiry = nextExpiry
	container:SetScript("OnUpdate", nextExpiry < math.huge and onContainerUpdate or nil)
end

local function update(frame)
	refresh(frame.cooldowns)
end

local function onCooldownUpdated(frame, guid)
	local container = frame.cooldowns
	if frame:IsShown() and (guid == nil or guid == container.guid or container.guid == nil) then
		refresh(container)
	end
end

local function create(frame, options)
	options = options or {}

	local container = UF:CreateIconGrid(frame, options)
	container.skip = options.skip or {}
	container.untilCheck = 0
	container.nextExpiry = math.huge
	container.Refresh = refresh

	frame:RegisterEvent(ns.COOLDOWN_UPDATED, onCooldownUpdated)
	frame:RegisterEvent(ns.TALENTS_UPDATED, onCooldownUpdated)
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", update)

	return container
end

UF:RegisterElement("cooldowns", create, update)
