local _, ns = ...

local Misc = ns:NewModule("Misc")

local function applyErrors()
	if ns.Config.tweaks.hideErrors then
		UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
	else
		UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
	end
end

local function applyScriptErrors()
	ns:GetModule("CVars"):Pin("scriptErrors", ns.Config.tweaks.scriptErrors and "1" or "0")
end

local function applyGroundClutter()
	local CVars = ns:GetModule("CVars")
	if ns.Config.tweaks.hideGroundClutter then
		CVars:Pin("groundEffectDist", "0")
	else
		CVars:Unpin("groundEffectDist")
	end
end

local function applyCameraDistance()
	ns:GetModule("CVars"):Pin("cameraDistanceMax", tostring(ns.Config.tweaks.cameraDistanceMax))
end

local function onPopupClick(self)
	if self.value == "SPECTATE" then
		SendChatMessage(".spec pla " .. UIDROPDOWNMENU_INIT_MENU.name)
	end
end

Misc:OnInitialize(function(self)
	if not ns.Config.tweaks.enabled then
		return
	end

	local CVars = ns:GetModule("CVars")
	CVars:Pin("showItemLevel", "0", "SHOW_ITEM_LEVEL")
	CVars:Pin("showTutorials", "0")
	CVars:Pin("cameraDistanceMaxFactor", "1")

	applyScriptErrors()
	applyGroundClutter()
	applyCameraDistance()
	applyErrors()
	self:WatchConfig("tweaks.scriptErrors", applyScriptErrors)
	self:WatchConfig("tweaks.hideGroundClutter", applyGroundClutter)
	self:WatchConfig("tweaks.cameraDistanceMax", applyCameraDistance)
	self:WatchConfig("tweaks.hideErrors", applyErrors)

	self:AnchorToConfig(WorldStateAlwaysUpFrame, "tweaks.worldStatePoint", nil, "World state")
	ns.Movers.Register(WorldStateAlwaysUpFrame, "tweaks.worldStatePoint", nil, { size = { 200, 30 } })

	UnitPopupButtons.SPECTATE = { text = "Spectate", dist = 0 }
	for _, menu in ipairs({ "FRIEND", "TEAM", "BN_FRIEND" }) do
		tinsert(UnitPopupMenus[menu], #UnitPopupMenus[menu] - 1, "SPECTATE")
	end
	hooksecurefunc("UnitPopup_OnClick", onPopupClick)
end)

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

SlashCmdList.FROSTATOMUI_CONFIG = function(text)
	local command = text and text:trim():lower()
	if command == "unlock" or command == "move" then
		ns.Movers.Unlock()
		return
	elseif command == "lock" then
		ns.Movers.Lock()
		return
	end
	local loaded, reason = LoadAddOn("FrostAtomUI_Config")
	if not loaded then
		ns.Print("cannot load FrostAtomUI_Config: %s", _G["ADDON_" .. reason] or reason)
		return
	end
	FrostAtomUI_Config.Toggle(command ~= "" and command or nil)
end
SLASH_FROSTATOMUI_CONFIG1 = "/fui"
SLASH_FROSTATOMUI_CONFIG2 = "/frostatomui"
SLASH_FROSTATOMUI_CONFIG3 = "/faui"
SLASH_FROSTATOMUI_CONFIG4 = "/ui"

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
