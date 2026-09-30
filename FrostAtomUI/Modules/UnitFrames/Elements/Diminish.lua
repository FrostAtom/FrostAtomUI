local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local UnitGUID = UnitGUID
local GameTooltip = GameTooltip
local GetTime = GetTime
local min, huge, random = math.min, math.huge, math.random
local unpack, wipe = unpack, wipe

local SpellTexture = ns.SpellTexture

local Data = ns.DRData
local RESET_TIME = Data.RESET_TIME
local AURA_TIMEOUT = Data.AURA_TIMEOUT
local CATEGORY_NAMES = Data.CATEGORY_NAMES
local TEST_SPELLS = Data.TEST_SPELLS

local DR = ns:GetModule("DiminishingReturns")
local CooldownTimer = ns:GetModule("CooldownTimer")

local CHECK_INTERVAL = 0.1
local FONT_SCALE = 0.4
local BADGE_SCALE = 0.5
local IMMUNE_BADGE = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local IMMUNE_STACKS = 3
local SEVERITY_KEYS = { "halfColor", "quarterColor", "immuneColor" }
local SEVERITY_TEXT = { "Next: 50% duration", "Next: 25% duration", "Next: immune" }
local GROW_LEFT_SIDES = { LEFT = true, TOP = true, BOTTOM = true }
local ARENA_PET_GAP = 2
local PLAYER_SLOTS = 3

local containers = {}

local function onIconEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(L[CATEGORY_NAMES[icon.category]], 1, 1, 1)
	local r, g, b = unpack(ns.Config.diminishingReturns[SEVERITY_KEYS[icon.stacks]])
	GameTooltip:AddLine(L[SEVERITY_TEXT[icon.stacks]], r, g, b)
	GameTooltip:Show()
end

local function onIconLeave()
	GameTooltip:Hide()
end

local function setIconSize(icon, size)
	icon:SetSize(size, size)
	ns.SetFont(icon.cooldown.timer, size * FONT_SCALE, "OUTLINE")
	icon.badge:SetSize(size * BADGE_SCALE, size * BADGE_SCALE)
end

local function placeIcon(container, icon, index)
	local step = container.size + container.spacing
	icon:ClearAllPoints()
	if container.centered then
		local shown = container.shown or 1
		icon:SetPoint("CENTER", container, "CENTER", (index - 1 - (shown - 1) / 2) * step, 0)
		return
	end
	local point = container.growLeft and "RIGHT" or "LEFT"
	step = (index - 1) * step
	icon:SetPoint(point, container, point, container.growLeft and -step or step, 0)
end

local function createIcon(container, index)
	local icon = CreateFrame("Frame", nil, container)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:EnableMouse(not ns.Config.diminishingReturns.clickThrough)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetNonBlocking(true)
	icon.texture:SetAllPoints()

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)

	local overlay = CreateFrame("Frame", nil, icon)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 1)

	icon.border = overlay:CreateTexture(nil, "ARTWORK")
	icon.border:SetTexture(ns.Media.buttonNormal)
	icon.border:SetAllPoints()

	icon.badge = overlay:CreateTexture(nil, "OVERLAY")
	icon.badge:SetTexture(IMMUNE_BADGE)
	icon.badge:SetPoint("TOPRIGHT", 2, 2)
	icon.badge:Hide()

	CooldownTimer:Attach(icon.cooldown, container.size * FONT_SCALE, overlay)

	setIconSize(icon, container.size)
	placeIcon(container, icon, index)
	container[index] = icon
	return icon
end

local function setIcon(container, index, category, spellId, stacks)
	local icon = container[index] or createIcon(container, index)
	icon.category = category
	icon.stacks = stacks
	icon.texture:SetTexture(SpellTexture(spellId))
	icon.border:SetVertexColor(unpack(ns.Config.diminishingReturns[SEVERITY_KEYS[stacks]]))
	ns.SetShown(icon.badge, stacks >= IMMUNE_STACKS)
	icon:Show()
	return icon
end

local function setIconCooldown(icon, start, duration)
	if start ~= icon.start then
		icon.start = start
		icon.cooldown:SetCooldown(start or 0, start and duration or 0)
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
	if container.nextCheck <= GetTime() then
		refresh(container)
	end
end

function refresh(container)
	local guid = UnitGUID(container.unit)
	container.guid = guid

	local state = container.enabled and DR:Get(guid)
	local shown = 0
	local nextCheck = huge
	if state then
		local now = GetTime()
		local order = state.order
		for i = 1, #order do
			local category = order[i]
			local entry = state[category]
			shown = shown + 1
			local icon = setIcon(container, shown, category, entry.spellId, entry.stacks)
			if DR:IsAuraActive(entry, now) then
				setIconCooldown(icon, nil)
				nextCheck = min(nextCheck, entry.appliedAt + AURA_TIMEOUT)
			else
				setIconCooldown(icon, entry.expires - RESET_TIME, RESET_TIME)
			end
			nextCheck = min(nextCheck, entry.expires)
		end
	end
	hideFrom(container, shown)

	container.nextCheck = nextCheck
	container.untilCheck = 0
	container:SetScript("OnUpdate", nextCheck < huge and onContainerUpdate or nil)
end

local function update(frame)
	refresh(frame.diminish)
end

local testCategories = {}

local function fillTest(container)
	container:SetScript("OnUpdate", nil)
	container.guid = nil
	local shown = 0
	if container.enabled then
		wipe(testCategories)
		local now = GetTime()
		for _ = 1, random(container.kind == "player" and 1 or 0, 4) do
			local spellId = TEST_SPELLS[random(#TEST_SPELLS)]
			local category = Data.SPELLS[spellId]
			if not testCategories[category] then
				testCategories[category] = true
				shown = shown + 1
				local icon = setIcon(container, shown, category, spellId, random(3))
				if random(4) == 1 then
					setIconCooldown(icon, nil)
				else
					setIconCooldown(icon, now - random(0, RESET_TIME - 3), RESET_TIME)
				end
			end
		end
	end
	hideFrom(container, shown)
end

local function test(frame)
	fillTest(frame.diminish)
end

local function onUpdated(frame, guid)
	local container = frame.diminish
	if frame:IsShown() and (guid == nil or guid == container.guid) then
		refresh(container)
	end
end

local function castbarAttached(frame)
	local castbar = frame.castbar
	local point = castbar and castbar.moverPath and ns:GetConfig(castbar.moverPath)
	return point ~= nil and point[4] == frame.moverPath
end

local function anchorContainer(container)
	local config = ns.Config.diminishingReturns
	local frame = container:GetParent()
	local arena = container.kind == "arena"
	local side = arena and config.arenaSide or config.targetSide
	local x = arena and config.arenaOffsetX or config.targetOffsetX
	local y = arena and config.arenaOffsetY or config.targetOffsetY

	container:ClearAllPoints()
	if side == "LEFT" then
		local relative = arena and castbarAttached(frame) and frame.castbar.icon or frame
		container:SetPoint("RIGHT", relative, "LEFT", x, y)
	elseif side == "TOP" then
		container:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", x, y)
	elseif side == "BOTTOM" then
		container:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", x, y)
	elseif arena and frame.trinket and UF.IsTrinketSeparate("enemy") then
		container:SetPoint("LEFT", frame.trinket, "RIGHT", x, y)
	elseif arena then
		local relative = UF.GroupChainEnd(frame)
		container:SetPoint("LEFT", relative, "RIGHT", (relative == frame and 0 or ARENA_PET_GAP) + x, y)
	else
		container:SetPoint("LEFT", frame, "RIGHT", x, y)
	end
	container.growLeft = GROW_LEFT_SIDES[side] or false
end

local SIZE_KEYS = { arena = "arenaSize", player = "playerSize" }

local function applyContainerSettings(container, config)
	local size = config[SIZE_KEYS[container.kind] or "size"]
	container.enabled = config.enabled and config[container.kind]
	container.size, container.spacing = size, config.spacing
	if container.centered then
		container:SetSize(size * PLAYER_SLOTS + config.spacing * (PLAYER_SLOTS - 1), size)
	else
		container:SetSize(size, size)
	end
end

local function applyIcons(container, config)
	container.shown = nil
	for j = 1, #container do
		local icon = container[j]
		setIconSize(icon, container.size)
		placeIcon(container, icon, j)
		icon:EnableMouse(not config.clickThrough)
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
	local config = ns.Config.diminishingReturns
	for i = 1, #containers do
		local container = containers[i]
		local frame = container:GetParent()
		applyContainerSettings(container, config)
		anchorContainer(container)
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
	container.untilCheck = 0
	container.nextCheck = huge
	applyContainerSettings(container, ns.Config.diminishingReturns)
	UF:AnchorToConfig(container, "diminishingReturns.playerPoint", "Player diminishing returns", {
		enabledPath = "diminishingReturns.player",
	})

	local events = ns.Mixin({}, ns.EventMixin)
	events:RegisterEvent(ns.DR_UPDATED, function(_, guid)
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
	container:SetFrameLevel(frame:GetFrameLevel() + 1)
	container.unit = frame.unit
	container.kind = frame.unit:find("^arena%d$") and "arena" or frame.unit
	container.untilCheck = 0
	container.nextCheck = huge
	applyContainerSettings(container, ns.Config.diminishingReturns)
	containers[#containers + 1] = container

	frame:RegisterEvent(ns.DR_UPDATED, onUpdated)
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", update)

	return container
end

UF:RegisterElement("diminish", create, update, test)

UF:OnInitialize(function(self)
	playerBlock = createPlayerBlock()
	applyConfig()
	self:WatchConfig("diminishingReturns", applyConfig)
	self:WatchConfig("arenaTrinket", applyConfig)
	self:WatchConfig("groupCooldowns", applyConfig)
	self:WatchConfig("unitFrames", function()
		for i = 1, #containers do
			anchorContainer(containers[i])
		end
	end)
end)
