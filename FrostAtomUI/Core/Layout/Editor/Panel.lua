local _, ns = ...
local L = ns.L

local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local max, floor = math.max, math.floor

local Movers = ns.Movers
local home = Movers.home
local PRESET_PREFIX = home.PRESET_PREFIX
local SAVED_PREFIX = home.SAVED_PREFIX
local bindNudgeKeys = home.bindNudgeKeys
local byPath = home.byPath
local closeSettings = home.closeSettings
local createOverlay = home.createOverlay
local isLayoutActive = home.isLayoutActive
local movers = home.movers
local onDragStop = home.onDragStop
local onGripMouseUp = home.onGripMouseUp
local queueRefresh = home.queueRefresh
local refresh = home.refresh
local selectMover = home.selectMover
local showStatusTooltip = home.showStatusTooltip
local toggleGrid = home.toggleGrid
local updateGrid = home.updateGrid
local updateVisibility = home.updateVisibility
local watchesPath = home.watchesPath

local PANEL_BUTTON_WIDTH = 120
local PANEL_GLYPH_SIZE, PANEL_GLYPH_GAP = 11, 5

local DROPDOWN_WIDTH = 150
local BUTTON_GAP = 8

local panel
local testModeOwned = false

local function createLabel(parent, size, shade, text)
	local label = parent:CreateFontString(nil, "OVERLAY")
	ns.SetFont(label, size)
	label:SetTextColor(shade, shade, shade)
	label:SetText(text)
	return label
end

local TEST_PREVIEW = "unitFrames"

local function onTestModeClick(check)
	if not ns.API.GetPreview(TEST_PREVIEW) then
		return
	end
	ns.API.SetPreview(TEST_PREVIEW, check:GetChecked())
	testModeOwned = ns.API.IsPreviewActive(TEST_PREVIEW)
	check:SetChecked(testModeOwned)
	queueRefresh()
end

local function createPanelButton(text, glyph, onClick)
	local button = CreateFrame("Button", nil, panel)
	button:SetHeight(20)
	button:SetBackdrop(ns.CreateBackdrop(8))
	button:SetBackdropColor(0, 0, 0, 0.5)
	button:SetBackdropBorderColor(0.6, 0.6, 0.6)
	button:SetHighlightTexture(ns.Media.blank)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	button:SetScript("OnClick", onClick)
	local label = createLabel(button, 12, 0.8, text)
	button:SetWidth(max(PANEL_BUTTON_WIDTH, label:GetStringWidth() + PANEL_GLYPH_SIZE + PANEL_GLYPH_GAP + 16))
	label:SetPoint("CENTER", (PANEL_GLYPH_SIZE + PANEL_GLYPH_GAP) / 2, 0)
	local icon = ns.CreateGlyph(button, glyph, PANEL_GLYPH_SIZE)
	icon:SetTextColor(0.8, 0.8, 0.8)
	icon:SetPoint("RIGHT", label, "LEFT", -PANEL_GLYPH_GAP, 0)
	return button
end

local function layoutValues()
	local values = {}
	for _, preset in ipairs(ns.LayoutPresets) do
		values[#values + 1] = { PRESET_PREFIX .. preset.key, L[preset.name] }
	end
	for _, name in ipairs(Movers.GetLayoutNames()) do
		values[#values + 1] = { SAVED_PREFIX .. name, name }
	end
	return values
end

local function activeLayoutValue()
	local preset = Movers.GetActivePreset()
	if preset then
		return PRESET_PREFIX .. preset
	end
	for _, name in ipairs(Movers.GetLayoutNames()) do
		if isLayoutActive(name) then
			return SAVED_PREFIX .. name
		end
	end
end

local function updateLayoutDropdown()
	local dropdown = panel and panel.layouts
	if not dropdown or not panel:IsShown() then
		return
	end
	local value = activeLayoutValue()
	if value then
		dropdown:Select(value)
	else
		dropdown.selected = nil
		UIDropDownMenu_SetSelectedValue(dropdown, nil)
		UIDropDownMenu_SetText(dropdown, L["Custom"])
	end
end

local layoutKey = {}

local function queueLayoutDropdown()
	ns.Defer(layoutKey, updateLayoutDropdown)
end

local pendingLayout

StaticPopupDialogs.FROSTATOMUI_APPLY_LAYOUT = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		local value = pendingLayout
		if value:sub(1, #PRESET_PREFIX) == PRESET_PREFIX then
			Movers.ApplyPreset(value:sub(#PRESET_PREFIX + 1))
		else
			Movers.LoadLayout(value:sub(#SAVED_PREFIX + 1))
		end
	end,
	OnHide = function(dialog)
		dialog:SetFrameStrata("DIALOG")
		queueLayoutDropdown()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local function selectLayout(value)
	pendingLayout = value
	local name
	for _, option in ipairs(layoutValues()) do
		if option[1] == value then
			name = option[2]
		end
	end
	local dialog = StaticPopup_Show(
		"FROSTATOMUI_APPLY_LAYOUT",
		L["Apply the %s layout? Frames move, and bar columns, frame and castbar sizes change to the layout's. Other settings stay."]:format(
			name or value
		)
	)
	if dialog then
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	end
end

local pendingSave

local function saveLayoutNamed(name)
	local ok, saved = Movers.SaveLayout(name)
	if ok then
		ns.Print(L["layout %q saved"], saved)
		queueLayoutDropdown()
	end
end

StaticPopupDialogs.FROSTATOMUI_SAVE_LAYOUT = {
	text = "%s",
	button1 = SAVE,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 40,
	OnShow = function(dialog)
		dialog.editBox:SetText("")
		dialog.editBox:SetFocus()
	end,
	OnAccept = function(dialog)
		local name = strtrim(dialog.editBox:GetText() or "")
		if name == "" then
			return
		end
		if Movers.LayoutExists(name) then
			pendingSave = name
			StaticPopup_Show(
				"FROSTATOMUI_REPLACE_LAYOUT",
				L['Replace the layout "%s"? The old one can be restored on the Backups page.']:format(name)
			)
		else
			saveLayoutNamed(name)
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		StaticPopupDialogs.FROSTATOMUI_SAVE_LAYOUT.OnAccept(dialog)
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

StaticPopupDialogs.FROSTATOMUI_REPLACE_LAYOUT = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		saveLayoutNamed(pendingSave)
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local function groupValues()
	return {
		{ "all", L["All"] },
		{ "frames", L["Unit frames"] },
		{ "bars", L["Action bars"] },
		{ "pvp", L["PvP and cooldowns"] },
		{ "other", L["Interface"] },
	}
end

local function selectGroup(value)
	home.group = value ~= "all" and value or nil
	home.showAll()
end

local function openSettings()
	Movers.Lock()
	local host = ns.API.LoadSettings()
	if host and not host.IsWindowShown() then
		host.Toggle()
	end
end

local function promptSaveLayout()
	local dialog = StaticPopup_Show("FROSTATOMUI_SAVE_LAYOUT", L["Save the current frame layout as:"])
	if dialog then
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	end
end

local panelSlot = ns.Storage.Claim("moversPanel", "Movers", "ui")

local function createPanel()
	panel = CreateFrame("Frame", "FrostAtomUIMovers", UIParent)
	home.panel = panel
	local saved = panelSlot:Get()
	if type(saved) == "table" and saved[1] then
		panel:SetPoint(saved[1], UIParent, saved[1], saved[2], saved[3])
	else
		panel:SetPoint("TOP", 0, -60)
	end
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		panelSlot:Set({ point, floor(x + 0.5), floor(y + 0.5) })
	end)
	panel:SetFrameStrata("FULLSCREEN")
	panel:SetBackdrop(ns.CreateBackdrop(14, 3))
	panel:SetBackdropColor(0, 0, 0, 0.85)

	local hint = createLabel(panel, 11, 0.7, L["Drag to move, Shift - no snapping. Click for frame settings."])
	hint:SetPoint("TOP", 0, -8)

	local nudgeHint = createLabel(panel, 11, 0.7, L["Right-click for options: move back, detach, hide."])
	nudgeHint:SetPoint("TOP", hint, "BOTTOM", 0, -4)

	local check = CreateFrame("CheckButton", "FrostAtomUIMoversTestMode", panel, "UICheckButtonTemplate")
	check:SetSize(22, 22)
	check:SetScript("OnClick", onTestModeClick)
	local checkLabel = createLabel(check, 11, 0.85, L["Show test unit frames"])
	checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
	check:SetPoint("TOPLEFT", panel, "TOP", -(22 + 2 + checkLabel:GetStringWidth()) / 2, -44)
	panel.testCheck = check

	local gridButton = ns.CreateGlyphButton(panel, "border-all", 14, L["Alignment grid"])
	gridButton.tooltipText =
		L["Grid over the screen while frames are unlocked; dragged frames snap to its lines. Screen center lines are always drawn."]
	gridButton:SetPoint("RIGHT", panel, "TOPRIGHT", -8, -55)
	gridButton:SetScript("OnClick", toggleGrid)
	panel.gridButton = gridButton

	local settingsButton = ns.CreateGlyphButton(panel, "gear", 14, L["Back to settings"])
	settingsButton.tooltipText = L["Lock the frames and open the FrostAtom UI settings."]
	settingsButton:SetPoint("LEFT", panel, "TOPLEFT", 8, -55)
	settingsButton:SetScript("OnClick", openSettings)

	local layoutLabel = createLabel(panel, 11, 0.85, L["Frame layout"])
	local groupLabel = createLabel(panel, 11, 0.85, L["Show frames"])
	local labelWidth = max(layoutLabel:GetStringWidth(), groupLabel:GetStringWidth())
	local formWidth = labelWidth + DROPDOWN_WIDTH + 30 + 16
	local labelRight = -formWidth / 2 + labelWidth

	local layouts = ns.CreateDropdown(panel, DROPDOWN_WIDTH, layoutValues, selectLayout, "FrostAtomUIMoversLayout")
	layoutLabel:SetPoint("TOPRIGHT", panel, "TOP", labelRight, -78)
	layouts:SetPoint("LEFT", layoutLabel, "RIGHT", -10, -2)
	panel.layouts = layouts

	local saveButton = ns.CreateGlyphButton(panel, "floppy-disk", 14, L["Save layout as..."])
	saveButton.tooltipText = L["Keep the current positions and sizes as a layout of your own."]
	saveButton:SetPoint("LEFT", layouts, "RIGHT", -8, 2)
	saveButton:SetScript("OnClick", promptSaveLayout)

	local groups = ns.CreateDropdown(panel, DROPDOWN_WIDTH, groupValues, selectGroup, "FrostAtomUIMoversGroup")
	groupLabel:SetPoint("TOPRIGHT", panel, "TOP", labelRight, -106)
	groups:SetPoint("LEFT", groupLabel, "RIGHT", -10, -2)
	groups:Select("all")
	panel.groups = groups

	local status = CreateFrame("Frame", nil, panel)
	status:SetHeight(16)
	status:SetPoint("TOP", 0, -134)
	status:EnableMouse(true)
	status:SetScript("OnEnter", showStatusTooltip)
	status:SetScript("OnLeave", GameTooltip_Hide)
	status.icon = ns.CreateGlyph(status, "circle-check", 11)
	status.icon:SetPoint("LEFT")
	status.text = createLabel(status, 11, 1, "")
	status.text:SetPoint("LEFT", status.icon, "RIGHT", 5, 0)
	panel.status = status

	local undo = createPanelButton(L["Undo"], "arrow-rotate-left", function()
		ns.Undo.Undo()
	end)
	undo:SetScript("OnEnter", home.undoTooltip)
	undo:SetScript("OnLeave", GameTooltip_Hide)
	panel.undo = undo

	local reset = createPanelButton(L["Reset positions"], "location-crosshairs", Movers.ConfirmResetPositions)
	local done = createPanelButton(L["Done"], "check", Movers.Lock)
	local showAll = createPanelButton(L["Show all frames"], "eye", home.showAll)
	panel.showAll = showAll
	panel.buttons = { reset, undo, done, showAll }

	local buttonWidth = max(undo:GetWidth(), reset:GetWidth(), done:GetWidth(), showAll:GetWidth())
	for _, button in ipairs(panel.buttons) do
		button:SetWidth(buttonWidth)
	end

	panel:SetSize(
		max(
			260,
			hint:GetStringWidth() + 24,
			nudgeHint:GetStringWidth() + 24,
			buttonWidth * 4 + BUTTON_GAP * 3 + 24,
			formWidth + 24,
			22 + 2 + checkLabel:GetStringWidth() + 2 * (gridButton:GetWidth() + 12)
		),
		186
	)
end

function home.undoTooltip(button)
	local step = ns.Undo.GetUndo()
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
	GameTooltip:SetText(L["Undo"], 1, 1, 1)
	if step then
		GameTooltip:AddLine(ns.Undo.Describe(step) or L["Last change"], 0.8, 0.8, 0.8, true)
	else
		GameTooltip:AddLine(L["Nothing to undo"], 0.6, 0.6, 0.6)
	end
	GameTooltip:AddLine(L["Ctrl+Z undoes, Ctrl+Y redoes when these keys are free."], 0.6, 0.6, 0.6, true)
	GameTooltip:Show()
end

function home.updatePanel()
	if not panel then
		return
	end
	local step = ns.Undo.GetUndo()
	panel.undo:SetAlpha(step and 1 or 0.45)
	panel.undo:EnableMouse(true)
	ns.SetShown(panel.showAll, home.focus ~= nil)
	ns.UIKit.CenterRow(panel, panel.buttons, BUTTON_GAP, 8)
	if GameTooltip:IsOwned(panel.undo) then
		home.undoTooltip(panel.undo)
	end
end

function home.kin(path)
	local root = byPath[path]
	if not root then
		return nil
	end
	local set, changed = { [root] = true }, true
	while changed do
		changed = false
		for _, mover in ipairs(movers) do
			if not set[mover] then
				local value = ns:GetConfig(mover.path)
				local anchor = type(value) == "table" and value[4] and byPath[value[4]]
				if mover.path:sub(1, #path) == path or (anchor and set[anchor]) then
					set[mover] = true
					changed = true
				end
			end
		end
	end
	return set
end

function home.showAll()
	home.focus = nil
	for _, mover in ipairs(movers) do
		if mover.overlay then
			updateVisibility(mover)
		end
	end
	home.updatePanel()
	queueRefresh()
end

function Movers.Unlock(focusPath)
	if home.unlocked then
		return
	end
	if InCombatLockdown() then
		ns.Print(L["cannot unlock frames in combat"])
		return
	end
	home.unlocked = true
	home.focus = focusPath and home.kin(focusPath) or nil
	if not panel then
		createPanel()
	end
	panel.groups:Select("all")
	home.updatePanel()
	bindNudgeKeys()
	ns.Undo.SetKeysOwner(Movers, true)
	if ns.API.GetPreview(TEST_PREVIEW) then
		panel.testCheck:SetChecked(ns.API.IsPreviewActive(TEST_PREVIEW))
		panel.testCheck:Show()
	else
		panel.testCheck:Hide()
	end
	panel:Show()
	updateLayoutDropdown()
	updateGrid()
	for _, mover in ipairs(movers) do
		if not mover.overlay then
			mover.overlay = createOverlay(mover)
		end
		updateVisibility(mover)
	end
	queueRefresh()
end

function Movers.Lock()
	if not home.unlocked then
		return
	end
	if home.dragging then
		onDragStop(home.dragging.overlay)
	end
	if home.resizing then
		onGripMouseUp(home.resizing.overlay.grip)
	end
	selectMover(nil)
	closeSettings()
	home.closeMenu()
	home.unlocked = false
	home.focus = nil
	home.group = nil
	bindNudgeKeys()
	ns.Undo.SetKeysOwner(Movers, false)
	panel:Hide()
	if testModeOwned and not InCombatLockdown() then
		ns.API.SetPreview(TEST_PREVIEW, false)
	end
	testModeOwned = false
	home.hideGrid()
	for _, mover in ipairs(movers) do
		mover.hiddenWhileUnlocked = nil
		if mover.overlay then
			mover.overlay:Hide()
		end
	end
end

function Movers.Toggle()
	if home.unlocked then
		Movers.Lock()
	else
		Movers.Unlock()
	end
end

function Movers.GetTourTarget(name)
	if name == "undo" or name == "done" then
		return panel and panel[name]
	end
	local mover = byPath[name]
	return mover and mover.overlay
end

function Movers.IsUnlocked()
	return home.unlocked
end

Movers:RegisterEvent("PLAYER_REGEN_DISABLED", Movers.Lock)
Movers:RegisterEvent(ns.E.HISTORY_CHANGED, function()
	home.updatePanel()
end)

local function onScaleChanged()
	if home.unlocked then
		updateGrid()
		queueRefresh()
	end
end

Movers:RegisterEvent("UI_SCALE_CHANGED", onScaleChanged)
Movers:RegisterEvent("DISPLAY_SIZE_CHANGED", onScaleChanged)
Movers:RegisterEvent(ns.E.PIXEL_CHANGED, onScaleChanged)

Movers:RegisterEvent(ns.E.POSITION_INVALIDATED, function()
	if home.unlocked then
		queueRefresh()
	end
end)

Movers:RegisterEvent(ns.E.CONFIG_CHANGED, function(_, path)
	if not home.unlocked then
		return
	end
	if not path or path:find("^general%.") then
		updateGrid()
	end
	queueRefresh()
	queueLayoutDropdown()
	local toggled = not path or path:find("enabled$") ~= nil
	for _, mover in ipairs(movers) do
		if not path or path == mover.path then
			refresh(mover)
		end
		if toggled or watchesPath(mover, path) then
			updateVisibility(mover)
		end
	end
end)
