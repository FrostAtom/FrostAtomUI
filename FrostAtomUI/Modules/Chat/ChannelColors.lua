local _, ns = ...

local GetChannelList = GetChannelList
local ChangeChatColor = ChangeChatColor
local match = string.match
local abs = math.abs

local Chat = ns:GetModule("Chat")

local savedColors

local function channelName(index, ...)
	for i = 1, select("#", ...), 2 do
		if select(i, ...) == index then
			return (select(i + 1, ...))
		end
	end
end

local function sameColor(info, color)
	return abs(info.r - color.r) < 0.01 and abs(info.g - color.g) < 0.01 and abs(info.b - color.b) < 0.01
end

local function restoreColors()
	local list = { GetChannelList() }
	for i = 1, #list, 2 do
		local chatType = "CHANNEL" .. list[i]
		local color = savedColors[list[i + 1]]
		local info = ChatTypeInfo[chatType]
		if color and info and not sameColor(info, color) then
			ChangeChatColor(chatType, color.r, color.g, color.b)
		end
	end
end

local function onColorChanged(_, chatType, r, g, b)
	local index = match(chatType, "^CHANNEL(%d+)$")
	local name = index and channelName(tonumber(index), GetChannelList())
	if name then
		savedColors[name] = { r = r, g = g, b = b }
	end
end

Chat:OnInitialize(function(self)
	local db = ns.db
	savedColors = db.channel_colors or {}
	db.channel_colors = savedColors

	self:RegisterEvent("UPDATE_CHAT_COLOR", onColorChanged)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", restoreColors)
	self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", restoreColors)
end)
