local namespace = select(2,...)
local misc = namespace:New("misc")
local printf = namespace.printf


local tonumber = tonumber
local pairs = pairs

--------------------------------------------------
-- CVars
do
    local CVars = namespace:Get("CVars")
    CVars:SetCVar("showItemLevel","0","SHOW_ITEM_LEVEL")
    CVars:SetCVar("groundEffectDist","0")
end


UnitPopupButtons["SPECTATE"] = {text = "Spectate", dist = 0}
tinsert(UnitPopupMenus["FRIEND"],#UnitPopupMenus["FRIEND"]-1,"SPECTATE")
tinsert(UnitPopupMenus["TEAM"],#UnitPopupMenus["TEAM"]-1,"SPECTATE")
tinsert(UnitPopupMenus["BN_FRIEND"],#UnitPopupMenus["BN_FRIEND"]-1,"SPECTATE")


hooksecurefunc("UnitPopup_OnClick",function(self)
    if self.value == "SPECTATE" then
        SendChatMessage(".spec pla "..UIDROPDOWNMENU_INIT_MENU.name)
    end
end)


SLASH_RELOAD2 = "/rl"

--------------------------------------------------
-- Blizz trash
namespace.destroyObject(UIErrorsFrame)
WorldStateAlwaysUpFrame:ClearAllPoints()
WorldStateAlwaysUpFrame:SetPoint("BOTTOMLEFT",ChatFrame1,"TOPLEFT",40,100)


--------------------------------------------------
-- NoDuel
do
    local state = false
    hooksecurefunc("StaticPopup_Show",function(witch)
        if witch == "DUEL_REQUESTED" then
            if state then
                StaticPopupDialogs[witch].OnCancel()
            end
        end
    end)

    misc:RegisterEvent("VariablesLoaded",function(self,db)
        state = db["NoDuel"]
    end)

    SlashCmdList["NODUEL"] = function()
        state = not state
        namespace:SaveVariable("NoDuel",state)
        printf(state and "NoDuel enabled" or "NoDuel disabled")
    end
    SLASH_NODUEL1 = "/noduel"
end


--------------------------------------------------
-- Cursor trail
do
    local GetCursorPosition = GetCursorPosition

    local trail = CreateFrame("Model")
    trail:SetAllPoints()
    trail:SetFrameStrata("FULLSCREEN_DIALOG")
    trail:SetModel("spells\\lightningboltivus_missile.mdx")
    trail:SetModelScale(0.0024)

    local shine = CreateFrame("Model",nil,trail)
    shine:SetAllPoints()
    shine:SetModel("spells\\manafunnel_impact_chest.mdx")
    shine:SetModelScale(0.014)


    local screenHypotenuse = (GetScreenWidth()^2+GetScreenHeight()^2)^0.5
    local prevX,prevY
    shine:SetScript("OnUpdate",function(self)
        local x,y = GetCursorPosition()
        if x ~= prevX or y ~= prevY then
            prevX,prevY = x,y

            x,y = (x+4)/screenHypotenuse,(y-6)/screenHypotenuse
            self:SetPosition(x,y)
            trail:SetPosition(x,y)
        end
    end)
end


--------------------------------------------------
-- Spell casts announcer
if select(2,UnitClass("player")) == "PALADIN" then
    local UnitInRaid = UnitInRaid
    local IsPartyLeader = IsPartyLeader
    local UnitExists = UnitExists
    local UnitBuff = UnitBuff
    local SendChatMessage = SendChatMessage


    local AURA_MASTERY = GetSpellInfo(31821)
    local CONCENTRATION_AURA = GetSpellInfo(19746)
    misc:RegisterEvent("COMBAT_TEXT_UPDATE",function(self,arg1,arg2)
        if arg1 == "SPELL_AURA_START" and arg2 == AURA_MASTERY then
            if  UnitBuff("player",CONCENTRATION_AURA) then
                local channel
                local inRaid = UnitInRaid("player")
                if inRaid and IsPartyLeader() then
                    channel = "RAID_WARNING"
                elseif inRaid or UnitExists("party1") then
                    channel = "PARTY"
                end

                if channel then
                    for i = 1,2 do
                        SendChatMessage("<<< AURA MASTERY >>>",channel)
                    end
                end
            end
        end
    end)
end


--------------------------------------------------
-- focus button
do
	local focusbtn = CreateFrame("button","FOCUSBTN",nil,"SecureActionButtonTemplate")
	focusbtn:RegisterForClicks("AnyDown")
	focusbtn:SetAttribute("type","macro")
	focusbtn:SetAttribute("macrotext","/focus mouseover")

	local function UPDATE_BINDINGS(self)
		self:UnregisterEvent("UPDATE_BINDINGS")

		if GetBindingByKey("BUTTON5")~="CLICK FOCUSBTN:LeftButton" then
	        SetBindingClick("BUTTON5","FOCUSBTN")
	        SaveBindings(GetCurrentBindingSet())
	    end
	end
	misc:RegisterEvent("UPDATE_BINDINGS",UPDATE_BINDINGS)
end


--------------------------------------------------
-- popups
do
    local FlashWindow = FlashWindow or namespace.null
    local StaticPopupDialogs = StaticPopupDialogs
    local IsInInstance = IsInInstance
    
    hooksecurefunc("StaticPopup_Show",function(witch)
        if witch == "DEATH" then
            local _,instanceType = IsInInstance()
            if instanceType == "pvp" then
                StaticPopupDialogs[witch].OnAccept()
            end
        elseif witch == "TRADE" then
            if InCombatLockdown() then
                StaticPopupDialogs[witch].OnCancel()
            end
        elseif witch == "PARTY_INVITE" or witch == "CONFIRM_BATTLEFIELD_ENTRY" then
            FlashWindow()
        end
    end)


    misc:RegisterEvent("CHAT_MSG_WHISPER",FlashWindow)
    misc:RegisterEvent("PLAYER_LOGOUT",FlashWindow)
end


--------------------------------------------------
-- /guid
SlashCmdList.GUID = function()
    if not UnitExists("target") then return end
    local guid = UnitGUID("target")
    if guid:sub(5,5) == "0" then
        printf("%s's GUID: %d",UnitName("target"),tonumber(guid:sub(13,18),16))
    else
        printf("%s isn't player",UnitName("target"))
    end
end
SLASH_GUID1 = "/guid"


--------------------------------------------------
-- morpher
if SetDisplayID then
    local SetDisplayID = SetDisplayID
    local GetDisplayID = GetDisplayID
    local GetOriginalDisplayID = GetOriginalDisplayID
    local math_random = math.random


    local customMorph

    local function UpdateModel(self,unit)
        if customMorph then
            if not unit or unit == "player" then
                if GetDisplayID("player") == GetOriginalDisplayID("player") then
                    SetDisplayID("player",customMorph)
                end
            end
        end
    end

    local function VariablesLoaded(self,db)
    	customMorph = db["Morph"]

    	UpdateModel()

        misc:RegisterEvent("UNIT_MODEL_CHANGED",UpdateModel)
        misc:RegisterEvent("PLAYER_ENTERING_WORLD",UpdateModel)
    end


    local keywords = {
        ["m"] = 19723,
        ["f"] = 19724,
        ["v"] = 24993,
        ["bem"] = 20578,
        ["bef"] = 20579,
        ["u"] = 28193,
        ["of"] = 20316,
        ["tf"] = 20321,
        ["tm"] = 20585,
        ["gm"] = 20580,
        ["nem"] = 20318,
        ["df"] = 20323,
        ["tree"] = 864,
        ["munkin"] = 15374,
    }


    SlashCmdList.MORPH = function(msg)
        local curDisplayID,newDisplayID = GetDisplayID("player")
        if not curDisplayID then
            return
        end

        if msg and msg~="" then
            local str = msg:lower():match("^(%l+)")
            if str then
                if str == "random" then
                    local count = 0
                    for _,v in pairs(keywords) do
                        if type(v) == "number" then
                            count = count + 1
                        end
                    end

                    count = math_random(1,count)
                    for _,v in pairs(keywords) do
                        if type(v) == "number" then
                            count = count - 1
                            if count == 0 then
                                newDisplayID = v
                                break
                            end
                        end
                    end
                elseif str == "target" then
                    newDisplayID = GetDisplayID("target")
                else
                    newDisplayID = tonumber(keywords[msg])
                end
            else
                newDisplayID = tonumber(msg)
            end
        end

        if newDisplayID then
            if newDisplayID == curDisplayID then
                printf("this morph alredy applied")
                return
            end

            SetDisplayID("player",newDisplayID)
            printf("morphed to %d",newDisplayID)
        else
            SetDisplayID("player",GetOriginalDisplayID("player"))
            printf("morph removed")
        end

        namespace:SaveVariable("Morph",newDisplayID)
        customMorph = newDisplayID
    end
    SLASH_MORPH1 = "/morph"

    misc:RegisterEvent("VariablesLoaded",VariablesLoaded)
end


--------------------------------------------------
-- red flash on low health
do
	local UnitHealthMax = UnitHealthMax
	local UnitHealth = UnitHealth

    local frame = CreateFrame("frame")

    local function Update(self,unit)
    	if not unit then
    		unit = "player"
    	elseif unit ~= "player" then
    		return
    	end

		if UnitHealth(unit)/UnitHealthMax(unit) < 0.33 then
			frame:Show()
			frame.lowHealth = true
		elseif frame.lowHealth then
			frame:Hide()
			frame:SetAlpha(0)
			frame.mod = 1.2
			frame.lowHealth = false
		end
    end

    local function OnUpdate(self,elapsed)
    	local alpha = self:GetAlpha()
    	local newAlpha = alpha + elapsed * self.mod
    	if newAlpha > 1 or newAlpha < 0 then
    		self.mod = -self.mod
    	end
    	self:SetAlpha(newAlpha)
    end
    
    frame:Hide()
    frame:SetAlpha(0)
    frame.mod = 1.2
    frame:SetScript("OnUpdate",OnUpdate)

    local texture = frame:CreateTexture(nil,"BORDER")
    texture:SetAllPoints(UIParent)
    texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    texture:SetBlendMode("ADD")

    misc:RegisterEvent("UNIT_HEALTH",Update)
    misc:RegisterEvent("UNIT_MAXHEALTH",Update)
    misc:RegisterEvent("PLAYER_ENTERING_WORLD",Update)
end


--------------------------------------------------
-- arena count down
do
    local FlashWindow = FlashWindow or namespace.null
    local SendChatMessage = SendChatMessage
    local ceil = ceil
    local GetGameTime = GetGameTime


    local MESSAGE = "Fifteen seconds until the Arena battle begins!"
    local frame = CreateFrame('frame')

    local function OnEvent(self,event,...)
        if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        	local message = ...
        	if message:find(MESSAGE) then
            	self.remain = 15
            	self:Show()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            self.remain = nil
            self:Hide()
        end
    end

    local function OnUpdate(self,elapsed)
        self.remain = self.remain - elapsed
        if self.remain <= 0 then
            self:Hide()
            self.remain = nil
            printf("Battle began at %d:%d",GetGameTime())
            FlashWindow()
        elseif self.remain <= 3 then
            self.timer:SetFormattedText("%.1f",self.remain)
            self.timer:SetTextColor(1,0,0)
        else
            self.timer:SetText(ceil(self.remain))
            self.timer:SetTextColor(1,1,1)
        end
    end

    frame:SetPoint("CENTER",0,180)
    frame:SetSize(2,2)
    frame.timer = frame:CreateFontString(nil,"BORDER")
    frame.timer:SetPoint("CENTER")
    frame.timer:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent",OnEvent)
    frame:SetScript("OnUpdate",OnUpdate)
    frame:Hide()
end

--------------------------------------------------
-- MMR Announcer
do
    local UnitName = UnitName
    local GetNumBattlefieldScores = GetNumBattlefieldScores
    local GetBattlefieldScore = GetBattlefieldScore
    local IsActiveBattlefieldArena = IsActiveBattlefieldArena
    local GetBattlefieldWinner = GetBattlefieldWinner
    local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
    local SendChatMessage = SendChatMessage


    local function GetPlayerTeamID()
        local playerName = UnitName("player")
        local name,teamId,_
        for i = 1,GetNumBattlefieldScores() do
            name,_,_,_,_,teamId = GetBattlefieldScore(i)
            if name == playerName then
                return teamId
            end
        end
    end

    misc:RegisterEvent("UPDATE_BATTLEFIELD_STATUS",function()
        if not (IsActiveBattlefieldArena() and GetBattlefieldWinner()) then return end

        local name,lost,got,mmr
        local msg
        for i = 0,1 do
            name,lost,got,mmr = GetBattlefieldTeamInfo(i)
            if name:find("^Solo Team [1-2]$") then
                name = GetPlayerTeamID() == i and "Our team" or "Enemy team"
            end

            if got > 0 then
                msg = ("%q(%d) +%d"):format(name,mmr,got)
            elseif lost > 0 then
                msg = ("%q(%d) -%d"):format(name,mmr,lost)
            else
                msg = ("%q(%d) no changes"):format(name,mmr)
            end
            printf(msg)
        end
    end)
end

-- icons\ilvl\id tooltip
do
    local TOOLTIPS = {ItemRefTooltip,GameTooltip,ShoppingTooltip1,ShoppingTooltip2,ShoppingTooltip3}
    local GetItemIcon = GetItemIcon
    local GetItemInfo = GetItemInfo
    local _G = _G

    local function OnTooltipSetSpell(self)
        local _,_,spell = self:GetSpell()
        if spell and GetSpellInfo(spell) then
            local title = _G[self:GetName().."TextLeft1"]
            if title then
                local _,_,texture = GetSpellInfo(spell)
                title:SetFormattedText("|T%s:20:20:0:0:64:64:5:59:5:59:20|t %s",texture,title:GetText())
            end

            self:AddLine(("|cff3366ffID|r: |cffffffff%d|r"):format(spell))
            self:Show()
        end
    end

    local function OnTooltipSetItem(self)
        local itemName,link = self:GetItem()
        if link and GetItemInfo(link) then
            local title
            for i = 1,2 do
                title = _G[("%sTextLeft%d"):format(self:GetName(),i)]
                if title and title:GetText() and title:GetText():find(itemName) then
                    title:SetFormattedText("|T%s:20:20:0:0:64:64:5:59:5:59:20|t %s",GetItemIcon(link),title:GetText())
                    break
                end
            end

            local _,_,_,ilvl = GetItemInfo(link)
            local id = link:match("|Hitem:(%d+):")
            ilvl = ilvl and ("|cff3366ffilvl|r: |cffffffff%d|r"):format(ilvl)
            id = id and ("|cff3366ffID|r: |cffffffff%d|r"):format(id)

            self:AddDoubleLine(id,ilvl)
            self:Show()
        end
    end

    for _,tooltip in pairs(TOOLTIPS) do
        tooltip:HookScript("OnTooltipSetSpell",OnTooltipSetSpell)
        tooltip:HookScript("OnTooltipSetItem",OnTooltipSetItem)
    end
end

-- arena of valor
do
    local math = math
    local select = select
    local GetTime = GetTime
    local GetZoneText = GetZoneText


    local frame = CreateFrame("StatusBar",nil,UIParent)
    frame:Hide()
    frame:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    frame:SetStatusBarColor(0,0,0,0.7)
    frame:SetOrientation("VERTICAL")
    frame:SetPoint("BOTTOMRIGHT",ChatFrame1,"TOPRIGHT",2,10)
    frame:SetSize(36,36)

    local texture = frame:CreateTexture(nil,"BORDER")
    texture:SetTexture("Interface\\Icons\\Ability_Smash")
    texture:SetAllPoints()

    local text = frame:CreateFontString(nil,"ARTWORK","NumberFontNormal")
    text:SetPoint("CENTER")


    local function onValueChaned(self,value)
        text:SetText(math.ceil(select(2,self:GetMinMaxValues())-value))
    end

    local function onUpdate_Second(self,elapsed)
        self.remain = self.remain - elapsed
        if self.remain < 0 then
            self.remain = 0.05

            self:SetValue((GetTime()-self.startTime)%25)
        end
    end

    local function onUpdate_First(self,elapsed)
        self.remain = self.remain - elapsed
        if self.remain < 0 then
            self.remain = 0.05

            local curTime = GetTime()
            if curTime > self.startTime then
                self:SetMinMaxValues(0,25)
                self:SetScript("OnUpdate",onUpdate_Second)
                onUpdate_Second(self,0)
            else
                self:SetValue(45-(self.startTime-curTime))
            end
        end
    end

    local function onShow(self)
        self.startTime = GetTime()+45
        self.remain = 0.1
        self:SetMinMaxValues(0,45)
        self:SetScript("OnUpdate",onUpdate_First)
    end

    local function onEvent(self,event,...)
        if event == "PLAYER_ENTERING_WORLD" then
            self:Hide()
        elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
            local message = ...
            if message == "The Arena battle has begun!" and GetZoneText() == "The Ring of Valor" then
                self:Show()
            end
        end
    end

    frame:SetScript("OnValueChanged",onValueChaned)
    frame:SetScript("OnShow",onShow)
    frame:SetScript("OnUpdate",onUpdate)
    frame:SetScript("OnEvent",onEvent)
    frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end
