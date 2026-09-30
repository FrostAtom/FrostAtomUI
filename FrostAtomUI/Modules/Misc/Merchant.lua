local ADDON_NAME, ns = ...

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
local GetMerchantItemInfo = GetMerchantItemInfo
local GetMerchantItemCostInfo = GetMerchantItemCostInfo
local GetMerchantItemCostItem = GetMerchantItemCostItem
local GetHonorCurrency = GetHonorCurrency
local GetArenaCurrency = GetArenaCurrency
local GetItemCount = GetItemCount
local min = math.min
local sort = table.sort
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
local SEARCH_LEFT = 82
local ART_SIZE = 256
local TOP_ART = "Interface\\MerchantFrame\\UI-Merchant-TopLeft"
local BOTTOM_ART = "Interface\\MerchantFrame\\UI-Merchant-BotLeft"
local STRETCHES = {
	{ art = TOP_ART, split = 0.6, left = 0.6, right = 0.98, bottom = 1 },
	{ art = BOTTOM_ART, split = 0.625, left = 0.3, right = 0.6, bottom = 1 },
	{
		name = "MerchantFrameBottomLeftBorder",
		split = 0.6,
		left = 0.1,
		right = 0.55,
		bottom = 0.4765625,
		border = true,
	},
}

local BUYBACK_ART = { "BuybackFrameTopLeft", "BuybackFrameTopRight", "BuybackFrameBotLeft", "BuybackFrameBotRight" }

local FILTER_GLYPH_SIZE = 14
local FILTER_ACTIVE_COLOR = { 0.25, 0.8, 1 }
local SCAN_TOOLTIP = ADDON_NAME .. "MerchantScanTooltip"
local TOGGLES = {
	{ "hideUnusable", "Usable only" },
	{ "hideSoldOut", "Hide sold out" },
	{ "hideUnaffordable", "Affordable only" },
	{ "hideKnown", "Hide known" },
}
local CHOICES = {
	{ "quality", "Quality" },
	{ "itemType", "Type" },
	{ "slot", "Slot" },
}
local SORTS = {
	{ "default", "Default" },
	{ "name", "Item name" },
	{ "price", "Price" },
	{ "level", "Item level" },
	{ "quality", "Quality" },
}
local SORT_FIELDS = {
	default = {},
	name = { "name" },
	price = { "price", "honor", "arena", "tokens" },
	level = { "level" },
	quality = { "quality", "level" },
}
local SORT_DESCENDING = { level = true }

local searchBox, searchQuery, searchText
local filterButton, filterMenu, scanTip
local filtered = {}
local entries = {}
local choices = {}
local knownCache = {}
local sortFields, sortDescending
local listUncertain = false
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

local function filtersActive()
	local c = config()
	if not (c.enabled and c.filterMenu) then
		return false
	end
	if c.sort ~= "default" or c.sortReverse or next(choices) then
		return true
	end
	for _, toggle in ipairs(TOGGLES) do
		if c[toggle[1]] then
			return true
		end
	end
	return false
end

local function listActive()
	return searchActive() or filtersActive()
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
	if listUncertain and listActive() and MerchantFrame.selectedTab == 1 then
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

	if (levelPending or listUncertain) and not levelRetryPending and levelRetries < LEVEL_RETRY_TRIES then
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
		local piece = sliceTexture(
			texture,
			info.left,
			info.left + (info.right - info.left) * width / tileWidth,
			info.bottom,
			width
		)
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
	local width = wide and BASE_WIDTH + EXTRA_WIDTH or BASE_WIDTH
	if floor(MerchantFrame:GetWidth() + 0.5) ~= width then
		MerchantFrame:SetWidth(width)
		if MerchantFrame:IsShown() then
			UpdateUIPanelPositions(MerchantFrame)
		end
	end
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
		for i = 1, #BUYBACK_ART do
			_G[BUYBACK_ART[i]]:Hide()
		end
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
		listUncertain = true
	end
	local name = GetMerchantItemInfo(index)
	return name ~= nil and name:lower():find(searchText, 1, true) ~= nil
end

local function itemEntry(index)
	local entry = entries[index]
	if not entry then
		entry = { index = index }
		entries[index] = entry
	end
	local name, _, price, _, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
	local link = GetMerchantItemLink(index)
	entry.name = name and name:lower() or ""
	entry.price = price or 0
	entry.soldOut = numAvailable == 0
	entry.usable = isUsable
	entry.id = link and tonumber(link:match("item:(%d+)"))
	entry.honor, entry.arena, entry.costItems, entry.tokens = 0, 0, 0, 0
	if extendedCost then
		local honor, arena, costItems = GetMerchantItemCostInfo(index)
		entry.honor, entry.arena, entry.costItems = honor or 0, arena or 0, costItems or 0
		for i = 1, entry.costItems > 0 and MAX_ITEM_COST or 0 do
			local _, count = GetMerchantItemCostItem(index, i)
			entry.tokens = entry.tokens + (count or 0)
		end
	end
	local itemName, quality, level, itemType, subType, equipLoc
	if link then
		itemName, _, quality, level, _, itemType, subType, _, equipLoc = GetItemInfo(link)
		if not itemName then
			listUncertain = true
			quality = ns.LinkQuality(link)
		end
	end
	entry.quality = quality
	entry.level = level or 0
	entry.itemType, entry.subType = itemType, subType
	entry.slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
	return entry
end

local function affordable(entry)
	if entry.price > GetMoney() or entry.honor > GetHonorCurrency() or entry.arena > GetArenaCurrency() then
		return false
	end
	if entry.costItems > 0 then
		for i = 1, MAX_ITEM_COST do
			local _, count, link = GetMerchantItemCostItem(entry.index, i)
			if link and GetItemCount(link) < (count or 0) then
				return false
			end
		end
	end
	return true
end

local function isKnown(entry)
	local id = entry.id
	if not id then
		return false
	end
	local known = knownCache[id]
	if known ~= nil then
		return known
	end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", SCAN_TOOLTIP, nil, "GameTooltipTemplate")
	end
	scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	scanTip:SetMerchantItem(entry.index)
	local lines = scanTip:NumLines()
	if lines < 2 then
		scanTip:Hide()
		listUncertain = true
		return false
	end
	known = false
	for i = 2, lines do
		if _G[SCAN_TOOLTIP .. "TextLeft" .. i]:GetText() == ITEM_SPELL_KNOWN then
			known = true
			break
		end
	end
	scanTip:Hide()
	knownCache[id] = known
	return known
end

local function passesFilters(entry)
	local c = config()
	if
		(c.hideUnusable and not entry.usable)
		or (c.hideSoldOut and entry.soldOut)
		or (choices.quality and entry.quality ~= choices.quality)
		or (choices.itemType and entry.itemType ~= choices.itemType)
		or (choices.subType and entry.subType ~= choices.subType)
		or (choices.slot and entry.slot ~= choices.slot)
	then
		return false
	end
	if c.hideUnaffordable and not affordable(entry) then
		return false
	end
	return not (c.hideKnown and isKnown(entry))
end

local function compareEntries(a, b)
	for i = 1, #sortFields do
		local field = sortFields[i]
		local x, y = a[field] or -1, b[field] or -1
		if x ~= y then
			if sortDescending then
				return x > y
			end
			return x < y
		end
	end
	if sortDescending and #sortFields == 0 then
		return a.index > b.index
	end
	return a.index < b.index
end

local function collectFiltered(numItems)
	wipe(filtered)
	listUncertain = false
	local search, filters = searchActive(), filtersActive()
	for index = 1, numItems do
		if not search or itemMatches(index) then
			local entry = itemEntry(index)
			if not filters or passesFilters(entry) then
				filtered[#filtered + 1] = entry
			end
		end
	end
	if filters then
		local c = config()
		sortFields = SORT_FIELDS[c.sort] or SORT_FIELDS.default
		sortDescending = c.sortReverse ~= (SORT_DESCENDING[c.sort] == true)
		if #sortFields > 0 or sortDescending then
			sort(filtered, compareEntries)
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
	local wide, list = wideActive(), listActive()
	if not wide and not list then
		listUncertain = false
		return
	end
	local numItems = GetMerchantNumItems()
	local perPage = itemsPerPage()
	local count = list and collectFiltered(numItems) or numItems
	updatePaging(count, perPage)
	local offset = (MerchantFrame.page - 1) * perPage
	for i = 1, perPage do
		local position = offset + i
		if list then
			local entry = filtered[position]
			renderItem(i, entry and entry.index)
		else
			renderItem(i, position <= numItems and position or nil)
		end
	end
end

local function updateSearchBox(buyback)
	local c = config()
	local wide = wideActive()
	local right = (wide and BASE_WIDTH + EXTRA_WIDTH or BASE_WIDTH) - 42
	local searchShown = c.enabled and c.searchBox and not buyback
	if searchShown then
		searchBox:ClearAllPoints()
		searchBox:SetWidth(wide and SEARCH_WIDTH or NARROW_SEARCH_WIDTH)
		searchBox:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", SEARCH_LEFT, SEARCH_TOP)
		searchBox:Show()
	elseif searchBox then
		searchBox:Hide()
	end
	if not filterButton then
		return
	end
	if not (c.enabled and c.filterMenu) or buyback then
		filterButton:Hide()
		return
	end
	filterButton:ClearAllPoints()
	filterButton:SetPoint("RIGHT", MerchantFrame, "TOPLEFT", right, SEARCH_TOP - SEARCH_HEIGHT / 2)
	filterButton.color = filtersActive() and FILTER_ACTIVE_COLOR or nil
	filterButton:Paint()
	filterButton:Show()
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

local function filtersChanged()
	levelRetries = 0
	MerchantFrame.page = 1
	refresh()
end

local function resetFilters()
	local c = config()
	for _, toggle in ipairs(TOGGLES) do
		c[toggle[1]] = false
	end
	c.sort, c.sortReverse = "default", false
	wipe(choices)
	filtersChanged()
end

local function setToggle(_, key, _arg2, checked)
	config()[key] = checked and true or false
	filtersChanged()
end

local function setSort(_, key)
	config().sort = key
	filtersChanged()
end

local function setChoice(_, key, value)
	CloseDropDownMenus()
	choices[key] = value
	if key == "itemType" then
		choices.subType = nil
	end
	filtersChanged()
end

local function setSubType(_, itemType, subType)
	CloseDropDownMenus()
	choices.itemType, choices.subType = itemType, subType
	filtersChanged()
end

local function choiceValues(key, itemType)
	local values, seen = {}, {}
	for index = 1, GetMerchantNumItems() do
		local entry = itemEntry(index)
		local value
		if key == "subType" then
			value = entry.itemType == itemType and entry.subType or nil
		else
			value = entry[key]
		end
		if value ~= nil and not seen[value] then
			seen[value] = true
			values[#values + 1] = value
		end
	end
	sort(values)
	return values
end

local function choiceText(key, value)
	if key == "quality" then
		local color = ITEM_QUALITY_COLORS[value]
		local name = _G["ITEM_QUALITY" .. value .. "_DESC"] or tostring(value)
		return color and color.hex .. name .. "|r" or name
	end
	return value
end

local function addMenuButton(text, func, arg1, arg2, checked, keepShown)
	local info = UIDropDownMenu_CreateInfo()
	info.text, info.func, info.arg1, info.arg2 = text, func, arg1, arg2
	info.checked = checked
	info.keepShownOnClick = keepShown
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

local function addMenuTitle(text)
	local info = UIDropDownMenu_CreateInfo()
	info.text, info.isTitle, info.notCheckable = text, true, true
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

local function addSubmenu(text, value)
	local info = UIDropDownMenu_CreateInfo()
	info.text, info.value = text, value
	info.hasArrow, info.notCheckable, info.keepShownOnClick = true, true, true
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

local function initTopMenu()
	local c = config()
	addMenuTitle(L["Filters"])
	for _, toggle in ipairs(TOGGLES) do
		addMenuButton(L[toggle[2]], setToggle, toggle[1], nil, c[toggle[1]], true)
	end
	for _, choice in ipairs(CHOICES) do
		local key, text = choice[1], L[choice[2]]
		local value = choices[key]
		if value ~= nil then
			text = text .. ": " .. choiceText(key, value)
			if key == "itemType" and choices.subType then
				text = text .. " / " .. choices.subType
			end
		end
		addSubmenu(text, key)
	end
	addMenuTitle(L["Sort by"])
	for _, option in ipairs(SORTS) do
		addMenuButton(L[option[2]], setSort, option[1], nil, c.sort == option[1])
	end
	addMenuButton(L["Reverse order"], setToggle, "sortReverse", nil, c.sortReverse, true)
	local info = UIDropDownMenu_CreateInfo()
	info.text, info.func, info.notCheckable = L["Reset"], resetFilters, true
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

local function initChoiceMenu(key)
	addMenuButton(L["All"], setChoice, key, nil, choices[key] == nil)
	for _, value in ipairs(choiceValues(key)) do
		local text = choiceText(key, value)
		local checked = choices[key] == value
		if key == "itemType" and #choiceValues("subType", value) > 1 then
			local info = UIDropDownMenu_CreateInfo()
			info.text, info.value, info.hasArrow = text, value, true
			info.func, info.arg1, info.arg2, info.checked = setChoice, key, value, checked
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
		else
			addMenuButton(text, setChoice, key, value, checked)
		end
	end
end

local function initSubTypeMenu(itemType)
	for _, subType in ipairs(choiceValues("subType", itemType)) do
		local checked = choices.itemType == itemType and choices.subType == subType
		addMenuButton(subType, setSubType, itemType, subType, checked)
	end
end

local function initFilterMenu()
	local level = UIDROPDOWNMENU_MENU_LEVEL
	if level == 1 then
		initTopMenu()
	elseif level == 2 then
		initChoiceMenu(UIDROPDOWNMENU_MENU_VALUE)
	elseif level == 3 then
		initSubTypeMenu(UIDROPDOWNMENU_MENU_VALUE)
	end
end

local function onFilterClick(self, button)
	if button == "RightButton" then
		CloseDropDownMenus()
		resetFilters()
		return
	end
	ToggleDropDownMenu(1, nil, filterMenu, self, 0, 0)
end

local function createFilterButton()
	filterButton = ns.CreateGlyphButton(MerchantFrame, "filter", FILTER_GLYPH_SIZE, L["Filters and sorting"])
	filterButton.tooltipText = L["Right-click to reset."]
	filterButton.tooltipAnchor = "ANCHOR_TOP"
	filterButton:SetFrameLevel(MerchantFrame:GetFrameLevel() + 5)
	filterButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	filterButton:SetScript("OnClick", onFilterClick)
	filterMenu = CreateFrame("Frame", ADDON_NAME .. "MerchantFilterMenu", UIParent, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(filterMenu, initFilterMenu, "MENU")
	MerchantFrame:HookScript("OnHide", function()
		if next(choices) then
			wipe(choices)
		end
	end)
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
	if not filterButton and config().filterMenu then
		createFilterButton()
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

Misc:WatchConfig("merchant", refresh)

local function scheduleRefresh()
	ns.Defer("MerchantFilters", refresh)
end

local function onBagUpdate()
	wipe(knownCache)
	local c = config()
	if (c.hideKnown or c.hideUnaffordable) and filtersActive() then
		scheduleRefresh()
	end
end

local function onCurrencyUpdate()
	if config().hideUnaffordable and filtersActive() then
		scheduleRefresh()
	end
end

local WATCHED_EVENTS = {
	BAG_UPDATE = onBagUpdate,
	PLAYER_MONEY = onCurrencyUpdate,
	HONOR_CURRENCY_UPDATE = onCurrencyUpdate,
}

MerchantFrame:HookScript("OnShow", function()
	for event, handler in pairs(WATCHED_EVENTS) do
		Misc:RegisterEvent(event, handler)
	end
end)

MerchantFrame:HookScript("OnHide", function()
	for event, handler in pairs(WATCHED_EVENTS) do
		Misc:UnregisterEvent(event, handler)
	end
end)

Misc:RegisterEvent("MERCHANT_SHOW", function()
	levelRetries = 0
	wipe(knownCache)
	local c = config()
	if not c.enabled or (c.shiftToSkip and IsShiftKeyDown()) then
		return
	end
	if c.sellGreys then
		sellGreys()
	end
	if c.autoRepair then
		repair()
	end
end)
