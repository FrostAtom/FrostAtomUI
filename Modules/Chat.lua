local namespace = select(2,...)

local tDel,tNew,tContains,tWipe = namespace.tDel,namespace.tNew,namespace.tContains,namespace.tWipe
local ChatEdit_UpdateHeader = ChatEdit_UpdateHeader
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local SendSystemMessage = SendSystemMessage
local _G = _G
local CreateFrame = CreateFrame
local math = math


local Chat = namespace:New("Chat")
namespace:Get("CVars"):SetCVar("chatStyle","classic")



CombatLog_LoadUI = namespace.null
Blizzard_CombatLog_Update_QuickButtons = namespace.null
ChatConfigFrame:SetScript("OnShow",nil)


-- Mute Announcer
Chat:RegisterEvent("UI_ERROR_MESSAGE",function(self,message)
    if message:find("^You must wait .- before speaking again.$") then
        SendSystemMessage(message)
    end
end)







-- TellTarget
hooksecurefunc("ChatEdit_OnSpacePressed",function(self)
	if self:GetText():lower():find("^/[wt]t .-$") then
		if UnitIsPlayer("target") then
			local name,realm = UnitName("target")
			if name then
				if realm and realm ~= "" then
					name = ("%s-%s"):format(name,realm)
				end

				self:SetAttribute("tellTarget",name)
				self:SetAttribute("chatType","WHISPER")
				self.setText = 1
				self.text = ""
				self:SetFocus()

				ChatEdit_UpdateHeader(self)
			end
		end
	end
end)

-- Server Spam Filter
local spam = {
	"^|cffff0000%[BG Queue Announcer%]:|r",
}

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM",function(self,event,msg)
	for i = 1,#spam do
		if msg:match(spam[i]) then
			return true
		end
	end
end)


-- Pm Close
do
	local printf = namespace.printf
	local tremove = tremove


	local MSG_RESPONSE = "private messages closed"
	local MSG_RESPONSE_RU = "личные сообщения закрыты"


	local BLOCKED = false
	local blockedMessages
	local whiteList = {}


	local function isFriend(name)
		for i = 1,GetNumFriends() do
			if GetFriendInfo(i) == name then
				return true
			end
		end
	end

	local lastResponse,lastMessage = 0
	local function CHAT_MSG_WHISPER_filter(_,_,message,sender)
		if not (isFriend(sender) or whiteList[sender]) then
			local curTime = GetTime()
			if curTime-lastResponse > 0.25 then
				lastResponse = curTime

				SendChatMessage(message:find("[\208\209]") and MSG_RESPONSE_RU or MSG_RESPONSE ,"WHISPER",nil,sender)
			end

			if lastMessage ~= message then
				lastMessage = message

				blockedMessages[#blockedMessages+1] = ("%s (at %s): %s"):format(sender,date("%m/%d/%y %H:%M:%S"),message)
			end

			return true
		end
	end

	local function CHAT_MSG_WHISPER_INFORM_filter(_,_,message,target)
		if (message == MSG_RESPONSE) or (message == MSG_RESPONSE_RU) then
			return true
		end

		local value
		for i = #blockedMessages,1 do
			value = blockedMessages[i]
			if value then
				if value:match("^(%.+) ") == target then
					printf(tremove(blockedMessages,i))
				end
			else
				break
			end
		end
		whiteList[target] = true
	end

	local function toggleBlock(state)
		if state then
			ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",CHAT_MSG_WHISPER_filter)
			ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM",CHAT_MSG_WHISPER_INFORM_filter)

			printf("you are |cffff0000no longer receiving|r private messages")
		else
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER",CHAT_MSG_WHISPER_filter)
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM",CHAT_MSG_WHISPER_INFORM_filter)

			printf("you now |cff00ff00receive|r private messages")
		end
	end

	SlashCmdList["PMDISABLE"] = function()
		BLOCKED = not BLOCKED
		toggleBlock(BLOCKED)
		namespace:SaveVariable("pm_blocked",BLOCKED)

		while #blockedMessages ~= 0 do
			printf(tremove(blockedMessages,#blockedMessages):gsub("%%","%%%%"))
		end

		wipe(whiteList)
	end

	Chat:RegisterEvent("VariablesLoaded",function(self,db)
		BLOCKED = db["pm_blocked"]
		blockedMessages = db["pm_messages"]
		if not blockedMessages then
			blockedMessages = {}
			db["pm_messages"] = blockedMessages
		end

		if BLOCKED then
			toggleBlock(BLOCKED)
		end
	end)

	SLASH_PMDISABLE1 = "/pm"
end


-- Restyle
CHAT_FRAME_FADE_OUT_TIME = 0.5
CHAT_TAB_HIDE_DELAY = 0
CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = 1
CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0
CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA = 1
CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA = 1
CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA = 1
CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0

local BACKDROP = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 14,

	bgFile = "Interface\\Buttons\\WHITE8x8",
	insets = {
		top = 3,
		bottom = 3,
		left = 3,
		right = 3,
	}
}

ChatFrameMenuButton:Hide()
ChatFrameMenuButton:SetScript("OnShow",ChatFrameMenuButton.Hide)

FriendsMicroButton:SetPoint("BOTTOM",ChatFrame1,"TOPLEFT",8,4)
FriendsMicroButton:SetFrameLevel(ChatFrame1Tab:GetFrameLevel()+1)



--[[local channels = {
	["Guild"] = "[G]",
	["Officer"] = "[O]",
	["Party"] = "[P]",
	[PARTY_LEADER] = "PL",
}]]

local function setupBackdrop(chatFrame)
	local frame = CreateFrame("frame",nil,chatFrame)
	frame:SetFrameLevel(chatFrame:GetFrameLevel()-1)
	frame:SetPoint("TOPRIGHT",6,6)
	frame:SetPoint("BOTTOMLEFT",-6,-6)
	frame:SetBackdrop(BACKDROP)
	frame:SetBackdropColor(0,0,0,0.6)
end

local function setupTab(name)
	local tab = _G[name]

	_G[name.."Left"]:Hide()
	_G[name.."Middle"]:Hide()
	_G[name.."Right"]:Hide()
	tab.leftSelectedTexture:SetAlpha(0)
	tab.rightSelectedTexture:SetAlpha(0)
	tab.middleSelectedTexture:SetAlpha(0)
	tab.leftHighlightTexture:SetTexture(nil)
	tab.rightHighlightTexture:SetTexture(nil)
	tab.middleHighlightTexture:SetTexture([[BUTTONS\CheckButtonGlow]])
	tab.middleHighlightTexture:SetWidth(76)
	tab.middleHighlightTexture:SetTexCoord(0, 0, 1, 0.5)
	tab.leftSelectedTexture:SetAlpha(0)
	tab.rightSelectedTexture:SetAlpha(0)
	tab.middleSelectedTexture:SetAlpha(0)
end

local function setupEditBox(name)
	local editBox = _G[name]
	editBox:SetAltArrowKeyMode(false)
	--editBox:SetFont("Fonts\\ARIALN.TTF",12,"OUTLINE")
	
	_G[name.."Left"]:Hide()
	_G[name.."Right"]:Hide()
	_G[name.."Mid"]:Hide()
	editBox.focusLeft:SetTexture(nil)
	editBox.focusRight:SetTexture(nil)
	editBox.focusMid:SetTexture(nil)
	editBox:Hide()

	local bgFrame = CreateFrame("frame",nil,editBox)
	bgFrame:SetFrameLevel(editBox:GetFrameLevel()-1)
	bgFrame:SetPoint("TOPRIGHT",0,-4)
	bgFrame:SetPoint("BOTTOMLEFT",0,4)
	bgFrame:SetBackdrop(BACKDROP)
	bgFrame:SetBackdropColor(0,0,0,0.6)
end

local function cleanupBlizzard(name)
	_G[name.."RightTexture"]:Hide()
	_G[name.."LeftTexture"]:Hide()
	_G[name.."TopTexture"]:Hide()
	_G[name.."BottomTexture"]:Hide()
	_G[name.."TopLeftTexture"]:Hide()
	_G[name.."BottomLeftTexture"]:Hide()
	_G[name.."TopRightTexture"]:Hide()
	_G[name.."BottomRightTexture"]:Hide()

	_G[name.."Background"]:Hide()
end

local name,chatFrame,chatFrameButtons
for i = 1,NUM_CHAT_WINDOWS do
	name = "ChatFrame"..i

	chatFrameButtons = _G[name.."ButtonFrame"]
	chatFrameButtons:Hide()
	chatFrameButtons:SetScript("OnShow",chatFrameButtons.Hide)

	chatFrame = _G[name]
	chatFrame:SetScript("OnUpdate",nil)
	chatFrame:SetTimeVisible(30)

	chatFrame:SetShadowOffset(0,0)
	chatFrame:SetClampRectInsets(-7,-7,-7,-31)

	cleanupBlizzard(name)
	setupBackdrop(chatFrame)
	setupTab(name.."Tab")
	setupEditBox(name.."EditBox")
end