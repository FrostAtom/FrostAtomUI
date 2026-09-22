local _, ns = ...
local UF = ns:GetModule("UnitFrames")

local UnitGUID = UnitGUID
local GameTooltip = GameTooltip
local GetTime = GetTime
local min, huge, random = math.min, math.huge, math.random

local SpellTexture = ns.SpellTexture

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

local function onIconResize(icon, size)
	ns.SetFont(icon.cooldown.timer, size * 0.38, "OUTLINE")
	icon.glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)
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

	icon.OnResize = onIconResize

	return icon
end

local refresh

local function onContainerUpdate(container, elapsed)
	container.untilCheck = container.untilCheck - elapsed
	if container.untilCheck > 0 then
		return
	end
	container.untilCheck = EXPIRY_CHECK_INTERVAL

	if container.nextExpiry <= GetTime() then
		refresh(container)
	end
end

function refresh(container)
	local unit = container.unit
	local guid = UnitGUID(unit)
	container.guid = guid

	local shown = 0
	local nextExpiry = huge
	local tracked = CooldownTracker:GetTracked(unit)
	for i = 1, tracked and #tracked or 0 do
		local id = tracked[i]
		local start, duration = CooldownTracker:GetCooldown(guid, id)
		local highlighted = CooldownTracker:IsHighlighted(guid, id)
		if (start or highlighted) and not container.skip[id] then
			shown = shown + 1
			local icon = container[shown]
			if not icon then
				icon = createIcon(container, shown)
				container[shown] = icon
			end

			icon.spellId = id
			icon.texture:SetTexture(SpellTexture(id))

			if start then
				if start ~= icon.start or duration ~= icon.duration then
					icon.start, icon.duration = start, duration
					icon.cooldown:SetCooldown(start, duration)
				end
				nextExpiry = min(nextExpiry, start + duration)
			elseif icon.start then
				icon.start = nil
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
	container:SetScript("OnUpdate", nextExpiry < huge and onContainerUpdate or nil)
end

local function update(frame)
	refresh(frame.cooldowns)
end

local function test(frame)
	local container = frame.cooldowns
	local spells = frame.test.class and ns.CooldownData.SPELLS[frame.test.class]
	local shown = 0
	local now = GetTime()
	for i = 1, spells and #spells or 0 do
		local id, cooldown = spells[i][1], spells[i][2]
		if random(3) == 1 and not container.skip[id] then
			shown = shown + 1
			local icon = container[shown]
			if not icon then
				icon = createIcon(container, shown)
				container[shown] = icon
			end
			icon.spellId = id
			icon.texture:SetTexture(SpellTexture(id))
			icon.start = nil
			icon.cooldown:SetCooldown(now - random(0, cooldown - 5), cooldown)
			if random(5) == 1 then
				icon.glow:Show()
			else
				icon.glow:Hide()
			end
			icon:Show()
		end
	end
	container:Layout(shown)
	container.nextExpiry = huge
	container:SetScript("OnUpdate", nil)
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
	container.unit = frame.unit
	container.skip = options.skip or {}
	container.untilCheck = 0
	container.nextExpiry = huge

	frame:RegisterEvent(ns.COOLDOWN_UPDATED, onCooldownUpdated)
	frame:RegisterEvent(ns.TALENTS_UPDATED, onCooldownUpdated)
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", update)

	return container
end

UF:RegisterElement("cooldowns", create, update, test)
