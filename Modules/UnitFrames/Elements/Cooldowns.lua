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

local function onIconEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetHyperlink("spell:" .. icon.spellId)
end

local function onIconLeave()
	GameTooltip:Hide()
end

local function createIcon(container, index)
	local icon = CreateFrame("Frame", nil, container)
	icon:SetSize(container.size, container.size)
	icon:SetPoint(ns.GridPoint(container.anchor, index, container.perRow, container.size + container.gap))
	icon:EnableMouse(true)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	CooldownTimer:Attach(icon.cooldown, container.size * 0.4)

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
		if not container.skip[id] then
			shown = shown + 1
			local icon = container[shown]
			if not icon then
				icon = createIcon(container, shown)
				container[shown] = icon
			end

			icon.spellId = id
			icon.texture:SetTexture((select(3, GetSpellInfo(id))))

			local start, duration = CooldownTracker:GetCooldown(container.guid, id)
			if start then
				icon.texture:SetDesaturated(true)
				icon.cooldown:SetCooldown(start, duration)
				nextExpiry = math.min(nextExpiry, start + duration)
			else
				icon.texture:SetDesaturated(false)
				icon.cooldown:SetCooldown(0, 0)
			end
			icon:Show()
		end
	end

	for i = shown + 1, #container do
		container[i]:Hide()
	end

	local rows = math.ceil(shown / container.perRow)
	container:SetHeight(math.max(rows * (container.size + container.gap), 2))

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

	local container = CreateFrame("Frame", nil, frame)
	container:SetFrameLevel(frame:GetFrameLevel())
	container:SetSize(2, 2)
	container.size = options.size or 24
	container.gap = options.gap or 2
	container.perRow = options.perRow or 8
	container.anchor = options.anchor or "TOPLEFT"
	container.skip = options.skip or {}
	container.untilCheck = 0
	container.nextExpiry = math.huge
	container.Refresh = refresh

	frame:RegisterEvent(ns.COOLDOWN_UPDATED, onCooldownUpdated)
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", update)

	return container
end

UF:RegisterElement("cooldowns", create, update)
