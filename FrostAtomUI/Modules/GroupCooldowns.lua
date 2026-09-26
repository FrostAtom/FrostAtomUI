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
	cc = L["Control"],
	mobility = L["Mobility"],
	utility = L["Utility"],
}
GroupCooldowns.CATEGORY_NAMES = CATEGORY_NAMES

local CATEGORY_COLORS = {
	defensive = { 0.35, 0.9, 0.35 },
	offensive = { 1, 0.35, 0.3 },
	interrupt = { 0.4, 0.7, 1 },
	cc = { 0.85, 0.5, 1 },
	mobility = { 0.4, 0.95, 0.9 },
	utility = { 0.75, 0.75, 0.75 },
}
GroupCooldowns.CATEGORY_COLORS = CATEGORY_COLORS

local SIDES = {
	friendly = { units = { "party1", "party2", "party3", "party4" }, label = "Ally cooldowns" },
	enemy = { units = { "arena1", "arena2", "arena3", "arena4", "arena5" }, label = "Enemy cooldowns" },
}

local panels = {}
local previewing = false

function GroupCooldowns.IsSpellShown(id)
	local override = ns.Config.groupCooldowns.spells[id]
	if override ~= nil then
		return override
	end
	local info = CooldownTracker:GetInfo(id)
	return not (info and info.hidden)
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

local function createIcon(panel)
	local icon = CreateFrame("Frame", nil, panel)
	icon:SetFrameLevel(panel:GetFrameLevel() + 1)
	icon:EnableMouse(not ns.Config.groupCooldowns.clickThrough)
	icon:SetScript("OnEnter", onIconEnter)
	icon:SetScript("OnLeave", onIconLeave)

	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetNonBlocking(true)
	UF.SkinIcon(icon, icon.texture)

	icon.cooldown = CreateFrame("Cooldown", nil, icon)
	icon.cooldown:SetAllPoints()
	CooldownTimer:Attach(icon.cooldown, ns.Config.groupCooldowns.size * FONT_SCALE, icon)
	CooldownTimer:AttachFlash(icon.cooldown, icon.texture, ns.Config.groupCooldowns, "readyFlash")

	icon.glow = icon:CreateTexture(nil, "OVERLAY")
	icon.glow:SetPoint("CENTER")
	icon.glow:SetTexture(GLOW_TEXTURE)
	icon.glow:SetBlendMode("ADD")
	icon.glow:Hide()

	setIconSize(icon, ns.Config.groupCooldowns.size)
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

local function collectSpells(owner, categories)
	local byCategory = owner.byCategory
	for _, list in pairs(byCategory) do
		wipe(list)
	end
	local tracked = owner.spells or CooldownTracker:GetTrackedFor(owner.guid, owner.class, owner.race, true)
	for i = 1, tracked and #tracked or 0 do
		local id = tracked[i]
		local category = categoryOf(id)
		if categories[category] and GroupCooldowns.IsSpellShown(id) then
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

function refresh(panel)
	local config = ns.Config.groupCooldowns
	local size, spacing = config.size, config.spacing
	local rowSpacing, perRow = config.rowSpacing, config.perRow
	local categories = config[panel.side .. "Categories"]
	local anchor, direction = anchorFor(panel)
	local owners = panel.owners

	for i = 1, #owners do
		collectSpells(owners[i], categories)
	end

	local used, rows, width = 0, 0, 0
	local nextExpiry = huge
	local now = GetTime()
	for c = 1, #CATEGORIES do
		local category = CATEGORIES[c]
		local count = 0
		local y = -rows * (size + rowSpacing)
		for i = 1, #owners do
			local owner = owners[i]
			local list = owner.byCategory[category]
			for j = 1, list and #list or 0 do
				local id = list[j]
				local x = count % perRow * (size + spacing)
				local line = rows + floor(count / perRow)
				count = count + 1
				used = used + 1
				local icon = acquireIcon(panel, used)
				icon:ClearAllPoints()
				icon:SetPoint(anchor, panel, anchor, direction * x, -line * (size + rowSpacing))
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
		local label = panel.labels[category]
		if count > 0 then
			width = max(width, min(count, perRow) * (size + spacing) - spacing)
			if config.labels then
				label = acquireLabel(panel, category)
				label:ClearAllPoints()
				if direction == 1 then
					label:SetPoint("RIGHT", panel, "TOPLEFT", -LABEL_GAP, y - size / 2)
				else
					label:SetPoint("LEFT", panel, "TOPRIGHT", LABEL_GAP, y - size / 2)
				end
				label:Show()
			elseif label then
				label:Hide()
			end
			rows = rows + ceil(count / perRow)
		elseif label then
			label:Hide()
		end
	end

	for i = used + 1, #panel.icons do
		local icon = panel.icons[i]
		icon:Hide()
		icon.owner = nil
	end

	panel:SetSize(max(width, size), max(rows * (size + rowSpacing) - rowSpacing, size))
	ns.SetShown(panel, panel.enabled and used > 0)

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

local function collectOwners(panel)
	local owners = panel.owners
	wipe(owners)
	local slots = panel.slots
	local units = SIDES[panel.side].units
	for i = 1, #units do
		local unit = units[i]
		local slot = slots[i]
		if not slot then
			slot = newOwner()
			slots[i] = slot
		end
		slot.spells, slot.preview = nil, nil
		if panel.side == "friendly" then
			if not (UnitExists(unit) and readUnit(slot, unit)) then
				slot.guid = nil
			end
		else
			readUnit(slot, unit)
		end
		if slot.guid and slot.class then
			owners[#owners + 1] = slot
		end
	end
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

local PREVIEW_COUNTS = { friendly = 2, enemy = 3 }

local function collectPreview(panel)
	local owners = panel.owners
	wipe(owners)
	for i = 1, PREVIEW_COUNTS[panel.side] do
		local slot = panel.previewSlots[i]
		if not slot then
			slot = newOwner()
			panel.previewSlots[i] = slot
			randomPreviewOwner(slot)
		end
		owners[#owners + 1] = slot
	end
end

local function update(panel)
	if previewing then
		collectPreview(panel)
	else
		collectOwners(panel)
	end
	refresh(panel)
end

local function updateAll()
	for _, panel in pairs(panels) do
		update(panel)
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

local function onCooldownUpdated(_, guid)
	if previewing then
		return
	end
	for _, panel in pairs(panels) do
		if guid == nil or ownsGUID(panel, guid) then
			refresh(panel)
		end
	end
end

local function clearEnemies()
	local panel = panels.enemy
	for i = 1, #panel.slots do
		panel.slots[i].guid = nil
	end
end

function GroupCooldowns:PLAYER_ENTERING_WORLD()
	clearEnemies()
	updateAll()
end

function GroupCooldowns:ARENA_OPPONENT_UPDATE(unit, kind)
	local index = tonumber(unit and unit:match("^arena(%d)$"))
	local slot = index and panels.enemy.slots[index]
	if slot and kind == "cleared" then
		slot.guid = nil
	end
	if not previewing then
		update(panels.enemy)
	end
end

function GroupCooldowns:PARTY_MEMBERS_CHANGED()
	if not previewing then
		update(panels.friendly)
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
		update(panels[side])
	end
end

function GroupCooldowns.SetPreview(enabled)
	enabled = enabled and true or false
	if enabled == previewing then
		return
	end
	previewing = enabled
	for _, panel in pairs(panels) do
		wipe(panel.previewSlots)
	end
	updateAll()
end

function GroupCooldowns.IsPreviewing()
	return previewing
end

local function applyConfig()
	local config = ns.Config.groupCooldowns
	for side, panel in pairs(panels) do
		panel.enabled = config.enabled and config[side]
		panel.growth = config[side .. "Growth"]
		ns.ApplyPoint(panel, "groupCooldowns." .. side .. "Point")
		for i = 1, #panel.icons do
			local icon = panel.icons[i]
			setIconSize(icon, config.size)
			icon:EnableMouse(not config.clickThrough)
			icon.owner = nil
		end
		update(panel)
	end
end

local function createPanel(self, side)
	local panel = CreateFrame("Frame", nil, UIParent)
	panel:SetFrameStrata("LOW")
	panel:Hide()
	panel.side = side
	panel.icons = {}
	panel.labels = {}
	panel.owners = {}
	panel.slots = {}
	panel.previewSlots = {}
	panel.untilCheck = 0
	panel.nextExpiry = huge
	panels[side] = panel
	self:RegisterMover(panel, "groupCooldowns." .. side .. "Point", SIDES[side].label, {
		enabledPath = "groupCooldowns." .. side,
		context = side == "enemy" and "arena" or nil,
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

function GroupCooldowns:Initialize()
	createPanel(self, "friendly")
	createPanel(self, "enemy")
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
