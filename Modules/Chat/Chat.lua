local _, ns = ...

-- Flat chat frames: no Blizzard textures, translucent backdrop, tabs that
-- only show on hover. Also a few chat conveniences.

local CreateFrame = CreateFrame
local ChatEdit_UpdateHeader = ChatEdit_UpdateHeader
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local SendSystemMessage = SendSystemMessage

local Chat = ns:NewModule("Chat")

ns:GetModule("CVars"):Pin("chatStyle", "classic")

-- Class-colored player names in every chat type (the "Class Color" checkbox
-- of the chat settings, ticked for everything). Chat settings are restored
-- by the client on login, so re-apply after entering the world too.
local function enableClassColors()
	for chatType, info in pairs(ChatTypeInfo) do
		if not info.colorNameByClass then
			SetChatColorNameByClass(chatType, true)
		end
	end
end

function Chat:Initialize()
	enableClassColors()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", enableClassColors)
end

-- The combat log tab is never used.
CombatLog_LoadUI = ns.noop
Blizzard_CombatLog_Update_QuickButtons = ns.noop
ChatConfigFrame:SetScript("OnShow", nil)

--------------------------------------------------
-- Conveniences

-- The "you must wait before speaking again" error goes to chat instead of
-- the (hidden) error frame.
Chat:RegisterEvent("UI_ERROR_MESSAGE", function(_, message)
	if message:find("^You must wait .- before speaking again.$") then
		SendSystemMessage(message)
	end
end)

-- "/tt " and "/wt " turn into a whisper to the current target.
hooksecurefunc("ChatEdit_OnSpacePressed", function(editBox)
	if not editBox:GetText():lower():find("^/[wt]t ") or not UnitIsPlayer("target") then
		return
	end

	local name, realm = UnitName("target")
	if not name then
		return
	end
	if realm and realm ~= "" then
		name = name .. "-" .. realm
	end

	editBox:SetAttribute("tellTarget", name)
	editBox:SetAttribute("chatType", "WHISPER")
	editBox.setText = 1
	editBox.text = ""
	editBox:SetFocus()
	ChatEdit_UpdateHeader(editBox)
end)

local SYSTEM_SPAM = {
	"^|cffff0000%[BG Queue Announcer%]:|r",
}

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
	for _, pattern in ipairs(SYSTEM_SPAM) do
		if message:match(pattern) then
			return true
		end
	end
end)

--------------------------------------------------
-- Short channel names and timestamps

-- Blizzard channel prefixes, e.g. "[Guild]" -> "[G]".
local CHANNEL_GETS = {
	CHAT_GUILD_GET = "|Hchannel:GUILD|h[G]|h %s:\32",
	CHAT_OFFICER_GET = "|Hchannel:OFFICER|h[O]|h %s:\32",
	CHAT_PARTY_GET = "|Hchannel:PARTY|h[P]|h %s:\32",
	CHAT_PARTY_LEADER_GET = "|Hchannel:PARTY|h[PL]|h %s:\32",
	CHAT_PARTY_GUIDE_GET = "|Hchannel:PARTY|h[PG]|h %s:\32",
	CHAT_RAID_GET = "|Hchannel:RAID|h[R]|h %s:\32",
	CHAT_RAID_LEADER_GET = "|Hchannel:RAID|h[RL]|h %s:\32",
	CHAT_RAID_WARNING_GET = "[RW] %s:\32",
	CHAT_BATTLEGROUND_GET = "|Hchannel:BATTLEGROUND|h[BG]|h %s:\32",
	CHAT_BATTLEGROUND_LEADER_GET = "|Hchannel:BATTLEGROUND|h[BL]|h %s:\32",
	CHAT_SAY_GET = "[S] %s:\32",
	CHAT_YELL_GET = "[Y] %s:\32",
	CHAT_WHISPER_GET = "[W from] %s:\32",
	CHAT_WHISPER_INFORM_GET = "[W to] %s:\32",
	CHAT_BN_WHISPER_GET = "[BN from] %s:\32",
	CHAT_BN_WHISPER_INFORM_GET = "[BN to] %s:\32",
}

for key, value in pairs(CHANNEL_GETS) do
	_G[key] = value
end

local TIMESTAMP_FORMAT = "|cff7f7f7f%H:%M|r "

-- Numbered channels are formatted as "[1. General]" by the client itself.
local function shortenChannelName(text)
	return (text:gsub("%[(%d+)%. [^%]]+%]", "[%1]", 1))
end

local function hookAddMessage(chatFrame)
	local addMessage = chatFrame.AddMessage
	chatFrame.AddMessage = function(self, text, ...)
		if type(text) == "string" then
			text = date(TIMESTAMP_FORMAT) .. shortenChannelName(text)
		end
		return addMessage(self, text, ...)
	end
end

--------------------------------------------------
-- Look

CHAT_FRAME_FADE_OUT_TIME = 0.5
CHAT_TAB_HIDE_DELAY = 0
CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = 1
CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0
CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA = 1
CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA = 1
CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA = 1
CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0

local BACKDROP = ns.CreateBackdrop(14, 3)

ChatFrameMenuButton:Hide()
ChatFrameMenuButton:SetScript("OnShow", ChatFrameMenuButton.Hide)

FriendsMicroButton:SetPoint("BOTTOM", ChatFrame1, "TOPLEFT", 8, 4)
FriendsMicroButton:SetFrameLevel(ChatFrame1Tab:GetFrameLevel() + 1)

local function hideRegions(prefix, ...)
	for i = 1, select("#", ...) do
		_G[prefix .. select(i, ...)]:Hide()
	end
end

local function addBackdrop(parent, inset)
	local backdrop = CreateFrame("Frame", nil, parent)
	backdrop:SetFrameLevel(parent:GetFrameLevel() - 1)
	backdrop:SetPoint("TOPRIGHT", inset, inset)
	backdrop:SetPoint("BOTTOMLEFT", -inset, -inset)
	backdrop:SetBackdrop(BACKDROP)
	backdrop:SetBackdropColor(0, 0, 0, 0.6)
	return backdrop
end

local function setupTab(name)
	local tab = _G[name]

	hideRegions(name, "Left", "Middle", "Right")
	tab.leftSelectedTexture:SetAlpha(0)
	tab.rightSelectedTexture:SetAlpha(0)
	tab.middleSelectedTexture:SetAlpha(0)
	tab.leftHighlightTexture:SetTexture(nil)
	tab.rightHighlightTexture:SetTexture(nil)
	tab.middleHighlightTexture:SetTexture([[BUTTONS\CheckButtonGlow]])
	tab.middleHighlightTexture:SetWidth(76)
	tab.middleHighlightTexture:SetTexCoord(0, 0, 1, 0.5)
end

local function setupEditBox(name)
	local editBox = _G[name]
	editBox:SetAltArrowKeyMode(false)
	editBox:Hide()

	hideRegions(name, "Left", "Right", "Mid")
	editBox.focusLeft:SetTexture(nil)
	editBox.focusRight:SetTexture(nil)
	editBox.focusMid:SetTexture(nil)

	local backdrop = addBackdrop(editBox, 0)
	backdrop:SetPoint("TOPRIGHT", 0, -4)
	backdrop:SetPoint("BOTTOMLEFT", 0, 4)
end

local function setupChatFrame(name)
	local chatFrame = _G[name]
	chatFrame:SetScript("OnUpdate", nil)
	chatFrame:SetTimeVisible(30)
	chatFrame:SetShadowOffset(0, 0)
	chatFrame:SetClampRectInsets(-7, -7, -7, -31)

	local buttonFrame = _G[name .. "ButtonFrame"]
	buttonFrame:Hide()
	buttonFrame:SetScript("OnShow", buttonFrame.Hide)

	hideRegions(
		name,
		"Background",
		"TopTexture",
		"BottomTexture",
		"LeftTexture",
		"RightTexture",
		"TopLeftTexture",
		"TopRightTexture",
		"BottomLeftTexture",
		"BottomRightTexture"
	)
	addBackdrop(chatFrame, 6)
	hookAddMessage(chatFrame)
end

for i = 1, NUM_CHAT_WINDOWS do
	local name = "ChatFrame" .. i
	setupChatFrame(name)
	setupTab(name .. "Tab")
	setupEditBox(name .. "EditBox")
end
