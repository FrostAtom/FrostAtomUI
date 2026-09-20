local _, ns = ...

local CreateFrame = CreateFrame
local ChatEdit_UpdateHeader = ChatEdit_UpdateHeader
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local SendSystemMessage = SendSystemMessage
local IsControlKeyDown = IsControlKeyDown
local StaticPopup_Show = StaticPopup_Show
local GameTooltip = GameTooltip
local IsInInstance = IsInInstance
local GetTime = GetTime

local Chat = ns:NewModule("Chat")

ns:GetModule("CVars"):Pin("chatStyle", "classic")

local STICKY_TYPES = {
	"SAY",
	"YELL",
	"WHISPER",
	"BN_WHISPER",
	"PARTY",
	"RAID",
	"RAID_WARNING",
	"BATTLEGROUND",
	"GUILD",
	"OFFICER",
	"CHANNEL",
	"EMOTE",
}

local function enableClassColors()
	for chatType, info in pairs(ChatTypeInfo) do
		if not info.colorNameByClass then
			SetChatColorNameByClass(chatType, true)
		end
	end
end

local function enableSticky()
	for _, chatType in ipairs(STICKY_TYPES) do
		local info = ChatTypeInfo[chatType]
		if info then
			info.sticky = 1
		end
	end
end

function Chat:Initialize()
	enableClassColors()
	enableSticky()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", enableClassColors)
end

local function groupChatType()
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" then
		return "BATTLEGROUND"
	elseif GetNumRaidMembers() > 0 then
		return "RAID"
	elseif GetNumPartyMembers() > 0 then
		return "PARTY"
	end
	return "SAY"
end

SlashCmdList.FROSTATOMUI_GROUP = function(text)
	if text:trim() ~= "" then
		SendChatMessage(text, groupChatType())
	end
end
SLASH_FROSTATOMUI_GROUP1 = "/gr"

SlashCmdList.FROSTATOMUI_CLEAR = function()
	local chatFrame = SELECTED_DOCK_FRAME or ChatFrame1
	chatFrame:Clear()
end
SLASH_FROSTATOMUI_CLEAR1 = "/clear"

SlashCmdList.FROSTATOMUI_CLEARALL = function()
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame" .. i]:Clear()
	end
end
SLASH_FROSTATOMUI_CLEARALL1 = "/clearall"

CombatLog_LoadUI = ns.noop
Blizzard_CombatLog_Update_QuickButtons = ns.noop
ChatConfigFrame:SetScript("OnShow", nil)

Chat:RegisterEvent("UI_ERROR_MESSAGE", function(_, message)
	if message:find("^You must wait .- before speaking again.$") then
		SendSystemMessage(message)
	end
end)

local function switchChatType(editBox, chatType, tellTarget)
	editBox:SetAttribute("tellTarget", tellTarget)
	editBox:SetAttribute("chatType", chatType)
	editBox.setText = 1
	editBox.text = ""
	editBox:SetFocus()
	ChatEdit_UpdateHeader(editBox)
end

hooksecurefunc("ChatEdit_OnSpacePressed", function(editBox)
	local text = editBox:GetText():lower()

	if text == "/gr " then
		switchChatType(editBox, groupChatType())
		return
	end

	if not text:find("^/[wt]t ") or not UnitIsPlayer("target") then
		return
	end

	local name, realm = UnitName("target")
	if not name then
		return
	end
	if realm and realm ~= "" then
		name = name .. "-" .. realm
	end

	switchChatType(editBox, "WHISPER", name)
end)

local SYSTEM_SPAM = {
	"^|cffff0000%[BG Queue Announcer%]:|r",
	"wowcircle%.net",
	"control panel at our website",
	"Speeding up the battle start",
}

local function formatToPattern(text)
	return "^" .. text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%%%[sd]", "(.-)") .. "$"
end

local ARENA_SPAM = {
	formatToPattern(ERR_SET_LOOT_FREEFORALL),
	formatToPattern(ERR_SET_LOOT_GROUP),
	formatToPattern(ERR_SET_LOOT_MASTER),
	formatToPattern(ERR_SET_LOOT_ROUNDROBIN),
	formatToPattern(ERR_SET_LOOT_THRESHOLD_S),
	formatToPattern(ERR_RAID_YOU_JOINED),
	formatToPattern(ERR_RAID_YOU_LEFT),
	formatToPattern(ERR_RAID_MEMBER_ADDED_S),
	formatToPattern(ERR_RAID_MEMBER_REMOVED_S),
	formatToPattern(ERR_BG_PLAYER_LEFT_S),
	formatToPattern(ERR_PLAYER_DIED_S),
	formatToPattern(ERR_LEFT_GROUP_S),
	"^%S+ has joined the battle%.?$",
	"^One minute until the Arena battle begins!$",
	"^Thirty seconds until the Arena battle begins!$",
	"^Fifteen seconds until the Arena battle begins!$",
	"^The Arena battle has begun!$",
	"^Speeding up the battle start! Players ready: %d+%.$",
	"^You are in Spectator Mode%. ",
}

local wasInArena, arenaLeftAt = false, 0

Chat:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local inArena = select(2, IsInInstance()) == "arena"
	if wasInArena and not inArena then
		arenaLeftAt = GetTime()
	end
	wasInArena = inArena
end)

local function isArenaSpam(message)
	if not wasInArena and GetTime() - arenaLeftAt > 10 then
		return false
	end
	for _, pattern in ipairs(ARENA_SPAM) do
		if message:match(pattern) then
			return true
		end
	end
	return false
end

local QUEUE_ICON = "|TInterface\\Icons\\%s:14:14:0:0:64:64:4:60:4:60|t"
local QUEUE_MELEE = QUEUE_ICON:format("Ability_MeleeDamage")
local QUEUE_RANGED = QUEUE_ICON:format("Ability_Marksmanship")
local QUEUE_HEALER = QUEUE_ICON:format("Spell_Holy_Renew")
local QUEUE_GROUPS = QUEUE_ICON:format("Achievement_PVP_A_A")
local QUEUE_ON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local QUEUE_OFF = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t"

ns.SOLOQ_SEARCHING = "FrostAtomUI_SOLOQ_SEARCHING"

local queueCounts = {}

local function queueRating(low, high)
	low, high = tonumber(low), tonumber(high)
	return ("%d |cff7f7f7f[%d-%d]|r"):format((low + high) / 2, low, high)
end

local function filterQueueSpam(message)
	local groups = message:match("^Number of groups in queue Arena 3v3 %(Solo%): (%d+)$")
	if groups then
		queueCounts.groups = groups
		return true
	end
	local melee = message:match("^Melee classes: (%d+)$")
	if melee then
		queueCounts.melee = melee
		return true
	end
	local ranged = message:match("^Ranged classes: (%d+)$")
	if ranged then
		queueCounts.ranged = ranged
		return true
	end
	local healers = message:match("^Healers: (%d+)$")
	if healers then
		queueCounts.healers = healers
		return true
	end

	local mixed = message:match("^Possibility of selecting a mixed arena team %(ignoring specializations%): (%a+)$")
	if mixed then
		local text = ("%s %s  %s %s  %s %s  %s %s  %s"):format(
			QUEUE_GROUPS, queueCounts.groups or "?",
			QUEUE_MELEE, queueCounts.melee or "?",
			QUEUE_RANGED, queueCounts.ranged or "?",
			QUEUE_HEALER, queueCounts.healers or "?",
			mixed == "enabled" and QUEUE_ON or QUEUE_OFF
		)
		wipe(queueCounts)
		return false, text
	end

	local low, high = message:match("^We are looking for the best team for you on the selection rating %[(%d+)%-(%d+)%]$")
	if low then
		ns:Fire(ns.SOLOQ_SEARCHING, tonumber(low), tonumber(high))
		return true
	end

	local teamRating
	teamRating, low, high = message:match("^Team to fight found! Team rating (%d+), looking for suitable opponents on the rating %[(%d+)%-(%d+)%]$")
	if teamRating then
		ns:Fire(ns.SOLOQ_SEARCHING, tonumber(low), tonumber(high), tonumber(teamRating))
		return false, ("Team found (%s), searching opponents: %s"):format(teamRating, queueRating(low, high))
	end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message, ...)
	for _, pattern in ipairs(SYSTEM_SPAM) do
		if message:match(pattern) then
			return true
		end
	end

	if isArenaSpam(message) then
		return true
	end

	local filtered, newMessage = filterQueueSpam(message)
	if filtered then
		return true
	elseif newMessage then
		return false, newMessage, ...
	end
end)

ChatFrame_AddMessageEventFilter("CHAT_MSG_BG_SYSTEM_NEUTRAL", function(_, _, message)
	return isArenaSpam(message)
end)

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

local function shortenChannelName(text)
	return (text:gsub("%[(%d+)%. [^%]]+%]", "[%1]", 1))
end

local URL_LINK = "|cff3399ff|Hurl:%s|h[%s]|h|r"
local URL_PATTERNS = {
	"%f[%S](%a[%w+.%-]+://%S+)",
	"%f[%S](www%.[%w_%%%-]+%.%S+)",
	"%f[%S](%d+%.%d+%.%d+%.%d+:?%d*/?%S*)",
	"%f[%S]([%w_%.%%%-]+%.(%a%a+)[:/]%S+)",
	"%f[%S]([%w_%.%%%-]+%.(%a%a+))%f[%s%p%z]",
}

local URL_TLDS = {}
for tld in ("com net org ru su ua by kz eu de fr uk io gg tv me co info biz dev app xyz pro club online site live"):gmatch("%S+") do
	URL_TLDS[tld] = true
end

local function linkUrl(url, tld)
	if tld and not URL_TLDS[tld:lower()] then
		return
	end
	return URL_LINK:format(url, url)
end

local function linkUrlsInPlainText(text)
	for _, pattern in ipairs(URL_PATTERNS) do
		local replaced = false
		local linked = text:gsub(pattern, function(url, tld)
			local link = linkUrl(url, tld)
			replaced = replaced or link ~= nil
			return link
		end)
		if replaced then
			return linked
		end
	end
	return text
end

local function stripRealm(text)
	if not text:find("|Hplayer:[^|]*%-") then
		return text
	end
	return (text:gsub("(|Hplayer:[^|]*%-[^|]*|h)(.-)(|h)", function(link, display, close)
		display = display:gsub("%-[^%]|]+", "", 1)
		return link .. display .. close
	end))
end

local function linkUrls(text)
	if not text:find("|H", 1, true) then
		return linkUrlsInPlainText(text)
	end

	local parts = {}
	local position = 1
	while true do
		local linkStart, linkEnd = text:find("|H.-|h.-|h", position)
		if not linkStart then
			break
		end
		parts[#parts + 1] = linkUrlsInPlainText(text:sub(position, linkStart - 1))
		parts[#parts + 1] = text:sub(linkStart, linkEnd)
		position = linkEnd + 1
	end
	parts[#parts + 1] = linkUrlsInPlainText(text:sub(position))
	return table.concat(parts)
end

StaticPopupDialogs.FROSTATOMUI_COPY_URL = {
	text = "Ctrl+C to copy",
	button1 = CLOSE,
	hasEditBox = true,
	editBoxWidth = 350,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(self)
		local editBox = _G[self:GetName() .. "EditBox"]
		editBox:SetText(self.url or "")
		editBox:SetFocus()
		editBox:HighlightText()
	end,
	EditBoxOnEnterPressed = function(self)
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}

local blizzardSetItemRef = SetItemRef
function SetItemRef(link, ...)
	local url = link:match("^url:(.+)$")
	if not url then
		return blizzardSetItemRef(link, ...)
	end

	local popup = StaticPopup_Show("FROSTATOMUI_COPY_URL")
	if popup then
		popup.url = url
		local editBox = _G[popup:GetName() .. "EditBox"]
		editBox:SetText(url)
		editBox:SetFocus()
		editBox:HighlightText()
	end
end

local MAX_LINES = 1000

Chat.lines = {}
local rawAddMessage = {}

local function storeLine(chatFrame, text, r, g, b)
	local lines = Chat.lines[chatFrame]
	lines[#lines + 1] = { text, r, g, b }
	if #lines > MAX_LINES then
		table.remove(lines, 1)
	end
end

function Chat.AddStoredLine(chatFrame, text, r, g, b)
	rawAddMessage[chatFrame](chatFrame, text, r, g, b)
	storeLine(chatFrame, text, r, g, b)
end

local function hookAddMessage(chatFrame)
	local addMessage = chatFrame.AddMessage
	rawAddMessage[chatFrame] = addMessage
	Chat.lines[chatFrame] = {}

	chatFrame.AddMessage = function(self, text, r, g, b, ...)
		if type(text) == "string" then
			text = date(TIMESTAMP_FORMAT) .. linkUrls(stripRealm(shortenChannelName(text)))
			storeLine(self, text, r, g, b)
		end
		return addMessage(self, text, r, g, b, ...)
	end
end

local TOOLTIP_LINK_TYPES = {
	item = true,
	spell = true,
	enchant = true,
	quest = true,
	achievement = true,
	talent = true,
	glyph = true,
}

local function onHyperlinkEnter(chatFrame, link)
	if TOOLTIP_LINK_TYPES[link:match("^(%a+):")] then
		GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end
end

local function onHyperlinkLeave()
	GameTooltip:Hide()
end

local function onMouseWheel(chatFrame, delta)
	if IsControlKeyDown() then
		if delta > 0 then
			chatFrame:ScrollToTop()
		else
			chatFrame:ScrollToBottom()
		end
	elseif delta > 0 then
		chatFrame:ScrollUp()
	else
		chatFrame:ScrollDown()
	end
end

local function hookMouseWheel(chatFrame)
	chatFrame:EnableMouseWheel(true)
	chatFrame:SetScript("OnMouseWheel", onMouseWheel)
end

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
	editBox.backdrop = backdrop
end

hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
	if not editBox.backdrop then
		return
	end

	local chatType = editBox:GetAttribute("chatType")
	if chatType == "CHANNEL" then
		local channel = editBox:GetAttribute("channelTarget")
		chatType = channel and channel ~= 0 and ("CHANNEL" .. channel) or nil
	end

	local info = chatType and ChatTypeInfo[chatType]
	if info then
		editBox.backdrop:SetBackdropBorderColor(info.r, info.g, info.b)
	else
		editBox.backdrop:SetBackdropBorderColor(1, 1, 1)
	end
end)

local function setupChatFrame(name)
	local chatFrame = _G[name]
	chatFrame:SetScript("OnUpdate", nil)
	chatFrame:SetTimeVisible(30)
	chatFrame:SetMaxLines(MAX_LINES)
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
	hookMouseWheel(chatFrame)
	chatFrame:SetScript("OnHyperlinkEnter", onHyperlinkEnter)
	chatFrame:SetScript("OnHyperlinkLeave", onHyperlinkLeave)
end

for i = 1, NUM_CHAT_WINDOWS do
	local name = "ChatFrame" .. i
	setupChatFrame(name)
	setupTab(name .. "Tab")
	setupEditBox(name .. "EditBox")
end
