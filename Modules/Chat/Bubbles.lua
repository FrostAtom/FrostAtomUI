local _, ns = ...

local ICON_TAG_LIST = ICON_TAG_LIST
local ICON_LIST = ICON_LIST

local Chat = ns:GetModule("Chat")

local MAX_WIDTH = 300
local PADDING = 6
local FONT_SIZE = 12
local BACKGROUND_ALPHA = 0.75
local BORDER_ALPHA = 0.9

local function replaceIconTags(text)
	return (text:gsub("%b{}", function(tag)
		local index = ICON_TAG_LIST[tag:sub(2, -2):lower()]
		return index and ICON_LIST[index] and (ICON_LIST[index] .. "0|t") or tag
	end))
end

local function onBubbleShow(bubble)
	local text = bubble.text
	local message = text:GetText() or ""
	if message:find("{", 1, true) then
		text:SetText(replaceIconTags(message))
	end

	local r, g, b = text:GetTextColor()
	bubble.border:SetVertexColor(r, g, b, BORDER_ALPHA)

	local width = math.min(text:GetStringWidth(), MAX_WIDTH) + PADDING * 2
	local height = text:GetStringHeight() + PADDING * 2
	bubble.background:SetSize(width, height)
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

	local borderSize = 1

	local background = bubble:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetTexture(0, 0, 0, BACKGROUND_ALPHA)
	background:SetPoint("CENTER", text)

	border:SetTexture(ns.Media.blank)
	border:SetDrawLayer("BACKGROUND", 0)
	border:ClearAllPoints()
	border:SetPoint("TOPRIGHT", background, borderSize, borderSize)
	border:SetPoint("BOTTOMLEFT", background, -borderSize, -borderSize)

	local r, g, b = text:GetTextColor()
	local font, _, flags = ChatFrame1:GetFont()
	text:SetFont(font, FONT_SIZE, flags)
	text:SetTextColor(r, g, b)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	text:SetDrawLayer("OVERLAY")

	bubble.border = border
	bubble.background = background
	bubble.text = text

	onBubbleShow(bubble)
	bubble:SetScript("OnShow", onBubbleShow)
end

Chat:RegisterEvent(ns.CHAT_BUBBLE_CREATED, setupBubble)
