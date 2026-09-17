local _, ns = ...

local GetChannelList = GetChannelList
local ChangeChatColor = ChangeChatColor

local Chat = ns:GetModule("Chat")

local savedColors

local function channelName(index)
	local list = { GetChannelList() }
	for i = 1, #list, 2 do
		if list[i] == index then
			return list[i + 1]
		end
	end
end

local function sameColor(info, color)
	return math.abs(info.r - color.r) < 0.01 and math.abs(info.g - color.g) < 0.01 and math.abs(info.b - color.b) < 0.01
end

local function restoreColors()
	if not savedColors then
		return
	end

	local list = { GetChannelList() }
	for i = 1, #list, 2 do
		local index, name = list[i], list[i + 1]
		local color = savedColors[name]
		local info = ChatTypeInfo["CHANNEL" .. index]
		if color and info and not sameColor(info, color) then
			ChangeChatColor("CHANNEL" .. index, color.r, color.g, color.b)
		end
	end
end

Chat:RegisterEvent("UPDATE_CHAT_COLOR", function(_, chatType, r, g, b)
	if not savedColors then
		return
	end

	local index = chatType:match("^CHANNEL(%d+)$")
	local name = index and channelName(tonumber(index))
	if name then
		savedColors[name] = { r = r, g = g, b = b }
	end
end)

Chat:RegisterEvent(ns.DB_LOADED, function(_, db)
	savedColors = db.channel_colors or {}
	db.channel_colors = savedColors
end)

Chat:RegisterEvent("PLAYER_ENTERING_WORLD", restoreColors)
Chat:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", restoreColors)
