local _, ns = ...

local L = ns.L

local IsAddOnLoaded, IsAddOnLoadOnDemand, GetAddOnInfo = IsAddOnLoaded, IsAddOnLoadOnDemand, GetAddOnInfo
local DisableAddOn, ReloadUI = DisableAddOn, ReloadUI

local SCAN_DELAY = 5
local LOAD_DELAY = 2
local WINDOW_WIDTH = 520
local PADDING = 20
local ROW_TITLE = 20
local RADIO_LINE = 20
local ROW_GAP = 10
local MAX_ROWS = 6
local WINDOW_NAME = "FrostAtomUIConflicts"

local ACTION_BARS = { "Action bars", "actionBar.enabled", "hideBlizzard.actionBars" }
local UNIT_FRAMES = {
	"Unit frames",
	"unitFrames.enabled",
	"hideBlizzard.unitFrames",
	"hideBlizzard.castBar",
	"hideBlizzard.buffs",
}
local ARENA_FRAMES = { "Arena frames", "unitFrames.showArena" }
local RAID_FRAMES = { "Raid frames", "raidFrames.enabled" }
local NAMEPLATES = { "Nameplates", "namePlates.enabled" }
local COOLDOWNS = { "Cooldowns", "groupCooldowns.enabled" }
local BAGS = { "Bags", "bags.enabled" }
local CHAT = { "Chat", "chat.enabled" }
local MINIMAP = { "Minimap", "minimap.enabled" }
local MAPS = { "Minimap & map", "minimap.enabled", "worldMap.enabled" }
local WHOLE_UI = {
	"most modules",
	"actionBar.enabled",
	"hideBlizzard.actionBars",
	"unitFrames.enabled",
	"hideBlizzard.unitFrames",
	"hideBlizzard.castBar",
	"hideBlizzard.buffs",
	"namePlates.enabled",
	"chat.enabled",
	"minimap.enabled",
	"bags.enabled",
	"tooltip.enabled",
}

local REGISTRY = {
	{ "Bartender4", ACTION_BARS },
	{ "Dominos", ACTION_BARS },
	{ "SnowfallKeyPress", ACTION_BARS },
	{ "ShadowedUnitFrames", UNIT_FRAMES },
	{ "PitBull4", UNIT_FRAMES },
	{ "XPerl", UNIT_FRAMES },
	{ "oUF_Abu", UNIT_FRAMES },
	{ "Gladius", ARENA_FRAMES },
	{ "GladiusEx", ARENA_FRAMES },
	{ "sArena", ARENA_FRAMES },
	{ "Gladdy", ARENA_FRAMES },
	{ "Grid", RAID_FRAMES },
	{ "Grid2", RAID_FRAMES },
	{ "VuhDo", RAID_FRAMES },
	{ "HealBot", RAID_FRAMES },
	{ "TidyPlates", NAMEPLATES },
	{ "Aloft", NAMEPLATES },
	{ "Kui_Nameplates", NAMEPLATES },
	{ "NotPlater", NAMEPLATES },
	{ "LoseControl", { "CC alert and CC on frames", "lossOfControl.enabled", "loseControl.enabled" } },
	{ "BigDebuffs", { "CC on frames", "loseControl.enabled" } },
	{ "DRTracker", { "Diminishing returns", "diminishingReturns.enabled" } },
	{ "DiminishingReturns", { "Diminishing returns", "diminishingReturns.enabled" } },
	{ "Afflicted", COOLDOWNS },
	{ "OmniBar", COOLDOWNS },
	{ "OmniCD", COOLDOWNS },
	{ "TellMeWhen", { "Trackers", "trackers.enabled" } },
	{ "InternalCooldowns", { "Trinket internal cooldowns", "internalCooldowns.enabled" } },
	{ "SoundAlerter", { "Spell alerts", "spellAlerts.enabled" } },
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
	{ "Carbonite", MAPS },
	{ "QuestHelper", MAPS },
	{ "Mapster", { "World map", "worldMap.enabled" } },
	{ "ElvUI", WHOLE_UI },
	{ "Tukui", WHOLE_UI },
}

local CHOICES = { "theirs", "ours", "keep" }

local Conflicts = ns:NewModule("Conflicts")

local found = {}
local window

local choicesSlot = ns.Storage.Claim("conflicts", "Conflicts", "settings")

local function choices()
	return choicesSlot:Table()
end

local function overlaps(entry)
	local path = entry[2][2]
	return not path or ns:GetConfig(path) ~= false
end

local function choiceText(entry, choice)
	local addon, module = entry[1], L[entry[2][1]]
	if choice == "theirs" then
		return L["Keep FrostAtom UI (disable %s)"]:format(addon)
	elseif choice == "ours" then
		if entry[2] == WHOLE_UI then
			return L["Keep %s (FrostAtom UI turns off most of its modules)"]:format(addon)
		end
		return L['Keep %s (turn off FrostAtom UI "%s")']:format(addon, module)
	end
	return L["Keep both (they may get in each other's way)"]
end

local function selectChoice(radio)
	local row = radio.row
	row.choice = radio.choice
	for _, other in ipairs(row.radios) do
		other:SetChecked(other == radio)
	end
end

local function createRow(index)
	local row = CreateFrame("Frame", nil, window)
	row:SetWidth(WINDOW_WIDTH - PADDING * 2)
	row:SetHeight(ROW_TITLE + RADIO_LINE * #CHOICES)
	local title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT")
	title:SetPoint("RIGHT")
	title:SetJustifyH("LEFT")
	row.title = title
	row.radios = {}
	for i, choice in ipairs(CHOICES) do
		local radio =
			CreateFrame("CheckButton", WINDOW_NAME .. "Row" .. index .. "Choice" .. i, row, "UIRadioButtonTemplate")
		radio:SetPoint("TOPLEFT", 4, -ROW_TITLE - (i - 1) * RADIO_LINE)
		radio.text = _G[radio:GetName() .. "Text"]
		radio.text:SetFontObject(GameFontHighlightSmall)
		radio.row, radio.choice = row, choice
		radio:SetScript("OnClick", selectChoice)
		row.radios[i] = radio
	end
	return row
end

local function resolve(list)
	local reload, disabled = false, {}
	ns.Undo.Run(L["Resolve addon conflicts"], function()
		for _, item in ipairs(list) do
			local entry, choice = item.entry, item.choice
			choices()[entry[1]] = choice
			if choice == "theirs" then
				DisableAddOn(entry[1])
				disabled[#disabled + 1] = entry[1]
				reload = true
			elseif choice == "ours" then
				for i = 2, #entry[2] do
					ns:SetConfig(entry[2][i], false)
				end
				reload = true
			end
		end
	end)
	wipe(found)
	return reload, disabled
end

local function apply()
	local list = {}
	for _, row in ipairs(window.rows) do
		if row:IsShown() and row.entry then
			list[#list + 1] = { entry = row.entry, choice = row.choice }
		end
	end
	local reload = resolve(list)
	window:Hide()
	if not reload then
		return
	elseif ns.InArenaPreparation() then
		ns.Print(L["addon conflicts are resolved; reload the UI after the match"])
	else
		ReloadUI()
	end
end

local function createWindow()
	window = ns.CreateWindow(WINDOW_NAME, {
		width = WINDOW_WIDTH,
		height = 200,
		title = L["Addons that overlap FrostAtom UI"],
		strata = "FULLSCREEN_DIALOG",
		noClose = true,
		movable = true,
	})
	window:SetPoint("CENTER")
	local text = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", PADDING, -42)
	text:SetWidth(WINDOW_WIDTH - PADDING * 2)
	text:SetJustifyH("LEFT")
	text:SetText(
		L["These addons do the same job as a FrostAtom UI module. Choose what to keep for each one; the answers are remembered."]
	)
	window.text = text
	window.rows = {}

	local later = ns.CreateButton(window, L["Later"], 90, 22, nil, true)
	later:SetPoint("BOTTOMRIGHT", -PADDING, 16)
	later:SetScript("OnClick", function()
		window:Hide()
	end)
	local accept = ns.CreateButton(window, L["Apply (UI reload 5-10 s, your character stays in place)"], 300)
	ns.FitButton(accept, 24, 200)
	accept:SetPoint("RIGHT", later, "LEFT", -4, 0)
	accept:SetScript("OnClick", apply)
end

local function pending()
	local list = {}
	for _, entry in ipairs(found) do
		if not choices()[entry[1]] and overlaps(entry) and #list < MAX_ROWS then
			list[#list + 1] = entry
		end
	end
	return list
end

local function show()
	local list = pending()
	if #list == 0 or ns.SetupState() == "pending" then
		return false
	end
	if not window then
		createWindow()
	end
	window:Show()
	local top = 42 + window.text:GetStringHeight() + ROW_GAP
	for index, entry in ipairs(list) do
		local row = window.rows[index] or createRow(index)
		window.rows[index] = row
		row.entry = entry
		row.title:SetText(L['%s overlaps FrostAtom UI "%s"']:format(entry[1], L[entry[2][1]]))
		local shown = 0
		for _, radio in ipairs(row.radios) do
			local available = radio.choice ~= "ours" or entry[2][2] ~= nil
			radio.text:SetText(choiceText(entry, radio.choice))
			ns.SetShown(radio, available)
			if available then
				radio:SetPoint("TOPLEFT", 4, -ROW_TITLE - shown * RADIO_LINE)
				shown = shown + 1
			end
		end
		row:SetHeight(ROW_TITLE + shown * RADIO_LINE)
		selectChoice(row.radios[1])
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", PADDING, -top)
		row:Show()
		top = top + row:GetHeight() + ROW_GAP
	end
	for index = #list + 1, #window.rows do
		window.rows[index]:Hide()
		window.rows[index].entry = nil
	end
	window:SetHeight(top + 50)
	return true
end

local function add(entry)
	for _, existing in ipairs(found) do
		if existing == entry then
			return
		end
	end
	if not choices()[entry[1]] then
		found[#found + 1] = entry
	end
end

local function collect()
	for i = 1, #REGISTRY do
		if IsAddOnLoaded(REGISTRY[i][1]) then
			add(REGISTRY[i])
		end
	end
end

local function scan()
	collect()
	return show()
end

local function watchLoadOnDemand(entry)
	local addon = entry[1]
	local name, _, _, enabled = GetAddOnInfo(addon)
	if not name or not enabled or IsAddOnLoaded(addon) or not IsAddOnLoadOnDemand(addon) then
		return
	end
	ns:OnAddonLoaded(addon, function()
		add(entry)
		ns.After(LOAD_DELAY, show)
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

function ns.GetConflicts()
	collect()
	local list = {}
	for _, entry in ipairs(pending()) do
		local item = { entry = entry, addon = entry[1], module = L[entry[2][1]], hasOurs = entry[2][2] ~= nil }
		item.texts = {}
		for _, choice in ipairs(CHOICES) do
			item.texts[choice] = choiceText(entry, choice)
		end
		list[#list + 1] = item
	end
	return list
end

ns.ResolveConflicts = resolve

function ns.ShowConflicts()
	return show()
end

function ns.ResetConflictChoices()
	choicesSlot:Set(nil)
	wipe(found)
	if not scan() then
		ns.Print(L["no addons overlap FrostAtom UI"])
	end
end
