local _, ns = ...

local hooksecurefunc = hooksecurefunc

local Chat = ns:GetModule("Chat")
local config = ns.Config.chat

local BUTTON_SIZE = 20
local FLASH_DURATION = 0.4
local SCROLL_METHODS = {
	"ScrollUp",
	"ScrollDown",
	"PageUp",
	"PageDown",
	"ScrollToTop",
	"ScrollToBottom",
	"SetScrollOffset",
	"Clear",
}

local buttons = {}

local function update(chatFrame)
	local button = buttons[chatFrame]
	if config.scrollToBottomButton and not chatFrame:AtBottom() then
		button:Show()
	else
		button.flash:Hide()
		button:Hide()
	end
end

local function onMessage(chatFrame)
	update(chatFrame)
	local button = buttons[chatFrame]
	if button:IsShown() then
		button.flash:Show()
	end
end

local function onClick(self)
	self:GetParent():ScrollToBottom()
end

local function playFlash(self)
	self.animation:Play()
end

local function stopFlash(self)
	self.animation:Stop()
end

local function createButton(chatFrame)
	local button = CreateFrame("Button", nil, chatFrame)
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", 0, 0)
	button:SetFrameLevel(chatFrame:GetFrameLevel() + 5)
	button:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Up]])
	button:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Down]])
	button:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]], "ADD")
	button:SetScript("OnClick", onClick)
	button:Hide()

	local flash = CreateFrame("Frame", nil, button)
	flash:SetAllPoints()
	local texture = flash:CreateTexture(nil, "OVERLAY")
	texture:SetTexture([[Interface\ChatFrame\UI-ChatIcon-BlinkHilight]])
	texture:SetBlendMode("ADD")
	texture:SetAllPoints()

	local animation = flash:CreateAnimationGroup()
	local alpha = animation:CreateAnimation("Alpha")
	alpha:SetChange(-1)
	alpha:SetDuration(FLASH_DURATION)
	animation:SetLooping("BOUNCE")
	flash.animation = animation
	flash:SetScript("OnShow", playFlash)
	flash:SetScript("OnHide", stopFlash)
	flash:Hide()

	button.flash = flash
	buttons[chatFrame] = button

	hooksecurefunc(chatFrame, "AddMessage", onMessage)
	for i = 1, #SCROLL_METHODS do
		if chatFrame[SCROLL_METHODS[i]] then
			hooksecurefunc(chatFrame, SCROLL_METHODS[i], update)
		end
	end
end

local function updateAll()
	for chatFrame in pairs(buttons) do
		update(chatFrame)
	end
end

Chat:OnInitialize(function(self)
	if not config.skin then
		return
	end
	for i = 1, NUM_CHAT_WINDOWS do
		createButton(_G["ChatFrame" .. i])
	end
	self:WatchConfig("chat.scrollToBottomButton", updateAll)
end)
