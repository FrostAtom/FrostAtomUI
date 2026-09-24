local _, ns = ...

local L = ns.L

local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemDurability = GetInventoryItemDurability
local GetItemInfo = GetItemInfo
local UnitGUID = UnitGUID
local UnitIsUnit = UnitIsUnit
local ColorGradient = ns.ColorGradient
local min, pi = math.min, math.pi

local Misc = ns:GetModule("Misc")
local Inspect = ns:GetModule("Inspect")

local SLOT_NAMES = {
	[1] = "HeadSlot",
	[2] = "NeckSlot",
	[3] = "ShoulderSlot",
	[5] = "ChestSlot",
	[6] = "WaistSlot",
	[7] = "LegsSlot",
	[8] = "FeetSlot",
	[9] = "WristSlot",
	[10] = "HandsSlot",
	[11] = "Finger0Slot",
	[12] = "Finger1Slot",
	[13] = "Trinket0Slot",
	[14] = "Trinket1Slot",
	[15] = "BackSlot",
	[16] = "MainHandSlot",
	[17] = "SecondaryHandSlot",
	[18] = "RangedSlot",
}
local DURABILITY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

local RETRY_DELAY = 0.3
local MAX_RETRIES = 10
local INSPECT_FALLBACK = 1.5

local function itemLevelColor(difference)
	if difference >= 0 then
		return 0.1, 1, 0.1
	end
	return ColorGradient(pi / -difference, 1, 0.1, 0.1, 1, 1, 0.1, 0.1, 1, 0.1)
end

local QUALITY_TIERS = { { "legendary", 5 }, { "epic", 4 }, { "rare", 3 }, { "uncommon", 2 } }

local function averageQualityColor(average)
	local thresholds = ns.Config.equipment.qualityThresholds
	local quality = 1
	for i = 1, #QUALITY_TIERS do
		local tier = QUALITY_TIERS[i]
		if average >= thresholds[tier[1]] then
			quality = tier[2]
			break
		end
	end
	local color = ITEM_QUALITY_COLORS[quality]
	return color.r, color.g, color.b, color.hex
end
ns.AverageItemLevelColor = averageQualityColor

local ITEM_LEVEL_PREFIX = ITEM_LEVEL:gsub("%%d.*", "")
local SCAN_TOOLTIP_NAME = "FrostAtomUIItemLevelScanTooltip"

local scanTooltip, scanLines
local scanCache, scanGuid, scanStamp = {}, nil, nil
local savedCVar

local function scanSlot(unit, slot)
	if not scanTooltip then
		scanTooltip = CreateFrame("GameTooltip", SCAN_TOOLTIP_NAME, nil, "GameTooltipTemplate")
		scanLines = {}
	end
	if not savedCVar then
		savedCVar = GetCVar("showItemLevel")
		if savedCVar ~= "1" then
			SetCVar("showItemLevel", "1")
		end
	end
	scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTooltip:SetInventoryItem(unit, slot)
	local itemLevel
	for i = 2, scanTooltip:NumLines() do
		local line = scanLines[i]
		if not line then
			line = _G[SCAN_TOOLTIP_NAME .. "TextLeft" .. i]
			scanLines[i] = line
		end
		local text = line:GetText()
		if text and text:sub(1, #ITEM_LEVEL_PREFIX) == ITEM_LEVEL_PREFIX then
			itemLevel = tonumber(text:match("%d+", #ITEM_LEVEL_PREFIX + 1))
			break
		end
	end
	scanTooltip:Hide()
	return itemLevel
end

local function slotItemLevel(unit, slot, scan)
	local link = GetInventoryItemLink(unit, slot)
	local scanPending = false
	if scan and (link or GetInventoryItemTexture(unit, slot)) then
		local itemLevel = scanCache[slot] or scanSlot(unit, slot)
		if itemLevel and itemLevel > 0 then
			scanCache[slot] = itemLevel
			return itemLevel, false
		end
		scanPending = true
	end
	if not link then
		return nil, GetInventoryItemTexture(unit, slot) ~= nil
	end
	local _, _, _, itemLevel = GetItemInfo(link)
	return itemLevel and itemLevel > 0 and itemLevel or nil, scanPending or itemLevel == nil
end

local function averageItemLevel(unit, slotTexts)
	local total, count, missing = 0, 0, false
	local scan = not UnitIsUnit(unit, "player")
	if scan then
		local guid = UnitGUID(unit)
		local stamp = Inspect:GetTime(guid)
		if guid ~= scanGuid or stamp ~= scanStamp then
			wipe(scanCache)
			scanGuid, scanStamp = guid, stamp
		end
	end
	for slot in pairs(SLOT_NAMES) do
		local itemLevel, pending = slotItemLevel(unit, slot, scan)
		if slotTexts and slotTexts[slot] then
			slotTexts[slot].itemLevel = itemLevel
		end
		if itemLevel then
			total = total + itemLevel
			count = count + 1
		end
		missing = missing or pending
	end
	if savedCVar then
		if savedCVar ~= "1" then
			SetCVar("showItemLevel", savedCVar)
		end
		savedCVar = nil
	end
	return count > 0 and total / count or 0, count, missing
end
ns.UnitAverageItemLevel = averageItemLevel

Misc:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
	if unit ~= "player" and scanGuid and UnitGUID(unit) == scanGuid then
		wipe(scanCache)
	end
end)

local function clearPage(page)
	for _, text in pairs(page.slotTexts) do
		text:SetText("")
	end
	page.averageText:SetText("")
	page.retry:Hide()
end

local function updatePage(page)
	local unit = page.getUnit()
	if not unit or not page.ready then
		return
	end

	local config = ns.Config.equipment
	local show = config.enabled and config.showItemLevels
	local average, count, missing = averageItemLevel(unit, page.slotTexts)
	for _, text in pairs(page.slotTexts) do
		if text.itemLevel and show then
			text:SetText(text.itemLevel)
			text:SetTextColor(itemLevelColor(text.itemLevel - average))
		else
			text:SetText("")
		end
	end
	if show and count > 0 then
		page.averageText:SetFormattedText("%.1f", average)
		page.averageText:SetTextColor(averageQualityColor(average))
	else
		page.averageText:SetText("")
	end

	if missing and page.retries < MAX_RETRIES then
		page.retries = page.retries + 1
		page.retry:Show()
	elseif not missing then
		page.retries = 0
	end
end

local pages = {}

local function applyFonts(page)
	local config = ns.Config.equipment
	local slotFont, averageFont = config.slotFont, config.averageFont
	for _, text in pairs(page.slotTexts) do
		ns.SetFont(text, slotFont.size, slotFont.outline)
	end
	ns.SetFont(page.averageText, averageFont.size, averageFont.outline, true)
end

local function createPage(getUnit, modelFrame, slotPrefix, anchor)
	local page = { getUnit = getUnit, slotTexts = {}, retries = 0, ready = true }
	pages[#pages + 1] = page

	for slot, suffix in pairs(SLOT_NAMES) do
		local button = _G[slotPrefix .. suffix]
		if button then
			local text = button:CreateFontString(nil, "OVERLAY")
			text:SetPoint("BOTTOM", 0, 1)
			page.slotTexts[slot] = text
		end
	end

	local overlay = CreateFrame("Frame", nil, modelFrame)
	overlay:SetSize(60, 16)
	overlay:SetPoint("BOTTOMRIGHT", unpack(anchor))
	overlay:SetFrameLevel(modelFrame:GetFrameLevel() + 1)

	local averageText = overlay:CreateFontString(nil, "OVERLAY")
	averageText:SetPoint("BOTTOMRIGHT")
	page.averageText = averageText
	applyFonts(page)

	local retry = CreateFrame("Frame")
	retry:Hide()
	retry:SetScript("OnShow", function(self)
		self.remain = RETRY_DELAY
	end)
	retry:SetScript("OnUpdate", function(self, elapsed)
		self.remain = self.remain - elapsed
		if self.remain <= 0 then
			self:Hide()
			updatePage(page)
		end
	end)
	page.retry = retry

	return page
end

local character = createPage(function()
	return "player"
end, CharacterModelFrame, "Character", { CharacterModelFrame, "BOTTOMRIGHT", -6, 27 })

PaperDollFrame:HookScript("OnShow", function()
	updatePage(character)
end)

Misc:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
	if PaperDollFrame:IsShown() then
		updatePage(character)
	end
end)

ns:OnAddonLoaded("Blizzard_InspectUI", function()
	local inspect = createPage(function()
		return InspectFrame.unit
	end, InspectModelFrame, "Inspect", { InspectModelFrame, "BOTTOMRIGHT", -2, -14 })

	local waitToken = 0

	local function markReady()
		inspect.ready = true
		inspect.retries = 0
		updatePage(inspect)
	end

	local function fallback(token)
		if token == waitToken and not inspect.ready and InspectPaperDollFrame:IsVisible() then
			markReady()
		end
	end

	local function beginInspect()
		local unit = InspectFrame.unit
		if unit and Inspect:IsLoaded(UnitGUID(unit)) then
			markReady()
			return
		end
		inspect.ready = false
		waitToken = waitToken + 1
		clearPage(inspect)
		ns.After(INSPECT_FALLBACK, fallback, waitToken)
	end

	hooksecurefunc("InspectPaperDollItemSlotButton_Update", function()
		if inspect.ready and InspectFrame:IsShown() then
			inspect.retry:Show()
		end
	end)
	hooksecurefunc("InspectPaperDollFrame_OnShow", beginInspect)
	InspectPaperDollFrame:HookScript("OnShow", beginInspect)

	Misc:RegisterEvent(ns.INSPECT_GEAR_READY, function(_, guid)
		local unit = InspectFrame.unit
		if unit and UnitGUID(unit) == guid and InspectPaperDollFrame:IsVisible() then
			markReady()
		end
	end)
end)

local warned = false

local function lowestDurability()
	local lowest = 1
	for i = 1, #DURABILITY_SLOTS do
		local current, max = GetInventoryItemDurability(DURABILITY_SLOTS[i])
		if current and max and max > 0 then
			lowest = min(lowest, current / max)
		end
	end
	return lowest
end

local function checkDurability()
	local config = ns.Config.equipment
	local lowest = lowestDurability()
	if config.enabled and config.durabilityWarning and lowest < config.durabilityThreshold then
		if not warned then
			warned = true
			ns.Print(L["|cffff0000durability %d%%|r - repair soon"], lowest * 100)
		end
	else
		warned = false
	end
end

Misc:RegisterEvent("UPDATE_INVENTORY_DURABILITY", checkDurability)
Misc:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", checkDurability)

Misc:WatchConfig("equipment", function()
	for i = 1, #pages do
		applyFonts(pages[i])
	end
	if PaperDollFrame:IsShown() then
		updatePage(character)
	end
	checkDurability()
end)
