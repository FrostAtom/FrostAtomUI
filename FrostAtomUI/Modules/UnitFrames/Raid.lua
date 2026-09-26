local ADDON_NAME, ns = ...
local UF = ns:GetModule("UnitFrames")

local InCombatLockdown = InCombatLockdown
local UnitInRange = UnitInRange
local UnitPowerType, UnitClass, UnitGUID = UnitPowerType, UnitClass, UnitGUID
local IsInInstance = IsInInstance
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local UnitFrame_OnEnter, UnitFrame_OnLeave = UnitFrame_OnEnter, UnitFrame_OnLeave
local floor, ceil, min, random = math.floor, math.ceil, math.min, math.random

local HEADER_NAME = ADDON_NAME .. "RaidHeader"
local HOLDER_NAME = ADDON_NAME .. "RaidFrames"
local MAX_UNITS = 40
local MAX_BUFFS = 6
local INSET = 3
local BACKDROP = ns.CreateBackdrop(10, 2)
local RANGE_INTERVAL = 0.25
local RANGE_TICKER = "raidFramesRange"
local MANA = 0
local GROUP_ORDER = "1,2,3,4,5,6,7,8"
local CLASS_ORDER = "PRIEST,PALADIN,DRUID,SHAMAN,WARRIOR,DEATHKNIGHT,ROGUE,HUNTER,MAGE,WARLOCK"
local RIGHT_CLICK_ACTIONS = { menu = "menu", focus = "focus" }
local HEALER_TREES = {
	PRIEST = { true, true, false },
	PALADIN = { true, false, false },
	SHAMAN = { false, false, true },
	DRUID = { false, false, true },
}
local POWER_EVENTS = { "UNIT_MANA", "UNIT_RAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_RUNIC_POWER" }

local config = ns.Config.raidFrames
local ufConfig = ns.Config.unitFrames
local elements = UF.elements
local buttons = {}
local holder, header, Talents
local pending, testing, rangeActive = false, false, false

local function powerWanted(frame)
	local mode = config.power
	if mode == "all" then
		return true
	elseif mode == "none" then
		return false
	end
	local data = frame.test
	local powerType, class, spec
	if data then
		powerType, class, spec = data.powerType, data.class, data.spec
	else
		local unit = frame.unit
		powerType = UnitPowerType(unit)
		local _, unitClass = UnitClass(unit)
		class = unitClass
		if mode == "healers" and Talents then
			local guid = UnitGUID(unit)
			spec = guid and Talents:GetSpec(guid)
		end
	end
	if powerType ~= MANA then
		return false
	elseif mode == "mana" then
		return true
	end
	local trees = class and HEALER_TREES[class]
	return trees ~= nil and (spec == nil or trees[spec] == true)
end

local function layoutBars(frame, shown)
	frame.powerShown = shown
	local health = frame.health
	health:SetPoint("TOPLEFT", INSET, -INSET)
	health:SetPoint("BOTTOMRIGHT", -INSET, INSET + (shown and config.powerHeight or 0))
	ns.SetShown(frame.power, shown)
end

local function updatePowerLayout(frame)
	local shown = powerWanted(frame)
	if shown == frame.powerShown then
		return
	end
	layoutBars(frame, shown)
	if shown then
		if frame.test then
			elements.power.test(frame)
		else
			elements.power.update(frame)
		end
	end
end

UF:RegisterElement("raidpower", function()
	return true
end, updatePowerLayout, updatePowerLayout)

local function updatePower(frame)
	if frame.powerShown then
		elements.power.update(frame)
	end
end

local function updateHealthText(frame, current, max)
	local text = frame.health.text
	local mode = config.healthText
	if mode == "percent" and max > 0 then
		text:SetFormattedText("%d%%", floor(current / max * 100 + 0.5))
	elseif mode == "deficit" and current < max then
		text:SetFormattedText("-%s", ns.FormatValue(max - current))
	else
		text:SetText(nil)
	end
end

local function onEnter(frame)
	ns.SetShown(frame.hover, ufConfig.hoverHighlight)
	if not frame.test then
		UnitFrame_OnEnter(frame)
	end
end

local function onLeave(frame)
	frame.hover:Hide()
	UnitFrame_OnLeave(frame)
end

local function onShow(frame)
	frame.watched = true
	frame:UpdateAll()
end

local function onHide(frame)
	frame.watched = false
end

local function onAttributeChanged(frame, name, value)
	if name ~= "unit" then
		return
	end
	local unit = value or "none"
	if unit ~= frame.unit then
		frame:SetDisplayUnit(unit)
		if frame:IsShown() then
			frame:QueueUpdate()
		end
	end
end

local function styleButton(frame)
	frame:SetSize(config.width, config.height)
	local font = config.font
	local health = frame.health
	ns.SetFont(health.text, font.size, font.outline)
	ns.SetFont(frame.name, font.size, font.outline)
	frame.name.template = ("[name:%d%s]"):format(config.nameLength, config.nameClassColor and ":class" or "")
	health.colorMode = config.classColor and "class" or "health"
	health.colorClass = nil
	local raidIcon = frame.raidicon
	raidIcon.shown = config.raidIcon
	raidIcon.size = config.raidIconSize
	UF.LayoutRaidAuras(frame)
	layoutBars(frame, frame.powerShown or false)
end

local function colorButton(frame)
	UF.SetBackdropColors(frame)
	local r, g, b = unpack(ufConfig.textColor)
	frame.health.text:SetTextColor(r, g, b)
	frame.name:SetTextColor(r, g, b)
	frame.hover.texture:SetVertexColor(1, 1, 1, ufConfig.hoverAlpha)
end

local function setupButton(frame)
	ns.Mixin(frame, ns.EventMixin, UF.FrameMixin)
	frame.unit = "none"
	frame.baseUnit = "raid"
	frame.unitEvents = {}
	frame.watched = false

	frame:RegisterForClicks("AnyDown")
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", RIGHT_CLICK_ACTIONS[ufConfig.rightClick])
	frame:SetAttribute("*type3", "focus")
	frame:SetBackdrop(BACKDROP)

	local hover = CreateFrame("Frame", nil, frame)
	hover:SetFrameLevel(frame:GetFrameLevel() + 2)
	hover:SetPoint("TOPLEFT", INSET, -INSET)
	hover:SetPoint("BOTTOMRIGHT", -INSET, INSET)
	hover.texture = hover:CreateTexture(nil, "OVERLAY")
	hover.texture:SetAllPoints()
	hover.texture:SetTexture(ns.Media.blank)
	hover.texture:SetBlendMode("ADD")
	hover:Hide()
	frame.hover = hover

	local health = UF:AddElement(frame, "health")
	health:SetScript("OnUpdate", nil)
	health.SetValue = health.SnapValue
	health.noCutaway = true
	health.text:SetPoint("BOTTOMLEFT", 2, 1)
	frame.UpdateHealthText = updateHealthText

	local power = UF:AddElement(frame, "power")
	power:SetScript("OnUpdate", nil)
	power.SetValue = power.SnapValue
	power.text.template = ""
	power:SetPoint("TOPLEFT", health, "BOTTOMLEFT")
	power:SetPoint("BOTTOMRIGHT", -INSET, INSET)

	local name = UF:AddElement(frame, "name")
	name:SetPoint("TOP", health, 0, -2)

	UF:AddElement(frame, "highlight")
	local raidIcon = UF:AddElement(frame, "raidicon")
	raidIcon:SetPoint("CENTER", health, "TOP", 0, 0)
	UF:AddElement(frame, "raidauras", MAX_BUFFS)
	UF:AddElement(frame, "raidleader")
	UF:AddElement(frame, "raidpower")

	frame:RegisterUnitEvent("UNIT_HEALTH", elements.health.update)
	for i = 1, #POWER_EVENTS do
		frame:RegisterUnitEvent(POWER_EVENTS[i], updatePower)
	end
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", updatePowerLayout)

	frame:SetScript("OnEnter", onEnter)
	frame:SetScript("OnLeave", onLeave)
	frame:SetScript("OnShow", onShow)
	frame:SetScript("OnHide", onHide)
	frame:SetScript("OnAttributeChanged", onAttributeChanged)

	buttons[#buttons + 1] = frame
	styleButton(frame)
	colorButton(frame)
end

local function isVertical()
	return config.orientation ~= "horizontal"
end

local function columnCount()
	return min(config.columns, ceil(MAX_UNITS / config.unitsPerColumn))
end

local function footprint()
	local perColumn, columns = config.unitsPerColumn, columnCount()
	local width, height = config.width, config.height
	local spacing, groupSpacing = config.spacing, config.groupSpacing
	if isVertical() then
		return columns * width + (columns - 1) * groupSpacing, perColumn * height + (perColumn - 1) * spacing
	end
	return perColumn * width + (perColumn - 1) * spacing, columns * height + (columns - 1) * groupSpacing
end

local function setSort()
	local sort = config.sort
	if sort == "class" then
		header:SetAttribute("groupBy", "CLASS")
		header:SetAttribute("groupingOrder", CLASS_ORDER)
		header:SetAttribute("sortMethod", "NAME")
	elseif sort == "name" then
		header:SetAttribute("groupBy", nil)
		header:SetAttribute("groupingOrder", nil)
		header:SetAttribute("sortMethod", "NAME")
	else
		header:SetAttribute("groupBy", "GROUP")
		header:SetAttribute("groupingOrder", GROUP_ORDER)
		header:SetAttribute("sortMethod", "INDEX")
	end
end

local function setLayout()
	local down, right = config.growthY ~= "UP", config.growthX ~= "LEFT"
	local spacing = config.spacing
	if isVertical() then
		header:SetAttribute("point", down and "TOP" or "BOTTOM")
		header:SetAttribute("xOffset", 0)
		header:SetAttribute("yOffset", down and -spacing or spacing)
		header:SetAttribute("columnAnchorPoint", right and "LEFT" or "RIGHT")
	else
		header:SetAttribute("point", right and "LEFT" or "RIGHT")
		header:SetAttribute("xOffset", right and spacing or -spacing)
		header:SetAttribute("yOffset", 0)
		header:SetAttribute("columnAnchorPoint", down and "TOP" or "BOTTOM")
	end
	header:SetAttribute("columnSpacing", config.groupSpacing)
	header:SetAttribute("unitsPerColumn", config.unitsPerColumn)
	header:SetAttribute("maxColumns", columnCount())
	setSort()

	local corner = (down and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
	header:ClearAllPoints()
	header:SetPoint(corner, holder, corner)
	holder:SetSize(footprint())
	ns.ApplyPoint(holder, "raidFrames.point")
end

local function groupVisibility()
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" then
		return config.showInBattleground, config.showInParty
	end
	return config.showInRaid, config.showInParty
end

local function rosterCount()
	local raid = GetNumRaidMembers()
	if raid > 0 then
		return raid
	end
	local party = GetNumPartyMembers()
	if party > 0 then
		return party + (config.showPlayer and 1 or 0)
	end
	return 1
end

local function inGroup()
	return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

local function updateRange()
	local alpha = config.outOfRangeAlpha
	for i = 1, #buttons do
		local frame = buttons[i]
		if frame.watched then
			frame:SetAlpha(UnitInRange(frame.unit) and 1 or alpha)
		end
	end
end

local function setRangeActive(active)
	if active == rangeActive then
		return
	end
	rangeActive = active
	if active then
		ns.Scheduler.AddTicker(RANGE_TICKER, updateRange, RANGE_INTERVAL)
	else
		ns.Scheduler.RemoveTicker(RANGE_TICKER)
		for i = 1, #buttons do
			buttons[i]:SetAlpha(1)
		end
	end
end

local function setReplacesParty(replaces)
	replaces = replaces and true or false
	if (UF.raidReplacesParty or false) ~= replaces then
		UF.raidReplacesParty = replaces
		UF.ApplyVisibility()
	end
end

local function replacesParty(raid, party)
	if GetNumRaidMembers() > 0 then
		return raid or party
	end
	return party
end

local function runTest()
	for i = 1, #buttons do
		local frame = buttons[i]
		if frame:IsShown() then
			if frame.test then
				UF:RunTest(frame)
			else
				UF.StartTest(frame)
			end
			frame:SetAlpha(random(5) == 1 and config.outOfRangeAlpha or 1)
		else
			frame.test = nil
		end
	end
end

local function createHeader()
	holder = CreateFrame("Frame", HOLDER_NAME, UIParent)
	header = CreateFrame("Frame", HEADER_NAME, holder, "SecureGroupHeaderTemplate")
	header:SetAttribute("template", "SecureUnitButtonTemplate")
	header.initialConfigFunction = setupButton
	setLayout()
	header:Show()
	header:SetAttribute("startingIndex", 1 - MAX_UNITS)
	header:Hide()
	header:SetAttribute("startingIndex", 1)
	UF:RegisterMover(holder, "raidFrames.point", "Raid", { secure = true, context = "battleground" })
end

local function applyGroup()
	if not header or not config.enabled or testing then
		return
	end
	if InCombatLockdown() then
		pending = true
		return
	end
	local raid, party = groupVisibility()
	if header:GetAttribute("showRaid") ~= raid then
		header:SetAttribute("showRaid", raid)
	end
	if header:GetAttribute("showParty") ~= party then
		header:SetAttribute("showParty", party)
	end
	setReplacesParty(replacesParty(raid, party))
	setRangeActive(inGroup())
end

local function applyHeader()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	if not config.enabled then
		if header then
			holder:Hide()
		end
		setReplacesParty(false)
		setRangeActive(false)
		return
	end
	if not header then
		createHeader()
	end
	testing = UF.testing or false
	holder:Show()
	header:Hide()
	for i = 1, #buttons do
		local frame = buttons[i]
		if not testing then
			frame.test = nil
		end
		styleButton(frame)
	end
	setLayout()
	local raid, party = groupVisibility()
	header:SetAttribute("showRaid", testing or raid)
	header:SetAttribute("showParty", testing or party)
	header:SetAttribute("showPlayer", config.showPlayer)
	header:SetAttribute("showSolo", testing)
	header:SetAttribute("startingIndex", testing and rosterCount() - config.testCount + 1 or 1)
	header:Show()
	if testing then
		setRangeActive(false)
		runTest()
	else
		setRangeActive(inGroup())
	end
	setReplacesParty(replacesParty(raid, party))
end

local function applyColors()
	for i = 1, #buttons do
		local frame = buttons[i]
		colorButton(frame)
		frame.raidauras.dispel.debuffType = false
		if frame.test then
			UF:RunTest(frame)
		elseif frame:IsShown() then
			frame:UpdateAll()
		end
	end
end

local function applyClicks()
	local action = RIGHT_CLICK_ACTIONS[ufConfig.rightClick]
	for i = 1, #buttons do
		buttons[i]:SetAttribute("*type2", action)
	end
end

local function onTestMode()
	if (UF.testing or false) ~= testing and not InCombatLockdown() then
		applyHeader()
	end
end

local function onCombatEnd()
	if pending then
		applyHeader()
	end
end

UF:OnInitialize(function(self)
	Talents = ns:GetModule("Talents")
	hooksecurefunc(self, "SetTestMode", onTestMode)
	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD",
		"ZONE_CHANGED_NEW_AREA",
		"PARTY_MEMBERS_CHANGED",
		"RAID_ROSTER_UPDATE",
	}) do
		self:RegisterEvent(event, applyGroup)
	end
	self:RegisterEvent("PLAYER_REGEN_ENABLED", onCombatEnd)
	applyHeader()
	self:WatchConfig("raidFrames", applyHeader, true)
	self:WatchConfig("unitFrames", applyColors)
	self:WatchConfig("dispelHighlightAlpha", applyColors)
	self:WatchConfig("unitFrames.rightClick", applyClicks, true)
end)
