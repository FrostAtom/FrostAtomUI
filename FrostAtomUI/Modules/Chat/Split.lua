local _, ns = ...

local SendChatMessage = SendChatMessage
local find, sub, byte = string.find, string.sub, string.byte
local tremove = table.remove

local Chat = ns:GetModule("Chat")

local MAX_LETTERS = 1024
local MESSAGE_BYTES = 255
-- the server's flood protection mutes chat messages sent in a burst
local SEND_INTERVAL = 1.5
local LINK_PATTERN = "|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r"

local SPLIT_TYPES = {
	SAY = true,
	YELL = true,
	EMOTE = true,
	WHISPER = true,
	PARTY = true,
	RAID = true,
	RAID_WARNING = true,
	BATTLEGROUND = true,
	GUILD = true,
	OFFICER = true,
	CHANNEL = true,
}

local tokens, spacedTokens = {}, {}

local function addToken(token, spaced)
	local count = #tokens + 1
	tokens[count], spacedTokens[count] = token, spaced
end

local function tokenize(text)
	wipe(tokens)
	wipe(spacedTokens)
	local position, length, spaced = 1, #text, false
	while position <= length do
		local linkStart, linkEnd = find(text, LINK_PATTERN, position)
		local plainEnd = (linkStart or length + 1) - 1
		while true do
			local wordStart, wordEnd = find(text, "%S+", position)
			if not wordStart or wordStart > plainEnd then
				break
			end
			if wordEnd > plainEnd then
				wordEnd = plainEnd
			end
			addToken(sub(text, wordStart, wordEnd), spaced or wordStart > position)
			spaced = false
			position = wordEnd + 1
		end
		spaced = spaced or position <= plainEnd
		if not linkStart then
			break
		end
		addToken(sub(text, linkStart, linkEnd), spaced)
		spaced = false
		position = linkEnd + 1
	end
end

local function characterBoundary(text, limit)
	local cut = limit
	while cut > 1 do
		local nextByte = byte(text, cut + 1)
		if not nextByte or nextByte < 0x80 or nextByte >= 0xC0 then
			break
		end
		cut = cut - 1
	end
	return cut
end

local function splitMessage(text)
	tokenize(text)
	local chunks, current = {}, ""
	for i = 1, #tokens do
		local token = tokens[i]
		local joined = current == "" and token or current .. (spacedTokens[i] and " " or "") .. token
		if #joined <= MESSAGE_BYTES then
			current = joined
		else
			if current ~= "" then
				chunks[#chunks + 1] = current
			end
			while #token > MESSAGE_BYTES do
				local cut = characterBoundary(token, MESSAGE_BYTES)
				chunks[#chunks + 1] = sub(token, 1, cut)
				token = sub(token, cut + 1)
			end
			current = token
		end
	end
	if current ~= "" then
		chunks[#chunks + 1] = current
	end
	return chunks
end

local queue = {}
local sending = false
local pendingEditBox, pendingText

local function sendNext()
	local message = tremove(queue, 1)
	if not message then
		sending = false
		return
	end
	SendChatMessage(message[1], message[2], message[3], message[4])
	ns.After(SEND_INTERVAL, sendNext)
end

local function onParseText(editBox, send)
	if send ~= 1 then
		return
	end
	local text = editBox:GetText()
	local chatType = editBox:GetAttribute("chatType")
	if #text <= MESSAGE_BYTES or not SPLIT_TYPES[chatType] then
		return
	end

	local chunks = splitMessage(text)
	if #chunks < 2 then
		return
	end
	local target
	if chatType == "WHISPER" then
		target = editBox:GetAttribute("tellTarget")
	elseif chatType == "CHANNEL" then
		target = editBox:GetAttribute("channelTarget")
	end
	local first = sending and 1 or 2
	for i = first, #chunks do
		queue[#queue + 1] = { chunks[i], chatType, editBox.language, target }
	end
	if not sending then
		sending = true
		ns.After(SEND_INTERVAL, sendNext)
	end

	pendingEditBox, pendingText = editBox, text
	editBox:SetText(first == 1 and "" or chunks[1])
end

local function onSendChatMessage()
	if pendingEditBox then
		pendingEditBox:SetText(pendingText)
		pendingEditBox, pendingText = nil, nil
	end
end

local function onSendText(editBox, addHistory)
	if pendingEditBox ~= editBox then
		return
	end
	editBox:SetText(pendingText)
	pendingEditBox, pendingText = nil, nil
	if addHistory then
		ChatEdit_AddHistory(editBox)
	end
end

Chat:OnInitialize(function()
	for i = 1, NUM_CHAT_WINDOWS do
		local editBox = _G["ChatFrame" .. i .. "EditBox"]
		editBox:SetMaxLetters(MAX_LETTERS)
		editBox:SetMaxBytes(0)
	end
	hooksecurefunc("ChatEdit_ParseText", onParseText)
	hooksecurefunc("SendChatMessage", onSendChatMessage)
	hooksecurefunc("ChatEdit_SendText", onSendText)
end)
