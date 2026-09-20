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
	"GetSpellInfo", "GetSpellTexture", "GetItemInfo", "GetItemIcon",
	"COMBATLOG_OBJECT_TYPE_PLAYER", "COMBATLOG_OBJECT_TYPE_PET",
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
	"GetComboPoints", "UnitHasVehicleUI", "GetRaidTargetIndex", "SetRaidTargetIconTexture",
	"UnitInRange", "CheckInteractDistance", "UnitLevel", "UnitXP", "UnitXPMax", "GetXPExhaustion",
	"GetWatchedFactionInfo", "UnitCanAssist",
	"IsResting", "UnitIsPVP", "UnitIsPVPFreeForAll", "UnitFactionGroup", "GetTotemInfo",
	"RequestBattlefieldScoreData", "UnitReaction", "GetGuildInfo", "GetItemCount",
	"CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "GetMoney", "GetContainerNumSlots",
	"GetContainerItemLink", "GetContainerItemInfo", "UseContainerItem", "GetNumGuildMembers",
	"GetGuildRosterInfo", "GetNumPartyMembers", "AcceptGroup", "IsInGuild", "GuildRoster",
	"GetInventoryItemLink", "GetInventoryItemDurability", "RaidNotice_AddMessage", "IsAddOnLoaded",
	"GetContainerNumFreeSlots", "GetContainerItemID", "GetContainerItemCooldown", "GetContainerItemQuestInfo",
	"GetItemQualityColor", "IsInventoryItemLocked", "ContainerIDToInventoryID", "BankButtonIDToInvSlotID",
	"GetNumBankSlots", "GetBankSlotCost", "CursorHasItem", "PutItemInBag", "PutItemInBackpack",
	"PickupBagFromSlot", "CloseBankFrame", "PlaySound", "SetItemButtonTexture", "SetItemButtonCount",
	"SetItemButtonDesaturated", "BACKPACK_CONTAINER", "BANK_CONTAINER", "NUM_BANKBAGSLOTS",
	"NUM_BANKGENERIC_SLOTS", "BANK", "BACKPACK_TOOLTIP", "BANK_BAG_PURCHASE", "EQUIP_CONTAINER",
	"GetItemFamily", "GetAuctionItemClasses", "GetAuctionItemSubClasses", "GetCursorInfo",
	"PickupContainerItem", "SplitContainerItem", "GetBackpackCurrencyInfo", "MAX_WATCHED_TOKENS",
	"BackpackTokenFrame_Update", "GameTooltip_Hide",

	-- Server-specific API (WoWCircle)
	"FlashWindow",

	-- FrameXML functions
	"CooldownFrame_SetTimer", "GameTooltip_SetDefaultAnchor", "UnitFrame_OnEnter", "UnitFrame_OnLeave", "Minimap_OnClick",
	"ChatEdit_UpdateHeader", "ChatFrame_AddMessageEventFilter", "ChatFrame_RemoveMessageEventFilter",
	"ChatTypeInfo", "SetChatColorNameByClass",
	"StaticPopup_Show", "StaticPopup_Hide", "ToggleDropDownMenu", "UIDropDownMenu_Initialize",
	"UnitPopup_ShowMenu",

	-- FrameXML tables & constants
	"UIDROPDOWNMENU_INIT_MENU", "RAID_CLASS_COLORS", "PowerBarColor", "DebuffTypeColor", "RAID_TARGET_ICON",
	"NUM_ACTIONBAR_BUTTONS", "NUM_PET_ACTION_SLOTS", "NUM_SHAPESHIFT_SLOTS", "NUM_BAG_SLOTS",
	"VEHICLE_MAX_ACTIONBUTTONS", "MAX_PARTY_MEMBERS", "NUM_CHAT_WINDOWS", "MAX_COMBO_POINTS",
	"MAX_BOSS_FRAMES", "MAX_PLAYER_LEVEL", "FACTION_BAR_COLORS", "CLOSE", "MAX_TOTEMS",
	"STATICPOPUP_NUMDIALOGS", "DELETE_ITEM_CONFIRM_STRING", "SELECTED_DOCK_FRAME",
	"WORLDMAP_SETTINGS", "WORLDMAP_WINDOWED_SIZE", "WorldMap_ToggleSizeUp", "ToggleMapFramerate",
	"WorldMapBlobFrame_CalculateHitTranslations", "UIPanelWindows",
	"ERR_SET_LOOT_FREEFORALL", "ERR_SET_LOOT_GROUP", "ERR_SET_LOOT_MASTER", "ERR_SET_LOOT_ROUNDROBIN",
	"ERR_SET_LOOT_THRESHOLD_S", "ERR_RAID_YOU_JOINED", "ERR_RAID_YOU_LEFT", "ERR_RAID_MEMBER_ADDED_S",
	"ERR_RAID_MEMBER_REMOVED_S", "ERR_BG_PLAYER_LEFT_S", "ERR_PLAYER_DIED_S", "ERR_LEFT_GROUP_S",
}

-- Frames and globals the addon deliberately writes to.
globals = {
	"FrostAtomUIDB",
	-- FrameXML tables the addon extends
	"SlashCmdList", "StaticPopupDialogs", "UnitPopupButtons", "UnitPopupMenus",
	"UIPARENT_MANAGED_FRAME_POSITIONS", "MultiCastActionBarFrame", "UISpecialFrames",
	-- overridden Blizzard functions
	"MainMenuBarVehicleLeaveButton_Update", "TalentFrame_LoadUI", "Arena_LoadUI",
	"TimeManager_LoadUI", "CombatLog_LoadUI", "Blizzard_CombatLog_Update_QuickButtons",
	"Minimap_UpdateRotationSetting", "UnitPopup_OnClick", "ChatEdit_OnSpacePressed", "SetItemRef",
	"InspectPaperDollItemSlotButton_Update",
	"ToggleBag", "ToggleBackpack", "OpenBackpack", "CloseBackpack", "OpenAllBags", "CloseAllBags", "IsBagOpen",
	-- chat constants
	"CHAT_FRAME_FADE_OUT_TIME", "CHAT_TAB_HIDE_DELAY",
	"CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA",
	"CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA", "CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA",
	-- slash commands and key bindings
	"SLASH_RELOAD2", "BINDING_HEADER_FROSTATOMUI",
}

-- Blizzard frames are accessed as globals; anything in CamelCase that is not
-- listed above is assumed to be one of them.
files["Modules/**/*.lua"] = {
	ignore = {
		"113/[A-Z][A-Za-z0-9]+", -- accessing undefined variable (frame globals)
		"111/SLASH_FROSTATOMUI_.*", -- setting undefined variable (slash commands)
	},
}
