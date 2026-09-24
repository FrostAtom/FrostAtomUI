local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitCanAttack = UnitCanAttack
local GameTooltip = GameTooltip
local GetTime = GetTime
local min, huge, random = math.min, math.huge, math.random
local unpack = unpack

local ICD = ns:GetModule("InternalCooldowns")
local CooldownTimer = ns:GetModule("CooldownTimer")

local CHECK_INTERVAL = 0.5
local FONT_SCALE = 0.45
local FRAME_LEVEL_OFFSET = 4
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 1.75
local TEST_AURA_DURATION = 15
local UNKNOWN = ICD.UNKNOWN

local containers = {}

local function setIconSize(icon, size)
	icon:SetSize(size, size)
	ns.SetFont(icon.cooldown.timer, size * FONT_SCALE, "OUTLINE")
	icon.glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)
end

local function placeIcon(container, icon, index)
	icon:ClearAllPoints()
	icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -(index - 1) * (container.size + container.spacing), 0)
end

local function onIconEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	local source = ICD:GetSource(icon.key)
	if not source then
		GameTooltip:SetText(L["Unknown trinket"], 1, 1, 1)
		GameTooltip:AddLine(L["Shown once the trinket procs."], nil, nil, nil, true)
		GameTooltip:Show()
		return
	end
	GameTooltip:SetHyperlink(source.kind == "i" and "item:" .. source.id or "spell:" .. source.spell)
	GameTooltip:AddLine(L["Internal cooldown: %d sec"]:format(source.cd), 1, 0.82, 0)
	GameTooltip:Show()
end

local function onIconLeave()
	GameTooltip:Hide()
end

local function createIcon(container, index)
	local icon = CreateFrame("Frame", nil, container)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:EnableMouse(true)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetNonBlocking(true)
	UF.SkinIcon(icon, icon.texture)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	CooldownTimer:Attach(icon.cooldown, container.size * FONT_SCALE, icon)
	CooldownTimer:AttachFlash(icon.cooldown, icon.texture, ns.Config.unitFrames, "cooldownReadyFlash")

	icon.glow = icon:CreateTexture(nil, "OVERLAY")
	icon.glow:SetPoint("CENTER")
	icon.glow:SetTexture(GLOW_TEXTURE)
	icon.glow:SetBlendMode("ADD")
	icon.glow:Hide()

	setIconSize(icon, container.size)
	placeIcon(container, icon, index)
	container[index] = icon
	return icon
end

local function setIcon(container, index, key)
	local icon = container[index] or createIcon(container, index)
	if icon.key ~= key then
		icon.key = key
		icon.texture:SetTexture(ICD:GetTexture(key))
	end
	icon:Show()
	return icon
end

local function setIconActive(icon, active)
	if active == icon.active then
		return
	end
	icon.active = active
	icon.cooldown:SetReverse(active)
	if active then
		local r, g, b = unpack(ns.Config.internalCooldowns.activeColor)
		icon.border:SetVertexColor(r, g, b)
		icon.glow:SetVertexColor(r, g, b)
		icon.glow:Show()
	else
		icon.border:SetVertexColor(1, 1, 1)
		icon.glow:Hide()
	end
end

local function setIconCooldown(icon, start, duration, active)
	active = active or false
	if start ~= icon.start or duration ~= icon.duration or active ~= icon.active then
		icon.start, icon.duration = start, duration
		setIconActive(icon, active)
		icon.cooldown:SetCooldown(start or 0, start and duration or 0)
		if active then
			icon.cooldown.flashArmed = false
		end
	end
end

local function hideFrom(container, shown)
	for i = shown + 1, #container do
		container[i]:Hide()
	end
end

local refresh

local function onContainerUpdate(container, elapsed)
	container.untilCheck = container.untilCheck - elapsed
	if container.untilCheck > 0 then
		return
	end
	container.untilCheck = CHECK_INTERVAL
	if container.nextExpiry <= GetTime() then
		refresh(container)
	end
end

local function isHostile(container, unit)
	return container.kind == "arena" or UnitCanAttack("player", unit)
end

function refresh(container)
	local unit = container.unit
	local guid = UnitGUID(unit)
	container.guid = guid

	local shown = 0
	local nextExpiry = huge
	if container.enabled and guid and (container.kind == "arena" or UnitIsPlayer(unit)) then
		local config = ns.Config.internalCooldowns
		local hideReady = config.hideReady
		local unknown = config.unknownTrinkets and not hideReady and isHostile(container, unit)
		local keys = ICD:Collect(guid, container.keys, unknown)
		for i = 1, #keys do
			local key = keys[i]
			local start, duration, auraStart, auraDuration
			if key ~= UNKNOWN then
				start, duration = ICD:GetCooldown(guid, key)
				auraStart, auraDuration = ICD:GetAura(guid, key)
			end
			if start or not hideReady then
				shown = shown + 1
				local icon = setIcon(container, shown, key)
				if auraStart then
					if auraDuration then
						setIconCooldown(icon, auraStart, auraDuration, true)
						nextExpiry = min(nextExpiry, auraStart + auraDuration)
					else
						setIconCooldown(icon, start, duration, true)
					end
				else
					setIconCooldown(icon, start, duration)
				end
				if start then
					nextExpiry = min(nextExpiry, start + duration)
				end
			end
		end
	end
	hideFrom(container, shown)

	container.nextExpiry = nextExpiry
	container.untilCheck = 0
	container:SetScript("OnUpdate", nextExpiry < huge and onContainerUpdate or nil)
end

local function update(frame)
	refresh(frame.procs)
end

local function test(frame)
	local container = frame.procs
	container:SetScript("OnUpdate", nil)
	container.guid = nil
	local shown = 0
	if container.enabled then
		local keys = ICD:GetTestKeys()
		local now = GetTime()
		local count = random(0, 3)
		for _ = 1, count do
			shown = shown + 1
			local icon = setIcon(container, shown, keys[random(#keys)])
			local roll = random(3)
			if roll == 1 then
				setIconCooldown(icon, now - random(0, TEST_AURA_DURATION - 5), TEST_AURA_DURATION, true)
			elseif roll == 2 then
				local duration = ICD:GetSource(icon.key).cd
				setIconCooldown(icon, now - random(0, duration - 5), duration)
			else
				setIconCooldown(icon, nil)
			end
		end
		if container.kind == "arena" and ns.Config.internalCooldowns.unknownTrinkets then
			for _ = count + 1, 2 do
				shown = shown + 1
				setIconCooldown(setIcon(container, shown, UNKNOWN), nil)
			end
		end
	end
	hideFrom(container, shown)
end

local function onUpdated(frame, guid)
	local container = frame.procs
	if frame:IsShown() and (guid == nil or guid == container.guid) then
		refresh(container)
	end
end

local function anchorContainer(container, config)
	container:ClearAllPoints()
	container:SetPoint("BOTTOMRIGHT", container:GetParent(), "TOPRIGHT", config.offsetX, config.offsetY)
end

local function applyContainerSettings(container, config)
	container.enabled = config.enabled and config[container.kind]
	container.size, container.spacing = config.size, config.spacing
	container:SetSize(config.size, config.size)
end

local function applyConfig()
	local config = ns.Config.internalCooldowns
	for i = 1, #containers do
		local container = containers[i]
		local frame = container:GetParent()
		applyContainerSettings(container, config)
		anchorContainer(container, config)
		for j = 1, #container do
			local icon = container[j]
			setIconSize(icon, config.size)
			placeIcon(container, icon, j)
			icon.active = nil
		end
		if frame.test then
			test(frame)
		elseif frame:IsShown() then
			refresh(container)
		end
	end
end

local function create(frame)
	local container = CreateFrame("Frame", nil, frame)
	container:SetFrameLevel(frame:GetFrameLevel() + FRAME_LEVEL_OFFSET)
	container.unit = frame.baseUnit or frame.unit
	container.kind = container.unit:find("^arena%d$") and "arena"
		or container.unit:find("^party%d$") and "party"
		or container.unit
	container.keys = {}
	container.untilCheck = 0
	container.nextExpiry = huge
	applyContainerSettings(container, ns.Config.internalCooldowns)
	containers[#containers + 1] = container

	frame:RegisterEvent(ns.PROC_COOLDOWN_UPDATED, onUpdated)
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", update)

	return container
end

UF:RegisterElement("procs", create, update, test)

UF:OnInitialize(function(self)
	applyConfig()
	self:WatchConfig("internalCooldowns", applyConfig)
end)
