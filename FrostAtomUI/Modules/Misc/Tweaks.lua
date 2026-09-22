local _, ns = ...

local L = ns.L

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

local function fixLFDCooldownFrame()
	LFDQueueFrameCooldownFrame:SetScript("OnEvent", function(_, event, unit)
		if event ~= "UNIT_AURA" or unit == "player" or (unit and unit:find("^party")) then
			LFDQueueFrameRandomCooldownFrame_Update()
		end
	end)
end

local function onPopupClick(self)
	if self.value == "SPECTATE" then
		SendChatMessage(".spec pla " .. UIDROPDOWNMENU_INIT_MENU.name)
	end
end

Misc:OnInitialize(function(self)
	fixLFDCooldownFrame()
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

	self:AnchorToConfig(WorldStateAlwaysUpFrame, "tweaks.worldStatePoint", "World state", { size = { 200, 30 } })

	UnitPopupButtons.SPECTATE = { text = L["Spectate"], dist = 0 }
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
		ns.Print(L["%s's GUID: %d"], UnitName("target"), tonumber(guid:sub(13, 18), 16))
	else
		ns.Print(L["%s isn't a player"], UnitName("target"))
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
		ns.Print(L["cannot load FrostAtomUI_Config: %s"], _G["ADDON_" .. reason] or reason)
		return
	end
	FrostAtomUI_Config.Toggle(command ~= "" and command or nil)
end
SLASH_FROSTATOMUI_CONFIG1 = "/fui"
SLASH_FROSTATOMUI_CONFIG2 = "/frostatomui"
SLASH_FROSTATOMUI_CONFIG3 = "/faui"
SLASH_FROSTATOMUI_CONFIG4 = "/ui"

local MENU_BUTTON_COLOR = { 0.09, 0.49, 0.75 }

local menuButton = CreateFrame("Button", "FrostAtomUIMenuButton", GameMenuFrame, "GameMenuButtonTemplate")
menuButton:SetText("FrostAtomUI")
menuButton:SetPoint("TOP", GameMenuButtonUIOptions, "BOTTOM", 0, -1)
menuButton:SetScript("OnClick", function()
	PlaySound("igMainMenuOption")
	HideUIPanel(GameMenuFrame)
	SlashCmdList.FROSTATOMUI_CONFIG("")
end)
menuButton:GetFontString():SetTextColor(unpack(MENU_BUTTON_COLOR))
menuButton:HookScript("OnEnable", function(self)
	self:GetFontString():SetTextColor(unpack(MENU_BUTTON_COLOR))
end)

GameMenuButtonKeybindings:SetPoint("TOP", menuButton, "BOTTOM", 0, -1)
GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + menuButton:GetHeight() + 1)

local FOCUS_BUTTON_NAME = "FrostAtomUIFocusButton"
local FOCUS_COMMAND = "CLICK " .. FOCUS_BUTTON_NAME .. ":LeftButton"
local FOCUS_DEFAULT_KEY = "BUTTON5"

BINDING_HEADER_FROSTATOMUI = "FrostAtomUI"

local focusButton = CreateFrame("Button", FOCUS_BUTTON_NAME, nil, "SecureActionButtonTemplate")
focusButton:RegisterForClicks("AnyDown")
focusButton:SetAttribute("type", "macro")
focusButton:SetAttribute("macrotext", "/focus mouseover")

local CAMERA_SNAP_SPEED = 10000
local CAMERA_SNAP_HOLD = 0.05
local CAMERA_SNAP_TAIL = 0.05
local CAMERA_SNAP_MIN_FRAMES = 3

ns.OnLocaleReady(function()
	_G["BINDING_NAME_" .. FOCUS_COMMAND] = L["Focus mouseover"]
	BINDING_NAME_FROSTATOMUI_CAMERA_CLOSE = L["Close camera distance"]
	BINDING_NAME_FROSTATOMUI_CAMERA_MEDIUM = L["Medium camera distance"]
	BINDING_NAME_FROSTATOMUI_CAMERA_FAR = L["Far camera distance"]
end)

local snapFrame = CreateFrame("Frame")
local snapMax, snapFactor, snapDistance, snapTime, snapFrames, snapStopFrames

local function finishSnap(self, elapsed)
	snapTime = snapTime + elapsed
	snapFrames = snapFrames + 1
	SetCVar("cameraDistanceMax", snapDistance)

	if not snapStopFrames then
		if snapTime < CAMERA_SNAP_HOLD or snapFrames < CAMERA_SNAP_MIN_FRAMES then
			MoveViewInStart(CAMERA_SNAP_SPEED)
			MoveViewOutStart(CAMERA_SNAP_SPEED)
		else
			MoveViewInStop()
			MoveViewOutStop()
			snapStopFrames = snapFrames
		end
		return
	end

	if snapTime < CAMERA_SNAP_HOLD + CAMERA_SNAP_TAIL or snapFrames < snapStopFrames + CAMERA_SNAP_MIN_FRAMES then
		return
	end

	self:SetScript("OnUpdate", nil)
	SetCVar("cameraDistanceMaxFactor", snapFactor)
	SetCVar("cameraDistanceMax", snapMax)
	snapTime = nil
end

function FrostAtomUI_SetCameraDistance(preset)
	local distance = ns.Config.tweaks["cameraDistance" .. preset]
	if not distance then
		return
	end

	if not snapTime then
		snapMax = GetCVar("cameraDistanceMax")
		snapFactor = GetCVar("cameraDistanceMaxFactor")
	end
	snapTime = 0
	snapFrames = 0
	snapStopFrames = nil
	snapDistance = tostring(distance)

	SetCVar("cameraDistanceMaxFactor", "1")
	SetCVar("cameraDistanceMax", snapDistance)
	MoveViewInStart(CAMERA_SNAP_SPEED)
	MoveViewOutStart(CAMERA_SNAP_SPEED)
	snapFrame:SetScript("OnUpdate", finishSnap)
end

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
