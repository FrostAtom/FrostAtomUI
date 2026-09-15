local _, ns = ...

-- Item levels in the character and inspect windows: on every slot, colored
-- relative to the average (green at or above, red far below), plus the
-- average in the corner of the model. Also a chat warning when an equipped
-- item is about to break.

local CreateFrame = CreateFrame
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemDurability = GetInventoryItemDurability
local GetItemInfo = GetItemInfo
local ColorGradient = ns.ColorGradient

local Misc = ns:GetModule("Misc")

-- Slot id -> Blizzard button suffix. Shirt (4) and tabard (19) are skipped.
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

local RETRY_DELAY = 0.3 -- item info may not be cached yet (inspect)
local MAX_RETRIES = 10

--------------------------------------------------
-- Colors (ElvUI's palette): green when at/above the average, fading
-- through yellow to red the further below it the item is.

local function itemLevelColor(difference)
	if difference >= 0 then
		return 0.1, 1, 0.1
	end
	return ColorGradient(math.pi / -difference, 1, 0.1, 0.1, 1, 1, 0.1, 0.1, 1, 0.1)
end

--------------------------------------------------
-- Pages: "Character" (player) and "Inspect" (InspectFrame.unit)

local pages = {}

local function slotItemLevel(unit, slot)
	local link = GetInventoryItemLink(unit, slot)
	if not link then
		-- A texture without a link: the item is not in the cache yet.
		return nil, GetInventoryItemTexture(unit, slot) ~= nil
	end
	local _, _, _, itemLevel = GetItemInfo(link)
	return itemLevel and itemLevel > 0 and itemLevel or nil, itemLevel == nil
end

local function updatePage(page)
	local unit = page.getUnit()
	if not unit then
		return
	end

	local total, count, missing = 0, 0, false
	for slot, text in pairs(page.slotTexts) do
		local itemLevel, pending = slotItemLevel(unit, slot)
		text.itemLevel = itemLevel
		if itemLevel then
			total = total + itemLevel
			count = count + 1
		end
		missing = missing or pending
	end

	local average = count > 0 and total / count or 0
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

-- `anchor` is { relativeTo, relativePoint, x, y } for the text's bottom right.
local function createPage(name, getUnit, modelFrame, slotPrefix, anchor)
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

	-- A Model draws over its own regions, so the text lives on a child frame.
	-- A Model draws over its own regions, so the text lives on a small child
	-- frame whose bottom right corner is placed by `anchor`.
	local overlay = CreateFrame("Frame", nil, modelFrame)
	overlay:SetSize(60, 16)
	overlay:SetPoint("BOTTOMRIGHT", unpack(anchor))
	overlay:SetFrameLevel(modelFrame:GetFrameLevel() + 1)

	local averageText = overlay:CreateFontString(nil, "OVERLAY")
	averageText:SetFont(ns.Media.fontBold, 14, "OUTLINE")
	averageText:SetPoint("BOTTOMRIGHT")
	averageText:SetTextColor(1, 0.9, 0.8)
	page.averageText = averageText

	-- Re-runs the update a moment later while item data is still loading.
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

	pages[name] = page
	return page
end

--------------------------------------------------
-- Character

-- The stat dropdowns cover the bottom of the model, so the text sits right
-- above the right one (the dropdown template has empty padding on top).
local character = createPage("Character", function()
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

--------------------------------------------------
-- Inspect (Blizzard_InspectUI is load-on-demand)

ns:OnAddonLoaded("Blizzard_InspectUI", function()
	-- Nothing overlaps the inspect model: plain bottom right corner.
	local inspect = createPage("Inspect", function()
		return InspectFrame.unit
	end, InspectModelFrame, "Inspect", { InspectModelFrame, "BOTTOMRIGHT", -4, 4 })

	-- Blizzard refreshes every slot through this when the data arrives.
	hooksecurefunc("InspectPaperDollItemSlotButton_Update", function()
		if InspectFrame:IsShown() then
			inspect.retry:Show()
		end
	end)
	InspectPaperDollFrame:HookScript("OnShow", function()
		updatePage(inspect)
	end)
end)

--------------------------------------------------
-- Durability

local warned = false

local function lowestDurability()
	local lowest = 1
	for _, slot in ipairs(DURABILITY_SLOTS) do
		local current, max = GetInventoryItemDurability(slot)
		if current and max and max > 0 then
			lowest = math.min(lowest, current / max)
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
