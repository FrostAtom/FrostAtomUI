local _, ns = ...

-- Small things that do not deserve a module of their own.

local Misc = ns:NewModule("Misc")

--------------------------------------------------
-- CVars

local CVars = ns:GetModule("CVars")
CVars:Pin("showItemLevel", "0", "SHOW_ITEM_LEVEL")
CVars:Pin("groundEffectDist", "0")

--------------------------------------------------
-- Blizzard frames

ns.DestroyFrame(UIErrorsFrame)

WorldStateAlwaysUpFrame:ClearAllPoints()
WorldStateAlwaysUpFrame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 40, 100)

--------------------------------------------------
-- Slash commands

SLASH_RELOAD2 = "/rl"

-- Prints the low part of the target's GUID (players only).
SlashCmdList.FROSTATOMUI_GUID = function()
	if not UnitExists("target") then
		return
	end

	local guid = UnitGUID("target")
	if guid:sub(5, 5) == "0" then
		ns.Print("%s's GUID: %d", UnitName("target"), tonumber(guid:sub(13, 18), 16))
	else
		ns.Print("%s isn't a player", UnitName("target"))
	end
end
SLASH_FROSTATOMUI_GUID1 = "/guid"

--------------------------------------------------
-- "Spectate" entry in player menus (server command)

UnitPopupButtons.SPECTATE = { text = "Spectate", dist = 0 }
for _, menu in ipairs({ "FRIEND", "TEAM", "BN_FRIEND" }) do
	tinsert(UnitPopupMenus[menu], #UnitPopupMenus[menu] - 1, "SPECTATE")
end

hooksecurefunc("UnitPopup_OnClick", function(self)
	if self.value == "SPECTATE" then
		SendChatMessage(".spec pla " .. UIDROPDOWNMENU_INIT_MENU.name)
	end
end)

--------------------------------------------------
-- Mouse button 5 sets focus on the mouseover unit

local FOCUS_BUTTON_NAME = "FrostAtomUIFocusButton"
local FOCUS_KEY = "BUTTON5"

local focusButton = CreateFrame("Button", FOCUS_BUTTON_NAME, nil, "SecureActionButtonTemplate")
focusButton:RegisterForClicks("AnyDown")
focusButton:SetAttribute("type", "macro")
focusButton:SetAttribute("macrotext", "/focus mouseover")

Misc:RegisterEvent("UPDATE_BINDINGS", function(self)
	self:UnregisterEvent("UPDATE_BINDINGS")

	if GetBindingByKey(FOCUS_KEY) ~= "CLICK " .. FOCUS_BUTTON_NAME .. ":LeftButton" then
		SetBindingClick(FOCUS_KEY, FOCUS_BUTTON_NAME)
		SaveBindings(GetCurrentBindingSet())
	end
end)
