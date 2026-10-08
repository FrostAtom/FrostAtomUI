local _, ns = ...

local L = ns.L

local GetTime = GetTime

local Tweaks = ns:NewModule("Tweaks")
local snapSlot = ns.Storage.Claim("cameraSnapDistance", "Tweaks", "state")
local focusDefaultedSlot = ns.Storage.Slot("focusKeyDefaulted")
local focusAnnouncedSlot = ns.Storage.Slot("focusKeyAnnounced")
ns:RegisterReloadPaths("tweaks.enabled")

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
	if ns.Config.tweaks.errorMessages == "filtered" and COOLDOWN_ERRORS[message] then
		return
	end
	local line = findVisibleErrorLine(message)
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
	local mode = ns.Config.tweaks.errorMessages
	if mode == "all" and not ns.Config.tweaks.enabled then
		Tweaks:UnregisterEvent("UI_ERROR_MESSAGE", onErrorMessage)
		UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
		return
	end
	UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
	if mode == "hidden" then
		Tweaks:UnregisterEvent("UI_ERROR_MESSAGE", onErrorMessage)
	else
		Tweaks:RegisterEvent("UI_ERROR_MESSAGE", onErrorMessage)
	end
end

local function applyScriptErrors()
	local CVars = ns:GetModule("CVars")
	if ns.Config.tweaks.scriptErrors then
		CVars:Pin("scriptErrors", "1")
	else
		CVars:Unpin("scriptErrors")
	end
end

local function applyTutorials()
	local CVars = ns:GetModule("CVars")
	if ns.Config.tweaks.disableTutorials then
		CVars:Pin("showTutorials", "0")
	else
		CVars:Unpin("showTutorials")
	end
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

local CVAR_TOGGLES = {
	keepCameraPitch = { cameraSmoothPitch = "0" },
	instantCameraHeight = { cameraHeightSmoothSpeed = "50" },
	keepShapeshift = { autoUnshift = "0" },
	keepMount = { autoDismount = "0" },
	keepSitting = { autoStand = "0" },
	hideSelectionCircle = { ObjectSelectionCircle = "0" },
	hideUnitHighlight = { unitHighlights = "0" },
	allSpellMechanics = { fctAllSpellMechanics = "1" },
	hideScreenEffects = { ffx = "0" },
	hideInvisibilityEffect = { ffxNetherWorld = "0" },
	fullViewDistance = { farClipOverride = "1" },
	muteArmorFoley = { Sound_EnableArmorFoleySoundForSelf = "0", Sound_EnableArmorFoleySoundForOthers = "0" },
}

local CVAR_VALUES = {
	cameraYawSpeed = "cameraYawMoveSpeed",
	cameraPitchSpeed = "cameraPitchMoveSpeed",
	cameraZoomSpeed = "cameraDistanceMoveSpeed",
	cameraFollowTime = "cameraSmoothTimeMax",
	cameraFollowStyle = "cameraSmoothStyle",
	maxFPS = "maxFPS",
	maxFPSBackground = "maxFPSBk",
	assetLoadTime = "asyncHandlerTimeout",
	timingMethod = "timingMethod",
}

-- 3.3.5: the client rounds mouseSpeed down a step, so the stored value is bumped slightly
local MOUSE_SPEED_ROUNDING = 0.005

local SOUND_LISTENER = {
	Sound_ListenerBackDist = { "0", "2" },
	Sound_ListenerUpDist = { "1.5", "4" },
}

local function applyCVarToggle(key)
	local CVars = ns:GetModule("CVars")
	local enabled = ns.Config.tweaks[key]
	for name, value in pairs(CVAR_TOGGLES[key]) do
		if enabled then
			CVars:Pin(name, value)
		else
			CVars:Unpin(name)
		end
	end
end

local function applyCVarValue(key)
	local CVars = ns:GetModule("CVars")
	local name = CVAR_VALUES[key]
	local value = ns.Config.tweaks[key]
	if value == "" or tonumber(value) == tonumber(GetCVarDefault(name)) then
		CVars:Unpin(name)
	else
		CVars:Pin(name, tostring(value))
	end
end

local appliedAmbient = 0

local function applyCharacterAmbient()
	local value = ns.Config.tweaks.characterAmbient
	if value > 0 or appliedAmbient > 0 then
		ConsoleExec(("characterAmbient %.2f"):format(value))
		appliedAmbient = value
	end
end

local sunGlareHidden

local function applySunGlare()
	if ns.Config.tweaks.hideSunGlare then
		ConsoleExec("SkySunGlare 0")
		sunGlareHidden = true
	elseif sunGlareHidden then
		ConsoleExec("SkySunGlare 1")
		sunGlareHidden = nil
	end
end

local function applyWorldCommands()
	applyCharacterAmbient()
	applySunGlare()
end

local function applyMouseSpeed()
	local CVars = ns:GetModule("CVars")
	local mode = ns.Config.tweaks.mouseSpeedMode
	if mode == "windows" then
		CVars:Pin("mouseSpeed", ("%.3f"):format(tonumber(GetCVarDefault("mouseSpeed")) + MOUSE_SPEED_ROUNDING))
	elseif mode == "custom" then
		CVars:Pin("mouseSpeed", ("%.3f"):format(ns.Config.tweaks.mouseSpeed + MOUSE_SPEED_ROUNDING))
	else
		CVars:Unpin("mouseSpeed")
	end
end

local function applySoundListener()
	local CVars = ns:GetModule("CVars")
	local enabled = ns.Config.tweaks.soundAtHead
	for name, values in pairs(SOUND_LISTENER) do
		if enabled then
			CVars:Pin(name, values[1])
		else
			CVars:Unpin(name)
			SetCVar(name, values[2])
		end
	end
end

local GAME_SETTINGS = {
	scriptErrors = { "tweaks.scriptErrors", false },
	showTutorials = { "tweaks.disableTutorials", false },
	groundEffectDist = { "tweaks.hideGroundClutter", false },
	mouseSpeed = { "tweaks.mouseSpeedMode", "" },
}
for key, cvars in pairs(CVAR_TOGGLES) do
	for name in pairs(cvars) do
		GAME_SETTINGS[name] = { "tweaks." .. key, false }
	end
end
for key, name in pairs(CVAR_VALUES) do
	GAME_SETTINGS[name] = { "tweaks." .. key, "" }
end
for name in pairs(SOUND_LISTENER) do
	GAME_SETTINGS[name] = { "tweaks.soundAtHead", false }
end

local function fixLFDCooldownFrame()
	LFDQueueFrameCooldownFrame:SetScript("OnEvent", function(_, event, unit)
		if event ~= "UNIT_AURA" or unit == "player" or (unit and unit:find("^party")) then
			LFDQueueFrameRandomCooldownFrame_Update()
		end
	end)
end

local WORLD_STATE_WIDTH = 160
local WORLD_STATE_ROW = 16
local WORLD_STATE_ICON = 14

local function layoutWorldState()
	local shown = 0
	local previous
	for i = 1, NUM_ALWAYS_UP_UI_FRAMES or 0 do
		local name = "AlwaysUpFrame" .. i
		local frame = _G[name]
		if frame and frame:IsShown() then
			local icon, text = _G[name .. "Icon"], _G[name .. "Text"]
			local dynamic, flash = _G[name .. "DynamicIconButton"], _G[name .. "Flash"]
			local texture = icon:GetTexture()
			if texture and texture:find("UI%-PVP") then
				icon:SetTexCoord(0, 0.625, 0, 0.625)
			else
				icon:SetTexCoord(0, 1, 0, 1)
			end
			icon:SetSize(WORLD_STATE_ICON, WORLD_STATE_ICON)
			icon:ClearAllPoints()
			icon:SetPoint("LEFT")
			text:ClearAllPoints()
			text:SetPoint("LEFT", icon, "RIGHT", 3, 0)
			dynamic:SetSize(WORLD_STATE_ROW, WORLD_STATE_ROW)
			dynamic:ClearAllPoints()
			dynamic:SetPoint("LEFT", text, "RIGHT", 2, 0)
			_G[name .. "DynamicIconButtonIcon"]:SetSize(WORLD_STATE_ROW, WORLD_STATE_ROW)
			flash:SetSize(WORLD_STATE_ROW, WORLD_STATE_ROW)
			_G[name .. "FlashTexture"]:SetSize(WORLD_STATE_ROW, WORLD_STATE_ROW)
			frame:SetSize(WORLD_STATE_ICON + 3 + text:GetStringWidth(), WORLD_STATE_ROW)
			frame:ClearAllPoints()
			if previous then
				frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
			else
				frame:SetPoint("TOPLEFT", WorldStateAlwaysUpFrame)
			end
			previous = frame
			shown = shown + 1
		end
	end
	WorldStateAlwaysUpFrame:SetSize(WORLD_STATE_WIDTH, max(shown, 1) * WORLD_STATE_ROW)
end

local function onPopupClick(self)
	if self.value == "SPECTATE" then
		SendChatMessage(".spec pla " .. UIDROPDOWNMENU_INIT_MENU.name)
	end
end

Tweaks:OnInitialize(function(self)
	fixLFDCooldownFrame()
	applyScriptErrors()
	applyErrors()
	self:WatchConfig("tweaks.scriptErrors", applyScriptErrors)
	self:WatchConfig("tweaks.errorMessages", applyErrors)
	if not ns.Config.tweaks.enabled then
		return
	end

	local CVars = ns:GetModule("CVars")
	CVars:Pin("showItemLevel", "0", "SHOW_ITEM_LEVEL")
	CVars:Pin("cameraDistanceMaxFactor", "1")

	applyTutorials()
	applyGroundClutter()
	applyCameraDistance()
	self:WatchConfig("tweaks.disableTutorials", applyTutorials)
	self:WatchConfig("tweaks.hideGroundClutter", applyGroundClutter)
	self:WatchConfig("tweaks.cameraDistanceMax", applyCameraDistance)

	for key in pairs(CVAR_TOGGLES) do
		applyCVarToggle(key)
		self:WatchConfig("tweaks." .. key, function()
			applyCVarToggle(key)
		end)
	end
	for key in pairs(CVAR_VALUES) do
		applyCVarValue(key)
		self:WatchConfig("tweaks." .. key, function()
			applyCVarValue(key)
		end)
	end
	applyWorldCommands()
	self:WatchConfig("tweaks.characterAmbient", applyCharacterAmbient)
	self:WatchConfig("tweaks.hideSunGlare", applySunGlare)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", applyWorldCommands)
	applyMouseSpeed()
	self:WatchConfig("tweaks.mouseSpeedMode", applyMouseSpeed)
	self:WatchConfig("tweaks.mouseSpeed", applyMouseSpeed)
	for name, values in pairs(SOUND_LISTENER) do
		RegisterCVar(name, values[2])
	end
	applySoundListener()
	self:WatchConfig("tweaks.soundAtHead", applySoundListener)

	hooksecurefunc("WorldStateAlwaysUpFrame_Update", layoutWorldState)
	layoutWorldState()
	self:AnchorToConfig(WorldStateAlwaysUpFrame, "tweaks.worldStatePoint", "World state", {
		size = { WORLD_STATE_WIDTH, WORLD_STATE_ROW * 2 },
	})

	UnitPopupButtons.SPECTATE = { text = L["Spectate"], dist = 0 }
	for _, menu in ipairs({ "FRIEND", "TEAM", "BN_FRIEND" }) do
		tinsert(UnitPopupMenus[menu], #UnitPopupMenus[menu] - 1, "SPECTATE")
	end
	hooksecurefunc("UnitPopup_OnClick", onPopupClick)
end)

local function addSlashAlias(key, alias)
	local index = 1
	while _G["SLASH_" .. key .. index] do
		if _G["SLASH_" .. key .. index] == alias then
			return
		end
		index = index + 1
	end
	_G["SLASH_" .. key .. index] = alias
end

addSlashAlias("RELOAD", "/rl")
addSlashAlias("RELOAD", "/кд")
addSlashAlias("RELOAD", "/КД")

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

local RUSSIAN_LAYOUT = {
	["й"] = "q",
	["ц"] = "w",
	["у"] = "e",
	["к"] = "r",
	["е"] = "t",
	["н"] = "y",
	["г"] = "u",
	["ш"] = "i",
	["щ"] = "o",
	["з"] = "p",
	["х"] = "[",
	["ъ"] = "]",
	["ф"] = "a",
	["ы"] = "s",
	["в"] = "d",
	["а"] = "f",
	["п"] = "g",
	["р"] = "h",
	["о"] = "j",
	["л"] = "k",
	["д"] = "l",
	["ж"] = ";",
	["э"] = "'",
	["я"] = "z",
	["ч"] = "x",
	["с"] = "c",
	["м"] = "v",
	["и"] = "b",
	["т"] = "n",
	["ь"] = "m",
	["б"] = ",",
	["ю"] = ".",
	["ё"] = "`",
}

function ns.FromRussianLayout(text)
	return (ns.Lower(text):gsub("[\208\209][\128-\191]", RUSSIAN_LAYOUT))
end

local function printConfigHelp()
	local russian = ns.LOCALE == "ruRU"
	local lines = {
		{ "", nil, L["open the settings (also %s)"]:format("/ui, /агш, /гш") },
		{ L["<words>"], nil, L["search the settings in English or Russian"] },
		{ "unlock", "двигать", L["move frames"] },
		{ "lock", nil, L["lock frames"] },
		{ "reset", nil, L["move all frames back to the active layout"] },
		{ "setup", "мастер", L["run the setup again"] },
		{ "restore", "копии", L["backups of the profile"] },
		{ "debug", "отчёт", L["report for the developer"] },
		{ "perf", nil, L["measure the addon's event handlers"] },
		{ "help", "справка", L["this list"] },
	}
	ns.Print("%s", L["Commands:"])
	for _, line in ipairs(lines) do
		local command = line[1]
		if russian and line[2] then
			command = ("%s (%s)"):format(line[2], command)
		end
		print(("  |cffffffff/fui %s|r - %s"):format(command, line[3]))
	end
	print(("  |cffffffff/rl|r (/кд) - %s"):format(L["reload the UI"]))
end

local CONFIG_COMMANDS = {
	unlock = function()
		ns.Movers.Unlock()
	end,
	lock = function()
		ns.Movers.Lock()
	end,
	reset = function()
		ns.Movers.ConfirmResetPositions()
	end,
	restore = function()
		local host = ns.API.LoadSettings(true)
		if host then
			host.Toggle("profiles", "backups")
		else
			ns.ConfirmRestoreBackup()
		end
	end,
	setup = function()
		ns.RunSetup()
	end,
	debug = function()
		ns.ShowDebugReport()
	end,
	perf = function()
		ns.TogglePerf()
	end,
	help = function()
		printConfigHelp()
		local host = not InCombatLockdown() and ns.API.LoadSettings(true)
		if host then
			host.Toggle("help", "commands")
		end
	end,
}
CONFIG_COMMANDS.move = CONFIG_COMMANDS.unlock

local COMMAND_ALIASES = {
	["двигать"] = "unlock",
	["справка"] = "help",
	["помощь"] = "help",
	["копии"] = "restore",
	["мастер"] = "setup",
	["настройка"] = "setup",
	["отчёт"] = "debug",
	["отчет"] = "debug",
}

function ns.ParseConfigCommand(text)
	local word = ns.Lower(strtrim(text or ""))
	if CONFIG_COMMANDS[word] then
		return word
	elseif COMMAND_ALIASES[word] then
		return COMMAND_ALIASES[word]
	end
	local latin = ns.FromRussianLayout(word)
	if CONFIG_COMMANDS[latin] then
		return latin
	end
	return nil, word
end

SlashCmdList.FROSTATOMUI_CONFIG = function(text)
	local command, query = ns.ParseConfigCommand(text)
	if command then
		CONFIG_COMMANDS[command]()
		return
	end
	local host = ns.API.LoadSettings()
	if host then
		host.Toggle(query ~= "" and query or nil)
	end
end
SLASH_FROSTATOMUI_CONFIG1 = "/fui"
SLASH_FROSTATOMUI_CONFIG2 = "/frostatomui"
SLASH_FROSTATOMUI_CONFIG3 = "/faui"
SLASH_FROSTATOMUI_CONFIG4 = "/ui"
SLASH_FROSTATOMUI_CONFIG5 = "/агш"
SLASH_FROSTATOMUI_CONFIG6 = "/гш"
SLASH_FROSTATOMUI_CONFIG7 = "/АГШ"
SLASH_FROSTATOMUI_CONFIG8 = "/ГШ"

SlashCmdList.FROSTATOMUI_MOVE = function()
	if ns.Movers.IsUnlocked() then
		ns.Movers.Lock()
	else
		ns.Movers.Unlock()
	end
end
SLASH_FROSTATOMUI_MOVE1 = "/moveui"

local MENU_BUTTON_COLOR = { 0.09, 0.49, 0.75 }

local menuButton =
	CreateFrame("Button", "FrostAtomUIMenuButton", GameMenuFrame, "GameMenuButtonTemplate,SecureActionButtonTemplate")
menuButton:SetText("FrostAtom UI")
menuButton:SetPoint("TOP", GameMenuButtonUIOptions, "BOTTOM", 0, -1)
-- FrameXML: hiding the game menu from addon code taints it; a secure click on Continue closes it cleanly
menuButton:SetAttribute("type", "click")
menuButton:SetAttribute("clickbutton", GameMenuButtonContinue)
menuButton:SetScript("PostClick", function()
	SlashCmdList.FROSTATOMUI_CONFIG("")
end)
menuButton:GetFontString():SetTextColor(unpack(MENU_BUTTON_COLOR))
menuButton:HookScript("OnEnable", function(self)
	self:GetFontString():SetTextColor(unpack(MENU_BUTTON_COLOR))
end)

GameMenuButtonKeybindings:SetPoint("TOP", menuButton, "BOTTOM", 0, -1)
GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + menuButton:GetHeight() + 1)

local FOCUS_BUTTON_NAME = ns.FOCUS_BUTTON_NAME
local FOCUS_COMMAND = ns.FOCUS_BINDING
local FOCUS_LEGACY_KEY = ns.FOCUS_MOUSE_KEY

function ns.GetGameSettingChanges()
	local CVars = ns:GetModule("CVars")
	local list = {}
	for name, owner in pairs(GAME_SETTINGS) do
		local original = CVars:GetOriginal(name)
		if CVars:IsPinned(name) and original ~= nil and original ~= GetCVar(name) then
			list[#list + 1] =
				{ key = name, name = name, was = original, now = GetCVar(name), path = owner[1], off = owner[2] }
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	if ns.Config.general.uiScaleMode ~= "game" then
		list[#list + 1] = {
			key = "uiScale",
			path = "general.uiScaleMode",
			off = "game",
			was = ns:GetModule("CVars"):GetOriginal("uiScale") or GetCVar("uiScale"),
			now = ("%.2f"):format(UIParent:GetScale()),
		}
	end
	if focusDefaultedSlot:Get() and GetBindingAction(FOCUS_LEGACY_KEY) == FOCUS_COMMAND then
		list[#list + 1] = { key = FOCUS_LEGACY_KEY, binding = true }
	end
	return list
end

function ns.RestoreGameSettings(keys)
	if InCombatLockdown() then
		ns.Print(L["cannot change game settings in combat"])
		return false
	end
	local list = ns.GetGameSettingChanges()
	ns.Undo.Snapshot("gameSettings")
	ns.Undo.Run(L["Restore game settings"], function()
		for _, item in ipairs(list) do
			if keys[item.key] and item.binding then
				SetBinding(FOCUS_LEGACY_KEY)
				SaveBindings(GetCurrentBindingSet())
				focusDefaultedSlot:Set(nil)
			elseif keys[item.key] and ns:GetConfig(item.path) ~= item.off then
				ns:SetConfig(item.path, item.off)
			end
		end
	end)
	return true
end

BINDING_HEADER_FROSTATOMUI = "FrostAtom UI"

local ARENA_BINDINGS = 3
for i = 1, ARENA_BINDINGS do
	for _, action in ipairs({ "Target", "Focus" }) do
		local button = CreateFrame("Button", "FrostAtomUIArena" .. action .. i, nil, "SecureActionButtonTemplate")
		button:RegisterForClicks("AnyDown")
		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", ("/%s arena%d"):format(action:lower(), i))
	end
end

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
	BINDING_NAME_FROSTATOMUI_SETTINGS = L["Open the settings"]
	BINDING_NAME_FROSTATOMUI_MOVE = L["Move frames"]
	BINDING_NAME_FROSTATOMUI_KEYBIND = L["Key binding mode"]
	for i = 1, ARENA_BINDINGS do
		_G["BINDING_NAME_CLICK FrostAtomUIArenaTarget" .. i .. ":LeftButton"] = L["Target: arena opponent %d"]:format(i)
		_G["BINDING_NAME_CLICK FrostAtomUIArenaFocus" .. i .. ":LeftButton"] = L["Focus: arena opponent %d"]:format(i)
	end
end)

local snapFrame = CreateFrame("Frame")
local snapMax, snapFactor, snapDistance, snapTime, snapFrames, snapStopFrames, snapLocked, snapReplay
local snapOwnView

local function snapView()
	local view = tonumber(GetCVar("cameraView"))
	if view and view >= 1 and view <= 5 then
		-- 3.3.5: an instant SetView of the current view cancels the client's 2 s collision distance blend
		local blendStyle = GetCVar("cameraViewBlendStyle")
		SetCVar("cameraViewBlendStyle", "0")
		snapOwnView = true
		SetView(view)
		snapOwnView = nil
		SetCVar("cameraViewBlendStyle", blendStyle)
	end
end

local function releaseSnap()
	if not snapLocked then
		return
	end
	snapLocked = nil
	snapSlot:Set(nil)
	MoveViewInStop()
	MoveViewOutStop()
	snapStopFrames = snapFrames
end

local function finishSnap(self, elapsed)
	snapTime = snapTime + elapsed
	snapFrames = snapFrames + 1
	local max = GetCVar("cameraDistanceMax")
	if tonumber(max) ~= tonumber(snapDistance) then
		snapMax = max
	end
	SetCVar("cameraDistanceMax", snapDistance)

	if snapLocked and (not ns.Config.tweaks.instantCameraCollision or UnitInVehicle("player")) then
		releaseSnap()
	end
	if not snapStopFrames then
		if snapLocked then
			snapView()
		end
		if snapLocked or snapTime < CAMERA_SNAP_HOLD or snapFrames < CAMERA_SNAP_MIN_FRAMES then
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
	local replay = snapReplay
	snapReplay = nil
	if replay == "view" then
		local view = tonumber(GetCVar("cameraView"))
		if view and view >= 1 and view <= 5 then
			SetView(view)
		end
	elseif replay then
		replay.func(replay.amount)
	end
end

for _, name in ipairs({ "CameraZoomIn", "CameraZoomOut" }) do
	hooksecurefunc(name, function(amount)
		if snapLocked then
			releaseSnap()
			snapReplay = { func = _G[name], amount = amount }
		end
	end)
end

for _, name in ipairs({ "SetView", "NextView", "PrevView", "ResetView" }) do
	hooksecurefunc(name, function()
		if snapLocked and not snapOwnView then
			releaseSnap()
			snapReplay = "view"
		end
	end)
end

local function snapCamera(distance)
	if not snapTime then
		snapMax = GetCVar("cameraDistanceMax")
		snapFactor = GetCVar("cameraDistanceMaxFactor")
	end
	snapTime = 0
	snapFrames = 0
	snapStopFrames = nil
	snapReplay = nil
	snapDistance = tostring(distance)
	snapLocked = ns.Config.tweaks.enabled and ns.Config.tweaks.instantCameraCollision and not UnitInVehicle("player")
	snapSlot:Set(snapLocked and distance or nil)

	snapView()

	SetCVar("cameraDistanceMaxFactor", "1")
	SetCVar("cameraDistanceMax", snapDistance)
	MoveViewInStart(CAMERA_SNAP_SPEED)
	MoveViewOutStart(CAMERA_SNAP_SPEED)
	snapFrame:SetScript("OnUpdate", finishSnap)
end

function FrostAtomUI_SetCameraDistance(preset)
	local distance = ns.Config.tweaks["cameraDistance" .. preset]
	if distance then
		snapCamera(distance)
	end
end

local function restoreCameraSnap(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", restoreCameraSnap)

	local distance = snapSlot:Get()
	if distance and not snapTime and ns.Config.tweaks.enabled and ns.Config.tweaks.instantCameraCollision then
		snapCamera(distance)
	end
end

Tweaks:RegisterEvent("PLAYER_ENTERING_WORLD", restoreCameraSnap)

local function announceFocusKey(self)
	self:UnregisterEvent("UPDATE_BINDINGS", announceFocusKey)

	if not focusDefaultedSlot:Get() or focusAnnouncedSlot:Get() then
		return
	end
	focusAnnouncedSlot:Set(true)
	if GetBindingAction(FOCUS_LEGACY_KEY) == FOCUS_COMMAND then
		ns.Print(
			L["mouse button 5 sets focus to the unit under the cursor; change it in /fui → Game client → Controls"]
		)
	end
end

Tweaks:RegisterEvent("UPDATE_BINDINGS", announceFocusKey)
