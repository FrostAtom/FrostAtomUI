-- luacheck configuration (https://luacheck.readthedocs.io)
-- The game embeds Lua 5.1; the WoW API and FrameXML are globals.

stds.wow335 = require("tools.luacheck_std_wow335")
std = "lua51+wow335"
max_line_length = false
exclude_files = { "node_modules/", "FrostAtomUI/Libs/" }

-- Code is loaded as an addon chunk: `local ADDON_NAME, ns = ...`
allow_defined_top = false
unused_args = false
ignore = { "421", "431", "432" }

read_globals = {
	"LibStub", "ChatThrottleLib", "FrostAtomUIMenuButton", "CUSTOM_CLASS_COLORS",
}

-- Frames and globals the addon deliberately writes to.
globals = {
	"FrostAtomUIDB", "FrostAtomUI", "FrostAtomUI_Config",
	-- FrameXML tables the addon extends
	"SlashCmdList", "StaticPopupDialogs", "UnitPopupButtons", "UnitPopupMenus",
	"UIPARENT_MANAGED_FRAME_POSITIONS", "MultiCastActionBarFrame", "UISpecialFrames",
	"ChatTypeInfo", "UIPanelWindows", "CHAT_FONT_HEIGHTS", "Minimap", "WorldMapPing", "MAP_VEHICLES",
	"UIDropDownMenu_AddButton", "FCF_ToggleLock", "ShowMacroFrame",
	"BankFrame", "MerchantFrame", "GENERAL_CHAT_DOCK", "MultiCastSummonSpellButton", "InspectUnit",
	"WorldMapFrame", "WorldMapBlobFrame", "UnitPopupShown",
	-- overridden Blizzard functions
	"MainMenuBarVehicleLeaveButton_Update", "TalentFrame_LoadUI", "GlyphFrame_LoadUI", "Arena_LoadUI",
	"TimeManager_LoadUI", "CombatLog_LoadUI", "Blizzard_CombatLog_Update_QuickButtons",
	"Minimap_UpdateRotationSetting", "UnitPopup_OnClick", "ChatEdit_OnSpacePressed", "SetItemRef",
	"InspectPaperDollItemSlotButton_Update", "GetMinimapShape",
	"ToggleSpellBook", "ToggleTalentFrame", "ToggleGlyphFrame", "OpenGlyphFrame",
	"ToggleBag", "ToggleBackpack", "OpenBackpack", "CloseBackpack", "OpenAllBags", "CloseAllBags",
	-- chat constants
	"CHAT_FRAME_FADE_OUT_TIME", "CHAT_TAB_HIDE_DELAY",
	"CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA",
	-- slash commands and key bindings
	"SLASH_RELOAD2", "BINDING_HEADER_FROSTATOMUI",
	"BINDING_NAME_FROSTATOMUI_CAMERA_CLOSE", "BINDING_NAME_FROSTATOMUI_CAMERA_MEDIUM",
	"BINDING_NAME_FROSTATOMUI_CAMERA_FAR", "FrostAtomUI_SetCameraDistance",
	"BINDING_NAME_FROSTATOMUI_SETTINGS", "BINDING_NAME_FROSTATOMUI_MOVE", "BINDING_NAME_FROSTATOMUI_KEYBIND",
	-- action bars
	"AutoCastShine_AutoCastStart", "AutoCastShine_AutoCastStop", "LEAVE_VEHICLE",
}

files["FrostAtomUI/Modules/**/*.lua"] = {
	ignore = {
		"111/SLASH_FROSTATOMUI_.*", -- setting undefined variable (slash commands)
	},
}

files["FrostAtomUI/Modules/InternalCooldowns.lua"] = {
	ignore = { "331/memory" },
}

files["tests/**/*.lua"] = {
	allow_defined_top = true,
	ignore = { "111", "112", "113", "121", "122", "131", "142", "143" },
}

files["FrostAtomUI_Config/**/*.lua"] = {
	globals = { "ColorPickerFrame" },
}
