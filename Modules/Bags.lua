local ADDON_NAME, ns = ...

local CreateFrame = CreateFrame
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemID = GetContainerItemID
local GetContainerItemCooldown = GetContainerItemCooldown
local GetContainerItemQuestInfo = GetContainerItemQuestInfo
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetInventoryItemTexture = GetInventoryItemTexture
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
local PutItemInBag = PutItemInBag
local PutItemInBackpack = PutItemInBackpack
local PickupBagFromSlot = PickupBagFromSlot
local CloseBankFrame = CloseBankFrame
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local SetItemButtonTexture = SetItemButtonTexture
local SetItemButtonCount = SetItemButtonCount
local SetItemButtonDesaturated = SetItemButtonDesaturated
local StaticPopup_Show = StaticPopup_Show
local PlaySound = PlaySound
local GameTooltip = GameTooltip
local UIParent = UIParent
local bit_band = bit.band
local ceil = math.ceil
local unpack = unpack
local pairs = pairs
local wipe = wipe
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local NUM_BANKGENERIC_SLOTS = NUM_BANKGENERIC_SLOTS
local BACKPACK_CONTAINER = BACKPACK_CONTAINER
local BANK_CONTAINER = BANK_CONTAINER

local Bags = ns:NewModule("Bags")
local CooldownTimer = ns:GetModule("CooldownTimer")

local config = ns.Config.bags
local PADDING = 12
local HEADER_HEIGHT = 22
local BAG_BUTTON_SIZE = 24
local BAG_ROW_HEIGHT = BAG_BUTTON_SIZE + 6
local FOOTER_HEIGHT = 16
local SEARCH_FADE_ALPHA = 0.25

local ITEM_BUTTON_NAME = ADDON_NAME .. "BagItem%d"
local BACKPACK_ICON = "Interface\\Buttons\\Button-Backpack-Up"
local EMPTY_BAG_ICON = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local CLOSE_ICON = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"
local CLOSE_ICON_HIGHLIGHT = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local SORT_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local ARENA_POINTS_ICON = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
local HONOR_ICON = "Interface\\TargetingFrame\\UI-PVP-%s"
local CURRENCY_ICON_SIZE = 14
local CURRENCY_SPACING = 10

local INVENTORY_BAGS = { BACKPACK_CONTAINER, 1, 2, 3, 4 }
local BANK_BAGS = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10, 11 }

local QUIVER_FAMILY = 0x0003
local SOUL_FAMILY = 0x0004
local PROFESSION_FAMILY = 0x0FF8

local bagFrames = {}
local bagFamilies = {}
local bagSizes = {}
local dirtyBags = {}
local inventoryDirty = false
local newItems = {}
local searchCache = {}
local searchText = ""
local atBank = false
local autoOpened = false
local inventory, bank
local frames = {}

local function bagSize(bag)
	if bag == BANK_CONTAINER then
		return NUM_BANKGENERIC_SLOTS
	end
	return GetContainerNumSlots(bag)
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
	local haystack = searchCache[itemId]
	if not haystack then
		local name, _, _, _, _, itemType, subType, _, equipLoc = GetItemInfo(itemId)
		if not name then
			return false
		end
		haystack = (name .. " " .. itemType .. " " .. subType .. " " .. (_G[equipLoc] or "")):lower()
		searchCache[itemId] = haystack
	end
	return haystack:find(searchText, 1, true) ~= nil
end

local lastCounts, currentCounts = {}, {}
local countsScanned = false

local function scanNewItems()
	wipe(currentCounts)
	for i = 1, #INVENTORY_BAGS do
		local bag = INVENTORY_BAGS[i]
		for slot = 1, GetContainerNumSlots(bag) do
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

local ItemMixin = {}

function ItemMixin:UpdateSearch()
	local itemId = self.itemId
	self:SetAlpha((searchText == "" or (itemId and itemMatchesSearch(itemId))) and 1 or SEARCH_FADE_ALPHA)
end

function ItemMixin:UpdateHighlight()
	if self.container.highlightBag == self.bag then
		self:LockHighlight()
	else
		self:UnlockHighlight()
	end
end

function ItemMixin:UpdateCooldown()
	CooldownFrame_SetTimer(self.cooldown, GetContainerItemCooldown(self.bag, self.slot))
end

function ItemMixin:UpdateLock()
	local _, _, locked = GetContainerItemInfo(self.bag, self.slot)
	SetItemButtonDesaturated(self, locked)
end

function ItemMixin:Update()
	local bag, slot = self.bag, self.slot
	local texture, count, locked, quality, readable = GetContainerItemInfo(bag, slot)
	local link = texture and GetContainerItemLink(bag, slot)
	local itemId = link and GetContainerItemID(bag, slot)

	self.link = link
	self.itemId = itemId
	self.hasItem = texture and 1 or nil
	self.readable = readable

	SetItemButtonTexture(self, texture)
	SetItemButtonCount(self, count)
	SetItemButtonDesaturated(self, locked)

	local r, g, b
	local level
	if link then
		local _, _, itemQuality, itemLevel, _, _, _, _, equipLoc = GetItemInfo(link)
		quality = itemQuality or quality
		if GetContainerItemQuestInfo(bag, slot) then
			r, g, b = 1, 0.8, 0
		elseif quality and quality >= 0 then
			r, g, b = GetItemQualityColor(quality)
		else
			r, g, b = 1, 1, 1
		end
		if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_AMMO" and equipLoc ~= "INVTYPE_BAG" then
			level = itemLevel
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

	if itemId and newItems[itemId] then
		self.glow:Show()
	else
		self.glow:Hide()
	end

	self:UpdateCooldown()
	self:UpdateSearch()
	self:UpdateHighlight()
end

local BagSlotMixin = {}

function BagSlotMixin:GetInventorySlot()
	local bag = self.bag
	if bag > NUM_BAG_SLOTS then
		return BankButtonIDToInvSlotID(bag - NUM_BAG_SLOTS, 1)
	elseif bag > BACKPACK_CONTAINER then
		return ContainerIDToInventoryID(bag)
	end
end

function BagSlotMixin:IsPurchasable()
	return self.bag > NUM_BAG_SLOTS and self.bag - NUM_BAG_SLOTS > GetNumBankSlots()
end

function BagSlotMixin:Update()
	local invSlot = self:GetInventorySlot()
	local icon = self.icon
	icon:SetDesaturated(false)

	if not invSlot then
		icon:SetTexture(BACKPACK_ICON)
		icon:SetVertexColor(1, 1, 1)
		return
	end

	local texture = GetInventoryItemTexture("player", invSlot)
	if texture then
		icon:SetTexture(texture)
		icon:SetVertexColor(1, 1, 1)
		icon:SetDesaturated(IsInventoryItemLocked(invSlot))
	elseif self:IsPurchasable() then
		icon:SetTexture(EMPTY_BAG_ICON)
		icon:SetVertexColor(1, 0.2, 0.2)
	else
		icon:SetTexture(EMPTY_BAG_ICON)
		icon:SetVertexColor(0.5, 0.5, 0.5)
	end
end

function BagSlotMixin:OnClick()
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
	local invSlot = self:GetInventorySlot()
	if invSlot and not self:IsPurchasable() then
		PickupBagFromSlot(invSlot)
	end
end

function BagSlotMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local invSlot = self:GetInventorySlot()
	if not invSlot then
		GameTooltip:SetText(self.bag == BANK_CONTAINER and BANK or BACKPACK_TOOLTIP, 1, 1, 1)
	elseif not GameTooltip:SetInventoryItem("player", invSlot) then
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
	local size = config.buttonSize

	button:SetSize(size, size)

	local normal = button:GetNormalTexture()
	normal:SetTexture(ns.Media.buttonNormal)
	normal:ClearAllPoints()
	normal:SetAllPoints()

	_G[name .. "IconQuestTexture"]:Hide()
	_G[name .. "Stock"]:Hide()

	local count = _G[name .. "Count"]
	count:SetFont(ns.Media.font, 12, "OUTLINE")
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", -1, 1)

	button.cooldown = _G[name .. "Cooldown"]
	CooldownTimer:Attach(button.cooldown)

	local level = button:CreateFontString(nil, "OVERLAY")
	level:SetFont(ns.Media.font, 10, "OUTLINE")
	level:SetPoint("TOPLEFT", 1, -1)
	button.level = level

	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW_TEXTURE)
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(0.3, 1, 0.3, 0.8)
	glow:SetSize(size * 1.6, size * 1.6)
	glow:SetPoint("CENTER")
	glow:Hide()
	button.glow = glow

	self.buttons[index] = button
	return button
end

function ContainerMixin:CreateBagButton(bag, index)
	local button = CreateFrame("Button", nil, self)
	ns.Mixin(button, BagSlotMixin)
	button.bag = bag
	button:SetSize(BAG_BUTTON_SIZE, BAG_BUTTON_SIZE)
	button:SetPoint("TOPLEFT", PADDING + (index - 1) * (BAG_BUTTON_SIZE + 2), -(PADDING + HEADER_HEIGHT))
	button:SetNormalTexture(ns.Media.buttonNormal)
	button:GetNormalTexture():SetAllPoints()
	button:SetHighlightTexture(ns.Media.buttonHighlight)

	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetAllPoints()

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
	currency.count:SetFont(ns.Media.font, 11, "OUTLINE")
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
		free = free + (GetContainerNumFreeSlots(bag) or 0)
		total = total + bagSize(bag)
	end
	self.freeText:SetFormattedText("%d / %d", total - free, total)
	self.moneyText:SetText(ns.FormatMoneyIcons(GetMoney()))
	self:UpdateBagButtons()
	self:UpdateCurrencies()
end

function ContainerMixin:Layout()
	local step = config.buttonSize + config.spacing
	local columns = self.columns
	local bags, buttons, holders = self.bags, self.buttons, self.holders
	local index = 0

	for i = 1, #bags do
		local bag = bags[i]
		local size = bagSize(bag)
		bagSizes[bag] = size
		updateBagFamily(bag)
		local holder = holders[bag]
		for slot = 1, size do
			index = index + 1
			local button = buttons[index] or self:CreateItemButton(index)
			button.bag, button.slot = bag, slot
			button:SetParent(holder)
			button:SetID(slot)
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
	local width = columns * step - config.spacing
	local height = rows * step - config.spacing
	self.itemArea:SetSize(width, height)
	self:SetSize(width + PADDING * 2, height + HEADER_HEIGHT + BAG_ROW_HEIGHT + FOOTER_HEIGHT + PADDING * 2)
	self:UpdateInfo()
end

function ContainerMixin:UpdateBag(bag)
	if not self:IsShown() then
		return
	end
	if bagSize(bag) ~= bagSizes[bag] then
		return self:Layout()
	end

	updateBagFamily(bag)
	local buttons = self.buttons
	for i = 1, #buttons do
		local button = buttons[i]
		if button.bag == bag and button:IsShown() then
			button:Update()
		end
	end
	self:UpdateInfo()
end

function ContainerMixin:SetSorting(sorting)
	self.sortButton:EnableMouse(not sorting)
	self.sortButton.icon:SetDesaturated(sorting)
end

function ContainerMixin:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

local function onShow(self)
	PlaySound("igBackPackOpen")
	self:Layout()
	if self == inventory then
		MainMenuBarBackpackButton:SetChecked(true)
	end
end

local function onHide(self)
	PlaySound("igBackPackClose")
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

local function setSearch(text)
	text = text:lower()
	if text == searchText then
		return
	end
	searchText = text
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

local function createSearchBox(frame)
	local search = CreateFrame("EditBox", nil, frame)
	search:SetAutoFocus(false)
	search:SetHeight(18)
	search:SetFont(ns.Media.font, 12)
	search:SetTextInsets(4, 4, 0, 0)
	search:SetMaxLetters(40)
	search:SetBackdrop(ns.CreateBackdrop(8))
	search:SetBackdropColor(0, 0, 0, 0.5)
	search:SetBackdropBorderColor(0.6, 0.6, 0.6)

	local placeholder = search:CreateFontString(nil, "OVERLAY")
	placeholder:SetFont(ns.Media.font, 12)
	placeholder:SetTextColor(0.5, 0.5, 0.5)
	placeholder:SetPoint("LEFT", 4, 0)
	placeholder:SetText("Search")
	search.placeholder = placeholder

	search:SetScript("OnEscapePressed", onSearchEscape)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	search:SetScript("OnEditFocusGained", onSearchFocusGained)
	search:SetScript("OnEditFocusLost", onSearchFocusLost)
	search:SetScript("OnTextChanged", onSearchTextChanged)

	return search
end

local function onCloseClick(self)
	self:GetParent():Hide()
end

local function onSortEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("Sort")
	GameTooltip:Show()
end

local function onSortClick(self)
	Bags:SortBags(self:GetParent())
end

local function createContainer(key, title, bags, columns)
	local frame = CreateFrame("Frame", ADDON_NAME .. key, UIParent)
	ns.Mixin(frame, ContainerMixin)
	frame.bags = bags
	frame.columns = columns
	frame.buttons = {}
	frame.bagButtons = {}
	frame:Hide()

	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	frame:SetBackdrop(ns.CreateBackdrop(14, 3))
	frame:SetBackdropColor(0, 0, 0, 0.6)
	frame:SetPoint(unpack(config[key]))
	frame:SetScript("OnShow", onShow)
	frame:SetScript("OnHide", onHide)
	tinsert(UISpecialFrames, frame:GetName())

	local titleText = frame:CreateFontString(nil, "OVERLAY")
	titleText:SetFont(ns.Media.fontBold, 13, "OUTLINE")
	titleText:SetPoint("TOPLEFT", PADDING, -PADDING - 3)
	titleText:SetText(title)
	frame.title = titleText

	local close = CreateFrame("Button", nil, frame)
	close:SetSize(26, 26)
	close:SetPoint("TOPRIGHT", -PADDING + 6, -PADDING + 6)
	close:SetNormalTexture(CLOSE_ICON)
	close:SetHighlightTexture(CLOSE_ICON_HIGHLIGHT)
	close:SetScript("OnClick", onCloseClick)
	frame.close = close

	local sortButton = CreateFrame("Button", nil, frame)
	sortButton:SetSize(BAG_BUTTON_SIZE, BAG_BUTTON_SIZE)
	sortButton:SetPoint("TOPRIGHT", -PADDING, -(PADDING + HEADER_HEIGHT))
	sortButton:SetNormalTexture(ns.Media.buttonNormal)
	sortButton:GetNormalTexture():SetAllPoints()
	sortButton:SetHighlightTexture(ns.Media.buttonHighlight)
	sortButton.icon = sortButton:CreateTexture(nil, "BORDER")
	sortButton.icon:SetTexture(SORT_ICON)
	sortButton.icon:SetAllPoints()
	sortButton:SetScript("OnEnter", onSortEnter)
	sortButton:SetScript("OnLeave", GameTooltip_Hide)
	sortButton:SetScript("OnClick", onSortClick)
	frame.sortButton = sortButton

	local search = createSearchBox(frame)
	search:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
	search:SetPoint("RIGHT", close, "LEFT", -4, 0)
	frame.search = search

	local itemArea = CreateFrame("Frame", nil, frame)
	itemArea:SetPoint("TOPLEFT", PADDING, -(PADDING + HEADER_HEIGHT + BAG_ROW_HEIGHT))
	frame.itemArea = itemArea

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
	frame.freeText:SetFont(ns.Media.font, 11, "OUTLINE")
	frame.freeText:SetPoint("BOTTOMLEFT", PADDING, PADDING)

	frame.moneyText = frame:CreateFontString(nil, "OVERLAY")
	frame.moneyText:SetFont(ns.Media.font, 11, "OUTLINE")
	frame.moneyText:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

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
	end
	wipe(dirtyBags)
end)

local function markDirty(bag)
	dirtyBags[bag] = true
	if bag >= BACKPACK_CONTAINER and bag <= NUM_BAG_SLOTS then
		inventoryDirty = true
	end
	updater:Show()
end

local function autoShow()
	if not inventory:IsShown() then
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

function Bags:BAG_UPDATE(bag)
	markDirty(bag)
end

function Bags:BAG_UPDATE_COOLDOWN()
	for i = 1, #frames do
		local frame = frames[i]
		if frame:IsShown() then
			frame:ForEachButton("UpdateCooldown")
		end
	end
end

function Bags:ITEM_LOCK_CHANGED(bag, slot)
	if slot then
		local frame = bagFrames[bag]
		if frame and frame:IsShown() then
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
		if frame:IsShown() then
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
end

function Bags:BANKFRAME_OPENED()
	atBank = true
	bank:Show()
	autoShow()
end

function Bags:BANKFRAME_CLOSED()
	atBank = false
	bank:Hide()
	autoHide()
end

function Bags:PLAYER_MONEY()
	for i = 1, #frames do
		local frame = frames[i]
		if frame:IsShown() then
			frame:UpdateInfo()
		end
	end
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
local blizzardIsBagOpen = IsBagOpen

function ToggleBag(bag)
	local frame = bagFrames[bag]
	if not frame then
		return blizzardToggleBag(bag)
	end
	if frame == bank and not atBank then
		return
	end
	frame:Toggle()
end

function ToggleBackpack()
	inventory:Toggle()
end

function OpenBackpack()
	inventory:Show()
end

function CloseBackpack()
	inventory:Hide()
end

function OpenAllBags(forceOpen)
	if forceOpen then
		inventory:Show()
	else
		inventory:Toggle()
	end
end

function CloseAllBags()
	local wasShown = inventory:IsShown()
	inventory:Hide()
	return wasShown
end

function IsBagOpen(bag)
	local frame = bagFrames[bag]
	if frame then
		return frame:IsShown() or nil
	end
	return blizzardIsBagOpen(bag)
end

function Bags:Initialize()
	inventory = createContainer("inventory", "Bags", INVENTORY_BAGS, config.inventoryColumns)
	bank = createContainer("bank", "Bank", BANK_BAGS, config.bankColumns)
	inventory.currencies = {}

	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", updateCurrencies)
	hooksecurefunc("BackpackTokenFrame_Update", updateCurrencies)

	BankFrame:UnregisterEvent("BANKFRAME_OPENED")
	BankFrame:UnregisterEvent("BANKFRAME_CLOSED")

	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("BAG_UPDATE_COOLDOWN")
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
	self:RegisterEvent("BANKFRAME_OPENED")
	self:RegisterEvent("BANKFRAME_CLOSED")
	self:RegisterEvent("PLAYER_MONEY")
	self:RegisterEvent("QUEST_ACCEPTED", questLogChanged)
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", function(_, unit)
		if unit == "player" then
			questLogChanged()
		end
	end)

	for showEvent, closeEvent in pairs(AUTO_SHOW_EVENTS) do
		self:RegisterEvent(showEvent, autoShow)
		self:RegisterEvent(closeEvent, autoHide)
	end
end
