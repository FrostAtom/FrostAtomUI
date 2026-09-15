-- luacheck configuration (https://luacheck.readthedocs.io)
-- The game embeds Lua 5.1; the WoW API and FrameXML are globals.

std = "lua51"
max_line_length = 120
exclude_files = { "node_modules/" }

-- Code is loaded as an addon chunk: `local ADDON_NAME, ns = ...`
allow_defined_top = false
unused_args = false

read_globals = {
	-- Lua extensions provided by the client
	"bit", "date", "wipe", "strsplit", "tinsert", "tremove", "hooksecurefunc",
	"CopyTable", "tContains", "getglobal", "setglobal",

	-- WoW API (only what the addon uses)
	"CreateFrame", "GetTime", "GetGameTime", "GetCVar", "SetCVar", "InCombatLockdown",
	"GetFramerate", "GetNetStats",
	"GetScreenWidth", "GetScreenHeight", "GetCursorPosition", "GetMouseFocus",
	"UIParent", "WorldFrame", "Minimap", "GameTooltip", "ItemRefTooltip",
	"ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
	"RegisterStateDriver", "RegisterUnitWatch",
	"UnitClass", "UnitName", "UnitGUID", "UnitExists", "UnitIsUnit", "UnitIsPlayer",
	"UnitIsConnected", "UnitIsDeadOrGhost", "UnitAffectingCombat", "UnitInRaid",
	"UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType",
	"UnitAura", "UnitBuff", "UnitCastingInfo", "UnitChannelInfo", "CancelUnitBuff",
	"GetSpellInfo", "GetItemInfo", "GetItemIcon",
	"GetActionTexture", "GetActionCooldown", "GetActionCount", "GetActionText",
	"HasAction", "IsActionInRange", "IsUsableAction", "IsEquippedAction", "IsCurrentAction",
	"IsAutoRepeatAction", "IsConsumableAction", "IsStackableAction", "PickupAction", "PlaceAction",
	"GetPetActionInfo", "GetPetActionCooldown", "GetPetActionSlotUsable",
	"GetNumShapeshiftForms", "GetShapeshiftForm", "GetShapeshiftFormInfo", "GetShapeshiftFormCooldown",
	"GetRuneType", "GetRuneCooldown",
	"GetWeaponEnchantInfo", "GetInventoryItemTexture", "CancelItemTempEnchantment",
	"GetBindingKey", "GetBindingByKey", "SetBinding", "SetBindingClick", "SaveBindings", "LoadBindings",
	"GetCurrentBindingSet", "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown",
	"GetNumFriends", "GetFriendInfo", "GetPartyLeaderIndex", "IsPartyLeader",
	"UnitInParty", "GetNumRaidMembers", "GetRaidRosterInfo",
	"SendChatMessage", "SendSystemMessage", "IsInInstance", "GetZoneText",
	"GetNumBattlefieldScores", "GetBattlefieldScore", "GetBattlefieldTeamInfo",
	"GetBattlefieldWinner", "IsActiveBattlefieldArena",
	"CombatLogClearEntries", "ToggleCalendar", "collectgarbage", "geterrorhandler", "GetLocale",

	-- Server-specific API (WoWCircle)
	"FlashWindow",

	-- FrameXML functions
	"CooldownFrame_SetTimer", "UnitFrame_OnEnter", "UnitFrame_OnLeave", "Minimap_OnClick",
	"ChatEdit_UpdateHeader", "ChatFrame_AddMessageEventFilter", "ChatFrame_RemoveMessageEventFilter",
	"ChatTypeInfo", "SetChatColorNameByClass",
	"StaticPopup_Show", "StaticPopup_Hide", "ToggleDropDownMenu", "UIDropDownMenu_Initialize",
	"UnitPopup_ShowMenu",

	-- FrameXML tables & constants
	"UIDROPDOWNMENU_INIT_MENU", "RAID_CLASS_COLORS", "PowerBarColor", "DebuffTypeColor", "RAID_TARGET_ICON",
	"NUM_ACTIONBAR_BUTTONS", "NUM_PET_ACTION_SLOTS", "NUM_SHAPESHIFT_SLOTS", "NUM_BAG_SLOTS",
	"VEHICLE_MAX_ACTIONBUTTONS", "MAX_PARTY_MEMBERS", "NUM_CHAT_WINDOWS",
}

-- Frames and globals the addon deliberately writes to.
globals = {
	"FrostAtomUIDB",
	-- FrameXML tables the addon extends
	"SlashCmdList", "StaticPopupDialogs", "UnitPopupButtons", "UnitPopupMenus",
	"UIPARENT_MANAGED_FRAME_POSITIONS", "MultiCastActionBarFrame",
	-- overridden Blizzard functions
	"MainMenuBarVehicleLeaveButton_Update", "TalentFrame_LoadUI", "Arena_LoadUI",
	"TimeManager_LoadUI", "CombatLog_LoadUI", "Blizzard_CombatLog_Update_QuickButtons",
	"Minimap_UpdateRotationSetting", "UnitPopup_OnClick", "ChatEdit_OnSpacePressed",
	-- chat constants
	"CHAT_FRAME_FADE_OUT_TIME", "CHAT_TAB_HIDE_DELAY",
	"CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA",
	-- slash commands
	"SLASH_RELOAD2",
}

-- Blizzard frames are accessed as globals; anything in CamelCase that is not
-- listed above is assumed to be one of them.
files["Modules/**/*.lua"] = {
	ignore = {
		"113/[A-Z][A-Za-z0-9]+", -- accessing undefined variable (frame globals)
		"111/SLASH_FROSTATOMUI_.*", -- setting undefined variable (slash commands)
	},
}
