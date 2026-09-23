local _, ns = ...

local L = ns.L

local GetTime = GetTime

local Misc = ns:NewModule("Misc")

local ERROR_FLASH_DURATION = 0.2
local ERROR_FLASH_BRIGHTNESS = 0.4
local MAX_ERROR_LINES = 8

local COOLDOWN_ERRORS = {}
for _, key in ipairs({
	"ERR_ABILITY_COOLDOWN",
	"ERR_SPELL_COOLDOWN",
	"ERR_ITEM_COOLDOWN",
	"ERR_POTION_COOLDOWN",
	"SPELL_FAILED_ITEM_NOT_READY",
	"SPELL_FAILED_NOT_READY",
	"SPELL_FAILED_SPELL_IN_PROGRESS",
	"ERR_OUT_OF_ENERGY",
	"ERR_OUT_OF_FOCUS",
	"ERR_OUT_OF_HEALTH",
	"ERR_OUT_OF_MANA",
	"ERR_OUT_OF_RAGE",
	"ERR_OUT_OF_RUNES",
	"ERR_OUT_OF_RUNIC_POWER",
	"OUT_OF_ENERGY",
	"OUT_OF_MANA",
	"OUT_OF_RAGE",
}) do
	if _G[key] then
		COOLDOWN_ERRORS[_G[key]] = true
	end
end

local errorLines, errorLineCount = {}, 0
local redrawingErrors = false
local flashLine, flashStart
local errorFlashFrame = CreateFrame("Frame")

local function recordErrorLine(_, text, r, g, b, id)
	if redrawingErrors or type(text) ~= "string" then
		return
	end
	local line
	if errorLineCount == MAX_ERROR_LINES then
		line = tremove(errorLines, 1)
		errorLines[MAX_ERROR_LINES] = line
		if line == flashLine then
			flashLine = nil
		end
	else
		errorLineCount = errorLineCount + 1
		line = errorLines[errorLineCount] or {}
		errorLines[errorLineCount] = line
	end
	line.text, line.r, line.g, line.b, line.id, line.time = text, r or 1, g or 1, b or 1, id, GetTime()
end

local function forgetErrorLines()
	if not redrawingErrors then
		errorLineCount = 0
	end
end

local function redrawErrors(boost)
	local now = GetTime()
	local hold = UIErrorsFrame:GetTimeVisible()
	redrawingErrors = true
	UIErrorsFrame:Clear()
	local kept = 0
	for i = 1, errorLineCount do
		local line = errorLines[i]
		if line == flashLine or now - line.time < hold then
			kept = kept + 1
			errorLines[i], errorLines[kept] = errorLines[kept], line
			line.time = now
			local extra = line == flashLine and boost or 0
			UIErrorsFrame:AddMessage(line.text, line.r + extra, line.g + extra, line.b + extra, line.id)
		end
	end
	errorLineCount = kept
	redrawingErrors = false
end

local function onErrorFlashUpdate(self)
	local progress = (GetTime() - flashStart) / ERROR_FLASH_DURATION
	if progress >= 1 then
		self:SetScript("OnUpdate", nil)
		redrawErrors(0)
		flashLine = nil
		return
	end
	redrawErrors((progress > 0.5 and 1 - progress or progress) * 2 * ERROR_FLASH_BRIGHTNESS)
end

local function findVisibleErrorLine(message)
	local window = UIErrorsFrame:GetTimeVisible() + UIErrorsFrame:GetFadeDuration()
	local now = GetTime()
	for i = errorLineCount, 1, -1 do
		local line = errorLines[i]
		if line.text == message and now - line.time < window then
			return line
		end
	end
end

local function onErrorMessage(_, message)
	local config = ns.Config.tweaks
	if config.filterCooldownErrors and COOLDOWN_ERRORS[message] then
		return
	end
	local line = config.dedupErrors and findVisibleErrorLine(message)
	if not line then
		UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1, 1)
		return
	end
	flashLine, flashStart = line, GetTime()
	redrawErrors(0)
	errorFlashFrame:SetScript("OnUpdate", onErrorFlashUpdate)
end

hooksecurefunc(UIErrorsFrame, "AddMessage", recordErrorLine)
hooksecurefunc(UIErrorsFrame, "Clear", forgetErrorLines)

local function applyErrors()
	local config = ns.Config.tweaks
	local takeOver = not config.hideErrors and (config.dedupErrors or config.filterCooldownErrors)
	if config.hideErrors or takeOver then
		UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
	else
		UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
	end
	if takeOver then
		Misc:RegisterEvent("UI_ERROR_MESSAGE", onErrorMessage)
	else
		Misc:UnregisterEvent("UI_ERROR_MESSAGE", onErrorMessage)
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
	self:WatchConfig("tweaks.dedupErrors", applyErrors)
	self:WatchConfig("tweaks.filterCooldownErrors", applyErrors)

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
