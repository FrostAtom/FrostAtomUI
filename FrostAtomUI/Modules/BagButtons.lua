local ADDON_NAME, ns = ...

local L = ns.L

local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemID = GetContainerItemID
local GetContainerItemCooldown = GetContainerItemCooldown
local GetContainerItemQuestInfo = GetContainerItemQuestInfo
local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local GetItemQualityColor = GetItemQualityColor
local GetInventoryItemTexture = GetInventoryItemTexture
local IsInventoryItemLocked = IsInventoryItemLocked
local BankButtonIDToInvSlotID = BankButtonIDToInvSlotID
local GetNumBankSlots = GetNumBankSlots
local GetBankSlotCost = GetBankSlotCost
local CursorHasItem = CursorHasItem
local ClearCursor = ClearCursor
local PickupContainerItem = PickupContainerItem
local PutItemInBag = PutItemInBag
local PutItemInBackpack = PutItemInBackpack
local PickupBagFromSlot = PickupBagFromSlot
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local SetItemButtonTexture = SetItemButtonTexture
local SetItemButtonCount = SetItemButtonCount
local StaticPopup_Show = StaticPopup_Show
local GameTooltip = GameTooltip
local GetMouseFocus = GetMouseFocus
local bit_band = bit.band
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local BACKPACK_CONTAINER = BACKPACK_CONTAINER
local BANK_CONTAINER = BANK_CONTAINER

local Bags = ns:GetModule("Bags")
local CooldownTimer = ns:GetModule("CooldownTimer")
local P = Bags.shared

local config = ns.Config.bags
local SEARCH_FADE_ALPHA = 0.25
local BAG_BUTTON_SIZE = P.BAG_BUTTON_SIZE
local GLOW_SCALE = P.GLOW_SCALE

local ITEM_BUTTON_NAME = ADDON_NAME .. "BagItem%d"
local BACKPACK_ICON = "Interface\\Buttons\\Button-Backpack-Up"
local LOCK_ICON = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LOCK_ICON_SIZE = 14
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"

local QUIVER_FAMILY = 0x0003
local SOUL_FAMILY = 0x0004
local PROFESSION_FAMILY = 0x0FF8

local LOCK_MODIFIERS = { ALT = 1, ["ALT-CTRL"] = 3, ["ALT-SHIFT"] = 5, ["CTRL-SHIFT"] = 6 }

local BagItems = ns.BagItems

local ContainerMixin = P.ContainerMixin
local bagFamilies = P.bagFamilies
local newItems = P.newItems
local slotLocks = P.slotLocks
local bagInventorySlot = P.bagInventorySlot
local lockKey = P.lockKey
local scheduleRetry = P.scheduleRetry
local itemMatchesSearch = P.itemMatchesSearch

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

local function offlineItem(bag, slot)
	local entry = P.bankCache and P.bankCache[bag]
	local item = entry and entry.items[slot]
	if item then
		return item[1], item[2]
	end
end

local function lockModifierDown()
	local state = (IsAltKeyDown() and 1 or 0) + (IsControlKeyDown() and 2 or 0) + (IsShiftKeyDown() and 4 or 0)
	return state ~= 0 and LOCK_MODIFIERS[config.lockModifier] == state
end

local ItemMixin = {}

function ItemMixin:UpdateSearch()
	local itemId = self.itemId
	self:SetAlpha((not P.searchQuery or (itemId and itemMatchesSearch(itemId))) and 1 or SEARCH_FADE_ALPHA)
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

	SetItemButtonTexture(self, texture or ns.Media.emptySlot)
	SetItemButtonCount(self, count)

	local r, g, b
	local level
	local isQuestItem, questId, questActive
	if link and not offline then
		isQuestItem, questId, questActive = GetContainerItemQuestInfo(bag, slot)
	end
	ns.SetShown(self.questBang, questId and not questActive)
	if link then
		local itemLevel, itemQuality, pending = ns.ItemButtonLevel(link)
		quality = itemQuality or quality
		if isQuestItem or questId then
			local color = config.questItemColor
			r, g, b = color[1], color[2], color[3]
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
	local entry = P.bankCache and P.bankCache[self.bag]
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
		BankFrame.nextSlotCost = GetBankSlotCost(GetNumBankSlots())
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
		GameTooltip:SetText(self.bag == BANK_CONTAINER and L["Bank"] or BACKPACK_TOOLTIP, 1, 1, 1)
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

	local questBang = _G[name .. "IconQuestTexture"]
	questBang:SetTexture(TEXTURE_ITEM_QUEST_BANG)
	questBang:ClearAllPoints()
	questBang:SetAllPoints()
	questBang:Hide()
	button.questBang = questBang
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
