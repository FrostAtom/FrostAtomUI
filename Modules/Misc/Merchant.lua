local _, ns = ...

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
local formatMoney = ns.FormatMoney

local function sellGreys()
	local total, count = 0, 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
				if quality == POOR_QUALITY and price and price > 0 then
					local _, stack = GetContainerItemInfo(bag, slot)
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
