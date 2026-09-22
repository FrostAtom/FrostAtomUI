local _, ns = ...

local GetNumFriends = GetNumFriends
local GetFriendInfo = GetFriendInfo
local GetTime = GetTime
local SendChatMessage = SendChatMessage
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local date = date
local strtrim = strtrim
local tremove = table.remove

local Chat = ns:GetModule("Chat")

local REPLY_COOLDOWN = 0.25
local MAX_STORED_MESSAGES = 200
local TIME_FORMAT = "%m/%d/%y %H:%M:%S"

local blocked = false
local blockedMessages
local reply
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

local function printStatus()
	if blocked then
		ns.Print("NoDM |cffff0000enabled|r, reply: %s", reply or "none (set with /nodm <message>)")
	else
		ns.Print("NoDM |cff00ff00disabled|r")
	end
end

local function onWhisper(_, _, message, sender)
	if isFriend(sender) or whitelist[sender] then
		return
	end

	local now = GetTime()
	if reply and now - lastReplyTime > REPLY_COOLDOWN then
		lastReplyTime = now
		SendChatMessage(reply, "WHISPER", nil, sender)
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
	if message == reply then
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
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", onWhisper)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", onWhisperSent)
	end
	printStatus()
end

Chat:RegisterEvent(ns.DB_LOADED, function(_, db)
	blockedMessages = db.pm_messages or {}
	db.pm_messages = blockedMessages
	reply = db.pm_reply

	for i = #blockedMessages, 1, -1 do
		if type(blockedMessages[i]) ~= "table" then
			tremove(blockedMessages, i)
		end
	end

	if db.pm_blocked then
		setBlocked(true)
	end
end)

SlashCmdList.FROSTATOMUI_NODM = function(args)
	args = strtrim(args or "")
	local lower = args:lower()
	local state, status
	if args == "" or lower == "on" or lower == "off" or lower == "status" then
		state, status = ns.ParseToggle(args, blocked)
	else
		reply = args
		ns:SaveVariable("pm_reply", reply)
		state = true
	end

	if status or state == blocked then
		printStatus()
		return
	end

	setBlocked(state)
	ns:SaveVariable("pm_blocked", blocked)

	for i = 1, #blockedMessages do
		printMessage(blockedMessages[i])
	end
	wipe(blockedMessages)
	wipe(whitelist)
end
SLASH_FROSTATOMUI_NODM1 = "/nodm"
