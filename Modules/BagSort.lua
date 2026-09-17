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
local moves = {}
local sorted, initialOrder, locked = {}, {}, {}
local targetItems, targetSlots, sourceUsed, emptySlots = {}, {}, {}, {}
local normalBags, specialtyBags = {}, {}
local typeOrder, subTypeOrder = {}, {}
local activeFrame

local function slotKey(bag, slot)
	return bag * 100 + slot
end

local function decode(key)
	return floor(key / 100), key % 100
end

local function buildTypeOrder()
	for i, itemType in ipairs({ GetAuctionItemClasses() }) do
		typeOrder[itemType] = i
		subTypeOrder[itemType] = {}
		for j, subType in ipairs({ GetAuctionItemSubClasses(i) }) do
			subTypeOrder[itemType][subType] = j
		end
	end
end

local function scan(bags)
	wipe(ids)
	wipe(counts)
	wipe(maxStacks)
	wipe(qualities)
	for _, bag in ipairs(bags) do
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

local function isPartial(key)
	return (maxStacks[key] or 0) - (counts[key] or 0) > 0
end

local function stack(sourceBags, targetBags, partialOnly)
	for _, bag in ipairs(targetBags) do
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
			if id and targetItems[id] and (not partialOnly or isPartial(source)) then
				for i = #targetSlots, 1, -1 do
					local target = targetSlots[i]
					if not ids[source] or not targetItems[id] then
						break
					end
					if ids[target] == id and target ~= source and counts[target] ~= maxStacks[target] and not sourceUsed[target] then
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
	local itemFamily = GetItemFamily(id)
	if not itemFamily then
		return false
	end
	if itemFamily > 0 and select(9, GetItemInfo(id)) == "INVTYPE_QUIVER" then
		itemFamily = 1
	end
	local bagFamily = select(2, GetContainerNumFreeSlots(bag))
	return bagFamily == 0 or bit_band(itemFamily, bagFamily) > 0
end

local function fill(sourceBags, targetBags)
	for _, bag in ipairs(targetBags) do
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

	local aName, _, _, aLevel, _, aType, aSubType, _, aLoc, _, aPrice = GetItemInfo(aId)
	local bName, _, _, bLevel, _, bType, bSubType, _, bLoc, _, bPrice = GetItemInfo(bId)

	local aTypeOrder, bTypeOrder = typeOrder[aType] or 99, typeOrder[bType] or 99
	if aTypeOrder ~= bTypeOrder then
		return aTypeOrder < bTypeOrder
	end

	local aSubOrder = subTypeOrder[aType] and subTypeOrder[aType][aSubType] or 99
	local bSubOrder = subTypeOrder[bType] and subTypeOrder[bType][bSubType] or 99
	if aSubOrder ~= bSubOrder then
		return aSubOrder < bSubOrder
	end

	local aSlot, bSlot = SLOT_ORDER[aLoc] or 99, SLOT_ORDER[bLoc] or 99
	if aSlot ~= bSlot then
		return aSlot < bSlot
	end

	aLevel, bLevel = aLevel or 0, bLevel or 0
	if aLevel ~= bLevel then
		return aLevel > bLevel
	end

	aPrice, bPrice = aPrice or 0, bPrice or 0
	if aPrice ~= bPrice then
		return aPrice > bPrice
	end

	aName, bName = aName or "", bName or ""
	if aName ~= bName then
		return aName < bName
	end

	return initialOrder[a] < initialOrder[b]
end

local function shouldMove(source, destination)
	if destination == source or not ids[source] then
		return false
	end
	return not (ids[source] == ids[destination] and counts[source] == counts[destination])
end

local function updateSorted(source, destination)
	for i, key in ipairs(sorted) do
		if key == source then
			sorted[i] = destination
		elseif key == destination then
			sorted[i] = source
		end
	end
end

local function sort(bags)
	wipe(sorted)
	wipe(initialOrder)

	local index = 0
	for _, bag in ipairs(bags) do
		for slot = 1, GetContainerNumSlots(bag) do
			local key = slotKey(bag, slot)
			index = index + 1
			initialOrder[key] = index
			sorted[index] = key
		end
	end
	tsort(sorted, compare)

	local passNeeded, passes = true, 0
	while passNeeded and passes < MAX_PASSES do
		passNeeded = false
		passes = passes + 1
		local i = 1
		for _, bag in ipairs(bags) do
			for slot = 1, GetContainerNumSlots(bag) do
				local destination = slotKey(bag, slot)
				local source = sorted[i]
				if shouldMove(source, destination) then
					if locked[source] or locked[destination] then
						passNeeded = true
					else
						addMove(source, destination)
						updateSorted(source, destination)
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
	local stackSize = select(8, GetItemInfo(sourceId)) or 1

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
	for _, bag in ipairs(bags) do
		if GetContainerNumSlots(bag) > 0 then
			local family = select(2, GetContainerNumFreeSlots(bag)) or 0
			if family == 0 then
				normalBags[#normalBags + 1] = bag
			else
				specialtyBags[family] = specialtyBags[family] or {}
				local group = specialtyBags[family]
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
