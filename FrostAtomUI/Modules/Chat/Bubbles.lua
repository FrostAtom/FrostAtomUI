local _, ns = ...

local ICON_TAG_LIST = ICON_TAG_LIST
local ICON_LIST = ICON_LIST
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local find, gsub, sub, lower, match = string.find, string.gsub, string.sub, string.lower, string.match
local min, max = math.min, math.max

local Chat = ns:GetModule("Chat")
local BubbleLayer = ns.BubbleLayer
local PlateLayer = ns.PlateLayer
local classColors = ns:GetModule("UnitFrames").classColors

local config = ns.Config.chat
local frameConfig = ns.Config.unitFrames
local plateConfig = ns.Config.namePlates
local BACKDROP = ns.CreateBackdrop(8, 2)
local BORDER_INSET = 3
local SENDER_GAP = 2

local function iconTagToTexture(tag)
	local index = ICON_TAG_LIST[lower(sub(tag, 2, -2))]
	return index and ICON_LIST[index] and (ICON_LIST[index] .. "0|t") or tag
end

local function senderColor(info)
	local guid = info.guid
	if PlateLayer.IsPlayerGUID(guid) then
		local _, class = GetPlayerInfoByGUID(guid)
		local color = class and classColors[class]
		if color then
			return color[1], color[2], color[3]
		end
	end
	return info.r, info.g, info.b
end

local function layout(bubble, info)
	local text, sender = bubble.text, bubble.sender
	local r, g, b = info.r, info.g, info.b

	local bubbleFont = config.bubbleFont
	ns.SetFont(text, bubbleFont.size, bubbleFont.outline)
	text:SetTextColor(r, g, b)

	local senderWidth, senderHeight = 0, 0
	if config.bubbleShowSender and info.sender then
		local nameFont = plateConfig.nameFont
		ns.SetFont(sender, nameFont.size, nameFont.outline)
		sender:SetText(match(info.sender, "^[^%-]+"))
		sender:SetTextColor(senderColor(info))
		sender:Show()
		senderWidth, senderHeight = sender:GetStringWidth(), sender:GetStringHeight() + SENDER_GAP
	else
		sender:Hide()
	end

	text:SetWidth(0)
	text:SetWidth(max(min(text:GetStringWidth(), config.bubbleMaxWidth), senderWidth))

	local inset = config.bubblePadding + BORDER_INSET
	bubble:ClearAllPoints()
	bubble:SetPoint("BOTTOMLEFT", text, -inset, -inset)
	bubble:SetPoint("TOPRIGHT", text, inset, inset + senderHeight)

	local backdrop = frameConfig.backdropColor
	bubble:SetBackdropColor(backdrop[1], backdrop[2], backdrop[3], backdrop[4])
	if config.bubbleTypeBorder then
		bubble:SetBackdropBorderColor(r, g, b)
	else
		local color = frameConfig.borderColor
		bubble:SetBackdropBorderColor(color[1], color[2], color[3])
	end
end

local function onShown(bubble, info)
	if not bubble.sender then
		return
	end
	local text = bubble.text
	local message = text:GetText() or ""
	if find(message, "{", 1, true) then
		text:SetText((gsub(message, "%b{}", iconTagToTexture)))
	end
	layout(bubble, info)
end

local function setupBubble(bubble, info)
	local text = info.text
	if info.tail then
		info.tail:SetTexture(nil)
		info.tail:Hide()
	end
	bubble:SetBackdrop(BACKDROP)

	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	text:SetJustifyH("LEFT")

	local sender = bubble:CreateFontString(nil, "OVERLAY")
	sender:SetPoint("BOTTOMLEFT", text, "TOPLEFT", 0, SENDER_GAP)
	sender:SetJustifyH("LEFT")
	sender:SetWordWrap(false)
	sender:Hide()

	bubble.text = text
	bubble.sender = sender
end

local function relayout()
	local bubbles = BubbleLayer.bubbles
	for i = 1, #bubbles do
		local bubble = bubbles[i]
		local info = BubbleLayer.GetInfo(bubble)
		if bubble.sender and info.shown then
			layout(bubble, info)
		end
	end
end

Chat:OnInitialize(function(self)
	BubbleLayer.Register({ created = setupBubble, shown = onShown })
	self:WatchConfig("chat", relayout)
	self:WatchConfig("unitFrames", relayout)
	self:WatchConfig("namePlates.nameFont", relayout)
end)
