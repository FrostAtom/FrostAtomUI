local namespace = select(2,...)
local binderFrame

local function CreateBinder()
	local SetBindingClick = SetBindingClick
	local IsAltKeyDown = IsAltKeyDown
	local IsControlKeyDown = IsControlKeyDown
	local IsShiftKeyDown = IsShiftKeyDown
	local SaveBindings = SaveBindings
	local GetCurrentBindingSet = GetCurrentBindingSet
	local GetMouseFocus = GetMouseFocus
    local tNew,tDel = namespace.tNew,namespace.tDel


    local ignoredButtons = {
    	["LSHIFT"] = true,
    	["RSHIFT"] = true,
    	["LCTRL"] = true,
    	["RCTRL"] = true,
    	["LALT"] = true,
    	["RALT"] = true,
    	["UNKNOWN"] = true,
    	["LeftButton"] = true,
    	["RightButton"] = true
    }

    local function OnUpdate(self)
        local focus = GetMouseFocus()
        if focus ~= self and focus ~= self.focus then
            if focus and focus:IsObjectType("Button") and focus:GetAttribute("type") and focus:GetName() then
                self:SetAllPoints(focus)
                self:SetAlpha(1)
                self.focus = focus
            else
                self:SetAlpha(0)
                self.focus = nil
            end
        end
    end

    local function OnClick(self,button)
    	if not self.focus or ignoredButtons[button] then return end

        if button == "ESCAPE" then
            local bind = GetBindingKey(("CLICK %s:LeftButton"):format(self.focus:GetName()))
            if bind then
                SetBinding(bind,nil)
            end
            return
        end

    	if button == "MiddleButton" then
    		button = "BUTTON3"
    	elseif button:find("^Button%d+$") then
    		button = button:upper()
    	end

        local tbl = tNew()
        if IsAltKeyDown() then
            tbl[#tbl+1] = "ALT"
        end

        if IsControlKeyDown() then
            tbl[#tbl+1] = "CTRL"
        end

        if IsShiftKeyDown() then
            tbl[#tbl+1] = "SHIFT"
        end

        tbl[#tbl+1] = button

        button = table.concat(tbl,"-")
        tbl = tDel(tbl)
        
    	SetBindingClick(button,self.focus:GetName())
    end

	binderFrame = CreateFrame("frame")
    binderFrame:SetFrameStrata("DIALOG")
    binderFrame:EnableMouse(true)
    binderFrame:EnableMouseWheel(true)
    binderFrame:EnableKeyboard(true)
    binderFrame:SetScript("OnUpdate",OnUpdate)
    binderFrame:SetScript("OnKeyUp",OnClick)
    binderFrame:SetScript("OnMouseUp",OnClick)
    binderFrame:SetScript("OnMouseWheel",function(self,delta)
    	if delta > 0 then
    		OnClick(self,"MOUSEWHEELUP")
    	else
    		OnClick(self,"MOUSEWHEELDOWN")
    	end
	end)

    binderFrame.texture = binderFrame:CreateTexture()
    binderFrame.texture:SetAllPoints()
    binderFrame.texture:SetTexture(0,1,0,0.4)

    StaticPopupDialogs["KEYBIND_MODE"] = {
        text = "Hover your mouse over any actionbutton to bind it. Press the escape key or right click to clear the current actionbutton's keybinding.",
        button1 = "Save bindings",
        button2 = "Discard bindings",
        OnAccept = function() SaveBindings(GetCurrentBindingSet()) binderFrame:Hide() binderFrame:ClearAllPoints() end,
        OnCancel = function() LoadBindings(GetCurrentBindingSet()) binderFrame:Hide() binderFrame:ClearAllPoints() end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = false
    }
end

SlashCmdList["BIND"] = function()
	if not binderFrame then
		CreateBinder()
        StaticPopup_Show("KEYBIND_MODE")
	elseif binderFrame:IsShown() then
    	binderFrame:Hide()
        StaticPopup_Hide("KEYBIND_MODE")
    else
    	binderFrame:Show()
        StaticPopup_Show("KEYBIND_MODE")
	end
end

SLASH_BIND1 = "/b"
SLASH_BIND2 = "/bind"