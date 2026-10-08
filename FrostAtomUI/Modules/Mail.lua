local _, ns = ...

local L = ns.L

local GetInboxNumItems = GetInboxNumItems
local GetInboxHeaderInfo = GetInboxHeaderInfo
local GetInboxItem = GetInboxItem
local GetInboxItemLink = GetInboxItemLink
local GetInboxText = GetInboxText
local TakeInboxMoney = TakeInboxMoney
local TakeInboxItem = TakeInboxItem
local CheckInbox = CheckInbox
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetTime = GetTime
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local ATTACHMENTS_MAX_RECEIVE = ATTACHMENTS_MAX_RECEIVE

local Mail = ns:NewModule("Mail")

local STEP_DELAY = 0.15
local REQUEST_TIMEOUT = 3
local BUTTON_WIDTH, BUTTON_HEIGHT = 110, 22
local BUTTON_X, BUTTON_Y = 182, 104

local button
local run

local function config()
	return ns.Config.mail
end

local function freeSlots()
	local free = 0
	for bag = 0, NUM_BAG_SLOTS do
		free = free + (GetContainerNumFreeSlots(bag) or 0)
	end
	return free
end

local function itemKey(index, slot)
	local link = GetInboxItemLink(index, slot)
	return link and link:match("item:(%d+)") or GetInboxItem(index, slot)
end

local function hasCod(cod)
	return (cod or 0) > 0
end

local function nextRequest(failed)
	for index = 1, GetInboxNumItems() do
		local _, _, sender, subject, money, cod, _, itemCount, wasRead = GetInboxHeaderInfo(index)
		if not wasRead then
			GetInboxText(index)
		end
		if not hasCod(cod) then
			local moneyKey = ("%s\1%s\1%d"):format(sender or "", subject or "", money or 0)
			if (money or 0) > 0 and not failed[moneyKey] then
				return { index = index, key = moneyKey, money = money }
			end
			for slot = 1, (itemCount or 0) > 0 and ATTACHMENTS_MAX_RECEIVE or 0 do
				local key = itemKey(index, slot)
				if key and not failed[key] then
					return { index = index, slot = slot, key = key }
				end
			end
		end
	end
end

local function requestDone(request)
	if GetInboxNumItems() ~= request.count then
		return true
	end
	if not request.key then
		return false
	end
	if request.slot then
		return itemKey(request.index, request.slot) ~= request.key
	end
	return select(5, GetInboxHeaderInfo(request.index)) ~= request.money
end

local function hasWork()
	for index = 1, GetInboxNumItems() do
		local _, _, _, _, money, cod, _, itemCount, wasRead = GetInboxHeaderInfo(index)
		if not wasRead or not hasCod(cod) and ((money or 0) > 0 or (itemCount or 0) > 0) then
			return true
		end
	end
	return false
end

local function updateButton()
	if not button then
		return
	end
	if run then
		button:SetText(L["Collecting..."])
		button:Enable()
	else
		button:SetText(L["Collect all"])
		if hasWork() then
			button:Enable()
		else
			button:Disable()
		end
	end
end

local function skippedCount()
	local count = 0
	for index = 1, GetInboxNumItems() do
		local _, _, _, _, money, cod, _, itemCount = GetInboxHeaderInfo(index)
		if hasCod(cod) and ((money or 0) > 0 or (itemCount or 0) > 0) then
			count = count + 1
		end
	end
	return count
end

local function finish(reason)
	local finished = run
	run = nil
	button:SetScript("OnUpdate", nil)
	Mail:UnregisterEvent("UI_ERROR_MESSAGE")
	Mail:UnregisterEvent("MAIL_FAILED")
	updateButton()
	if reason then
		ns.Print(reason)
	end
	local parts = {}
	if finished.money > 0 then
		parts[#parts + 1] = ns.FormatMoney(finished.money)
	end
	if finished.items > 0 then
		parts[#parts + 1] = L["%d item(s)"]:format(finished.items)
	end
	if #parts > 0 then
		ns.Print(L["collected from the mail: %s"], table.concat(parts, ", "))
	elseif not reason then
		ns.Print(L["nothing to collect in the mail"])
	end
	local skipped = skippedCount()
	if skipped > 0 then
		ns.Print(L["left %d letter(s) with cash on delivery"], skipped)
	end
	local count, total = GetInboxNumItems()
	if (total or 0) > count then
		ns.Print(L["%d more letter(s) wait on the server and come in as the inbox frees up"], total - count)
	end
end

local function failRequest()
	local request = run and run.request
	if request and request.key then
		run.failed[request.key] = true
		run.request = nil
	end
end

local function step()
	local request = run.request
	if request then
		local done = requestDone(request)
		if not done and GetTime() < request.expires then
			return
		end
		if request.key then
			if not done then
				run.failed[request.key] = true
			elseif request.slot then
				run.items = run.items + 1
			else
				run.money = run.money + request.money
			end
		end
		run.request = nil
	end
	request = nextRequest(run.failed)
	if not request then
		local count, total = GetInboxNumItems()
		if (total or 0) > count and not run.refreshed then
			run.refreshed = true
			CheckInbox()
			run.request = { count = count, expires = GetTime() + REQUEST_TIMEOUT }
			return
		end
		finish()
		return
	end
	if request.slot then
		if freeSlots() == 0 then
			finish(L["bags are full, mail collection stopped"])
			return
		end
		TakeInboxItem(request.index, request.slot)
	else
		TakeInboxMoney(request.index)
	end
	request.count = GetInboxNumItems()
	request.expires = GetTime() + REQUEST_TIMEOUT
	run.request = request
end

local function onUpdate()
	if GetTime() >= run.nextStep then
		run.nextStep = GetTime() + STEP_DELAY
		step()
	end
end

local function onErrorMessage(_, message)
	if message == ERR_INV_FULL then
		finish(L["bags are full, mail collection stopped"])
	elseif message == ERR_ITEM_MAX_COUNT then
		failRequest()
	end
end

local function start()
	run = { money = 0, items = 0, failed = {}, nextStep = 0 }
	Mail:RegisterEvent("UI_ERROR_MESSAGE", onErrorMessage)
	Mail:RegisterEvent("MAIL_FAILED", failRequest)
	button:SetScript("OnUpdate", onUpdate)
	updateButton()
end

local function onClick()
	if run then
		finish()
	else
		start()
	end
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L["Collect all"])
	GameTooltip:AddLine(
		L["Takes gold and items from every letter and marks all letters read. Letters with cash on delivery are left for you. Click again to stop."],
		1,
		1,
		1,
		true
	)
	GameTooltip:Show()
end

local function onHide()
	if run then
		finish()
	end
end

local function createButton()
	button = ns.CreateButton(InboxFrame, L["Collect all"], BUTTON_WIDTH, BUTTON_HEIGHT)
	button:SetPoint("CENTER", InboxFrame, "BOTTOMLEFT", BUTTON_X, BUTTON_Y)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnHide", onHide)
	hooksecurefunc("InboxFrame_Update", updateButton)
end

local function apply()
	local shown = config().collectAll
	if shown and not button then
		createButton()
	end
	if button then
		ns.SetShown(button, shown)
		updateButton()
	end
end

function Mail:Initialize()
	self:WatchConfig("mail", apply)
	InboxFrame:HookScript("OnShow", apply)
end
