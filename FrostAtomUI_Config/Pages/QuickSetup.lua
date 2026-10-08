local _, ns = ...

local ui = FrostAtomUI
local L = ui.L
local Presets = ui.SetupPresets

local CARD_PADDING = 10
local CARD_LINE_GAP = 6
local CARD_BUTTON_WIDTH, CARD_BUTTON_GAP = 100, 10
local CARD_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
}

local VOICE_VALUES = {
	{ "off", L["Off"] },
	{ "arena", L["Arena only"] },
	{ "all", L["Arena and battlegrounds"] },
}
local DRAG_VALUES = {
	{ "shift", L["Shift + left button"] },
	{ "alt", L["Alt + right button"] },
}
local DRAG = { shift = { "shift", "LeftButton" }, alt = { "alt", "RightButton" } }

ns.WhatsNew = {
	{
		text = L["Resetting a page no longer moves frames or clears your lists, and a backup of the profile is saved first."],
	},
	{
		text = L['Undo: Ctrl+Z or "Undo" at the bottom of the settings window. Copies of the whole profile: Backups (/fui restore).'],
	},
	{
		text = L["Changes that need a UI reload wait in one bar at the bottom instead of a question after every click."],
	},
	{
		text = L["Importing a profile shows what changes and can take only some parts or go into a new profile."],
	},
	{
		text = L["One window for addons that do the same job as FrostAtom UI, and one UI reload for all of them."],
	},
	{
		text = L['The voice says "on you" only when a control spell lands on you, not at the start of a cast aimed at you.'],
		button = L["As before"],
		path = "spellAlerts.urgentWhenTargeted",
		value = true,
	},
	{
		text = L["Holy priests and Arms warriors got their own spec icons; new installs show the class icon with a spec badge."],
	},
	{ text = L["Setup wizard with play styles: /fui setup."] },
}

local function getVoice()
	if not ui:GetConfig("spellAlerts.enabled") then
		return "off"
	end
	return ui:GetConfig("spellAlerts.zones.battleground") and "all" or "arena"
end

local function setVoice(value)
	ui.Undo.Run(L["Voice"], function()
		ui:SetConfig("spellAlerts.enabled", value ~= "off")
		if value ~= "off" then
			ui:SetConfig("spellAlerts.zones.arena", true)
			ui:SetConfig("spellAlerts.zones.battleground", value == "all")
		end
	end)
end

local function getDrag()
	local modifier, button = ui:GetConfig("actionBar.dragModifier"), ui:GetConfig("actionBar.dragButton")
	for key, values in pairs(DRAG) do
		if values[1] == modifier and values[2] == button then
			return key
		end
	end
end

local function setDrag(value)
	local values = DRAG[value]
	ui.Undo.Run(L["To take a spell off a bar, hold:"], function()
		ui:SetConfig("actionBar.dragModifier", values[1])
		ui:SetConfig("actionBar.dragButton", values[2])
	end)
end

local function styleValues()
	local values = {}
	for _, style in ipairs(Presets.STYLES) do
		if style.key ~= "none" then
			values[#values + 1] = { style.key, L[style.name], L[style.desc] }
		end
	end
	return values
end

local function closeWhatsNew()
	ui.API.SetUIState("whatsNewSeen", ui.WHATS_NEW_VERSION)
	ns.RefreshPage()
end

local function cardText(parent, width)
	local text = parent:CreateFontString(nil, "ARTWORK")
	text:SetFontObject(ns.Font("GameFontHighlightSmall"))
	text:SetJustifyH("LEFT")
	text:SetWidth(width)
	return text
end

local function buildWhatsNew(row)
	local card = CreateFrame("Frame", nil, row)
	card:SetPoint("TOPLEFT", 4, 0)
	card:SetPoint("RIGHT", -4, 0)
	card:SetBackdrop(CARD_BACKDROP)
	card:SetBackdropColor(0.1, 0.08, 0.02, 0.85)
	card:SetBackdropBorderColor(1, 0.82, 0)
	local width = row:GetParent():GetWidth() - 8 - CARD_PADDING * 2
	local title = card:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(ns.Font("GameFontNormal"))
	title:SetPoint("TOPLEFT", CARD_PADDING, -CARD_PADDING)
	title:SetText(L["What's new in %s"]:format(ui.WHATS_NEW_VERSION))
	local close = ui.CreateGlyphButton(card, "xmark", 12, CLOSE)
	close:SetPoint("TOPRIGHT", -4, -4)
	close:SetScript("OnClick", closeWhatsNew)
	local y = CARD_PADDING + 20
	local previous, gap = title, 20 - title:GetStringHeight()
	local buttons = {}
	local count = #ui:GetLegacyRecommendations()
	if count > 0 then
		local button =
			ns.CreateButton(card, L["Recommended new values (%d)"]:format(count), 200, true, nil, "list-check")
		button:SetScript("OnClick", ns.ShowRecommendations)
		buttons[#buttons + 1] = button
	end
	local setup = ns.CreateButton(card, L["Run the setup"], 140, true, nil, "wand-magic-sparkles")
	setup:SetScript("OnClick", ui.RunSetup)
	buttons[#buttons + 1] = setup
	for _, item in ipairs(ns.WhatsNew) do
		local showButton = item.button and ui:GetConfig(item.path) ~= item.value
		local line = cardText(card, showButton and width - CARD_BUTTON_WIDTH - CARD_BUTTON_GAP or width)
		line:SetText("- " .. item.text)
		local height = line:GetStringHeight()
		local pad = 0
		if showButton then
			local button = ns.CreateButton(card, item.button, CARD_BUTTON_WIDTH, true)
			pad = math.max(0, (button:GetHeight() - height) / 2)
			button:SetPoint("LEFT", line, "RIGHT", CARD_BUTTON_GAP, 0)
			button:SetScript("OnClick", function()
				ui:SetConfig(item.path, item.value)
				ns.RefreshPage()
			end)
		end
		line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(gap + pad))
		previous, gap = line, CARD_LINE_GAP + pad
		y = y + height + pad * 2 + CARD_LINE_GAP
	end
	buttons[1]:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(gap + 4))
	for i = 2, #buttons do
		buttons[i]:SetPoint("LEFT", buttons[i - 1], "RIGHT", 6, 0)
	end
	local height = y + 4 + 22 + CARD_PADDING
	card:SetHeight(height)
	row:SetHeight(height + 8)
end

local function currentStyleText()
	local style = Presets.GetStyle(Presets.GetActiveStyle())
	if not style then
		return L["Now: no style chosen. A style sets FrostAtom UI's starting values; you see the list of changes first."]
	end
	return L['Now: "%s". Choosing another style shows its list of changes first.']:format(L[style.name])
end

local function buildSchema()
	local schema = {
		{
			description = L['The settings asked about most. Everything else is in the sections on the left; "?" at the bottom opens the help. Search understands Russian and English words.'],
		},
	}
	if ui.API.GetUIState("whatsNewSeen") ~= ui.WHATS_NEW_VERSION and ui.SetupState() ~= "pending" then
		schema[#schema + 1] = { type = "custom", label = "", height = 10, build = buildWhatsNew }
	end
	local list = {
		{ header = L["Play style"], glyph = "chess-rook" },
		{
			label = L["Play style"],
			type = "select",
			values = styleValues(),
			get = Presets.GetActiveStyle,
			set = function(value)
				ns.ShowStyleDialog(value)
			end,
		},
		{ description = currentStyleText() },
		{ header = L["Interface size and frames"], glyph = "display" },
		{
			path = "general.uiScaleMode",
			label = L["UI scale"],
			type = "select",
			values = {
				{ "game", L["As in game"], L["The game's own setting from the video options."] },
				{
					"pixel",
					L["Sharp frames (%d%%)"]:format(math.floor(ui.PixelPerfectScale() * 100 + 0.5)),
					L["One interface unit becomes one screen pixel, borders stay sharp. On large screens everything gets smaller."],
				},
				{ "custom", L["Custom size"], L["The size from the slider below."] },
			},
			set = function(value)
				if value == "custom" then
					ui:SetConfig("general.uiScale", math.floor(UIParent:GetScale() * 100 + 0.5) / 100)
				end
				ui:SetConfig("general.uiScaleMode", value)
			end,
			confirmRevert = true,
		},
		{ description = L['"As in game" brings back the scale you had before.'] },
		{
			label = L["Frame layout"],
			type = "execute",
			text = L["Choose..."],
			glyph = "table-cells-large",
			func = function()
				ns.Toggle("layouts")
			end,
		},
		{ description = L["Ready-made places for all frames: Standard, Classic, Arena and others."] },
		{
			label = L["Move frames"],
			type = "execute",
			text = L["Unlock frames"],
			glyph = "up-down-left-right",
			func = function()
				ui.Movers.Unlock()
				if ui.Movers.IsUnlocked() then
					ns.HideWindow()
				end
			end,
		},
		{ description = L['Drag frames with the mouse; Ctrl+Z undoes a move, "Done" or combat locks them.'] },
		{ header = L["Sound and messages"], glyph = "volume-high" },
		{
			label = L["Voice (English)"],
			type = "select",
			values = VOICE_VALUES,
			get = getVoice,
			set = setVoice,
		},
		{ description = L["A voice names dangerous enemy spells."] },
		{
			path = "tweaks.errorMessages",
			label = L["Red error messages"],
			type = "select",
			values = {
				{ "all", L["All"] },
				{ "filtered", L["No spam"] },
				{ "hidden", L["Hide all"] },
			},
		},
		{ description = L['"Out of range", "Not enough energy" and other red text at the top of the screen.'] },
		{
			path = "announce.interrupts",
			label = L["Post my interrupts to group chat"],
			type = "toggle",
		},
		{ description = L["Other players see these messages; they are in English."] },
		{ header = L["Controls and game settings"], glyph = "keyboard" },
		{
			label = L["To take a spell off a bar, hold:"],
			type = "select",
			values = DRAG_VALUES,
			get = getDrag,
			set = setDrag,
		},
		{ description = L["Without a key a spell can be dragged off a bar by accident."] },
		{
			path = "tweaks.hideGroundClutter",
			label = L["Hide grass - more frames per second"],
			type = "toggle",
		},
		{ description = L["The old value comes back when you turn this off."] },
		{
			path = "tweaks.disableTutorials",
			label = L["Turn off Blizzard tips for new players"],
			type = "toggle",
		},
		{ description = L["Pop-up windows about talking to NPCs, taking quests and learning spells."] },
		{ header = L["Setup"], glyph = "wand-magic-sparkles" },
		{
			label = L["Setup wizard"],
			type = "execute",
			text = L["Run the setup"],
			glyph = "wand-magic-sparkles",
			func = ui.RunSetup,
		},
		{ description = L["The same questions as at the first start; a backup of the profile is saved first."] },
	}
	for _, entry in ipairs(list) do
		schema[#schema + 1] = entry
	end
	return schema
end

local function signature()
	return table.concat({
		tostring(ui.API.GetUIState("whatsNewSeen")),
		tostring(Presets.GetActiveStyle()),
		tostring(ui:GetConfig("spellAlerts.urgentWhenTargeted")),
		tostring(#ui:GetLegacyRecommendations()),
		ui:GetActiveProfile(),
	}, ",")
end

ns.RegisterPage({
	key = "quicksetup",
	name = L["Quick setup"],
	desc = L["The settings asked about most, on one page."],
	glyph = "bolt",
	order = 1,
	group = "start",
	buildSchema = buildSchema,
	signature = signature,
	noReset = true,
	noSearch = true,
})
