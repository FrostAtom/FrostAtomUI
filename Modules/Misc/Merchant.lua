local _, ns = ...

-- At a merchant: sell grey items and repair everything. Hold Shift while
-- opening the merchant to skip both.

local CanMerchantRepair = CanMerchantRepair
local GetRepairAllCost = GetRepairAllCost
local RepairAllItems = RepairAllItems
local GetMoney = GetMoney
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemInfo = GetContainerItemInfo
local GetItemInfo = GetItemInfo
local UseContainerItem = UseContainerItem
local IsShiftKeyDown = IsShiftKeyDown
local NUM_BAG_SLOTS = NUM_BAG_SLOTS

local Misc = ns:GetModule("Misc")

local POOR_QUALITY = 0

local function formatMoney(copper)
	local gold = math.floor(copper / 1e4)
	local silver = math.floor(copper % 1e4 / 100)
	copper = copper % 100
	if gold > 0 then
		return ("%d|cffffd700g|r %d|cffc7c7cfs|r"):format(gold, silver)
	elseif silver > 0 then
		return ("%d|cffc7c7cfs|r %d|cffeda55fc|r"):format(silver, copper)
	end
	return ("%d|cffeda55fc|r"):format(copper)
end

local function sellGreys()
	local total, count = 0, 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
				local _, stack = GetContainerItemInfo(bag, slot)
				if quality == POOR_QUALITY and price and price > 0 then
					UseContainerItem(bag, slot)
					total = total + price * (stack or 1)
					count = count + 1
				end
			end
		end
	end

	if count > 0 then
		ns.Print("sold %d grey item(s) for %s", count, formatMoney(total))
	end
end

local function repair()
	if not CanMerchantRepair() then
		return
	end

	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost <= 0 then
		return
	end

	if GetMoney() >= cost then
		RepairAllItems()
		ns.Print("repaired for %s", formatMoney(cost))
	else
		ns.Print("not enough money to repair (%s)", formatMoney(cost))
	end
end

Misc:RegisterEvent("MERCHANT_SHOW", function()
	if IsShiftKeyDown() then
		return
	end
	sellGreys()
	repair()
end)
