local _, ns = ...

local ui = FrostAtomUI
local L = ui.L
local Presets = ui.SetupPresets

local floor = math.floor

local WINDOW_NAME = "FrostAtomUISetup"
local SKIP_POPUP = "FROSTATOMUI_SETUP_SKIP"
local WIDTH, HEIGHT, PADDING = 660, 540, 24
local CONTENT_TOP, FOOTER = 48, 54
local CONTENT_WIDTH = WIDTH - PADDING * 2
local CARD_GAP, ROLE_CARD_HEIGHT = 8, 116
local LAYOUT_COLUMNS = 5
local LAYOUT_CARD_WIDTH = (CONTENT_WIDTH - CARD_GAP * (LAYOUT_COLUMNS - 1)) / LAYOUT_COLUMNS
local THUMB_INSET, THUMB_HEIGHT, LAYOUT_NAME_HEIGHT = 4, 61, 26
local THUMB_WIDTH = LAYOUT_CARD_WIDTH - THUMB_INSET * 2
local LAYOUT_CARD_HEIGHT = THUMB_HEIGHT + THUMB_INSET * 2 + LAYOUT_NAME_HEIGHT
local CHECK_LINE = 24
local LEFT_COLUMN_WIDTH = 330
local LARGER, MAX_SCALE = 1.15, 1.15
local SCALE_EPSILON = 0.005
local DETAIL_LINE = 22
local EXAMPLE_SOUND = "cyclone"
local EXPERT_ADDONS = { "ElvUI", "Tukui", "Gladius", "GladiusEx", "sArena" }
local BORDER = { 0.3, 0.3, 0.3 }
local HOVER = { 0.6, 0.6, 0.6 }
local SELECTED = { 1, 0.82, 0 }
local GRAY = { 0.62, 0.62, 0.62 }
local CARD_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
}

local WHERE = {
	{ "arena", L["Arena"] },
	{ "battlegrounds", L["Battlegrounds"] },
	{ "both", L["Arena and battlegrounds"] },
}
local WHERE_STYLES = { arena = "arena", battlegrounds = "pvp", both = "pvp" }
local VOICE = {
	{ "off", L["Off"] },
	{ "arena", L["Arena only"] },
	{ "all", L["Arena and battlegrounds"] },
}
local ERRORS = {
	{ "all", L["All"] },
	{ "filtered", L["No spam"] },
	{ "hidden", L["Hide all"] },
}
local OPTION_PATHS = {
	interrupts = { "announce.interrupts" },
	arenaResults = { "announce.arenaResultToParty" },
	errors = { "tweaks.errorMessages" },
	merchant = { "merchant.sellGreys", "merchant.autoRepair" },
	invites = { "popups.autoAcceptInvites" },
	release = { "popups.autoRelease" },
	grass = { "tweaks.hideGroundClutter" },
	tutorials = { "tweaks.disableTutorials" },
}
local FEATURE_COLUMNS, FEATURE_HEIGHT = 3, 52
local FEATURES = {
	{ "trophy", "Arena frames", "Trinkets, casts and crowd control of every enemy" },
	{ "hourglass-half", "Cooldowns", "Important abilities of your team and the enemies" },
	{ "volume-high", "Voice alerts", "A voice names dangerous enemy spells" },
	{ "face-dizzy", "Loss of control", "A big icon with a timer when you are stunned or silenced" },
	{ "eye", "Nameplates", "Class icons and healer marks above heads" },
	{ "table-cells-large", "Layouts", "Ready-made frame layouts; any frame can be dragged" },
}
local STYLE_OPTIONS = { "voice", "release" }
local LAYOUT_KEEP = "keep"

local state = {}
local window
local screens = {}
local order = {}

local function text(parent, fontName, width, color)
	local region = parent:CreateFontString(nil, "ARTWORK")
	region:SetFontObject(ns.Font(fontName or "GameFontHighlight"))
	region:SetJustifyH("LEFT")
	if width then
		region:SetWidth(width)
	end
	if color then
		region:SetTextColor(color[1], color[2], color[3])
	end
	return region
end

local function paintBorder(frame, selected)
	local color = selected and SELECTED or BORDER
	frame:SetBackdropBorderColor(color[1], color[2], color[3])
end

local function segment(parent, options, onSelect)
	local group = CreateFrame("Frame", nil, parent)
	group.buttons = {}
	local x = 0
	for i, option in ipairs(options) do
		local button = ns.CreateButton(group, option[2], 70, true)
		button:SetPoint("LEFT", x, 0)
		x = x + button:GetWidth() + 4
		button.value = option[1]
		button:SetScript("OnClick", function()
			onSelect(option[1])
			group:SetValue(option[1])
		end)
		local mark = button:CreateTexture(nil, "OVERLAY")
		mark:SetTexture(SELECTED[1], SELECTED[2], SELECTED[3])
		mark:SetHeight(2)
		mark:SetPoint("BOTTOMLEFT", 4, 1)
		mark:SetPoint("BOTTOMRIGHT", -4, 1)
		button.mark = mark
		group.buttons[i] = button
	end
	group:SetSize(x, 22)
	function group.SetValue(_, value)
		for _, button in ipairs(group.buttons) do
			local selected = button.value == value
			ui.SetShown(button.mark, selected)
			if selected then
				button:LockHighlight()
			else
				button:UnlockHighlight()
			end
		end
	end
	return group
end

local radioCount = 0

local function radio(parent, label, onClick)
	radioCount = radioCount + 1
	local name = WINDOW_NAME .. "Radio" .. radioCount
	local button = CreateFrame("CheckButton", name, parent, "UIRadioButtonTemplate")
	button.text = _G[name .. "Text"]
	button.text:SetFontObject(ns.Font("GameFontHighlight"))
	button.text:SetText(label)
	button:SetHitRectInsets(0, -(button.text:GetStringWidth() + 6), 0, 0)
	button:SetScript("OnClick", onClick)
	return button
end

local function check(parent, label, onClick)
	local button = ui.CreateCheckButton(parent, label, nil, true)
	button:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)
	return button
end

local function hoverBorder(button)
	if not button.selected then
		button:SetBackdropBorderColor(HOVER[1], HOVER[2], HOVER[3])
	end
end

local function card(parent, width, height, glyph, title, desc, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	button:SetBackdrop(CARD_BACKDROP)
	button:SetBackdropColor(0, 0, 0, 0.45)
	paintBorder(button, false)
	local icon = ui.CreateGlyph(button, glyph, 22, "ARTWORK")
	icon:SetPoint("TOP", 0, -12)
	local heading = text(button, "GameFontNormal", width - 14)
	heading:SetJustifyH("CENTER")
	heading:SetPoint("TOP", icon, "BOTTOM", 0, -8)
	heading:SetText(title)
	local body = text(button, "GameFontHighlightSmall", width - 16)
	body:SetJustifyH("CENTER")
	body:SetJustifyV("TOP")
	body:SetPoint("TOP", heading, "BOTTOM", 0, -6)
	body:SetText(desc)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", hoverBorder)
	button:SetScript("OnLeave", function(self)
		paintBorder(self, self.selected)
	end)
	return button
end

local function setSelected(button, selected)
	button.selected = selected
	paintBorder(button, selected)
end

local function isFresh()
	return ui.SetupState() == "pending"
end

local function currentScale()
	return UIParent:GetScale()
end

local function largerScale()
	return math.min(MAX_SCALE, floor(currentScale() * LARGER * 100 + 0.5) / 100)
end

local function hasLarger()
	return largerScale() > currentScale() + SCALE_EPSILON
end

local function offersPixel()
	return ui:GetConfig("general.uiScaleMode") ~= "pixel"
end

local function chosenScale()
	if state.scale == "larger" then
		return largerScale()
	elseif state.scale == "sharp" then
		return ui.PixelPerfectScale()
	end
	return currentScale()
end

local function percent(scale)
	return floor(scale * 100 + 0.5)
end

local function currentStyle()
	return WHERE_STYLES[state.where] or "pvp"
end

local function experienceKey()
	if not state.explain then
		return "expert"
	end
	return state.experience == "new" and "new" or "returning"
end

local function styleValue(path)
	local style = Presets.GetStyle(currentStyle())
	local value = style and style.values[path]
	if value == nil then
		value = ui:GetConfig(path)
	end
	return value
end

local function voiceOf(enabled, battleground)
	if not enabled then
		return "off"
	end
	return battleground and "all" or "arena"
end

local function resetOptions()
	state.options, state.initial, state.touched = {}, {}, {}
	state.optionsReady, state.optionsStyle = nil, nil
end

local function initOptions()
	local options, initial = state.options, state.initial
	if not state.optionsReady then
		state.optionsReady = true
		for key, paths in pairs(OPTION_PATHS) do
			local value = true
			for _, path in ipairs(paths) do
				value = value and ui:GetConfig(path)
			end
			initial[key] = value
			options[key] = value
		end
		options.focusKey = false
	end
	local style = currentStyle()
	if state.optionsStyle ~= style then
		state.optionsStyle = style
		initial.voice = voiceOf(styleValue("spellAlerts.enabled"), styleValue("spellAlerts.zones.battleground"))
		initial.release = styleValue("popups.autoRelease")
		for _, key in ipairs(STYLE_OPTIONS) do
			if not state.touched[key] then
				options[key] = initial[key]
			end
		end
	end
end

local function setOption(key, value)
	state.options[key] = value
	state.touched[key] = true
end

local function extras()
	initOptions()
	local values = {}
	if state.scale == "larger" then
		values["general.uiScaleMode"] = "custom"
		values["general.uiScale"] = largerScale()
	elseif state.scale == "sharp" then
		values["general.uiScaleMode"] = "pixel"
	end
	local options, initial = state.options, state.initial
	for key, paths in pairs(OPTION_PATHS) do
		if options[key] ~= initial[key] then
			for _, path in ipairs(paths) do
				values[path] = options[key]
			end
		end
	end
	if options.voice ~= initial.voice then
		values["spellAlerts.enabled"] = options.voice ~= "off"
		if options.voice ~= "off" then
			values["spellAlerts.zones.arena"] = true
			values["spellAlerts.zones.battleground"] = options.voice == "all"
		end
	end
	return values
end

local function recommendedLayout()
	return Presets.RecommendedLayout(currentStyle(), state.role)
end

local function layoutChoice()
	return state.layout or recommendedLayout() or LAYOUT_KEEP
end

local function buildPlan()
	local plan = Presets.Plan(currentStyle(), experienceKey(), extras(), state.role)
	local layout = layoutChoice()
	plan.layout = layout ~= LAYOUT_KEEP and layout ~= ui.Movers.GetActivePreset() and layout or nil
	plan.layoutChecked = plan.layout ~= nil and not state.layoutOff
	for _, item in ipairs(plan) do
		local toggle = state.toggles[item.path]
		if toggle ~= nil then
			item.checked = toggle
		end
	end
	return plan
end

local function presetByKey(key)
	for _, preset in ipairs(ui.Movers.GetPresets()) do
		if preset.key == key then
			return preset
		end
	end
end

local function presetName(key)
	local preset = presetByKey(key)
	return preset and L[preset.name] or key
end

local function changeCount(plan)
	return Presets.CountChecked(plan) + (plan.layoutChecked and 1 or 0)
end

local refresh

local function showScreen(index)
	state.screen = index
	for i, key in ipairs(order) do
		local screen = screens[key]
		if screen.frame then
			ui.SetShown(screen.frame, i == index)
		end
	end
	window.details:Hide()
	refresh()
end

local function goNext()
	local screen = screens[order[state.screen]]
	if screen.ready and not screen.ready() then
		return
	end
	if state.screen < #order then
		showScreen(state.screen + 1)
	end
end

local function goBack()
	if window.details:IsShown() then
		window.details:Hide()
		refresh()
	elseif state.screen > 1 then
		showScreen(state.screen - 1)
	end
end

local function closeWindow()
	window.closing = true
	window:Hide()
	window.closing = nil
end

local function skip()
	closeWindow()
	if isFresh() then
		ui.SetSetupState("skipped")
	end
	ui.Print(L['you can run the setup later: |cffffffff/fui setup|r or Esc > "FrostAtom UI"'])
	ui.ShowConflicts()
end

StaticPopupDialogs[SKIP_POPUP] = {
	text = L['Skip setup? FrostAtom UI keeps its safe settings. To come back: |cffffffff/fui setup|r or Esc > "FrostAtom UI"'],
	button1 = L["Continue setup"],
	button2 = L["Skip"],
	OnAccept = function()
		window:Show()
	end,
	OnCancel = function(_, _, reason)
		if reason == "clicked" then
			skip()
		else
			window:Show()
		end
	end,
	timeout = 0,
	whileDead = 1,
	preferredIndex = 3,
}

local function needsReload(applied, reload)
	if state.locale ~= ui.GetLocaleOverride() then
		ui.SetLocaleOverride(state.locale)
		reload = true
	end
	for _, item in ipairs(applied) do
		if ns.ReloadLabel(item.path) then
			reload = true
		end
	end
	return reload
end

local function focusKeyChosen()
	return state.options.focusKey and ui.IsFocusMouseKeyFree()
end

local function applyInfo(plan)
	local reload = state.locale ~= ui.GetLocaleOverride()
	for _, item in ipairs(plan) do
		if item.checked and ns.ReloadLabel(item.path) then
			reload = true
		end
	end
	for _, item in ipairs(state.conflicts) do
		if (state.choices[item.addon] or "theirs") ~= "keep" then
			reload = true
		end
	end
	local notes = {}
	if not isFresh() then
		notes[#notes + 1] =
			L['Your current settings are saved to the backup "Before setup (%s)".']:format(date("%H:%M"))
	end
	if reload then
		notes[#notes + 1] = L["A UI reload is needed: 5-10 seconds, your character stays in place."]
	end
	local blocked = ui.InArenaPreparation()
	if blocked then
		notes[#notes + 1] = L["Applies after the match."]
	end
	return reload, notes, blocked or InCombatLockdown()
end

local function apply()
	if InCombatLockdown() or ui.InArenaPreparation() then
		return
	end
	local plan = buildPlan()
	local snapshot = ui.Undo.Snapshot("setup")
	if snapshot then
		snapshot.pinned = true
	end
	local list, reload, disabled = {}, false, {}
	ui.Undo.Begin(L["Setup"])
	local applied = Presets.Apply(plan, L["Setup"])
	for _, item in ipairs(state.conflicts) do
		list[#list + 1] = { entry = item.entry, choice = state.choices[item.addon] or "theirs" }
	end
	if #list > 0 then
		reload, disabled = ui.ResolveConflicts(list)
	end
	ui.Undo.End()
	local focusKey = focusKeyChosen() and ui.SetFocusMouseKey(true) or nil
	reload = needsReload(applied, reload)
	local resolved = {}
	for _, item in ipairs(list) do
		resolved[#resolved + 1] = item.entry[1]
	end
	ui.API.SetUIState("setup", {
		state = "done",
		experience = experienceKey(),
		style = currentStyle(),
		role = state.role,
		where = state.where,
		time = time(),
		toast = true,
		undo = {
			time = snapshot and snapshot.time,
			profile = ui:GetActiveProfile(),
			addons = disabled,
			conflicts = resolved,
			focusKey = focusKey,
		},
	})
	closeWindow()
	if reload then
		ReloadUI()
	else
		ui.ShowSetupToast()
	end
end

local function createDetails()
	local details = CreateFrame("Frame", nil, window)
	details:SetPoint("TOPLEFT", PADDING - 6, -CONTENT_TOP + 4)
	details:SetPoint("BOTTOMRIGHT", -PADDING + 6, FOOTER - 4)
	details:SetFrameLevel(window:GetFrameLevel() + 20)
	details:EnableMouse(true)
	details:Hide()
	local shade = details:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(0.04, 0.04, 0.04, 0.97)
	shade:SetAllPoints()
	local heading = text(details, "GameFontNormal", CONTENT_WIDTH - 20)
	heading:SetPoint("TOPLEFT", 8, -8)
	details.heading = heading
	local hint = text(details, "GameFontHighlightSmall", CONTENT_WIDTH - 20, GRAY)
	hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
	hint:SetText(L["Unchecked settings stay as they are. Settings you changed yourself are unchecked."])
	local scroll = CreateFrame("ScrollFrame", WINDOW_NAME .. "DetailsScroll", details, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -48)
	scroll:SetPoint("BOTTOMRIGHT", -28, 6)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(CONTENT_WIDTH - 30, 10)
	scroll:SetScrollChild(child)
	details.scroll = scroll
	details.child = child
	details.rows = {}
	window.details = details
end

local function fitScrollBar(scroll, child)
	local bar = _G[scroll:GetName() .. "ScrollBar"]
	if child:GetHeight() > scroll:GetHeight() then
		bar:Show()
	else
		scroll:SetVerticalScroll(0)
		bar:Hide()
	end
end

local function detailRow(index)
	local details = window.details
	local row = details.rows[index]
	if not row then
		row = check(details.child, "", function(checked)
			local item = details.rows[index].item
			if item == "layout" then
				state.layoutOff = not checked
			elseif item then
				state.toggles[item.path] = checked
			end
			refresh()
		end)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * DETAIL_LINE)
		details.rows[index] = row
	end
	row:Show()
	return row
end

local function itemText(item)
	local line = L["%s: from %s to %s"]:format(
		Presets.Label(item.path),
		Presets.ValueText(item.path, item.current),
		Presets.ValueText(item.path, item.value)
	)
	if item.mine then
		line = line .. " |cff9d9d9d" .. L["(changed by you)"] .. "|r"
	end
	return line
end

local function showDetails()
	local details = window.details
	local plan = buildPlan()
	for _, row in ipairs(details.rows) do
		row:Hide()
	end
	local index = 0
	if plan.layout then
		index = index + 1
		local row = detailRow(index)
		row.item = "layout"
		row:SetLabel(L['Frame layout: "%s"']:format(presetName(plan.layout)))
		row:SetChecked(plan.layoutChecked)
	end
	for _, item in ipairs(plan) do
		index = index + 1
		local row = detailRow(index)
		row.item = item
		row:SetLabel(itemText(item))
		row:SetChecked(item.checked)
	end
	details.child:SetHeight(math.max(10, index * DETAIL_LINE))
	details.empty = index == 0
	details:Show()
	fitScrollBar(details.scroll, details.child)
	refresh()
end

local function recommendedSetup()
	state.role = state.role or "damage"
	state.where = "both"
	state.layout = nil
	state.layoutOff = nil
	state.scale = "keep"
	state.toggles = {}
	resetOptions()
	showScreen(#order)
	showDetails()
end

local PLAN = { WIDTH = 580, HEIGHT = 460, PADDING = 20, LABEL_WIDTH = 500 }
local planDialog

local function createPlanDialog()
	local dialog = ns.CreateWindow(WINDOW_NAME .. "Plan", {
		width = PLAN.WIDTH,
		height = PLAN.HEIGHT,
		header = true,
		strata = "FULLSCREEN_DIALOG",
		noClose = true,
	})
	dialog:SetPoint("CENTER")
	local shade = dialog:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(0, 0, 0, 0.92)
	shade:SetPoint("TOPLEFT", 4, -4)
	shade:SetPoint("BOTTOMRIGHT", -4, 4)
	local note = text(dialog, "GameFontHighlightSmall", PLAN.WIDTH - PLAN.PADDING * 2, GRAY)
	note:SetPoint("TOPLEFT", PLAN.PADDING, -42)
	dialog.note = note
	local scroll = CreateFrame("ScrollFrame", WINDOW_NAME .. "PlanScroll", dialog, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", PLAN.PADDING - 4, -78)
	scroll:SetPoint("BOTTOMRIGHT", -PLAN.PADDING - 22, 52)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(PLAN.WIDTH - PLAN.PADDING * 2 - 26, 10)
	scroll:SetScrollChild(child)
	dialog.scroll = scroll
	dialog.child = child
	dialog.rows = {}
	local cancel = ns.CreateButton(dialog, CANCEL, 100, true)
	cancel:SetPoint("BOTTOMRIGHT", -PLAN.PADDING, 16)
	cancel:SetScript("OnClick", function()
		dialog:Hide()
	end)
	local accept = ns.CreateButton(dialog, L["Apply"], 140, nil, nil, "check")
	accept:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
	accept:SetScript("OnClick", function()
		dialog:Hide()
		dialog.options.onApply(dialog.options.rows)
	end)
	dialog.accept = accept
	planDialog = dialog
end

local function planRow(index)
	local row = planDialog.rows[index]
	if not row then
		row = check(planDialog.child, "", function(checked)
			planDialog.rows[index].data.checked = checked
		end)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * DETAIL_LINE)
		row.text:SetWidth(PLAN.LABEL_WIDTH)
		row.text:SetHeight(14)
		row.text:SetJustifyH("LEFT")
		planDialog.rows[index] = row
	end
	row:Show()
	return row
end

function ns.ShowPlanDialog(options)
	if not planDialog then
		createPlanDialog()
	end
	planDialog.options = options
	planDialog.heading:SetText(options.title)
	planDialog.note:SetText(options.note or "")
	for _, row in ipairs(planDialog.rows) do
		row:Hide()
	end
	for index, data in ipairs(options.rows) do
		local row = planRow(index)
		row.data = data
		row:SetLabel(data.text)
		row:SetChecked(data.checked)
	end
	planDialog.child:SetHeight(math.max(10, #options.rows * DETAIL_LINE))
	planDialog:Show()
	fitScrollBar(planDialog.scroll, planDialog.child)
end

function ns.ShowStyleDialog(key)
	local style = Presets.GetStyle(key)
	local plan = Presets.Plan(key)
	local rows = {}
	if plan.layout then
		rows[1] = { text = L['Frame layout: "%s"']:format(presetName(plan.layout)), checked = true, layout = true }
	end
	for _, item in ipairs(plan) do
		rows[#rows + 1] = { text = itemText(item), checked = item.checked, item = item }
	end
	local name = L[style.name]
	if #rows == 0 then
		Presets.Apply(plan)
		ui.Print(L['the "%s" style is chosen; nothing else changes'], name)
		ns.RefreshPage()
		return
	end
	ns.ShowPlanDialog({
		title = L['Apply the style "%s"?']:format(name),
		note = L["A backup of the profile is saved first. Unchecked settings stay as they are; the settings you changed yourself are unchecked."],
		rows = rows,
		onApply = function()
			for _, row in ipairs(rows) do
				if row.layout then
					plan.layoutChecked = row.checked
				else
					row.item.checked = row.checked
				end
			end
			ui.Undo.Snapshot("style", name)
			Presets.Apply(plan, L['Apply the style "%s"']:format(name))
			ns.RefreshPage()
		end,
	})
end

function ns.ShowRecommendations()
	local list = ui:GetLegacyRecommendations()
	local rows = {}
	for _, item in ipairs(list) do
		local label = Presets.Label(item.path)
		local line = item.point and L["%s: the new position"]:format(label)
			or L["%s: from %s to %s"]:format(
				label,
				Presets.ValueText(item.path, item.current),
				Presets.ValueText(item.path, item.value)
			)
		rows[#rows + 1] = { text = line, checked = true, item = item }
	end
	ns.ShowPlanDialog({
		title = L["Recommended new values"],
		note = L["Your profile keeps the values of the old version. Checked ones switch to the new defaults; a backup is saved first."],
		rows = rows,
		onApply = function()
			local chosen = {}
			for _, row in ipairs(rows) do
				if row.checked then
					chosen[#chosen + 1] = row.item
				end
			end
			if #chosen > 0 then
				ui.ApplyRecommendations(chosen)
			end
			ns.RefreshPage()
		end,
	})
end

local function title(frame, label, y)
	local region = text(frame, "GameFontNormalLarge", CONTENT_WIDTH)
	region:SetPoint("TOPLEFT", 0, y or -4)
	region:SetText(label)
	return region
end

screens.welcome = {
	build = function(frame)
		local heading =
			title(frame, L["Welcome to FrostAtom UI %s"]:format(GetAddOnMetadata("FrostAtomUI", "Version") or ""))
		local body = text(frame, "GameFontHighlight", CONTENT_WIDTH)
		body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
		body:SetText(
			L['Your interface for arenas and battlegrounds. Three short questions, about a minute; everything can be changed later in Esc > "FrostAtom UI".']
		)
		local width = (CONTENT_WIDTH - CARD_GAP * (FEATURE_COLUMNS - 1)) / FEATURE_COLUMNS
		for i, feature in ipairs(FEATURES) do
			local column, row = (i - 1) % FEATURE_COLUMNS, floor((i - 1) / FEATURE_COLUMNS)
			local glyph = ui.CreateGlyph(frame, feature[1], 16, "ARTWORK")
			glyph:SetPoint("TOPLEFT", body, "BOTTOMLEFT", column * (width + CARD_GAP), -18 - row * FEATURE_HEIGHT)
			glyph:SetTextColor(SELECTED[1], SELECTED[2], SELECTED[3])
			local name = text(frame, "GameFontNormal", width - 26)
			name:SetPoint("TOPLEFT", glyph, "TOPLEFT", 24, 0)
			name:SetText(L[feature[2]])
			local desc = text(frame, "GameFontHighlightSmall", width - 26, GRAY)
			desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
			desc:SetText(L[feature[3]])
		end
		local language = text(frame, "GameFontNormal")
		language:SetPoint(
			"TOPLEFT",
			body,
			"BOTTOMLEFT",
			0,
			-18 - math.ceil(#FEATURES / FEATURE_COLUMNS) * FEATURE_HEIGHT - 8
		)
		language:SetText(L["Language:"])
		local languages = segment(frame, ui.GetLocaleOptions(), function(value)
			state.locale = value
		end)
		languages:SetPoint("LEFT", language, "RIGHT", 10, 0)
		frame.languages = languages
		local import = ns.CreateButton(frame, L["I have a profile string - import..."], 260, true)
		import:SetPoint("TOPLEFT", language, "BOTTOMLEFT", 0, -24)
		import:SetScript("OnClick", function()
			closeWindow()
			if isFresh() then
				ui.SetSetupState("imported")
			end
			ns.Toggle("profiles")
			ns.ShowProfileImport()
		end)
		local note = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH, GRAY)
		note:SetPoint("TOPLEFT", import, "BOTTOMLEFT", 0, -10)
		frame.note = note
		local quickNote = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH, GRAY)
		quickNote:SetPoint("BOTTOMLEFT", 0, 6)
		quickNote:SetText(
			L["The recommended setup takes your role from your talents and the recommended layout; you see the list of changes before anything is applied."]
		)
	end,
	update = function(frame)
		frame.languages:SetValue(state.locale)
		frame.note:SetText(
			isFresh() and ""
				or L["Running the setup again: your current settings are saved as a backup first, and the settings you changed yourself stay unless you check them."]
		)
	end,
	start = true,
}

screens.you = {
	build = function(frame)
		title(frame, L["Your role"])
		local width = (CONTENT_WIDTH - CARD_GAP) / 2
		frame.cards = {}
		for i, role in ipairs(Presets.ROLES) do
			local button = card(frame, width, ROLE_CARD_HEIGHT, role.glyph, L[role.name], L[role.desc], function()
				state.role = role.key
				refresh()
			end)
			button:SetPoint("TOPLEFT", (i - 1) * (width + CARD_GAP), -30)
			button.key = role.key
			frame.cards[i] = button
		end
		local detected = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH, GRAY)
		detected:SetPoint("TOPLEFT", 0, -30 - ROLE_CARD_HEIGHT - 8)
		frame.detected = detected
		local where = title(frame, L["Where do you play most?"], -30 - ROLE_CARD_HEIGHT - 38)
		local places = segment(frame, WHERE, function(value)
			state.where = value
			refresh()
		end)
		places:SetPoint("TOPLEFT", where, "BOTTOMLEFT", 0, -10)
		frame.places = places
		local explain = check(
			frame,
			L["Explain new things when they first appear (one line in chat)"],
			function(checked)
				state.explain = checked
				refresh()
			end
		)
		explain:SetPoint("TOPLEFT", places, "BOTTOMLEFT", -2, -18)
		frame.explain = explain
	end,
	update = function(frame)
		for _, button in ipairs(frame.cards) do
			setSelected(button, button.key == state.role)
		end
		frame.detected:SetText(
			state.detectedTree and L["Detected by your talents: %s"]:format(state.detectedTree) or ""
		)
		frame.places:SetValue(state.where)
		frame.explain:SetChecked(state.explain)
	end,
	ready = function()
		return state.role ~= nil
	end,
	hint = L["Choose your role to continue."],
}

local function sizeNote()
	if state.scale == "larger" then
		return L["Frames and text get bigger."]
	elseif state.scale == "sharp" then
		local width, height = (GetCVar("gxResolution") or ""):match("(%d+)x(%d+)")
		local note = ui.PixelPerfectScale() < currentScale() - SCALE_EPSILON
				and L["One interface unit = one screen pixel on %dx%d: frames get smaller, borders stay sharp."]
			or L["One interface unit = one screen pixel on %dx%d: borders stay sharp."]
		return note:format(tonumber(width) or 0, tonumber(height) or 0)
	end
	return L["The size does not change."]
end

local function layoutEnter(button)
	hoverBorder(button)
	GameTooltip:SetOwner(button, "ANCHOR_TOP")
	GameTooltip:SetText(button.name, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddLine(button.desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	if button.preset then
		local _, fit = ns.LayoutFitText(button.preset, chosenScale())
		if fit then
			GameTooltip:AddLine(fit, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
		end
	end
	GameTooltip:Show()
end

local function layoutLeave(button)
	paintBorder(button, button.selected)
	GameTooltip:Hide()
end

local function paintTag(tag, recommended, active)
	ui.SetShown(tag, recommended or active)
	if recommended then
		tag.text:SetText(L["Recommended"])
		tag.text:SetTextColor(0, 0, 0)
		tag.shade:SetVertexColor(SELECTED[1], SELECTED[2], SELECTED[3], 0.95)
	elseif active then
		tag.text:SetText(L["Now"])
		tag.text:SetTextColor(1, 1, 1)
		tag.shade:SetVertexColor(0.3, 0.3, 0.3, 0.95)
	end
end

local function layoutCard(frame, index, item)
	local button = CreateFrame("Button", nil, frame)
	button:SetSize(LAYOUT_CARD_WIDTH, LAYOUT_CARD_HEIGHT)
	button:SetBackdrop(CARD_BACKDROP)
	button:SetBackdropColor(0, 0, 0, 0.45)
	paintBorder(button, false)
	local column, row = (index - 1) % LAYOUT_COLUMNS, floor((index - 1) / LAYOUT_COLUMNS)
	button:SetPoint("TOPLEFT", column * (LAYOUT_CARD_WIDTH + CARD_GAP), -30 - row * (LAYOUT_CARD_HEIGHT + CARD_GAP))
	local thumb = CreateFrame("Frame", nil, button)
	thumb:SetPoint("TOPLEFT", THUMB_INSET, -THUMB_INSET)
	thumb:SetSize(THUMB_WIDTH, THUMB_HEIGHT)
	button.thumb = thumb
	if not item.preset then
		local screen = thumb:CreateTexture(nil, "BACKGROUND")
		screen:SetTexture(0.04, 0.06, 0.09, 0.95)
		screen:SetAllPoints()
		local glyph = ui.CreateGlyph(thumb, "thumbtack", 20, "ARTWORK")
		glyph:SetPoint("CENTER")
		glyph:SetTextColor(GRAY[1], GRAY[2], GRAY[3])
	end
	local tag = CreateFrame("Frame", nil, thumb)
	tag:SetFrameLevel(thumb:GetFrameLevel() + 3)
	local tagText = text(tag, "GameFontNormalSmall")
	tagText:SetPoint("TOPLEFT", thumb, "TOPLEFT", 4, -2)
	tagText:SetShadowOffset(0, 0)
	tag:SetPoint("TOPLEFT", thumb, "TOPLEFT")
	tag:SetPoint("BOTTOMRIGHT", tagText, "BOTTOMRIGHT", 4, -2)
	tag.shade = tag:CreateTexture(nil, "BACKGROUND")
	tag.shade:SetTexture(ui.Media.blank)
	tag.shade:SetAllPoints()
	tag.text = tagText
	button.tag = tag
	local name = text(button, "GameFontHighlightSmall", LAYOUT_CARD_WIDTH - 6)
	name:SetJustifyH("CENTER")
	name:SetJustifyV("MIDDLE")
	name:SetHeight(LAYOUT_NAME_HEIGHT - 4)
	name:SetPoint("TOP", thumb, "BOTTOM", 0, -2)
	name:SetText(item.name)
	button.label = name
	button.key, button.name, button.desc, button.preset = item.key, item.name, item.desc, item.preset
	button:SetScript("OnClick", function()
		state.layout = item.key
		state.layoutOff = nil
		refresh()
	end)
	button:SetScript("OnEnter", layoutEnter)
	button:SetScript("OnLeave", layoutLeave)
	return button
end

screens.screen = {
	build = function(frame)
		title(frame, L["Frame layout"])
		local list = {}
		if not isFresh() then
			list[1] = { key = LAYOUT_KEEP, name = L["Keep mine"], desc = L["Frames stay where they are now."] }
		end
		for _, preset in ipairs(ui.Movers.GetPresets()) do
			list[#list + 1] = { key = preset.key, name = L[preset.name], desc = L[preset.desc], preset = preset }
		end
		frame.layouts = {}
		for i, item in ipairs(list) do
			frame.layouts[i] = layoutCard(frame, i, item)
		end
		local rows = math.ceil(#list / LAYOUT_COLUMNS)
		local bottom = 30 + rows * LAYOUT_CARD_HEIGHT + (rows - 1) * CARD_GAP
		local desc = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH, GRAY)
		desc:SetPoint("TOPLEFT", 0, -bottom - 8)
		desc:SetJustifyV("TOP")
		frame.layoutDesc = desc

		local sizeTitle = title(frame, L["Interface size"], -bottom - 56)
		local options = { { "keep", L["As now (%d%%)"]:format(percent(currentScale())) } }
		if hasLarger() then
			options[#options + 1] = { "larger", L["Larger (%d%%)"]:format(percent(largerScale())) }
		end
		if offersPixel() then
			options[#options + 1] = { "sharp", L["Pixel-perfect (%d%%)"]:format(percent(ui.PixelPerfectScale())) }
		end
		local sizes = segment(frame, options, function(value)
			state.scale = value
			refresh()
		end)
		sizes:SetPoint("TOPLEFT", sizeTitle, "BOTTOMLEFT", 0, -10)
		frame.sizes = sizes
		local note = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH, GRAY)
		note:SetPoint("TOPLEFT", sizes, "BOTTOMLEFT", 0, -8)
		frame.sizeNote = note
	end,
	update = function(frame)
		local scale = chosenScale()
		if frame.drawnScale ~= scale then
			frame.drawnScale = scale
			for _, button in ipairs(frame.layouts) do
				if button.preset then
					ns.DrawLayoutThumbnail(button.thumb, button.preset, nil, scale)
				end
			end
		end
		local choice, recommended = layoutChoice(), recommendedLayout() or LAYOUT_KEEP
		local active = ui.Movers.GetActivePreset()
		local desc = ""
		for _, button in ipairs(frame.layouts) do
			local selected = button.key == choice
			setSelected(button, selected)
			local color = selected and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			button.label:SetTextColor(color.r, color.g, color.b)
			paintTag(button.tag, button.key == recommended, button.key == active)
			if selected then
				desc = button.desc
			end
		end
		frame.layoutDesc:SetText(desc)
		frame.sizes:SetValue(state.scale)
		frame.sizeNote:SetText(sizeNote())
	end,
}

screens.conflicts = {
	build = function(frame)
		local heading = title(frame, L["These addons do the same job as parts of FrostAtom UI"])
		local note = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH, GRAY)
		note:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
		note:SetText(
			L["Together they draw the same thing twice, so it is better to keep one. The choice is applied with one UI reload at the end (5-10 s, your character stays in place)."]
		)
		local top = -62
		frame.groups = {}
		for _, item in ipairs(state.conflicts) do
			local addon = text(frame, "GameFontNormal", CONTENT_WIDTH)
			addon:SetPoint("TOPLEFT", 0, top)
			addon:SetText(L['%s overlaps FrostAtom UI "%s"']:format(item.addon, item.module))
			top = top - 18
			local group = {}
			for _, choice in ipairs({ "theirs", "ours", "keep" }) do
				if choice ~= "ours" or item.hasOurs then
					local button = radio(frame, item.texts[choice], function()
						state.choices[item.addon] = choice
						refresh()
					end)
					button:SetPoint("TOPLEFT", 4, top)
					button.choice = choice
					group[#group + 1] = button
					top = top - 20
				end
			end
			group.addon = item.addon
			frame.groups[#frame.groups + 1] = group
			top = top - 8
		end
	end,
	update = function(frame)
		for _, group in ipairs(frame.groups) do
			local chosen = state.choices[group.addon] or "theirs"
			for _, button in ipairs(group) do
				button:SetChecked(button.choice == chosen)
			end
		end
	end,
}

local function optionCheck(frame, label, key, x, y)
	local button = check(frame, label, function(checked)
		setOption(key, checked)
		refresh()
	end)
	button:SetPoint("TOPLEFT", x, y)
	button.key = key
	frame.checks[#frame.checks + 1] = button
	return button
end

local function caption(frame, label, y)
	local region = text(frame, "GameFontNormal", CONTENT_WIDTH)
	region:SetPoint("TOPLEFT", 0, y)
	region:SetText(label)
	return region
end

local function optionSegment(frame, anchor, options, key)
	local group = segment(frame, options, function(value)
		setOption(key, value)
		refresh()
	end)
	group:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
	group.key = key
	frame.segments[#frame.segments + 1] = group
	return group
end

local CONVENIENCE = {
	{ "merchant", L["Sell grey items and repair (Shift skips)"] },
	{ "invites", L["Accept group invites from friends and guild"] },
	{ "release", L["Release on battlegrounds automatically"] },
	{ "grass", L["Hide grass - more frames per second"] },
	{ "tutorials", L["Turn off Blizzard tips for new players"] },
}

screens.signals = {
	build = function(frame)
		frame.checks, frame.segments = {}, {}
		local voice = caption(frame, L["Voice for dangerous enemy spells (English)"], -4)
		local voices = optionSegment(frame, voice, VOICE, "voice")
		local example = ns.CreateButton(frame, L["Play example"], 110, true, nil, "volume-high")
		example:SetPoint("LEFT", voices, "RIGHT", 12, 0)
		example:SetScript("OnClick", function()
			local data = ui.API.Catalog("alerts")
			PlaySoundFile(data.VOICE_PATH:format(EXAMPLE_SOUND), ui:GetConfig("spellAlerts.channel"))
		end)
		local errors = caption(
			frame,
			L['Red messages at the top of the screen ("Out of range", "Target not in line of sight"):'],
			-60
		)
		optionSegment(frame, errors, ERRORS, "errors")

		local focus =
			optionCheck(frame, L["Mouse button 5: focus the character under the cursor"], "focusKey", -2, -110)
		frame.focusCheck = focus
		local focusNote = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH - 30, GRAY)
		focusNote:SetPoint("TOPLEFT", focus, "BOTTOMLEFT", 26, 2)
		focusNote:SetText(L["Focus is a second remembered target, needed mostly in arenas."])
		frame.focusNote = focusNote
		local focusBusy = text(frame, "GameFontHighlightSmall", CONTENT_WIDTH, GRAY)
		focusBusy:SetPoint("TOPLEFT", 0, -116)
		focusBusy:SetText(L['Mouse button 5 is taken: bind "Focus mouseover" in Game client > Controls.'])
		frame.focusBusy = focusBusy

		caption(frame, L["Messages to other players (in English)"], -162)
		optionCheck(
			frame,
			L['Say when I interrupt a spell: "Interrupted Vasya\'s Shadow Bolt"'],
			"interrupts",
			-2,
			-178
		)
		optionCheck(frame, L["Post arena rating results to the party"], "arenaResults", -2, -178 - CHECK_LINE)

		caption(frame, L["Convenience"], -240)
		local rows = math.ceil(#CONVENIENCE / 2)
		for i, item in ipairs(CONVENIENCE) do
			local column, row = floor((i - 1) / rows), (i - 1) % rows
			optionCheck(frame, item[2], item[1], column * LEFT_COLUMN_WIDTH - 2, -256 - row * CHECK_LINE)
		end

		local details = ns.CreateButton(frame, L["Details (changes: %d)"]:format(0), 200, true, nil, "list-check")
		details:SetPoint("BOTTOMLEFT", 0, 6)
		details:SetScript("OnClick", showDetails)
		frame.details = details
		local note = text(frame, "GameFontHighlightSmall", nil, GRAY)
		note:SetPoint("LEFT", details, "RIGHT", 12, 0)
		note:SetPoint("RIGHT", frame, "RIGHT")
		note:SetSpacing(3)
		frame.note = note
	end,
	update = function(frame)
		initOptions()
		for _, button in ipairs(frame.checks) do
			button:SetChecked(state.options[button.key] and true or false)
		end
		for _, group in ipairs(frame.segments) do
			group:SetValue(state.options[group.key])
		end
		local free = ui.IsFocusMouseKeyFree()
		ui.SetShown(frame.focusCheck, free)
		ui.SetShown(frame.focusNote, free and state.explain)
		ui.SetShown(frame.focusBusy, not free)
		local plan = buildPlan()
		frame.details:SetText(L["Details (changes: %d)"]:format(changeCount(plan)))
		ui.FitButton(frame.details, 40, 200)
		local _, notes = applyInfo(plan)
		frame.note:SetText(table.concat(notes, "\n"))
	end,
}

local function buildOrder()
	wipe(order)
	order[1] = "welcome"
	order[2] = "you"
	order[3] = "screen"
	if #state.conflicts > 0 then
		order[#order + 1] = "conflicts"
	end
	order[#order + 1] = "signals"
end

local function ensureScreen(key)
	local screen = screens[key]
	if not screen.frame then
		local frame = CreateFrame("Frame", nil, window)
		frame:SetPoint("TOPLEFT", PADDING, -CONTENT_TOP)
		frame:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER)
		frame:Hide()
		screen.frame = frame
		screen.build(frame)
	end
	return screen
end

local function dropScreen(key)
	local screen = screens[key]
	if screen.frame then
		screen.frame:Hide()
		screen.frame = nil
	end
end

function refresh()
	local key = order[state.screen]
	local screen = ensureScreen(key)
	local details = window.details:IsShown()
	ui.SetShown(screen.frame, not details)
	screen.update(screen.frame)
	local step = state.screen - 1
	ui.SetShown(window.step, step > 0)
	window.step:SetText(L["Step %d of %d"]:format(step, #order - 1))
	ui.SetShown(window.back, state.screen > 1)
	ui.SetShown(window.quick, screen.start or false)
	local last = state.screen == #order
	ui.SetShown(window.next, not last)
	ui.SetShown(window.apply, last)
	window.next:SetText(screen.start and L["Start"] or L["Next"])
	ui.FitButton(window.next, 40, 110)
	window.step:ClearAllPoints()
	window.step:SetPoint("RIGHT", last and window.apply or window.next, "LEFT", -12, 0)
	if last then
		local plan = buildPlan()
		local reload, _, blocked = applyInfo(plan)
		window.apply:SetText(reload and L["Apply and reload"] or L["Apply"])
		ui.FitButton(window.apply, 40, 110)
		if blocked then
			window.apply:Disable()
		else
			window.apply:Enable()
		end
		if details then
			window.details.heading:SetText(
				window.details.empty and L["Nothing changes: everything is already like this."]
					or L["Settings to change: %d"]:format(changeCount(plan))
			)
		end
	end
	local ready = not screen.ready or screen.ready()
	if ready then
		window.next:Enable()
	else
		window.next:Disable()
	end
	window.hint:SetText(not ready and screen.hint or "")
	window.heading:SetText(
		step > 0 and L["FrostAtom UI: step %d of %d"]:format(step, #order - 1) or L["FrostAtom UI: setup"]
	)
end

local function createWindow()
	window = ns.CreateWindow(WINDOW_NAME, {
		width = WIDTH,
		height = HEIGHT,
		header = true,
		strata = "DIALOG",
		noClose = true,
	})
	window:SetPoint("CENTER")
	local shade = window:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(0, 0, 0, 0.92)
	shade:SetPoint("TOPLEFT", 4, -4)
	shade:SetPoint("BOTTOMRIGHT", -4, 4)
	window:SetScript("OnHide", function(self)
		if not self.closing and state.screen then
			StaticPopup_Show(SKIP_POPUP)
		end
	end)

	local skipButton = ns.CreateButton(window, L["Skip setup"], 120, true)
	skipButton:SetPoint("BOTTOMLEFT", PADDING, 16)
	skipButton:SetScript("OnClick", function()
		closeWindow()
		StaticPopup_Show(SKIP_POPUP)
	end)
	local nextButton = ns.CreateButton(window, L["Next"], 110, nil, nil, "arrow-right", true)
	nextButton:SetPoint("BOTTOMRIGHT", -PADDING, 16)
	nextButton:SetScript("OnClick", goNext)
	window.next = nextButton
	local applyButton = ns.CreateButton(window, L["Apply and reload"], 110, nil, nil, "check")
	applyButton:SetPoint("BOTTOMRIGHT", -PADDING, 16)
	applyButton:SetScript("OnClick", apply)
	window.apply = applyButton
	local quick = ns.CreateButton(window, L["Recommended setup - 1 click"], 200, nil, nil, "wand-magic-sparkles")
	quick:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
	quick:SetScript("OnClick", recommendedSetup)
	window.quick = quick
	local step = text(window, "GameFontHighlightSmall")
	window.step = step
	local back = ns.CreateButton(window, L["Back"], 100, true, nil, "arrow-left")
	back:SetPoint("RIGHT", step, "LEFT", -12, 0)
	back:SetScript("OnClick", goBack)
	window.back = back
	local hint = text(window, "GameFontHighlightSmall", nil, GRAY)
	hint:SetPoint("BOTTOMRIGHT", nextButton, "TOPRIGHT", 0, 6)
	window.hint = hint
	createDetails()
end

local function expertAddonLoaded()
	for _, addon in ipairs(EXPERT_ADDONS) do
		if IsAddOnLoaded(addon) then
			return true
		end
	end
	return false
end

local function previousSetup()
	local setup = not isFresh() and ui.API.GetUIState("setup")
	return type(setup) == "table" and setup or {}
end

function ns.RunSetup()
	if InCombatLockdown() then
		return
	end
	if not window then
		createWindow()
	elseif window:IsShown() then
		return
	end
	wipe(state)
	state.conflicts = ui.GetConflicts()
	dropScreen("conflicts")
	dropScreen("screen")
	local previous = previousSetup()
	state.locale = ui.GetLocaleOverride()
	state.scale = "keep"
	state.choices = {}
	state.toggles = {}
	resetOptions()
	state.experience = previous.experience
	state.detectedRole, state.detectedTree = Presets.DetectRole()
	state.role = state.detectedRole or previous.role
	state.where = previous.where or (Presets.GetActiveStyle() == "arena" and "arena" or "both")
	state.explain = previous.experience ~= "expert" and #state.conflicts == 0 and not expertAddonLoaded()
	buildOrder()
	ns.HideWindow()
	window:Show()
	showScreen(1)
end
