local _, ns = ...

local L = ns.L

local UnitExists, UnitGUID, UnitClass, UnitRace, UnitName = UnitExists, UnitGUID, UnitClass, UnitRace, UnitName
local GameTooltip = GameTooltip
local GetTime = GetTime
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UNKNOWNOBJECT = UNKNOWNOBJECT
local max, min, floor, ceil, huge, random = math.max, math.min, math.floor, math.ceil, math.huge, math.random
local wipe, unpack = wipe, unpack

local Data = ns.CooldownData
local CATEGORIES = Data.CATEGORIES
local SPEC_HINTS = Data.SPEC_HINTS
local CooldownTracker = ns:GetModule("CooldownTracker")
local CooldownTimer = ns:GetModule("CooldownTimer")
local UF = ns:GetModule("UnitFrames")

local GroupCooldowns = ns:NewModule("GroupCooldowns")
ns.GroupCooldowns = GroupCooldowns

local CHECK_INTERVAL = 0.2
local FONT_SCALE = 0.45
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 1.75
local LABEL_GAP = 4
local LABEL_FONT_SIZE = 10
local PREVIEW_NAMES = { "Frostatom", "Nightshade", "Zephyra", "Thoralf", "Mirelle", "Kaelith", "Dravok", "Sylvara" }
local PREVIEW_RACES =
	{ "Human", "Scourge", "Tauren", "Gnome", "BloodElf", "Orc", "Troll", "Dwarf", "NightElf", "Draenei" }
local PREVIEW_CLASSES = {
	"WARRIOR",
	"PALADIN",
	"HUNTER",
	"ROGUE",
	"PRIEST",
	"DEATHKNIGHT",
	"SHAMAN",
	"MAGE",
	"WARLOCK",
	"DRUID",
}

local CATEGORY_NAMES = {
	defensive = L["Defensive"],
	offensive = L["Burst"],
	interrupt = L["Interrupt"],
	trinket = L["Trinket"],
	cc = L["Control"],
	mobility = L["Mobility"],
	utility = L["Utility"],
}
GroupCooldowns.CATEGORY_NAMES = CATEGORY_NAMES

local CATEGORY_COLORS = {
	defensive = { 0.35, 0.9, 0.35 },
	offensive = { 1, 0.35, 0.3 },
	interrupt = { 0.4, 0.7, 1 },
	trinket = { 1, 0.82, 0 },
	cc = { 0.85, 0.5, 1 },
	mobility = { 0.4, 0.95, 0.9 },
	utility = { 0.75, 0.75, 0.75 },
}
GroupCooldowns.CATEGORY_COLORS = CATEGORY_COLORS

local SIDES = {
	friendly = {
		units = { "party1", "party2", "party3", "party4" },
		label = "Ally cooldowns",
		interruptLabel = "Ally interrupts",
		frames = "party",
		frameLabel = "Party",
		frameSide = "RIGHT",
	},
	enemy = {
		units = { "arena1", "arena2", "arena3", "arena4", "arena5" },
		label = "Enemy cooldowns",
		interruptLabel = "Enemy interrupts",
		frames = "arena",
		frameLabel = "Arena",
		frameSide = "LEFT",
	},
}

local PREVIEW_COUNTS = { friendly = 2, enemy = 3 }

local sides = {}
local previewing = false
local framesReady = false

function GroupCooldowns.IsSpellShown(id)
	local override = ns.Config.groupCooldowns.spells[id]
	if override ~= nil then
		return override
	end
	local info = CooldownTracker:GetInfo(id)
	return not (info and info.hidden)
end

local function usesFrames(side)
	return ns.Config.groupCooldowns[side .. "Layout"] == "frames" and #sides[side].frames > 0
end

local function categoryOf(id)
	local info = CooldownTracker:GetInfo(id)
	return info and info.category or "utility"
end

local function onIconEnter(icon)
	GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetHyperlink("spell:" .. icon.spellId)
	local owner = icon.owner
	if owner and owner.name then
		local color = RAID_CLASS_COLORS[owner.class]
		if color then
			GameTooltip:AddLine(owner.name, color.r, color.g, color.b)
		else
			GameTooltip:AddLine(owner.name, 1, 1, 1)
		end
	end
	GameTooltip:Show()
end

local function onIconLeave()
	GameTooltip:Hide()
end

local function setIconSize(icon, size)
	icon:SetSize(size, size)
	ns.SetFont(icon.cooldown.timer, size * FONT_SCALE, "OUTLINE")
	icon.glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)
end

local function layoutOf(panel, config)
	local prefix = panel.kind == "interrupts" and panel.side .. "Interrupt" or panel.side
	local perRow = config[prefix .. (panel.kind == "frame" and "FramePerRow" or "PerRow")]
	return config[prefix .. "Size"], config[prefix .. "Spacing"], perRow, config[prefix .. "RowSpacing"]
end

local function createIcon(panel)
	local config = ns.Config.groupCooldowns
	local size = layoutOf(panel, config)
	local icon = CreateFrame("Frame", nil, panel)
	icon:SetFrameLevel(panel:GetFrameLevel() + 1)
	icon:EnableMouse(not config.clickThrough)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetNonBlocking(true)
	UF.SkinIcon(icon, icon.texture)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	CooldownTimer:Attach(icon.cooldown, size * FONT_SCALE, icon)
	CooldownTimer:AttachFlash(icon.cooldown, icon.texture, config, "readyFlash")

	icon.glow = icon:CreateTexture(nil, "OVERLAY")
	icon.glow:SetPoint("CENTER")
	icon.glow:SetTexture(GLOW_TEXTURE)
	icon.glow:SetBlendMode("ADD")
	icon.glow:Hide()

	setIconSize(icon, size)
	return icon
end

local function acquireIcon(panel, index)
	local icon = panel.icons[index]
	if not icon then
		icon = createIcon(panel)
		panel.icons[index] = icon
	end
	return icon
end

local function acquireLabel(panel, category)
	local label = panel.labels[category]
	if not label then
		label = panel:CreateFontString(nil, "OVERLAY")
		ns.SetFont(label, LABEL_FONT_SIZE, "OUTLINE")
		label:SetTextColor(unpack(CATEGORY_COLORS[category]))
		label:SetText(CATEGORY_NAMES[category])
		panel.labels[category] = label
	end
	return label
end

local function setIconState(icon, owner, id, start, duration, active)
	local config = ns.Config.groupCooldowns
	if icon.spellId ~= id then
		icon.spellId = id
		icon.texture:SetTexture(ns.SpellTexture(id))
	end
	if icon.owner ~= owner or icon.start ~= start or icon.duration ~= duration then
		icon.owner, icon.start, icon.duration = owner, start, duration
		icon.cooldown:SetCooldown(start or 0, start and duration or 0)
	end
	icon.texture:SetDesaturated(start ~= nil and config.desaturate)
	local color = RAID_CLASS_COLORS[owner.class]
	if color then
		icon.border:SetVertexColor(color.r, color.g, color.b)
	else
		icon.border:SetVertexColor(1, 1, 1)
	end
	if active then
		icon.glow:SetVertexColor(unpack(config.glowColor))
		icon.glow:Show()
	else
		icon.glow:Hide()
	end
	icon:Show()
end

local function accepts(panel, config, category)
	if not config[panel.side .. "Categories"][category] then
		return false
	elseif panel.kind == "interrupts" then
		return category == "interrupt"
	end
	if category == "trinket" then
		return not config[panel.side .. "SeparateTrinket"]
	end
	return category ~= "interrupt" or not config[panel.side .. "SeparateInterrupts"]
end

local function collectSpells(owner, panel, config)
	local byCategory = owner.byCategory
	for _, list in pairs(byCategory) do
		wipe(list)
	end
	local tracked = owner.spells or CooldownTracker:GetTrackedFor(owner.guid, owner.class, owner.race, true)
	for i = 1, tracked and #tracked or 0 do
		local id = tracked[i]
		local category = categoryOf(id)
		if accepts(panel, config, category) and GroupCooldowns.IsSpellShown(id) then
			local list = byCategory[category]
			if not list then
				list = {}
				byCategory[category] = list
			end
			list[#list + 1] = id
		end
	end
end

local function spellState(owner, id)
	local preview = owner.preview
	if preview then
		local state = preview[id]
		if state then
			return state.start, state.duration, state.active
		end
		return
	end
	local start, duration = CooldownTracker:GetCooldown(owner.guid, id)
	return start, duration, CooldownTracker:IsHighlighted(owner.guid, id)
end

local refresh

local function onPanelUpdate(panel, elapsed)
	panel.untilCheck = panel.untilCheck - elapsed
	if panel.untilCheck > 0 then
		return
	end
	panel.untilCheck = CHECK_INTERVAL
	if panel.nextExpiry <= GetTime() then
		refresh(panel)
	end
end

local function anchorFor(panel)
	return panel.growth == "LEFT" and "TOPRIGHT" or "TOPLEFT", panel.growth == "LEFT" and -1 or 1
end

local function placeLabel(panel, config, category, count, y, direction)
	local label = panel.labels[category]
	if count > 0 and config.labels then
		label = acquireLabel(panel, category)
		label:ClearAllPoints()
		if direction == 1 then
			label:SetPoint("RIGHT", panel, "TOPLEFT", -LABEL_GAP, y)
		else
			label:SetPoint("LEFT", panel, "TOPRIGHT", LABEL_GAP, y)
		end
		label:Show()
	elseif label then
		label:Hide()
	end
end

local function isPlaced(panel)
	return panel.kind ~= "frame" or previewing or panel.frame:IsVisible()
end

function refresh(panel)
	local config = ns.Config.groupCooldowns
	local size, spacing, perRow, rowSpacing = layoutOf(panel, config)
	local step, rowStep = size + spacing, size + rowSpacing
	local grouped = panel.kind == "group"
	local anchor, direction = anchorFor(panel)
	local owners = panel.owners

	for i = 1, #owners do
		collectSpells(owners[i], panel, config)
	end

	local used, rows, count = 0, 0, 0
	local nextExpiry = huge
	local now = GetTime()
	for c = 1, #CATEGORIES do
		local category = CATEGORIES[c]
		if grouped then
			count = 0
		end
		for i = 1, #owners do
			local owner = owners[i]
			local list = owner.byCategory[category]
			for j = 1, list and #list or 0 do
				local id = list[j]
				local x = count % perRow * step
				local line = rows + floor(count / perRow)
				count = count + 1
				used = used + 1
				local icon = acquireIcon(panel, used)
				icon:ClearAllPoints()
				icon:SetPoint(anchor, panel, anchor, direction * x, -line * rowStep)
				local start, duration, active = spellState(owner, id)
				if start and start + duration <= now then
					start, duration = nil, nil
				end
				setIconState(icon, owner, id, start, duration, active)
				if start then
					nextExpiry = min(nextExpiry, start + duration)
				end
			end
		end
		if grouped then
			placeLabel(panel, config, category, count, -rows * rowStep - size / 2, direction)
			rows = rows + ceil(count / perRow)
		end
	end
	if not grouped then
		rows = ceil(count / perRow)
	end

	for i = used + 1, #panel.icons do
		local icon = panel.icons[i]
		icon:Hide()
		icon.owner = nil
	end

	panel:SetSize(perRow * step - spacing, max(rows, 1) * rowStep - rowSpacing)
	ns.SetShown(panel, panel.active and used > 0 and isPlaced(panel))

	panel.nextExpiry = nextExpiry
	panel.untilCheck = CHECK_INTERVAL
	panel:SetScript("OnUpdate", nextExpiry < huge and onPanelUpdate or nil)
end

local function newOwner()
	return { byCategory = {} }
end

local function readUnit(owner, unit)
	local guid = UnitGUID(unit)
	if not guid then
		return false
	end
	if owner.guid ~= guid then
		owner.guid, owner.class, owner.race, owner.name = guid, nil, nil, nil
	end
	local _, class = UnitClass(unit)
	local _, race = UnitRace(unit)
	local name = UnitName(unit)
	owner.class = class or owner.class
	owner.race = race or owner.race
	if name and name ~= UNKNOWNOBJECT then
		owner.name = name
	end
	return owner.class ~= nil
end

local function readSlots(state)
	local slots = state.slots
	local units = SIDES[state.side].units
	for i = 1, #units do
		local unit = units[i]
		local slot = slots[i]
		if not slot then
			slot = newOwner()
			slots[i] = slot
		end
		slot.spells, slot.preview = nil, nil
		if state.side == "friendly" then
			if not (UnitExists(unit) and readUnit(slot, unit)) then
				slot.guid = nil
			end
		else
			readUnit(slot, unit)
		end
	end
end

local function validSlot(state, index)
	local slot = state.slots[index]
	return slot and slot.guid and slot.class and slot or nil
end

local function randomPreviewOwner(slot)
	local class = PREVIEW_CLASSES[random(#PREVIEW_CLASSES)]
	local race = PREVIEW_RACES[random(#PREVIEW_RACES)]
	local tree = random(3)
	slot.guid, slot.class, slot.race = nil, class, race
	slot.name = PREVIEW_NAMES[random(#PREVIEW_NAMES)]
	local spells, preview = {}, {}
	local now = GetTime()
	local list = CooldownTracker:GetTrackedFor(nil, class, race)
	for i = 1, #list do
		local id = list[i]
		local info = CooldownTracker:GetInfo(id)
		local hint = SPEC_HINTS[id]
		if not info.talent or hint and hint.tree == tree then
			spells[#spells + 1] = id
			local roll = random(6)
			if roll <= 2 then
				local duration = min(info.cooldown, 180)
				preview[id] = { start = now - random(0, duration - 5), duration = duration, active = roll == 1 }
			end
		end
	end
	slot.spells, slot.preview = spells, preview
end

local function previewSlot(state, index)
	local slot = state.previewSlots[index]
	if not slot then
		slot = newOwner()
		state.previewSlots[index] = slot
		randomPreviewOwner(slot)
	end
	return slot
end

local function update(state)
	local owners = state.owners
	wipe(owners)
	if previewing then
		for i = 1, PREVIEW_COUNTS[state.side] do
			owners[#owners + 1] = previewSlot(state, i)
		end
	else
		readSlots(state)
		for i = 1, #state.slots do
			owners[#owners + 1] = validSlot(state, i)
		end
	end
	refresh(state.group)
	refresh(state.interrupts)
	local frames = state.frames
	for i = 1, #frames do
		local panel = frames[i]
		local owner
		if previewing then
			owner = previewSlot(state, panel.index)
		else
			owner = validSlot(state, panel.index)
		end
		panel.owners[1] = owner
		refresh(panel)
	end
end

local function updateAll()
	for _, state in pairs(sides) do
		update(state)
	end
end

local function ownsGUID(panel, guid)
	local owners = panel.owners
	for i = 1, #owners do
		if owners[i].guid == guid then
			return true
		end
	end
	return false
end

local function refreshOwning(panel, guid)
	if guid == nil or ownsGUID(panel, guid) then
		refresh(panel)
	end
end

local function onCooldownUpdated(_, guid)
	if previewing then
		return
	end
	for _, state in pairs(sides) do
		refreshOwning(state.group, guid)
		refreshOwning(state.interrupts, guid)
		for i = 1, #state.frames do
			refreshOwning(state.frames[i], guid)
		end
	end
end

local function clearEnemies()
	local slots = sides.enemy.slots
	for i = 1, #slots do
		slots[i].guid = nil
	end
end

function GroupCooldowns:PLAYER_ENTERING_WORLD()
	clearEnemies()
	updateAll()
end

function GroupCooldowns:ARENA_OPPONENT_UPDATE(unit, kind)
	local index = tonumber(unit and unit:match("^arena(%d)$"))
	local slot = index and sides.enemy.slots[index]
	if slot and kind == "cleared" then
		slot.guid = nil
	end
	if not previewing then
		update(sides.enemy)
	end
end

function GroupCooldowns:PARTY_MEMBERS_CHANGED()
	if not previewing then
		update(sides.friendly)
	end
end

local UNIT_SIDES = {}
for side, info in pairs(SIDES) do
	for i = 1, #info.units do
		UNIT_SIDES[info.units[i]] = side
	end
end

local function onNameUpdate(_, unit)
	local side = UNIT_SIDES[unit]
	if side and not previewing then
		update(sides[side])
	end
end

function GroupCooldowns.SetPreview(enabled)
	enabled = enabled and true or false
	if enabled == previewing then
		return
	end
	previewing = enabled
	for _, state in pairs(sides) do
		wipe(state.previewSlots)
	end
	updateAll()
end

function GroupCooldowns.IsPreviewing()
	return previewing
end

local function applyIcons(panel, config)
	local size = layoutOf(panel, config)
	for i = 1, #panel.icons do
		local icon = panel.icons[i]
		setIconSize(icon, size)
		icon:EnableMouse(not config.clickThrough)
		icon.owner = nil
	end
end

local function applyConfig()
	local config = ns.Config.groupCooldowns
	for side, state in pairs(sides) do
		local enabled = config.enabled and config[side]
		local byFrames = usesFrames(side)
		local growth = config[side .. "Growth"]

		state.group.active = enabled and not byFrames
		state.group.growth = growth
		ns.ApplyPoint(state.group, "groupCooldowns." .. side .. "Point")
		applyIcons(state.group, config)

		state.interrupts.active = enabled and config[side .. "SeparateInterrupts"]
		state.interrupts.growth = config[side .. "InterruptGrowth"]
		ns.ApplyPoint(state.interrupts, "groupCooldowns." .. side .. "InterruptPoint")
		applyIcons(state.interrupts, config)

		for i = 1, #state.frames do
			local panel = state.frames[i]
			panel.active = enabled and byFrames
			panel.growth = SIDES[side].frameSide
			ns.ApplyPoint(panel, panel.pointPath)
			applyIcons(panel, config)
		end
		update(state)
	end
end

local function newPanel(side, kind)
	local panel = CreateFrame("Frame", nil, UIParent)
	panel:SetFrameStrata("LOW")
	panel:Hide()
	panel.side = side
	panel.kind = kind
	panel.icons = {}
	panel.labels = {}
	panel.untilCheck = 0
	panel.nextExpiry = huge
	return panel
end

local function createGroupPanel(self, state)
	local side = state.side
	local panel = newPanel(side, "group")
	panel.owners = state.owners
	self:RegisterMover(panel, "groupCooldowns." .. side .. "Point", SIDES[side].label, {
		enabledPath = { "groupCooldowns." .. side, "groupCooldowns." .. side .. "Layout" },
		context = side == "enemy" and "arena" or nil,
		visible = function()
			return not usesFrames(side)
		end,
		insets = function()
			local width = 0
			for _, label in pairs(panel.labels) do
				if label:IsShown() then
					width = max(width, label:GetStringWidth() + LABEL_GAP)
				end
			end
			if select(2, anchorFor(panel)) == 1 then
				return width, 0, 0, 0
			end
			return 0, width, 0, 0
		end,
	})
	return panel
end

local function createInterruptPanel(self, state)
	local side = state.side
	local panel = newPanel(side, "interrupts")
	panel.owners = state.owners
	self:RegisterMover(panel, "groupCooldowns." .. side .. "InterruptPoint", SIDES[side].interruptLabel, {
		enabledPath = { "groupCooldowns." .. side, "groupCooldowns." .. side .. "SeparateInterrupts" },
		context = side == "enemy" and "arena" or nil,
	})
	return panel
end

local function createFramePanels()
	for side, state in pairs(sides) do
		local info = SIDES[side]
		local frames = UF.groupFrames and UF.groupFrames[info.frames]
		for i = 1, frames and #frames or 0 do
			local panel = newPanel(side, "frame")
			panel.frame = frames[i]
			panel.index = i
			panel.owners = {}
			panel.pointPath = "groupCooldowns." .. info.frames .. i .. "Point"
			state.frames[i] = panel
			GroupCooldowns:RegisterMover(panel, panel.pointPath, info.frameLabel .. " " .. i .. " cooldowns", {
				enabledPath = {
					"groupCooldowns." .. side,
					"groupCooldowns." .. side .. "Layout",
					"unitFrames.show" .. info.frameLabel,
				},
				context = side == "enemy" and "arena" or nil,
				visible = function()
					return usesFrames(side)
				end,
			})
			local function onFrameShown()
				if panel.active then
					refresh(panel)
				end
			end
			frames[i]:HookScript("OnShow", onFrameShown)
			frames[i]:HookScript("OnHide", onFrameShown)
		end
	end
end

local initialized = false

UF:OnInitialize(function()
	framesReady = true
	if initialized then
		createFramePanels()
		applyConfig()
	end
end)

function GroupCooldowns:Initialize()
	for side in pairs(SIDES) do
		local state = { side = side, owners = {}, slots = {}, previewSlots = {}, frames = {} }
		sides[side] = state
		state.group = createGroupPanel(self, state)
		state.interrupts = createInterruptPanel(self, state)
	end
	initialized = true
	if framesReady then
		createFramePanels()
	end
	applyConfig()
	self:WatchConfig("groupCooldowns", applyConfig)

	self:RegisterEvent(ns.COOLDOWN_UPDATED, onCooldownUpdated)
	self:RegisterEvent(ns.TALENTS_UPDATED, onCooldownUpdated)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ARENA_OPPONENT_UPDATE")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("UNIT_NAME_UPDATE", onNameUpdate)

	hooksecurefunc(UF, "SetTestMode", function()
		GroupCooldowns.SetPreview(UF.testing)
	end)
end
