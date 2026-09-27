local _, ns = ...

local L = ns.L

local CanMerchantRepair = CanMerchantRepair
local GetRepairAllCost = GetRepairAllCost
local RepairAllItems = RepairAllItems
local GetMoney = GetMoney
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemInfo = GetContainerItemInfo
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetMerchantNumItems = GetMerchantNumItems
local GetMerchantItemLink = GetMerchantItemLink
local GetBuybackItemLink = GetBuybackItemLink
local GetNumBuybackItems = GetNumBuybackItems
local UseContainerItem = UseContainerItem
local IsShiftKeyDown = IsShiftKeyDown
local IsInGuild = IsInGuild
local CanGuildBankRepair = CanGuildBankRepair
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local GetGuildBankMoney = GetGuildBankMoney
local min = math.min
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local MERCHANT_ITEMS_PER_PAGE = MERCHANT_ITEMS_PER_PAGE
local BUYBACK_ITEMS_PER_PAGE = BUYBACK_ITEMS_PER_PAGE

local Misc = ns:GetModule("Misc")

local POOR_QUALITY = 0
local LEVEL_RETRY_DELAY = 0.5
local LEVEL_RETRY_TRIES = 3
local formatMoney = ns.FormatMoney

local function sellGreys()
	local total, count = 0, 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
				if not quality then
					quality = ns.LinkQuality(link)
				end
				if quality == POOR_QUALITY and (not price or price > 0) then
					local _, stack, locked = GetContainerItemInfo(bag, slot)
					if not locked then
						UseContainerItem(bag, slot)
						total = total + (price or 0) * (stack or 1)
						count = count + 1
					end
				end
			end
		end
	end

	if count > 0 then
		ns.Print(L["sold %d grey item(s) for %s"], count, formatMoney(total))
	end
end

local function guildFunds()
	if not IsInGuild() or not CanGuildBankRepair() then
		return 0
	end
	local withdraw, bank = GetGuildBankWithdrawMoney(), GetGuildBankMoney()
	if withdraw == -1 then
		return bank
	end
	return min(withdraw, bank)
end

local function repair()
	if not CanMerchantRepair() then
		return
	end

	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost <= 0 then
		return
	end

	if ns.Config.merchant.guildRepair and guildFunds() >= cost then
		RepairAllItems(1)
		ns.Print(L["repaired for %s from the guild bank"], formatMoney(cost))
	elseif GetMoney() >= cost then
		RepairAllItems()
		ns.Print(L["repaired for %s"], formatMoney(cost))
	else
		ns.Print(L["not enough money to repair (%s)"], formatMoney(cost))
	end
end

local levelTexts = {}
local levelRetries = 0
local levelRetryPending = false
local levelPending = false
local updateLevels

local function levelText(button)
	local text = levelTexts[button]
	if not text then
		text = button:CreateFontString(nil, "OVERLAY")
		text:SetPoint("TOPLEFT", 1, -1)
		levelTexts[button] = text
	end
	local font = ns.Config.bags.levelFont
	if text.fontSize ~= font.size or text.fontOutline ~= font.outline then
		text.fontSize, text.fontOutline = font.size, font.outline
		ns.SetFont(text, font.size, font.outline)
	end
	return text
end

local function setButtonLevel(button, link, show)
	if not button then
		return
	end
	local level, quality, pending
	if show and link then
		level, quality, pending = ns.ItemButtonLevel(link)
	end
	if pending then
		levelPending = true
	end
	if not level then
		local text = levelTexts[button]
		if text then
			text:SetText("")
		end
		return
	end
	local text = levelText(button)
	text:SetText(level)
	text:SetTextColor(GetItemQualityColor(quality or 1))
end

local WIDE_COLUMNS = 4
local ROWS = 5
local WIDE_ITEMS = WIDE_COLUMNS * ROWS
local ITEM_LEFT, ITEM_TOP = 24, -80
local ITEM_WIDTH, ITEM_HEIGHT = 153, 44
local COLUMN_GAP, ROW_GAP = 12, 8
local BASE_WIDTH = 384
local EXTRA_WIDTH = (WIDE_COLUMNS - 2) * (ITEM_WIDTH + COLUMN_GAP)
local BUYBACK_ITEM_LEFT, BUYBACK_ITEM_TOP = 189, -385
local NEXT_BUTTON_X, NEXT_BUTTON_Y = 324, 156
local SEARCH_WIDTH, SEARCH_HEIGHT = 260, 24
local NARROW_SEARCH_WIDTH = 200
local SEARCH_TOP = -44
local ART_SIZE = 256
local TOP_ART = "Interface\\MerchantFrame\\UI-Merchant-TopLeft"
local BOTTOM_ART = "Interface\\MerchantFrame\\UI-Merchant-BotLeft"
local STRETCHES = {
	{ art = TOP_ART, split = 0.6, left = 0.6, right = 0.98, bottom = 1 },
	{ art = BOTTOM_ART, split = 0.625, left = 0.3, right = 0.6, bottom = 1 },
	{ name = "MerchantFrameBottomLeftBorder", split = 0.6, left = 0.1, right = 0.55, bottom = 0.4765625, border = true },
}

local searchBox, searchQuery, searchText
local filtered = {}
local searchUncertain = false
local stretches
local originalPoints

local function config()
	return ns.Config.merchant
end

local function wideActive()
	local c = config()
	return c.enabled and c.wideFrame
end

local function searchActive()
	local c = config()
	return c.enabled and c.searchBox and searchQuery ~= nil
end

local function itemsPerPage()
	return wideActive() and WIDE_ITEMS or MERCHANT_ITEMS_PER_PAGE
end

local function refresh()
	if MerchantFrame:IsShown() then
		MerchantFrame_Update()
	end
end

local function retryLevels()
	levelRetryPending = false
	if not MerchantFrame:IsShown() then
		return
	end
	if searchUncertain and searchActive() and MerchantFrame.selectedTab == 1 then
		refresh()
	else
		updateLevels()
	end
end

function updateLevels()
	local c = config()
	local show = c.enabled and c.showItemLevel
	levelPending = false
	if MerchantFrame.selectedTab == 2 then
		for i = 1, BUYBACK_ITEMS_PER_PAGE do
			setButtonLevel(_G["MerchantItem" .. i .. "ItemButton"], GetBuybackItemLink(i), show)
		end
	else
		for i = 1, itemsPerPage() do
			local button = _G["MerchantItem" .. i .. "ItemButton"]
			setButtonLevel(button, button:IsShown() and GetMerchantItemLink(button:GetID()) or nil, show)
		end
		setButtonLevel(MerchantBuyBackItemItemButton, GetBuybackItemLink(GetNumBuybackItems()), show)
	end

	if (levelPending or searchUncertain) and not levelRetryPending and levelRetries < LEVEL_RETRY_TRIES then
		levelRetries = levelRetries + 1
		levelRetryPending = true
		ns.After(LEVEL_RETRY_DELAY, retryLevels)
	end
end

local function itemFrame(i)
	local frame = _G["MerchantItem" .. i]
	if not frame then
		frame = CreateFrame("Frame", "MerchantItem" .. i, MerchantFrame, "MerchantItemTemplate")
	end
	return frame
end

local function saveOriginalPoints()
	originalPoints = {}
	local frames = { MerchantNextPageButton, MerchantBuyBackItem }
	for i = 1, BUYBACK_ITEMS_PER_PAGE do
		frames[#frames + 1] = _G["MerchantItem" .. i]
	end
	for _, frame in ipairs(frames) do
		local points = {}
		for p = 1, frame:GetNumPoints() do
			points[p] = { frame:GetPoint(p) }
		end
		originalPoints[frame] = points
	end
end

local function restorePoints()
	for frame, points in pairs(originalPoints) do
		frame:ClearAllPoints()
		for _, point in ipairs(points) do
			frame:SetPoint(unpack(point))
		end
	end
end

local function artTexture(file)
	for i = 1, MerchantFrame:GetNumRegions() do
		local region = select(i, MerchantFrame:GetRegions())
		if region:GetObjectType() == "Texture" and region:GetTexture() == file then
			return region
		end
	end
end

local function sliceTexture(source, left, right, bottom, width)
	local texture = MerchantFrame:CreateTexture(nil, source:GetDrawLayer())
	texture:SetTexture(source:GetTexture())
	texture:SetSize(width, source:GetHeight())
	texture:SetTexCoord(left, right, 0, bottom)
	return texture
end

local function createStretch(info)
	local texture = info.art and artTexture(info.art) or _G[info.name]
	local stretch = { texture = texture, info = info, pieces = {} }
	local tileWidth = (info.right - info.left) * ART_SIZE
	local x = 0
	while x < EXTRA_WIDTH do
		local width = min(tileWidth, EXTRA_WIDTH - x)
		local piece = sliceTexture(texture, info.left, info.left + (info.right - info.left) * width / tileWidth, info.bottom, width)
		piece:SetPoint("LEFT", texture, "RIGHT", x, 0)
		stretch.pieces[#stretch.pieces + 1] = piece
		x = x + width
	end
	local tail = sliceTexture(texture, info.split, 1, info.bottom, (1 - info.split) * ART_SIZE)
	tail:SetPoint("LEFT", texture, "RIGHT", EXTRA_WIDTH, 0)
	stretch.pieces[#stretch.pieces + 1] = tail
	stretch.tail = tail
	return stretch
end

local function createStretches()
	stretches = {}
	for _, info in ipairs(STRETCHES) do
		stretches[#stretches + 1] = createStretch(info)
	end
end

local function applyStretches(wide, buyback)
	for _, stretch in ipairs(stretches) do
		local info, texture = stretch.info, stretch.texture
		local split = wide and info.split or 1
		texture:SetWidth(split * ART_SIZE)
		texture:SetTexCoord(0, split, 0, info.bottom)
		local shown = wide and not (info.border and buyback)
		for _, piece in ipairs(stretch.pieces) do
			ns.SetShown(piece, shown)
		end
		if info.border then
			MerchantFrameBottomRightBorder:ClearAllPoints()
			if wide then
				MerchantFrameBottomRightBorder:SetPoint("LEFT", stretch.tail, "RIGHT")
			else
				MerchantFrameBottomRightBorder:SetPoint("LEFT", texture, "RIGHT")
			end
		end
	end
end

local function placeItem(i, row, column)
	local frame = itemFrame(i)
	frame:ClearAllPoints()
	frame:SetPoint(
		"TOPLEFT",
		MerchantFrame,
		"TOPLEFT",
		ITEM_LEFT + column * (ITEM_WIDTH + COLUMN_GAP),
		ITEM_TOP - row * (ITEM_HEIGHT + ROW_GAP)
	)
end

local function applyLayout()
	local wide = wideActive()
	if wide and not stretches then
		createStretches()
	end
	if not wide and not MerchantFrame.frostAtomWide then
		return
	end
	MerchantFrame.frostAtomWide = wide or nil
	MerchantFrame:SetWidth(wide and BASE_WIDTH + EXTRA_WIDTH or BASE_WIDTH)
	local buyback = MerchantFrame.selectedTab == 2
	applyStretches(wide, buyback)
	if not wide then
		restorePoints()
		for i = BUYBACK_ITEMS_PER_PAGE + 1, WIDE_ITEMS do
			itemFrame(i):Hide()
		end
		return
	end
	local count = buyback and BUYBACK_ITEMS_PER_PAGE or WIDE_ITEMS
	for i = 1, count do
		placeItem(i, floor((i - 1) / WIDE_COLUMNS), (i - 1) % WIDE_COLUMNS)
	end
	for i = count + 1, WIDE_ITEMS do
		itemFrame(i):Hide()
	end
	if buyback then
		BuybackFrameTopLeft:Hide()
		BuybackFrameTopRight:Hide()
		BuybackFrameBotLeft:Hide()
		BuybackFrameBotRight:Hide()
	end
	MerchantNextPageButton:ClearAllPoints()
	MerchantNextPageButton:SetPoint("CENTER", MerchantFrame, "BOTTOMLEFT", NEXT_BUTTON_X + EXTRA_WIDTH, NEXT_BUTTON_Y)
	MerchantBuyBackItem:ClearAllPoints()
	MerchantBuyBackItem:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", BUYBACK_ITEM_LEFT + EXTRA_WIDTH, BUYBACK_ITEM_TOP)
end

local function tintItem(merchantButton, itemButton, nr, ng, nb, sr, sg, sb, tr, tg, tb)
	SetItemButtonNameFrameVertexColor(merchantButton, nr, ng, nb)
	SetItemButtonSlotVertexColor(merchantButton, sr, sg, sb)
	SetItemButtonTextureVertexColor(itemButton, tr, tg, tb)
	SetItemButtonNormalTextureVertexColor(itemButton, tr, tg, tb)
end

local function renderItem(i, index)
	local merchantButton = itemFrame(i)
	local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
	local nameText = _G["MerchantItem" .. i .. "Name"]
	local money = _G["MerchantItem" .. i .. "MoneyFrame"]
	local altCurrency = _G["MerchantItem" .. i .. "AltCurrencyFrame"]
	merchantButton:Show()
	if not index then
		itemButton.price = nil
		itemButton.hasItem = nil
		itemButton:Hide()
		SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
		SetItemButtonSlotVertexColor(merchantButton, 0.4, 0.4, 0.4)
		nameText:SetText("")
		money:Hide()
		altCurrency:Hide()
		return
	end
	local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
	nameText:SetText(name)
	SetItemButtonCount(itemButton, quantity)
	SetItemButtonStock(itemButton, numAvailable)
	SetItemButtonTexture(itemButton, texture)
	itemButton.link = GetMerchantItemLink(index)
	itemButton.texture = texture
	if extendedCost then
		itemButton.extendedCost = true
		MerchantFrame_UpdateAltCurrency(index, i)
		altCurrency:ClearAllPoints()
		if price <= 0 then
			itemButton.price = nil
			altCurrency:SetPoint("BOTTOMLEFT", "MerchantItem" .. i .. "NameFrame", "BOTTOMLEFT", 0, 31)
			money:Hide()
		else
			itemButton.price = price
			MoneyFrame_Update(money:GetName(), price)
			altCurrency:SetPoint("LEFT", money:GetName(), "RIGHT", -14, 0)
			money:Show()
		end
		altCurrency:Show()
	else
		itemButton.price = price
		itemButton.extendedCost = nil
		MoneyFrame_Update(money:GetName(), price)
		altCurrency:Hide()
		money:Show()
	end
	itemButton.hasItem = true
	itemButton:SetID(index)
	itemButton:Show()
	if numAvailable == 0 then
		if not isUsable then
			tintItem(merchantButton, itemButton, 0.5, 0, 0, 0.5, 0, 0, 0.5, 0, 0)
		else
			tintItem(merchantButton, itemButton, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
		end
	elseif not isUsable then
		tintItem(merchantButton, itemButton, 1, 0, 0, 1, 0, 0, 0.9, 0, 0)
	else
		tintItem(merchantButton, itemButton, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1, 1)
	end
end

local function itemMatches(index)
	local link = GetMerchantItemLink(index)
	local id = link and tonumber(link:match("item:(%d+)"))
	if id then
		local matched, uncertain = ns.BagItems.Matches(searchQuery, id)
		if matched then
			return true
		end
		if not uncertain then
			return false
		end
		searchUncertain = true
	end
	local name = GetMerchantItemInfo(index)
	return name ~= nil and name:lower():find(searchText, 1, true) ~= nil
end

local function collectFiltered(numItems)
	wipe(filtered)
	searchUncertain = false
	for index = 1, numItems do
		if itemMatches(index) then
			filtered[#filtered + 1] = index
		end
	end
	return #filtered
end

local function updatePaging(count, perPage)
	local pages = max(1, ceil(count / perPage))
	if MerchantFrame.page > pages then
		MerchantFrame.page = pages
	end
	local page = MerchantFrame.page
	MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, page, pages)
	if count > perPage then
		if page == 1 then
			MerchantPrevPageButton:Disable()
		else
			MerchantPrevPageButton:Enable()
		end
		if page == pages then
			MerchantNextPageButton:Disable()
		else
			MerchantNextPageButton:Enable()
		end
		MerchantPageText:Show()
		MerchantPrevPageButton:Show()
		MerchantNextPageButton:Show()
	else
		MerchantPageText:Hide()
		MerchantPrevPageButton:Hide()
		MerchantNextPageButton:Hide()
	end
end

local function renderMerchant()
	local wide, search = wideActive(), searchActive()
	if not wide and not search then
		searchUncertain = false
		return
	end
	local numItems = GetMerchantNumItems()
	local perPage = itemsPerPage()
	local count = search and collectFiltered(numItems) or numItems
	updatePaging(count, perPage)
	local offset = (MerchantFrame.page - 1) * perPage
	for i = 1, perPage do
		local position = offset + i
		if search then
			renderItem(i, filtered[position])
		else
			renderItem(i, position <= numItems and position or nil)
		end
	end
end

local function updateSearchBox(buyback)
	local c = config()
	if not (c.enabled and c.searchBox) or buyback then
		if searchBox then
			searchBox:Hide()
		end
		return
	end
	searchBox:ClearAllPoints()
	local wide = wideActive()
	local right = wide and BASE_WIDTH + EXTRA_WIDTH or BASE_WIDTH
	searchBox:SetWidth(wide and SEARCH_WIDTH or NARROW_SEARCH_WIDTH)
	searchBox:SetPoint("TOPRIGHT", MerchantFrame, "TOPLEFT", right - 42, SEARCH_TOP)
	searchBox:Show()
end

local function onSearchChanged(self)
	local text = strtrim(self:GetText()):lower()
	if text == (searchText or "") then
		return
	end
	searchText = text ~= "" and text or nil
	searchQuery = searchText and ns.BagItems.CompileSearch(searchText) or nil
	levelRetries = 0
	MerchantFrame.page = 1
	refresh()
end

local function createSearchBox()
	searchBox = ns.CreateEditBox(MerchantFrame, SEARCH_WIDTH, SEARCH_HEIGHT, nil, L["Search"])
	searchBox:SetFrameLevel(MerchantFrame:GetFrameLevel() + 5)
	searchBox:HookScript("OnTextChanged", onSearchChanged)
	searchBox:SetScript("OnEscapePressed", searchBox.ClearFocus)
	searchBox:SetScript("OnEnterPressed", searchBox.ClearFocus)
	searchBox:SetScript("OnEnter", ns.ShowItemSearchHelp)
	searchBox:SetScript("OnLeave", GameTooltip_Hide)
	MerchantFrame:HookScript("OnHide", function()
		searchBox:SetText("")
		searchBox:ClearFocus()
	end)
end

local function onMerchantInfo()
	if not searchBox and config().searchBox then
		createSearchBox()
	end
	applyLayout()
	renderMerchant()
	updateSearchBox(false)
	updateLevels()
end

local function onBuybackInfo()
	applyLayout()
	updateSearchBox(true)
	updateLevels()
end

saveOriginalPoints()
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", onMerchantInfo)
hooksecurefunc("MerchantFrame_UpdateBuybackInfo", onBuybackInfo)

Misc:WatchConfig("merchant", function()
	if MerchantFrame:IsShown() then
		MerchantFrame_Update()
	end
end)

Misc:RegisterEvent("MERCHANT_SHOW", function()
	levelRetries = 0
	local config = ns.Config.merchant
	if not config.enabled or (config.shiftToSkip and IsShiftKeyDown()) then
		return
	end
	if config.sellGreys then
		sellGreys()
	end
	if config.autoRepair then
		repair()
	end
end)
