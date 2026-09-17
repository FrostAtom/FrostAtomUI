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
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS
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
	for _, bag in ipairs(INVENTORY_BAGS) do
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
	if searchText == "" then
		self:SetAlpha(1)
	elseif self.itemId and itemMatchesSearch(self.itemId) then
		self:SetAlpha(1)
	else
		self:SetAlpha(SEARCH_FADE_ALPHA)
	end
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

	self.link = link
	self.itemId = link and GetContainerItemID(bag, slot)
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

	if self.itemId and newItems[self.itemId] then
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
	if self.bag > NUM_BAG_SLOTS then
		return BankButtonIDToInvSlotID(self.bag - NUM_BAG_SLOTS, 1)
	elseif self.bag > BACKPACK_CONTAINER then
		return ContainerIDToInventoryID(self.bag)
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
	else
		icon:SetTexture(EMPTY_BAG_ICON)
		if self:IsPurchasable() then
			icon:SetVertexColor(1, 0.2, 0.2)
		else
			icon:SetVertexColor(0.5, 0.5, 0.5)
		end
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

function ContainerMixin:ForEachButton(method, ...)
	for _, button in ipairs(self.buttons) do
		if button:IsShown() then
			button[method](button, ...)
		end
	end
end

local itemButtonCount = 0

function ContainerMixin:CreateItemButton(index)
	itemButtonCount = itemButtonCount + 1
	local button = CreateFrame("Button", ITEM_BUTTON_NAME:format(itemButtonCount), self.itemArea, "ContainerFrameItemButtonTemplate")
	ns.Mixin(button, ItemMixin)
	button.container = self
	local name = button:GetName()
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

	button.level = button:CreateFontString(nil, "OVERLAY")
	button.level:SetFont(ns.Media.font, 10, "OUTLINE")
	button.level:SetPoint("TOPLEFT", 1, -1)

	button.glow = button:CreateTexture(nil, "OVERLAY")
	button.glow:SetTexture(GLOW_TEXTURE)
	button.glow:SetBlendMode("ADD")
	button.glow:SetVertexColor(0.3, 1, 0.3, 0.8)
	button.glow:SetSize(size * 1.6, size * 1.6)
	button.glow:SetPoint("CENTER")
	button.glow:Hide()

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
	for _, button in ipairs(self.bagButtons) do
		button:Update()
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
	if not self.currencies then
		return
	end

	local previous = self.freeText
	for index = 1, MAX_WATCHED_TOKENS do
		local name, count, currencyType, icon = GetBackpackCurrencyInfo(index)
		local currency = self.currencies[index] or self:CreateCurrency(index)
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
	local free, total = 0, 0
	for _, bag in ipairs(self.bags) do
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
	local index = 0

	for _, bag in ipairs(self.bags) do
		local size = bagSize(bag)
		bagSizes[bag] = size
		bagFamilies[bag] = select(2, GetContainerNumFreeSlots(bag)) or 0
		local holder = self.holders[bag]
		for slot = 1, size do
			index = index + 1
			local button = self.buttons[index] or self:CreateItemButton(index)
			button.bag, button.slot = bag, slot
			button:SetParent(holder)
			button:SetID(slot)
			button:ClearAllPoints()
			button:SetPoint(ns.GridPoint("TOPLEFT", index, self.columns, step))
			button:Show()
			button:Update()
		end
	end

	for i = index + 1, #self.buttons do
		self.buttons[i]:Hide()
	end

	local rows = ceil(index / self.columns)
	local width = self.columns * step - config.spacing
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

	bagFamilies[bag] = select(2, GetContainerNumFreeSlots(bag)) or 0
	for _, button in ipairs(self.buttons) do
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

local function updateBagBar(shown)
	MainMenuBarBackpackButton:SetChecked(shown)
end

local function onShow(self)
	PlaySound("igBackPackOpen")
	self:Layout()
	if self == inventory then
		updateBagBar(true)
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
		updateBagBar(false)
	end
end

local function setSearch(text)
	text = text:lower()
	if text == searchText then
		return
	end
	searchText = text
	for _, frame in ipairs(frames) do
		if frame.search:GetText():lower() ~= text then
			frame.search:SetText(text)
		end
		if frame:IsShown() then
			frame:ForEachButton("UpdateSearch")
		end
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

	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	search:SetScript("OnEditFocusGained", function()
		placeholder:Hide()
	end)
	search:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then
			placeholder:Show()
		end
	end)
	search:SetScript("OnTextChanged", function(self)
		setSearch(self:GetText())
		if self:GetText() ~= "" then
			placeholder:Hide()
		elseif not self:HasFocus() then
			placeholder:Show()
		end
	end)

	return search
end

local function createContainer(key, title, bags, columns)
	local frame = CreateFrame("Frame", ADDON_NAME .. key, UIParent)
	ns.Mixin(frame, ContainerMixin)
	frame.key = key
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

	frame.title = frame:CreateFontString(nil, "OVERLAY")
	frame.title:SetFont(ns.Media.fontBold, 13, "OUTLINE")
	frame.title:SetPoint("TOPLEFT", PADDING, -PADDING - 3)
	frame.title:SetText(title)

	frame.close = CreateFrame("Button", nil, frame)
	frame.close:SetSize(26, 26)
	frame.close:SetPoint("TOPRIGHT", -PADDING + 6, -PADDING + 6)
	frame.close:SetNormalTexture(CLOSE_ICON)
	frame.close:SetHighlightTexture(CLOSE_ICON_HIGHLIGHT)
	frame.close:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame.sortButton = CreateFrame("Button", nil, frame)
	frame.sortButton:SetSize(BAG_BUTTON_SIZE, BAG_BUTTON_SIZE)
	frame.sortButton:SetPoint("TOPRIGHT", -PADDING, -(PADDING + HEADER_HEIGHT))
	frame.sortButton:SetNormalTexture(ns.Media.buttonNormal)
	frame.sortButton:GetNormalTexture():SetAllPoints()
	frame.sortButton:SetHighlightTexture(ns.Media.buttonHighlight)
	frame.sortButton.icon = frame.sortButton:CreateTexture(nil, "BORDER")
	frame.sortButton.icon:SetTexture(SORT_ICON)
	frame.sortButton.icon:SetAllPoints()
	frame.sortButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Sort")
		GameTooltip:Show()
	end)
	frame.sortButton:SetScript("OnLeave", GameTooltip_Hide)
	frame.sortButton:SetScript("OnClick", function()
		Bags:SortBags(frame)
	end)

	frame.search = createSearchBox(frame)
	frame.search:SetPoint("LEFT", frame.title, "RIGHT", 10, 0)
	frame.search:SetPoint("RIGHT", frame.close, "LEFT", -4, 0)

	for i, bag in ipairs(bags) do
		frame:CreateBagButton(bag, i)
	end

	frame.itemArea = CreateFrame("Frame", nil, frame)
	frame.itemArea:SetPoint("TOPLEFT", PADDING, -(PADDING + HEADER_HEIGHT + BAG_ROW_HEIGHT))

	frame.holders = setmetatable({}, {
		__index = function(holders, bag)
			local holder = CreateFrame("Frame", nil, frame.itemArea)
			holder:SetID(bag)
			holder:SetAllPoints()
			holders[bag] = holder
			return holder
		end,
	})

	frame.freeText = frame:CreateFontString(nil, "OVERLAY")
	frame.freeText:SetFont(ns.Media.font, 11, "OUTLINE")
	frame.freeText:SetPoint("BOTTOMLEFT", PADDING, PADDING)

	frame.moneyText = frame:CreateFontString(nil, "OVERLAY")
	frame.moneyText:SetFont(ns.Media.font, 11, "OUTLINE")
	frame.moneyText:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

	for _, bag in ipairs(bags) do
		bagFrames[bag] = frame
	end
	frames[#frames + 1] = frame

	return frame
end

local updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function(self)
	self:Hide()

	for bag in pairs(dirtyBags) do
		if bag >= BACKPACK_CONTAINER and bag <= NUM_BAG_SLOTS then
			scanNewItems()
			break
		end
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

function Bags:BAG_UPDATE(bag)
	markDirty(bag)
end

function Bags:BAG_UPDATE_COOLDOWN()
	for _, frame in ipairs(frames) do
		if frame:IsShown() then
			frame:ForEachButton("UpdateCooldown")
		end
	end
end

function Bags:ITEM_LOCK_CHANGED(bag, slot)
	if slot then
		local frame = bagFrames[bag]
		if frame and frame:IsShown() then
			for _, button in ipairs(frame.buttons) do
				if button.bag == bag and button.slot == slot and button:IsShown() then
					button:UpdateLock()
					return
				end
			end
		end
		return
	end

	for _, frame in ipairs(frames) do
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
	for _, frame in ipairs(frames) do
		if frame:IsShown() then
			frame:UpdateInfo()
		end
	end
end

local function questLogChanged()
	for _, bag in ipairs(INVENTORY_BAGS) do
		markDirty(bag)
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

	local function updateCurrencies()
		if inventory:IsShown() then
			inventory:UpdateCurrencies()
		end
	end
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
