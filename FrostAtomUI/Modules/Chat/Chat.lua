local _, ns = ...

local ChatEdit_UpdateHeader = ChatEdit_UpdateHeader
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local SendSystemMessage = SendSystemMessage
local IsControlKeyDown = IsControlKeyDown
local StaticPopup_Show = StaticPopup_Show
local GameTooltip = GameTooltip
local IsInInstance = IsInInstance
local GetTime = GetTime
local date = date
local find, match, gsub, format, lower, sub =
	string.find, string.match, string.gsub, string.format, string.lower, string.sub
local tconcat = table.concat
local max = math.max

local Chat = ns:NewModule("Chat")
Chat.configKey = "chat"
local config = ns.Config.chat

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

local blizzardSticky = {}

local function applySticky()
	for i = 1, #STICKY_TYPES do
		local info = ChatTypeInfo[STICKY_TYPES[i]]
		if info then
			info.sticky = config.stickyChannels and 1 or blizzardSticky[STICKY_TYPES[i]]
		end
	end
end

local function applyClassColors()
	for chatType, info in pairs(ChatTypeInfo) do
		if (info.colorNameByClass and true or false) ~= config.classColorNames then
			SetChatColorNameByClass(chatType, config.classColorNames)
		end
	end
end

local chatBackdrops = {}
local dockRails = {}
local tabs = {}
local fader, tabFader
local updateTabColors, chatInsets

local function applyPosition()
	ns.ApplyPoint(ChatFrame1, "chat.point")
	ChatFrame1:SetSize(config.width, config.height)
end

local function applyFrameConfig()
	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame" .. i]
		chatFrame:SetFading(config.fadeMessages)
		chatFrame:SetTimeVisible(config.fadeTime)
	end
	for i = 1, #chatBackdrops do
		chatBackdrops[i]:SetBackdropColor(0, 0, 0, config.backgroundAlpha)
	end
	for i = 1, #tabs do
		updateTabColors(tabs[i])
	end
	fader:Configure(config.mouseover, config.fadeAlpha)
	applyPosition()
end

local blizzardAddButton = UIDropDownMenu_AddButton

local function addButtonWithoutLock(info, level)
	if info.text ~= LOCK_WINDOW and info.text ~= UNLOCK_WINDOW then
		blizzardAddButton(info, level)
	end
end

local function initializeTabDropDown(...)
	UIDropDownMenu_AddButton = addButtonWithoutLock
	FCFOptionsDropDown_Initialize(...)
	UIDropDownMenu_AddButton = blizzardAddButton
end

local function lockChatFrames()
	FCF_ToggleLock = ns.noop
	for i = 1, NUM_CHAT_WINDOWS do
		local name = "ChatFrame" .. i
		local chatFrame = _G[name]
		FCF_SetLocked(chatFrame, 1)

		local tab = _G[name .. "Tab"]
		tab:RegisterForDrag()
		tab:SetScript("OnDragStart", nil)
		tab:SetScript("OnDragStop", nil)
		_G[name .. "TabDropDown"].initialize = initializeTabDropDown

		local resizeButton = _G[name .. "ResizeButton"]
		resizeButton:Hide()
		resizeButton:SetScript("OnShow", resizeButton.Hide)
	end
	hooksecurefunc("FCF_RestorePositionAndDimensions", function(chatFrame)
		if chatFrame == ChatFrame1 then
			applyPosition()
		end
	end)
end

function Chat:Initialize()
	ns:GetModule("CVars"):Pin("chatStyle", "classic")
	self:HookMessages()
	if config.skin then
		self:Skin()
	end
	if config.lockFrames then
		lockChatFrames()
	end
	applyClassColors()
	local function isTyping()
		return ChatFrame1EditBox:IsShown()
	end
	local hover = { ChatFrame1, ChatFrame1EditBox }
	for i = 1, #tabs do
		hover[#hover + 1] = tabs[i]
	end
	fader = ns.CreateFader({ ChatFrame1 }, hover, isTyping)
	if config.skin then
		tabFader = ns.CreateFader(tabs, hover, isTyping, dockRails)
		tabFader:Configure(true, 0)
	end
	applyFrameConfig()
	for i = 1, #STICKY_TYPES do
		local info = ChatTypeInfo[STICKY_TYPES[i]]
		if info then
			blizzardSticky[STICKY_TYPES[i]] = info.sticky
		end
	end
	applySticky()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", applyClassColors)
	self:WatchConfig("chat", applyClassColors)
	self:WatchConfig("chat", applyFrameConfig)
	self:WatchConfig("chat.stickyChannels", applySticky)
	self:RegisterMover(ChatFrame1, "chat.point", "Chat", {
		insets = chatInsets,
		resize = {
			minWidth = 200,
			maxWidth = 1200,
			minHeight = 60,
			maxHeight = 800,
			get = function()
				return config.width, config.height
			end,
			set = function(width, height)
				ns:SetConfig("chat.width", width)
				ns:SetConfig("chat.height", height)
			end,
		},
	})
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

local function onErrorMessage(_, message)
	if find(message, "^You must wait .- before speaking again.$") then
		SendSystemMessage(message)
	end
end

local function switchChatType(editBox, chatType, tellTarget)
	editBox:SetAttribute("tellTarget", tellTarget)
	editBox:SetAttribute("chatType", chatType)
	editBox.setText = 1
	editBox.text = ""
	editBox:SetFocus()
	ChatEdit_UpdateHeader(editBox)
end

local function onSpacePressed(editBox)
	local text = lower(editBox:GetText())

	if text == "/gr " then
		switchChatType(editBox, groupChatType())
		return
	end

	if not find(text, "^/[wt]t ") or not UnitIsPlayer("target") then
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
end

local SYSTEM_SPAM = {
	"^|cffff0000%[BG Queue Announcer%]:|r",
	"wowcircle%.net",
	"control panel at our website",
	"Speeding up the battle start",
	"/join english",
}

local function formatToPattern(text)
	return "^" .. gsub(gsub(text, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"), "%%%%[sd]", "(.-)") .. "$"
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
	formatToPattern(ERR_NEW_LEADER_YOU),
	formatToPattern(ERR_NEW_LEADER_S),
	"^%S+ has joined the battle%.?$",
	"^One minute until the Arena battle begins!$",
	"^Thirty seconds until the Arena battle begins!$",
	"^Fifteen seconds until the Arena battle begins!$",
	"^The Arena battle has begun!$",
	"^Speeding up the battle start! Players ready: %d+%.$",
	"^You are in Spectator Mode%. ",
	"^The %a+ Team wins!$",
}

local wasInArena, arenaLeftAt = false, 0

Chat:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local inArena = select(2, IsInInstance()) == "arena"
	if wasInArena and not inArena then
		arenaLeftAt = GetTime()
	end
	wasInArena = inArena
end)

local function matchesAny(message, patterns)
	for i = 1, #patterns do
		if find(message, patterns[i]) then
			return true
		end
	end
	return false
end

local function isArenaSpam(message)
	if not config.filterArenaSpam or (not wasInArena and GetTime() - arenaLeftAt > 10) then
		return false
	end
	return matchesAny(message, ARENA_SPAM)
end

local QUEUE_ICON = "|TInterface\\Icons\\%s:14:14:0:0:64:64:4:60:4:60|t"
local QUEUE_MELEE = format(QUEUE_ICON, "Ability_MeleeDamage")
local QUEUE_RANGED = format(QUEUE_ICON, "Ability_Marksmanship")
local QUEUE_HEALER = format(QUEUE_ICON, "Spell_Holy_Renew")
local QUEUE_GROUPS = format(QUEUE_ICON, "Achievement_PVP_A_A")
local QUEUE_ON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local QUEUE_OFF = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t"

local QUEUE_COUNT_PATTERNS = {
	{ "^Number of groups in queue Arena 3v3 %(Solo%): (%d+)$", "groups" },
	{ "^Melee classes: (%d+)$", "melee" },
	{ "^Ranged classes: (%d+)$", "ranged" },
	{ "^Healers: (%d+)$", "healers" },
}
local QUEUE_MIXED_PATTERN = "^Possibility of selecting a mixed arena team %(ignoring specializations%): (%a+)$"
local QUEUE_SEARCHING_PATTERN = "^We are looking for the best team for you on the selection rating %[(%d+)%-(%d+)%]$"
local QUEUE_TEAM_FOUND_PATTERN =
	"^Team to fight found! Team rating (%d+), looking for suitable opponents on the rating %[(%d+)%-(%d+)%]$"

ns.SOLOQ_SEARCHING = "FrostAtomUI_SOLOQ_SEARCHING"

local queueCounts = {}

local function filterQueueSpam(message)
	for i = 1, #QUEUE_COUNT_PATTERNS do
		local entry = QUEUE_COUNT_PATTERNS[i]
		local count = match(message, entry[1])
		if count then
			queueCounts[entry[2]] = count
			return true
		end
	end

	local mixed = match(message, QUEUE_MIXED_PATTERN)
	if mixed then
		local text = format(
			"%s %s  %s %s  %s %s  %s %s  %s",
			QUEUE_GROUPS,
			queueCounts.groups or "?",
			QUEUE_MELEE,
			queueCounts.melee or "?",
			QUEUE_RANGED,
			queueCounts.ranged or "?",
			QUEUE_HEALER,
			queueCounts.healers or "?",
			mixed == "enabled" and QUEUE_ON or QUEUE_OFF
		)
		wipe(queueCounts)
		return false, text
	end

	local low, high = match(message, QUEUE_SEARCHING_PATTERN)
	if low then
		ns:Fire(ns.SOLOQ_SEARCHING, tonumber(low), tonumber(high))
		return true
	end

	local teamRating
	teamRating, low, high = match(message, QUEUE_TEAM_FOUND_PATTERN)
	if teamRating then
		low, high = tonumber(low), tonumber(high)
		ns:Fire(ns.SOLOQ_SEARCHING, low, high, tonumber(teamRating))
		return false,
			format(
				"Team found (%s), searching opponents: %d |cff7f7f7f[%d-%d]|r",
				teamRating,
				(low + high) / 2,
				low,
				high
			)
	end
end

local function filterSystem(_, _, message, ...)
	if (config.filterSystemSpam and matchesAny(message, SYSTEM_SPAM)) or isArenaSpam(message) then
		return true
	end

	local filtered, newMessage = filterQueueSpam(message)
	if filtered then
		return true
	elseif newMessage then
		return false, newMessage, ...
	end
end

local function filterBgSystem(_, _, message)
	return isArenaSpam(message)
end

local function filterTargetIcons()
	return wasInArena and config.filterArenaSpam
end

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

local blizzardGets = {}

local function applyChannelGets()
	for key, value in pairs(CHANNEL_GETS) do
		_G[key] = config.shortChannelNames and value or blizzardGets[key]
	end
end

local TIMESTAMP_COLOR = "|cff7f7f7f"

local function shortenChannelName(text)
	if not config.shortChannelNames then
		return text
	end
	return (gsub(text, "%[(%d+)%. [^%]]+%]", "[%1]", 1))
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
for tld in
	("com net org ru su ua by kz eu de fr uk io gg tv me co info biz dev app xyz pro club online site live"):gmatch(
		"%S+"
	)
do
	URL_TLDS[tld] = true
end

local linkedAny = false

local function linkUrl(url, tld)
	if tld and not URL_TLDS[lower(tld)] then
		return
	end
	linkedAny = true
	return format(URL_LINK, url, url)
end

local function linkUrlsInPlainText(text)
	if not find(text, ".", 1, true) then
		return text
	end
	for i = 1, #URL_PATTERNS do
		linkedAny = false
		local linked = gsub(text, URL_PATTERNS[i], linkUrl)
		if linkedAny then
			return linked
		end
	end
	return text
end

local function stripRealmFromLink(link, display, close)
	return link .. gsub(display, "%-[^%]|]+", "", 1) .. close
end

local function stripRealm(text)
	if not config.stripRealm or not find(text, "|Hplayer:[^|]*%-") then
		return text
	end
	return (gsub(text, "(|Hplayer:[^|]*%-[^|]*|h)(.-)(|h)", stripRealmFromLink))
end

local urlParts = {}

local function linkUrls(text)
	if not config.urlLinks then
		return text
	end
	if not find(text, "|H", 1, true) then
		return linkUrlsInPlainText(text)
	end

	wipe(urlParts)
	local position = 1
	while true do
		local linkStart, linkEnd = find(text, "|H.-|h.-|h", position)
		if not linkStart then
			break
		end
		urlParts[#urlParts + 1] = linkUrlsInPlainText(sub(text, position, linkStart - 1))
		urlParts[#urlParts + 1] = sub(text, linkStart, linkEnd)
		position = linkEnd + 1
	end
	urlParts[#urlParts + 1] = linkUrlsInPlainText(sub(text, position))
	return tconcat(urlParts)
end

local function focusEditBoxText(popup, url)
	local editBox = _G[popup:GetName() .. "EditBox"]
	editBox:SetText(url)
	editBox:SetFocus()
	editBox:HighlightText()
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
		focusEditBoxText(self, self.url or "")
	end,
	EditBoxOnEnterPressed = function(self)
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}

local blizzardSetItemRef

local function setItemRef(link, ...)
	local url = match(link, "^url:(.+)$")
	if not url then
		return blizzardSetItemRef(link, ...)
	end

	local popup = StaticPopup_Show("FROSTATOMUI_COPY_URL")
	if popup then
		popup.url = url
		focusEditBoxText(popup, url)
	end
end

local maxLines = 1000

Chat.lines = {}
local rawAddMessage = {}

local function storeLine(chatFrame, text, r, g, b)
	local lines = Chat.lines[chatFrame]
	local count = lines.count
	local slot
	if count < maxLines then
		count = count + 1
		lines.count = count
		slot = count
	else
		slot = lines.head
		lines.head = slot % maxLines + 1
	end
	local line = lines[slot]
	if not line then
		line = {}
		lines[slot] = line
	end
	line[1], line[2], line[3], line[4] = text, r, g, b
end

function Chat.NumLines(chatFrame)
	return Chat.lines[chatFrame].count
end

function Chat.GetLine(chatFrame, index)
	local lines = Chat.lines[chatFrame]
	return lines[(lines.head + index - 2) % maxLines + 1]
end

function Chat.AddStoredLine(chatFrame, text, r, g, b)
	rawAddMessage[chatFrame](chatFrame, text, r, g, b)
	storeLine(chatFrame, text, r, g, b)
end

local function hookAddMessage(chatFrame)
	local addMessage = chatFrame.AddMessage
	rawAddMessage[chatFrame] = addMessage
	Chat.lines[chatFrame] = { head = 1, count = 0 }

	chatFrame.AddMessage = function(self, text, r, g, b, ...)
		if type(text) == "string" then
			text = linkUrls(stripRealm(shortenChannelName(text)))
			if config.timestamps then
				text = TIMESTAMP_COLOR .. date(config.timestampFormat) .. "|r " .. text
			end
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
	if TOOLTIP_LINK_TYPES[match(link, "^(%a+):")] then
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

local BACKDROP = ns.CreateBackdrop(14, 3)
local FRIENDS_ICON = [[Interface\FriendsFrame\UI-Toast-FriendOnlineIcon]]
local TAB_HEIGHT = 21
local TAB_INACTIVE_ALPHA = 0.45
local TAB_ACTIVE_COLOR = { 1, 1, 1 }
local TAB_INACTIVE_COLOR = { 0.55, 0.55, 0.55 }
local PANEL_INSET = 6
local BORDER_BAND = BACKDROP.edgeSize
local MIN_FONT_SIZE = 8
local MAX_FONT_SIZE = 24

function chatInsets()
	if not config.skin then
		return 0, 0, 0, 0
	end
	local tab = ChatFrame1Tab
	local top = 0
	if tab:IsShown() and tab:GetBottom() and ChatFrame1:GetTop() then
		top = max(tab:GetBottom() + TAB_HEIGHT - ChatFrame1:GetTop(), 0)
	end
	return PANEL_INSET, PANEL_INSET, top, PANEL_INSET
end

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
	backdrop:SetBackdropColor(0, 0, 0, config.backgroundAlpha)
	chatBackdrops[#chatBackdrops + 1] = backdrop
	return backdrop
end

local function createClipped(parent, level)
	local clip = CreateFrame("ScrollFrame", nil, parent)
	clip:SetFrameLevel(level > 0 and level or 0)
	local backdrop = CreateFrame("Frame", nil, clip)
	backdrop:SetBackdrop(BACKDROP)
	backdrop:SetBackdropColor(0, 0, 0, config.backgroundAlpha)
	clip:SetScrollChild(backdrop)
	clip.backdrop = backdrop
	chatBackdrops[#chatBackdrops + 1] = backdrop
	return clip
end

local function layoutPanel(clip)
	local width, height = clip:GetWidth(), clip:GetHeight()
	if width < 1 or height < 1 then
		return
	end
	clip.backdrop:SetSize(width, height + BORDER_BAND)
	clip:SetVerticalScroll(BORDER_BAND)
end

local function layoutRail(clip)
	local width = clip:GetWidth()
	if width < 1 then
		return
	end
	clip.backdrop:SetSize(width + BORDER_BAND, BORDER_BAND * 3)
	clip:SetHorizontalScroll(clip.clipLeft and BORDER_BAND or 0)
end

local function edgeTabs(chatFrame)
	local docked = FCFDock_GetChatFrames(GeneralDockManager)
	local own = _G[chatFrame:GetName() .. "Tab"]
	local first, last
	for i = 1, #docked do
		if docked[i] == chatFrame then
			for j = 1, #docked do
				local tab = _G[docked[j]:GetName() .. "Tab"]
				if tab:IsShown() then
					if not first or tab:GetLeft() < first:GetLeft() then
						first = tab
					end
					if not last or tab:GetRight() > last:GetRight() then
						last = tab
					end
				end
			end
			return first, last
		end
	end
	if own:IsShown() then
		return own, own
	end
end

local function updateRail(chatFrame)
	local rail, dockRail = chatFrame.rail, chatFrame.dockRail
	if not rail then
		return
	end
	local first, last = edgeTabs(chatFrame)
	for i = 1, #tabs do
		local tab = tabs[i]
		tab.clip:SetPoint("TOPLEFT", tab == first and -PANEL_INSET or 0, -(tab:GetHeight() - TAB_HEIGHT))
	end
	rail:ClearAllPoints()
	rail:SetHeight(BORDER_BAND)
	rail:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", PANEL_INSET, BORDER_BAND)
	rail.clipLeft = last ~= nil
	if last then
		rail:SetPoint("LEFT", last, "RIGHT")
		dockRail:ClearAllPoints()
		dockRail:SetHeight(BORDER_BAND)
		dockRail:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -PANEL_INSET, BORDER_BAND)
		dockRail:SetPoint("RIGHT", last, "RIGHT")
		dockRail:Show()
	else
		rail:SetPoint("LEFT", chatFrame, "LEFT", -PANEL_INSET, 0)
		dockRail:Hide()
	end
	layoutRail(rail)
	layoutRail(dockRail)
end

local function updateRails()
	for i = 1, NUM_CHAT_WINDOWS do
		updateRail(_G["ChatFrame" .. i])
	end
end

function updateTabColors(tab, selected)
	if not tab.backdrop then
		return
	end
	if selected == nil then
		selected = SELECTED_DOCK_FRAME == tab.chatFrame
	end
	tab.backdrop:SetBackdropColor(0, 0, 0, config.backgroundAlpha)
	tab.backdrop:SetBackdropBorderColor(1, 1, 1, selected and 1 or TAB_INACTIVE_ALPHA)
	tab:GetFontString():SetTextColor(unpack(selected and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR))
end

local function layoutTab(tab)
	local width, height = tab.clip:GetWidth(), tab.clip:GetHeight()
	if width < 1 or height < 1 then
		return
	end
	tab.backdrop:SetSize(width, height + BORDER_BAND)
end

local function setupTab(name)
	local tab = _G[name]

	hideRegions(name, "Left", "Middle", "Right")
	tab.leftSelectedTexture:SetAlpha(0)
	tab.rightSelectedTexture:SetAlpha(0)
	tab.middleSelectedTexture:SetAlpha(0)
	tab.leftHighlightTexture:SetTexture(nil)
	tab.rightHighlightTexture:SetTexture(nil)
	tab.middleHighlightTexture:SetTexture(nil)

	tab.chatFrame = _G[name:gsub("Tab$", "")]

	local clip = createClipped(tab, tab:GetFrameLevel() - 1)
	clip:SetPoint("TOPLEFT", 0, -(tab:GetHeight() - TAB_HEIGHT))
	clip:SetPoint("RIGHT")
	clip:SetPoint("BOTTOM", tab.chatFrame.panel, "TOP")

	tab.clip, tab.backdrop = clip, clip.backdrop
	layoutTab(tab)
	tab:HookScript("OnSizeChanged", updateRails)
	clip:SetScript("OnSizeChanged", function()
		layoutTab(tab)
	end)

	local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture(1, 1, 1, 0.08)
	highlight:SetPoint("TOPLEFT", clip, "TOPLEFT")
	highlight:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT")

	tabs[#tabs + 1] = tab
	updateTabColors(tab)
end

local function setupEditBox(name, chatFrame)
	local editBox = _G[name]
	editBox:SetAltArrowKeyMode(false)
	editBox:Hide()
	editBox:ClearAllPoints()
	editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -6, -2)
	editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 6, -2)

	hideRegions(name, "Left", "Right", "Mid")
	editBox.focusLeft:SetTexture(nil)
	editBox.focusRight:SetTexture(nil)
	editBox.focusMid:SetTexture(nil)

	local backdrop = addBackdrop(editBox, 0)
	backdrop:SetPoint("TOPRIGHT", 0, -4)
	backdrop:SetPoint("BOTTOMLEFT", 0, 4)
	editBox.backdrop = backdrop
end

local function onUpdateHeader(editBox)
	local backdrop = editBox.backdrop
	if not backdrop then
		return
	end

	local chatType = editBox:GetAttribute("chatType")
	if chatType == "CHANNEL" then
		local channel = editBox:GetAttribute("channelTarget")
		chatType = channel and channel ~= 0 and ("CHANNEL" .. channel) or nil
	end

	local info = chatType and ChatTypeInfo[chatType]
	if info then
		backdrop:SetBackdropBorderColor(info.r, info.g, info.b)
	else
		backdrop:SetBackdropBorderColor(1, 1, 1)
	end
end

local function skinChatFrame(name)
	local chatFrame = _G[name]
	chatFrame:SetScript("OnUpdate", nil)
	chatFrame:SetFading(config.fadeMessages)
	chatFrame:SetTimeVisible(config.fadeTime)
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

	local level = chatFrame:GetFrameLevel() - 1
	local panel = createClipped(chatFrame, level)
	panel:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", PANEL_INSET, 0)
	panel:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", -PANEL_INSET, -PANEL_INSET)
	panel:SetScript("OnSizeChanged", layoutPanel)
	layoutPanel(panel)

	local rail = createClipped(chatFrame, level)
	rail:SetScript("OnSizeChanged", layoutRail)

	local dockRail = createClipped(chatFrame, level)
	dockRail:SetScript("OnSizeChanged", layoutRail)
	dockRails[#dockRails + 1] = dockRail

	chatFrame.panel, chatFrame.rail, chatFrame.dockRail = panel, rail, dockRail
	updateRail(chatFrame)
end

function Chat:HookMessages()
	CombatLog_LoadUI = ns.noop
	Blizzard_CombatLog_Update_QuickButtons = ns.noop
	ChatConfigFrame:SetScript("OnShow", nil)
	wipe(CHAT_FONT_HEIGHTS)
	for size = MIN_FONT_SIZE, MAX_FONT_SIZE do
		CHAT_FONT_HEIGHTS[#CHAT_FONT_HEIGHTS + 1] = size
	end
	self:RegisterEvent("UI_ERROR_MESSAGE", onErrorMessage)
	hooksecurefunc("ChatEdit_OnSpacePressed", onSpacePressed)
	hooksecurefunc("ChatEdit_UpdateHeader", onUpdateHeader)

	for key in pairs(CHANNEL_GETS) do
		blizzardGets[key] = _G[key]
	end
	applyChannelGets()
	self:WatchConfig("chat.shortChannelNames", applyChannelGets)

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filterSystem)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BG_SYSTEM_NEUTRAL", filterBgSystem)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_TARGETICONS", filterTargetIcons)

	blizzardSetItemRef = SetItemRef
	SetItemRef = setItemRef

	maxLines = config.maxLines
	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame" .. i]
		chatFrame:SetMaxLines(maxLines)
		hookAddMessage(chatFrame)
		chatFrame:EnableMouseWheel(true)
		chatFrame:SetScript("OnMouseWheel", onMouseWheel)
		chatFrame:SetScript("OnHyperlinkEnter", onHyperlinkEnter)
		chatFrame:SetScript("OnHyperlinkLeave", onHyperlinkLeave)
	end
end

function Chat:Skin()
	CHAT_FRAME_FADE_OUT_TIME = 0.5
	CHAT_TAB_HIDE_DELAY = 0
	CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = 1
	CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0
	CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA = 1
	CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA = 1
	CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA = 1
	CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0

	ChatFrameMenuButton:Hide()
	ChatFrameMenuButton:SetScript("OnShow", ChatFrameMenuButton.Hide)

	FriendsMicroButton:SetParent(ChatFrame1)
	FriendsMicroButton:ClearAllPoints()
	FriendsMicroButton:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", -4, 4)
	FriendsMicroButton:SetSize(24, 24)
	FriendsMicroButton:SetFrameLevel(ChatFrame1:GetFrameLevel() + 5)
	FriendsMicroButton:SetNormalTexture(FRIENDS_ICON)
	FriendsMicroButton:SetPushedTexture(FRIENDS_ICON)
	FriendsMicroButton:SetHighlightTexture(FRIENDS_ICON)
	FriendsMicroButton:GetNormalTexture():SetTexCoord(0.15, 0.85, 0.15, 0.85)
	FriendsMicroButton:GetPushedTexture():SetTexCoord(0.15, 0.85, 0.15, 0.85)
	FriendsMicroButton:GetHighlightTexture():SetTexCoord(0.15, 0.85, 0.15, 0.85)
	FriendsMicroButton:SetAlpha(0.7)
	FriendsMicroButton:HookScript("OnEnter", function(self)
		self:SetAlpha(1)
	end)
	FriendsMicroButton:HookScript("OnLeave", function(self)
		self:SetAlpha(0.7)
	end)
	FriendsMicroButtonCount:Hide()

	for i = 1, NUM_CHAT_WINDOWS do
		local name = "ChatFrame" .. i
		skinChatFrame(name)
		setupTab(name .. "Tab")
		setupEditBox(name .. "EditBox", _G[name])
	end
	hooksecurefunc("FCFTab_UpdateColors", updateTabColors)
	hooksecurefunc("FCFDock_UpdateTabs", updateRails)
	updateRails()
end
