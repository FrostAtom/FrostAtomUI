local _, ns = ...

local CreateFrame = CreateFrame
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemID = GetContainerItemID
local GetItemInfo = GetItemInfo
local GetItemFamily = GetItemFamily
local GetAuctionItemClasses = GetAuctionItemClasses
local GetAuctionItemSubClasses = GetAuctionItemSubClasses
local GetCursorInfo = GetCursorInfo
local PickupContainerItem = PickupContainerItem
local SplitContainerItem = SplitContainerItem
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime
local tremove = table.remove
local tsort = table.sort
local floor = math.floor
local bit_band = bit.band
local wipe = wipe
local pairs = pairs
local next = next

local Bags = ns:GetModule("Bags")

local TICK = 0.05
local MAX_MOVE_TIME = 1.25
local MAX_RETRIES = 5
local MAX_PASSES = 50

local SLOT_ORDER = {
	INVTYPE_AMMO = 0,
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_BODY = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 12,
	INVTYPE_CLOAK = 13,
	INVTYPE_WEAPON = 14,
	INVTYPE_SHIELD = 15,
	INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 18,
	INVTYPE_WEAPONOFFHAND = 19,
	INVTYPE_HOLDABLE = 20,
	INVTYPE_RANGED = 21,
	INVTYPE_THROWN = 22,
	INVTYPE_RANGEDRIGHT = 23,
	INVTYPE_RELIC = 24,
	INVTYPE_TABARD = 25,
}

local ids, counts, maxStacks, qualities = {}, {}, {}, {}
local itemTypeOrder, itemSubTypeOrder, itemSlotOrder, itemLevels, itemPrices, itemNames, itemFamilies =
	{}, {}, {}, {}, {}, {}, {}
local moves = {}
local sorted, sortedPosition, initialOrder, locked = {}, {}, {}, {}
local targetItems, targetSlots, sourceUsed, emptySlots = {}, {}, {}, {}
local normalBags, specialtyBags, bagFamilies = {}, {}, {}
local typeOrder, subTypeOrder = {}, {}
local activeFrame

local function slotKey(bag, slot)
	return bag * 100 + slot
end

local function decode(key)
	return floor(key / 100), key % 100
end

local function buildTypeOrder()
	local types = { GetAuctionItemClasses() }
	for i = 1, #types do
		local itemType = types[i]
		typeOrder[itemType] = i
		local subOrder = {}
		subTypeOrder[itemType] = subOrder
		local subTypes = { GetAuctionItemSubClasses(i) }
		for j = 1, #subTypes do
			subOrder[subTypes[j]] = j
		end
	end
end

local function cacheItem(id)
	if itemTypeOrder[id] then
		return
	end
	local name, _, _, level, _, itemType, subType, _, equipLoc, _, price = GetItemInfo(id)
	itemTypeOrder[id] = typeOrder[itemType] or 99
	local subOrder = subTypeOrder[itemType]
	itemSubTypeOrder[id] = subOrder and subOrder[subType] or 99
	itemSlotOrder[id] = SLOT_ORDER[equipLoc] or 99
	itemLevels[id] = level or 0
	itemPrices[id] = price or 0
	itemNames[id] = name or ""

	local family = GetItemFamily(id)
	if family and family > 0 and equipLoc == "INVTYPE_QUIVER" then
		family = 1
	end
	itemFamilies[id] = family
end

local function scan(bags)
	wipe(ids)
	wipe(counts)
	wipe(maxStacks)
	wipe(qualities)
	wipe(itemTypeOrder)
	wipe(itemSubTypeOrder)
	wipe(itemSlotOrder)
	wipe(itemLevels)
	wipe(itemPrices)
	wipe(itemNames)
	wipe(itemFamilies)
	for i = 1, #bags do
		local bag = bags[i]
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			if id then
				local key = slotKey(bag, slot)
				local _, count = GetContainerItemInfo(bag, slot)
				local _, _, quality, _, _, _, _, maxStack = GetItemInfo(id)
				ids[key] = id
				counts[key] = count or 1
				maxStacks[key] = maxStack or 1
				qualities[key] = quality or 0
				cacheItem(id)
			end
		end
	end
end

local function updateLocation(from, to)
	if ids[from] == ids[to] and counts[to] < maxStacks[to] then
		local stackSize = maxStacks[to]
		if counts[to] + counts[from] > stackSize then
			counts[from] = counts[from] - (stackSize - counts[to])
			counts[to] = stackSize
		else
			counts[to] = counts[to] + counts[from]
			ids[from], counts[from], maxStacks[from], qualities[from] = nil, nil, nil, nil
		end
	else
		ids[from], ids[to] = ids[to], ids[from]
		counts[from], counts[to] = counts[to], counts[from]
		maxStacks[from], maxStacks[to] = maxStacks[to], maxStacks[from]
		qualities[from], qualities[to] = qualities[to], qualities[from]
	end
end

local function addMove(from, to)
	updateLocation(from, to)
	moves[#moves + 1] = { from, to }
end

local function stack(sourceBags, targetBags, partialOnly)
	for i = 1, #targetBags do
		local bag = targetBags[i]
		for slot = 1, GetContainerNumSlots(bag) do
			local key = slotKey(bag, slot)
			local id = ids[key]
			if id and counts[key] ~= maxStacks[key] then
				targetItems[id] = (targetItems[id] or 0) + 1
				targetSlots[#targetSlots + 1] = key
			end
		end
	end

	for b = #sourceBags, 1, -1 do
		local bag = sourceBags[b]
		for slot = GetContainerNumSlots(bag), 1, -1 do
			local source = slotKey(bag, slot)
			local id = ids[source]
			if id and targetItems[id] and (not partialOnly or counts[source] < maxStacks[source]) then
				for i = #targetSlots, 1, -1 do
					local target = targetSlots[i]
					if not ids[source] or not targetItems[id] then
						break
					end
					if
						ids[target] == id
						and target ~= source
						and counts[target] ~= maxStacks[target]
						and not sourceUsed[target]
					then
						addMove(source, target)
						sourceUsed[source] = true
						if counts[target] == maxStacks[target] then
							targetItems[id] = targetItems[id] > 1 and targetItems[id] - 1 or nil
						end
					end
				end
			end
		end
	end

	wipe(targetItems)
	wipe(targetSlots)
	wipe(sourceUsed)
end

local function canGoInBag(id, bag)
	local itemFamily = itemFamilies[id]
	if not itemFamily then
		return false
	end
	local bagFamily = bagFamilies[bag]
	return bagFamily == 0 or bit_band(itemFamily, bagFamily) > 0
end

local function fill(sourceBags, targetBags)
	for i = 1, #targetBags do
		local bag = targetBags[i]
		for slot = 1, GetContainerNumSlots(bag) do
			local key = slotKey(bag, slot)
			if not ids[key] then
				emptySlots[#emptySlots + 1] = key
			end
		end
	end

	for b = #sourceBags, 1, -1 do
		local bag = sourceBags[b]
		for slot = GetContainerNumSlots(bag), 1, -1 do
			if #emptySlots == 0 then
				break
			end
			local source = slotKey(bag, slot)
			local id = ids[source]
			if id and canGoInBag(id, (decode(emptySlots[1]))) then
				addMove(source, tremove(emptySlots, 1))
			end
		end
	end
	wipe(emptySlots)
end

local function compare(a, b)
	local aId, bId = ids[a], ids[b]
	if not (aId and bId) then
		return aId ~= nil and bId == nil
	end

	if aId == bId then
		local aCount, bCount = counts[a], counts[b]
		if aCount ~= bCount then
			return aCount < bCount
		end
		return initialOrder[a] < initialOrder[b]
	end

	local aQuality, bQuality = qualities[a], qualities[b]
	if aQuality ~= bQuality then
		return aQuality > bQuality
	end

	local aOrder, bOrder = itemTypeOrder[aId], itemTypeOrder[bId]
	if aOrder ~= bOrder then
		return aOrder < bOrder
	end

	aOrder, bOrder = itemSubTypeOrder[aId], itemSubTypeOrder[bId]
	if aOrder ~= bOrder then
		return aOrder < bOrder
	end

	aOrder, bOrder = itemSlotOrder[aId], itemSlotOrder[bId]
	if aOrder ~= bOrder then
		return aOrder < bOrder
	end

	local aLevel, bLevel = itemLevels[aId], itemLevels[bId]
	if aLevel ~= bLevel then
		return aLevel > bLevel
	end

	local aPrice, bPrice = itemPrices[aId], itemPrices[bId]
	if aPrice ~= bPrice then
		return aPrice > bPrice
	end

	local aName, bName = itemNames[aId], itemNames[bId]
	if aName ~= bName then
		return aName < bName
	end

	return initialOrder[a] < initialOrder[b]
end

local function shouldMove(source, destination)
	local id = ids[source]
	return destination ~= source
		and id ~= nil
		and not (id == ids[destination] and counts[source] == counts[destination])
end

local function swapSorted(source, destination)
	local sourceIndex, destinationIndex = sortedPosition[source], sortedPosition[destination]
	sorted[sourceIndex] = destination
	sorted[destinationIndex] = source
	sortedPosition[source], sortedPosition[destination] = destinationIndex, sourceIndex
end

local function sort(bags)
	wipe(sorted)
	wipe(initialOrder)

	local index = 0
	for i = 1, #bags do
		local bag = bags[i]
		for slot = 1, GetContainerNumSlots(bag) do
			local key = slotKey(bag, slot)
			index = index + 1
			initialOrder[key] = index
			sorted[index] = key
		end
	end
	tsort(sorted, compare)
	for i = 1, index do
		sortedPosition[sorted[i]] = i
	end

	local passNeeded, passes = true, 0
	while passNeeded and passes < MAX_PASSES do
		passNeeded = false
		passes = passes + 1
		local i = 1
		for b = 1, #bags do
			local bag = bags[b]
			for slot = 1, GetContainerNumSlots(bag) do
				local destination = slotKey(bag, slot)
				local source = sorted[i]
				if shouldMove(source, destination) then
					if locked[source] or locked[destination] then
						passNeeded = true
					else
						addMove(source, destination)
						swapSorted(source, destination)
						locked[source] = true
						locked[destination] = true
					end
				end
				i = i + 1
			end
		end
		wipe(locked)
	end

	wipe(sorted)
	wipe(sortedPosition)
	wipe(initialOrder)
end

local ticker = CreateFrame("Frame")
ticker:Hide()

local function stop(message)
	wipe(moves)
	ticker:Hide()
	if activeFrame then
		activeFrame:SetSorting(false)
		activeFrame = nil
	end
	if message then
		ns.Print(message)
	end
end

local function doMove(move)
	local sourceBag, sourceSlot = decode(move[1])
	local targetBag, targetSlot = decode(move[2])

	local _, sourceCount, sourceLocked = GetContainerItemInfo(sourceBag, sourceSlot)
	local _, targetCount, targetLocked = GetContainerItemInfo(targetBag, targetSlot)
	if sourceLocked or targetLocked then
		return false
	end

	local sourceId = GetContainerItemID(sourceBag, sourceSlot)
	if not sourceId then
		return nil
	end
	local targetId = GetContainerItemID(targetBag, targetSlot)
	local _, _, _, _, _, _, _, stackSize = GetItemInfo(sourceId)
	stackSize = stackSize or 1

	if sourceId == targetId and targetCount < stackSize and targetCount + sourceCount > stackSize then
		SplitContainerItem(sourceBag, sourceSlot, stackSize - targetCount)
	else
		PickupContainerItem(sourceBag, sourceSlot)
	end
	if GetCursorInfo() == "item" then
		PickupContainerItem(targetBag, targetSlot)
	end

	move.expect = sourceId
	return true
end

ticker:SetScript("OnUpdate", function(self, elapsed)
	self.timer = self.timer - elapsed
	if self.timer > 0 then
		return
	end
	self.timer = TICK

	if InCombatLockdown() then
		return stop("sorting interrupted by combat")
	end

	local move = moves[1]
	if not move then
		return stop()
	end

	if move.started then
		local sourceBag, sourceSlot = decode(move[1])
		local targetBag, targetSlot = decode(move[2])

		local cursorType, cursorId = GetCursorInfo()
		if cursorType == "item" then
			if cursorId == move.expect then
				PickupContainerItem(targetBag, targetSlot)
				return
			end
			return stop("sorting aborted: cursor is busy")
		end

		local _, _, sourceLocked = GetContainerItemInfo(sourceBag, sourceSlot)
		local _, _, targetLocked = GetContainerItemInfo(targetBag, targetSlot)
		if sourceLocked or targetLocked then
			return
		end

		if GetContainerItemID(targetBag, targetSlot) == move.expect then
			tremove(moves, 1)
			return
		end

		if GetTime() - move.started > MAX_MOVE_TIME then
			move.retries = (move.retries or 0) + 1
			if move.retries > MAX_RETRIES then
				return stop("sorting failed, try again")
			end
			move.started = nil
		end
		return
	end

	if GetCursorInfo() then
		return
	end

	local ok = doMove(move)
	if ok then
		move.started = GetTime()
	elseif ok == nil then
		tremove(moves, 1)
	end
end)

function Bags:SortBags(frame)
	if ticker:IsShown() or InCombatLockdown() then
		return
	end
	if not next(typeOrder) then
		buildTypeOrder()
	end

	local bags = frame.bags
	scan(bags)

	wipe(normalBags)
	wipe(specialtyBags)
	wipe(bagFamilies)
	for i = 1, #bags do
		local bag = bags[i]
		if GetContainerNumSlots(bag) > 0 then
			local _, family = GetContainerNumFreeSlots(bag)
			family = family or 0
			bagFamilies[bag] = family
			if family == 0 then
				normalBags[#normalBags + 1] = bag
			else
				local group = specialtyBags[family]
				if not group then
					group = {}
					specialtyBags[family] = group
				end
				group[#group + 1] = bag
			end
		end
	end

	for _, group in pairs(specialtyBags) do
		stack(group, group, true)
		stack(normalBags, group)
		fill(normalBags, group)
		sort(group)
	end
	stack(normalBags, normalBags, true)
	sort(normalBags)

	if #moves == 0 then
		return
	end

	activeFrame = frame
	frame:SetSorting(true)
	ticker.timer = TICK
	ticker:Show()
end
