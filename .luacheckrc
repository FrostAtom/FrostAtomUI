-- luacheck configuration (https://luacheck.readthedocs.io)
-- The game embeds Lua 5.1; the WoW API and FrameXML are globals.

std = "lua51"
max_line_length = false
exclude_files = { "node_modules/", "FrostAtomUI/Libs/" }

-- Code is loaded as an addon chunk: `local ADDON_NAME, ns = ...`
allow_defined_top = false
unused_args = false
ignore = { "421", "431", "432" }

read_globals = {
	-- Lua extensions provided by the client
	"bit", "date", "time", "wipe", "strsplit", "tinsert", "tremove", "hooksecurefunc",
	"CopyTable", "tContains", "getglobal", "setglobal",

	-- WoW API (only what the addon uses)
	"CreateFrame", "GetTime", "GetGameTime", "GetCVar", "SetCVar", "GetCVarDefault", "RegisterCVar", "InCombatLockdown", "PlaySoundFile",
	"GetFramerate", "GetNetStats",
	"CanGuildBankRepair", "GetGuildBankWithdrawMoney", "GetGuildBankMoney",
	"GetScreenWidth", "GetScreenHeight", "GetCursorPosition", "GetMouseFocus",
	"UIParent", "WorldFrame", "GameTooltip", "ItemRefTooltip",
	"ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
	"RegisterStateDriver", "RegisterUnitWatch", "UnregisterUnitWatch",
	"UnitClass", "UnitName", "UnitGUID", "UnitExists", "UnitIsUnit", "UnitIsPlayer",
	"UnitIsConnected", "UnitIsDeadOrGhost", "UnitAffectingCombat", "UnitInRaid",
	"UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType",
	"UnitAura", "UnitBuff", "UnitDebuff", "LibStub", "UnitCastingInfo", "UnitChannelInfo", "CancelUnitBuff",
	"GetSpellInfo", "GetSpellTexture", "GetItemInfo", "GetItemIcon",
	"COMBATLOG_OBJECT_TYPE_PLAYER", "COMBATLOG_OBJECT_TYPE_PET", "COMBATLOG_OBJECT_REACTION_HOSTILE",
	"GetActionTexture", "GetActionCooldown", "GetActionCount", "GetActionText",
	"HasAction", "IsActionInRange", "IsUsableAction", "IsEquippedAction", "IsCurrentAction",
	"IsAutoRepeatAction", "IsConsumableAction", "IsStackableAction", "PickupAction", "PlaceAction",
	"GetPetActionInfo", "GetPetActionCooldown", "GetPetActionSlotUsable",
	"GetNumShapeshiftForms", "GetShapeshiftForm", "GetShapeshiftFormInfo", "GetShapeshiftFormCooldown",
	"GetRuneType", "GetRuneCooldown",
	"GetWeaponEnchantInfo", "GetInventoryItemTexture", "CancelItemTempEnchantment",
	"GetBindingKey", "GetBindingByKey", "GetBindingAction", "GetBindingText", "SetBinding", "SetBindingClick", "SaveBindings", "LoadBindings",
	"GetCurrentBindingSet", "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown",
	"GetNumFriends", "GetFriendInfo", "GetPartyLeaderIndex", "IsPartyLeader",
	"UnitInParty", "GetNumRaidMembers", "GetRaidRosterInfo",
	"SendChatMessage", "SendSystemMessage", "IsInInstance", "GetZoneText",
	"GetNumBattlefieldScores", "GetBattlefieldScore", "GetBattlefieldTeamInfo",
	"GetBattlefieldWinner", "IsActiveBattlefieldArena", "GetBattlefieldStatus", "GetBattlefieldTimeWaited",
	"GetBattlefieldInstanceRunTime", "GetNumArenaOpponents", "GetRealZoneText", "AcceptBattlefieldPort", "LeaveBattlefield",
	"CombatLogClearEntries", "ToggleCalendar", "collectgarbage", "geterrorhandler", "GetLocale",
	"GetComboPoints", "UnitHasVehicleUI", "GetRaidTargetIndex", "SetRaidTargetIconTexture",
	"UnitInRange", "CheckInteractDistance", "UnitLevel", "UnitXP", "UnitXPMax", "GetXPExhaustion",
	"GetWatchedFactionInfo", "UnitCanAssist", "UnitCanAttack", "GetPlayerInfoByGUID", "UnitIsFeignDeath",
	"IsResting", "UnitIsPVP", "UnitIsPVPFreeForAll", "UnitFactionGroup", "GetTotemInfo",
	"RequestBattlefieldScoreData", "UnitReaction", "GetGuildInfo", "GetItemCount",
	"CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "GetMoney", "GetContainerNumSlots",
	"GetContainerItemLink", "GetContainerItemInfo", "UseContainerItem", "GetNumGuildMembers",
	"GetGuildRosterInfo", "GetNumPartyMembers", "AcceptGroup", "IsInGuild", "GuildRoster",
	"GetInventoryItemLink", "GetInventoryItemID", "GetInventoryItemDurability", "RaidNotice_AddMessage", "IsAddOnLoaded", "LoadAddOn",
	"GetContainerNumFreeSlots", "GetContainerItemID", "GetContainerItemCooldown", "GetContainerItemQuestInfo",
	"GetItemQualityColor", "IsInventoryItemLocked", "ContainerIDToInventoryID", "BankButtonIDToInvSlotID",
	"GetNumBankSlots", "GetBankSlotCost", "CursorHasItem", "PutItemInBag", "PutItemInBackpack",
	"PickupBagFromSlot", "CloseBankFrame", "PlaySound", "SetItemButtonTexture", "SetItemButtonCount",
	"SetItemButtonDesaturated", "BACKPACK_CONTAINER", "BANK_CONTAINER", "NUM_BANKBAGSLOTS",
	"NUM_BANKGENERIC_SLOTS", "BANK", "BACKPACK_TOOLTIP", "BANK_BAG_PURCHASE", "EQUIP_CONTAINER",
	"GetItemFamily", "GetAuctionItemClasses", "GetAuctionItemSubClasses", "GetCursorInfo",
	"PickupContainerItem", "SplitContainerItem", "GetBackpackCurrencyInfo", "MAX_WATCHED_TOKENS",
	"BackpackTokenFrame_Update", "GameTooltip_Hide",
	"GetRealmName", "strtrim", "ClearOverrideBindings", "SetOverrideBindingClick",

	-- FrameXML functions
	"CooldownFrame_SetTimer", "GameTooltip_SetDefaultAnchor", "UnitFrame_OnEnter", "UnitFrame_OnLeave", "Minimap_OnClick",
	"ChatEdit_UpdateHeader", "ChatFrame_AddMessageEventFilter", "ChatFrame_RemoveMessageEventFilter",
	"SetChatColorNameByClass",
	"StaticPopup_Show", "StaticPopup_Hide", "ToggleDropDownMenu", "UIDropDownMenu_Initialize",
	"UIDropDownMenu_CreateInfo", "UIDropDownMenu_SetWidth",
	"StaticPopup_Visible", "StaticPopup_FindVisible", "ContainerFrameItemButton_OnEnter",
	"FCFOptionsDropDown_Initialize", "FCF_SetLocked", "LFDQueueFrameRandomCooldownFrame_Update",
	"ScrollingEdit_OnTextChanged", "ScrollingEdit_OnCursorChanged", "ScrollingEdit_OnUpdate",
	"WorldMap_GetVehicleTexture", "WorldMapFrame_UpdateQuests", "WorldMapButton_OnClick",
	"BattlefieldMinimap_OnUpdate",
	"UIDropDownMenu_SetSelectedValue", "UIDropDownMenu_SetText", "YES", "NO",
	"DEAD", "AFK", "DND", "FRIENDS_LIST_OFFLINE", "INTERRUPTED", "FAILED", "UNKNOWN",
	"UnitPopup_ShowMenu", "FauxScrollFrame_Update", "FauxScrollFrame_OnVerticalScroll",
	"FauxScrollFrame_GetOffset", "FauxScrollFrame_SetOffset",
	"UIDropDownMenu_EnableDropDown", "UIDropDownMenu_DisableDropDown",
	"PanelTemplates_TabResize", "PanelTemplates_SetTab", "PanelTemplates_SetNumTabs",
	"PanelTemplates_EnableTab", "PanelTemplates_DisableTab",
	"GameFontHighlightSmall", "GameFontHighlightLeft", "GameFontDisableLeft",
	"ShowUIPanel", "HideUIPanel", "HideParentPanel", "PVPFrame",

	-- FrameXML tables & constants
	"UIDROPDOWNMENU_INIT_MENU", "UIDROPDOWNMENU_MENU_LEVEL", "UIDROPDOWNMENU_MAXLEVELS", "RAID_CLASS_COLORS", "PowerBarColor", "DebuffTypeColor", "RAID_TARGET_ICON",
	"NUM_ACTIONBAR_BUTTONS", "NUM_PET_ACTION_SLOTS", "NUM_SHAPESHIFT_SLOTS", "NUM_BAG_SLOTS",
	"VEHICLE_MAX_ACTIONBUTTONS", "MAX_PARTY_MEMBERS", "NUM_CHAT_WINDOWS", "MAX_COMBO_POINTS",
	"MAX_BOSS_FRAMES", "MAX_PLAYER_LEVEL", "FACTION_BAR_COLORS", "CLOSE", "MAX_TOTEMS",
	"MAX_BATTLEFIELD_QUEUES", "LEAVE_QUEUE", "ENTER_BATTLE", "LEAVE_ARENA",
	"STATICPOPUP_NUMDIALOGS", "DELETE_ITEM_CONFIRM_STRING", "SELECTED_DOCK_FRAME",
	"WORLDMAP_SETTINGS", "WORLDMAP_WINDOWED_SIZE", "WorldMap_ToggleSizeUp", "ToggleMapFramerate",
	"WorldMapBlobFrame_CalculateHitTranslations",
	"VEHICLE_TEXTURES", "NUM_WORLDMAP_FLAGS", "WORLDMAP_POI_FRAMELEVEL", "WORLDMAP_WORLD_ID",
	"STANDARD_TEXT_FONT", "COPPER_PER_GOLD", "COPPER_PER_SILVER", "ICON_TAG_LIST", "ICON_LIST",
	"LOCK_WINDOW", "UNLOCK_WINDOW", "DEFAULT_CHAT_FRAME", "PLAYER_LIST_DELIMITER", "ERR_BG_PLAYER_JOINED_SS",
	"ERR_PLAYER_LEFT_BATTLE_D", "ERR_PLAYERLIST_LEFT_BATTLE", "ERR_PLAYERS_LEFT_BATTLE_D",
	"ERR_PLAYER_JOINED_BATTLE_D", "ERR_PLAYERLIST_JOINED_BATTLE", "ERR_PLAYERS_JOINED_BATTLE_D",
	"ERR_DUEL_CANCELLED", "ERR_TRADE_CANCELLED", "ARENA_COMPLETE_MESSAGE", "BATTLEGROUND_COMPLETE_MESSAGE",
	"MAX_ACCOUNT_MACROS", "MAX_CHARACTER_MACROS", "NUM_ACTIONBAR_PAGES",
	"SLASH_USE1", "SLASH_EQUIP1", "SLASH_CAST1", "SLASH_EQUIP_SET1",
	"NUM_EXTENDED_UI_FRAMES", "MERCHANT_ITEMS_PER_PAGE", "BUYBACK_ITEMS_PER_PAGE",
	"COPY_NAME", "PVP_REPORT_AFK", "LOCALIZED_CLASS_NAMES_MALE",
	"CAMERA_SMART", "CAMERA_SMARTER", "CAMERA_ALWAYS", "CAMERA_NEVER",
	"ERR_SET_LOOT_FREEFORALL", "ERR_SET_LOOT_GROUP", "ERR_SET_LOOT_MASTER", "ERR_SET_LOOT_ROUNDROBIN",
	"ERR_SET_LOOT_THRESHOLD_S", "ERR_RAID_YOU_JOINED", "ERR_RAID_YOU_LEFT", "ERR_RAID_MEMBER_ADDED_S",
	"ERR_RAID_MEMBER_REMOVED_S", "ERR_BG_PLAYER_LEFT_S", "ERR_PLAYER_DIED_S", "ERR_LEFT_GROUP_S",
	"ERR_NEW_LEADER_YOU", "ERR_NEW_LEADER_S",
	"PVP_ENABLED", "FACTION_ALLIANCE", "FACTION_HORDE", "ITEM_QUALITY3_DESC", "ITEM_QUALITY_COLORS",
	"CLASS_ICON_TCOORDS", "MAX_RAID_MEMBERS", "FOREIGN_SERVER_LABEL", "CHAT_FLAG_AFK", "CHAT_FLAG_DND",
	"PLAYER_OFFLINE", "TOOLTIP_DEFAULT_COLOR", "ITEM_LEVEL",
	"strjoin", "ChatEdit_InsertLink", "SPELLBOOK", "BOOKTYPE_SPELL", "BOOKTYPE_PET", "PET", "ERR_NOT_IN_COMBAT",
	"PASSIVE_SPELL_FONT_COLOR",
	"TALENTS", "TALENT_SPEC_PRIMARY", "TALENT_SPEC_SECONDARY", "TALENT_SPEC_PET_PRIMARY", "TALENT_SPEC_ACTIVATE",
	"TALENT_ACTIVATION_SPELLS", "GLYPHS", "RESET", "LEARN", "UNSPENT_TALENT_POINTS", "CONFIRM_LEARN_PREVIEW_TALENTS",
	"SHOW_TALENT_LEVEL", "SHOW_INSCRIPTION_LEVEL", "CONFIRM_REMOVE_GLYPH", "CONFIRM_GLYPH_PLACEMENT",
	"GLYPH_LOCKED", "GLYPH_EMPTY", "TalentFrame_UpdateSpecInfoCache", "TALENT_HYBRID_ICON",
	"TALENT_ACTIVE_SPEC_STATUS", "TALENT_TOOLTIP_RESETTALENTGROUP", "TALENT_TOOLTIP_LEARNTALENTGROUP",
	"GREEN_FONT_COLOR", "NORMAL_FONT_COLOR", "GRAY_FONT_COLOR", "HIGHLIGHT_FONT_COLOR",
	"HIGHLIGHT_FONT_COLOR_CODE", "FONT_COLOR_CODE_CLOSE",
	"GRAY_FONT_COLOR_CODE", "GREEN_FONT_COLOR_CODE", "RED_FONT_COLOR_CODE", "NORMAL_FONT_COLOR_CODE",
	"WhoFrameColumn_SetWidth",
	"RED_FONT_COLOR", "ORANGE_FONT_COLOR", "ORANGE_FONT_COLOR_CODE", "TOOLTIP_DEFAULT_BACKGROUND_COLOR",
	"MACROFRAME_CHAR_LIMIT", "MACRO_POPUP_TEXT", "MACRO_POPUP_CHOOSE_ICON", "CHANGE_MACRO_NAME_ICON",
	"ENTER_MACRO_LABEL", "OKAY", "CANCEL", "EXIT", "NEW", "DELETE", "ScrollFrameTemplate_OnMouseWheel",
}

-- Frames and globals the addon deliberately writes to.
globals = {
	"FrostAtomUIDB", "FrostAtomUI", "FrostAtomUI_Config",
	-- FrameXML tables the addon extends
	"SlashCmdList", "StaticPopupDialogs", "UnitPopupButtons", "UnitPopupMenus",
	"UIPARENT_MANAGED_FRAME_POSITIONS", "MultiCastActionBarFrame", "UISpecialFrames",
	"ChatTypeInfo", "UIPanelWindows", "CHAT_FONT_HEIGHTS", "Minimap", "WorldMapPing", "MAP_VEHICLES",
	"UIDropDownMenu_AddButton", "FCF_ToggleLock", "ShowMacroFrame",
	-- overridden Blizzard functions
	"MainMenuBarVehicleLeaveButton_Update", "TalentFrame_LoadUI", "Arena_LoadUI",
	"TimeManager_LoadUI", "CombatLog_LoadUI", "Blizzard_CombatLog_Update_QuickButtons",
	"Minimap_UpdateRotationSetting", "UnitPopup_OnClick", "ChatEdit_OnSpacePressed", "SetItemRef",
	"InspectPaperDollItemSlotButton_Update", "GetMinimapShape",
	"ToggleSpellBook", "ToggleTalentFrame", "ToggleGlyphFrame", "OpenGlyphFrame",
	"ToggleBag", "ToggleBackpack", "OpenBackpack", "CloseBackpack", "OpenAllBags", "CloseAllBags", "IsBagOpen",
	-- chat constants
	"CHAT_FRAME_FADE_OUT_TIME", "CHAT_TAB_HIDE_DELAY",
	"CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA",
	-- slash commands and key bindings
	"SLASH_RELOAD2", "BINDING_HEADER_FROSTATOMUI",
	"BINDING_NAME_FROSTATOMUI_CAMERA_CLOSE", "BINDING_NAME_FROSTATOMUI_CAMERA_MEDIUM",
	"BINDING_NAME_FROSTATOMUI_CAMERA_FAR", "FrostAtomUI_SetCameraDistance",
	-- action bars
	"AutoCastShine_AutoCastStart", "AutoCastShine_AutoCastStop", "LEAVE_VEHICLE",
}

-- Blizzard frames are accessed as globals; anything in CamelCase that is not
-- listed above is assumed to be one of them.
files["FrostAtomUI/Modules/**/*.lua"] = {
	ignore = {
		"113/[A-Z][A-Za-z0-9]+", -- accessing undefined variable (frame globals)
		"111/SLASH_FROSTATOMUI_.*", -- setting undefined variable (slash commands)
	},
}

files["FrostAtomUI/Modules/InternalCooldowns.lua"] = {
	ignore = { "113/[A-Z][A-Za-z0-9]+", "331/memory" },
}

files["FrostAtomUI_Config/**/*.lua"] = {
	ignore = {
		"113/[A-Z][A-Za-z0-9]+", -- accessing undefined variable (frame globals)
	},
	read_globals = {
		"UIDropDownMenu_EnableDropDown", "UIDropDownMenu_DisableDropDown", "ReloadUI", "ScrollFrame_OnScrollRangeChanged",
	},
	globals = { "ColorPickerFrame" },
}
