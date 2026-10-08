local _, ns = ...
local L = ns.L

local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local GetCursorPosition = GetCursorPosition
local IsShiftKeyDown = IsShiftKeyDown
local floor = math.floor
local max = math.max
local min = math.min
local tconcat = table.concat

local Movers = ns.Movers
local home = Movers.home
local MIN_HEIGHT = home.MIN_HEIGHT
local MIN_WIDTH = home.MIN_WIDTH
local byPath = home.byPath
local fallbackSize = home.fallbackSize
local isActive = home.isActive
local moverRect = home.moverRect
local rectOf = home.rectOf
local unpackPoint = home.unpackPoint

local COLOR = {
	BACKDROP = { 0.2, 0.6, 1, 0.35 },
	BORDER = { 0.5, 0.8, 1 },
	HOVER = { 0.3, 0.8, 1, 0.5 },
	TEXT = { 1, 1, 1 },
	ANCHORED_BACKDROP = { 0.16, 0.34, 0.5, 0.18 },
	ANCHORED_BORDER = { 0.3, 0.45, 0.55 },
	ANCHORED_HOVER = { 0.22, 0.5, 0.65, 0.35 },
	ANCHORED_TEXT = { 0.6, 0.65, 0.7 },
	GRIP = { 0.8, 0.95, 1, 0.8 },
	GRID = { 1, 1, 1, 0.12 },
	GRID_CENTER = { 1, 0.4, 0.4, 0.4 },
	SELECTED_BORDER = { 1, 0.82, 0 },
	CONFLICT_BORDER = { 1, 0.25, 0.2 },
	STATUS_OK = { 0.45, 0.85, 0.45 },
	STATUS_WARN = { 1, 0.35, 0.3 },
	SNAP_LINE = { 1, 0.82, 0, 0.9 },
	ATTACH_LINE = { 0.4, 1, 0.5, 0.9 },
	GRID_BUTTON_ON = { 0.5, 0.8, 1 },
	GRID_BUTTON_OFF = { 0.45, 0.45, 0.45 },
}

local LINK_SIZE, LINK_GAP = 9, 3

local GRIP_SIZE = 12

local SHIFT_NUDGE = 10

local NUDGE_BUTTON = "FrostAtomUIMoversNudge"
local OVERLAY_STRATA = "DIALOG"

local NUDGE_KEYS = {
	UP = { 0, 1 },
	DOWN = { 0, -1 },
	LEFT = { -1, 0 },
	RIGHT = { 1, 0 },
}

local function cursorPosition()
	local uiScale = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	return cursorX / uiScale, cursorY / uiScale
end

local function placeLabel(overlay)
	local text = overlay.text
	local linkWidth = overlay.link:IsShown() and LINK_SIZE + LINK_GAP or 0
	text:ClearAllPoints()
	if overlay:GetWidth() < text:GetStringWidth() + linkWidth + 8 or overlay:GetHeight() < MIN_HEIGHT then
		text:SetPoint("BOTTOM", overlay, "TOP", linkWidth / 2, 2)
	else
		text:SetPoint("CENTER", linkWidth / 2, 0)
	end
end

local function attach(mover)
	local overlay = mover.overlay
	overlay:ClearAllPoints()
	local left, bottom, width, height = moverRect(mover)
	local frameLeft, frameBottom = rectOf(mover.frame)
	if left and frameLeft then
		overlay:SetSize(max(width, 1), max(height, 1))
		overlay:SetPoint("BOTTOMLEFT", mover.frame, "BOTTOMLEFT", left - frameLeft, bottom - frameBottom)
	else
		local fallbackWidth, fallbackHeight = fallbackSize(mover)
		overlay:SetSize(max(fallbackWidth, 1), max(fallbackHeight, 1))
		ns.ApplyPoint(overlay, mover.path)
	end
	placeLabel(overlay)
end

local function showTooltip(overlay)
	local mover = overlay.mover
	local value = ns:GetConfig(mover.path)
	if type(value) ~= "table" then
		return
	end
	local point, x, y, anchorPath, anchorPoint = unpackPoint(value)
	GameTooltip:SetOwner(overlay, "ANCHOR_TOP")
	GameTooltip:SetText(L[mover.label], 1, 1, 1)
	if anchorPath then
		GameTooltip:AddLine(
			L["%s  %d, %d  of  %s %s"]:format(point, x, y, Movers.GetLabel(anchorPath), anchorPoint),
			0.4,
			1,
			0.5
		)
	elseif anchorPoint and anchorPoint ~= point then
		GameTooltip:AddLine(L["%s  %d, %d  of screen %s"]:format(point, x, y, anchorPoint), 0.8, 0.8, 0.8)
	else
		GameTooltip:AddLine(("%s  %d, %d"):format(point, x, y), 0.8, 0.8, 0.8)
	end
	if mover.offScreen then
		GameTooltip:AddLine(L["Partly off screen"], 1, 0.35, 0.3)
	end
	if mover.conflicts then
		local names = {}
		for i = 1, #mover.conflicts do
			names[i] = L[mover.conflicts[i].label]
		end
		GameTooltip:AddLine(L["Overlaps: %s"]:format(tconcat(names, ", ")), 1, 0.35, 0.3, true)
	end
	GameTooltip:AddLine(L["Drag to move"], 0.6, 0.6, 0.6)
	GameTooltip:AddLine(L["Click for frame settings"], 0.6, 0.6, 0.6)
	GameTooltip:AddLine(L["Right-click for a menu (move back, detach)"], 0.6, 0.6, 0.6)
	GameTooltip:AddLine(L["Shift: no snapping"], 0.6, 0.6, 0.6)
	if mover == home.selected then
		GameTooltip:AddLine(
			L["Arrow keys nudge by 1, Shift+arrows by 10, the attachment is kept; Esc clears the selection"],
			1,
			0.82,
			0,
			true
		)
	else
		GameTooltip:AddLine(L["Selected frames nudge with the arrow keys"], 0.6, 0.6, 0.6)
	end
	if mover.resize then
		GameTooltip:AddLine(L["Drag the bottom-right corner to resize"], 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

local selectMover

local function loadedConfig()
	return ns.API.GetSettingsHost()
end

local function loadConfig()
	return ns.API.LoadSettings()
end

local function openSettings(path)
	local config = loadConfig()
	local mover = byPath[path]
	if config and config.OpenElement then
		config.OpenElement(path, mover and mover.overlay)
	end
end

local function closeSettings()
	local config = loadedConfig()
	if config and config.CloseElement then
		config.CloseElement()
	end
end

local function openedSettings()
	local config = loadedConfig()
	return config and config.GetOpenElement and config.GetOpenElement()
end

local function onMouseDown(overlay, button)
	local mover = overlay.mover
	mover.cursorX, mover.cursorY = cursorPosition()
	mover.dragged = false
	if button == "LeftButton" then
		selectMover(mover)
		local opened = openedSettings()
		if opened and opened ~= mover.path and home.selected == mover then
			openSettings(mover.path)
		end
	end
end

local resizeFrame = CreateFrame("Frame")
resizeFrame:Hide()

local function updateResize()
	local mover = home.resizing
	local resize = mover.resize
	local cursorX, cursorY = cursorPosition()
	local width = mover.startWidth + cursorX - mover.cursorX
	local height = mover.startHeight - (cursorY - mover.cursorY)

	width = floor(max(resize.minWidth or MIN_WIDTH, min(resize.maxWidth or UIParent:GetWidth(), width)) + 0.5)
	height = floor(max(resize.minHeight or MIN_HEIGHT, min(resize.maxHeight or UIParent:GetHeight(), height)) + 0.5)
	if resize.square then
		width = max(width, height)
		height = width
	end
	if width ~= mover.lastWidth or height ~= mover.lastHeight then
		mover.lastWidth, mover.lastHeight = width, height
		resize.set(width, height)
	end
end

resizeFrame:SetScript("OnUpdate", updateResize)

local function onGripMouseDown(grip)
	local mover = grip:GetParent().mover
	if mover.secure and InCombatLockdown() then
		return
	end
	mover.cursorX, mover.cursorY = cursorPosition()
	local _, _, width, height = moverRect(mover)
	mover.startWidth, mover.startHeight = mover.resize.get()
	mover.startWidth = mover.startWidth or width
	mover.startHeight = mover.startHeight or height
	mover.lastWidth, mover.lastHeight = nil, nil
	ns.Undo.Begin(L['Resize "%s"']:format(L[mover.label]))
	home.resizing = mover
	resizeFrame:Show()
end

local function onGripMouseUp(grip)
	local mover = grip:GetParent().mover
	if home.resizing ~= mover then
		return
	end
	updateResize()
	home.resizing = nil
	resizeFrame:Hide()
	ns.Undo.End()
	attach(mover)
end

local function createGrip(overlay)
	local grip = CreateFrame("Button", nil, overlay)
	grip:SetSize(GRIP_SIZE, GRIP_SIZE)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(overlay:GetFrameLevel() + 1)
	grip:SetScript("OnMouseDown", onGripMouseDown)
	grip:SetScript("OnMouseUp", onGripMouseUp)

	for i = 1, 3 do
		local line = grip:CreateTexture(nil, "OVERLAY")
		line:SetTexture(ns.Media.blank)
		line:SetVertexColor(unpack(COLOR.GRIP))
		line:SetSize(GRIP_SIZE - (i - 1) * 4, 2)
		line:SetPoint("BOTTOMRIGHT", 0, (i - 1) * 4)
	end
	return grip
end

local function onClick(overlay, button)
	local mover = overlay.mover
	if button == "RightButton" then
		if IsControlKeyDown() then
			home.moveBack(mover, true)
		elseif IsShiftKeyDown() then
			home.hide(mover)
		else
			home.showMenu(mover)
		end
	elseif not mover.dragged and home.selected == mover then
		openSettings(mover.path)
	end
end

local function updateColors(mover, hover)
	local overlay = mover.overlay
	local value = ns:GetConfig(mover.path)
	local anchored = type(value) == "table" and value[4] ~= nil
	if hover then
		overlay:SetBackdropColor(unpack(anchored and COLOR.ANCHORED_HOVER or COLOR.HOVER))
	else
		overlay:SetBackdropColor(unpack(anchored and COLOR.ANCHORED_BACKDROP or COLOR.BACKDROP))
	end
	if mover == home.selected then
		overlay:SetBackdropBorderColor(unpack(COLOR.SELECTED_BORDER))
	elseif mover.conflicts or mover.offScreen then
		overlay:SetBackdropBorderColor(unpack(COLOR.CONFLICT_BORDER))
	else
		overlay:SetBackdropBorderColor(unpack(anchored and COLOR.ANCHORED_BORDER or COLOR.BORDER))
	end
	overlay.text:SetTextColor(unpack(anchored and COLOR.ANCHORED_TEXT or COLOR.TEXT))
	if anchored ~= (overlay.link:IsShown() and true or false) then
		ns.SetShown(overlay.link, anchored)
		placeLabel(overlay)
	end
end

local function onEnter(overlay)
	updateColors(overlay.mover, true)
	showTooltip(overlay)
end

local function onLeave(overlay)
	updateColors(overlay.mover)
	GameTooltip:Hide()
end

local function createOverlay(mover)
	local overlay = CreateFrame("Button", nil, UIParent)
	overlay.mover = mover
	overlay:Hide()
	overlay:SetFrameStrata(OVERLAY_STRATA)
	overlay:SetMovable(true)
	overlay:SetClampedToScreen(true)
	overlay:EnableMouse(true)
	overlay:RegisterForDrag("LeftButton")
	overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	overlay:SetBackdrop(ns.CreateBackdrop(8, 2))
	overlay:SetBackdropColor(unpack(COLOR.BACKDROP))
	overlay:SetScript("OnMouseDown", onMouseDown)
	overlay:SetScript("OnDragStart", home.onDragStart)
	overlay:SetScript("OnDragStop", home.onDragStop)
	overlay:SetScript("OnClick", onClick)
	overlay:SetScript("OnEnter", onEnter)
	overlay:SetScript("OnLeave", onLeave)

	local text = overlay:CreateFontString(nil, "OVERLAY")
	ns.SetFont(text, 11, "OUTLINE", true)
	text:SetPoint("CENTER")
	text:SetText(L[mover.label])
	overlay.text = text

	local link = ns.CreateGlyph(overlay, "link", LINK_SIZE, "OVERLAY", "OUTLINE")
	link:SetTextColor(COLOR.ATTACH_LINE[1], COLOR.ATTACH_LINE[2], COLOR.ATTACH_LINE[3])
	link:SetPoint("RIGHT", text, "LEFT", -LINK_GAP, 0)
	link:Hide()
	overlay.link = link

	if mover.resize then
		overlay.grip = createGrip(overlay)
	end
	return overlay
end

local function refresh(mover)
	updateColors(mover, mover.overlay:IsMouseOver())
	attach(mover)
end

local GROUP_PREFIXES = {
	{ "frames", { "unitFrames.", "raidFrames.", "playerPlate." } },
	{ "bars", { "actionBar." } },
	{
		"pvp",
		{
			"groupCooldowns.",
			"diminishingReturns.",
			"arena",
			"loseControl.",
			"lossOfControl.",
			"externalDefensives.",
			"soloQueue.",
			"trackers.",
		},
	},
}

function home.groupOf(mover)
	local path = mover.path
	for _, group in ipairs(GROUP_PREFIXES) do
		for _, prefix in ipairs(group[2]) do
			if path:sub(1, #prefix) == prefix then
				return group[1]
			end
		end
	end
	return "other"
end

local function updateVisibility(mover)
	local active = not mover.hiddenWhileUnlocked
		and (not home.focus or home.focus[mover])
		and (not home.group or home.groupOf(mover) == home.group)
		and isActive(mover)
	if not active and mover == home.selected then
		selectMover(nil)
	end
	if active and not mover.overlay:IsShown() then
		refresh(mover)
	end
	ns.SetShown(mover.overlay, active)
end

local nudgeButton

function home.escape()
	if StaticPopup_EscapePressed() then
		return
	elseif UIDROPDOWNMENU_OPEN_MENU then
		CloseDropDownMenus()
	elseif home.selected then
		selectMover(nil)
	else
		Movers.Lock()
	end
end

local function nudge(_, button)
	if button == "ESCAPE" then
		home.escape()
		return
	end
	local mover = home.selected
	if not mover then
		return
	end
	local key = button:gsub("^SHIFT%-", "")
	local step = NUDGE_KEYS[key]
	if not step or (mover.secure and InCombatLockdown()) then
		return
	end
	local distance = key ~= button and SHIFT_NUDGE or 1
	local point, x, y, anchorPath, anchorPoint = unpackPoint(ns:GetConfig(mover.path))
	ns:SetConfig(mover.path, { point, x + step[1] * distance, y + step[2] * distance, anchorPath, anchorPoint })
	if mover.overlay:IsMouseOver() then
		showTooltip(mover.overlay)
	end
end

local function bindNudgeKeys()
	if not nudgeButton then
		nudgeButton = CreateFrame("Button", NUDGE_BUTTON, UIParent)
		nudgeButton:RegisterForClicks("AnyDown")
		nudgeButton:SetScript("OnClick", nudge)
	end
	ClearOverrideBindings(nudgeButton)
	if not home.unlocked or InCombatLockdown() then
		return
	end
	if home.selected then
		for key in pairs(NUDGE_KEYS) do
			SetOverrideBindingClick(nudgeButton, true, key, NUDGE_BUTTON, key)
			SetOverrideBindingClick(nudgeButton, true, "SHIFT-" .. key, NUDGE_BUTTON, "SHIFT-" .. key)
		end
	end
	SetOverrideBindingClick(nudgeButton, true, "ESCAPE", NUDGE_BUTTON, "ESCAPE")
end

function selectMover(mover)
	if mover == home.selected or (mover and InCombatLockdown()) then
		return
	end
	local previous = home.selected
	home.selected = mover
	if previous and previous.overlay then
		updateColors(previous, previous.overlay:IsMouseOver())
	end
	if mover then
		updateColors(mover, mover.overlay:IsMouseOver())
		if mover.overlay:IsMouseOver() then
			showTooltip(mover.overlay)
		end
	else
		closeSettings()
	end
	bindNudgeKeys()
end

function Movers.Select(path)
	local mover = byPath[path]
	if not home.unlocked or not mover or not mover.overlay or not mover.overlay:IsShown() then
		return false
	end
	selectMover(mover)
	if home.selected ~= mover then
		return false
	end
	openSettings(path)
	return true
end

function Movers.ClearSelection()
	selectMover(nil)
end

home.COLOR = COLOR
home.OVERLAY_STRATA = OVERLAY_STRATA
home.attach = attach
home.bindNudgeKeys = bindNudgeKeys
home.closeSettings = closeSettings
home.createOverlay = createOverlay
home.cursorPosition = cursorPosition
home.onGripMouseUp = onGripMouseUp
home.refresh = refresh
home.selectMover = selectMover
home.showTooltip = showTooltip
home.updateColors = updateColors
home.updateVisibility = updateVisibility
