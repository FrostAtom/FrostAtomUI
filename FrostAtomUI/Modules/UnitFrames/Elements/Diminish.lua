local _, ns = ...
local UF = ns:GetModule("UnitFrames")
local L = ns.L

local UnitGUID = UnitGUID
local GameTooltip = GameTooltip
local GetTime = GetTime
local min, huge, random = math.min, math.huge, math.random
local unpack, wipe, sort, tremove = unpack, wipe, table.sort, table.remove

local SpellTexture = ns.SpellTexture

local Data = ns.DRData
local RESET_TIME = Data.RESET_TIME
local AURA_TIMEOUT = Data.AURA_TIMEOUT
local CATEGORY_NAMES = Data.CATEGORY_NAMES
local TEST_SPELLS = Data.TEST_SPELLS
local FILTER_GROUPS = Data.FILTER_GROUPS
local SEVERITY_LABELS = { "½", "¼" }

local categoryRank = {}
for index, category in ipairs(Data.CATEGORY_ORDER) do
	categoryRank[category] = index
end

local DR = ns:GetModule("DiminishingReturns")
local CooldownTimer = ns:GetModule("CooldownTimer")

local CHECK_INTERVAL = 0.1
local FONT_SCALE = 0.4
local BADGE_SCALE = 0.5
local SEVERITY_SCALE = 0.36
local IMMUNE_BADGE = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local IMMUNE_STACKS = 3
local SEVERITY_KEYS = { "halfColor", "quarterColor", "immuneColor" }
local SEVERITY_TEXT = { "Next: 50% duration", "Next: 25% duration", "Next: immune" }
local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }
local GROWTH_STEPS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
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
	ns.SetFont(icon.severity, size * SEVERITY_SCALE, "OUTLINE")
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
	step = (index - 1) * step
	icon:SetPoint("CENTER", container, "CENTER", container.stepX * step, container.stepY * step)
end

local function createIcon(container, index)
	local icon = CooldownTimer:CreateIcon(
		container,
		{ borderAbove = true, reverse = true, fontSize = container.size * FONT_SCALE }
	)
	icon:SetFrameLevel(container:GetFrameLevel() + 1)
	icon:EnableMouse(not ns.Config.diminishingReturns.clickThrough)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)
	local overlay = icon.overlay

	icon.severity = overlay:CreateFontString(nil, "OVERLAY")
	icon.severity:SetPoint("BOTTOMLEFT", 1, 1)

	icon.badge = overlay:CreateTexture(nil, "OVERLAY")
	icon.badge:SetTexture(IMMUNE_BADGE)
	icon.badge:SetPoint("TOPRIGHT", 2, 2)
	icon.badge:Hide()

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
	local label = ns.Config.diminishingReturns.severityText and SEVERITY_LABELS[stacks]
	icon.severity:SetText(label or "")
	if label then
		icon.severity:SetTextColor(unpack(ns.Config.diminishingReturns[SEVERITY_KEYS[stacks]]))
	end
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
local collected = {}
local pool = {}

local function byRank(a, b)
	return (categoryRank[a.category] or 99) < (categoryRank[b.category] or 99)
end

local function collect(guid)
	for i = #collected, 1, -1 do
		pool[#pool + 1] = collected[i]
		collected[i] = nil
	end
	local filter = ns.Config.diminishingReturns.categories
	for category, stacks, expires, auraActive, spellId, appliedAt in DR:IterateCategories(guid) do
		if filter[FILTER_GROUPS[category] or ""] ~= false then
			local item = tremove(pool) or {}
			item.category, item.stacks, item.expires = category, stacks, expires
			item.auraActive, item.spellId, item.appliedAt = auraActive, spellId, appliedAt
			collected[#collected + 1] = item
		end
	end
	sort(collected, byRank)
	return collected
end

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
	local guid = UnitGUID(container.unit) or UF.GhostGUID and UF.GhostGUID(container.frame)
	container.guid = guid

	local shown = 0
	local nextCheck = huge
	if container.enabled then
		local list = collect(guid)
		for i = 1, #list do
			local item = list[i]
			local category, stacks, expires, auraActive, spellId, appliedAt =
				item.category, item.stacks, item.expires, item.auraActive, item.spellId, item.appliedAt
			shown = shown + 1
			local icon = setIcon(container, shown, category, spellId, stacks)
			if auraActive then
				setIconCooldown(icon, nil)
				nextCheck = min(nextCheck, appliedAt + AURA_TIMEOUT)
			else
				setIconCooldown(icon, expires - RESET_TIME, RESET_TIME)
			end
			nextCheck = min(nextCheck, expires)
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
			local filtered = ns.Config.diminishingReturns.categories[FILTER_GROUPS[category] or ""] == false
			if not testCategories[category] and not filtered then
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
	if container:IsVisible() and (guid == nil or guid == container.guid) then
		refresh(container)
	end
end

local function castbarAttached(frame)
	local castbar = frame.castbar
	local point = castbar and castbar.moverPath and ns:GetConfig(castbar.moverPath)
	return point ~= nil and point[4] == frame.moverPath
end

local function splitPoint(point)
	return point:match("^TOP") or point:match("^BOTTOM") or "", point:match("LEFT$") or point:match("RIGHT$") or ""
end

local function iconPoint(anchor, growth)
	local anchorV, anchorH = splitPoint(anchor)
	local iconV, iconH
	if growth == "LEFT" or growth == "RIGHT" then
		iconV = OPPOSITE[anchorV] or ""
		iconH = anchorV == "" and OPPOSITE[anchorH] or OPPOSITE[growth]
	else
		iconH = OPPOSITE[anchorH] or ""
		iconV = anchorH == "" and OPPOSITE[anchorV] or (growth == "UP" and "BOTTOM" or "TOP")
	end
	local point = iconV .. iconH
	return point ~= "" and point or "CENTER", anchorV, anchorH, iconV, iconH
end

local function anchorContainer(container)
	local config = ns.Config.diminishingReturns
	local frame = container:GetParent()
	local kind = container.kind
	local prefix = (kind == "arena" or kind == "party") and kind or "target"
	local anchor, growth = config[prefix .. "Anchor"], config[prefix .. "Growth"]
	local x, y = config[prefix .. "OffsetX"], config[prefix .. "OffsetY"]
	local point, anchorV, anchorH, iconV, iconH = iconPoint(anchor, growth)

	local relative = frame
	if anchor == "LEFT" and kind == "arena" and castbarAttached(frame) then
		relative = frame.castbar.icon
	elseif anchor == "RIGHT" and kind == "arena" and frame.trinket and UF.IsTrinketSeparate("enemy") then
		relative = frame.trinket
	elseif anchor == "RIGHT" and prefix ~= "target" then
		relative = UF.GroupChainEnd(frame)
		x = x + (relative == frame and 0 or ARENA_PET_GAP)
	end
	if anchorV ~= "" and iconV == OPPOSITE[anchorV] and (anchorH == "" or iconH ~= OPPOSITE[anchorH]) then
		y = y + UF.CastbarClearance(frame, anchorV)
	end

	container:ClearAllPoints()
	container:SetPoint(point, relative, anchor, x, y)
	local step = GROWTH_STEPS[growth] or GROWTH_STEPS.RIGHT
	container.stepX, container.stepY = step[1], step[2]
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
	events:RegisterEvent(ns.E.DR_UPDATED, function(_, guid)
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
	container.frame = frame
	container.kind = frame.unit:find("^arena%d$") and "arena" or frame.unit:find("^party%d$") and "party" or frame.unit
	container.untilCheck = 0
	container.nextCheck = huge
	container.stepX, container.stepY = 1, 0
	applyContainerSettings(container, ns.Config.diminishingReturns)
	containers[#containers + 1] = container

	frame:RegisterEvent(ns.E.DR_UPDATED, onUpdated)
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", update)
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE", update)

	return container
end

UF:RegisterElement({ name = "diminish", Create = create, Update = update, Test = test })

local function applyDemand()
	DR:SetDemand("unitFrames", ns.Config.diminishingReturns.enabled)
end

UF:OnInitialize(function(self)
	applyDemand()
	self:WatchConfig("diminishingReturns.enabled", applyDemand)
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
