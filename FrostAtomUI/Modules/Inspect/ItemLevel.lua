local _, ns = ...

local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfo = GetItemInfo
local UnitGUID = UnitGUID
local UnitIsUnit = UnitIsUnit
local ColorGradient = ns.ColorGradient
local pi = math.pi

local ItemLevel = ns:NewModule("ItemLevel")
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
ns.EquipmentSlots = SLOT_NAMES

local function itemLevelColor(difference)
	if difference >= 0 then
		return 0.1, 1, 0.1
	end
	return ColorGradient(pi / -difference, 1, 0.1, 0.1, 1, 1, 0.1, 0.1, 1, 0.1)
end
ns.ItemLevelDifferenceColor = itemLevelColor

local QUALITY_TIERS = { { 264, 5 }, { 245, 4 }, { 220, 3 }, { 200, 2 } }

local function averageQualityColor(average)
	local quality = 1
	for i = 1, #QUALITY_TIERS do
		local tier = QUALITY_TIERS[i]
		if average >= tier[1] then
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

ItemLevel:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
	if unit ~= "player" and scanGuid and UnitGUID(unit) == scanGuid then
		wipe(scanCache)
	end
end)
