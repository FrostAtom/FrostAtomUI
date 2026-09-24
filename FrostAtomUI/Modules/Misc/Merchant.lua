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

local function retryLevels()
	levelRetryPending = false
	if MerchantFrame:IsShown() then
		updateLevels()
	end
end

function updateLevels()
	local config = ns.Config.merchant
	local show = config.enabled and config.showItemLevel
	levelPending = false
	if MerchantFrame.selectedTab == 2 then
		for i = 1, BUYBACK_ITEMS_PER_PAGE do
			setButtonLevel(_G["MerchantItem" .. i .. "ItemButton"], GetBuybackItemLink(i), show)
		end
	else
		local offset = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE
		local numItems = GetMerchantNumItems()
		for i = 1, MERCHANT_ITEMS_PER_PAGE do
			local index = offset + i
			setButtonLevel(
				_G["MerchantItem" .. i .. "ItemButton"],
				index <= numItems and GetMerchantItemLink(index) or nil,
				show
			)
		end
		setButtonLevel(MerchantBuyBackItemItemButton, GetBuybackItemLink(GetNumBuybackItems()), show)
	end

	if levelPending and not levelRetryPending and levelRetries < LEVEL_RETRY_TRIES then
		levelRetries = levelRetries + 1
		levelRetryPending = true
		ns.After(LEVEL_RETRY_DELAY, retryLevels)
	end
end

hooksecurefunc("MerchantFrame_UpdateMerchantInfo", updateLevels)
hooksecurefunc("MerchantFrame_UpdateBuybackInfo", updateLevels)

Misc:WatchConfig("merchant", function()
	if MerchantFrame:IsShown() then
		updateLevels()
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
