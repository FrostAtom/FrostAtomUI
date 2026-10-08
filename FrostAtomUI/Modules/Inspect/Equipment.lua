local _, ns = ...

local L = ns.L

local GetInventoryItemDurability = GetInventoryItemDurability
local UnitGUID = UnitGUID
local min = math.min
local averageItemLevel, itemLevelColor = ns.UnitAverageItemLevel, ns.ItemLevelDifferenceColor
local averageQualityColor = ns.AverageItemLevelColor

local Equipment = ns:NewModule("Equipment")
local Inspect = ns:GetModule("Inspect")

local SLOT_NAMES = ns.EquipmentSlots
local DURABILITY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

local RETRY_DELAY = 0.3
local MAX_RETRIES = 10
local INSPECT_FALLBACK = 1.5

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

Equipment:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
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

	Equipment:RegisterEvent(ns.E.INSPECT_GEAR_READY, function(_, guid)
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
		local current, maximum = GetInventoryItemDurability(DURABILITY_SLOTS[i])
		if current and maximum and maximum > 0 then
			lowest = min(lowest, current / maximum)
		end
	end
	return lowest
end

local function checkDurability()
	local config = ns.Config.equipment
	local lowest = lowestDurability()
	if config.enabled and lowest < config.durabilityThreshold then
		if not warned then
			warned = true
			ns.Print(L["|cffff0000durability %d%%|r - repair soon"], lowest * 100)
		end
	else
		warned = false
	end
end

Equipment:RegisterEvent("UPDATE_INVENTORY_DURABILITY", checkDurability)
Equipment:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", checkDurability)

Equipment:WatchConfig("equipment", function()
	for i = 1, #pages do
		applyFonts(pages[i])
	end
	if PaperDollFrame:IsShown() then
		updatePage(character)
	end
	checkDurability()
end)
