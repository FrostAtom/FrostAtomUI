local _, ns = ...

local CreateFrame = CreateFrame
local gsub = string.gsub
local tconcat, tinsert, tremove = table.concat, table.insert, table.remove
local max = math.max

local Chat = ns:GetModule("Chat")

local SAVED_LINES = 100
local SAVED_COMMANDS = 50
local DIVIDER = "|cff7f7f7f" .. ("-"):rep(60) .. "|r"

local COPY_FRAME_NAME = "FrostAtomUICopyChat"
local COPY_WIDTH, COPY_HEIGHT = 520, 380

local commandHistory = {}

Chat:RegisterEvent(ns.DB_LOADED, function(_, db)
	local saved = db.chat_history
	if saved and #saved > 0 then
		for i = 1, #saved do
			local line = saved[i]
			Chat.AddStoredLine(ChatFrame1, line[1], line[2], line[3], line[4])
		end
		Chat.AddStoredLine(ChatFrame1, DIVIDER)
	end

	commandHistory = db.command_history or commandHistory
	db.command_history = commandHistory

	for i = #commandHistory, 1, -1 do
		ChatFrame1EditBox:AddHistoryLine(commandHistory[i])
	end
end)

Chat:RegisterEvent("PLAYER_LOGOUT", function()
	local lines = Chat.lines[ChatFrame1]
	local saved = {}
	for i = max(1, #lines - SAVED_LINES + 1), #lines do
		if lines[i][1] ~= DIVIDER then
			saved[#saved + 1] = lines[i]
		end
	end
	ns:SaveVariable("chat_history", saved)
end)

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

hooksecurefunc(ChatFrame1EditBox, "AddHistoryLine", function(editBox)
	local command = editBoxCommand(editBox)
	if not command then
		return
	end

	ns.tDeleteItem(commandHistory, command)
	tinsert(commandHistory, 1, command)
	while #commandHistory > SAVED_COMMANDS do
		tremove(commandHistory)
	end
end)

local function plainText(text)
	text = gsub(text, "|T.-|t", "")
	text = gsub(text, "|H.-|h(.-)|h", "%1")
	text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	return (gsub(text, "|r", ""))
end

local copyFrame

local function createCopyFrame()
	local frame = CreateFrame("Frame", COPY_FRAME_NAME, UIParent)
	frame:SetSize(COPY_WIDTH, COPY_HEIGHT)
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
	editBox:SetWidth(COPY_WIDTH - 40)
	editBox:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(editBox)

	frame.scroll = scroll
	frame.editBox = editBox
	return frame
end

SlashCmdList.FROSTATOMUI_COPY = function()
	copyFrame = copyFrame or createCopyFrame()

	local lines = Chat.lines[SELECTED_DOCK_FRAME or ChatFrame1]
	local text = {}
	for i = 1, #lines do
		text[i] = plainText(lines[i][1])
	end

	local editBox = copyFrame.editBox
	editBox:SetText(tconcat(text, "\n"))
	copyFrame.scroll.scrollToBottom = true
	copyFrame:Show()
	editBox:SetFocus()
	editBox:HighlightText()
end
SLASH_FROSTATOMUI_COPY1 = "/copy"

local copyButton = CreateFrame("Button", nil, ChatFrame1)
copyButton:SetSize(16, 16)
copyButton:SetPoint("TOPRIGHT", ChatFrame1, "TOPRIGHT", 4, 4)
copyButton:SetFrameLevel(ChatFrame1:GetFrameLevel() + 5)
copyButton:SetNormalTexture([[Interface\Buttons\UI-GuildButton-PublicNote-Up]])
copyButton:SetHighlightTexture([[Interface\Buttons\UI-GuildButton-PublicNote-Up]])
copyButton:SetAlpha(0.4)
copyButton:SetScript("OnEnter", function(self)
	self:SetAlpha(1)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("/copy")
	GameTooltip:Show()
end)
copyButton:SetScript("OnLeave", function(self)
	self:SetAlpha(0.4)
	GameTooltip:Hide()
end)
copyButton:SetScript("OnClick", SlashCmdList.FROSTATOMUI_COPY)
