local ADDON_NAME, ns = ...

local L = ns.L

local GetContainerNumSlots = GetContainerNumSlots
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemID = GetContainerItemID
local GetContainerItemCooldown = GetContainerItemCooldown
local GetContainerItemQuestInfo = GetContainerItemQuestInfo
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local GetItemQualityColor = GetItemQualityColor
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemLink = GetInventoryItemLink
local IsInventoryItemLocked = IsInventoryItemLocked
local ContainerIDToInventoryID = ContainerIDToInventoryID
local BankButtonIDToInvSlotID = BankButtonIDToInvSlotID
local GetNumBankSlots = GetNumBankSlots
local GetBankSlotCost = GetBankSlotCost
local GetMoney = GetMoney
local GetBackpackCurrencyInfo = GetBackpackCurrencyInfo
local UnitFactionGroup = UnitFactionGroup
local MAX_WATCHED_TOKENS = MAX_WATCHED_TOKENS
local CursorHasItem = CursorHasItem
local ClearCursor = ClearCursor
local PickupContainerItem = PickupContainerItem
local PutItemInBag = PutItemInBag
local PutItemInBackpack = PutItemInBackpack
local PickupBagFromSlot = PickupBagFromSlot
local CloseBankFrame = CloseBankFrame
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local SetItemButtonTexture = SetItemButtonTexture
local SetItemButtonCount = SetItemButtonCount
local StaticPopup_Show = StaticPopup_Show
local PlaySound = PlaySound
local GameTooltip = GameTooltip
local GetMouseFocus = GetMouseFocus
local bit_band = bit.band
local tsort = table.sort
local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local NUM_BANKGENERIC_SLOTS = NUM_BANKGENERIC_SLOTS
local BACKPACK_CONTAINER = BACKPACK_CONTAINER
local BANK_CONTAINER = BANK_CONTAINER

local Bags = ns:NewModule("Bags")
Bags.configKey = "bags"
local CooldownTimer = ns:GetModule("CooldownTimer")

local config = ns.Config.bags
local ROW_GAP = 6
local HEADER_HEIGHT = 20
local BAG_BUTTON_SIZE = 20
local FOOTER_HEIGHT = BAG_BUTTON_SIZE

local ITEM_BUTTON_NAME = ADDON_NAME .. "BagItem%d"
local BACKPACK_ICON = "Interface\\Buttons\\Button-Backpack-Up"
local LOCK_ICON = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LOCK_ICON_SIZE = 14
local GLYPH_SIZE = 16
local GLYPH_ICON_SIZE = 12
local SEARCH_ICON_SIZE = 10
local SEARCH_TEXT_INSET = 18
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_SCALE = 1.6
local ARENA_POINTS_ICON = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
local HONOR_ICON = "Interface\\TargetingFrame\\UI-PVP-%s"
local MIN_COLUMNS = 4
local MAX_COLUMNS = 24
local CURRENCY_ICON_SIZE = 14
local CURRENCY_SPACING = 10
local MONEY_ICON_OVERHANG = 7
local RETRY_DELAY = 0.5
local RETRY_TRIES = 3
local BAG_RECHECK_DELAY = 0.5
local LEVEL_UP_DELAY = 1

local INVENTORY_BAGS = { BACKPACK_CONTAINER, 1, 2, 3, 4 }
local BANK_BAGS = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }

local QUIVER_FAMILY = 0x0003
local SOUL_FAMILY = 0x0004
local PROFESSION_FAMILY = 0x0FF8

local LOCK_MODIFIERS = { ALT = 1, ["ALT-CTRL"] = 3, ["ALT-SHIFT"] = 5, ["CTRL-SHIFT"] = 6 }

local BagItems = ns.BagItems

local bagFrames = {}
local bagFamilies = {}
local bagSizes = {}
local dirtyBags = {}
local recheckPending = {}
local inventoryDirty = false
local newItems = {}
local searchResults = {}
local searchText = ""
local searchQuery
local atBank = false
local autoOpened = false
local inventory, bank
local frames = {}
local slotLocks = {}
local savedLocks, bankCache
local charKey, moneyKey, playerRealm
local retryBudget, retryScheduled = 0, false

local function frameWidth(columns)
	return columns * (config.buttonSize + config.spacing) - config.spacing + config.padding * 2
end

local function frameHeight(rows)
	return rows * (config.buttonSize + config.spacing)
		- config.spacing
		+ HEADER_HEIGHT
		+ FOOTER_HEIGHT
		+ ROW_GAP * 2
		+ config.padding * 2
end

local function bagInventorySlot(bag)
	if bag > NUM_BAG_SLOTS then
		return BankButtonIDToInvSlotID(bag - NUM_BAG_SLOTS, 1)
	elseif bag > BACKPACK_CONTAINER then
		return ContainerIDToInventoryID(bag)
	end
end

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

local function isBankBag(bag)
	return bag == BANK_CONTAINER or bag > NUM_BAG_SLOTS
end

local function linkItemId(link)
	return tonumber(link:match("item:(%d+)"))
end

local function itemTexture(itemId)
	local texture = GetItemIcon and GetItemIcon(itemId)
	if not texture then
		local _
		_, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
	end
	return texture or UNKNOWN_ICON
end

local function lockKey(bag, slot)
	return bag * 100 + slot
end

function Bags.IsSlotLocked(key)
	return slotLocks[key]
end

local function updateBagFamily(bag)
	local _, family = GetContainerNumFreeSlots(bag)
	bagFamilies[bag] = family or 0
end

local function familyColor(family)
	if bit_band(family, QUIVER_FAMILY) ~= 0 then
		return 0.8, 0.7, 0.3
	elseif bit_band(family, SOUL_FAMILY) ~= 0 then
		return 0.6, 0.35, 0.8
	elseif bit_band(family, PROFESSION_FAMILY) ~= 0 then
		return 0.35, 0.7, 0.35
	end
	return 0.5, 0.5, 0.5
end

local function itemMatchesSearch(itemId)
	local result = searchResults[itemId]
	if result == nil then
		local uncertain
		result, uncertain = BagItems.Matches(searchQuery, itemId)
		if not uncertain then
			searchResults[itemId] = result
		end
	end
	return result
end

local function offlineItem(bag, slot)
	local entry = bankCache and bankCache[bag]
	local item = entry and entry.items[slot]
	if item then
		return item[1], item[2]
	end
end

local function saveBankBag(bag)
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

local function saveMoney()
	local db = ns.db
	if not db or not moneyKey then
		return
	end
	local gold = db.gold or {}
	db.gold = gold
	local entry = gold[moneyKey] or {}
	gold[moneyKey] = entry
	entry.money = GetMoney()
	entry.class = ns.PLAYER_CLASS
end

local function lockModifierDown()
	local state = (IsAltKeyDown() and 1 or 0) + (IsControlKeyDown() and 2 or 0) + (IsShiftKeyDown() and 4 or 0)
	return state ~= 0 and LOCK_MODIFIERS[config.lockModifier] == state
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
	if retryScheduled or retryBudget <= 0 then
		return
	end
	retryScheduled = true
	retryBudget = retryBudget - 1
	ns.After(RETRY_DELAY, retryPending)
end

local ItemMixin = {}

function ItemMixin:UpdateSearch()
	local itemId = self.itemId
	self:SetAlpha((not searchQuery or (itemId and itemMatchesSearch(itemId))) and 1 or config.searchFadeAlpha)
end

function ItemMixin:UpdateHighlight()
	if self.container.highlightBag == self.bag then
		self:LockHighlight()
	else
		self:UnlockHighlight()
	end
end

function ItemMixin:UpdateIcon()
	local icon = self.icon
	local grey = (self.locked or self.cooldownPending) and true or false
	if grey ~= self.desaturated then
		self.desaturated = grey
		icon:SetDesaturated(grey)
	end
	if grey then
		icon:SetVertexColor(0.5, 0.5, 0.5)
	elseif self.unusable then
		icon:SetVertexColor(1, 0.3, 0.3)
	else
		icon:SetVertexColor(1, 1, 1)
	end
end

function ItemMixin:UpdateCooldown()
	local pending = false
	if self.hasItem and not self.container.offline then
		local start, duration, enable = GetContainerItemCooldown(self.bag, self.slot)
		CooldownFrame_SetTimer(self.cooldown, start, duration, enable)
		pending = duration > 0 and enable == 0
	else
		CooldownFrame_SetTimer(self.cooldown, 0, 0, 0)
	end
	if pending ~= self.cooldownPending then
		self.cooldownPending = pending
		self:UpdateIcon()
	end
end

function ItemMixin:UpdateLock()
	local _, _, locked = GetContainerItemInfo(self.bag, self.slot)
	self.locked = locked
	self:UpdateIcon()
end

function ItemMixin:UpdateSortLock()
	ns.SetShown(self.lockIcon, slotLocks[lockKey(self.bag, self.slot)])
end

function ItemMixin:RetryPending()
	if self.pending then
		self:Update()
	end
end

function ItemMixin:SetOffline(offline)
	if self.offline == offline then
		return
	end
	self.offline = offline
	if offline then
		self:RegisterForClicks()
		self:RegisterForDrag()
	else
		self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		self:RegisterForDrag("LeftButton")
	end
end

function ItemMixin:Update()
	local bag, slot = self.bag, self.slot
	local offline = self.container.offline
	local texture, count, locked, quality, readable, link, itemId
	if offline then
		link, count = offlineItem(bag, slot)
		if link then
			itemId = linkItemId(link)
			texture = itemId and itemTexture(itemId) or UNKNOWN_ICON
		end
	else
		texture, count, locked, quality, readable = GetContainerItemInfo(bag, slot)
		link = texture and GetContainerItemLink(bag, slot)
		itemId = link and GetContainerItemID(bag, slot)
	end

	self.link = link
	self.itemId = itemId
	self.hasItem = texture and 1 or nil
	self.readable = readable
	self.locked = locked
	self.unusable = itemId and config.tintUnusable and BagItems.IsUnusable(itemId) or false
	self.pending = nil

	SetItemButtonTexture(self, texture)
	SetItemButtonCount(self, count)

	local r, g, b
	local level
	if link then
		local itemLevel, itemQuality, pending = ns.ItemButtonLevel(link)
		quality = itemQuality or quality
		if not offline and GetContainerItemQuestInfo(bag, slot) then
			r, g, b = unpack(config.questItemColor)
		elseif quality and quality >= 0 then
			r, g, b = GetItemQualityColor(quality)
		else
			r, g, b = 1, 1, 1
		end
		if config.showItemLevel then
			level = itemLevel
		end
		if pending then
			self.pending = true
			scheduleRetry()
		end
	else
		r, g, b = familyColor(bagFamilies[bag] or 0)
	end
	self:GetNormalTexture():SetVertexColor(r, g, b)

	if level then
		self.level:SetText(level)
		self.level:SetTextColor(r, g, b)
	else
		self.level:SetText("")
	end

	if itemId and config.highlightNewItems and newItems[itemId] then
		self.glow:Show()
	else
		self.glow:Hide()
	end

	self:UpdateSortLock()
	self:UpdateCooldown()
	self:UpdateIcon()
	self:UpdateSearch()
	self:UpdateHighlight()

	if GetMouseFocus() == self then
		self:UpdateTooltip()
	end
end

local function anchorItemTooltip(button)
	if button:GetRight() >= GetScreenWidth() / 2 then
		GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	end
end

local function onItemEnter(self)
	if self.container.offline then
		if self.link then
			anchorItemTooltip(self)
			GameTooltip:SetHyperlink(self.link)
			GameTooltip:Show()
		end
		return
	end

	if self.bag == BANK_CONTAINER then
		anchorItemTooltip(self)
		GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(self.slot))
		CursorUpdate(self)
	else
		ContainerFrameItemButton_OnEnter(self)
	end

	if slotLocks[lockKey(self.bag, self.slot)] and GameTooltip:IsOwned(self) then
		GameTooltip:AddLine(L["Locked: sorting skips this slot"], 0.5, 0.8, 1)
		GameTooltip:Show()
	end
end

local function onItemPreClick(self)
	self.cursorHadItem = CursorHasItem()
end

local function onItemClick(self, mouseButton)
	if mouseButton ~= "LeftButton" or self.container.offline or not lockModifierDown() then
		return
	end
	Bags:ToggleSlotLock(self.bag, self.slot)
	if not self.cursorHadItem and CursorHasItem() then
		PickupContainerItem(self.bag, self.slot)
		if CursorHasItem() then
			ClearCursor()
		end
	end
end

local function onItemMouseUp(self)
	if self.offline and self.link and IsModifiedClick() then
		HandleModifiedItemClick(self.link)
	end
end

local BagSlotMixin = {}

function BagSlotMixin:GetInventorySlot()
	return bagInventorySlot(self.bag)
end

function BagSlotMixin:IsPurchasable()
	return not self:GetParent().offline and self.bag > NUM_BAG_SLOTS and self.bag - NUM_BAG_SLOTS > GetNumBankSlots()
end

function BagSlotMixin:GetCachedLink()
	local entry = bankCache and bankCache[self.bag]
	return entry and entry.link
end

function BagSlotMixin:UpdateFree()
	local frame = self:GetParent()
	local size = frame:BagSize(self.bag)
	if config.showBagFreeSlots and size > 0 then
		self.free:SetText(frame:FreeSlots(self.bag, size))
	else
		self.free:SetText("")
	end
end

function BagSlotMixin:Update()
	local invSlot = self:GetInventorySlot()
	local icon, border = self.icon, self:GetNormalTexture()
	icon:SetDesaturated(false)
	self:UpdateFree()

	if not invSlot then
		icon:SetTexture(BACKPACK_ICON)
		border:SetVertexColor(1, 1, 1)
		return
	end

	local texture
	if self:GetParent().offline then
		local link = self:GetCachedLink()
		local itemId = link and linkItemId(link)
		texture = itemId and itemTexture(itemId)
	else
		texture = GetInventoryItemTexture("player", invSlot)
	end

	if texture then
		icon:SetTexture(texture)
		icon:SetDesaturated(not self:GetParent().offline and IsInventoryItemLocked(invSlot))
		border:SetVertexColor(1, 1, 1)
	elseif self:IsPurchasable() then
		icon:SetTexture(nil)
		border:SetVertexColor(1, 0.2, 0.2)
	else
		icon:SetTexture(nil)
		border:SetVertexColor(0.5, 0.5, 0.5)
	end
end

function BagSlotMixin:OnClick()
	if self:GetParent().offline then
		return
	end
	if self:IsPurchasable() then
		StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
	elseif CursorHasItem() then
		if self.bag == BACKPACK_CONTAINER then
			PutItemInBackpack()
		elseif self.bag ~= BANK_CONTAINER then
			PutItemInBag(self:GetInventorySlot())
		end
	end
end

function BagSlotMixin:OnDragStart()
	if self:GetParent().offline then
		return
	end
	local invSlot = self:GetInventorySlot()
	if invSlot and not self:IsPurchasable() then
		PickupBagFromSlot(invSlot)
	end
end

function BagSlotMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local invSlot = self:GetInventorySlot()
	local link = self:GetParent().offline and self:GetCachedLink()
	if not invSlot then
		GameTooltip:SetText(self.bag == BANK_CONTAINER and BANK or BACKPACK_TOOLTIP, 1, 1, 1)
	elseif link then
		GameTooltip:SetHyperlink(link)
	elseif self:GetParent().offline or not GameTooltip:SetInventoryItem("player", invSlot) then
		if self:IsPurchasable() then
			GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
			GameTooltip:AddLine(ns.FormatMoney(GetBankSlotCost(GetNumBankSlots())))
		else
			GameTooltip:SetText(EQUIP_CONTAINER, 1, 1, 1)
		end
	end
	GameTooltip:Show()

	local frame = self:GetParent()
	frame.highlightBag = self.bag
	frame:ForEachButton("UpdateHighlight")
end

function BagSlotMixin:OnLeave()
	GameTooltip:Hide()
	local frame = self:GetParent()
	frame.highlightBag = nil
	frame:ForEachButton("UpdateHighlight")
end

local ContainerMixin = {}

function ContainerMixin:BagSize(bag)
	if self.offline then
		local entry = bankCache and bankCache[bag]
		return entry and entry.size or 0
	end
	return bagSize(bag)
end

function ContainerMixin:FreeSlots(bag, size)
	if self.offline then
		local entry = bankCache and bankCache[bag]
		local used = 0
		if entry then
			for _ in pairs(entry.items) do
				used = used + 1
			end
		end
		return max(size - used, 0)
	end
	return (GetContainerNumFreeSlots(bag)) or 0
end

function ContainerMixin:ForEachButton(method)
	local buttons = self.buttons
	for i = 1, #buttons do
		local button = buttons[i]
		if button:IsShown() then
			button[method](button)
		end
	end
end

local itemButtonCount = 0

function ContainerMixin:CreateItemButton(index)
	itemButtonCount = itemButtonCount + 1
	local name = ITEM_BUTTON_NAME:format(itemButtonCount)
	local button = CreateFrame("Button", name, self.itemArea, "ContainerFrameItemButtonTemplate")
	ns.Mixin(button, ItemMixin)
	button.container = self
	button.icon = _G[name .. "IconTexture"]
	local size = config.buttonSize

	button:SetSize(size, size)

	local normal = button:GetNormalTexture()
	normal:SetTexture(ns.Media.buttonNormal)
	normal:ClearAllPoints()
	normal:SetAllPoints()

	_G[name .. "IconQuestTexture"]:Hide()
	_G[name .. "Stock"]:Hide()

	local count = _G[name .. "Count"]
	ns.SetFont(count, config.countFont.size, config.countFont.outline)
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", -1, 1)
	button.countText = count

	button.cooldown = _G[name .. "Cooldown"]
	CooldownTimer:Attach(button.cooldown)

	local level = button:CreateFontString(nil, "OVERLAY")
	ns.SetFont(level, config.levelFont.size, config.levelFont.outline)
	level:SetPoint("TOPLEFT", 1, -1)
	button.level = level

	local lockIcon = button:CreateTexture(nil, "OVERLAY")
	lockIcon:SetTexture(LOCK_ICON)
	lockIcon:SetSize(LOCK_ICON_SIZE, LOCK_ICON_SIZE)
	lockIcon:SetPoint("TOPRIGHT", -1, -1)
	lockIcon:Hide()
	button.lockIcon = lockIcon

	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW_TEXTURE)
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(0.3, 1, 0.3, 0.8)
	glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)
	glow:SetPoint("CENTER")
	glow:Hide()
	button.glow = glow

	button:SetScript("OnEnter", onItemEnter)
	button.UpdateTooltip = onItemEnter
	button:HookScript("PreClick", onItemPreClick)
	button:HookScript("OnClick", onItemClick)
	button:HookScript("OnMouseUp", onItemMouseUp)

	self.buttons[index] = button
	return button
end

function ContainerMixin:CreateBagButton(bag, index)
	local button = CreateFrame("Button", nil, self)
	ns.Mixin(button, BagSlotMixin)
	button.bag = bag
	button:SetSize(BAG_BUTTON_SIZE, BAG_BUTTON_SIZE)
	button:SetNormalTexture(ns.Media.buttonNormal)
	button:GetNormalTexture():SetAllPoints()
	button:SetHighlightTexture(ns.Media.buttonHighlight)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()

	button.free = button:CreateFontString(nil, "OVERLAY")
	ns.SetFont(button.free, 9, "OUTLINE")
	button.free:SetPoint("BOTTOMRIGHT", 0, 1)

	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", button.OnClick)
	button:SetScript("OnReceiveDrag", button.OnClick)
	button:SetScript("OnDragStart", button.OnDragStart)
	button:SetScript("OnEnter", button.OnEnter)
	button:SetScript("OnLeave", button.OnLeave)

	self.bagButtons[index] = button
	return button
end

function ContainerMixin:UpdateBagButtons()
	local bagButtons = self.bagButtons
	for i = 1, #bagButtons do
		bagButtons[i]:Update()
	end
end

local function onCurrencyEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetBackpackToken(self:GetID())
	GameTooltip:Show()
end

function ContainerMixin:CreateCurrency(index)
	local currency = CreateFrame("Button", nil, self)
	currency:SetID(index)
	currency:SetHeight(FOOTER_HEIGHT)

	currency.icon = currency:CreateTexture(nil, "ARTWORK")
	currency.icon:SetSize(CURRENCY_ICON_SIZE, CURRENCY_ICON_SIZE)
	currency.icon:SetPoint("LEFT")

	currency.count = currency:CreateFontString(nil, "OVERLAY")
	ns.SetFont(currency.count, 11, "OUTLINE")
	currency.count:SetPoint("LEFT", currency.icon, "RIGHT", 2, 0)

	currency:SetScript("OnEnter", onCurrencyEnter)
	currency:SetScript("OnLeave", GameTooltip_Hide)

	self.currencies[index] = currency
	return currency
end

function ContainerMixin:UpdateCurrencies()
	local currencies = self.currencies
	if not currencies then
		return
	end

	local previous = self.freeText
	for index = 1, MAX_WATCHED_TOKENS do
		local name, count, currencyType, icon = GetBackpackCurrencyInfo(index)
		local currency = currencies[index] or self:CreateCurrency(index)
		if name then
			if currencyType == 1 then
				icon = ARENA_POINTS_ICON
			elseif currencyType == 2 then
				icon = HONOR_ICON:format(UnitFactionGroup("player"))
			end
			currency.icon:SetTexture(icon)
			currency.count:SetText(count)
			currency:SetWidth(CURRENCY_ICON_SIZE + 2 + currency.count:GetStringWidth())
			currency:ClearAllPoints()
			currency:SetPoint("LEFT", previous, "RIGHT", CURRENCY_SPACING, 0)
			currency:Show()
			previous = currency
		else
			currency:Hide()
		end
	end
end

function ContainerMixin:UpdateInfo()
	local bags = self.bags
	local free, total = 0, 0
	for i = 1, #bags do
		local bag = bags[i]
		local size = self:BagSize(bag)
		if size > 0 then
			free = free + self:FreeSlots(bag, size)
			total = total + size
		end
	end
	self.freeText:SetFormattedText("%d / %d", total - free, total)
	self.moneyText:SetText(ns.FormatMoneyIcons(GetMoney()))
	self:UpdateBagButtons()
	self:UpdateCurrencies()
end

function ContainerMixin:LayoutChrome()
	local padding = config.padding
	self.close:ClearAllPoints()
	self.close:SetPoint("TOPRIGHT", -padding, -padding - (HEADER_HEIGHT - GLYPH_SIZE) / 2)
	local searchAnchor = self.sortButton
	if self.bankButton then
		ns.SetShown(self.bankButton, config.offlineBank)
		if config.offlineBank then
			searchAnchor = self.bankButton
		end
	end
	self.search:ClearAllPoints()
	self.search:SetPoint("TOPLEFT", padding, -padding)
	self.search:SetPoint("RIGHT", searchAnchor, "LEFT", -ROW_GAP, 0)
	self.itemArea:ClearAllPoints()
	self.itemArea:SetPoint("TOPLEFT", padding, -(padding + HEADER_HEIGHT + ROW_GAP))
	self.moneyText:ClearAllPoints()
	self.moneyText:SetPoint("RIGHT", self, "BOTTOMRIGHT", -padding - MONEY_ICON_OVERHANG, padding + FOOTER_HEIGHT / 2)
	local bagButtons = self.bagButtons
	for i = 1, #bagButtons do
		bagButtons[i]:ClearAllPoints()
		bagButtons[i]:SetPoint("BOTTOMLEFT", padding + (i - 1) * (BAG_BUTTON_SIZE + 2), padding)
	end
end

function ContainerMixin:Layout()
	local buttonSize = config.buttonSize
	local step = buttonSize + config.spacing
	local columns = config[self.columnsKey]
	local bags, buttons, holders = self.bags, self.buttons, self.holders
	local offline = self.offline or false
	local index = 0

	self:LayoutChrome()

	for i = 1, #bags do
		local bag = bags[i]
		local size = self:BagSize(bag)
		bagSizes[bag] = size
		if offline then
			bagFamilies[bag] = 0
		else
			updateBagFamily(bag)
		end
		local holder = holders[bag]
		for slot = 1, size do
			index = index + 1
			local button = buttons[index] or self:CreateItemButton(index)
			button.bag, button.slot = bag, slot
			button:SetParent(holder)
			button:SetID(slot)
			button:SetOffline(offline)
			button:SetSize(buttonSize, buttonSize)
			button.glow:SetSize(buttonSize * GLOW_SCALE, buttonSize * GLOW_SCALE)
			ns.SetFont(button.countText, config.countFont.size, config.countFont.outline)
			ns.SetFont(button.level, config.levelFont.size, config.levelFont.outline)
			button:ClearAllPoints()
			button:SetPoint(ns.GridPoint("TOPLEFT", index, columns, step))
			button:Show()
			button:Update()
		end
	end

	for i = index + 1, #buttons do
		buttons[i]:Hide()
	end

	local rows = ceil(index / columns)
	self.itemArea:SetSize(columns * step - config.spacing, rows * step - config.spacing)
	self:SetSize(frameWidth(columns), frameHeight(rows))
	self:SetBackdropColor(0, 0, 0, config.backgroundAlpha)
	self:UpdateInfo()
end

function ContainerMixin:UpdateBag(bag)
	if not self:IsShown() then
		return
	end
	if self:BagSize(bag) ~= bagSizes[bag] then
		return self:Layout()
	end

	if not self.offline then
		updateBagFamily(bag)
	end
	local buttons = self.buttons
	for i = 1, #buttons do
		local button = buttons[i]
		if button.bag == bag and button:IsShown() then
			button:Update()
		end
	end
	self:UpdateInfo()
end

function ContainerMixin:UpdateSortButton()
	if self.sorting or self.offline then
		self.sortButton:Disable()
	else
		self.sortButton:Enable()
	end
end

function ContainerMixin:SetSorting(sorting)
	self.sorting = sorting
	self:UpdateSortButton()
end

function ContainerMixin:SetOffline(offline)
	self.offline = offline
	self.search.placeholder:SetText(offline and L["Bank (offline)"] or self.title)
	self:UpdateSortButton()
end

function ContainerMixin:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

local function onShow(self)
	if config.playSounds then
		PlaySound("igBackPackOpen")
	end
	retryBudget = RETRY_TRIES
	if self == bank then
		self:SetOffline(not atBank)
	end
	self:Layout()
	if self == inventory then
		MainMenuBarBackpackButton:SetChecked(true)
	end
end

local function onHide(self)
	if config.playSounds then
		PlaySound("igBackPackClose")
	end
	if self == bank then
		if atBank then
			CloseBankFrame()
		end
	else
		autoOpened = false
		wipe(newItems)
		MainMenuBarBackpackButton:SetChecked(false)
	end
end

local function setSearch(text, force)
	text = text:lower()
	if text == searchText and not force then
		return
	end
	searchText = text
	searchQuery = BagItems.CompileSearch(text)
	wipe(searchResults)
	for i = 1, #frames do
		local frame = frames[i]
		if frame.search:GetText():lower() ~= text then
			frame.search:SetText(text)
		end
		if frame:IsShown() then
			frame:ForEachButton("UpdateSearch")
		end
	end
end

local function onSearchEscape(self)
	self:SetText("")
	self:ClearFocus()
end

local function onSearchFocusGained(self)
	self.placeholder:Hide()
end

local function onSearchFocusLost(self)
	if self:GetText() == "" then
		self.placeholder:Show()
	end
end

local function onSearchTextChanged(self)
	local text = self:GetText()
	setSearch(text)
	if text ~= "" then
		self.placeholder:Hide()
	elseif not self:HasFocus() then
		self.placeholder:Show()
	end
end

local function onSearchEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(L["Search"], 1, 1, 1)
	GameTooltip:AddLine(L["Plain text matches name, type and slot."], 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine("q:epic  q>=3", L["quality"], 1, 0.82, 0, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine("ilvl>=251  ilvl<200", L["item level"], 1, 0.82, 0, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine("t:cloth  n:frost", L["type / name"], 1, 0.82, 0, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine("tt:text", L["tooltip text"], 1, 0.82, 0, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine("s:name", L["equipment set"], 1, 0.82, 0, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine("boe  bop  boa  quest", L["binding"], 1, 0.82, 0, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine("!a   a | b   a b", L["not / or / and"], 1, 0.82, 0, 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

local function createSearchBox(frame, title)
	local search = CreateFrame("EditBox", nil, frame)
	search:SetAutoFocus(false)
	search:SetHeight(HEADER_HEIGHT)
	ns.SetFont(search, 12)
	search:SetTextInsets(SEARCH_TEXT_INSET, 4, 0, 0)
	search:SetMaxLetters(80)
	search:SetBackdrop(ns.CreateBackdrop(8))
	search:SetBackdropColor(0, 0, 0, 0.5)
	search:SetBackdropBorderColor(0.6, 0.6, 0.6)

	local icon = ns.CreateGlyph(search, "magnifying-glass", SEARCH_ICON_SIZE)
	icon:SetTextColor(0.5, 0.5, 0.5)
	icon:SetPoint("CENTER", search, "LEFT", SEARCH_TEXT_INSET / 2 + 1, 0)

	local placeholder = search:CreateFontString(nil, "OVERLAY")
	ns.SetFont(placeholder, 12)
	placeholder:SetTextColor(0.5, 0.5, 0.5)
	placeholder:SetPoint("LEFT", SEARCH_TEXT_INSET, 0)
	placeholder:SetText(title)
	search.placeholder = placeholder

	search:SetScript("OnEscapePressed", onSearchEscape)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	search:SetScript("OnEditFocusGained", onSearchFocusGained)
	search:SetScript("OnEditFocusLost", onSearchFocusLost)
	search:SetScript("OnTextChanged", onSearchTextChanged)
	search:SetScript("OnEnter", onSearchEnter)
	search:SetScript("OnLeave", GameTooltip_Hide)

	return search
end

local function onCloseClick(self)
	self:GetParent():Hide()
end

local function onSortClick(self)
	Bags:SortBags(self:GetParent())
end

local function onBankButtonClick()
	if atBank or bank:IsShown() then
		return bank:Toggle()
	end
	if not bankCache or not next(bankCache) then
		ns.Print(L["visit a banker once to view the bank from anywhere"])
		return
	end
	bank:Show()
end

local function createGlyphButton(parent, glyph, tooltip, onClick)
	local button = ns.CreateGlyphButton(parent, glyph, GLYPH_ICON_SIZE, tooltip)
	button:SetSize(GLYPH_SIZE, GLYPH_SIZE)
	button.tooltipAnchor = "ANCHOR_TOP"
	button:SetScript("OnClick", onClick)
	return button
end

local moneyEntries = {}

local function sortByMoney(a, b)
	if a.money ~= b.money then
		return a.money > b.money
	end
	return a.name < b.name
end

local function onMoneyEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	local gold = ns.db and ns.db.gold
	if config.altGold and gold then
		for key, entry in pairs(gold) do
			local realm, name = key:match("^(.-)|(.+)$")
			if realm == playerRealm and entry.money then
				moneyEntries[#moneyEntries + 1] = { name = name, money = entry.money, class = entry.class }
			end
		end
		tsort(moneyEntries, sortByMoney)
		GameTooltip:SetText(playerRealm, 1, 1, 1)
		local total = 0
		for i = 1, #moneyEntries do
			local entry = moneyEntries[i]
			local color = entry.class and RAID_CLASS_COLORS[entry.class]
			local r, g, b = 1, 1, 1
			if color then
				r, g, b = color.r, color.g, color.b
			end
			GameTooltip:AddDoubleLine(entry.name, ns.FormatMoneyIcons(entry.money), r, g, b, 1, 1, 1)
			total = total + entry.money
		end
		wipe(moneyEntries)
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L["Total"], ns.FormatMoneyIcons(total), 1, 0.82, 0, 1, 1, 1)
	else
		GameTooltip:SetText(ns.FormatMoneyIcons(GetMoney()), 1, 1, 1)
	end
	GameTooltip:AddLine(L["Click to pick up gold, Shift-click silver, Ctrl-click copper."], 0.6, 0.6, 0.6, true)
	GameTooltip:Show()
end

local function onMoneyClick(self)
	local money = GetMoney() - GetCursorMoney() - GetPlayerTradeMoney()
	local multiplier = COPPER_PER_GOLD
	if IsControlKeyDown() then
		multiplier = 1
	elseif IsShiftKeyDown() then
		multiplier = COPPER_PER_SILVER
	end
	while multiplier > 1 and money < multiplier do
		multiplier = multiplier / COPPER_PER_SILVER
	end
	GameTooltip:Hide()
	OpenCoinPickupFrame(multiplier, money, self)
	self.hasPickup = 1
	CoinPickupFrame:SetFrameStrata("DIALOG")
end

local function createMoneyButton(frame)
	local money = CreateFrame("Button", nil, frame)
	money:SetPoint("TOPLEFT", frame.moneyText, "TOPLEFT", 0, 2)
	money:SetPoint("BOTTOMRIGHT", frame.moneyText, "BOTTOMRIGHT", MONEY_ICON_OVERHANG, -2)
	money.moneyType = "PLAYER"
	money.hasPickup = 0
	money:RegisterForClicks("LeftButtonUp")
	money:SetScript("OnClick", onMoneyClick)
	money:SetScript("OnEnter", onMoneyEnter)
	money:SetScript("OnLeave", GameTooltip_Hide)
	return money
end

local function createContainer(key, title, bags, columnsKey)
	local frame = CreateFrame("Frame", ADDON_NAME .. key, UIParent)
	ns.Mixin(frame, ContainerMixin)
	frame.bags = bags
	frame.title = title
	frame.columnsKey = columnsKey
	frame.buttons = {}
	frame.bagButtons = {}
	frame:Hide()

	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	frame:SetBackdrop(ns.CreateBackdrop(14, 3))
	frame:SetBackdropColor(0, 0, 0, config.backgroundAlpha)

	Bags:AnchorToConfig(frame, "bags." .. key, title, {
		floating = true,
		size = function()
			local columns = config[columnsKey]
			local slots = 0
			for i = 1, #bags do
				slots = slots + frame:BagSize(bags[i])
			end
			return frameWidth(columns), frameHeight(ceil(slots / columns))
		end,
		resize = {
			square = false,
			minWidth = frameWidth(MIN_COLUMNS),
			maxWidth = frameWidth(MAX_COLUMNS),
			get = function()
				return frameWidth(config[columnsKey]), frame:GetHeight()
			end,
			set = function(width)
				local step = config.buttonSize + config.spacing
				local columns = floor((width - config.padding * 2 + config.spacing) / step + 0.5)
				ns:SetConfig("bags." .. columnsKey, max(MIN_COLUMNS, min(MAX_COLUMNS, columns)))
			end,
		},
	})
	frame:SetScript("OnShow", onShow)
	frame:SetScript("OnHide", onHide)
	tinsert(UISpecialFrames, frame:GetName())

	local close = createGlyphButton(frame, "xmark", nil, onCloseClick)
	frame.close = close

	local sortButton = createGlyphButton(frame, "arrow-down-wide-short", L["Sort"], onSortClick)
	sortButton:SetPoint("RIGHT", close, "LEFT", -ROW_GAP, 0)
	frame.sortButton = sortButton

	frame.search = createSearchBox(frame, title)
	frame.itemArea = CreateFrame("Frame", nil, frame)
	local itemArea = frame.itemArea

	local holders = {}
	frame.holders = holders
	for i = 1, #bags do
		local bag = bags[i]
		frame:CreateBagButton(bag, i)
		local holder = CreateFrame("Frame", nil, itemArea)
		holder:SetID(bag)
		holder:SetAllPoints()
		holders[bag] = holder
		bagFrames[bag] = frame
	end

	frame.freeText = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(frame.freeText, 11, "OUTLINE")
	frame.freeText:SetPoint("LEFT", frame.bagButtons[#bags], "RIGHT", ROW_GAP, 0)

	frame.moneyText = frame:CreateFontString(nil, "OVERLAY")
	ns.SetFont(frame.moneyText, 11, "OUTLINE")
	frame.money = createMoneyButton(frame)

	frames[#frames + 1] = frame

	return frame
end

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
		if atBank and isBankBag(bag) then
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
	retryBudget = RETRY_TRIES
	updater:Show()
end

local function recheckBag(bag)
	recheckPending[bag] = nil
	markDirty(bag)
end

local function autoShow()
	if config.autoOpen and not inventory:IsShown() then
		autoOpened = true
		inventory:Show()
	end
end

local function autoHide()
	if autoOpened then
		inventory:Hide()
	end
end

local function updateCurrencies()
	if inventory:IsShown() then
		inventory:UpdateCurrencies()
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
	local saveKey = bag .. ":" .. slot
	if slotLocks[key] then
		slotLocks[key] = nil
		savedLocks[saveKey] = nil
	else
		slotLocks[key] = true
		savedLocks[saveKey] = true
	end
	refreshSortLocks()
end

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
		if frame and frame:IsShown() and not frame.offline then
			local buttons = frame.buttons
			for i = 1, #buttons do
				local button = buttons[i]
				if button.bag == bag and button.slot == slot and button:IsShown() then
					button:UpdateLock()
					return
				end
			end
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
	if bank:IsShown() then
		bank:UpdateBagButtons()
	end
	if atBank then
		for i = 2, #BANK_BAGS do
			markDirty(BANK_BAGS[i])
		end
	end
end

function Bags:BANKFRAME_OPENED()
	atBank = true
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
	atBank = false
	bank:Hide()
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
	if frame == bank and not atBank then
		return
	end
	frame:Toggle()
end

local function toggleBackpack()
	inventory:Toggle()
end

local function openBackpack()
	inventory:Show()
end

local function closeBackpack()
	inventory:Hide()
end

local function openAllBags(forceOpen)
	if forceOpen then
		inventory:Show()
	else
		inventory:Toggle()
	end
end

local function closeAllBags()
	local wasShown = inventory:IsShown()
	inventory:Hide()
	return wasShown
end

local function loadSaved(db)
	playerRealm = GetRealmName()
	local name = UnitName("player")
	charKey = name .. " - " .. playerRealm
	moneyKey = playerRealm .. "|" .. name

	db.bagLocks = db.bagLocks or {}
	savedLocks = db.bagLocks[charKey] or {}
	db.bagLocks[charKey] = savedLocks
	for key in pairs(savedLocks) do
		local bag, slot = key:match("^(-?%d+):(%d+)$")
		if bag then
			slotLocks[lockKey(tonumber(bag), tonumber(slot))] = true
		else
			savedLocks[key] = nil
		end
	end

	db.bankCache = db.bankCache or {}
	bankCache = db.bankCache[charKey] or {}
	db.bankCache[charKey] = bankCache
end

SlashCmdList.FROSTATOMUI_SORT = function(args)
	if not inventory then
		return
	end
	if strtrim(args or ""):lower() == "unlock" then
		Bags:ClearSlotLocks()
		ns.Print(L["all bag slot locks cleared"])
		return
	end
	Bags:SortBags(inventory)
end
SLASH_FROSTATOMUI_SORT1 = "/sort"

SlashCmdList.FROSTATOMUI_SORTBANK = function()
	if not bank then
		return
	end
	if not atBank then
		ns.Print(L["the bank is not open"])
		return
	end
	Bags:SortBags(bank)
end
SLASH_FROSTATOMUI_SORTBANK1 = "/sortbank"

function Bags:Initialize()
	loadSaved(ns.db)

	inventory = createContainer("inventory", L["Bags"], INVENTORY_BAGS, "inventoryColumns")
	bank = createContainer("bank", L["Bank"], BANK_BAGS, "bankColumns")
	bank.stackSources = INVENTORY_BAGS
	inventory.currencies = {}

	local bankButton = createGlyphButton(inventory, "building-columns", L["Bank"], onBankButtonClick)
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
		if searchText ~= "" then
			setSearch(searchText, true)
		end
	end)

	for showEvent, closeEvent in pairs(AUTO_SHOW_EVENTS) do
		self:RegisterEvent(showEvent, autoShow)
		self:RegisterEvent(closeEvent, autoHide)
	end
end
