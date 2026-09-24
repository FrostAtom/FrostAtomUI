local _, ns = ...

local L = ns.L

local IsAddOnLoaded, IsAddOnLoadOnDemand, GetAddOnInfo = IsAddOnLoaded, IsAddOnLoadOnDemand, GetAddOnInfo
local DisableAddOn, ReloadUI = DisableAddOn, ReloadUI
local StaticPopup_Show, StaticPopup_Visible = StaticPopup_Show, StaticPopup_Visible
local tremove = table.remove

local POPUP = "FROSTATOMUI_CONFLICT"
local SCAN_DELAY = 5
local LOAD_DELAY = 2
local NEXT_DELAY = 0.3
local MAX_BUTTON_NAME = 12

local ACTION_BARS = { "Action bars", "actionBar.enabled" }
local UNIT_FRAMES = { "Unit frames", "unitFrames.enabled" }
local ARENA_FRAMES = { "Arena frames", "unitFrames.showArena" }
local NAMEPLATES = { "Nameplates", "namePlates.enabled" }
local BAGS = { "Bags", "bags.enabled" }
local CHAT = { "Chat", "chat.enabled" }
local MINIMAP = { "Minimap", "minimap.enabled" }
local WHOLE_UI = { "most modules" }

local REGISTRY = {
	{ "Bartender4", ACTION_BARS },
	{ "Dominos", ACTION_BARS },
	{ "ShadowedUnitFrames", UNIT_FRAMES },
	{ "PitBull4", UNIT_FRAMES },
	{ "XPerl", UNIT_FRAMES },
	{ "oUF_Abu", UNIT_FRAMES },
	{ "Gladius", ARENA_FRAMES },
	{ "sArena", ARENA_FRAMES },
	{ "Gladdy", ARENA_FRAMES },
	{ "TidyPlates", NAMEPLATES },
	{ "Aloft", NAMEPLATES },
	{ "Kui_Nameplates", NAMEPLATES },
	{ "LoseControl", { "Loss of control", "lossOfControl.enabled" } },
	{ "DRTracker", { "Diminishing returns", "diminishingReturns.enabled" } },
	{ "DiminishingReturns", { "Diminishing returns", "diminishingReturns.enabled" } },
	{ "InternalCooldowns", { "Trinket internal cooldowns", "internalCooldowns.enabled" } },
	{ "OmniCC", { "Cooldown timers" } },
	{ "Quartz", { "Player castbar", "unitFrames.showPlayerCastbar" } },
	{ "TipTac", { "Tooltip", "tooltip.enabled" } },
	{ "Bagnon", BAGS },
	{ "AdiBags", BAGS },
	{ "ArkInventory", BAGS },
	{ "Combuctor", BAGS },
	{ "OneBag3", BAGS },
	{ "Prat-3.0", CHAT },
	{ "Chatter", CHAT },
	{ "SexyMap", MINIMAP },
	{ "Chinchilla", MINIMAP },
	{ "Mapster", { "World map", "worldMap.enabled" } },
	{ "ElvUI", WHOLE_UI },
	{ "Tukui", WHOLE_UI },
}

local Conflicts = ns:NewModule("Conflicts")

local queue = {}
local queued = {}
local current

local function choices()
	local store = ns.db.conflicts
	if not store then
		store = {}
		ns.db.conflicts = store
	end
	return store
end

local function remember(addon, choice)
	choices()[addon] = choice
end

local function overlaps(entry)
	local path = entry[2][2]
	return not path or ns:GetConfig(path) ~= false
end

local showNext

local function finish()
	current = nil
	ns.After(NEXT_DELAY, showNext)
end

StaticPopupDialogs[POPUP] = {
	text = "%s",
	button1 = "",
	button2 = "",
	button3 = "",
	OnAccept = function(_, entry)
		remember(entry[1], "theirs")
		DisableAddOn(entry[1])
		ReloadUI()
	end,
	OnAlt = function(_, entry)
		remember(entry[1], "ours")
		ns:SetConfig(entry[2][2], false)
		ReloadUI()
	end,
	OnCancel = function(_, entry, reason)
		if reason == "clicked" and entry then
			remember(entry[1], "keep")
		end
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
		finish()
	end,
	DisplayButton3 = function()
		return current ~= nil and current[2][2] ~= nil
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
	preferredIndex = 3,
}

local function popupText(entry)
	local addon, module = entry[1], L[entry[2][1]]
	local text = L["%s overlaps FrostAtom UI's %s."]:format(addon, module)
	if entry[2][2] then
		return text .. "\n\n" .. L["Disable one of them, or keep both and stop asking."]
	end
	return text .. "\n\n" .. L["Disable it, or keep both and stop asking."]
end

function showNext()
	if current or StaticPopup_Visible(POPUP) then
		return
	end
	local entry
	repeat
		entry = tremove(queue, 1)
	until not entry or (not choices()[entry[1]] and overlaps(entry))
	if not entry then
		return
	end
	local dialog = StaticPopupDialogs[POPUP]
	local addon = entry[1]
	dialog.button1 = #addon <= MAX_BUTTON_NAME and L["Disable %s"]:format(addon) or L["Disable it"]
	dialog.button2 = L["Keep both"]
	dialog.button3 = L["Disable ours"]
	current = entry
	local shown = StaticPopup_Show(POPUP, popupText(entry), nil, entry)
	if shown then
		shown:SetFrameStrata("FULLSCREEN_DIALOG")
	else
		current = nil
	end
end

local function enqueue(entry)
	local addon = entry[1]
	if queued[addon] or choices()[addon] then
		return
	end
	queued[addon] = true
	queue[#queue + 1] = entry
end

local function scan()
	for i = 1, #REGISTRY do
		if IsAddOnLoaded(REGISTRY[i][1]) then
			enqueue(REGISTRY[i])
		end
	end
	showNext()
end

local function watchLoadOnDemand(entry)
	local addon = entry[1]
	local name, _, _, enabled = GetAddOnInfo(addon)
	if not name or not enabled or IsAddOnLoaded(addon) or not IsAddOnLoadOnDemand(addon) then
		return
	end
	ns:OnAddonLoaded(addon, function()
		enqueue(entry)
		ns.After(LOAD_DELAY, showNext)
	end)
end

local function onEnteringWorld(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
	ns.After(SCAN_DELAY, scan)
end

function Conflicts:Initialize()
	for i = 1, #REGISTRY do
		local entry = REGISTRY[i]
		if not choices()[entry[1]] then
			watchLoadOnDemand(entry)
		end
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", onEnteringWorld)
end

function ns.ResetConflictChoices()
	ns.db.conflicts = nil
	wipe(queued)
	scan()
end
