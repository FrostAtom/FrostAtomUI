local _, ns = ...

local L = ns.L

local GetNumFriends = GetNumFriends
local GetFriendInfo = GetFriendInfo
local GetTime = GetTime
local SendChatMessage = SendChatMessage
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local PlaySound = PlaySound
local date = date
local strtrim = strtrim
local tremove, tconcat = table.remove, table.concat
local huge = math.huge

local Chat = ns:GetModule("Chat")

local REPLY_COOLDOWN = 0.25
local MAX_STORED_MESSAGES = 200
local TIME_FORMAT = "%m/%d/%y %H:%M:%S"

local chatConfig = ns.Config.chat
local config = chatConfig.whisperBlock
local blocked = false
local blockedMessages = {}
local whitelist = {}
local lastReplyTime = 0
local printLines = {}
local soundThrottled = false
local soundPlayedAt = {}

local function replyText()
	local reply = config.reply
	return reply ~= "" and reply or nil
end

local function isFriend(name)
	for i = 1, GetNumFriends() do
		if GetFriendInfo(i) == name then
			return true
		end
	end
	return false
end

local function printMessages(sender)
	wipe(printLines)
	for i = 1, #blockedMessages do
		local entry = blockedMessages[i]
		if not sender or entry.sender == sender then
			printLines[#printLines + 1] = L["%s (at %s): %s"]:format(entry.sender, entry.time, entry.text)
		end
	end
	if #printLines > 0 then
		ns.Print(L["blocked whispers:\n%s"], tconcat(printLines, "\n"))
	end
end

local function printStatus()
	if blocked then
		ns.Print(L["NoDM |cffff0000enabled|r, reply: %s"], replyText() or L["none (set with /nodm <message>)"])
	else
		ns.Print(L["NoDM |cff00ff00disabled|r"])
	end
end

local function isBlocked(sender)
	return blocked and not ((config.friendsBypass and isFriend(sender)) or whitelist[sender])
end

local function onWhisper(_, _, message, sender)
	if not isBlocked(sender) then
		return
	end

	local reply = replyText()
	local now = GetTime()
	if reply and now - lastReplyTime > REPLY_COOLDOWN then
		lastReplyTime = now
		SendChatMessage(reply, "WHISPER", nil, sender)
	end

	local last = blockedMessages[#blockedMessages]
	if not (last and last.sender == sender and last.text == message and last.at == now) then
		blockedMessages[#blockedMessages + 1] = { sender = sender, time = date(TIME_FORMAT), text = message, at = now }

		while #blockedMessages > MAX_STORED_MESSAGES do
			tremove(blockedMessages, 1)
		end
	end

	return true
end

local function onWhisperSent(_, _, message, target)
	if message == replyText() then
		return true
	end

	printMessages(target)
	for i = #blockedMessages, 1, -1 do
		if blockedMessages[i].sender == target then
			tremove(blockedMessages, i)
		end
	end
	whitelist[target] = true
end

local function applyConfig()
	if config.enabled == blocked then
		return
	end
	blocked = config.enabled
	if blocked then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", onWhisper)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", onWhisperSent)
		wipe(whitelist)
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", onWhisper)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", onWhisperSent)
		printMessages()
		wipe(blockedMessages)
	end
	printStatus()
end

local function holdBlizzardTellSound(chatFrame)
	chatFrame.tellTimer = huge
end

local function onWhisperSound(_, _, sender)
	if isBlocked(sender) then
		return
	end
	local now = GetTime()
	local last = soundPlayedAt[sender]
	if last and now - last < chatConfig.whisperSoundInterval then
		return
	end
	soundPlayedAt[sender] = now
	PlaySound("TellMessage")
end

local function applyWhisperSound()
	local enabled = chatConfig.whisperSoundThrottle
	if enabled == soundThrottled then
		return
	end
	soundThrottled = enabled
	if enabled then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", holdBlizzardTellSound)
		Chat:RegisterEvent("CHAT_MSG_WHISPER", onWhisperSound)
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", holdBlizzardTellSound)
		Chat:UnregisterEvent("CHAT_MSG_WHISPER", onWhisperSound)
		local now = GetTime()
		for i = 1, NUM_CHAT_WINDOWS do
			_G["ChatFrame" .. i].tellTimer = now
		end
	end
end

Chat:OnInitialize(function(self)
	local db = ns.db
	blockedMessages = db.pm_messages or blockedMessages
	db.pm_messages = blockedMessages

	if config.enabled then
		applyConfig()
	end
	self:WatchConfig("chat.whisperBlock", applyConfig)

	applyWhisperSound()
	self:WatchConfig("chat.whisperSoundThrottle", applyWhisperSound)
end)

SlashCmdList.FROSTATOMUI_NODM = function(args)
	args = strtrim(args or "")
	local lower = args:lower()
	local state, status
	if args == "" or lower == "on" or lower == "off" or lower == "status" then
		state, status = ns.ParseToggle(args, blocked)
	else
		ns:SetConfig("chat.whisperBlock.reply", args)
		state = true
	end

	if status or state == blocked then
		printStatus()
		return
	end
	ns:SetConfig("chat.whisperBlock.enabled", state)
end
SLASH_FROSTATOMUI_NODM1 = "/nodm"
