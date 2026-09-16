local _, ns = ...

local CreateFrame = CreateFrame

local Chat = ns:GetModule("Chat")

local SAVED_LINES = 100
local DIVIDER = "|cff7f7f7f" .. ("-"):rep(60) .. "|r"

local COPY_FRAME_NAME = "FrostAtomUICopyChat"
local COPY_WIDTH, COPY_HEIGHT = 520, 380

Chat:RegisterEvent(ns.DB_LOADED, function(_, db)
	local saved = db.chat_history
	if not saved or #saved == 0 then
		return
	end
	for _, line in ipairs(saved) do
		Chat.AddStoredLine(ChatFrame1, line[1], line[2], line[3], line[4])
	end
	Chat.AddStoredLine(ChatFrame1, DIVIDER)
end)

Chat:RegisterEvent("PLAYER_LOGOUT", function()
	local lines = Chat.lines[ChatFrame1]
	local saved = {}
	for i = math.max(1, #lines - SAVED_LINES + 1), #lines do
		if lines[i][1] ~= DIVIDER then
			saved[#saved + 1] = lines[i]
		end
	end
	ns:SaveVariable("chat_history", saved)
end)

local function plainText(text)
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return text
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

	local chatFrame = SELECTED_DOCK_FRAME or ChatFrame1
	local text = {}
	for i, line in ipairs(Chat.lines[chatFrame]) do
		text[i] = plainText(line[1])
	end

	local editBox = copyFrame.editBox
	editBox:SetText(table.concat(text, "\n"))
	copyFrame.scroll.scrollToBottom = true
	copyFrame:Show()
	editBox:SetFocus()
	editBox:HighlightText()
end
SLASH_FROSTATOMUI_COPY1 = "/copy"
