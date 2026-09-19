local _, ns = ...

local Misc = ns:NewModule("Misc")

local CVars = ns:GetModule("CVars")
CVars:Pin("showItemLevel", "0", "SHOW_ITEM_LEVEL")
CVars:Pin("groundEffectDist", "0")
CVars:Pin("showTutorials", "0")
CVars:Pin("scriptErrors", "1")
CVars:Pin("cameraDistanceMax", "50")
CVars:Pin("cameraDistanceMaxFactor", "1")

UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")

WorldStateAlwaysUpFrame:ClearAllPoints()
WorldStateAlwaysUpFrame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 40, 100)

SLASH_RELOAD2 = "/rl"

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

UnitPopupButtons.SPECTATE = { text = "Spectate", dist = 0 }
for _, menu in ipairs({ "FRIEND", "TEAM", "BN_FRIEND" }) do
	tinsert(UnitPopupMenus[menu], #UnitPopupMenus[menu] - 1, "SPECTATE")
end

hooksecurefunc("UnitPopup_OnClick", function(self)
	if self.value == "SPECTATE" then
		SendChatMessage(".spec pla " .. UIDROPDOWNMENU_INIT_MENU.name)
	end
end)

local FOCUS_BUTTON_NAME = "FrostAtomUIFocusButton"
local FOCUS_COMMAND = "CLICK " .. FOCUS_BUTTON_NAME .. ":LeftButton"
local FOCUS_DEFAULT_KEY = "BUTTON5"

BINDING_HEADER_FROSTATOMUI = "FrostAtomUI"
_G["BINDING_NAME_" .. FOCUS_COMMAND] = "Focus mouseover"

local focusButton = CreateFrame("Button", FOCUS_BUTTON_NAME, nil, "SecureActionButtonTemplate")
focusButton:RegisterForClicks("AnyDown")
focusButton:SetAttribute("type", "macro")
focusButton:SetAttribute("macrotext", "/focus mouseover")

Misc:RegisterEvent("UPDATE_BINDINGS", function(self)
	self:UnregisterEvent("UPDATE_BINDINGS")

	if ns.db.focusKeyDefaulted or GetBindingKey(FOCUS_COMMAND) then
		return
	end
	ns:SaveVariable("focusKeyDefaulted", true)
	if not GetBindingByKey(FOCUS_DEFAULT_KEY) then
		SetBindingClick(FOCUS_DEFAULT_KEY, FOCUS_BUTTON_NAME)
		SaveBindings(GetCurrentBindingSet())
	end
end)
