local _, ns = ...

local CreateFrame = CreateFrame
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemDurability = GetInventoryItemDurability
local GetItemInfo = GetItemInfo
local ColorGradient = ns.ColorGradient
local min, pi = math.min, math.pi

local Misc = ns:GetModule("Misc")

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

local function itemLevelColor(difference)
	if difference >= 0 then
		return 0.1, 1, 0.1
	end
	return ColorGradient(pi / -difference, 1, 0.1, 0.1, 1, 1, 0.1, 0.1, 1, 0.1)
end

local function slotItemLevel(unit, slot)
	local link = GetInventoryItemLink(unit, slot)
	if not link then
		return nil, GetInventoryItemTexture(unit, slot) ~= nil
	end
	local _, _, _, itemLevel = GetItemInfo(link)
	return itemLevel and itemLevel > 0 and itemLevel or nil, itemLevel == nil
end

local function averageItemLevel(unit, slotTexts)
	local total, count, missing = 0, 0, false
	for slot in pairs(SLOT_NAMES) do
		local itemLevel, pending = slotItemLevel(unit, slot)
		if slotTexts and slotTexts[slot] then
			slotTexts[slot].itemLevel = itemLevel
		end
		if itemLevel then
			total = total + itemLevel
			count = count + 1
		end
		missing = missing or pending
	end
	return count > 0 and total / count or 0, count, missing
end
ns.UnitAverageItemLevel = averageItemLevel

local function updatePage(page)
	local unit = page.getUnit()
	if not unit then
		return
	end

	local average, count, missing = averageItemLevel(unit, page.slotTexts)
	for _, text in pairs(page.slotTexts) do
		if text.itemLevel then
			text:SetText(text.itemLevel)
			text:SetTextColor(itemLevelColor(text.itemLevel - average))
		else
			text:SetText("")
		end
	end
	page.averageText:SetText(count > 0 and ("%.1f"):format(average) or "")

	if missing and page.retries < MAX_RETRIES then
		page.retries = page.retries + 1
		page.retry:Show()
	elseif not missing then
		page.retries = 0
	end
end

local function createPage(getUnit, modelFrame, slotPrefix, anchor)
	local page = { getUnit = getUnit, slotTexts = {}, retries = 0 }

	for slot, suffix in pairs(SLOT_NAMES) do
		local button = _G[slotPrefix .. suffix]
		if button then
			local text = button:CreateFontString(nil, "OVERLAY")
			text:SetFont(ns.Media.font, 11, "OUTLINE")
			text:SetPoint("BOTTOM", 0, 1)
			page.slotTexts[slot] = text
		end
	end

	local overlay = CreateFrame("Frame", nil, modelFrame)
	overlay:SetSize(60, 16)
	overlay:SetPoint("BOTTOMRIGHT", unpack(anchor))
	overlay:SetFrameLevel(modelFrame:GetFrameLevel() + 1)

	local averageText = overlay:CreateFontString(nil, "OVERLAY")
	averageText:SetFont(ns.Media.fontBold, 14, "OUTLINE")
	averageText:SetPoint("BOTTOMRIGHT")
	averageText:SetTextColor(1, 0.9, 0.8)
	page.averageText = averageText

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
end, CharacterModelFrame, "Character", { PlayerStatFrameRightDropDown, "TOPRIGHT", -18, -2 })

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
	end, InspectModelFrame, "Inspect", { InspectModelFrame, "BOTTOMRIGHT", -4, 4 })

	hooksecurefunc("InspectPaperDollItemSlotButton_Update", function()
		if InspectFrame:IsShown() then
			inspect.retry:Show()
		end
	end)
	InspectPaperDollFrame:HookScript("OnShow", function()
		updatePage(inspect)
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
	local lowest = lowestDurability()
	if lowest < ns.Config.durabilityWarning then
		if not warned then
			warned = true
			ns.Print("|cffff0000durability %d%%|r - repair soon", lowest * 100)
		end
	else
		warned = false
	end
end

Misc:RegisterEvent("UPDATE_INVENTORY_DURABILITY", checkDurability)
Misc:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", checkDurability)
