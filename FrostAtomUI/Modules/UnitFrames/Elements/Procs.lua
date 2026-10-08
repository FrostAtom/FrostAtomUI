local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitCanAttack = UnitCanAttack
local GameTooltip = GameTooltip
local GetTime = GetTime
local min, huge, random = math.min, math.huge, math.random
local unpack, wipe = unpack, wipe

local ICD = ns:GetModule("InternalCooldowns")
local CooldownTimer = ns:GetModule("CooldownTimer")

local CHECK_INTERVAL = 0.5
local FONT_SCALE = 0.45
local FRAME_LEVEL_OFFSET = 4
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 1.75
local TEST_AURA_DURATION = 15
local TEST_MAX_ICONS = 3
local MAX_UNKNOWN = 2
local PLAYER_SLOTS = 4
local UNKNOWN = ICD.UNKNOWN

local containers = {}

local function setIconSize(icon, size)
	icon:SetSize(size, size)
	ns.SetFont(icon.cooldown.timer, size * FONT_SCALE, "OUTLINE")
	icon.glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)
end

local function placeIcon(container, icon, index)
	local step = container.size + container.spacing
	icon:ClearAllPoints()
	if container.centered then
		local shown = container.shown or 1
		icon:SetPoint("CENTER", container, "CENTER", (index - 1 - (shown - 1) / 2) * step, 0)
		return
	end
	icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -(index - 1) * step, 0)
end

local function slotShown(guid, key)
	local category = ICD:GetCategory(guid, key)
	return category == nil or ns.Config.internalCooldowns.slots[category] ~= false
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
	local icon = CooldownTimer:CreateIcon(
		container,
		{ fontSize = container.size * FONT_SCALE, timerOnIcon = true, flash = true }
	)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:EnableMouse(not ns.Config.internalCooldowns.clickThrough)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

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
	if container.centered and container.shown ~= shown then
		container.shown = shown
		for i = 1, shown do
			placeIcon(container, container[i], i)
		end
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
		local unknown = config.unknownTrinkets and config.slots.trinket and not hideReady and isHostile(container, unit)
		local keys = ICD:Collect(guid, container.keys, unknown)
		for i = 1, #keys do
			local key = keys[i]
			local start, duration, auraStart, auraDuration
			if key ~= UNKNOWN then
				start, duration = ICD:GetCooldown(guid, key)
				auraStart, auraDuration = ICD:GetAura(guid, key)
			end
			if (start or not hideReady) and slotShown(guid, key) then
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

local testKeys = {}

local function shownTestKeys()
	wipe(testKeys)
	local keys = ICD:GetTestKeys()
	for i = 1, #keys do
		if slotShown(nil, keys[i]) then
			testKeys[#testKeys + 1] = keys[i]
		end
	end
	return testKeys
end

local function fillTest(container)
	container:SetScript("OnUpdate", nil)
	container.guid = nil
	local shown = 0
	if container.enabled then
		local config = ns.Config.internalCooldowns
		local keys = shownTestKeys()
		local now = GetTime()
		local count = min(random(container.centered and 1 or 0, TEST_MAX_ICONS), #keys)
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
		if container.kind == "arena" and config.unknownTrinkets and config.slots.trinket then
			for _ = count + 1, MAX_UNKNOWN do
				shown = shown + 1
				setIconCooldown(setIcon(container, shown, UNKNOWN), nil)
			end
		end
	end
	hideFrom(container, shown)
end

local function test(frame)
	fillTest(frame.procs)
end

local function onUpdated(frame, guid)
	local container = frame.procs
	if frame:IsShown() and (guid == nil or guid == container.guid) then
		refresh(container)
	end
end

local DR_PREFIXES = { arena = "arena", party = "party", target = "target", focus = "target" }

local function diminishAbove(container)
	local config = ns.Config.diminishingReturns
	local prefix = DR_PREFIXES[container.kind]
	local anchor = prefix and config[prefix .. "Anchor"]
	if not (config.enabled and config[container.kind] and anchor and anchor:find("^TOP")) or anchor == "TOPLEFT" then
		return 0
	end
	local size = container.kind == "arena" and config.arenaSize or config.size
	return config[prefix .. "OffsetY"] + size
end

local function anchorContainer(container, config)
	local frame = container:GetParent()
	local y = config.offsetY + diminishAbove(container) + UF.CastbarClearance(frame, "TOP")
	container:ClearAllPoints()
	container:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", config.offsetX, y)
end

local function applyContainerSettings(container, config)
	local enabled = config.enabled and config[container.kind]
	local size = config.size
	if container.centered then
		enabled = enabled and config.playerDetached
		size = config.playerSize
		container:SetSize(size * PLAYER_SLOTS + config.spacing * (PLAYER_SLOTS - 1), size)
	else
		enabled = enabled and not (container.kind == "player" and config.playerDetached)
		container:SetSize(size, size)
	end
	container.enabled = enabled
	container.size, container.spacing = size, config.spacing
end

local function applyIcons(container, config)
	container.shown = nil
	for j = 1, #container do
		local icon = container[j]
		setIconSize(icon, container.size)
		placeIcon(container, icon, j)
		icon:EnableMouse(not config.clickThrough)
		icon.active = nil
	end
end

local playerBlock

local function updatePlayerBlock()
	if UF.testing or ns.Movers.IsUnlocked() then
		fillTest(playerBlock)
	else
		refresh(playerBlock)
	end
end

local function applyConfig()
	local config = ns.Config.internalCooldowns
	for i = 1, #containers do
		local container = containers[i]
		local frame = container:GetParent()
		applyContainerSettings(container, config)
		anchorContainer(container, config)
		applyIcons(container, config)
		if frame.test then
			test(frame)
		elseif frame:IsShown() then
			refresh(container)
		end
	end
	applyContainerSettings(playerBlock, config)
	applyIcons(playerBlock, config)
	updatePlayerBlock()
end

local function createPlayerBlock()
	local container = CreateFrame("Frame", nil, UIParent)
	container.unit = "player"
	container.kind = "player"
	container.centered = true
	container.keys = {}
	container.untilCheck = 0
	container.nextExpiry = huge
	applyContainerSettings(container, ns.Config.internalCooldowns)
	UF:AnchorToConfig(container, "internalCooldowns.playerPoint", "Player internal cooldowns", {
		enabledPath = { "internalCooldowns.player", "internalCooldowns.playerDetached" },
	})

	local events = ns.Mixin({}, ns.EventMixin)
	events:RegisterEvent(ns.E.PROC_COOLDOWN_UPDATED, function(_, guid)
		if guid == nil or guid == UnitGUID("player") then
			updatePlayerBlock()
		end
	end)
	hooksecurefunc(UF, "SetTestMode", updatePlayerBlock)
	hooksecurefunc(ns.Movers, "Unlock", updatePlayerBlock)
	hooksecurefunc(ns.Movers, "Lock", updatePlayerBlock)
	return container
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

	frame:RegisterEvent(ns.E.PROC_COOLDOWN_UPDATED, onUpdated)
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", update)

	return container
end

UF:RegisterElement({ name = "procs", Create = create, Update = update, Test = test })

UF:OnInitialize(function(self)
	playerBlock = createPlayerBlock()
	applyConfig()
	self:WatchConfig("internalCooldowns", applyConfig)
	local function reanchor()
		for i = 1, #containers do
			anchorContainer(containers[i], ns.Config.internalCooldowns)
		end
	end
	self:WatchConfig("unitFrames", reanchor)
	self:WatchConfig("diminishingReturns", reanchor)
end)
