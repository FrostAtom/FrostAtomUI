local ADDON_NAME, ns = ...

local L = ns.L

local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetMoney = GetMoney
local GetBackpackCurrencyInfo = GetBackpackCurrencyInfo
local UnitFactionGroup = UnitFactionGroup
local MAX_WATCHED_TOKENS = MAX_WATCHED_TOKENS
local CloseBankFrame = CloseBankFrame
local PlaySound = PlaySound
local GameTooltip = GameTooltip
local tsort = table.sort
local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

local Bags = ns:GetModule("Bags")
local P = Bags.shared

local config = ns.Config.bags
local ROW_GAP = P.ROW_GAP
local HEADER_HEIGHT = P.HEADER_HEIGHT
local HEADER_MARGIN = 4
local BAG_BUTTON_SIZE = P.BAG_BUTTON_SIZE
local FOOTER_HEIGHT = BAG_BUTTON_SIZE
local GLYPH_SIZE = 16
local GLYPH_ICON_SIZE = 12
local GLOW_SCALE = P.GLOW_SCALE
local ARENA_POINTS_ICON = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
local HONOR_ICON = "Interface\\TargetingFrame\\UI-PVP-%s"
local MIN_COLUMNS = 4
local MAX_COLUMNS = 24
local CURRENCY_ICON_SIZE = 14
local CURRENCY_SPACING = 10
local MONEY_ICON_OVERHANG = 7
local RETRY_TRIES = P.RETRY_TRIES

local ContainerMixin = P.ContainerMixin
local bagFrames = P.bagFrames
local bagFamilies = P.bagFamilies
local bagSizes = P.bagSizes
local newItems = P.newItems
local frames = P.frames
local bagSize = P.bagSize
local createSearchBox = P.createSearchBox

local function frameWidth(columns)
	return columns * (config.buttonSize + config.spacing) - config.spacing + config.padding * 2
end

local function headerMargin()
	return config.movable and HEADER_MARGIN or 0
end

local function frameHeight(rows)
	return rows * (config.buttonSize + config.spacing)
		- config.spacing
		+ HEADER_HEIGHT
		+ headerMargin() * 2
		+ FOOTER_HEIGHT
		+ ROW_GAP * 2
		+ config.padding * 2
end

local function updateBagFamily(bag)
	local _, family = GetContainerNumFreeSlots(bag)
	bagFamilies[bag] = family or 0
end

function ContainerMixin:BagSize(bag)
	if self.offline then
		local entry = P.bankCache and P.bankCache[bag]
		return entry and entry.size or 0
	end
	return bagSize(bag)
end

function ContainerMixin:FreeSlots(bag, size)
	if self.offline then
		local entry = P.bankCache and P.bankCache[bag]
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
	local margin = headerMargin()
	if config.movable then
		self:RegisterForDrag("LeftButton")
	else
		self:RegisterForDrag()
	end
	self.close:ClearAllPoints()
	self.close:SetPoint("TOPRIGHT", -padding, -padding - margin - (HEADER_HEIGHT - GLYPH_SIZE) / 2)
	local searchAnchor = self.sortButton
	if self.bankButton then
		ns.SetShown(self.bankButton, config.offlineBank)
		if config.offlineBank then
			searchAnchor = self.bankButton
		end
	end
	self.search:ClearAllPoints()
	self.search:SetPoint("TOPLEFT", padding, -padding - margin)
	self.search:SetPoint("RIGHT", searchAnchor, "LEFT", -ROW_GAP, 0)
	self.itemArea:ClearAllPoints()
	self.itemArea:SetPoint("TOPLEFT", padding, -(padding + margin * 2 + HEADER_HEIGHT + ROW_GAP))
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
	local bags, buttons, holders, bagOffsets = self.bags, self.buttons, self.holders, self.bagOffsets
	local offline = self.offline or false
	local index = 0

	self:LayoutChrome()

	for i = 1, #bags do
		local bag = bags[i]
		local size = self:BagSize(bag)
		bagSizes[bag] = size
		bagOffsets[bag] = index
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
	local buttons, offset = self.buttons, self.bagOffsets[bag]
	for i = offset + 1, offset + bagSizes[bag] do
		buttons[i]:Update()
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

local function onDragStart(self)
	self.moving = true
	self:StartMoving()
end

local function onDragStop(self)
	if not self.moving then
		return
	end
	self.moving = nil
	self:StopMovingOrSizing()
	self:SetUserPlaced(false)
	ns.Movers.SavePosition(self.positionPath)
end

local function onShow(self)
	if config.playSounds then
		PlaySound("igBackPackOpen")
	end
	P.retryBudget = RETRY_TRIES
	if self == P.bank then
		self:SetOffline(not P.atBank)
	end
	self:Layout()
	if self == P.inventory then
		MainMenuBarBackpackButton:SetChecked(true)
	end
end

local function onHide(self)
	onDragStop(self)
	if config.playSounds then
		PlaySound("igBackPackClose")
	end
	if self == P.bank then
		if P.atBank then
			CloseBankFrame()
		end
	else
		P.autoOpened = false
		wipe(newItems)
		MainMenuBarBackpackButton:SetChecked(false)
	end
end

local function onCloseClick(self)
	self:GetParent():Hide()
end

local function onSortClick(self)
	Bags:SortBags(self:GetParent())
end

local function onBankButtonClick()
	local bank, bankCache = P.bank, P.bankCache
	if P.atBank or bank:IsShown() then
		return bank:Toggle()
	end
	if not bankCache or not next(bankCache) then
		ns.Print(L["visit a banker once to view the bank from anywhere"])
		return
	end
	bank:Show()
end
P.onBankButtonClick = onBankButtonClick

local function createGlyphButton(parent, glyph, tooltip, onClick)
	local button = ns.CreateGlyphButton(parent, glyph, GLYPH_ICON_SIZE, tooltip)
	button:SetSize(GLYPH_SIZE, GLYPH_SIZE)
	button.tooltipAnchor = "ANCHOR_TOP"
	button:SetScript("OnClick", onClick)
	return button
end
P.createGlyphButton = createGlyphButton

local moneyEntries = {}

local function sortByMoney(a, b)
	if a.money ~= b.money then
		return a.money > b.money
	end
	return a.name < b.name
end

local function onMoneyEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	local gold = ns.Storage.Slot("gold"):Get()
	if config.altGold and gold then
		local playerRealm = P.playerRealm
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
			local r, g, b = ns.ClassColor(entry.class)
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
	frame.positionPath = "bags." .. key
	frame.buttons = {}
	frame.bagButtons = {}
	frame.bagOffsets = {}
	frame:Hide()

	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	frame:SetMovable(true)
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
	frame:SetScript("OnDragStart", onDragStart)
	frame:SetScript("OnDragStop", onDragStop)
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
P.createContainer = createContainer
