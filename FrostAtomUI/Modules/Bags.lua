local _, ns = ...

local L = ns.L

local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemID = GetContainerItemID
local GetInventoryItemLink = GetInventoryItemLink
local ContainerIDToInventoryID = ContainerIDToInventoryID
local BankButtonIDToInvSlotID = BankButtonIDToInvSlotID
local GetMoney = GetMoney
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local NUM_BANKGENERIC_SLOTS = NUM_BANKGENERIC_SLOTS
local BACKPACK_CONTAINER = BACKPACK_CONTAINER
local BANK_CONTAINER = BANK_CONTAINER

local Bags = ns:NewModule("Bags")
Bags.configKey = "bags"

local P = {}
Bags.shared = P

local config = ns.Config.bags
local ROW_GAP = 6
local RETRY_DELAY = 0.5
local RETRY_TRIES = 3
local BAG_RECHECK_DELAY = 0.5
local LEVEL_UP_DELAY = 1

P.ROW_GAP = ROW_GAP
P.HEADER_HEIGHT = 20
P.BAG_BUTTON_SIZE = 20
P.GLOW_SCALE = 1.6
P.RETRY_TRIES = RETRY_TRIES

local INVENTORY_BAGS = { BACKPACK_CONTAINER, 1, 2, 3, 4 }
local BANK_BAGS = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }

local BagItems = ns.BagItems

local bagFrames = {}
local bagFamilies = {}
local bagSizes = {}
local dirtyBags = {}
local recheckPending = {}
local inventoryDirty = false
local newItems = {}
local searchResults = {}
local frames = {}
local slotLocks = {}
local savedLocks
local charKey, moneyKey
local retryScheduled = false

P.bagFrames = bagFrames
P.bagFamilies = bagFamilies
P.bagSizes = bagSizes
P.newItems = newItems
P.searchResults = searchResults
P.frames = frames
P.slotLocks = slotLocks
P.ContainerMixin = {}
P.searchText = ""
P.atBank = false
P.autoOpened = false
P.retryBudget = 0

local function bagInventorySlot(bag)
	if bag > NUM_BAG_SLOTS then
		return BankButtonIDToInvSlotID(bag, 1)
	elseif bag > BACKPACK_CONTAINER then
		return ContainerIDToInventoryID(bag)
	end
end
P.bagInventorySlot = bagInventorySlot

local function bagSize(bag)
	if bag == BANK_CONTAINER then
		return NUM_BANKGENERIC_SLOTS
	end
	local invSlot = bagInventorySlot(bag)
	if invSlot and not GetInventoryItemLink("player", invSlot) then
		return 0
	end
	return GetContainerNumSlots(bag)
end
Bags.BagSize = bagSize
P.bagSize = bagSize

local function isBankBag(bag)
	return bag == BANK_CONTAINER or bag > NUM_BAG_SLOTS
end

local function lockKey(bag, slot)
	return bag * 100 + slot
end
P.lockKey = lockKey

function Bags.IsSlotLocked(key)
	return slotLocks[key]
end

local function saveBankBag(bag)
	local bankCache = P.bankCache
	if not bankCache then
		return
	end
	local size = bagSize(bag)
	if size == 0 then
		bankCache[bag] = nil
		return
	end
	local entry = bankCache[bag]
	if not entry then
		entry = { items = {} }
		bankCache[bag] = entry
	end
	entry.size = size
	local invSlot = bagInventorySlot(bag)
	entry.link = invSlot and GetInventoryItemLink("player", invSlot) or nil

	local items = entry.items
	for slot in pairs(items) do
		if slot > size then
			items[slot] = nil
		end
	end
	for slot = 1, size do
		local link = GetContainerItemLink(bag, slot)
		if link then
			local _, count = GetContainerItemInfo(bag, slot)
			local item = items[slot]
			if item then
				item[1], item[2] = link, count or 1
			else
				items[slot] = { link, count or 1 }
			end
		else
			items[slot] = nil
		end
	end
end

local function saveBank()
	for i = 1, #BANK_BAGS do
		saveBankBag(BANK_BAGS[i])
	end
end

ns.Storage.Claim("gold", "Bags", "state")
ns.Storage.Claim("bagLocks", "Bags", "state")
ns.Storage.Claim("bankCache", "Bags", "state")

local function saveMoney()
	if not ns.Storage.IsLoaded() or not moneyKey then
		return
	end
	local gold = ns.Storage.Slot("gold"):Table()
	local entry = gold[moneyKey] or {}
	gold[moneyKey] = entry
	entry.money = GetMoney()
	entry.class = ns.PLAYER_CLASS
end

local lastCounts, currentCounts = {}, {}
local countsScanned = false

local function scanNewItems()
	wipe(currentCounts)
	for i = 1, #INVENTORY_BAGS do
		local bag = INVENTORY_BAGS[i]
		for slot = 1, bagSize(bag) do
			local itemId = GetContainerItemID(bag, slot)
			if itemId then
				local _, count = GetContainerItemInfo(bag, slot)
				currentCounts[itemId] = (currentCounts[itemId] or 0) + (count or 1)
			end
		end
	end

	if countsScanned then
		for itemId, count in pairs(currentCounts) do
			if count > (lastCounts[itemId] or 0) then
				newItems[itemId] = true
			end
		end
	end
	countsScanned = true
	lastCounts, currentCounts = currentCounts, lastCounts
end

local function forEachShownFrame(method, arg)
	for i = 1, #frames do
		local frame = frames[i]
		if frame:IsShown() then
			frame[method](frame, arg)
		end
	end
end

local function retryPending()
	retryScheduled = false
	forEachShownFrame("ForEachButton", "RetryPending")
end

local function scheduleRetry()
	if retryScheduled or P.retryBudget <= 0 then
		return
	end
	retryScheduled = true
	P.retryBudget = P.retryBudget - 1
	ns.After(RETRY_DELAY, retryPending)
end
P.scheduleRetry = scheduleRetry

local updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function(self)
	self:Hide()

	if inventoryDirty then
		inventoryDirty = false
		scanNewItems()
	end

	for bag in pairs(dirtyBags) do
		local frame = bagFrames[bag]
		if frame then
			frame:UpdateBag(bag)
		end
		if P.atBank and isBankBag(bag) then
			saveBankBag(bag)
		end
	end
	wipe(dirtyBags)
end)

local function markDirty(bag)
	dirtyBags[bag] = true
	if bag >= BACKPACK_CONTAINER and bag <= NUM_BAG_SLOTS then
		inventoryDirty = true
	end
	P.retryBudget = RETRY_TRIES
	updater:Show()
end

local function recheckBag(bag)
	recheckPending[bag] = nil
	markDirty(bag)
end

local function autoShow()
	if config.autoOpen and not P.inventory:IsShown() then
		P.autoOpened = true
		P.inventory:Show()
	end
end

local function autoHide()
	if P.autoOpened then
		P.inventory:Hide()
	end
end

local function updateCurrencies()
	if P.inventory:IsShown() then
		P.inventory:UpdateCurrencies()
	end
end

local function refreshItems()
	forEachShownFrame("ForEachButton", "Update")
end

local function refreshUsability()
	BagItems.ResetScans()
	wipe(searchResults)
	refreshItems()
end

local function refreshSortLocks()
	forEachShownFrame("ForEachButton", "UpdateSortLock")
end

function Bags:ToggleSlotLock(bag, slot)
	local key = lockKey(bag, slot)
	local locked = not slotLocks[key] or nil
	slotLocks[key] = locked
	savedLocks[bag .. ":" .. slot] = locked
	refreshSortLocks()
end

ns.API.RegisterAction("bagsClearSlotLocks", function()
	Bags:ClearSlotLocks()
end)

function Bags:ClearSlotLocks()
	wipe(slotLocks)
	if savedLocks then
		wipe(savedLocks)
		refreshSortLocks()
	end
end

function Bags:BAG_UPDATE(bag)
	markDirty(bag)
	if bag > BACKPACK_CONTAINER and not recheckPending[bag] then
		recheckPending[bag] = true
		ns.After(BAG_RECHECK_DELAY, recheckBag, bag)
	end
end

function Bags:BAG_UPDATE_COOLDOWN()
	forEachShownFrame("ForEachButton", "UpdateCooldown")
end

function Bags:ITEM_LOCK_CHANGED(bag, slot)
	if slot then
		local frame = bagFrames[bag]
		local offset = frame and frame.bagOffsets[bag]
		if offset and frame:IsShown() and not frame.offline and slot <= bagSizes[bag] then
			frame.buttons[offset + slot]:UpdateLock()
		end
		return
	end

	for i = 1, #frames do
		local frame = frames[i]
		if frame:IsShown() and not frame.offline then
			frame:UpdateBagButtons()
			frame:ForEachButton("UpdateLock")
		end
	end
end

function Bags:PLAYERBANKSLOTS_CHANGED(slot)
	if slot <= NUM_BANKGENERIC_SLOTS then
		markDirty(BANK_CONTAINER)
	else
		markDirty(NUM_BAG_SLOTS + slot - NUM_BANKGENERIC_SLOTS)
	end
end

function Bags:PLAYERBANKBAGSLOTS_CHANGED()
	if P.bank:IsShown() then
		P.bank:UpdateBagButtons()
	end
	if P.atBank then
		for i = 2, #BANK_BAGS do
			markDirty(BANK_BAGS[i])
		end
	end
end

function Bags:BANKFRAME_OPENED()
	P.atBank = true
	local bank = P.bank
	if bank:IsShown() then
		bank:SetOffline(false)
		bank:Layout()
	else
		bank:Show()
	end
	saveBank()
	autoShow()
end

function Bags:BANKFRAME_CLOSED()
	P.atBank = false
	P.bank:Hide()
	autoHide()
end

function Bags:PLAYER_MONEY()
	saveMoney()
	forEachShownFrame("UpdateInfo")
end

local function questLogChanged()
	for i = 1, #INVENTORY_BAGS do
		markDirty(INVENTORY_BAGS[i])
	end
end

local AUTO_SHOW_EVENTS = {
	MERCHANT_SHOW = "MERCHANT_CLOSED",
	MAIL_SHOW = "MAIL_CLOSED",
	AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED",
	TRADE_SHOW = "TRADE_CLOSED",
	GUILDBANKFRAME_OPENED = "GUILDBANKFRAME_CLOSED",
}

local blizzardToggleBag = ToggleBag

local function toggleBag(bag)
	local frame = bagFrames[bag]
	if not frame then
		return blizzardToggleBag(bag)
	end
	if frame == P.bank and not P.atBank then
		return
	end
	frame:Toggle()
end

local function toggleBackpack()
	P.inventory:Toggle()
end

local function openBackpack()
	P.inventory:Show()
end

local function closeBackpack()
	P.inventory:Hide()
end

local function openAllBags(forceOpen)
	if forceOpen then
		P.inventory:Show()
	else
		P.inventory:Toggle()
	end
end

local function closeAllBags()
	local inventory = P.inventory
	local wasShown = inventory:IsShown()
	inventory:Hide()
	return wasShown
end

local function loadSaved()
	local playerRealm = GetRealmName()
	P.playerRealm = playerRealm
	local name = UnitName("player")
	charKey = name .. " - " .. playerRealm
	moneyKey = playerRealm .. "|" .. name

	local locks = ns.Storage.Slot("bagLocks"):Table()
	savedLocks = locks[charKey] or {}
	locks[charKey] = savedLocks
	for key in pairs(savedLocks) do
		local bag, slot = key:match("^(-?%d+):(%d+)$")
		if bag then
			slotLocks[lockKey(tonumber(bag), tonumber(slot))] = true
		else
			savedLocks[key] = nil
		end
	end

	local caches = ns.Storage.Slot("bankCache"):Table()
	local bankCache = caches[charKey] or {}
	P.bankCache = bankCache
	caches[charKey] = bankCache
end

SlashCmdList.FROSTATOMUI_SORT = function(args)
	if not P.inventory then
		return
	end
	if strtrim(args or ""):lower() == "unlock" then
		Bags:ClearSlotLocks()
		ns.Print(L["all bag slot locks cleared"])
		return
	end
	Bags:SortBags(P.inventory)
end
SLASH_FROSTATOMUI_SORT1 = "/sort"

SlashCmdList.FROSTATOMUI_SORTBANK = function()
	if not P.bank then
		return
	end
	if not P.atBank then
		ns.Print(L["the bank is not open"])
		return
	end
	Bags:SortBags(P.bank)
end
SLASH_FROSTATOMUI_SORTBANK1 = "/sortbank"

function Bags:Initialize()
	loadSaved()

	local inventory = P.createContainer("inventory", L["Bags"], INVENTORY_BAGS, "inventoryColumns")
	P.inventory = inventory
	local bank = P.createContainer("bank", L["Bank"], BANK_BAGS, "bankColumns")
	P.bank = bank
	bank.stackSources = INVENTORY_BAGS
	inventory.currencies = {}

	local bankButton = P.createGlyphButton(inventory, "building-columns", L["Bank"], P.onBankButtonClick)
	bankButton.tooltipText = L["Contents saved at the last bank visit, viewable anywhere."]
	bankButton:SetPoint("RIGHT", inventory.sortButton, "LEFT", -ROW_GAP, 0)
	inventory.bankButton = bankButton

	for i = 1, #frames do
		frames[i]:LayoutChrome()
	end

	ToggleBag = toggleBag
	ToggleBackpack = toggleBackpack
	OpenBackpack = openBackpack
	CloseBackpack = closeBackpack
	OpenAllBags = openAllBags
	CloseAllBags = closeAllBags

	self:WatchConfig("bags", function()
		forEachShownFrame("Layout")
	end)

	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", updateCurrencies)
	hooksecurefunc("BackpackTokenFrame_Update", updateCurrencies)

	BankFrame:UnregisterEvent("BANKFRAME_OPENED")
	BankFrame:UnregisterEvent("BANKFRAME_CLOSED")

	for _, event in ipairs({
		"BAG_UPDATE",
		"BAG_UPDATE_COOLDOWN",
		"ITEM_LOCK_CHANGED",
		"PLAYERBANKSLOTS_CHANGED",
		"PLAYERBANKBAGSLOTS_CHANGED",
		"BANKFRAME_OPENED",
		"BANKFRAME_CLOSED",
		"PLAYER_MONEY",
	}) do
		self:RegisterEvent(event)
	end
	self:RegisterEvent("QUEST_ACCEPTED", questLogChanged)
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", function(_, unit)
		if unit == "player" then
			questLogChanged()
		end
	end)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", saveMoney)
	self:RegisterEvent("PLAYER_LOGOUT", saveMoney)
	self:RegisterEvent("PLAYER_LEVEL_UP", function()
		ns.After(LEVEL_UP_DELAY, refreshUsability)
	end)
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", refreshUsability)
	self:RegisterEvent("EQUIPMENT_SETS_CHANGED", function()
		if P.searchText ~= "" then
			P.setSearch(P.searchText, true)
		end
	end)

	for showEvent, closeEvent in pairs(AUTO_SHOW_EVENTS) do
		self:RegisterEvent(showEvent, autoShow)
		self:RegisterEvent(closeEvent, autoHide)
	end
end
