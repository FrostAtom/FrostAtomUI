local _, ns = ...

local ICON_TAG_LIST = ICON_TAG_LIST
local ICON_LIST = ICON_LIST
local find, gsub, sub, lower = string.find, string.gsub, string.sub, string.lower
local min = math.min

local Chat = ns:GetModule("Chat")

local config = ns.Config.chat
local BORDER_SIZE = 1

local function iconTagToTexture(tag)
	local index = ICON_TAG_LIST[lower(sub(tag, 2, -2))]
	return index and ICON_LIST[index] and (ICON_LIST[index] .. "0|t") or tag
end

local function onBubbleShow(bubble)
	local text = bubble.text
	local message = text:GetText() or ""
	if find(message, "{", 1, true) then
		text:SetText((gsub(message, "%b{}", iconTagToTexture)))
	end

	local r, g, b = text:GetTextColor()
	bubble.border:SetVertexColor(r, g, b, config.bubbleBorderAlpha)

	local font = ChatFrame1:GetFont()
	text:SetFont(font, config.bubbleFont.size, config.bubbleFont.outline)
	text:SetTextColor(r, g, b)
	bubble.background:SetTexture(0, 0, 0, config.bubbleAlpha)
	local padding = config.bubblePadding
	bubble.background:SetSize(
		min(text:GetStringWidth(), config.bubbleMaxWidth) + padding * 2,
		text:GetStringHeight() + padding * 2
	)
end

local function setupBubble(_, bubble)
	local border, text
	for i = 1, bubble:GetNumRegions() do
		local region = select(i, bubble:GetRegions())
		if region:GetObjectType() == "FontString" then
			text = region
		elseif not border then
			border = region
		else
			region:SetTexture(nil)
			region:Hide()
		end
	end
	if not (border and text) then
		return
	end

	local background = bubble:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetPoint("CENTER", text)

	border:SetTexture(ns.Media.blank)
	border:SetDrawLayer("BACKGROUND", 0)
	border:ClearAllPoints()
	border:SetPoint("TOPRIGHT", background, BORDER_SIZE, BORDER_SIZE)
	border:SetPoint("BOTTOMLEFT", background, -BORDER_SIZE, -BORDER_SIZE)

	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	text:SetDrawLayer("OVERLAY")

	bubble.border = border
	bubble.background = background
	bubble.text = text

	onBubbleShow(bubble)
	bubble:SetScript("OnShow", onBubbleShow)
end

Chat:OnInitialize(function(self)
	self:RegisterEvent(ns.CHAT_BUBBLE_CREATED, setupBubble)
end)
