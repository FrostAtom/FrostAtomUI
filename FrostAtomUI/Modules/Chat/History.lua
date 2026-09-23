local _, ns = ...

local gsub, find = string.gsub, string.find
local tconcat, tinsert, tremove = table.concat, table.insert, table.remove
local max = math.max

local Chat = ns:GetModule("Chat")
local config = ns.Config.chat

local COPY_FRAME_NAME = "FrostAtomUICopyChat"
local COPY_TEXT_MARGIN = 40
local COPY_ICON = [[Interface\Buttons\UI-GuildButton-PublicNote-Up]]
local COPY_BUTTON_ALPHA = 0.4

local commandHistory = {}

local function isOwnPrint(text)
	return find(text, ns.PRINT_PREFIX, 1, true) ~= nil
end

local function restoreHistory(db)
	local saved = db.chat_history
	if saved then
		for i = 1, #saved do
			local line = saved[i]
			if not isOwnPrint(line[1]) then
				Chat.AddStoredLine(ChatFrame1, line[1], line[2], line[3], line[4])
			end
		end
	end

	commandHistory = db.command_history or commandHistory
	db.command_history = commandHistory

	for i = #commandHistory, 1, -1 do
		ChatFrame1EditBox:AddHistoryLine(commandHistory[i])
	end
end

local function saveHistory()
	local count = Chat.NumLines(ChatFrame1)
	local saved = {}
	for i = max(1, count - config.savedHistoryLines + 1), count do
		local line = Chat.GetLine(ChatFrame1, i)
		if not isOwnPrint(line[1]) then
			saved[#saved + 1] = { line[1], line[2], line[3], line[4] }
		end
	end
	ns:SaveVariable("chat_history", saved)
end

local function editBoxCommand(editBox)
	local text = editBox:GetText()
	if text == "" then
		return
	end

	local chatType = editBox:GetAttribute("chatType")
	local header = _G["SLASH_" .. chatType .. "1"] or ""
	if chatType == "WHISPER" then
		header = header .. " " .. (editBox:GetAttribute("tellTarget") or "")
	elseif chatType == "CHANNEL" then
		header = "/" .. (editBox:GetAttribute("channelTarget") or "")
	end
	return header .. " " .. text
end

local function onHistoryLine(editBox)
	local command = editBoxCommand(editBox)
	if not command then
		return
	end

	ns.tDeleteItem(commandHistory, command)
	tinsert(commandHistory, 1, command)
	while #commandHistory > config.savedCommands do
		tremove(commandHistory)
	end
end

local function plainText(text)
	text = gsub(text, "|T.-|t", "")
	text = gsub(text, "|H.-|h(.-)|h", "%1")
	text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	return (gsub(text, "|r", ""))
end

local copyFrame

local function applyCopySize()
	if copyFrame then
		copyFrame:SetSize(config.copyWindowWidth, config.copyWindowHeight)
		copyFrame.editBox:SetWidth(config.copyWindowWidth - COPY_TEXT_MARGIN)
	end
end

local function createCopyFrame()
	local frame = CreateFrame("Frame", COPY_FRAME_NAME, UIParent)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetBackdrop(ns.CreateBackdrop(14, 3))
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:EnableMouse(true)
	frame:Hide()
	tinsert(UISpecialFrames, COPY_FRAME_NAME)

	local scroll = CreateFrame("ScrollFrame", COPY_FRAME_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -10)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)
	scroll:SetScript("OnScrollRangeChanged", function(self, _, range)
		if self.scrollToBottom then
			self.scrollToBottom = false
			self:SetVerticalScroll(range)
		end
	end)

	local editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	editBox:EnableMouseWheel(true)
	editBox:SetScript("OnMouseWheel", function(_, delta)
		ScrollFrameTemplate_OnMouseWheel(scroll, delta)
	end)
	scroll:SetScrollChild(editBox)

	frame.scroll = scroll
	frame.editBox = editBox
	copyFrame = frame
	applyCopySize()
end

local function copyChatFrame(chatFrame)
	if not Chat.lines[chatFrame] then
		return
	end
	if not copyFrame then
		createCopyFrame()
	end

	local text = {}
	for i = 1, Chat.NumLines(chatFrame) do
		text[i] = plainText(Chat.GetLine(chatFrame, i)[1])
	end

	local editBox = copyFrame.editBox
	editBox:SetText(tconcat(text, "\n"))
	copyFrame.scroll.scrollToBottom = true
	copyFrame:Show()
	editBox:SetFocus()
	editBox:HighlightText()
end

SlashCmdList.FROSTATOMUI_COPY = function()
	copyChatFrame(SELECTED_DOCK_FRAME or ChatFrame1)
end
SLASH_FROSTATOMUI_COPY1 = "/copy"

local function onCopyButtonEnter(self)
	self:SetAlpha(1)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("/copy")
	GameTooltip:Show()
end

local function onCopyButtonLeave(self)
	self:SetAlpha(COPY_BUTTON_ALPHA)
	GameTooltip:Hide()
end

local function onCopyButtonClick(self)
	copyChatFrame(self:GetParent())
end

Chat:OnInitialize(function(self)
	restoreHistory(ns.db)
	self:RegisterEvent("PLAYER_LOGOUT", saveHistory)
	self:WatchConfig("chat", applyCopySize)
	hooksecurefunc(ChatFrame1EditBox, "AddHistoryLine", onHistoryLine)

	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame" .. i]
		local copyButton = CreateFrame("Button", nil, chatFrame)
		copyButton:SetSize(16, 16)
		copyButton:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 4, 4)
		copyButton:SetFrameLevel(chatFrame:GetFrameLevel() + 5)
		copyButton:SetNormalTexture(COPY_ICON)
		copyButton:SetHighlightTexture(COPY_ICON)
		copyButton:SetAlpha(COPY_BUTTON_ALPHA)
		copyButton:SetScript("OnEnter", onCopyButtonEnter)
		copyButton:SetScript("OnLeave", onCopyButtonLeave)
		copyButton:SetScript("OnClick", onCopyButtonClick)
	end
end)
