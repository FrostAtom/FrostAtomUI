local _, ns = ...

local GetNumFriends = GetNumFriends
local GetFriendInfo = GetFriendInfo
local GetTime = GetTime
local SendChatMessage = SendChatMessage
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local date = date
local type = type
local find = string.find
local tremove = table.remove

local Chat = ns:GetModule("Chat")

local REPLY_EN = "private messages closed"
local REPLY_RU = "личные сообщения закрыты"
local REPLY_COOLDOWN = 0.25
local MAX_STORED_MESSAGES = 200
local TIME_FORMAT = "%m/%d/%y %H:%M:%S"

local blocked = false
local blockedMessages
local whitelist = {}
local lastReplyTime, lastMessageText = 0

local function isFriend(name)
	for i = 1, GetNumFriends() do
		if GetFriendInfo(i) == name then
			return true
		end
	end
	return false
end

local function printMessage(entry)
	ns.Print("%s (at %s): %s", entry.sender, entry.time, entry.text)
end

local function onWhisper(_, _, message, sender)
	if isFriend(sender) or whitelist[sender] then
		return
	end

	local now = GetTime()
	if now - lastReplyTime > REPLY_COOLDOWN then
		lastReplyTime = now
		SendChatMessage(find(message, "[\208\209]") and REPLY_RU or REPLY_EN, "WHISPER", nil, sender)
	end

	if lastMessageText ~= message then
		lastMessageText = message
		blockedMessages[#blockedMessages + 1] = { sender = sender, time = date(TIME_FORMAT), text = message }

		while #blockedMessages > MAX_STORED_MESSAGES do
			tremove(blockedMessages, 1)
		end
	end

	return true
end

local function onWhisperSent(_, _, message, target)
	if message == REPLY_EN or message == REPLY_RU then
		return true
	end

	for i = 1, #blockedMessages do
		local entry = blockedMessages[i]
		if entry.sender == target then
			printMessage(entry)
		end
	end
	for i = #blockedMessages, 1, -1 do
		if blockedMessages[i].sender == target then
			tremove(blockedMessages, i)
		end
	end
	whitelist[target] = true
end

local function setBlocked(state)
	blocked = state
	if state then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", onWhisper)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", onWhisperSent)
		ns.Print("you are |cffff0000no longer receiving|r private messages")
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", onWhisper)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", onWhisperSent)
		ns.Print("you now |cff00ff00receive|r private messages")
	end
end

Chat:RegisterEvent(ns.DB_LOADED, function(_, db)
	blockedMessages = db.pm_messages or {}
	db.pm_messages = blockedMessages

	for i = #blockedMessages, 1, -1 do
		if type(blockedMessages[i]) ~= "table" then
			tremove(blockedMessages, i)
		end
	end

	if db.pm_blocked then
		setBlocked(true)
	end
end)

SlashCmdList.FROSTATOMUI_PM = function()
	setBlocked(not blocked)
	ns:SaveVariable("pm_blocked", blocked)

	for i = 1, #blockedMessages do
		printMessage(blockedMessages[i])
	end
	wipe(blockedMessages)
	wipe(whitelist)
end
SLASH_FROSTATOMUI_PM1 = "/pm"
