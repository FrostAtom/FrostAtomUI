local _, ns = ...

local GetContainerNumSlots = GetContainerNumSlots
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemID = GetContainerItemID
local GetItemInfo = GetItemInfo
local GetItemFamily = GetItemFamily
local GetAuctionItemClasses = GetAuctionItemClasses
local GetAuctionItemSubClasses = GetAuctionItemSubClasses
local GetCursorInfo = GetCursorInfo
local ClearCursor = ClearCursor
local PickupContainerItem = PickupContainerItem
local SplitContainerItem = SplitContainerItem
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime
local tremove = table.remove
local tsort = table.sort
local floor = math.floor
local bit_band = bit.band

local Bags = ns:GetModule("Bags")

local MOVES_PER_FRAME = 12
local MOVE_TIMEOUT = 2
local MAX_REPLANS = 5

local CLASS_ORDER = { 2, 1, 8, 3, 5, 6, 11, 12, 7, 4, 9, 10 }

local PINNED = {
	[6948] = 1, -- Hearthstone
}

local SLOT_ORDER = {
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_CLOAK = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_BODY = 6,
	INVTYPE_TABARD = 7,
	INVTYPE_WRIST = 8,
	INVTYPE_HAND = 9,
	INVTYPE_WAIST = 10,
	INVTYPE_LEGS = 11,
	INVTYPE_FEET = 12,
	INVTYPE_FINGER = 13,
	INVTYPE_TRINKET = 14,
	INVTYPE_2HWEAPON = 15,
	INVTYPE_WEAPONMAINHAND = 16,
	INVTYPE_WEAPON = 17,
	INVTYPE_WEAPONOFFHAND = 18,
	INVTYPE_SHIELD = 19,
	INVTYPE_HOLDABLE = 20,
	INVTYPE_RANGED = 21,
	INVTYPE_RANGEDRIGHT = 22,
	INVTYPE_THROWN = 23,
	INVTYPE_RELIC = 24,
	INVTYPE_AMMO = 25,
}

local ids, counts, maxStacks = {}, {}, {}
local itemOrder, itemFamilies = {}, {}
local moves = {}
local slots, sorted, sortedPosition, initialOrder = {}, {}, {}, {}
local targetItems, targetSlots, sourceUsed, emptySlots = {}, {}, {}, {}
local normalBags, specialtyBags, bagFamilies = {}, {}, {}
local typeOrder, subTypeOrder = {}, {}
local busy = {}
local activeFrame
local replans = 0

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
		typeOrder[itemType] = CLASS_ORDER[i] or i
		local subOrder = {}
		subTypeOrder[itemType] = subOrder
		local subTypes = { GetAuctionItemSubClasses(i) }
		for j = 1, #subTypes do
			subOrder[subTypes[j]] = j
		end
	end
end

local function cacheItem(id)
	if itemOrder[id] then
		return
	end
	local name, _, quality, level, _, itemType, subType, _, equipLoc, _, price = GetItemInfo(id)
	local subOrder = subTypeOrder[itemType]
	itemOrder[id] = ("%02d%02d%02d%d%04d%02d%08d%s"):format(
		PINNED[id] or 99,
		typeOrder[itemType] or 99,
		SLOT_ORDER[equipLoc] or 99,
		9 - (quality or 0),
		9999 - (level or 0),
		subOrder and subOrder[subType] or 99,
		99999999 - (price or 0),
		name or ""
	)

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
	wipe(itemOrder)
	wipe(itemFamilies)
	for i = 1, #bags do
		local bag = bags[i]
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			if id then
				local key = slotKey(bag, slot)
				local _, count = GetContainerItemInfo(bag, slot)
				local _, _, _, _, _, _, _, maxStack = GetItemInfo(id)
				ids[key] = id
				counts[key] = count or 1
				maxStacks[key] = maxStack or 1
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
			ids[from], counts[from], maxStacks[from] = nil, nil, nil
		end
	else
		ids[from], ids[to] = ids[to], ids[from]
		counts[from], counts[to] = counts[to], counts[from]
		maxStacks[from], maxStacks[to] = maxStacks[to], maxStacks[from]
	end
end

local function addMove(from, to)
	updateLocation(from, to)
	moves[#moves + 1] = {
		from = from,
		to = to,
		fromId = ids[from] or false,
		toId = ids[to],
		toCount = counts[to],
	}
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

	if aId ~= bId then
		local aOrder, bOrder = itemOrder[aId], itemOrder[bId]
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		return aId < bId
	end

	local aCount, bCount = counts[a], counts[b]
	if aCount ~= bCount then
		return aCount > bCount
	end
	return initialOrder[a] < initialOrder[b]
end

local function sameContent(a, b)
	return ids[a] == ids[b] and counts[a] == counts[b]
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
			slots[index] = key
			sorted[index] = key
		end
	end
	tsort(sorted, compare)
	for i = 1, index do
		sortedPosition[sorted[i]] = i
	end

	for i = 1, index do
		local source, destination = sorted[i], slots[i]
		if source ~= destination and ids[source] and not sameContent(source, destination) then
			addMove(source, destination)
			local sourceIndex, destinationIndex = sortedPosition[source], sortedPosition[destination]
			sorted[sourceIndex], sorted[destinationIndex] = destination, source
			sortedPosition[source], sortedPosition[destination] = destinationIndex, sourceIndex
		end
	end

	wipe(slots)
	wipe(sorted)
	wipe(sortedPosition)
	wipe(initialOrder)
end

local function plan(bags)
	wipe(moves)
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
	return #moves > 0
end

local ticker = CreateFrame("Frame")
ticker:Hide()

local function stop(message)
	wipe(moves)
	wipe(busy)
	ticker:Hide()
	if activeFrame then
		activeFrame:SetSorting(false)
		activeFrame = nil
	end
	if message then
		ns.Print(message)
	end
end

local function replan()
	replans = replans + 1
	if replans > MAX_REPLANS then
		return stop("sorting failed, try again")
	end
	if not plan(activeFrame.bags) then
		return stop()
	end
end

local function slotState(key)
	local bag, slot = decode(key)
	local _, count, locked = GetContainerItemInfo(bag, slot)
	return GetContainerItemID(bag, slot) or false, count or 0, locked
end

local function moveFinished(move)
	local toId, toCount, toLocked = slotState(move.to)
	local fromId, _, fromLocked = slotState(move.from)
	if toLocked or fromLocked then
		return false
	end
	return toId == move.toId and toCount == move.toCount and fromId == move.fromId
end

local function issue(move)
	local sourceBag, sourceSlot = decode(move.from)
	local targetBag, targetSlot = decode(move.to)
	local sourceId, sourceCount = slotState(move.from)
	local targetId, targetCount = slotState(move.to)
	if not sourceId then
		return false
	end

	if sourceId == targetId and move.toCount > targetCount and move.toCount < targetCount + sourceCount then
		SplitContainerItem(sourceBag, sourceSlot, move.toCount - targetCount)
	else
		PickupContainerItem(sourceBag, sourceSlot)
	end
	if GetCursorInfo() ~= "item" then
		return false
	end
	PickupContainerItem(targetBag, targetSlot)
	if GetCursorInfo() then
		ClearCursor()
		return false
	end
	move.started = GetTime()
	return true
end

ticker:SetScript("OnUpdate", function()
	if InCombatLockdown() then
		return stop("sorting interrupted by combat")
	end
	if not moves[1] then
		return replan()
	end
	if GetCursorInfo() then
		return
	end

	wipe(busy)
	local issued = 0
	local now = GetTime()
	local i = 1
	while moves[i] do
		local move = moves[i]
		local from, to = move.from, move.to
		if move.started then
			if moveFinished(move) then
				tremove(moves, i)
				i = i - 1
			elseif now - move.started > MOVE_TIMEOUT then
				return replan()
			else
				busy[from], busy[to] = true, true
			end
		elseif not (busy[from] or busy[to]) then
			if issued < MOVES_PER_FRAME then
				local _, _, fromLocked = slotState(from)
				local _, _, toLocked = slotState(to)
				if not (fromLocked or toLocked) then
					if not issue(move) then
						return replan()
					end
					issued = issued + 1
				end
			end
			busy[from], busy[to] = true, true
		else
			busy[from], busy[to] = true, true
		end
		i = i + 1
	end
end)

function Bags:SortBags(frame)
	if ticker:IsShown() or InCombatLockdown() then
		return
	end
	if not next(typeOrder) then
		buildTypeOrder()
	end

	replans = 0
	if not plan(frame.bags) then
		return
	end

	activeFrame = frame
	frame:SetSorting(true)
	ticker:Show()
end
